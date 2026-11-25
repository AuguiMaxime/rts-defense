class_name Scenario
extends RefCounted
## Moteur de scénario : objectifs, déclencheurs QUAND / SI / ALORS / SINON, variables, chronos.
## Tourne chez l'hôte. Les événements sont détectés en comparant l'état du monde d'un tick à l'autre.
##
## Données (fichier de mission, section "scenario") :
##   objectives : [{id, name, desc, kind (main/secondary/optional), start (visible/hidden/after), after:[ids],
##                  type, …paramètres du type, deadline, fail_dead:[eid], reward:{metal, essence}}]
##   triggers   : [{id, name, enabled, once, priority, delay, event:{type,…}, cond:{op, items:[…]}, actions:[…], else:[…]}]
##   variables  : [{name, type, value}]
##   rules      : {victory: "objectives"|"manual", defeat_base: bool, defeat_main_failed: bool}

const MAX_ACTIONS_PER_TICK := 300
const MAX_FIRES_PER_SECOND := 20
const LOG_SIZE := 300

var data := {}
var w: GameWorld
var objectives: Array[Dictionary] = [] # {def, state, t0, cur, need, text, hold}
var triggers: Array[Dictionary] = [] # {def, enabled, fires, window, next_every}
var vars := {}
var timers := {} # nom -> {left, label, show}
var markers: Array[Dictionary] = [] # {pos, text, until}
var log: Array[String] = []
var forced := "" # "won" / "lost" imposé par une action
var end_text := ""
var _running: Array[Dictionary] = [] # séquences d'actions : {actions, i, wait, name}
var _queue: Array[Dictionary] = []
var _started := false
var _prev := {}
var _actions_this_tick := 0


func _init(d: Dictionary = {}) -> void:
	data = d if d != null else {}


func has_content() -> bool:
	return not data.get("objectives", []).is_empty() or not data.get("triggers", []).is_empty()


## Après une victoire, la partie peut continuer en vagues infinies : plus de nouvelle victoire.
var endless := false


func _rules() -> Dictionary:
	return data.get("rules", {})


func defeat_on_base() -> bool:
	return bool(_rules().get("defeat_base", true))


func setup(world: GameWorld) -> void:
	w = world
	for v: Dictionary in data.get("variables", []):
		vars[str(v.name)] = _typed(v.get("type", "int"), v.get("value", 0))
	for o: Dictionary in data.get("objectives", []):
		var st := "active" if str(o.get("start", "visible")) == "visible" else "hidden"
		objectives.append({"def": o, "state": st, "t0": 0.0, "cur": 0, "need": 0, "text": "", "hold": 0.0, "step": 0, "ids": {}})
	var list: Array = data.get("triggers", []).duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	for t: Dictionary in list:
		triggers.append({"def": t, "enabled": bool(t.get("enabled", true)), "fires": 0, "window": 0.0, "count": 0,
				"next_every": float(t.event.get("seconds", 30.0)) if t.event.get("type", "") == "every" else INF})


static func _typed(t: String, v: Variant) -> Variant:
	match t:
		"int":
			return int(v)
		"float":
			return float(v)
		"bool":
			return bool(v) if not v is String else v == "true"
		"ref":
			return int(v)
	return str(v)


func _log(text: String) -> void:
	log.append("%5.1f s  %s" % [w.time, text])
	if log.size() > LOG_SIZE:
		log.pop_front()


# =============================================================================================
# Tick
# =============================================================================================

func tick(delta: float) -> void:
	_actions_this_tick = 0
	if not _started:
		_started = true
		_queue.append({"type": "start"})
		for o in objectives:
			if o.state == "active":
				_activate(o, false)
	_detect()
	# Chronos
	for name in timers.keys():
		var t: Dictionary = timers[name]
		t.left = float(t.left) - delta
		if t.left <= 0.0:
			timers.erase(name)
			_queue.append({"type": "timer_end", "timer": name})
	markers = markers.filter(func(m: Dictionary) -> bool: return float(m.until) <= 0.0 or float(m.until) > w.time)
	_tick_objectives(delta)
	# Événements de temps
	for tr in triggers:
		var ev: Dictionary = tr.def.event
		if not tr.enabled:
			continue
		match str(ev.get("type", "")):
			"time":
				if tr.count == 0 and w.time >= float(ev.get("seconds", 0.0)):
					_fire(tr, {"type": "time"})
			"every":
				if w.time >= tr.next_every:
					tr.next_every = w.time + maxf(0.5, float(ev.get("seconds", 30.0)))
					_fire(tr, {"type": "every"})
	# Événements détectés (un événement provoqué par une action est traité au tick suivant :
	# une boucle de déclencheurs ne bloque jamais le jeu).
	var batch := _queue
	_queue = []
	for ev in batch:
		for tr in triggers:
			if tr.enabled and _matches(tr.def.event, ev):
				_fire(tr, ev)
	_run_sequences(delta)
	for tr in triggers:
		tr.window = maxf(0.0, float(tr.window) - delta)


## Lance un déclencheur : vérifie ses conditions, puis ALORS ou SINON.
func _fire(tr: Dictionary, ev: Dictionary) -> void:
	if tr.window > 0.0 and tr.fires >= MAX_FIRES_PER_SECOND:
		if tr.fires == MAX_FIRES_PER_SECOND:
			_log("⚠ « %s » se déclenche trop souvent : mis en pause 1 s" % tr.def.name)
			tr.fires += 1
		return
	if tr.window <= 0.0:
		tr.window = 1.0
		tr.fires = 0
	tr.fires += 1
	tr.count += 1
	if tr.def.get("once", true):
		tr.enabled = false
	var ok := eval_cond(tr.def.get("cond", {}), ev)
	var list: Array = tr.def.get("actions", []) if ok else tr.def.get("else", [])
	_log("▶ %s%s" % [tr.def.name, "" if ok else " (SINON)"])
	if list.is_empty():
		return
	var seq := {"actions": list, "i": 0, "wait": float(tr.def.get("delay", 0.0)), "name": tr.def.name, "ev": ev}
	_running.append(seq)


