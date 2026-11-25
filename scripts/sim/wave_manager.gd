class_name WaveManager
extends RefCounted
## Déroulé des vagues : minuterie, composition, apparition progressive des ennemis.
##
## Deux modes :
## - automatique : nombre de vagues, difficulté et intervalle ; la composition grossit à chaque vague ;
## - personnalisé (`plan.mode == "custom"`) : liste de vagues nommées de l'éditeur, chacune avec ses
##   groupes d'ennemis, ses points d'apparition, son lancement (après la précédente, quand elle est
##   éliminée, par un déclencheur ou par un objectif), son comportement et ses répétitions.

const START_LABELS := [["auto", "Après la précédente (délai)"], ["clear", "Quand la précédente est éliminée (+ délai)"],
		["trigger", "Par un déclencheur"], ["objective", "Quand un objectif est réussi (+ délai)"]]
const ORDER_LABELS := [["progressive", "Progressive (l'un après l'autre)"], ["simultaneous", "Simultanée (tous ensemble)"]]
const BEHAVIOR_LABELS := [["base", "Marche sur la base"], ["aggressive", "Chasse les unités"], ["attack_target", "Attaque une cible"],
		["attack_zone", "Attaque une zone"]]
## Ennemis tirés au hasard par le type « Aléatoire ».
const RANDOM_POOL: Array[String] = ["normal", "fast", "armored", "swarmer", "spitter", "shell", "flying"]

var wave := 0 # nombre de vagues lancées
var total := Balance.WAVE_COUNT
var infinite := false
var interval := Balance.WAVE_INTERVAL # secondes entre deux vagues
var difficulty := 1.0 # multiplie le nombre d'ennemis de chaque vague
var timer := Balance.FIRST_WAVE_DELAY
var span := Balance.FIRST_WAVE_DELAY # durée totale du compte à rebours en cours (barre du HUD)
var paused := false # suspendu par un déclencheur
var speed := 1.0 # accéléré par un déclencheur (comptes à rebours et apparitions)
var auto_on := true # vagues lancées seules (sinon seulement par déclencheur)
var left := 0 # ennemis des vagues encore en jeu ou à venir (copie pour le 2e joueur)
var last_id := ""
var net_skip := -1 # coop, 2e joueur : bouton ▶▶ disponible chez l'hôte (-1 = inconnu) # vague personnalisée lancée en dernier

var plan: Array = [] # vagues personnalisées
var _state: Array = [] # par vague : {"n": lancements, "done": bool, "next": temps du prochain lancement}
var _seq: Array[int] = [] # vagues enchaînées automatiquement (lancement "auto" / "clear"), dans l'ordre
var _seq_i := 0
var _wait_clear := false # le compte à rebours attend que la vague précédente soit éliminée
var _prev_tag := 0
var _time := 0.0

var _queue: Array[Dictionary] = []
var _spawn_timer := 0.0
var _spawn_index := 0


## Composition de la wave n (1 = première).
static func composition(n: int) -> Array[String]:
	var list: Array[String] = []
	for i in 2 + n * 2 + n * n / 10:
		list.append("normal")
	if n >= 2:
		for i in n:
			list.insert(mini(list.size(), i * 3 + 1), "fast")
	if n >= 4:
		for i in (n - 2) / 2:
			list.append("armored")
	if n >= 5:
		for i in (n - 3) / 2:
			list.insert(list.size() / 2, "flying")
	# Aliens : nuées rapides, cracheurs à distance, carapaces blindées, brutes, artillerie.
	if n >= 4:
		for i in n / 2:
			list.insert(mini(list.size(), i * 4 + 2), "swarmer")
	if n >= 4:
		for i in (n - 2) / 3:
			list.insert(list.size() / 3, "spitter")
	if n >= 7:
		for i in (n - 5) / 3:
			list.append("shell")
	if n >= 8:
		for i in (n - 6) / 4:
			list.append("brute")
	if n >= 11:
		for i in (n - 9) / 3:
			list.append("siege")
	if n % Balance.BOSS_EVERY == 0:
		# Un boss sur deux est le vaisseau-mère volant.
		var air := (n / Balance.BOSS_EVERY) % 2 == 0
		for i in n / Balance.BOSS_EVERY:
			list.append("mothership" if air and i == 0 else "boss")
	return list


