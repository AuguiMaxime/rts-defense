class_name Mission
extends RefCounted
## Mission d'une carte : type, paramètres et entités posées dans l'éditeur (convois, VIP, zones,
## objets interactifs…). La victoire et la défaite sont décidées par le scénario (objectifs et
## déclencheurs) : chaque type génère les siens via MissionTemplates.
##
## Types :
##   waves          défense : survivre à toutes les vagues (et garder en vie les bâtiments à défendre)
##   survive        tenir `time` secondes ; la base détruite = défaite
##   destroy_base   détruire toutes les bases ennemies (structures "e_hq")
##   convoy         détruire `convoy_need` convois ennemis sur `convoy_count`
##   escort         amener l'unité VIP dans la zone d'arrivée
##   escort_defend  faire arriver `convoy_need` convois alliés sur `convoy_count` au bout de leur trajet
##   capture        tenir chaque zone de prise le temps indiqué sur la zone
##
## Entités (liste de dictionnaires, toutes avec "kind" et "cell") :
##   structure  {type}                    structure ennemie (Balance.ENEMY_STRUCTURES)
##   enemy      {type, hold}              unité ennemie en garde (hold = ne bouge pas)
##   ally_tower {type, level}             tourelle alliée déjà construite
##   ally_unit  {type, hold}              unité alliée déjà présente
##   defend     {type}                    bâtiment allié à défendre (détruit = défaite, cible prioritaire des ennemis)
##   vip        {type}                    unité à escorter (mission escort)
##   escortee   {}                        point de départ des convois alliés (optionnel)
##   waypoint   {order, pause}            trajet des convois (alliés ou ennemis selon la mission), pause en secondes
##   zone       {role, radius, time}      "goal" (arrivée) ou "capture" (time = secondes à tenir)
##   deco       {sprite, block, rot}      décor ; taille lue dans le nom du fichier (nom_2x2) ; rot = quarts de tour

const TYPES := ["waves", "survive", "destroy_base", "convoy", "escort", "escort_defend", "capture"]
const TYPE_NAMES := {
	"waves": "Défense", "survive": "Survie", "destroy_base": "Détruire la base",
	"convoy": "Attaque de convois", "escort": "Escorte", "escort_defend": "Protéger le convoi",
	"capture": "Prise de position",
}
const ESCORTEE_SPEED := 0.9

var type := "waves"
var data := {}
var entities: Array = []
## État
var zones: Array[Dictionary] = [] # {pos, radius, role, progress, captured, time}
var vip: Unit = null
var decos: Array[Dictionary] = [] # {sprite, cell, size, base, rot, block}
var convoy_total := 0
## Trajet tracé dans l'éditeur (points de passage dans l'ordre) et pauses à chaque point.
var route_cells: Array[Vector2i] = []
var route_pauses: Array[float] = []
## Convois ennemis : trajet détaillé case par case et pauses (index du trajet -> secondes).
var foe_route: Array[Vector2] = []
var foe_pauses := {}
## Convois alliés : {uid, at, i, pause, state ("wait", "go", "arrived", "dead")}
var convoys: Array[Dictionary] = []
var convoy_spawn := Vector2i(-1, -1)
## Bâtiments à défendre (ids des chantiers).
var defend_ids: Array[int] = []
## Objets interactifs (identifiant d'éditeur `eid`).
var doors: Array[Dictionary] = [] # {eid, cells, open, link}
var shields: Array[Dictionary] = [] # {eid, pos, radius, link, active}
var terminals: Array[Dictionary] = [] # {eid, cell, time, progress, done}
var prisoners: Array[Dictionary] = [] # {eid, cell, count, type, freed}
var pickups: Array[Dictionary] = [] # {eid, cell, label, taken}
var collected := 0
## Objets absents au départ (apparaissent par un déclencheur) : eid -> objet d'éditeur.
var absent := {}
const LATE_KINDS := ["structure", "enemy", "ally_tower", "ally_unit", "vip", "prisoners", "pickup", "terminal", "defend"]
const BEHAVIORS_ENEMY := ["guard", "static", "patrol", "defend", "aggressive", "attack_target", "attack_zone", "follow", "march", "wait"]


func _init(d: Dictionary = {}, ents: Array = []) -> void:
	data = d
	type = str(d.get("type", "waves"))
	if not TYPES.has(type):
		type = "waves"
	entities = ents


