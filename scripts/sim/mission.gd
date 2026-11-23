class_name Mission
extends RefCounted
## Mission d'une carte : type, paramètres, entités posées dans l'éditeur, et règles de victoire.
##
## Types :
##   waves          défense classique : survivre à toutes les vagues
##   survive        tenir `time` secondes
##   destroy_base   détruire toutes les bases ennemies (structures "e_hq")
##   convoy         détruire `need` convois sur `count` (train, camions ou bateau)
##   escort         amener l'unité VIP dans la zone d'arrivée
##   escort_defend  protéger le véhicule allié jusqu'au bout de son trajet (points de passage)
##   capture        tenir toutes les zones de prise `time` secondes chacune
##
## Entités (liste de dictionnaires, toutes avec "kind" et "cell") :
##   structure  {type}                    structure ennemie (Balance.ENEMY_STRUCTURES)
##   enemy      {type, hold}              unité ennemie en garde (hold = ne bouge pas)
##   ally_tower {type, level}             tourelle alliée déjà construite
##   ally_unit  {type, hold}              unité alliée déjà présente
##   vip        {type}                    unité à escorter (mission escort)
##   escortee   {}                        véhicule allié à protéger (mission escort_defend)
##   waypoint   {order}                   trajet du véhicule allié
##   zone       {role, radius}            "goal" (arrivée) ou "capture"
##   deco       {sprite, block}           décor (block = bloque le passage)

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
var zones: Array[Dictionary] = [] # {pos, radius, role, progress, captured}
var vip: Unit = null
var escortee: Unit = null
var escort_route: Array[Vector2i] = []
var escort_i := 0
var decos: Array[Dictionary] = []
var convoy_total := 0


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


func setup(w: GameWorld) -> void:
	if not waves_enabled():
		w.waves.timer = INF
	elif type == "survive":
		w.waves.infinite = true # les vagues continuent jusqu'à la fin du chrono
	var waypoints: Array = []
	for ent: Dictionary in entities:
		var c := Vector2i(int(ent.cell[0]), int(ent.cell[1])) if ent.cell is Array else Vector2i(ent.cell)
		var at := Vector2(c) + Vector2(0.5, 0.5)
		match str(ent.get("kind", "")):
			"structure":
				if not Balance.ENEMY_STRUCTURES.has(ent.type):
					continue
				var e := Enemy.create(ent.type, at, 1.0)
				var sz := int(Balance.ENEMY_STRUCTURES[ent.type].size)
				e.pos = Vector2(c) + Vector2(sz, sz) * 0.5
				e.guard_pos = e.pos
				e.id = w._next_enemy_id
				w._next_enemy_id += 1
				w.enemies.append(e)
				for cc in w._structure_cells(e):
					w.pathfinder.set_solid(cc, true)
				w._flow_dirty = true
			"enemy":
				if not Balance.ENEMIES.has(ent.type):
					continue
				var e := Enemy.create(ent.type, at, 1.0)
				e.mode = "static" if ent.get("hold", false) else "guard"
				e.guard_pos = at
				e.id = w._next_enemy_id
				w._next_enemy_id += 1
				w.enemies.append(e)
			"ally_tower":
				# Posée gratuitement : on avance le coût puis on le retire avec place().
				var cost := Content.building(ent.type)
				w.metal += int(cost.metal)
				w.essence += int(cost.essence)
				if w.can_place(ent.type, c) != "":
					w.metal -= int(cost.metal)
					w.essence -= int(cost.essence)
					continue
				var s := w.place(ent.type, c)
				if s != null:
					s.level = clampi(int(ent.get("level", 1)), 1, BuildSite.MAX_LEVEL)
					s.work_done = s.work_needed
					w._finish_site(s)
					s.max_hp = int(s.stats().hp)
					s.hp = s.max_hp
			"ally_unit", "vip", "escortee":
				var t := str(ent.get("type", "soldier")) if ent.kind != "escortee" else "escort_truck"
				if not Content.UNITS.has(t):
					continue
				var u := Unit.create(t, at)
				u.id = w._next_unit_id
				w._next_unit_id += 1
				w.units.append(u)
				if ent.kind == "ally_unit" and ent.get("hold", false):
					u.order = Unit.Order.HOLD
				if ent.kind == "vip":
					u.vip = true
					vip = u
				elif ent.kind == "escortee":
					u.locked = true
					escortee = u
			"waypoint":
				waypoints.append([int(ent.get("order", waypoints.size())), c])
			"zone":
				zones.append({"pos": at, "radius": float(ent.get("radius", 2.5)), "role": str(ent.get("role", "capture")),
						"progress": 0.0, "captured": false})
			"deco":
				decos.append({"sprite": str(ent.get("sprite", "")), "cell": c, "block": bool(ent.get("block", false))})
				if ent.get("block", false):
					w.pathfinder.set_solid(c, true)
					w._flow_dirty = true
	waypoints.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for wp in waypoints:
		escort_route.append(wp[1])
	if type == "convoy":
		var kind := str(data.get("convoy_kind", "convoy"))
		convoy_total = int(data.get("convoy_count", 3))
		var start := float(data.get("convoy_start", 20.0))
		var gap := float(data.get("convoy_interval", 40.0))
		for i in convoy_total:
			w.objectives.append({"type": kind, "wave": 0, "time": start + gap * i, "state": "pending", "destroyed": 0,
					"total": int(Balance.OBJECTIVES[kind].count), "main": true})