## Force un déclencheur (outils de test, action « Exécuter un déclencheur »).
func run_trigger(id: String, skip_cond := false) -> void:
	for tr in triggers:
		if tr.def.id == id:
			if skip_cond:
				_log("▶ %s (forcé)" % tr.def.name)
				_running.append({"actions": tr.def.get("actions", []), "i": 0, "wait": 0.0, "name": tr.def.name, "ev": {}})
			else:
				_fire(tr, {"type": "forced"})


func _run_sequences(delta: float) -> void:
	var i := 0
	while i < _running.size():
		var seq: Dictionary = _running[i]
		if seq.wait > 0.0:
			seq.wait = float(seq.wait) - delta
			if seq.wait > 0.0:
				i += 1
				continue
		while seq.i < seq.actions.size() and _actions_this_tick < MAX_ACTIONS_PER_TICK:
			var a: Dictionary = seq.actions[seq.i]
			seq.i += 1
			_actions_this_tick += 1
			if a.get("type", "") == "wait":
				seq.wait = float(a.get("seconds", 1.0))
				break
			execute(a, seq.ev)
		if seq.i >= seq.actions.size() and seq.wait <= 0.0:
			_running.remove_at(i)
		else:
			i += 1


# =============================================================================================
# Détection des événements (différences d'un tick à l'autre)
# =============================================================================================

func _detect() -> void:
	var p := _prev
	var cur := {}
	for ch: Array in w.factions.pending:
		_queue.append({"type": "relation_changed", "a": ch[0], "b": ch[1], "rel": ch[2]})
		_log("relation %s / %s : %s" % [w.factions.name_of(ch[0]), w.factions.name_of(ch[1]), ch[2]])
	w.factions.pending.clear()
	# Morts / créations
	var alive := {}
	var created: Array[Dictionary] = []
	for e in w.enemies:
		if e.neutral:
			continue
		alive["e%d" % e.id] = e
		if p.has("alive") and not p.alive.has("e%d" % e.id):
			created.append({"type": "created", "team": "enemy"})
			if e.is_boss():
				_queue.append({"type": "boss_spawned"})
	for u in w.units:
		if u.alive:
			alive["u%d" % u.id] = u
			if p.has("alive") and not p.alive.has("u%d" % u.id):
				created.append({"type": "created", "team": "player"})
	for s in w.sites:
		if s.alive:
			alive["s%d" % s.id] = s
	if p.has("alive"):
		for k in p.alive:
			if alive.has(k):
				continue
			var o: Variant = p.alive[k]
			var dead := false
			var team := "enemy"
			var eid := -1
			var boss := false
			var building := false
			if o is Enemy:
				dead = (o as Enemy).hp <= 0
				eid = (o as Enemy).eid
				boss = (o as Enemy).is_boss()
			elif o is Unit:
				dead = (o as Unit).hp <= 0
				eid = (o as Unit).eid
				team = "player"
			elif o is BuildSite:
				dead = (o as BuildSite).hp <= 0
				eid = (o as BuildSite).eid
				team = "player"
				building = true
			if not dead:
				continue
			_queue.append({"type": "killed", "team": team, "eid": eid})
			if boss:
				_queue.append({"type": "boss_killed"})
			if building:
				_queue.append({"type": "building_destroyed", "eid": eid})
	_queue.append_array(created)
	cur.alive = alive
	# Bâtiments terminés
	var built := {}
	for s in w.sites:
		if s.alive and s.built:
			built[s.id] = true
			if p.has("built") and not p.built.has(s.id):
				_queue.append({"type": "building_built", "kind": "tower" if s.is_tower() else "building", "eid": s.eid})
	cur.built = built
	# Zones : entrées, sorties, contrôle
	var inside := {}
	var control := {}
	for z in w.mission.zones:
		var r2: float = z.radius * z.radius
		var set := {}
		var nmine := 0
		var ntheirs := 0
		for u in w.units:
			if u.alive and u.pos.distance_squared_to(z.pos) <= r2:
				set["u%d" % u.id] = [u.eid, "vip" if u.vip else "player"]
				if not u.locked:
					nmine += 1
		for e in w.enemies:
			if e.hp > 0 and not e.neutral and e.pos.distance_squared_to(z.pos) <= r2:
				set["e%d" % e.id] = [e.eid, "enemy"]
				ntheirs += 1
		var zk: int = z.eid
		inside[zk] = set
		control[zk] = nmine > 0 and ntheirs == 0
		if p.has("inside"):
			var before: Dictionary = p.inside.get(zk, {})
			for k in set:
				if not before.has(k):
					_queue.append({"type": "enter_zone", "zone": zk, "eid": set[k][0], "team": set[k][1]})
					if set[k][1] == "vip":
						_queue.append({"type": "vip_arrived", "zone": zk})
			for k in before:
				if not set.has(k):
					_queue.append({"type": "leave_zone", "zone": zk, "eid": before[k][0], "team": before[k][1]})
			var was: bool = p.control.get(zk, false)
			if control[zk] and not was:
				_queue.append({"type": "zone_captured", "zone": zk})
			elif was and not control[zk]:
				_queue.append({"type": "zone_lost", "zone": zk})
	cur.inside = inside
	cur.control = control
	# Vagues
	var wave := w.waves.wave
	if p.has("wave"):
		for n in range(int(p.wave) + 1, wave + 1):
			_queue.append({"type": "wave_started", "n": n, "id": w.waves.id_of(n)})
	cur.wave = wave
	var marching := w.enemies.any(func(e: Enemy) -> bool: return e.hp > 0 and not e.neutral and e.mode == "march")
	var wave_live := wave > 0 and (marching or not w.waves.queue_empty())
	cur.wave_live = wave_live
	# Une vague est éliminée quand plus aucun de ses ennemis n'est en jeu ni à venir.
	var tags := w.waves.live_tags(w)
	for t in p.get("tags", {}):
		if not tags.has(t):
			_queue.append({"type": "wave_ended", "n": t, "id": w.waves.id_of(t)})
	cur.tags = tags
	# Convois, VIP
	var arrived := 0
	var lost := 0
	for c in w.mission.convoys:
		if c.state == "arrived":
			arrived += 1
		elif c.state == "dead":
			lost += 1
	var foes_done := w.objectives.filter(func(o: Dictionary) -> bool: return o.state == "done").size()
	if p.has("arrived"):
		for i in arrived - int(p.arrived):
			_queue.append({"type": "convoy_arrived"})
		for i in (lost - int(p.lost)) + (foes_done - int(p.foes_done)):
			_queue.append({"type": "convoy_destroyed"})
	cur.arrived = arrived
	cur.lost = lost
	cur.foes_done = foes_done
	var vip_alive := w.mission.vip != null and w.mission.vip.alive
	if p.get("vip_alive", false) and not vip_alive:
		_queue.append({"type": "vip_killed"})
	cur.vip_alive = vip_alive
	# Objets interactifs
	var inter := {}
	for d in w.mission.doors:
		inter[d.eid] = d.open
	for t in w.mission.terminals:
		inter[t.eid] = t.done
	for q in w.mission.prisoners:
		inter[q.eid] = q.freed
	for k in w.mission.pickups:
		inter[k.eid] = k.taken
	if p.has("inter"):
		for eid in inter:
			if inter[eid] and not p.inter.get(eid, false):
				_queue.append({"type": "interaction", "eid": eid})
	cur.inter = inter
	# Base
	if w.base_hp <= 0 and not p.get("base_dead", false):
		_queue.append({"type": "base_destroyed"})
	cur.base_dead = w.base_hp <= 0
	# Objets repérés : une unité du joueur à moins de X cases
	for tr in triggers:
		var ev: Dictionary = tr.def.event
		if tr.enabled and ev.get("type", "") == "spotted":
			var o: Variant = obj(ev.get("obj", -1))
			if o != null:
				var r := float(ev.get("radius", 6.0))
				var pos := GameWorld.obj_pos(o)
				if w.units.any(func(u: Unit) -> bool: return u.alive and not u.locked and u.pos.distance_to(pos) <= r):
					_queue.append({"type": "spotted", "eid": int(ev.get("obj", -1))})
	_prev = cur