static func is_boss_wave(n: int) -> bool:
	return n > 0 and n % Balance.BOSS_EVERY == 0


## Nouvelle vague personnalisée vide.
static func new_wave(id: String, name: String) -> Dictionary:
	return {"id": id, "name": name, "start": "auto", "delay": 30.0, "objective": "", "order": "progressive", "spacing": Balance.SPAWN_INTERVAL,
			"hp": 1.0, "behavior": "base", "target": -1, "zone": -1, "repeat": 0, "every": 30.0,
			"groups": [{"type": "normal", "count": 6, "spawn": "", "escort": 0, "escort_type": "normal"}]}


## Vagues personnalisées équivalentes au mode automatique (point de départ modifiable).
static func from_auto(count: int, diff: float, gap: float) -> Array:
	var out: Array = []
	for n in range(1, count + 1):
		var w := new_wave("w%d" % n, "Vague %d" % n)
		w.delay = Balance.FIRST_WAVE_DELAY if n == 1 else gap
		w.hp = snappedf(1.0 + Balance.WAVE_HP_GROWTH * (n - 1), 0.01)
		var counts := {}
		var order: Array[String] = []
		for t in composition(n):
			if not counts.has(t):
				order.append(t)
				counts[t] = 0
			counts[t] += 1
		w.groups = []
		for t in order:
			var c: int = counts[t] if Balance.BOSSES.has(t) else maxi(1, roundi(counts[t] * diff))
			w.groups.append({"type": t, "count": c, "spawn": "", "escort": 0, "escort_type": "normal"})
		out.append(w)
	return out


## Mode personnalisé : `p` = {"mode": "custom", "list": [...]} (sinon rien ne change).
func setup_plan(p: Dictionary) -> void:
	if str(p.get("mode", "auto")) != "custom" or p.get("list", []).is_empty():
		return
	plan = p.list.duplicate(true)
	total = 0
	for i in plan.size():
		var d: Dictionary = plan[i]
		_state.append({"n": 0, "done": false, "next": INF})
		if str(d.get("start", "auto")) in ["auto", "clear"]:
			_seq.append(i)
			# Le total affiché compte les vagues enchaînées ; celles sur événement s'y ajoutent quand elles partent.
			total += 1 + maxi(0, int(d.get("repeat", 0)))
	_arm_seq()


func custom() -> bool:
	return not plan.is_empty()


func tick(delta: float, world: GameWorld) -> void:
	var dt := 0.0 if paused else delta * speed
	_time += dt
	if not _queue.is_empty():
		_spawn_timer -= dt
		while not _queue.is_empty() and _spawn_timer <= 0.0:
			var q: Dictionary = _queue.pop_front()
			_spawn(q, world)
			_spawn_timer += float(q.gap)
	if _queue.is_empty():
		_spawn_timer = 0.0
	if custom():
		_tick_custom(dt, world)
	elif has_more_waves() and not paused:
		timer -= delta * speed
		if timer <= 0.0:
			start_next()
	left = _queue.size() + world.enemies.filter(func(e: Enemy) -> bool: return e.wave_no > 0 and e.hp > 0).size()


func _tick_custom(dt: float, world: GameWorld) -> void:
	# Répétitions et vagues lancées par un objectif.
	for i in plan.size():
		var st: Dictionary = _state[i]
		if st.done:
			continue
		if str(plan[i].get("start", "")) == "objective" and st.n == 0 and st.next == INF and world.scenario != null:
			var oid := str(plan[i].get("objective", ""))
			if world.scenario.objectives.any(func(o: Dictionary) -> bool: return str(o.def.id) == oid and o.state == "done"):
				st.next = _time + float(plan[i].get("delay", 0.0))
		if _time >= float(st.next):
			launch(i)
	# Enchaînement automatique.
	if not auto_on or paused:
		return
	if _seq_i >= _seq.size():
		if infinite and timer != INF:
			timer -= dt
			if timer <= 0.0:
				_launch_generated()
		return
	if _wait_clear:
		if _alive_tag(world, _prev_tag) > 0:
			return
		_wait_clear = false
	timer -= dt
	if timer <= 0.0:
		launch(_seq[_seq_i])


