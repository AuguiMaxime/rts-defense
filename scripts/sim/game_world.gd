class_name GameWorld
extends RefCounted
## État complet d'une partie et ses règles. Avancé par tick(delta).
## Aucune dépendance à l'affichage : c'est ce bloc qui tournera sur le serveur en multi.

enum State { PLAYING, WON, LOST }

var grid: GameGrid
var pathfinder: Pathfinder
var flow: FlowField
var waves: WaveManager
var state := State.PLAYING
var base_hp := Balance.BASE_HP
var enemies: Array[Enemy] = []
var kills := 0
## Événements visuels (tirs, destructions) que l'affichage récupère avec take_events().
var events: Array[Dictionary] = []
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
var sites: Array[BuildSite] = []
var train_queue := 0
var train_timer := 0.0

var _next_id := 1
var _flow_dirty := true
var _base_rect := Rect2()
var _rng := RandomNumberGenerator.new()


## config (optionnel) : start_metal, start_workers, base_hp, damage_mult, worker_speed_mult,
## carry_bonus, orbital (bool), waves (nombre de vagues), difficulty, laser (bool).
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
	_rng.seed = 12345 # déterministe : même partie sur tous les appareils en multi
	if not g.base_cells.is_empty():
		_base_rect = Rect2(Vector2(g.base_cells[0]), Vector2.ONE)
		for c in g.base_cells:
			_base_rect = _base_rect.merge(Rect2(Vector2(c), Vector2.ONE))
	waves.total = config.get("waves", Balance.WAVE_COUNT)
	waves.difficulty = config.get("difficulty", 1.0)
	for i in config.get("start_workers", Balance.START_WORKERS):
		_spawn_worker()


# --- Avancement du temps -------------------------------------------------

func tick(delta: float) -> void:
	if state != State.PLAYING:
		return
	waves.tick(delta, self)
	if orbital_cooldown > 0.0:
		orbital_cooldown = maxf(0.0, orbital_cooldown - delta)
	if _flow_dirty:
		flow.rebuild()
		_flow_dirty = false
	if train_queue > 0:
		train_timer += delta
		if train_timer >= Balance.WORKER_TRAIN_TIME:
			train_timer = 0.0
			train_queue -= 1
			_spawn_worker()
	for w in workers:
		_tick_worker(w, delta)
	for s in sites:
		if s.built and s.is_tower():
			_tick_tower(s, delta)
	for e in enemies:
		_tick_enemy(e, delta)
	_remove_dead()
	if base_hp <= 0:
		base_hp = 0
		state = State.LOST
	elif waves.finished() and enemies.is_empty():
		state = State.WON


## Reprend la partie après une victoire, en waves infinies.
func continue_infinite() -> void:
	waves.infinite = true
	waves.timer = Balance.WAVE_INTERVAL
	state = State.PLAYING


func take_events() -> Array[Dictionary]:
	var e := events
	events = []
	return e


func spawn_enemy(type_name: String, cell: Vector2i, hp_scale: float) -> void:
	var at := Vector2(cell) + Vector2(0.5, 0.5) + Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
	var e := Enemy.create(type_name, at, hp_scale)
	e.visual_offset = Vector2(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.2, 0.2))
	enemies.append(e)


func base_center() -> Vector2:
	return _base_rect.get_center()


# --- Combat ---------------------------------------------------------------------

func _tick_tower(s: BuildSite, delta: float) -> void:
	var st := s.stats()
	s.cooldown -= delta
	var center := Vector2(s.cell) + Vector2(0.5, 0.5)
	var best: Enemy = null
	var best_d: float = st.range
	for e in enemies:
		if e.hp <= 0:
			continue
		if (st.targets == "air" and not e.flying) or (st.targets == "ground" and e.flying):
			continue
		var d := center.distance_to(e.pos)
		if d <= best_d:
			best = e
			best_d = d
	s.beam_target = best if s.kind == "laser" else null
	if best == null:
		return
	s.aim_angle = (best.pos - center).angle()
	if s.cooldown > 0.0:
		return
	s.cooldown = st.delay
	var dmg := roundi(st.damage * damage_mult)
	if st.splash > 0.0:
		for e in enemies:
			if e.hp > 0 and not e.flying and e.pos.distance_to(best.pos) <= st.splash:
				_damage_enemy(e, dmg)
	else:
		_damage_enemy(best, dmg)
	if s.kind != "laser":
		events.append({"type": "shot", "kind": s.kind, "from": center, "to": best.pos})