func _matches(ev: Dictionary, got: Dictionary) -> bool:
	var t := str(ev.get("type", ""))
	if t != got.type:
		return false
	match t:
		"killed":
			return _who_matches(ev, got)
		"created":
			return got.team == ev.get("team", "player")
		"spotted":
			return int(got.eid) == _eid(ev.get("obj", -1))
		"enter_zone", "leave_zone":
			return int(got.zone) == _eid(ev.get("zone", -1)) and _who_matches(ev, got)
		"zone_captured", "zone_lost", "vip_arrived":
			return _eid(ev.get("zone", -1)) < 0 or int(got.zone) == _eid(ev.get("zone", -1))
		"building_destroyed", "interaction":
			return _eid(ev.get("obj", -1)) < 0 or int(got.eid) == _eid(ev.get("obj", -1))
		"building_built":
			return ev.get("kind", "any") == "any" or ev.kind == got.kind
		"relation_changed":
			var a := str(ev.get("a", ""))
			var b := str(ev.get("b", ""))
			var pair := [str(got.a), str(got.b)]
			return (a == "" or pair.has(a)) and (b == "" or pair.has(b))
		"wave_started", "wave_ended":
			if str(ev.get("wave", "")) != "":
				return str(ev.wave) == str(got.get("id", ""))
			return int(ev.get("n", 0)) == 0 or int(ev.n) == int(got.n)
		"objective_started", "objective_done", "objective_failed":
			return str(ev.get("objective", "")) == "" or str(ev.objective) == str(got.objective)
		"var_changed":
			return str(ev.get("var", "")) == "" or str(ev.var) == str(got.var)
		"timer_end":
			return str(ev.get("timer", "")) == str(got.timer)
	return true


func _who_matches(ev: Dictionary, got: Dictionary) -> bool:
	match str(ev.get("who", "player")):
		"player":
			return got.team in ["player", "vip"]
		"enemy":
			return got.team == "enemy"
		"vip":
			return got.team == "vip"
		"obj":
			return int(got.eid) == _eid(ev.get("obj", -1)) and int(got.eid) >= 0
	return false


# =============================================================================================
# Valeurs, objets, conditions
# =============================================================================================

## Identifiant d'objet : nombre, ou "$nom" (variable de type référence).
func _eid(v: Variant) -> int:
	if v is String and (v as String).begins_with("$"):
		return int(vars.get((v as String).substr(1), -1))
	return int(v) if v != null else -1


func value(v: Variant) -> Variant:
	if v is String and (v as String).begins_with("$"):
		return vars.get((v as String).substr(1), 0)
	if v is String and (v as String).is_valid_float():
		return float(v)
	return v


## Objet du jeu (ennemi, unité, bâtiment) pour un identifiant d'éditeur.
func obj(v: Variant) -> Variant:
	return w.find_by_eid(_eid(v))


func zone(v: Variant) -> Dictionary:
	var id := _eid(v)
	for z in w.mission.zones:
		if z.eid == id:
			return z
	return {}


## Position d'un objet, d'une zone ou d'un objet interactif.
func place_of(v: Variant) -> Vector2:
	var o: Variant = obj(v)
	if o != null:
		return GameWorld.obj_pos(o)
	var z := zone(v)
	if not z.is_empty():
		return z.pos
	var id := _eid(v)
	for list in [w.mission.terminals, w.mission.prisoners, w.mission.pickups]:
		for x in list:
			if x.eid == id:
				return Vector2(x.cell) + Vector2(0.5, 0.5)
	for d in w.mission.doors:
		if d.eid == id and not d.cells.is_empty():
			return Vector2(d.cells[0]) + Vector2(0.5, 0.5)
	for sh in w.mission.shields:
		if sh.eid == id:
			return sh.pos
	return Vector2.INF


## Nombre d'unités d'un camp dans une zone (ou sur toute la carte si zone vide).
func count_in(team: String, z: Dictionary, one := -1) -> int:
	var n := 0
	var r2: float = z.radius * z.radius if not z.is_empty() else INF
	if team in ["player", "vip", "obj"]:
		for u in w.units:
			if not u.alive:
				continue
			if team == "player" and u.locked and not u.vip:
				continue
			if team == "vip" and not u.vip:
				continue
			if team == "obj" and u.eid != one:
				continue
			if z.is_empty() or u.pos.distance_squared_to(z.pos) <= r2:
				n += 1
	if team in ["enemy", "obj"]:
		for e in w.enemies:
			if e.hp <= 0 or e.neutral:
				continue
			if team == "obj" and e.eid != one:
				continue
			if z.is_empty() or e.pos.distance_squared_to(z.pos) <= r2:
				n += 1
	return n