func param(key: String, default: Variant) -> Variant:
	return data.get(key, default)


## Les vagues ennemies sont-elles actives pour cette mission ?
func waves_enabled() -> bool:
	return type == "waves" or bool(data.get("waves_enabled", type == "survive"))


## Taille d'un décor d'après son nom de fichier : "hangar_2x2" -> (2, 2), sinon 1x1.
static func deco_size(sprite: String) -> Vector2i:
	var rx := RegEx.create_from_string("_(\\d)x(\\d)$")
	var m := rx.search(sprite)
	if m == null:
		return Vector2i.ONE
	return Vector2i(clampi(int(m.get_string(1)), 1, 8), clampi(int(m.get_string(2)), 1, 8))


## Emprise d'un décor une fois pivoté (quarts de tour).
static func deco_footprint(sprite: String, rot: int) -> Vector2i:
	var s := deco_size(sprite)
	return Vector2i(s.y, s.x) if rot % 2 == 1 else s


static func _cell_of(ent: Dictionary) -> Vector2i:
	return Vector2i(int(ent.cell[0]), int(ent.cell[1])) if ent.cell is Array else Vector2i(ent.cell)


func setup(w: GameWorld) -> void:
	if not waves_enabled():
		w.waves.timer = INF
		w.waves.auto_on = false
	elif type == "survive":
		w.waves.infinite = true # les vagues continuent jusqu'à la fin du chrono
	var waypoints: Array = []
	for ent: Dictionary in entities:
		if ent.get("absent", false) and str(ent.get("kind", "")) in LATE_KINDS:
			absent[int(ent.get("id", -1))] = ent
			continue
		_spawn(w, ent, waypoints)
	# Ennemis qui attaquent une zone : position de la zone.
	for e in w.enemies:
		if e.mode == "attack_zone":
			for z in zones:
				if z.eid == e.target_eid:
					e.goal_pos = z.pos
	waypoints.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for wp in waypoints:
		route_cells.append(wp[1])
		route_pauses.append(wp[2])
	var count := int(data.get("convoy_count", 3 if type == "convoy" else 1))
	var start := float(data.get("convoy_start", 20.0 if type == "convoy" else 0.0))
	var gap := float(data.get("convoy_interval", 40.0))
	if type == "convoy":
		var kind := str(data.get("convoy_kind", "convoy"))
		convoy_total = count
		var custom := route_cells.size() >= 2
		if custom:
			_build_foe_route(w, kind)
		for i in convoy_total:
			w.objectives.append({"type": kind, "wave": 0, "time": start + gap * i, "state": "pending", "destroyed": 0,
					"total": int(Balance.OBJECTIVES[kind].count), "main": true, "custom": custom})
	elif type == "escort_defend":
		if convoy_spawn.x < 0 and not route_cells.is_empty():
			convoy_spawn = route_cells[0]
		convoy_total = count
		for i in convoy_total:
			convoys.append({"uid": -1, "at": start + gap * i, "i": 0, "pause": 0.0, "state": "wait"})