func _damage_enemy(e: Enemy, amount: int) -> void:
	if e.hp <= 0:
		return
	e.hp -= maxi(1, amount - e.armor)
	if e.hp <= 0:
		kills += 1
		events.append({"type": "death", "pos": e.pos, "big": e.type == "armored"})


func _tick_enemy(e: Enemy, delta: float) -> void:
	if e.hp <= 0:
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
	e.pos += dir * e.speed * delta


## Cible la plus proche à portée : ouvrier, chantier, tourelle ou base.
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
	for s in sites:
		d = _dist_to_rect(e.pos, Rect2(Vector2(s.cell), Vector2.ONE))
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
			return e.pos.distance_to(w.pos) - 0.3 if workers.has(w) else INF
		Enemy.Target.SITE:
			var s: BuildSite = e.target_ref
			return _dist_to_rect(e.pos, Rect2(Vector2(s.cell), Vector2.ONE)) if sites.has(s) else INF
	return INF


func _enemy_attack(e: Enemy) -> void:
	var to := base_center()
	match e.target_kind:
		Enemy.Target.BASE:
			base_hp -= e.damage
		Enemy.Target.WORKER:
			var w: Worker = e.target_ref
			w.hp -= e.damage
			to = w.pos
		Enemy.Target.SITE:
			var s: BuildSite = e.target_ref
			s.hp -= e.damage
			to = Vector2(s.cell) + Vector2(0.5, 0.5)
	events.append({"type": "hit", "from": e.pos, "to": to, "ranged": e.attack_range > 1.5})


func _remove_dead() -> void:
	enemies = enemies.filter(func(e: Enemy) -> bool: return e.hp > 0)
	for w in workers.duplicate():
		if w.hp <= 0:
			workers.erase(w)
			events.append({"type": "death", "pos": w.pos, "big": false})
	for s in sites.duplicate():
		if s.hp <= 0:
			sites.erase(s)
			if s.built and s.kind == "house":
				pop_cap -= Content.HOUSE.pop
			pathfinder.set_solid(s.cell, false)
			_flow_dirty = true
			events.append({"type": "death", "pos": Vector2(s.cell) + Vector2(0.5, 0.5), "big": true})
			for w in workers:
				if w.target_site == s:
					_resume_or_idle(w)