func _zone_controlled(z: Dictionary) -> bool:
	return not z.is_empty() and count_in("player", z) > 0 and count_in("enemy", z) == 0


func _inter_state(id: int, state: String) -> bool:
	match state:
		"open":
			for d in w.mission.doors:
				if d.eid == id:
					return d.open
		"done":
			for t in w.mission.terminals:
				if t.eid == id:
					return t.done
			for d in w.mission.doors:
				if d.eid == id:
					return d.open
		"freed":
			for q in w.mission.prisoners:
				if q.eid == id:
					return q.freed
		"taken":
			for k in w.mission.pickups:
				if k.eid == id:
					return k.taken
		"active":
			for sh in w.mission.shields:
				if sh.eid == id:
					return sh.active
	return false


## Évalue un arbre de conditions {op: and/or, items: [...]} ; chaque condition peut avoir "not": true.
func eval_cond(node: Dictionary, ev := {}) -> bool:
	if node.is_empty():
		return true
	if node.has("op"):
		var items: Array = node.get("items", [])
		if items.is_empty():
			return true
		var any: bool = node.op == "or"
		for it: Dictionary in items:
			var r := eval_cond(it, ev)
			if any and r:
				return true
			if not any and not r:
				return false
		return not any
	var res := _leaf(node)
	return not res if node.get("not", false) else res


func _leaf(c: Dictionary) -> bool:
	match str(c.get("type", "")):
		"alive":
			return obj(c.get("obj", -1)) != null
		"dead":
			return obj(c.get("obj", -1)) == null and not w.mission.absent.has(_eid(c.get("obj", -1)))
		"in_zone":
			var who := str(c.get("who", "player"))
			var n := count_in(who, zone(c.get("zone", -1)), _eid(c.get("obj", -1)))
			return ScenarioDefs.compare(n, str(c.get("cmp", ">=")), value(c.get("value", 1)))
		"zone_control":
			return _zone_controlled(zone(c.get("zone", -1)))
		"objective":
			var o := _objective(str(c.get("objective", "")))
			return not o.is_empty() and o.state == str(c.get("state", "done"))
		"time":
			return ScenarioDefs.compare(w.time, str(c.get("cmp", ">=")), value(c.get("value", 0)))
		"var":
			return ScenarioDefs.compare(vars.get(str(c.get("var", "")), 0), str(c.get("cmp", "==")), value(c.get("value", 0)))
		"count":
			return ScenarioDefs.compare(count_in(str(c.get("team", "enemy")), zone(c.get("zone", -1))), str(c.get("cmp", "<=")), value(c.get("value", 0)))
		"team_eliminated":
			if c.get("team", "enemy") == "enemy":
				return count_in("enemy", {}) == 0 and w.waves.finished()
			return count_in("player", {}) == 0 and w.workers.is_empty()
		"obj_state":
			return _inter_state(_eid(c.get("obj", -1)), str(c.get("state", "done")))
		"resources":
			var have := w.metal if c.get("res", "metal") == "metal" else w.essence
			return ScenarioDefs.compare(have, str(c.get("cmp", ">=")), value(c.get("value", 0)))
		"wave":
			return ScenarioDefs.compare(w.waves.wave, str(c.get("cmp", ">=")), value(c.get("value", 0)))
		"relation":
			return w.factions.relation(str(c.get("a", "p1")), str(c.get("b", "neutral"))) == str(c.get("rel", "enemy"))
		"faction_of":
			var fo: Variant = obj(c.get("obj", -1))
			return (fo is Unit or fo is Enemy) and str(fo.faction) == str(c.get("faction", ""))
		"enemies_left":
			return ScenarioDefs.compare(w.waves.left, str(c.get("cmp", "<=")), value(c.get("value", 0)))
		"players":
			return ScenarioDefs.compare(2 if w.hq_site != null else 1, str(c.get("cmp", "==")), value(c.get("value", 1)))
		"random":
			return randf() * 100.0 < float(c.get("percent", 50.0))
	return false


# =============================================================================================
# Objectifs
# =============================================================================================

func _objective(id: String) -> Dictionary:
	for o in objectives:
		if o.def.id == id:
			return o
	return {}


func _activate(o: Dictionary, announce := true) -> void:
	o.state = "active"
	o.t0 = w.time
	o.hold = 0.0
	_queue.append({"type": "objective_started", "objective": o.def.id})
	_log("◆ Objectif : %s" % o.def.name)
	if announce:
		w._emit({"type": "scn_objective", "state": "new", "text": o.def.name})


func set_objective(id: String, state: String) -> void:
	var o := _objective(id)
	if o.is_empty() or o.state == state:
		return
	if state == "active" or state == "visible":
		if o.state == "hidden":
			_activate(o)
		return
	if state == "hidden":
		o.state = "hidden"
		return
	if o.state in ["done", "failed"]:
		return
	o.state = state
	_queue.append({"type": "objective_done" if state == "done" else "objective_failed", "objective": o.def.id})
	_log(("✔ " if state == "done" else "✖ ") + str(o.def.name))
	w._emit({"type": "scn_objective", "state": state, "text": o.def.name})
	if state == "done":
		var rw: Dictionary = o.def.get("reward", {})
		w.metal += int(rw.get("metal", 0))
		w.essence += int(rw.get("essence", 0))
	# Objectifs qui attendaient celui-ci
	for x in objectives:
		if x.state == "hidden" and str(x.def.get("start", "")) == "after" and x.def.get("after", []).has(id):
			if x.def.after.all(func(a: String) -> bool: return _objective(a).get("state", "") == "done"):
				_activate(x)


func _tick_objectives(delta: float) -> void:
	for o in objectives:
		if o.state != "active":
			continue
		var d: Dictionary = o.def
		# Échecs communs
		if float(d.get("deadline", 0.0)) > 0.0 and w.time - float(o.t0) > float(d.deadline):
			set_objective(d.id, "failed")
			continue
		var dead_fail := false
		for id in d.get("fail_dead", []):
			if obj(id) == null and not w.mission.absent.has(_eid(id)):
				dead_fail = true
		if dead_fail:
			set_objective(d.id, "failed")
			continue
		var r := _progress(o, delta)
		if r == "done" or r == "failed":
			set_objective(d.id, r)