func _alive_tag(world: GameWorld, tag: int) -> int:
	return _queue.filter(func(q: Dictionary) -> bool: return q.tag == tag).size() \
			+ world.enemies.filter(func(e: Enemy) -> bool: return e.wave_no == tag and e.hp > 0).size()


## Prépare le compte à rebours de la prochaine vague enchaînée.
func _arm_seq() -> void:
	if _seq_i >= _seq.size():
		timer = interval if infinite else INF
		span = interval
		return
	var d: Dictionary = plan[_seq[_seq_i]]
	timer = maxf(0.0, float(d.get("delay", 0.0)))
	span = maxf(timer, 0.1)
	_wait_clear = str(d.get("start", "auto")) == "clear" and wave > 0


## Lance la vague personnalisée d'indice i (et programme sa répétition).
func launch(i: int) -> void:
	if i < 0 or i >= plan.size() or _state[i].done:
		return
	var d: Dictionary = plan[i]
	var st: Dictionary = _state[i]
	wave += 1
	total = maxi(total, wave)
	_queue_ids[wave] = i
	last_id = str(d.get("id", ""))
	_prev_tag = wave
	st.n += 1
	st.next = INF
	if st.n > maxi(0, int(d.get("repeat", 0))):
		st.done = true
	else:
		st.next = _time + maxf(1.0, float(d.get("every", 30.0)))
	var gap := 0.05 if str(d.get("order", "progressive")) == "simultaneous" else maxf(0.05, float(d.get("spacing", Balance.SPAWN_INTERVAL)))
	var base := {"tag": wave, "hp": float(d.get("hp", 1.0)), "beh": str(d.get("behavior", "base")),
			"target": int(d.get("target", -1)), "zone": int(d.get("zone", -1)), "gap": gap}
	for g: Dictionary in d.get("groups", []):
		var cell: Variant = _parse_cell(str(g.get("spawn", "")))
		for k in maxi(0, int(g.get("count", 0))):
			_push(base, str(g.get("type", "normal")), cell)
			for x in maxi(0, int(g.get("escort", 0))):
				_push(base, str(g.get("escort_type", "normal")), cell, 0.05)
	if _seq_i < _seq.size() and _seq[_seq_i] == i:
		_seq_i += 1
		_arm_seq()
	elif _seq.has(i) and _seq.find(i) > _seq_i:
		# Lancée en avance par un déclencheur : l'enchaînement la saute.
		_seq.erase(i)
		_arm_seq()


func _push(base: Dictionary, type: String, cell: Variant, gap := -1.0) -> void:
	var q := base.duplicate()
	q.t = type
	q.cell = cell
	if gap >= 0.0:
		q.gap = gap
	_queue.append(q)


static func _parse_cell(key: String) -> Variant:
	var p := key.split(",")
	if p.size() != 2 or not p[0].is_valid_int() or not p[1].is_valid_int():
		return null
	return Vector2i(int(p[0]), int(p[1]))


func _spawn(q: Dictionary, world: GameWorld) -> void:
	var spawns := world.grid.spawn_points
	var cell: Variant = q.get("cell")
	if cell == null or not spawns.has(cell):
		if spawns.is_empty():
			return
		cell = spawns[_spawn_index % spawns.size()]
		_spawn_index += 1
	var t := str(q.t)
	if t == "random":
		t = RANDOM_POOL[world._rng.randi() % RANDOM_POOL.size()]
	if not Balance.ENEMIES.has(t):
		t = "normal"
	var e := world.spawn_enemy(t, cell, float(q.hp))
	e.wave_no = int(q.tag)
	e.home = e.pos
	match str(q.get("beh", "base")):
		"aggressive":
			e.mode = "aggressive"
			e.guard_pos = e.pos
		"attack_target":
			if int(q.target) >= 0:
				e.mode = "attack_target"
				e.target_eid = int(q.target)
		"attack_zone":
			var z: Dictionary = world.scenario.zone(int(q.zone)) if world.scenario != null else {}
			if not z.is_empty():
				e.mode = "attack_zone"
				e.goal_pos = z.pos