func tick(w: GameWorld, delta: float) -> void:
	# Véhicule allié à protéger : suit ses points de passage.
	if escortee != null and escortee.alive and escort_i < escort_route.size():
		var goal := escort_route[escort_i]
		if escortee.cell() == goal or escortee.pos.distance_to(Vector2(goal) + Vector2(0.5, 0.5)) < 0.6:
			escort_i += 1
		elif escortee.path.is_empty() or escortee.repath_timer <= 0.0:
			escortee.repath_timer = 1.0
			escortee.path = w._path_toward(escortee.cell(), goal)
		escortee.repath_timer -= delta
		w._follow_path(escortee, ESCORTEE_SPEED, delta)
	# Zones de prise de position : des alliés dedans et aucun ennemi hostile.
	for z in zones:
		if z.role != "capture" or z.captured:
			continue
		var r2: float = z.radius * z.radius
		var mine := w.units.any(func(u: Unit) -> bool: return u.alive and u.pos.distance_squared_to(z.pos) <= r2)
		var theirs := w.enemies.any(func(e: Enemy) -> bool: return e.hp > 0 and not e.neutral and e.pos.distance_squared_to(z.pos) <= r2)
		if mine and not theirs:
			z.progress += delta
			if z.progress >= float(data.get("time", 30.0)):
				z.captured = true
				w._emit({"type": "zone_captured", "pos": z.pos})
		elif theirs:
			z.progress = maxf(0.0, z.progress - delta * 0.5)


## "won", "lost" ou "" tant que la mission continue (la perte de la base est gérée par le monde).
func result(w: GameWorld) -> String:
	match type:
		"waves":
			if w.waves.finished() and not w.enemies.any(func(x: Enemy) -> bool: return not x.neutral and x.mode == "march"):
				return "won"
		"survive":
			if w.time >= float(data.get("time", 300.0)):
				return "won"
		"destroy_base":
			if not w.enemies.any(func(x: Enemy) -> bool: return x.type == "e_hq" and x.hp > 0):
				return "won"
		"convoy":
			var main := w.objectives.filter(func(o: Dictionary) -> bool: return o.get("main", false))
			var done := main.filter(func(o: Dictionary) -> bool: return o.state == "done").size()
			var failed := main.filter(func(o: Dictionary) -> bool: return o.state == "failed").size()
			var need := int(data.get("convoy_need", convoy_total))
			if done >= need:
				return "won"
			if failed > convoy_total - need:
				return "lost"
		"escort":
			if vip == null:
				return ""
			if not vip.alive:
				return "lost"
			for z in zones:
				if z.role == "goal" and vip.pos.distance_to(z.pos) <= z.radius:
					return "won"
		"escort_defend":
			if escortee == null:
				return ""
			if not escortee.alive:
				return "lost"
			if escort_i >= escort_route.size():
				return "won"
		"capture":
			var caps := zones.filter(func(z: Dictionary) -> bool: return z.role == "capture")
			if not caps.is_empty() and caps.all(func(z: Dictionary) -> bool: return z.captured):
				return "won"
	return ""


## Texte de l'objectif principal (HUD).
func objective_text(w: GameWorld) -> String:
	match type:
		"waves":
			return "Survivre aux %d vagues" % w.waves.total
		"survive":
			var left := maxf(0.0, float(data.get("time", 300.0)) - w.time)
			return "Tenir encore %d:%02d" % [int(left) / 60, int(left) % 60]
		"destroy_base":
			var n := w.enemies.filter(func(x: Enemy) -> bool: return x.type == "e_hq" and x.hp > 0).size()
			return "Détruire la base ennemie (%d restante%s)" % [n, "s" if n > 1 else ""]
		"convoy":
			var main := w.objectives.filter(func(o: Dictionary) -> bool: return o.get("main", false))
			var done := main.filter(func(o: Dictionary) -> bool: return o.state == "done").size()
			return "Détruire les convois : %d/%d" % [done, int(data.get("convoy_need", convoy_total))]
		"escort":
			return "Amener l'unité escortée dans la zone d'arrivée"
		"escort_defend":
			return "Protéger le convoi allié : étape %d/%d" % [mini(escort_i + 1, escort_route.size()), escort_route.size()]
		"capture":
			var caps := zones.filter(func(z: Dictionary) -> bool: return z.role == "capture")
			var done := caps.filter(func(z: Dictionary) -> bool: return z.captured).size()
			return "Prendre les positions : %d/%d" % [done, caps.size()]
	return ""