## Avance un objectif. Renvoie "done", "failed" ou "". Met à jour o.cur / o.need / o.text.
func _progress(o: Dictionary, delta: float) -> String:
	var d: Dictionary = o.def
	match str(d.type):
		"destroy":
			var what := str(d.get("what", "targets"))
			var total := 0
			var left := 0
			match what:
				"targets":
					var ids: Array = d.get("targets", [])
					total = ids.size()
					for id in ids:
						if obj(id) != null or w.mission.absent.has(_eid(id)):
							left += 1
				"all_enemies":
					left = count_in("enemy", {})
					o.text = "%d ennemi%s restant%s" % [left, "s" if left > 1 else "", "s" if left > 1 else ""]
					return "done" if left == 0 and w.waves.finished() else ""
				"structures", "bases":
					for e in w.enemies:
						if e.hp > 0 and e.is_structure() and (what == "structures" or e.type == "e_hq"):
							left += 1
					o.ids["max"] = maxi(int(o.ids.get("max", 0)), left)
					total = int(o.ids.max)
				"boss":
					var seen := bool(o.ids.get("seen", false))
					var alive := w.enemies.any(func(e: Enemy) -> bool: return e.hp > 0 and e.is_boss())
					if alive:
						o.ids["seen"] = true
					o.text = "Boss en vie" if alive else ("Boss vaincu" if seen else "Le boss n'est pas encore apparu")
					return "done" if seen and not alive else ""
			var need := int(d.get("count", 0))
			if need <= 0 or need > total:
				need = total
			o.cur = total - left
			o.need = need
			o.text = "%d / %d" % [o.cur, need]
			return "done" if total > 0 and o.cur >= need else ""
		"protect":
			var ids: Array = d.get("targets", [])
			for id in ids:
				if obj(id) == null and not w.mission.absent.has(_eid(id)):
					return "failed"
			if ids.is_empty():
				# La base et les bâtiments « à défendre » posés sur la carte.
				if w.base_hp <= 0:
					return "failed"
				for sid in w.mission.defend_ids:
					var s := w.site_by_id(sid)
					if s == null or not s.alive:
						return "failed"
			var t := float(d.get("time", 0.0))
			if t > 0.0:
				var left := maxf(0.0, t - (w.time - float(o.t0)))
				o.text = _clock(left)
				return "done" if left <= 0.0 else ""
			o.text = ""
			return ""
		"survive_time":
			var dur := float(d.get("time", 300.0))
			if dur <= 0.0:
				dur = float(w.mission.data.get("time", 300.0))
			var left := maxf(0.0, dur - (w.time - float(o.t0)))
			o.text = _clock(left)
			return "done" if left <= 0.0 else ""
		"survive_waves":
			var n := int(d.get("waves", 0))
			if n <= 0:
				o.text = "Vague %d / %d" % [w.waves.wave, w.waves.total]
				var calm := not w.enemies.any(func(e: Enemy) -> bool: return e.hp > 0 and not e.neutral and e.mode == "march")
				return "done" if w.waves.finished() and calm else ""
			var ended := int(_prev.get("wave", 0)) if not _prev.get("wave_live", false) else int(_prev.get("wave", 1)) - 1
			o.cur = mini(ended, n)
			o.need = n
			o.text = "%d / %d vagues" % [o.cur, n]
			return "done" if ended >= n else ""
		"hold":
			var z := zone(d.get("zone", -1))
			if _zone_controlled(z):
				o.hold = float(o.hold) + delta
			elif count_in("enemy", z) > 0:
				o.hold = maxf(0.0, float(o.hold) - delta * 0.5)
			var t := float(d.get("time", 60.0))
			o.text = "%s / %s" % [_clock(o.hold), _clock(t)]
			return "done" if o.hold >= t else ""
		"prevent":
			var z := zone(d.get("zone", -1))
			var seen: Dictionary = o.ids
			if not z.is_empty():
				var r2: float = z.radius * z.radius
				for e in w.enemies:
					if e.hp > 0 and not e.neutral and e.pos.distance_squared_to(z.pos) <= r2:
						seen[e.id] = true
			var mx := int(d.get("max", 0))
			o.text = "%d / %d entrés" % [seen.size(), mx]
			if seen.size() > mx:
				return "failed"
			var t := float(d.get("time", 0.0))
			if t > 0.0:
				o.text += " · " + _clock(maxf(0.0, t - (w.time - float(o.t0))))
				return "done" if w.time - float(o.t0) >= t else ""
			return ""
		"reach":
			var z := zone(d.get("zone", -1))
			if z.is_empty():
				return ""
			var who := str(d.get("who", "player"))
			var need := maxi(1, int(d.get("count", 1)))
			var r2: float = z.radius * z.radius
			if d.get("extract", false):
				for u in w.units.duplicate():
					if not u.alive or u.pos.distance_squared_to(z.pos) > r2:
						continue
					if (who == "obj" and u.eid == _eid(d.get("obj", -1))) or (who == "vip" and u.vip) or (who == "player" and not u.locked):
						o.cur = int(o.cur) + 1
						u.alive = false
						w.units.erase(u)
						w._emit({"type": "scn_extract", "pos": u.pos})
			else:
				o.cur = count_in(who, z, _eid(d.get("obj", -1)))
			o.need = need
			o.text = "%d / %d" % [mini(o.cur, need), need]
			if who == "obj" and obj(d.get("obj", -1)) == null and o.cur < need and not w.mission.absent.has(_eid(d.get("obj", -1))):
				return "failed"
			return "done" if o.cur >= need else ""
		"escort":
			var oid := _eid(d.get("obj", -1))
			var u: Variant = obj(oid) if oid >= 0 else w.mission.vip
			if u == null or (u is Unit and not (u as Unit).alive):
				if oid < 0:
					if w.mission.vip == null and not w.mission.absent.values().any(func(e: Dictionary) -> bool: return e.kind == "vip"):
						return "" # pas de VIP sur la carte
					if w.mission.vip == null:
						return "" # VIP absent au départ
				return "" if w.mission.absent.has(oid) else "failed"
			var z := zone(d.get("zone", -1)) if _eid(d.get("zone", -1)) >= 0 else _goal_zone()
			o.text = ""
			return "done" if not z.is_empty() and GameWorld.obj_pos(u).distance_to(z.pos) <= z.radius else ""
		"convoys":
			var n := w.mission.convoys.filter(func(c: Dictionary) -> bool: return c.state == "arrived").size()
			var lost := w.mission.convoys.filter(func(c: Dictionary) -> bool: return c.state == "dead").size()
			var need := int(d.get("count", 1))
			if need <= 0:
				need = mini(int(w.mission.data.get("convoy_need", w.mission.convoy_total)), w.mission.convoy_total)
			o.cur = n
			o.need = need
			o.text = "%d / %d arrivés" % [n, need]
			var waiting := w.mission.convoys.filter(func(c: Dictionary) -> bool: return c.state == "wait")
			if not waiting.is_empty() and not w.mission.convoys.any(func(c: Dictionary) -> bool: return c.state == "go"):
				o.text += " · départ dans %d s" % int(ceilf(maxf(0.0, float(waiting[0].at) - w.time)))
			if n >= need:
				return "done"
			return "failed" if w.mission.convoy_total - lost < need and w.mission.convoy_total > 0 else ""
		"convoys_destroyed":
			var main := w.objectives.filter(func(x: Dictionary) -> bool: return x.get("main", false))
			var n := main.filter(func(x: Dictionary) -> bool: return x.state == "done").size()
			var failed := main.filter(func(x: Dictionary) -> bool: return x.state == "failed").size()
			var total := w.mission.convoy_total
			var need := int(d.get("count", 1))
			if need <= 0:
				need = int(w.mission.data.get("convoy_need", total))
			o.cur = n
			o.need = need
			o.text = "%d / %d détruits" % [n, need]
			if n >= need and need > 0:
				return "done"
			return "failed" if total > 0 and total - failed < need else ""
		"route":
			var zs: Array = d.get("zones", [])
			var step := int(o.step)
			if step >= zs.size():
				return "done" if not zs.is_empty() else ""
			var who := str(d.get("who", "player"))
			if count_in(who, zone(zs[step]), _eid(d.get("obj", -1))) > 0:
				o.step = step + 1
				w._emit({"type": "scn_objective", "state": "step", "text": "%s : point %d / %d" % [d.name, o.step, zs.size()]})
			o.text = "%d / %d points" % [o.step, zs.size()]
			return "done" if int(o.step) >= zs.size() else ""
		"capture":
			var zs: Array = d.get("zones", [])
			var need := int(d.get("need", 0))
			var t := float(d.get("time", 10.0))
			if zs.is_empty() or t <= 0.0:
				# Modèle « Prise de position » : les zones de prise de la carte, chacune avec sa propre durée.
				var caps := w.mission.zones.filter(func(z: Dictionary) -> bool: return z.role == "capture" and (zs.is_empty() or zs.has(z.eid) or zs.has(float(z.eid))))
				var got := caps.filter(func(z: Dictionary) -> bool: return z.captured).size()
				if need <= 0 or need > caps.size():
					need = caps.size()
				o.cur = got
				o.need = need
				o.text = "%d / %d positions" % [got, need]
				return "done" if need > 0 and got >= need else ""
			if need <= 0 or need > zs.size():
				need = zs.size()
			var who := _eid(d.get("obj", -1))
			var done := 0
			for zid in zs:
				var key := str(zid)
				var z := zone(zid)
				var prog := float(o.ids.get(key, 0.0))
				if prog >= t:
					done += 1
					continue
				var mine := count_in("obj", z, who) > 0 if who >= 0 else count_in("player", z) > 0
				if mine and count_in("enemy", z) == 0:
					prog += delta
					if prog >= t:
						w._emit({"type": "zone_captured", "pos": z.get("pos", Vector2.ZERO)})
				elif count_in("enemy", z) > 0:
					prog = maxf(0.0, prog - delta * 0.5)
				o.ids[key] = prog
				if prog >= t:
					done += 1
			o.cur = done
			o.need = need
			o.text = "%d / %d zones" % [done, need]
			return "done" if need > 0 and done >= need else ""
		"control":
			var zs: Array = d.get("zones", [])
			var all := not zs.is_empty() and zs.all(func(zid: Variant) -> bool: return _zone_controlled(zone(zid)))
			o.hold = float(o.hold) + delta if all else 0.0
			var t := float(d.get("time", 30.0))
			o.text = "%s / %s" % [_clock(o.hold), _clock(t)] if all else "Tiens toutes les zones en même temps"
			return "done" if o.hold >= t else ""
		"interact":
			var ids: Array = d.get("targets", [])
			var done := 0
			for id in ids:
				var e := _eid(id)
				if _inter_state(e, "done") or _inter_state(e, "freed") or _inter_state(e, "taken") or _inter_state(e, "open"):
					done += 1
				elif obj(id) == null and not w.mission.absent.has(e) and not _is_inter(e):
					done += 1 # générateur / structure détruit
			var need := int(d.get("count", 0))
			if need <= 0 or need > ids.size():
				need = ids.size()
			o.cur = done
			o.need = need
			o.text = "%d / %d" % [done, need]
			return "done" if need > 0 and done >= need else ""
		"collect":
			var need := int(d.get("count", 1))
			o.cur = w.mission.collected
			o.need = need
			o.text = "%d / %d" % [mini(o.cur, need), need]
			return "done" if o.cur >= need else ""
		"condition":
			o.text = ""
			return "done" if eval_cond(d.get("cond", {})) else ""
		"compound":
			var ch: Array = d.get("children", [])
			var done := 0
			var failed := 0
			for id in ch:
				var x := _objective(str(id))
				if x.get("state", "") == "done":
					done += 1
				elif x.get("state", "") == "failed":
					failed += 1
			match str(d.get("mode", "all")):
				"all":
					o.text = "%d / %d" % [done, ch.size()]
					return "failed" if failed > 0 else ("done" if done == ch.size() and not ch.is_empty() else "")
				"any":
					return "done" if done > 0 else ("failed" if failed == ch.size() and not ch.is_empty() else "")
				"atleast":
					var n := int(d.get("n", 1))
					o.text = "%d / %d" % [done, n]
					return "done" if done >= n else ("failed" if ch.size() - failed < n else "")
				"none":
					return "failed" if done > 0 else ""
	return ""


