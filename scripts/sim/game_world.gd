class_name GameWorld
extends RefCounted
## État complet d'une partie et ses règles. Avancé par tick(delta).
## Aucune dépendance à l'affichage : c'est ce bloc qui tourne chez l'hôte en coop.

enum State { PLAYING, WON, LOST }

## Identifiant de producteur réservé à la base (les bâtiments utilisent leur id, toujours > 0).
const BASE_ID := -1

var grid: GameGrid
var pathfinder: Pathfinder
var flow: FlowField
var waves: WaveManager
var state := State.PLAYING
var base_hp := Balance.BASE_HP
var enemies: Array[Enemy] = []
var kills := 0
## Compteurs de la partie (missions du jour, statistiques).
var stats := {"towers_built": 0, "houses_built": 0, "upgrades": 0, "workers_trained": 0, "boss_kills": 0,
		"metal_harvested": 0, "units_trained": 0, "objectives_done": 0}
## Objectifs bonus de la carte : {type, wave, state ("pending", "active", "done", "failed"), destroyed, total}
var objectives: Array[Dictionary] = []
var _routes := {}
var _objective_queue: Array = [] # [délai, type d'entité, index objectif]
## Événements visuels (tirs, destructions) que l'affichage récupère avec take_events().
var events: Array[Dictionary] = []
## En coop, l'hôte garde aussi une copie des événements pour l'autre joueur.
var record_net_events := false
var net_events: Array[Dictionary] = []
## Gisements : quantité restante par case ; cases épuisées (dans l'ordre).
var deposit_left := {}
var depleted: Array[Vector2i] = []
var metal := Balance.START_METAL
var essence := Balance.START_ESSENCE
var max_base_hp := Balance.BASE_HP
var pop_cap := Content.BASE_POP
var orbital_cooldown := 0.0 # < 0 = pouvoir non débloqué

## Bonus de progression (technos, augments). Voir GameWorld.new().
var damage_mult := 1.0
var worker_speed_mult := 1.0
var carry_bonus := 0
var laser_unlocked := false
var workers: Array[Worker] = []
var units: Array[Unit] = []
var sites: Array[BuildSite] = []
var base_producer := Producer.new()

## Nombre d'unités en file à la base (compatibilité HUD / tests).
var train_queue: int:
	get:
		return base_producer.queue.size()

var _next_id := 1
var _next_enemy_id := 1
var _next_site_id := 1
var _next_unit_id := 1
var _flow_dirty := true
var _base_rect := Rect2()
var _rng := RandomNumberGenerator.new()
var _auto_repair_timer := 0.0
## Grille spatiale des ennemis (cases de BUCKET x BUCKET), refaite à chaque tick.
const BUCKET := 4
var _buckets := {}


## config (optionnel) : start_metal, start_workers, base_hp, damage_mult, worker_speed_mult,
## carry_bonus, orbital (bool), waves (nombre de vagues), difficulty, wave_interval, laser (bool).
func _init(g: GameGrid, config := {}) -> void:
	grid = g
	metal = config.get("start_metal", Balance.START_METAL)
	max_base_hp = config.get("base_hp", Balance.BASE_HP)
	base_hp = max_base_hp
	damage_mult = config.get("damage_mult", 1.0)
	worker_speed_mult = config.get("worker_speed_mult", 1.0)
	carry_bonus = config.get("carry_bonus", 0)
	laser_unlocked = config.get("laser", false)
	orbital_cooldown = 0.0 if config.get("orbital", false) else -1.0
	pathfinder = Pathfinder.new(g)
	flow = FlowField.new(g, pathfinder)
	waves = WaveManager.new()
	_rng.seed = 12345 # déterministe
	if not g.base_cells.is_empty():
		_base_rect = Rect2(Vector2(g.base_cells[0]), Vector2.ONE)
		for c in g.base_cells:
			_base_rect = _base_rect.merge(Rect2(Vector2(c), Vector2.ONE))
	waves.total = config.get("waves", Balance.WAVE_COUNT)
	waves.difficulty = config.get("difficulty", 1.0)
	waves.interval = config.get("wave_interval", Balance.WAVE_INTERVAL)
	for c in g.metal_deposits:
		deposit_left[c] = Balance.METAL_PER_DEPOSIT
	for c in g.essence_deposits:
		deposit_left[c] = Balance.ESSENCE_PER_DEPOSIT
	for o in config.get("objectives", []):
		if Balance.OBJECTIVES.has(o.get("type", "")):
			objectives.append({"type": o.type, "wave": int(o.get("wave", 3)), "state": "pending", "destroyed": 0,
					"total": int(Balance.OBJECTIVES[o.type].count)})
	for i in config.get("start_workers", Balance.START_WORKERS):
		_spawn_worker()


# --- Avancement du temps -------------------------------------------------

func tick(delta: float) -> void:
	if state != State.PLAYING:
		return
	waves.tick(delta, self)
	_tick_objectives(delta)
	if orbital_cooldown > 0.0:
		orbital_cooldown = maxf(0.0, orbital_cooldown - delta)
	if _flow_dirty:
		flow.rebuild()
		_flow_dirty = false
	_tick_producer(base_producer, BASE_ID, delta)
	for s in sites:
		if s.built and s.producer != null:
			_tick_producer(s.producer, s.id, delta)
	_auto_repair_timer -= delta
	if _auto_repair_timer <= 0.0:
		_auto_repair_timer = 0.5
		_auto_repair_scan()
	for w in workers:
		_tick_worker(w, delta)
	_rebuild_buckets()
	for s in sites:
		if s.built and s.is_tower():
			_tick_tower(s, delta)
	for u in units:
		_tick_unit(u, delta)
	_separate_units()
	for e in enemies:
		_tick_enemy(e, delta)
	_remove_dead()
	if base_hp <= 0:
		base_hp = 0
		state = State.LOST
	elif waves.finished() and not enemies.any(func(x: Enemy) -> bool: return not x.neutral):
		state = State.WON


## Reprend la partie après une victoire, en waves infinies.
func continue_infinite() -> void:
	waves.infinite = true
	waves.timer = waves.interval
	state = State.PLAYING


func _emit(ev: Dictionary) -> void:
	events.append(ev)
	if record_net_events:
		net_events.append(ev)


func take_net_events() -> Array[Dictionary]:
	var e := net_events
	net_events = []
	return e


func take_events() -> Array[Dictionary]:
	var e := events
	events = []
	return e


func spawn_enemy(type_name: String, cell: Vector2i, hp_scale: float) -> void:
	var at := Vector2(cell) + Vector2(0.5, 0.5) + Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
	var e := Enemy.create(type_name, at, hp_scale)
	e.id = _next_enemy_id
	_next_enemy_id += 1
	e.visual_offset = Vector2(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2))
	enemies.append(e)


# --- Objectifs bonus ------------------------------------------------------------

## Trajet d'un objectif : d'un bord de la carte à l'autre, le long de son réseau.
func objective_route(type_name: String) -> Array[Vector2]:
	if _routes.has(type_name):
		return _routes[type_name]
	var check: Callable
	match type_name:
		"train":
			check = grid.is_rail
		"convoy":
			check = grid.is_road
		_:
			check = grid.is_water
	var route := _longest_route(check)
	_routes[type_name] = route
	return route