## Crée dans le monde l'objet d'éditeur `ent` (au départ, ou plus tard par un déclencheur).
func _spawn(w: GameWorld, ent: Dictionary, waypoints: Array) -> void:
	var c := _cell_of(ent)
	var at := Vector2(c) + Vector2(0.5, 0.5)
	match str(ent.get("kind", "")):
		"structure":
			if not Balance.ENEMY_STRUCTURES.has(ent.type):
				return
			var e := Enemy.create(ent.type, at, 1.0)
			var sz := int(Balance.ENEMY_STRUCTURES[ent.type].size)
			e.pos = Vector2(c) + Vector2(sz, sz) * 0.5
			e.guard_pos = e.pos
			e.id = w._next_enemy_id
			w._next_enemy_id += 1
			_enemy_props(e, ent)
			w.enemies.append(e)
			for cc in w._structure_cells(e):
				w.pathfinder.set_solid(cc, true)
			w._flow_dirty = true
		"enemy":
			if not Balance.ENEMIES.has(ent.type):
				return
			var e := Enemy.create(ent.type, at, 1.0)
			var beh := str(ent.get("behavior", "static" if ent.get("hold", false) else "guard"))
			e.mode = beh if BEHAVIORS_ENEMY.has(beh) else "guard"
			e.guard_pos = at
			e.home = at
			e.id = w._next_enemy_id
			w._next_enemy_id += 1
			_enemy_props(e, ent)
			for pc in ent.get("patrol", []):
				e.patrol.append(Vector2i(int(pc[0]), int(pc[1])))
			e.target_eid = int(ent.get("target", -1))
			e.retreat_pct = float(ent.get("retreat", 0)) / 100.0
			w.enemies.append(e)
		"ally_tower", "defend":
			var s := _place_free(w, str(ent.get("type", "")), c, not ent.get("building", false))
			if s == null:
				return
			s.eid = int(ent.get("id", -1))
			s.invulnerable = ent.get("inv", false)
			s.set_mults(float(ent.get("dmg_mul", 1.0)), float(ent.get("rng_mul", 1.0)))
			if ent.kind == "ally_tower":
				s.level = clampi(int(ent.get("level", 1)), 1, BuildSite.MAX_LEVEL)
			else:
				defend_ids.append(s.id)
			if s.built:
				s.max_hp = roundi((s.stats().hp if s.is_tower() else Content.building(s.kind).hp) * float(ent.get("hp_mul", 1.0)))
				s.hp = s.max_hp
		"ally_unit", "vip":
			var t := str(ent.get("type", "soldier"))
			if not Content.UNITS.has(t):
				return
			var u := Unit.create(t, at)
			u.id = w._next_unit_id
			w._next_unit_id += 1
			u.eid = int(ent.get("id", -1))
			u.invulnerable = ent.get("inv", false)
			u.max_hp = roundi(u.max_hp * float(ent.get("hp_mul", 1.0)))
			u.hp = u.max_hp
			u.mul_dmg = float(ent.get("dmg_mul", 1.0))
			u.mul_spd = float(ent.get("spd_mul", 1.0))
			u.mul_rng = float(ent.get("rng_mul", 1.0))
			w.units.append(u)
			if ent.kind == "ally_unit":
				var beh := str(ent.get("behavior", "hold" if ent.get("hold", false) else "guard"))
				match beh:
					"hold":
						u.order = Unit.Order.HOLD
					"patrol":
						for pc in ent.get("patrol", []):
							u.patrol.append(Vector2i(int(pc[0]), int(pc[1])))
					"follow":
						u.follow_eid = int(ent.get("target", -1))
					"hunt":
						u.hunt = true
				u.faction = str(ent.get("faction", "p1" if ent.get("selectable", true) else "ally"))
				# Hors des factions des joueurs, l'unité est pilotée par l'ordinateur.
				u.ai = not (u.faction in ["p1", "p2"])
				if ent.get("sieged", false) and u.ability() == "siege":
					u.sieged = true
			if ent.kind == "vip":
				u.faction = str(ent.get("faction", "p1"))
				u.vip = true
				vip = u
		"escortee":
			convoy_spawn = c
		"waypoint":
			waypoints.append([int(ent.get("order", waypoints.size())), c, float(ent.get("pause", 0.0))])
		"zone":
			zones.append({"eid": int(ent.get("id", -1)), "name": str(ent.get("name", "")), "pos": at, "radius": float(ent.get("radius", 2.5)),
					"role": str(ent.get("role", "capture")), "progress": 0.0, "captured": false,
					"time": float(ent.get("time", data.get("time", 30.0)))})
		"door":
			var cells: Array[Vector2i] = []
			for i in clampi(int(ent.get("len", 2)), 1, 8):
				var cc := c + (Vector2i(0, i) if ent.get("vertical", false) else Vector2i(i, 0))
				if w.grid.is_inside(cc):
					cells.append(cc)
			var dr := {"eid": int(ent.get("id", -1)), "cells": cells, "open": bool(ent.get("open", false)),
					"link": int(ent.get("link", -1)), "vertical": bool(ent.get("vertical", false))}
			doors.append(dr)
			if not dr.open:
				for cc in cells:
					w.pathfinder.set_solid(cc, true)
				w._flow_dirty = true
		"shield":
			shields.append({"eid": int(ent.get("id", -1)), "pos": at, "radius": float(ent.get("radius", 4.0)),
					"link": int(ent.get("link", -1)), "active": true})
		"terminal":
			terminals.append({"eid": int(ent.get("id", -1)), "cell": c, "time": float(ent.get("time", 5.0)), "progress": 0.0, "done": false})
		"prisoners":
			prisoners.append({"eid": int(ent.get("id", -1)), "cell": c, "count": clampi(int(ent.get("count", 3)), 1, 12),
					"type": str(ent.get("unit", "soldier")), "freed": false})
		"pickup":
			pickups.append({"eid": int(ent.get("id", -1)), "cell": c, "label": str(ent.get("label", "Objet")), "taken": false})
		"deco":
			var sp := str(ent.get("sprite", ""))
			var rot := int(ent.get("rot", 0)) % 4
			var fp := deco_footprint(sp, rot)
			decos.append({"sprite": sp, "cell": c, "size": fp, "base": deco_size(sp), "rot": rot, "flip": bool(ent.get("flip", false)), "block": bool(ent.get("block", false))})
			if ent.get("block", false):
				for dy in fp.y:
					for dx in fp.x:
						if w.grid.is_inside(c + Vector2i(dx, dy)):
							w.pathfinder.set_solid(c + Vector2i(dx, dy), true)
				w._flow_dirty = true