func _goal_zone() -> Dictionary:
	for z in w.mission.zones:
		if z.role == "goal":
			return z
	return {}


func _is_inter(id: int) -> bool:
	for list in [w.mission.terminals, w.mission.prisoners, w.mission.pickups, w.mission.doors]:
		for x in list:
			if x.eid == id:
				return true
	return false


static func _clock(s: float) -> String:
	var t := int(ceilf(s))
	return "%d:%02d" % [t / 60, t % 60]


## "won", "lost" ou "" (seulement si le scénario décide de l'issue).
func result() -> String:
	if forced != "":
		return forced
	var main := objectives.filter(func(o: Dictionary) -> bool: return o.def.get("kind", "main") == "main")
	if bool(_rules().get("defeat_main_failed", true)) and main.any(func(o: Dictionary) -> bool: return o.state == "failed"):
		return "lost"
	if endless:
		return ""
	if str(_rules().get("victory", "objectives")) == "objectives" and main.any(func(o: Dictionary) -> bool: return o.state == "done") \
			and main.all(func(o: Dictionary) -> bool: return _satisfied(o)):
		return "won"
	return ""


## Un objectif principal compte pour la victoire s'il est réussi, ou s'il s'agit de « défendre » ou
## « empêcher » sans durée (il suffit de ne pas l'avoir échoué).
func _satisfied(o: Dictionary) -> bool:
	if o.state == "done":
		return true
	return o.state == "active" and str(o.def.type) in ["protect", "prevent"] and float(o.def.get("time", 0.0)) <= 0.0