## Vague suivante : bouton ▶▶ et action « Lancer une vague » sans vague précise.
func start_next() -> void:
	if custom():
		if _seq_i < _seq.size():
			launch(_seq[_seq_i])
		elif infinite:
			_launch_generated()
		return
	if not has_more_waves():
		return
	wave += 1
	var list := composition(wave)
	var bosses := list.filter(func(t: String) -> bool: return Balance.BOSSES.has(t))
	list = list.filter(func(t: String) -> bool: return not Balance.BOSSES.has(t))
	var keep := maxi(2, roundi(list.size() * difficulty))
	# On retire des ennemis répartis dans la liste pour garder le mélange des types.
	while list.size() > keep:
		list.remove_at(list.size() * 2 / 3 if list.size() > 2 else 0)
	var base_count := list.size()
	var i := 0
	while list.size() < keep and base_count > 0:
		# Difficulté > 1 : on ajoute des renforts copiés de la vague, répartis dans la file.
		list.insert(mini(list.size(), i * 2 + 1), list[i % base_count])
		i += 1
	list.append_array(bosses) # le boss arrive en dernier
	var base := {"tag": wave, "hp": hp_scale(), "beh": "base", "target": -1, "zone": -1, "gap": Balance.SPAWN_INTERVAL}
	for t in list:
		_push(base, t, null)
	timer = interval
	span = interval


## Après la liste personnalisée, en mode infini : vagues générées comme en automatique.
func _launch_generated() -> void:
	wave += 1
	var base := {"tag": wave, "hp": hp_scale(), "beh": "base", "target": -1, "zone": -1, "gap": Balance.SPAWN_INTERVAL}
	for t in composition(wave):
		_push(base, t, null)
	timer = interval
	span = interval


## Lance une vague par son identifiant ("" = la suivante).
func launch_id(id: String) -> void:
	if id == "":
		start_next()
		return
	for i in plan.size():
		if str(plan[i].get("id", "")) == id:
			if _state[i].done:
				# Une vague déjà terminée peut être relancée par un déclencheur.
				_state[i].done = false
				_state[i].n = 0
			launch(i)
			return


## Arrête une vague (ennemis pas encore apparus annulés, répétitions annulées), ou toutes ("").
func stop(id: String) -> void:
	if id == "":
		_queue.clear()
		for st in _state:
			st.done = true
		_seq_i = _seq.size()
		timer = INF
		infinite = false
		if not custom():
			total = wave
		return
	for i in plan.size():
		if str(plan[i].get("id", "")) == id:
			_state[i].done = true
			_state[i].next = INF
			_queue = _queue.filter(func(q: Dictionary) -> bool: return not _tag_of(i, int(q.tag)))
			if _seq_i < _seq.size() and _seq[_seq_i] == i:
				_seq_i += 1
				_arm_seq()
			else:
				_seq.erase(i)


func _tag_of(i: int, tag: int) -> bool:
	# Les ennemis en file portent le numéro de vague ; on retrouve la vague par son dernier lancement.
	return _queue_ids.get(tag, -1) == i


var _queue_ids := {} # numéro de vague -> indice de la vague personnalisée


## Identifiant de la vague personnalisée lancée sous ce numéro ("" en automatique).
func id_of(n: int) -> String:
	var i: int = _queue_ids.get(n, -1)
	return str(plan[i].get("id", "")) if i >= 0 else ""


## Numéros des vagues dont des ennemis sont en jeu ou à venir.
func live_tags(world: GameWorld) -> Dictionary:
	var out := {}
	for q in _queue:
		out[int(q.tag)] = true
	for e in world.enemies:
		if e.wave_no > 0 and e.hp > 0:
			out[e.wave_no] = true
	return out


func has_more_waves() -> bool:
	if custom():
		return infinite or _seq_i < _seq.size() or _state.any(func(st: Dictionary) -> bool: return not st.done and st.next != INF)
	return infinite or wave < total


## Il reste une vague que le bouton ▶▶ peut lancer.
func can_skip() -> bool:
	if net_skip >= 0:
		return net_skip == 1
	return (_seq_i < _seq.size() or infinite) if custom() else has_more_waves()


func hp_scale() -> float:
	return 1.0 + Balance.WAVE_HP_GROWTH * (wave - 1)


func queue_empty() -> bool:
	return _queue.is_empty()


## Toutes les waves de la map ont été envoyées.
func finished() -> bool:
	return not has_more_waves() and _queue.is_empty()