func _longest_route(check: Callable) -> Array[Vector2]:
	var ends: Array[Vector2i] = []
	for y in grid.height:
		for x in grid.width:
			var c := Vector2i(x, y)
			if not check.call(c):
				continue
			var n := 0
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if check.call(c + d):
					n += 1
			if x == 0 or y == 0 or x == grid.width - 1 or y == grid.height - 1 or n <= 1:
				ends.append(c)
	var best: Array[Vector2i] = []
	for a in ends:
		var prev := {a: a}
		var q: Array[Vector2i] = [a]
		var last := a
		while not q.is_empty():
			var c: Vector2i = q.pop_front()
			last = c
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nb: Vector2i = c + d
				if check.call(nb) and not prev.has(nb):
					prev[nb] = c
					q.append(nb)
		# Extrémité la plus lointaine parmi les bouts du réseau
		var far := a
		var far_d := -1
		for b in ends:
			if prev.has(b) and b != a:
				var k := 0
				var cur := b
				while cur != a:
					cur = prev[cur]
					k += 1
				if k > far_d:
					far_d = k
					far = b
		if far_d + 1 > best.size():
			var path: Array[Vector2i] = []
			var cur := far
			while cur != a:
				path.push_front(cur)
				cur = prev[cur]
			path.push_front(a)
			best = path
	var out: Array[Vector2] = []
	for c in best:
		out.append(Vector2(c) + Vector2(0.5, 0.5))
	return out


func _tick_objectives(delta: float) -> void:
	for i in objectives.size():
		var o := objectives[i]
		if o.state == "pending" and waves.wave >= o.wave:
			var route := objective_route(o.type)
			if route.size() < 4:
				o.state = "failed"
				continue
			o.state = "active"
			var def: Dictionary = Balance.OBJECTIVES[o.type]
			for k in int(def.count):
				_objective_queue.append([k * 1.4, def.entity, i])
			_emit({"type": "objective", "state": "active", "index": i})
	for q in _objective_queue:
		q[0] -= delta
	while not _objective_queue.is_empty() and _objective_queue[0][0] <= 0.0:
		var q: Array = _objective_queue.pop_front()
		var route := objective_route(objectives[q[2]].type)
		var e := Enemy.create(q[1], route[0], waves.hp_scale())
		e.id = _next_enemy_id
		_next_enemy_id += 1
		e.route = route
		e.route_i = 1
		e.objective = q[2]
		e.facing = (route[1] - route[0]).normalized()
		enemies.append(e)


## Entité d'objectif : avance le long de son trajet ; si elle sort de la carte, l'objectif échoue.
func _tick_neutral(e: Enemy, delta: float) -> void:
	var step := e.speed * (e.slow_mult if e.slow_timer > 0.0 else 1.0) * delta
	while step > 0.0 and e.route_i < e.route.size():
		var t: Vector2 = e.route[e.route_i]
		var d := e.pos.distance_to(t)
		if d > 0.001:
			e.facing = e.facing.lerp((t - e.pos) / d, 0.35).normalized()
		if d <= step:
			e.pos = t
			step -= d
			e.route_i += 1
		else:
			e.pos += (t - e.pos) / d * step
			step = 0.0
	if e.route_i >= e.route.size():
		e.hp = 0 # sorti de la carte
		var o := objectives[e.objective]
		if o.state == "active":
			o.state = "failed"
			_emit({"type": "objective", "state": "failed", "index": e.objective})


func _objective_destroyed(e: Enemy) -> void:
	var o := objectives[e.objective]
	o.destroyed += 1
	_emit({"type": "death", "pos": e.pos, "big": true})
	if o.state == "active" and o.destroyed >= o.total:
		o.state = "done"
		var def: Dictionary = Balance.OBJECTIVES[o.type]
		metal += int(def.metal)
		essence += int(def.essence)
		stats.objectives_done += 1
		_emit({"type": "objective", "state": "done", "index": e.objective, "pos": e.pos})


func base_center() -> Vector2:
	return _base_rect.get_center()


func base_rect() -> Rect2:
	return _base_rect


# --- Production ------------------------------------------------------------------

func producer_by_id(id: int) -> Producer:
	if id == BASE_ID:
		return base_producer
	var s := site_by_id(id)
	return s.producer if s != null and s.built else null


## Types que peut former ce producteur.
func producer_options(id: int) -> Array:
	if id == BASE_ID:
		return Content.BASE_PRODUCES
	var s := site_by_id(id)
	return Content.PRODUCTION[s.kind].produces if s != null and s.is_producer() else []


func pop_used() -> int:
	var n := workers.size()
	for u in units:
		n += u.pop()
	n += base_producer.queued_pop()
	for s in sites:
		if s.producer != null:
			n += s.producer.queued_pop()
	return n


## Raison du refus, ou "" si on peut mettre cette unité en file.
func can_queue(producer_id: int, type_name: String) -> String:
	var p := producer_by_id(producer_id)
	if p == null:
		return "Bâtiment indisponible"
	if not producer_options(producer_id).has(type_name):
		return "Ce bâtiment ne forme pas cette unité"
	if p.queue.size() >= Producer.MAX_QUEUE:
		return "File pleine (%d max)" % Producer.MAX_QUEUE
	var d: Dictionary = Content.UNITS[type_name]
	if pop_used() + int(d.pop) > pop_cap:
		return "Population max atteinte : construis un habitat"
	if metal < d.metal:
		return "Pas assez de métal (%d)" % d.metal
	if essence < d.essence:
		return "Pas assez d'essence (%d)" % d.essence
	return ""


## Met une unité en file : le coût est payé tout de suite (remboursé si on annule).
func queue_unit(producer_id: int, type_name: String) -> bool:
	if can_queue(producer_id, type_name) != "":
		return false
	var d: Dictionary = Content.UNITS[type_name]
	metal -= d.metal
	essence -= d.essence
	producer_by_id(producer_id).queue.append(type_name)
	return true


func cancel_queue(producer_id: int, index: int) -> bool:
	var p := producer_by_id(producer_id)
	if p == null or index < 0 or index >= p.queue.size():
		return false
	var d: Dictionary = Content.UNITS[p.queue[index]]
	metal += d.metal
	essence += d.essence
	p.queue.remove_at(index)
	if index == 0:
		p.progress = 0.0
	return true


func set_rally(producer_id: int, c: Vector2i) -> void:
	var p := producer_by_id(producer_id)
	if p != null and grid.is_inside(c):
		p.rally = c


## Compatibilité : former un ouvrier à la base.
func can_train_worker() -> String:
	return can_queue(BASE_ID, "worker")


func train_worker() -> bool:
	return queue_unit(BASE_ID, "worker")