## Objectifs principaux visibles, pour le briefing.
func brief_text() -> String:
	var out: Array[String] = []
	for o in objectives:
		if o.state != "hidden" and o.def.get("kind", "main") == "main":
			out.append("◆ " + str(o.def.name))
	return "\n".join(out)


# =============================================================================================
# Actions
# =============================================================================================

func execute(a: Dictionary, ev := {}) -> void:
	var t := str(a.get("type", ""))
	match t:
		"spawn":
			var z := zone(a.get("zone", -1))
			var at: Vector2 = z.pos if not z.is_empty() else w.base_center() + Vector2(4, 0)
			var n := clampi(int(value(a.get("count", 1))), 1, 60)
			for i in n:
				var p := at + Vector2.from_angle(TAU * i / n) * (0.4 + 0.3 * (i % 3)) if n > 1 else at
				if a.get("team", "enemy") == "enemy":
					var e := Enemy.create(str(a.get("enemy_type", "normal")), p, w.waves.hp_scale())
					e.id = w._next_enemy_id
					w._next_enemy_id += 1
					var beh := str(a.get("behavior", "march"))
					e.mode = beh if beh in Mission.BEHAVIORS_ENEMY else "march"
					e.guard_pos = p
					e.home = p
					if e.mode == "attack_zone":
						e.goal_pos = place_of(a.get("target", -1))
					var ef := str(a.get("faction", ""))
					if ef != "" and w.factions.camp(ef) == "enemy":
						e.faction = ef
					w.enemies.append(e)
				else:
					var u := Unit.create(str(a.get("unit_type", "soldier")), p)
					u.id = w._next_unit_id
					w._next_unit_id += 1
					var uf := str(a.get("faction", ""))
					if uf != "" and w.factions.camp(uf) == "player":
						u.faction = uf
						u.ai = not (uf in ["p1", "p2"])
					w.units.append(u)
			_log("  créer %d %s" % [n, a.get("enemy_type", "") if a.get("team", "enemy") == "enemy" else a.get("unit_type", "")])
		"set_relation":
			w.factions.set_relation(str(a.get("a", "p1")), str(a.get("b", "neutral")), str(a.get("rel", "enemy")))
		"set_faction":
			var fo: Variant = obj(a.get("obj", -1))
			var nf := str(a.get("faction", ""))
			if fo is Unit and w.factions.camp(nf) == "player":
				var u: Unit = fo
				u.faction = nf
				u.ai = not (nf in ["p1", "p2"])
			elif fo is Enemy and w.factions.camp(nf) == "enemy":
				(fo as Enemy).faction = nf
				(fo as Enemy).target_kind = Enemy.Target.NONE
			else:
				_log("  faction impossible : %s ne peut pas rejoindre %s (autre camp)" % [str(a.get("obj", -1)), w.factions.name_of(nf)])
		"activate":
			var id := _eid(a.get("obj", -1))
			if not w.mission.spawn_late(w, id):
				var o: Variant = obj(id)
				if o is Enemy and (o as Enemy).mode == "wait":
					(o as Enemy).mode = "guard"
		"remove":
			var o: Variant = obj(a.get("obj", -1))
			if o is Enemy:
				for c in w._structure_cells(o):
					w.pathfinder.set_solid(c, false)
				w.enemies.erase(o)
				w._flow_dirty = true
			elif o is Unit:
				(o as Unit).alive = false
				w.units.erase(o)
			elif o is BuildSite:
				w._remove_site(o)
		"move":
			var o: Variant = obj(a.get("obj", -1))
			var z := zone(a.get("zone", -1))
			if z.is_empty() or o == null:
				return
			if o is Enemy:
				(o as Enemy).mode = "attack_zone"
				(o as Enemy).goal_pos = z.pos
			elif o is Unit:
				w._unit_go(o, Vector2i(z.pos.floor()))
		"heal":
			var o: Variant = obj(a.get("obj", -1))
			if o != null:
				o.hp = o.max_hp
		"immobilize":
			var o: Variant = obj(a.get("obj", -1))
			var on := bool(a.get("on", true))
			if o is Enemy:
				(o as Enemy).mode = "static" if on else "guard"
			elif o is Unit:
				(o as Unit).order = Unit.Order.HOLD if on else Unit.Order.GUARD
		"build":
			var z := zone(a.get("zone", -1))
			if not z.is_empty():
				var s := w.mission._place_free(w, str(a.get("build_type", "gun")), Vector2i(z.pos.floor()))
				if s == null:
					_log("  ⚠ impossible de construire ici")
		"destroy":
			var o: Variant = obj(a.get("obj", -1))
			if o != null:
				o.hp = 0
		"behavior":
			var o: Variant = obj(a.get("obj", -1))
			if o is Enemy:
				var e := o as Enemy
				e.mode = str(a.get("behavior", "aggressive"))
				e.target_eid = _eid(a.get("target", -1))
				e.path.clear()
				if e.mode == "attack_zone":
					e.goal_pos = place_of(a.get("target", -1))
		"wave_launch":
			w.waves.paused = false
			w.waves.launch_id(str(a.get("wave", "")))
		"wave_stop":
			w.waves.stop(str(a.get("wave", "")))
		"wave_speed":
			w.waves.speed = clampf(float(value(a.get("factor", 2.0))), 0.1, 10.0)
		"wave_pause":
			w.waves.paused = true
		"wave_resume":
			w.waves.paused = false
		"wave_interval":
			w.waves.interval = maxf(3.0, float(value(a.get("seconds", 20.0))))
		"give":
			var n := int(value(a.get("amount", 0)))
			if a.get("res", "metal") == "metal":
				w.metal = maxi(0, w.metal + n)
			else:
				w.essence = maxi(0, w.essence + n)
		"obj_reveal":
			set_objective(str(a.get("objective", "")), "active")
		"obj_hide":
			set_objective(str(a.get("objective", "")), "hidden")
		"obj_complete":
			set_objective(str(a.get("objective", "")), "done")
		"obj_fail":
			set_objective(str(a.get("objective", "")), "failed")
		"door_open":
			var d := w.mission.door_by_eid(_eid(a.get("obj", -1)))
			if not d.is_empty():
				w.mission.open_door(w, d)
		"door_close":
			var d := w.mission.door_by_eid(_eid(a.get("obj", -1)))
			if not d.is_empty():
				w.mission.close_door(w, d)
		"message":
			w._emit({"type": "scn_message", "speaker": _text(a.get("speaker", "")), "text": _text(a.get("text", "")), "seconds": float(a.get("seconds", 6.0))})
		"alert":
			w._emit({"type": "scn_alert", "text": _text(a.get("text", ""))})
		"notify":
			w._emit({"type": "scn_notify", "text": _text(a.get("text", ""))})
		"marker":
			var p := place_of(a.get("obj", -1))
			if p != Vector2.INF:
				var s := float(a.get("seconds", 10.0))
				markers.append({"pos": p, "text": _text(a.get("text", "")), "until": w.time + s if s > 0.0 else 0.0})
				w._emit({"type": "scn_ping", "pos": p})
		"marker_clear":
			markers.clear()
		"sound":
			w._emit({"type": "scn_sound", "name": str(a.get("sound", "wave"))})
		"timer_start":
			timers[str(a.get("timer", "chrono"))] = {"left": float(value(a.get("seconds", 60.0))), "label": _text(a.get("label", "")), "show": bool(a.get("show", true))}
		"timer_stop":
			timers.erase(str(a.get("timer", "chrono")))
		"timer_add":
			var tm: Dictionary = timers.get(str(a.get("timer", "chrono")), {})
			if not tm.is_empty():
				tm.left = maxf(0.0, float(tm.left) + float(value(a.get("seconds", 0.0))))
		"var_set":
			_set_var(str(a.get("var", "")), value(a.get("value", 0)))
		"var_add":
			_set_var(str(a.get("var", "")), float(vars.get(str(a.get("var", "")), 0)) + float(value(a.get("value", 1))))
		"var_reset":
			for v: Dictionary in data.get("variables", []):
				if v.name == a.get("var", ""):
					_set_var(v.name, _typed(v.get("type", "int"), v.get("value", 0)))
		"trigger_enable":
			for tr in triggers:
				if tr.def.id == a.get("trigger", ""):
					tr.enabled = bool(a.get("on", true))
		"trigger_run":
			run_trigger(str(a.get("trigger", "")))
		"victory":
			forced = "won"
			end_text = _text(a.get("text", ""))
		"defeat":
			forced = "lost"
			end_text = _text(a.get("text", ""))
	if t not in ["spawn"]:
		_log("  %s" % ScenarioDefs.ACTIONS.get(t, {}).get("label", t))