## Fait apparaître un objet absent au départ. Renvoie true s'il vient d'apparaître.
func spawn_late(w: GameWorld, eid: int) -> bool:
	if not absent.has(eid):
		return false
	var ent: Dictionary = absent[eid]
	absent.erase(eid)
	_spawn(w, ent, [])
	for e in w.enemies:
		if e.eid == eid and e.mode == "attack_zone":
			for z in zones:
				if z.eid == e.target_eid:
					e.goal_pos = z.pos
	return true


## Réglages de la fiche communs aux ennemis et structures.
static func _enemy_props(e: Enemy, ent: Dictionary) -> void:
	e.faction = str(ent.get("faction", "enemy"))
	e.eid = int(ent.get("id", -1))
	e.invulnerable = ent.get("inv", false)
	e.max_hp = roundi(e.max_hp * float(ent.get("hp_mul", 1.0)))
	e.hp = e.max_hp
	e.damage = roundi(e.damage * float(ent.get("dmg_mul", 1.0)))
	e.speed = e.speed * float(ent.get("spd_mul", 1.0))
	e.attack_range = e.attack_range * float(ent.get("rng_mul", 1.0))


## Pose un bâtiment allié sans le faire payer, construit ou en chantier.
func _place_free(w: GameWorld, kind: String, c: Vector2i, built := true) -> BuildSite:
	if kind == "" or (not Content.TOWERS.has(kind) and kind != "house" and not Content.PRODUCTION.has(kind)):
		return null
	var cost := Content.building(kind)
	w.metal += int(cost.metal)
	w.essence += int(cost.essence)
	var s := w.place(kind, c)
	if s == null:
		w.metal -= int(cost.metal)
		w.essence -= int(cost.essence)
		return null
	if built:
		s.work_done = s.work_needed
		w._finish_site(s)
		s.max_hp = int(s.stats().hp) if s.is_tower() else int(Content.building(kind).hp)
		s.hp = s.max_hp
	return s


## Trajet case par case des convois ennemis : chaque tronçon suit les rails (train), l'eau (bateau)
## ou le sol libre (camions) ; à défaut, une ligne droite.
func _build_foe_route(w: GameWorld, kind: String) -> void:
	var ok: Callable
	match kind:
		"train":
			ok = w.grid.is_rail
		"boat":
			ok = w.grid.is_water
		_:
			ok = func(c: Vector2i) -> bool: return w.grid.is_road(c) or w.pathfinder.is_free(c)
	var cells: Array[Vector2i] = [route_cells[0]]
	foe_pauses.clear()
	if route_pauses[0] > 0.0:
		foe_pauses[0] = route_pauses[0]
	for k in range(1, route_cells.size()):
		var seg := _bfs(w, route_cells[k - 1], route_cells[k], ok)
		if seg.is_empty():
			seg = _line(route_cells[k - 1], route_cells[k])
		cells.append_array(seg)
		if route_pauses[k] > 0.0:
			foe_pauses[cells.size() - 1] = route_pauses[k]
	foe_route.clear()
	for c in cells:
		foe_route.append(Vector2(c) + Vector2(0.5, 0.5))