func _tick_producer(p: Producer, producer_id: int, delta: float) -> void:
	if not p.busy():
		return
	p.progress += delta
	if p.progress < p.current_time():
		return
	var type_name: String = p.queue.pop_front()
	p.progress = 0.0
	var spot := _spawn_spot(producer_id, p)
	if type_name == "worker":
		var w := _spawn_worker(spot)
		stats.workers_trained += 1
		_send_to_rally_worker(w, p)
	else:
		var u := Unit.create(type_name, Vector2(spot) + Vector2(0.5, 0.5))
		u.id = _next_unit_id
		_next_unit_id += 1
		units.append(u)
		stats.units_trained += 1
		if p.has_rally():
			_unit_go(u, p.rally)
	_emit({"type": "spawned", "pos": Vector2(spot) + Vector2(0.5, 0.5)})


func _producer_cells(producer_id: int) -> Array[Vector2i]:
	if producer_id == BASE_ID:
		return grid.base_cells
	var s := site_by_id(producer_id)
	return s.cells() if s != null else grid.base_cells


## Case libre autour du producteur, la plus proche du point de ralliement.
func _spawn_spot(producer_id: int, p: Producer) -> Vector2i:
	var spots := pathfinder.free_cells_around(_producer_cells(producer_id))
	if spots.is_empty():
		return Vector2i(base_center().floor())
	if not p.has_rally():
		return spots[_rng.randi_range(0, spots.size() - 1)]
	var best := spots[0]
	for c in spots:
		if Vector2(c).distance_squared_to(Vector2(p.rally)) < Vector2(best).distance_squared_to(Vector2(p.rally)):
			best = c
	return best


func _send_to_rally_worker(w: Worker, p: Producer) -> void:
	if not p.has_rally():
		return
	var t := grid.get_cell(p.rally)
	if t == GameGrid.Cell.METAL or t == GameGrid.Cell.ESSENCE:
		command_harvest([w], p.rally)
	elif depleted.has(p.rally):
		# Le ralliement était sur un gisement épuisé : on récolte le plus proche.
		w.deposit_type = GameGrid.Cell.METAL
		w.target_deposit = p.rally
		_retarget_deposit(w)
	else:
		command_move([w], p.rally)


# --- Combat ---------------------------------------------------------------------

func _rebuild_buckets() -> void:
	_buckets.clear()
	for e in enemies:
		if e.hp <= 0:
			continue
		var k := Vector2i(int(e.pos.x) / BUCKET, int(e.pos.y) / BUCKET)
		if _buckets.has(k):
			_buckets[k].append(e)
		else:
			_buckets[k] = [e]


func _can_hit(st: Dictionary, e: Enemy) -> bool:
	return e.hp > 0 and not ((st.targets == "air" and not e.flying) or (st.targets == "ground" and e.flying))


func _find_target(center: Vector2, st: Dictionary, r: float = -1.0) -> Enemy:
	if r < 0.0:
		r = st.range
	var best: Enemy = null
	var best_d := r * r
	var best_n: Enemy = null
	var best_nd := r * r
	var b0 := Vector2i(int(maxf(0.0, center.x - r)) / BUCKET, int(maxf(0.0, center.y - r)) / BUCKET)
	var b1 := Vector2i(int(center.x + r) / BUCKET, int(center.y + r) / BUCKET)
	for by in range(b0.y, b1.y + 1):
		for bx in range(b0.x, b1.x + 1):
			var list: Variant = _buckets.get(Vector2i(bx, by))
			if list == null:
				continue
			for e: Enemy in list:
				if not _can_hit(st, e):
					continue
				var d := center.distance_squared_to(e.pos)
				if e.neutral:
					# Objectif bonus : seulement s'il n'y a pas d'ennemi hostile à portée.
					if d <= best_nd:
						best_n = e
						best_nd = d
				elif d <= best_d:
					best = e
					best_d = d
	return best if best != null else best_n


## Tir d'une tourelle ou d'une unité : dégâts (de zone si splash) + événement visuel.
func _fire(kind: String, from: Vector2, target: Enemy, st: Dictionary, mult := 1.0) -> void:
	var dmg := roundi(st.damage * damage_mult * mult)
	match st.get("effect", ""):
		"cone":
			var dir := (target.pos - from).normalized()
			var r2: float = st.range * st.range
			for e in enemies:
				if e.hp > 0 and not e.flying and e.pos.distance_squared_to(from) <= r2 \
						and dir.dot((e.pos - from).normalized()) > 0.8:
					_damage_enemy(e, dmg)
			_emit({"type": "shot", "kind": kind, "from": from, "to": from + dir * st.range})
			return
		"chain":
			var pts: Array = [from]
			var hit := {}
			var cur := target
			for i in int(st.chain):
				hit[cur.id] = true
				pts.append(cur.pos)
				_damage_enemy(cur, roundi(dmg * pow(0.85, i)))
				var nxt: Enemy = null
				var bd: float = st.chain_range * st.chain_range
				for e in enemies:
					if e.hp > 0 and not hit.has(e.id) and _can_hit(st, e):
						var d := e.pos.distance_squared_to(cur.pos)
						if d < bd:
							bd = d
							nxt = e
				if nxt == null:
					break
				cur = nxt
			_emit({"type": "chain", "pts": pts})
			return
		"slow", "stun":
			var sp: float = st.splash
			for e in enemies:
				if e.hp > 0 and _can_hit(st, e) and e.pos.distance_squared_to(target.pos) <= sp * sp:
					_damage_enemy(e, dmg)
					if st.effect == "slow":
						e.slow_timer = st.slow_time
						e.slow_mult = st.slow
					else:
						e.stun_timer = maxf(e.stun_timer, st.stun * (0.5 if e.is_boss() else 1.0))
			_emit({"type": "wave_fx", "kind": kind, "pos": target.pos, "r": sp, "from": from})
			return
	if st.splash > 0.0:
		var sp: float = st.splash
		for e in enemies:
			if e.hp > 0 and not e.flying and e.pos.distance_squared_to(target.pos) <= sp * sp:
				_damage_enemy(e, dmg)
	else:
		_damage_enemy(target, dmg)
	if kind != "laser":
		_emit({"type": "shot", "kind": kind, "from": from, "to": target.pos})


func _tick_tower(s: BuildSite, delta: float) -> void:
	var st := s.stats()
	s.cooldown -= delta
	s.retarget_timer -= delta
	var center := s.center()
	var t := s.target
	# On garde la cible tant qu'elle est vivante et à portée ; sinon on cherche (au plus 5 fois par seconde).
	if t == null or t.hp <= 0 or center.distance_squared_to(t.pos) > st.range * st.range:
		t = null
		if s.retarget_timer <= 0.0:
			s.retarget_timer = 0.2
			t = _find_target(center, st)
	s.target = t
	s.beam_target = t if s.kind == "laser" else null
	if t == null:
		return
	s.aim_angle = (t.pos - center).angle()
	if s.cooldown > 0.0:
		return
	s.cooldown = st.delay
	_fire(s.kind, center, t, st)