static func _dist_to_rect(p: Vector2, r: Rect2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_to(q)


func _tick_worker(w: Worker, delta: float) -> void:
	match w.state:
		Worker.State.MOVING:
			if _follow_path(w, delta):
				_on_arrived(w)
		Worker.State.HARVESTING:
			w.timer -= delta
			if w.timer <= 0.0:
				w.carry_type = grid.get_cell(w.target_deposit)
				w.carry_amount = Balance.CARRY_CAPACITY + carry_bonus
				_move_to_adjacent(w, grid.base_cells)
		Worker.State.BUILDING:
			var s := w.target_site
			if s == null or s.built or not sites.has(s):
				_set_idle(w)
				return
			s.work_done += delta
			if s.work_done >= s.work_needed:
				_finish_site(s)
		Worker.State.REPAIRING:
			var s := w.target_site
			if s == null or not sites.has(s) or s.hp >= s.max_hp:
				_set_idle(w)
				return
			s.hp = mini(s.max_hp, s.hp + ceili(Balance.REPAIR_RATE * delta))
			if s.hp >= s.max_hp:
				_resume_or_idle(w)


func _follow_path(w: Worker, delta: float) -> bool:
	var step := Balance.WORKER_SPEED * worker_speed_mult * delta
	while step > 0.0 and not w.path.is_empty():
		var target := Vector2(w.path[0]) + Vector2(0.5, 0.5)
		var d := w.pos.distance_to(target)
		if d > 0.001:
			w.facing = (target - w.pos) / d
		if d <= step:
			w.pos = target
			step -= d
			w.path.remove_at(0)
		else:
			w.pos += (target - w.pos) / d * step
			step = 0.0
	return w.path.is_empty()


func _on_arrived(w: Worker) -> void:
	match w.job:
		Worker.Job.HARVEST:
			if w.carry_amount > 0:
				_deposit(w)
				_move_to_adjacent(w, [w.target_deposit] as Array[Vector2i])
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
	elif w.carry_type == GameGrid.Cell.ESSENCE:
		essence += w.carry_amount
	w.carry_amount = 0
	w.carry_type = -1


# --- Ordres du joueur ---------------------------------------------------------

## Raison du refus, ou "" si on peut former un ouvrier.
func can_train_worker() -> String:
	if workers.size() + train_queue >= pop_cap:
		return "Population max atteinte : construis un habitat"
	if metal < Balance.WORKER_COST_METAL:
		return "Pas assez de métal (%d)" % Balance.WORKER_COST_METAL
	return ""


func train_worker() -> bool:
	if can_train_worker() != "":
		return false
	metal -= Balance.WORKER_COST_METAL
	train_queue += 1
	return true


func command_move(ws: Array, c: Vector2i) -> void:
	for w: Worker in ws:
		if w == null:
			continue
		w.job = Worker.Job.NONE
		w.target_site = null
		w.target_deposit = Vector2i(-1, -1)
		if pathfinder.is_free(c):
			_set_path(w, pathfinder.find_path(w.cell(), c))
		else:
			_move_to_adjacent(w, [c] as Array[Vector2i])


func command_harvest(ws: Array, deposit: Vector2i) -> void:
	for w: Worker in ws:
		if w == null:
			continue
		w.job = Worker.Job.HARVEST
		w.target_site = null
		w.target_deposit = deposit
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
		_move_to_adjacent(w, [site.cell] as Array[Vector2i])


func command_repair(ws: Array, site: BuildSite) -> void:
	for w: Worker in ws:
		if w == null:
			continue
		w.job = Worker.Job.REPAIR
		w.target_site = site
		_move_to_adjacent(w, [site.cell] as Array[Vector2i])


## Raison du refus, ou "" si le bâtiment peut être posé.
func can_place(kind: String, c: Vector2i) -> String:
	if kind == "laser" and not laser_unlocked:
		return "Laser à débloquer dans la boutique"
	var cost := Content.building(kind)
	if not grid.is_inside(c):
		return "Hors de la map"
	if grid.get_cell(c) != GameGrid.Cell.EMPTY or site_at(c) != null:
		return "Case occupée"
	if metal < cost.metal:
		return "Pas assez de métal (%d)" % cost.metal
	if essence < cost.essence:
		return "Pas assez d'essence (%d)" % cost.essence
	pathfinder.set_solid(c, true)
	var open := enemies_can_reach_base()
	pathfinder.set_solid(c, false)
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
	s.cell = c
	if kind == "house":
		s.work_needed = Balance.HOUSE_BUILD_WORK
	sites.append(s)
	pathfinder.set_solid(c, true)
	_flow_dirty = true
	for w in workers:
		if w.state == Worker.State.MOVING and w.path.has(c):
			_set_path(w, pathfinder.find_path(w.cell(), w.path.back()))
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
	s.max_hp = s.stats().hp
	s.hp += s.max_hp - old_max
	events.append({"type": "built", "pos": Vector2(s.cell) + Vector2(0.5, 0.5)})
	return true


func sell(s: BuildSite) -> void:
	if not sites.has(s):
		return
	var refund := s.sell_value()
	metal += refund.metal
	essence += refund.essence
	sites.erase(s)
	if s.built and s.kind == "house":
		pop_cap -= Content.HOUSE.pop
	pathfinder.set_solid(s.cell, false)
	_flow_dirty = true
	for w in workers:
		if w.target_site == s:
			_resume_or_idle(w)


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
	events.append({"type": "orbital", "pos": at})
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
		if s.cell == c:
			return s
	return null


func worker_at(p: Vector2, radius := 0.5) -> Worker:
	var best: Worker = null
	var best_d := radius
	for w in workers:
		var d := w.pos.distance_to(p)
		if d <= best_d:
			best = w
			best_d = d
	return best


func workers_in_rect(r: Rect2) -> Array[Worker]:
	var result: Array[Worker] = []
	for w in workers:
		if r.has_point(w.pos):
			result.append(w)
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

func _spawn_worker() -> void:
	var w := Worker.new()
	w.id = _next_id
	_next_id += 1
	var spots := pathfinder.free_cells_around(grid.base_cells)
	var c := spots[(w.id - 1) % spots.size()] if not spots.is_empty() else Vector2i.ZERO
	w.pos = Vector2(c) + Vector2(0.5, 0.5)
	workers.append(w)


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
	w.path.clear()


func _finish_site(s: BuildSite) -> void:
	s.built = true
	s.hp = s.max_hp
	events.append({"type": "built", "pos": Vector2(s.cell) + Vector2(0.5, 0.5)})
	if s.kind == "house":
		pop_cap += Content.HOUSE.pop
	for w in workers:
		if w.target_site == s:
			_resume_or_idle(w)


## Après un chantier ou une réparation, l'ouvrier retourne à son gisement s'il en avait un.
func _resume_or_idle(w: Worker) -> void:
	if grid.is_inside(w.target_deposit):
		command_harvest([w], w.target_deposit)
	else:
		_set_idle(w)