## Plus court chemin (4 directions) de a à b sur les cases acceptées par ok ; sans a, avec b.
static func _bfs(w: GameWorld, a: Vector2i, b: Vector2i, ok: Callable) -> Array[Vector2i]:
	var prev := {a: a}
	var q: Array[Vector2i] = [a]
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		if c == b:
			var out: Array[Vector2i] = []
			while c != a:
				out.push_front(c)
				c = prev[c]
			return out
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if w.grid.is_inside(n) and not prev.has(n) and (n == b or ok.call(n)):
				prev[n] = c
				q.append(n)
	return []


static func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := a
	while c != b:
		var d := b - c
		if absi(d.x) >= absi(d.y):
			c.x += signi(d.x)
		else:
			c.y += signi(d.y)
		out.append(c)
	return out


func tick(w: GameWorld, delta: float) -> void:
	_tick_convoys(w, delta)
	_tick_interactive(w, delta)
	# Zones de prise de position : des alliés dedans et aucun ennemi hostile.
	for z in zones:
		if z.role != "capture" or z.captured:
			continue
		var r2: float = z.radius * z.radius
		var mine := w.units.any(func(u: Unit) -> bool: return u.alive and not u.locked and u.pos.distance_squared_to(z.pos) <= r2)
		var theirs := w.enemies.any(func(e: Enemy) -> bool: return e.hp > 0 and not e.neutral and e.pos.distance_squared_to(z.pos) <= r2)
		if mine and not theirs:
			z.progress += delta
			if z.progress >= float(z.time):
				z.captured = true
				w._emit({"type": "zone_captured", "pos": z.pos})
		elif theirs:
			z.progress = maxf(0.0, z.progress - delta * 0.5)


## Convois alliés : départ à l'heure prévue, trajet de point en point, pauses, arrivée.
func _tick_convoys(w: GameWorld, delta: float) -> void:
	for cv in convoys:
		match str(cv.state):
			"wait":
				if w.time >= float(cv.at) and convoy_spawn.x >= 0:
					var u := Unit.create("escort_truck", Vector2(convoy_spawn) + Vector2(0.5, 0.5))
					u.id = w._next_unit_id
					w._next_unit_id += 1
					u.locked = true
					w.units.append(u)
					cv.uid = u.id
					cv.state = "go"
					cv.i = 1 if (not route_cells.is_empty() and route_cells[0] == convoy_spawn) else 0
					if cv.i == 1 and route_pauses[0] > 0.0:
						cv.pause = route_pauses[0]
					w._emit({"type": "convoy_start", "pos": u.pos})
			"go":
				var u := w.unit_by_id(int(cv.uid))
				if u == null or not u.alive:
					cv.state = "dead"
					continue
				if float(cv.pause) > 0.0:
					cv.pause = float(cv.pause) - delta
					continue
				if int(cv.i) >= route_cells.size():
					cv.state = "arrived"
					u.alive = false
					w.units.erase(u)
					w._emit({"type": "convoy_arrived", "pos": u.pos})
					continue
				var goal := route_cells[int(cv.i)]
				if u.cell() == goal or u.pos.distance_to(Vector2(goal) + Vector2(0.5, 0.5)) < 0.6:
					cv.pause = route_pauses[int(cv.i)]
					cv.i = int(cv.i) + 1
					u.path.clear()
					continue
				if u.path.is_empty() or u.repath_timer <= 0.0:
					u.repath_timer = 1.0
					u.path = w._path_toward(u.cell(), goal)
				u.repath_timer -= delta
				w._follow_path(u, ESCORTEE_SPEED, delta)