func _tick_unit(u: Unit, delta: float) -> void:
	if u.ability_cd > 0.0:
		u.ability_cd -= delta
	if u.buff_time > 0.0:
		u.buff_time -= delta
		if u.buff_time <= 0.0 and u.ability() == "bastion":
			u.max_hp = int(u.stats().hp)
			u.hp = mini(u.hp, u.max_hp)
	var st := u.eff()
	u.cooldown -= delta
	u.retarget_timer -= delta
	u.repath_timer -= delta
	var rng: float = st.range
	if st.targets == "none":
		_tick_medic(u, st, delta)
		return
	if u.sieged:
		_tick_sieged(u, st)
		return
	if u.target != null and u.target.hp <= 0:
		u.target = null
		if u.order == Unit.Order.ATTACK:
			u.order = Unit.Order.GUARD
			u.guard_pos = u.pos
	match u.order:
		Unit.Order.MOVE:
			# Déplacement forcé : on ignore les ennemis jusqu'à l'arrivée (permet de battre en retraite).
			u.target = null
			var md := u.pos.distance_to(u.dest)
			var mstuck := md > 0.6 and _unit_stuck(u, delta)
			if mstuck and md > 3.0 and u.stuck_tries < 3:
				u.stuck_tries += 1
				u.path = _path_toward(u.cell(), Vector2i(u.dest.floor()))
				mstuck = false
			if mstuck or _follow_path(u, st.speed, delta):
				u.order = Unit.Order.GUARD
				u.guard_pos = u.pos
				u.path.clear()
			return
		Unit.Order.AMOVE:
			# Déplacement offensif : on engage tout ennemi croisé, puis on reprend la route.
			if u.target == null and u.retarget_timer <= 0.0:
				u.retarget_timer = 0.3
				u.target = _find_target(u.pos, st, rng + Unit.AGGRO_EXTRA)
			if u.target != null and u.pos.distance_to(u.target.pos) > rng + Unit.AGGRO_EXTRA + 2.0:
				u.target = null
			if u.target == null:
				var dd := u.pos.distance_to(u.dest)
				var stuck := dd > 0.6 and _unit_stuck(u, delta)
				if stuck and dd > 3.0 and u.stuck_tries < 3:
					# Bloqué loin du but : on recalcule le chemin.
					u.stuck_tries += 1
					u.path.clear()
					u.repath_timer = 0.0
					stuck = false
				if dd <= 0.6 or stuck:
					u.order = Unit.Order.GUARD
					u.guard_pos = u.pos
					u.path.clear()
					return
				if u.path.is_empty() and u.repath_timer <= 0.0:
					u.repath_timer = 0.5
					u.path = _path_toward(u.cell(), Vector2i(u.dest.floor()))
					if u.path.is_empty():
						u.order = Unit.Order.GUARD
						u.guard_pos = u.pos
						return
				if _follow_path(u, st.speed, delta):
					u.order = Unit.Order.GUARD
					u.guard_pos = u.pos
				return
		Unit.Order.GUARD:
			if u.target == null and u.retarget_timer <= 0.0:
				u.retarget_timer = 0.3
				var t := _find_target(u.pos, st, rng + Unit.AGGRO_EXTRA)
				if t != null and t.pos.distance_to(u.guard_pos) <= Unit.LEASH + rng:
					u.target = t
			if u.target != null and u.target.pos.distance_to(u.guard_pos) > Unit.LEASH + rng:
				u.target = null # trop loin de son poste : on lâche
	if u.target != null:
		u.stuck_pos = Vector2.INF # en combat : la détection de blocage repart de zéro
		u.stuck_t = 0.0
		var d := u.pos.distance_to(u.target.pos)
		if d <= rng:
			u.path.clear()
			u.aim_angle = (u.target.pos - u.pos).angle()
			u.facing = (u.target.pos - u.pos).normalized()
			if u.cooldown <= 0.0:
				u.cooldown = st.delay
				_unit_shoot(u, st)
			return
		if u.repath_timer <= 0.0:
			u.repath_timer = 0.5
			u.path = _path_toward(u.cell(), Vector2i(u.target.pos.floor()))
		_follow_path(u, st.speed, delta)
		return
	# Garde sans cible : retour au poste (s'il est bloqué par un voisin, son poste devient sa position).
	var gd := u.pos.distance_to(u.guard_pos)
	if gd > 0.7:
		if _unit_stuck(u, delta):
			u.guard_pos = u.pos
			u.path.clear()
			return
		if u.path.is_empty() and u.repath_timer <= 0.0:
			u.repath_timer = 0.5
			u.path = _path_toward(u.cell(), Vector2i(u.guard_pos.floor()))
		_follow_path(u, st.speed, delta)


## Détection de blocage : l'unité n'a pas bougé de plus de 0,25 case depuis 1,2 s.
func _unit_stuck(u: Unit, delta: float) -> bool:
	if u.stuck_pos == Vector2.INF or u.pos.distance_to(u.stuck_pos) > 0.25:
		u.stuck_pos = u.pos
		u.stuck_t = 0.0
		return false
	u.stuck_t += delta
	if u.stuck_t >= 1.2:
		u.stuck_t = 0.0
		u.stuck_pos = Vector2.INF
		return true
	return false


## Tir d'une unité (passif critique du sniper).
func _unit_shoot(u: Unit, st: Dictionary) -> void:
	var mult := 1.0
	if st.get("passive", "") == "first_crit":
		if u.target.id != u.last_target_id:
			u.last_target_id = u.target.id
			u.crit_ready = true
		if u.crit_ready:
			u.crit_ready = false
			mult = 3.0
			_emit({"type": "crit", "pos": u.target.pos})
	_fire(u.type, u.pos, u.target, st, mult)


## Char en mode siège : immobile, tire sur ce qui est à portée.
func _tick_sieged(u: Unit, st: Dictionary) -> void:
	u.path.clear()
	var rng: float = st.range
	if u.target != null and (u.target.hp <= 0 or u.pos.distance_to(u.target.pos) > rng):
		u.target = null
	if u.target == null and u.retarget_timer <= 0.0:
		u.retarget_timer = 0.3
		u.target = _find_target(u.pos, st, rng)
	if u.target == null:
		return
	u.aim_angle = (u.target.pos - u.pos).angle()
	if u.cooldown <= 0.0:
		u.cooldown = st.delay
		_unit_shoot(u, st)


## Médic : se déplace sur ordre, soigne en continu l'unité blessée la plus proche à portée.
func _tick_medic(u: Unit, st: Dictionary, delta: float) -> void:
	if u.order == Unit.Order.MOVE or u.order == Unit.Order.AMOVE:
		if _follow_path(u, st.speed, delta):
			u.order = Unit.Order.GUARD
			u.guard_pos = u.pos
		return
	var best: Unit = null
	var bd: float = st.range
	for o in units:
		if o != u and o.alive and o.hp < o.max_hp:
			var d := u.pos.distance_to(o.pos)
			if d < bd:
				bd = d
				best = o
	if best == null:
		u.heal_acc = 0.0
		return
	u.facing = (best.pos - u.pos).normalized()
	u.heal_acc += float(st.heal) * delta
	if u.heal_acc >= 1.0:
		var amount := int(u.heal_acc)
		u.heal_acc -= amount
		best.hp = mini(best.max_hp, best.hp + amount)
		if randf() < 0.25:
			_emit({"type": "heal", "from": u.pos, "to": best.pos})