func _set_var(name: String, v: Variant) -> void:
	if name == "":
		return
	for d: Dictionary in data.get("variables", []):
		if d.name == name:
			v = _typed(d.get("type", "int"), v)
	if vars.get(name) == v:
		return
	vars[name] = v
	_queue.append({"type": "var_changed", "var": name})


## Texte avec variables : « Il reste {vies} vies ».
func _text(s: Variant) -> String:
	var out := str(s)
	if not out.contains("{"):
		return out
	for k in vars:
		out = out.replace("{%s}" % k, str(vars[k]))
	return out


# =============================================================================================
# Coop : état transmis au 2e joueur
# =============================================================================================

func net_state() -> Array:
	return [objectives.map(func(o: Dictionary) -> Array: return [o.state, o.text]),
			timers.values().filter(func(t: Dictionary) -> bool: return t.show).map(func(t: Dictionary) -> Array: return [t.label, t.left]),
			markers.map(func(m: Dictionary) -> Array: return [m.pos.x, m.pos.y, m.text]), w.factions.rel]


var net_timers: Array = []


func apply_net_state(a: Array) -> void:
	for i in mini(objectives.size(), a[0].size()):
		objectives[i].state = a[0][i][0]
		objectives[i].text = a[0][i][1]
	net_timers = a[1]
	if a.size() > 3 and a[3] != w.factions.rel:
		w.factions.rel = a[3].duplicate()
		w.factions._refresh()
	markers.clear()
	for m in a[2]:
		markers.append({"pos": Vector2(m[0], m[1]), "text": m[2], "until": 0.0})


## Chronos affichés (hôte ou client).
func shown_timers() -> Array:
	if not net_timers.is_empty():
		return net_timers
	return timers.values().filter(func(t: Dictionary) -> bool: return t.show).map(func(t: Dictionary) -> Array: return [t.label, t.left])