## Portes, boucliers, terminaux, prisonniers, objets à récupérer.
func _tick_interactive(w: GameWorld, delta: float) -> void:
	var mine := w.units.filter(func(u: Unit) -> bool: return u.alive and not u.locked)
	# Terminaux : une unité du joueur à côté pendant le temps indiqué.
	for t in terminals:
		if t.done:
			continue
		var c := Vector2(t.cell) + Vector2(0.5, 0.5)
		if mine.any(func(u: Unit) -> bool: return u.pos.distance_to(c) <= 1.6):
			t.progress = float(t.progress) + delta
			if t.progress >= t.time:
				t.done = true
				w._emit({"type": "terminal_done", "pos": c, "eid": t.eid})
		else:
			t.progress = maxf(0.0, float(t.progress) - delta * 0.5)
	# Portes liées à un terminal (activé) ou à un objet (détruit).
	for d in doors:
		if d.open or d.link < 0:
			continue
		var opened := false
		var term := terminals.filter(func(t: Dictionary) -> bool: return t.eid == d.link)
		if not term.is_empty():
			opened = term[0].done
		else:
			opened = w.find_by_eid(d.link) == null
		if opened:
			open_door(w, d)
	# Boucliers : actifs tant que leur générateur est en vie.
	for e in w.enemies:
		e.shielded = false
	for sh in shields:
		sh.active = sh.link < 0 or w.find_by_eid(sh.link) != null
		if not sh.active:
			continue
		var r2: float = sh.radius * sh.radius
		for e in w.enemies:
			if not e.neutral and e.eid != sh.link and e.pos.distance_squared_to(sh.pos) <= r2:
				e.shielded = true
	# Prisonniers : libérés au contact, ils rejoignent le joueur.
	for p in prisoners:
		if p.freed:
			continue
		var c := Vector2(p.cell) + Vector2(0.5, 0.5)
		if mine.any(func(u: Unit) -> bool: return u.pos.distance_to(c) <= 1.6):
			p.freed = true
			var t := str(p.type) if Content.UNITS.has(str(p.type)) else "soldier"
			for i in int(p.count):
				var u := Unit.create(t, c + Vector2.from_angle(TAU * i / float(p.count)) * 0.6)
				u.id = w._next_unit_id
				w._next_unit_id += 1
				w.units.append(u)
			w._emit({"type": "prisoners_freed", "pos": c, "eid": p.eid})
	# Objets à récupérer : ramassés au passage.
	for k in pickups:
		if k.taken:
			continue
		var c := Vector2(k.cell) + Vector2(0.5, 0.5)
		if mine.any(func(u: Unit) -> bool: return u.pos.distance_to(c) <= 0.9):
			k.taken = true
			collected += 1
			w._emit({"type": "pickup", "pos": c, "eid": k.eid})


func close_door(w: GameWorld, d: Dictionary) -> void:
	if not d.open:
		return
	d.open = false
	for cc in d.cells:
		w.pathfinder.set_solid(cc, true)
	w._flow_dirty = true


func door_by_eid(eid: int) -> Dictionary:
	for d in doors:
		if d.eid == eid:
			return d
	return {}


func open_door(w: GameWorld, d: Dictionary) -> void:
	if d.open:
		return
	d.open = true
	for cc in d.cells:
		w.pathfinder.set_solid(cc, false)
	w._flow_dirty = true
	w._emit({"type": "door_open", "pos": Vector2(d.cells[0]) + Vector2(0.5, 0.5), "eid": d.eid})


## État des objets interactifs (coop : envoyé au 2e joueur).
func inter_state() -> Array:
	return [doors.map(func(d: Dictionary) -> bool: return d.open), terminals.map(func(t: Dictionary) -> Array: return [t.progress, t.done]),
			prisoners.map(func(p: Dictionary) -> bool: return p.freed), pickups.map(func(k: Dictionary) -> bool: return k.taken),
			shields.map(func(s: Dictionary) -> bool: return s.active)]


func apply_inter_state(a: Array) -> void:
	for i in mini(doors.size(), a[0].size()):
		doors[i].open = a[0][i]
	for i in mini(terminals.size(), a[1].size()):
		terminals[i].progress = a[1][i][0]
		terminals[i].done = a[1][i][1]
	for i in mini(prisoners.size(), a[2].size()):
		prisoners[i].freed = a[2][i]
	for i in mini(pickups.size(), a[3].size()):
		pickups[i].taken = a[3][i]
	for i in mini(shields.size(), a[4].size()):
		shields[i].active = a[4][i]


## Cibles prioritaires des ennemis : convois alliés en route, puis bâtiments à défendre.
func focus_targets(w: GameWorld) -> Array:
	var out: Array = []
	for cv in convoys:
		if cv.state == "go":
			var u := w.unit_by_id(int(cv.uid))
			if u != null and u.alive:
				out.append(u)
	if not out.is_empty():
		return out
	for id in defend_ids:
		var s := w.site_by_id(id)
		if s != null and s.alive:
			out.append(s)
	return out