## Pouvoirs : appliqués à toutes les unités de la liste qui ont ce pouvoir et l'ont rechargé.
func use_ability(us: Array, ability_id: String) -> int:
	var n := 0
	var ab: Dictionary = Content.ABILITIES.get(ability_id, {})
	if ab.is_empty():
		return 0
	for u: Unit in us:
		if u == null or not u.alive or u.ability() != ability_id or u.ability_cd > 0.0:
			continue
		n += 1
		u.ability_cd = ab.cd
		match ability_id:
			"siege":
				u.sieged = not u.sieged
				u.path.clear()
				u.order = Unit.Order.GUARD
				u.guard_pos = u.pos
				u.target = null
			"nanoheal":
				for o in units:
					if o.alive and o.pos.distance_to(u.pos) <= ab.radius:
						o.hp = mini(o.max_hp, o.hp + int(ab.amount))
			"bastion":
				u.buff_time = ab.dur
				var bonus := int(u.stats().hp * 0.5)
				u.max_hp = int(u.stats().hp) + bonus
				u.hp += bonus
			_:
				u.buff_time = ab.dur
		_emit({"type": "ability", "id": ability_id, "pos": u.pos})
	return n


## Chemin vers une case, ou vers une case libre voisine si elle est bloquée.
func _path_toward(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if pathfinder.is_free(to):
		return pathfinder.find_path(from, to)
	return pathfinder.find_path_to_adjacent(from, [to] as Array[Vector2i])


## Écarte légèrement les unités qui se superposent.
func _separate_units() -> void:
	var n := units.size()
	for i in n:
		for j in range(i + 1, n):
			var a := units[i]
			var b := units[j]
			var d := a.pos - b.pos
			var l := d.length()
			if l < 0.6 and l > 0.0001:
				var push := d / l * (0.6 - l) * 0.5
				if pathfinder.is_free(Vector2i((a.pos + push).floor())):
					a.pos += push
				if pathfinder.is_free(Vector2i((b.pos - push).floor())):
					b.pos -= push


func _damage_enemy(e: Enemy, amount: int) -> void:
	if e.hp <= 0:
		return
	e.hp -= maxi(1, amount - e.armor)
	if e.hp <= 0 and e.neutral:
		_objective_destroyed(e)
		return
	if e.hp <= 0:
		kills += 1
		if e.is_boss():
			stats.boss_kills += 1
		var bounty: int = Balance.KILL_BOUNTY.get(e.type, 1)
		metal += bounty
		_emit({"type": "bounty", "pos": e.pos, "amount": bounty})
		_emit({"type": "death", "pos": e.pos, "big": e.type in ["armored", "brute", "siege", "shell"] or e.is_boss(), "boss": e.is_boss()})


func _tick_enemy(e: Enemy, delta: float) -> void:
	if e.hp <= 0:
		return
	if e.slow_timer > 0.0:
		e.slow_timer -= delta
	if e.stun_timer > 0.0:
		e.stun_timer -= delta
		return # étourdi : ni déplacement ni attaque
	if e.neutral:
		_tick_neutral(e, delta)
		return
	e.attack_timer -= delta
	e.retarget_timer -= delta
	if e.retarget_timer <= 0.0:
		e.retarget_timer = 0.25
		_pick_target(e)
	if e.target_kind != Enemy.Target.NONE and _target_distance(e) <= e.attack_range:
		if e.attack_timer <= 0.0:
			e.attack_timer = e.cooldown
			_enemy_attack(e)
		return
	var dir := Vector2.ZERO
	if not e.flying:
		dir = flow.direction_at(e.pos)
	if dir == Vector2.ZERO:
		dir = (base_center() - e.pos).normalized()
	e.facing = dir
	e.pos += dir * e.speed * (e.slow_mult if e.slow_timer > 0.0 else 1.0) * delta


## Cible la plus proche à portée : ouvrier, unité, bâtiment ou base.
func _pick_target(e: Enemy) -> void:
	e.target_kind = Enemy.Target.NONE
	e.target_ref = null
	var best_d := e.attack_range
	var d := _dist_to_rect(e.pos, _base_rect)
	if d <= best_d:
		best_d = d
		e.target_kind = Enemy.Target.BASE
	for w in workers:
		d = e.pos.distance_to(w.pos) - 0.3
		if d < best_d:
			best_d = d
			e.target_kind = Enemy.Target.WORKER
			e.target_ref = w
	for u in units:
		d = e.pos.distance_to(u.pos) - 0.35
		if d < best_d:
			best_d = d
			e.target_kind = Enemy.Target.UNIT
			e.target_ref = u
	for s in sites:
		d = _dist_to_rect(e.pos, s.rect())
		if d < best_d:
			best_d = d
			e.target_kind = Enemy.Target.SITE
			e.target_ref = s


func _target_distance(e: Enemy) -> float:
	match e.target_kind:
		Enemy.Target.BASE:
			return _dist_to_rect(e.pos, _base_rect)
		Enemy.Target.WORKER:
			var w: Worker = e.target_ref
			return e.pos.distance_to(w.pos) - 0.3 if w.alive else INF
		Enemy.Target.UNIT:
			var u: Unit = e.target_ref
			return e.pos.distance_to(u.pos) - 0.35 if u.alive else INF
		Enemy.Target.SITE:
			var s: BuildSite = e.target_ref
			return _dist_to_rect(e.pos, s.rect()) if s.alive else INF
	return INF


func _enemy_attack(e: Enemy) -> void:
	var to := base_center()
	match e.target_kind:
		Enemy.Target.BASE:
			base_hp -= e.damage
			_emit({"type": "base_hit"})
		Enemy.Target.WORKER:
			var w: Worker = e.target_ref
			w.hp -= e.damage
			to = w.pos
		Enemy.Target.UNIT:
			var u: Unit = e.target_ref
			u.hp -= maxi(1, e.damage - int(u.eff().armor))
			to = u.pos
		Enemy.Target.SITE:
			var s: BuildSite = e.target_ref
			s.hp -= e.damage
			to = s.center()
	_emit({"type": "hit", "from": e.pos, "to": to, "ranged": e.attack_range > 1.5})


func _remove_dead() -> void:
	for e in enemies:
		if e.hp <= 0:
			enemies = enemies.filter(func(x: Enemy) -> bool: return x.hp > 0)
			break
	for w in workers.filter(func(x: Worker) -> bool: return x.hp <= 0):
		w.alive = false
		workers.erase(w)
		_emit({"type": "death", "pos": w.pos, "big": false})
	for u in units.filter(func(x: Unit) -> bool: return x.hp <= 0):
		u.alive = false
		units.erase(u)
		_emit({"type": "death", "pos": u.pos, "big": u.type == "tank"})
	for s in sites.filter(func(x: BuildSite) -> bool: return x.hp <= 0):
		_remove_site(s)
		_emit({"type": "death", "pos": s.center(), "big": true})


func _remove_site(s: BuildSite) -> void:
	s.alive = false
	sites.erase(s)
	if s.built and s.kind == "house":
		pop_cap -= Content.HOUSE.pop
	if s.producer != null:
		# Ce qui était en file est remboursé.
		for t in s.producer.queue:
			metal += int(Content.UNITS[t].metal)
			essence += int(Content.UNITS[t].essence)
		s.producer.queue.clear()
	for c in s.cells():
		pathfinder.set_solid(c, false)
	_flow_dirty = true
	for w in workers:
		if w.target_site == s:
			_resume_or_idle(w)


static func _dist_to_rect(p: Vector2, r: Rect2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(q)


# --- Ouvriers -----------------------------------------------------------------

func _tick_worker(w: Worker, delta: float) -> void:
	match w.state:
		Worker.State.MOVING:
			if _follow_path(w, Balance.WORKER_SPEED * worker_speed_mult, delta):
				_on_arrived(w)
		Worker.State.HARVESTING:
			w.timer -= delta
			if w.timer <= 0.0:
				var c := w.target_deposit
				var left: int = deposit_left.get(c, 0)
				if left <= 0 or not is_deposit(c):
					_retarget_deposit(w)
					return
				var take := mini(Balance.CARRY_CAPACITY + carry_bonus, left)
				deposit_left[c] = left - take
				w.carry_type = grid.get_cell(c)
				w.carry_amount = take
				if left - take <= 0:
					_deplete(c)
				_move_to_adjacent(w, grid.base_cells)
		Worker.State.BUILDING:
			var s := w.target_site
			if s == null or s.built or not s.alive:
				_set_idle(w)
				return
			s.work_done += delta
			if s.work_done >= s.work_needed:
				_finish_site(s)
		Worker.State.REPAIRING:
			var amount := ceili(Balance.REPAIR_RATE * delta)
			if w.repair_base:
				base_hp = mini(max_base_hp, base_hp + amount)
				if base_hp >= max_base_hp:
					_resume_or_idle(w)
				return
			var s := w.target_site
			if s == null or not s.alive or s.hp >= s.max_hp:
				_resume_or_idle(w)
				return
			s.hp = mini(s.max_hp, s.hp + amount)
			if s.hp >= s.max_hp:
				_resume_or_idle(w)


## Avance le long du chemin (ouvrier ou unité). Renvoie true une fois arrivé.
func _follow_path(m: Variant, speed: float, delta: float) -> bool:
	var step := speed * delta
	var loose: bool = m is Unit # les unités de combat coupent les virages (évite les bouchons)
	while step > 0.0 and not m.path.is_empty():
		var target := Vector2(m.path[0]) + Vector2(0.5, 0.5)
		var d: float = m.pos.distance_to(target)
		if d > 0.001:
			m.facing = (target - m.pos) / d
		if loose and d < (0.55 if m.path.size() > 1 else 0.35):
			m.path.remove_at(0) # point de passage atteint « à peu près » : on enchaîne
			continue
		if d <= step:
			m.pos = target
			step -= d
			m.path.remove_at(0)
		else:
			m.pos += (target - m.pos) / d * step
			step = 0.0
	return m.path.is_empty()


func _on_arrived(w: Worker) -> void:
	match w.job:
		Worker.Job.HARVEST:
			if w.carry_amount > 0:
				_deposit(w)
				if is_deposit(w.target_deposit):
					_move_to_adjacent(w, [w.target_deposit] as Array[Vector2i])
				else:
					_retarget_deposit(w)
			elif not is_deposit(w.target_deposit):
				_retarget_deposit(w)
			else:
				w.state = Worker.State.HARVESTING
				w.timer = Balance.HARVEST_TIME
		Worker.Job.BUILD:
			w.state = Worker.State.BUILDING
		Worker.Job.REPAIR:
			w.state = Worker.State.REPAIRING
		_:
			w.state = Worker.State.IDLE


func _deposit(w: Worker) -> void:
	if w.carry_type == GameGrid.Cell.METAL:
		metal += w.carry_amount
		stats.metal_harvested += w.carry_amount
	elif w.carry_type == GameGrid.Cell.ESSENCE:
		essence += w.carry_amount
	w.carry_amount = 0
	w.carry_type = -1


## Les ouvriers en réparation auto vont réparer le bâtiment abîmé le plus proche (base comprise).
func _auto_repair_scan() -> void:
	for w in workers:
		if w.job == Worker.Job.BUILD or w.job == Worker.Job.REPAIR:
			continue
		var idle := is_idle(w)
		if not idle and not w.auto_repair:
			continue
		# Un ouvrier inactif termine d'abord les chantiers en attente.
		if idle:
			var site: BuildSite = null
			var sd := Balance.IDLE_ASSIST_RADIUS
			for s in sites:
				if not s.built:
					var d := _dist_to_rect(w.pos, s.rect())
					if d < sd:
						site = s
						sd = d
			if site != null:
				command_build([w], site)
				continue
		var radius := Balance.IDLE_ASSIST_RADIUS if idle else Balance.AUTO_REPAIR_RADIUS
		var best: BuildSite = null
		var best_d := radius
		for s in sites:
			if s.built and s.hp < s.max_hp:
				var d := _dist_to_rect(w.pos, s.rect())
				if d < best_d:
					best = s
					best_d = d
		var base_d := _dist_to_rect(w.pos, _base_rect)
		if base_hp < max_base_hp and base_d < best_d:
			command_repair_base([w])
		elif best != null:
			command_repair([w], best)


## Ouvrier sans tâche et à l'arrêt.
func is_idle(w: Worker) -> bool:
	return w.alive and w.job == Worker.Job.NONE and w.state == Worker.State.IDLE and w.path.is_empty()


func idle_workers() -> Array[Worker]:
	var out: Array[Worker] = []
	for w in workers:
		if is_idle(w):
			out.append(w)
	return out


# --- Ordres du joueur ---------------------------------------------------------

func command_move(ws: Array, c: Vector2i) -> void:
	for w: Worker in ws:
		if w == null:
			continue
		w.job = Worker.Job.NONE
		w.target_site = null
		w.repair_base = false
		w.target_deposit = Vector2i(-1, -1)
		_set_path(w, _path_toward(w.cell(), c))


func command_harvest(ws: Array, deposit: Vector2i) -> void:
	for w: Worker in ws:
		if w == null:
			continue
		w.job = Worker.Job.HARVEST
		w.target_site = null
		w.repair_base = false
		w.target_deposit = deposit
		if is_deposit(deposit):
			w.deposit_type = grid.get_cell(deposit)
		elif w.carry_amount <= 0:
			_retarget_deposit(w)
			continue
		if w.carry_amount > 0:
			_move_to_adjacent(w, grid.base_cells)
		else:
			_move_to_adjacent(w, [deposit] as Array[Vector2i])


func command_build(ws: Array, site: BuildSite) -> void:
	for w: Worker in ws:
		if w == null:
			continue
		w.job = Worker.Job.BUILD
		w.target_site = site
		w.repair_base = false
		_move_to_adjacent(w, site.cells())


func command_repair(ws: Array, site: BuildSite) -> void:
	for w: Worker in ws:
		if w == null:
			continue
		w.job = Worker.Job.REPAIR
		w.target_site = site
		w.repair_base = false
		_move_to_adjacent(w, site.cells())


func command_repair_base(ws: Array) -> void:
	for w: Worker in ws:
		if w == null:
			continue
		w.job = Worker.Job.REPAIR
		w.target_site = null
		w.repair_base = true
		_move_to_adjacent(w, grid.base_cells)


func set_auto_repair(ws: Array, on: bool) -> void:
	for w: Worker in ws:
		if w != null:
			w.auto_repair = on


## Déplace un groupe en formation : chaque unité vise une case libre autour du point touché.
func command_units_move(us: Array, c: Vector2i) -> void:
	var spots := _formation_cells(c, us.size(), us)
	var i := 0
	for u: Unit in us:
		if u != null:
			_unit_go(u, spots[mini(i, spots.size() - 1)])
			i += 1


func _formation_cells(c: Vector2i, n: int, movers: Array = []) -> Array[Vector2i]:
	# Cases déjà tenues par des unités qui ne font pas partie du groupe : on les évite.
	var held := {}
	for u in units:
		if u.alive and not movers.has(u) and u.order == Unit.Order.GUARD:
			held[Vector2i(u.guard_pos.floor())] = true
	var out: Array[Vector2i] = []
	if pathfinder.is_free(c) and not held.has(c):
		out.append(c)
	var r := 1
	while out.size() < n and r <= 10:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cc := c + Vector2i(dx, dy)
				if pathfinder.is_free(cc) and not held.has(cc) and out.size() < n:
					out.append(cc)
		r += 1
	if out.is_empty():
		out.append(c)
	return out


func command_units_attack(us: Array, e: Enemy) -> void:
	for u: Unit in us:
		if u == null or e == null:
			continue
		var st := u.stats()
		if (st.targets == "air" and not e.flying) or (st.targets == "ground" and e.flying):
			continue # cette unité ne peut pas toucher cette cible
		u.order = Unit.Order.ATTACK
		u.target = e
		u.repath_timer = 0.0


## Arrête tout : unités en garde sur place, ouvriers inactifs.
func command_stop(us: Array, ws: Array) -> void:
	for u: Unit in us:
		if u != null:
			u.order = Unit.Order.GUARD
			u.target = null
			u.path.clear()
			u.guard_pos = u.pos
	for w: Worker in ws:
		if w != null:
			w.target_deposit = Vector2i(-1, -1)
			_set_idle(w)


func _unit_go(u: Unit, c: Vector2i) -> void:
	if u.sieged:
		return # un char en mode siège ne bouge pas
	u.order = Unit.Order.MOVE # déplacement simple : on ignore les ennemis (repli possible)
	u.dest = Vector2(c) + Vector2(0.5, 0.5)
	u.stuck_t = 0.0
	u.stuck_pos = Vector2.INF
	u.stuck_tries = 0
	u.target = null
	u.path = _path_toward(u.cell(), c)
	if u.path.is_empty():
		u.order = Unit.Order.GUARD
		u.guard_pos = u.pos


## Raison du refus, ou "" si le bâtiment peut être posé (c = coin haut-gauche).
func can_place(kind: String, c: Vector2i) -> String:
	if kind == "laser" and not laser_unlocked:
		return "Laser à débloquer dans la boutique"
	var cost := Content.building(kind)
	var size := int(cost.get("size", 1))
	var cells: Array[Vector2i] = []
	for dy in size:
		for dx in size:
			cells.append(c + Vector2i(dx, dy))
	for cc in cells:
		if not grid.is_inside(cc):
			return "Hors de la map"
		if grid.get_cell(cc) != GameGrid.Cell.EMPTY or site_at(cc) != null:
			return "Emplacement occupé" if size > 1 else "Case occupée"
	if metal < cost.metal:
		return "Pas assez de métal (%d)" % cost.metal
	if essence < cost.essence:
		return "Pas assez d'essence (%d)" % cost.essence
	for cc in cells:
		pathfinder.set_solid(cc, true)
	var open := enemies_can_reach_base()
	for cc in cells:
		pathfinder.set_solid(cc, false)
	if not open:
		return "Bloquerait le chemin des ennemis"
	return ""


func place(kind: String, c: Vector2i) -> BuildSite:
	if can_place(kind, c) != "":
		return null
	var cost := Content.building(kind)
	metal -= cost.metal
	essence -= cost.essence
	var s := BuildSite.new(kind)
	s.id = _next_site_id
	_next_site_id += 1
	s.cell = c
	sites.append(s)
	for cc in s.cells():
		pathfinder.set_solid(cc, true)
	_flow_dirty = true
	for w in workers:
		if w.state == Worker.State.MOVING and s.cells().any(func(cc: Vector2i) -> bool: return w.path.has(cc)):
			_set_path(w, _path_toward(w.cell(), w.path.back()))
	for u in units:
		if not u.path.is_empty():
			u.repath_timer = 0.0
			if u.order == Unit.Order.MOVE or u.order == Unit.Order.AMOVE:
				u.path = _path_toward(u.cell(), u.path.back())
	return s


## Raccourcis pour la mitrailleuse (utilisés par les tests).
func can_place_tower(c: Vector2i) -> String:
	return can_place("gun", c)


func place_tower(c: Vector2i) -> BuildSite:
	return place("gun", c)


# --- Amélioration et vente -------------------------------------------------------------

func can_upgrade(s: BuildSite) -> String:
	if not s.built or not s.is_tower():
		return "Pas améliorable"
	if s.level >= BuildSite.MAX_LEVEL:
		return "Niveau maximum"
	var cost := s.upgrade_cost()
	if metal < cost.metal:
		return "Pas assez de métal (%d)" % cost.metal
	if essence < cost.essence:
		return "Pas assez d'essence (%d)" % cost.essence
	return ""


func upgrade(s: BuildSite) -> bool:
	if can_upgrade(s) != "":
		return false
	var cost := s.upgrade_cost()
	metal -= cost.metal
	essence -= cost.essence
	s.invested_metal += cost.metal
	s.invested_essence += cost.essence
	var old_max := s.max_hp
	s.level += 1
	stats.upgrades += 1
	s.max_hp = s.stats().hp
	s.hp += s.max_hp - old_max
	_emit({"type": "built", "pos": s.center()})
	return true


func sell(s: BuildSite) -> void:
	if not sites.has(s):
		return
	var refund := s.sell_value()
	metal += refund.metal
	essence += refund.essence
	_remove_site(s)


# --- Pouvoir de base ------------------------------------------------------------------

func orbital_unlocked() -> bool:
	return orbital_cooldown >= 0.0


func orbital_ready() -> bool:
	return orbital_cooldown == 0.0


func cast_orbital(at: Vector2) -> bool:
	if not orbital_ready():
		return false
	orbital_cooldown = Content.ORBITAL.cooldown
	for e in enemies:
		if e.hp > 0 and e.pos.distance_to(at) <= Content.ORBITAL.radius:
			_damage_enemy(e, roundi(Content.ORBITAL.damage * damage_mult))
	_emit({"type": "orbital", "pos": at})
	return true


## Règle anti-blocage : chaque point d'apparition doit garder un chemin vers la base.
func enemies_can_reach_base() -> bool:
	for sp in grid.spawn_points:
		if pathfinder.find_path_to_adjacent(sp, grid.base_cells).is_empty():
			return false
	return true


# --- Requêtes pour l'interface -----------------------------------------------

func site_at(c: Vector2i) -> BuildSite:
	for s in sites:
		if s.contains(c):
			return s
	return null


func is_base_cell(c: Vector2i) -> bool:
	return grid.get_cell(c) == GameGrid.Cell.BASE


func worker_at(p: Vector2, radius := 0.5) -> Worker:
	var best: Worker = null
	var best_d := radius
	for w in workers:
		var d := w.pos.distance_to(p)
		if d <= best_d:
			best = w
			best_d = d
	return best


func unit_at(p: Vector2, radius := 0.55) -> Unit:
	var best: Unit = null
	var best_d := radius
	for u in units:
		var d := u.pos.distance_to(p)
		if d <= best_d:
			best = u
			best_d = d
	return best


func enemy_at(p: Vector2, radius := 0.7) -> Enemy:
	var best: Enemy = null
	var best_d := radius
	for e in enemies:
		var d := (e.pos + e.visual_offset).distance_to(p)
		if e.hp > 0 and d <= best_d:
			best = e
			best_d = d
	return best


func workers_in_rect(r: Rect2) -> Array[Worker]:
	var result: Array[Worker] = []
	for w in workers:
		if r.has_point(w.pos):
			result.append(w)
	return result


func units_in_rect(r: Rect2) -> Array[Unit]:
	var result: Array[Unit] = []
	for u in units:
		if r.has_point(u.pos):
			result.append(u)
	return result


## L'ouvrier le plus proche qui n'est pas déjà sur un chantier.
func nearest_available_worker(c: Vector2i) -> Worker:
	var target := Vector2(c) + Vector2(0.5, 0.5)
	var best: Worker = null
	var best_score := INF
	for w in workers:
		if w.job == Worker.Job.BUILD or w.job == Worker.Job.REPAIR:
			continue
		var score := w.pos.distance_to(target) + (0.0 if w.state == Worker.State.IDLE else 1000.0)
		if score < best_score:
			best = w
			best_score = score
	return best


# --- Interne ----------------------------------------------------------------

func _spawn_worker(at := Vector2i(-1, -1)) -> Worker:
	var w := Worker.new()
	w.id = _next_id
	_next_id += 1
	var c := at
	if c.x < 0:
		var spots := pathfinder.free_cells_around(grid.base_cells)
		c = spots[(w.id - 1) % spots.size()] if not spots.is_empty() else Vector2i.ZERO
	w.pos = Vector2(c) + Vector2(0.5, 0.5)
	workers.append(w)
	return w


func _move_to_adjacent(w: Worker, targets: Array[Vector2i]) -> void:
	_set_path(w, pathfinder.find_path_to_adjacent(w.cell(), targets))


func _set_path(w: Worker, p: Array[Vector2i]) -> void:
	if p.is_empty():
		_set_idle(w)
		return
	w.path = p
	w.state = Worker.State.MOVING


func _set_idle(w: Worker) -> void:
	w.state = Worker.State.IDLE
	w.job = Worker.Job.NONE
	w.target_site = null
	w.repair_base = false
	w.path.clear()


func _finish_site(s: BuildSite) -> void:
	s.built = true
	s.hp = s.max_hp
	_emit({"type": "built", "pos": s.center()})
	if s.kind == "house":
		pop_cap += Content.HOUSE.pop
		stats.houses_built += 1
	elif s.is_producer():
		s.producer = Producer.new()
	else:
		stats.towers_built += 1
	for w in workers:
		if w.target_site == s:
			_resume_or_idle(w)


## Après un chantier ou une réparation, l'ouvrier retourne à son gisement s'il en avait un.
## Gisement encore exploitable ?
func is_deposit(c: Vector2i) -> bool:
	var t := grid.get_cell(c)
	return (t == GameGrid.Cell.METAL or t == GameGrid.Cell.ESSENCE) and int(deposit_left.get(c, 0)) > 0


func deposit_max(c: Vector2i) -> int:
	return Balance.METAL_PER_DEPOSIT if grid.get_cell(c) == GameGrid.Cell.METAL else Balance.ESSENCE_PER_DEPOSIT


## Gisement épuisé : il disparaît, la case devient praticable.
func _deplete(c: Vector2i) -> void:
	if depleted.has(c):
		return
	var t := grid.get_cell(c)
	grid.metal_deposits.erase(c)
	grid.essence_deposits.erase(c)
	grid.set_cell(c, GameGrid.Cell.EMPTY)
	deposit_left[c] = 0
	pathfinder.set_solid(c, false)
	_flow_dirty = true
	depleted.append(c)
	_emit({"type": "depleted", "pos": Vector2(c) + Vector2(0.5, 0.5), "metal": t == GameGrid.Cell.METAL})
	# Les ouvriers qui allaient vers ce gisement les mains vides en cherchent un autre tout de suite.
	for w in workers:
		if w.job == Worker.Job.HARVEST and w.target_deposit == c and w.carry_amount <= 0 and w.state != Worker.State.HARVESTING:
			_retarget_deposit(w)


## Envoie l'ouvrier vers le gisement du même type le plus proche ; inactif s'il n'y en a plus.
func _retarget_deposit(w: Worker) -> bool:
	var list: Array[Vector2i] = grid.metal_deposits if w.deposit_type != GameGrid.Cell.ESSENCE else grid.essence_deposits
	var from := Vector2(w.target_deposit) if grid.is_inside(w.target_deposit) else w.pos
	var best := Vector2i(-1, -1)
	var bd := INF
	for c in list:
		if is_deposit(c):
			var d := from.distance_squared_to(Vector2(c))
			if d < bd:
				bd = d
				best = c
	if best.x < 0:
		w.target_deposit = Vector2i(-1, -1)
		_set_idle(w)
		return false
	w.target_deposit = best
	w.job = Worker.Job.HARVEST
	_move_to_adjacent(w, [best] as Array[Vector2i])
	return true


func _resume_or_idle(w: Worker) -> void:
	w.repair_base = false
	if is_deposit(w.target_deposit):
		command_harvest([w], w.target_deposit)
	else:
		_set_idle(w)


func boss() -> Enemy:
	for e in enemies:
		if e.is_boss() and e.hp > 0:
			return e
	return null


func worker_by_id(id: int) -> Worker:
	for w in workers:
		if w.id == id:
			return w
	return null


func unit_by_id(id: int) -> Unit:
	for u in units:
		if u.id == id:
			return u
	return null


func enemy_by_id(id: int) -> Enemy:
	for e in enemies:
		if e.id == id:
			return e
	return null


func site_by_id(id: int) -> BuildSite:
	for s in sites:
		if s.id == id:
			return s
	return null
