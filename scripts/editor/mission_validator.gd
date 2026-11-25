class_name MissionValidator
extends RefCounted
## Validation complète d'une mission dans l'éditeur.
##
## Chaque problème est un dictionnaire :
##   {"lvl": "error" | "warn", "text": String, "go": {"tab": ..., "id": ..., "cell": [x, y]}}
## Les erreurs empêchent de tester ; les avertissements signalent un oubli probable.
## « go » dit où aller pour corriger : un objet de la carte, un objectif, un déclencheur, une vague,
## une case, ou un onglet.

## Paramètres obligatoires (vide = -1 ou []) par élément du scénario.
const REQUIRED := {
	"objective": {"hold": ["zone"], "prevent": ["zone"], "reach": ["zone"], "route": ["zones"],
			"control": ["zones"], "interact": ["targets"], "compound": ["children"]},
	"event": {"enter_zone": ["zone"], "leave_zone": ["zone"], "spotted": ["obj"]},
	"action": {"activate": ["obj"], "remove": ["obj"], "move": ["obj", "zone"], "heal": ["obj"], "immobilize": ["obj"], "build": ["zone"],
			"destroy": ["obj"], "behavior": ["obj"], "door_open": ["obj"], "door_close": ["obj"], "marker": ["obj"],
			"obj_reveal": ["objective"], "obj_hide": ["objective"], "obj_complete": ["objective"], "obj_fail": ["objective"],
			"var_set": ["var"], "var_add": ["var"], "var_reset": ["var"], "trigger_enable": ["trigger"], "trigger_run": ["trigger"],
			"set_faction": ["obj"]},
	"cond": {"alive": ["obj"], "dead": ["obj"], "in_zone": ["zone"], "zone_control": ["zone"], "objective": ["objective"],
			"var": ["var"], "obj_state": ["obj"], "faction_of": ["obj"]},
}
## Objets qui marchent : pas sur un rocher, un mur ou l'eau.
const WALKERS := ["enemy", "ally_unit", "vip", "escortee", "prisoner"]

var doc: EditorDoc
var grid: GameGrid
var out: Array = []


static func run(d: EditorDoc, g: GameGrid) -> Array:
	var v := MissionValidator.new()
	v.doc = d
	v.grid = g
	v._map()
	v._objects()
	v._mission_type()
	v._params()
	v._scenario()
	v._waves()
	v._factions()
	# Sans doublons, erreurs d'abord.
	var seen := {}
	var res: Array = []
	for lvl in ["error", "warn"]:
		for it: Dictionary in v.out:
			var k := str(it.text)
			if it.lvl == lvl and not seen.has(k):
				seen[k] = true
				res.append(it)
	return res


static func errors(list: Array) -> Array:
	return list.filter(func(i: Dictionary) -> bool: return i.lvl == "error")


static func warnings(list: Array) -> Array:
	return list.filter(func(i: Dictionary) -> bool: return i.lvl == "warn")


func _err(text: String, go := {}) -> void:
	out.append({"lvl": "error", "text": text, "go": go})


func _warn(text: String, go := {}) -> void:
	out.append({"lvl": "warn", "text": text, "go": go})


static func at_cell(c: Vector2i) -> Dictionary:
	return {"tab": "map", "cell": [c.x, c.y]}


func at_ent(e: Dictionary) -> Dictionary:
	return {"tab": "objects", "id": int(e.get("id", -1))}


# --- Carte ---------------------------------------------------------------------------------

func _map() -> void:
	var waves_on: bool = Mission.new(doc.mission).waves_enabled() or not doc.wave_plan.get("list", []).is_empty() and str(doc.wave_plan.get("mode", "")) == "custom"
	if grid.base_cells.size() != 9:
		_err("Il faut une base de 3×3 (onglet Carte, Base joueur 1)", {"tab": "map"})
	if grid.spawn_points.is_empty() and waves_on:
		_err("Il faut au moins un point d'apparition pour les vagues", {"tab": "map"})
	if grid.metal_deposits.is_empty():
		_err("Il faut au moins un gisement de métal", {"tab": "map"})
	if grid.base_cells.size() != 9:
		return
	var pf := Pathfinder.new(grid)
	for sp in grid.spawn_points:
		if pf.find_path_to_adjacent(sp, grid.base_cells).is_empty():
			_err("L'apparition (%d, %d) n'a aucun chemin vers la base" % [sp.x, sp.y], at_cell(sp))
	var start: Array[Vector2i] = pf.free_cells_around(grid.base_cells)
	if start.is_empty():
		_err("La base est entièrement entourée d'obstacles", at_cell(grid.base_cells[4]))
		return
	for m in grid.metal_deposits:
		if pf.find_path_to_adjacent(start[0], [m] as Array[Vector2i]).is_empty():
			_err("Le métal (%d, %d) est inaccessible depuis la base" % [m.x, m.y], at_cell(m))
			break
	for m in grid.essence_deposits:
		if pf.find_path_to_adjacent(start[0], [m] as Array[Vector2i]).is_empty():
			_warn("L'essence (%d, %d) est inaccessible depuis la base" % [m.x, m.y], at_cell(m))
			break
	if not grid.base2_cells.is_empty():
		if grid.base2_cells.size() != 9:
			_err("La base du joueur 2 doit faire 3×3", at_cell(grid.base2_cells[0]))
		elif pf.find_path_to_adjacent(start[0], grid.base2_cells).is_empty():
			_err("La base du joueur 2 n'est pas reliée à la base principale", at_cell(grid.base2_cells[4]))


# --- Objets --------------------------------------------------------------------------------

func _objects() -> void:
	var names := {}
	var cells := {}
	for e: Dictionary in doc.entities:
		var c := Vector2i(int(e.cell[0]), int(e.cell[1]))
		var nm := str(e.get("name", ""))
		if c.x < 0 or c.y < 0 or c.x >= doc.width() or c.y >= doc.height():
			_err("%s : hors de la carte" % nm, at_ent(e))
			continue
		if nm != "":
			if names.has(nm):
				_warn("Deux objets s'appellent « %s » : les déclencheurs risquent de viser le mauvais" % nm, at_ent(e))
			names[nm] = true
		if str(e.kind) in WALKERS and not grid.is_walkable(c):
			_err("%s : posé sur un obstacle (rocher, mur ou eau)" % nm, at_ent(e))
		if str(e.kind) in WALKERS + ["structure", "ally_tower", "defend", "building", "door", "generator", "shield", "terminal", "pickup"]:
			var k := "%d,%d" % [c.x, c.y]
			if cells.has(k):
				_warn("%s et %s sont sur la même case" % [cells[k], nm], at_ent(e))
			cells[k] = nm
		if str(e.kind) == "deco" and not _deco_exists(str(e.get("sprite", ""))):
			_warn("Image de décor introuvable : %s" % e.get("sprite", ""), at_ent(e))
		var beh := str(e.get("behavior", ""))
		if beh == "patrol" and e.get("patrol", []).size() < 2:
			_warn("%s : la patrouille a besoin d'au moins 2 points" % nm, at_ent(e))
		if beh in ["defend", "attack_target", "attack_zone", "follow"] and int(e.get("target", -1)) < 0:
			_warn("%s : choisis sa cible dans sa fiche" % nm, at_ent(e))
		for key in ["target", "link"]:
			if int(e.get(key, -1)) >= 0 and doc.entity_by_id(int(e[key])).is_empty():
				_err("%s : l'objet lié n'existe plus" % nm, at_ent(e))
		if e.kind == "shield" and int(e.get("link", -1)) < 0:
			_warn("%s : sans générateur, il reste actif toute la partie" % nm, at_ent(e))


static func _has_terrain(g: GameGrid, kind: String) -> bool:
	var need: Callable = {"train": g.is_rail, "convoy": g.is_road, "boat": g.is_water}[kind]
	for y in g.height:
		for x in g.width:
			if need.call(Vector2i(x, y)):
				return true
	return false


static func _deco_exists(sprite: String) -> bool:
	for p in ["res://assets/deco/%s.png" % sprite, "user://deco/%s.png" % sprite]:
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return true
	return false


# --- Type de mission ------------------------------------------------------------------------

func _mission_type() -> void:
	var kinds := {}
	var wps := 0
	for e: Dictionary in doc.entities:
		kinds[str(e.kind) + ":" + str(e.get("type", e.get("role", "")))] = true
		kinds[e.kind] = true
		if e.kind == "waypoint":
			wps += 1
	var m := {"tab": "mission"}
	match str(doc.mission.get("type", "waves")):
		"destroy_base":
			if not kinds.has("structure:e_hq"):
				_warn("Pose une BASE ENNEMIE (onglet Objets)", m)
		"escort":
			if not kinds.has("vip") or not kinds.has("zone:goal"):
				_warn("Il faut un VIP et une ZONE D'ARRIVÉE", m)
		"escort_defend":
			if wps < (1 if kinds.has("escortee") else 2):
				_warn("Trace le trajet du convoi : au moins 2 POINTS DE PASSAGE", m)
		"capture":
			if not kinds.has("zone:capture"):
				_warn("Pose au moins une ZONE DE PRISE", m)
		"convoy":
			if wps == 1:
				_warn("Un trajet a besoin d'au moins 2 POINTS DE PASSAGE", m)
			var kind := str(doc.mission.get("convoy_kind", "convoy"))
			if wps < 2 and not _has_terrain(grid, kind):
				_warn("Les convois ont besoin de %s" % {"train": "rails", "convoy": "route", "boat": "eau"}[kind], m)
	for o: Dictionary in doc.objectives:
		if not _has_terrain(grid, o.type):
			_warn("%s sans %s" % [Balance.OBJECTIVES[o.type].name, {"train": "rails", "convoy": "route", "boat": "eau"}[o.type]], m)


# --- Paramètres de mission ------------------------------------------------------------------

func _params() -> void:
	var p: Dictionary = doc.mission.get("params", {})
	var m := {"tab": "mission"}
	if doc.name.strip_edges() == "" or doc.name == "Nouvelle carte":
		_warn("Donne un nom à la mission (en haut à gauche)", m)
	if str(p.get("preview", "")) == "":
		_warn("Pas d'image d'aperçu (Mission → Aperçu → Générer depuis la carte)", m)
	if str(doc.mission.get("briefing", "")).strip_edges() == "":
		_warn("Briefing vide : le joueur ne saura pas quoi faire", m)
	var players := str(p.get("players", "solo"))
	if players != "solo" and grid.base2_cells.size() != 9:
		_err("Mission jouable en coop : pose la base du joueur 2 (onglet Carte)", {"tab": "map"})
	var limit := float(p.get("time_limit", 0.0))
	if limit > 0.0:
		var surv := float(doc.mission.get("time", 0.0)) if str(doc.mission.get("type", "")) == "survive" else 0.0
		if surv > 0.0 and limit <= surv:
			_err("La durée maximale (%d s) est plus courte que la survie demandée (%d s)" % [int(limit), int(surv)], m)
		if limit < 60.0:
			_warn("Durée maximale très courte (%d s)" % int(limit), m)
	if int(p.get("metal", -1)) == 0 and int(p.get("workers", -1)) == 0:
		_warn("Aucun métal ni ouvrier au départ : le joueur ne pourra rien construire", m)


# --- Scénario -------------------------------------------------------------------------------

func _scenario() -> void:
	var sc: Dictionary = doc.scenario
	var objs: Array = sc.get("objectives", [])
	var trigs: Array = sc.get("triggers", [])
	var vars: Array = sc.get("variables", [])
	var ctx := {"obj_ids": objs.map(func(o: Dictionary) -> String: return str(o.id)),
			"trig_ids": trigs.map(func(t: Dictionary) -> String: return str(t.id)),
			"var_names": vars.map(func(v: Dictionary) -> String: return str(v.name))}
	for o: Dictionary in objs:
		var where := "Objectif « %s »" % o.name
		var go := {"tab": "objectives", "id": str(o.id)}
		_check_item(ctx, where, go, o, REQUIRED.objective.get(str(o.type), []))
		for a in o.get("after", []) + o.get("children", []):
			if not ctx.obj_ids.has(str(a)):
				_err("%s : objectif lié introuvable" % where, go)
		if o.get("type", "") == "destroy" and o.get("what", "targets") == "targets" and o.get("targets", []).is_empty():
			_err("%s : choisis les objets à détruire" % where, go)
		if o.get("type", "") == "escort":
			if int(o.get("obj", -1)) < 0 and not _has("vip", ""):
				_err("%s : aucune unité escortée (pose un VIP ou choisis une unité)" % where, go)
			if int(o.get("zone", -1)) < 0 and not _has("zone", "goal"):
				_err("%s : aucune destination (pose une zone d'arrivée ou choisis une zone)" % where, go)
		if o.get("type", "") == "capture" and o.get("zones", []).is_empty() and not _has("zone", "capture"):
			_err("%s : aucune zone de prise sur la carte" % where, go)
		if o.get("type", "") == "condition":
			_check_cond(ctx, where, go, o.get("cond", {}))
		if str(o.get("start", "visible")) == "hidden" and not _acts(trigs).any(func(a: Dictionary) -> bool:
				return a.get("type", "") in ["obj_reveal", "obj_complete", "obj_fail"] and str(a.get("objective", "")) == str(o.id)):
			_warn("%s : caché, mais aucun déclencheur ne le révèle" % where, go)
	for t: Dictionary in trigs:
		var where := "Déclencheur « %s »" % t.name
		var go := {"tab": "events", "id": str(t.id)}
		var ev: Dictionary = t.get("event", {})
		var req: Array = REQUIRED.event.get(str(ev.get("type", "")), []).duplicate()
		if ev.get("who", "") == "obj":
			req.append("obj")
		_check_item(ctx, where, go, ev, req)
		if str(ev.get("type", "")).begins_with("objective_") and str(ev.get("objective", "")) != "" and not ctx.obj_ids.has(str(ev.objective)):
			_err("%s : objectif introuvable" % where, go)
		if ev.get("type", "") == "var_changed" and str(ev.get("var", "")) != "" and not ctx.var_names.has(str(ev["var"])):
			_err("%s : variable introuvable" % where, go)
		_check_cond(ctx, where, go, t.get("cond", {}))
		for a: Dictionary in t.get("actions", []) + t.get("else", []):
			_check_item(ctx, "%s, action « %s »" % [where, ScenarioDefs.ACTIONS.get(str(a.get("type", "")), {}).get("label", "?")], go, a,
					REQUIRED.action.get(str(a.get("type", "")), []))
		if t.get("actions", []).is_empty() and t.get("else", []).is_empty():
			_warn("%s : aucune action" % where, go)
		if not t.get("enabled", true) and not _acts(trigs).any(func(a: Dictionary) -> bool:
				return a.get("type", "") in ["trigger_enable", "trigger_run"] and str(a.get("trigger", "")) == str(t.id)):
			_warn("%s : désactivé et jamais réactivé, il ne se déclenchera pas" % where, go)
	var all := JSON.stringify(trigs) + JSON.stringify(objs) + JSON.stringify(doc.wave_plan)
	for v: Dictionary in vars:
		if not all.contains('"%s"' % v.name) and not all.contains("$%s" % v.name) and not all.contains("{%s}" % v.name):
			_warn("Variable « %s » jamais utilisée" % v.name, {"tab": "events", "view": "variables", "id": str(v.name)})
	for e: Dictionary in doc.entities:
		if e.kind == "zone" and str(e.get("role", "")) in ["extraction", "passage", "trigger"] and not _uses(all, int(e.id)):
			_warn("%s : zone jamais utilisée par un objectif ou un déclencheur" % e.name, at_ent(e))
		if e.get("absent", false) and not _activated(trigs, int(e.id)):
			_warn("%s : absent au départ, mais aucun déclencheur ne le fait apparaître" % e.name, at_ent(e))
		if str(e.get("behavior", "")) == "wait" and not _activated(trigs, int(e.id)):
			_warn("%s : attend un événement, mais aucun déclencheur ne le réveille" % e.name, at_ent(e))
	# Victoire / défaite
	var rules: Dictionary = sc.get("rules", {})
	var acts := _acts(trigs)
	var has_victory := acts.any(func(a: Dictionary) -> bool: return a.get("type", "") == "victory")
	var m := {"tab": "objectives"}
	if str(rules.get("victory", "objectives")) == "manual" and not has_victory:
		_err("Aucune condition de victoire : ajoute l'action « Victoire » à un déclencheur", m)
	if not objs.is_empty() and str(rules.get("victory", "objectives")) == "objectives" \
			and not objs.any(func(o: Dictionary) -> bool: return o.get("kind", "main") == "main") and not has_victory:
		_err("Aucun objectif principal : la mission ne peut pas être gagnée", m)
	var limit := float(doc.mission.get("params", {}).get("time_limit", 0.0)) > 0.0
	if (not objs.is_empty() or str(rules.get("victory", "")) == "manual") and not bool(rules.get("defeat_base", true)) \
			and not bool(rules.get("defeat_main_failed", true)) and not limit and not acts.any(func(a: Dictionary) -> bool: return a.get("type", "") == "defeat"):
		_warn("Aucune condition de défaite : la mission ne peut pas être perdue", m)


func _acts(trigs: Array) -> Array:
	var acts: Array = []
	for t: Dictionary in trigs:
		acts.append_array(t.get("actions", []) + t.get("else", []))
	return acts


func _has(kind: String, role: String) -> bool:
	return doc.entities.any(func(e: Dictionary) -> bool: return e.kind == kind and (role == "" or str(e.get("role", "")) == role))


static func _uses(all: String, id: int) -> bool:
	for pat in [':%d,' % id, ':%d}' % id, '[%d,' % id, '[%d]' % id, ',%d]' % id, ',%d,' % id]:
		if all.contains(pat):
			return true
	return false


static func _activated(trigs: Array, id: int) -> bool:
	return trigs.any(func(t: Dictionary) -> bool:
		return (t.get("actions", []) + t.get("else", [])).any(func(a: Dictionary) -> bool:
			return a.get("type", "") in ["activate", "behavior"] and int(a.get("obj", -1)) == id))


func _check_item(ctx: Dictionary, where: String, go: Dictionary, it: Dictionary, required: Array) -> void:
	for k in required:
		var v: Variant = it.get(k, -1)
		var empty: bool = v == null or (v is Array and v.is_empty()) or (v is String and v == "") or ((v is int or v is float) and int(v) < 0)
		if empty:
			_err("%s : paramètre « %s » à remplir" % [where, k], go)
	for k in ["obj", "zone", "target"]:
		var v: Variant = it.get(k, -1)
		if (v is int or v is float) and int(v) >= 0 and doc.entity_by_id(int(v)).is_empty():
			_err("%s : objet référencé introuvable" % where, go)
		if v is String and (v as String).begins_with("$") and not ctx.var_names.has((v as String).substr(1)):
			_err("%s : variable %s introuvable" % [where, v], go)
	for k in ["targets", "zones", "fail_dead"]:
		for x in it.get(k, []):
			if doc.entity_by_id(int(x)).is_empty():
				_err("%s : objet référencé introuvable" % where, go)
	if it.has("objective") and str(it.objective) != "" and not ctx.obj_ids.has(str(it.objective)):
		_err("%s : objectif introuvable" % where, go)
	if it.has("trigger") and str(it.trigger) != "" and not ctx.trig_ids.has(str(it.trigger)):
		_err("%s : déclencheur introuvable" % where, go)
	if it.has("var") and str(it["var"]) != "" and not ctx.var_names.has(str(it["var"])):
		_err("%s : variable introuvable" % where, go)


func _check_cond(ctx: Dictionary, where: String, go: Dictionary, node: Dictionary) -> void:
	for c: Dictionary in node.get("items", []):
		var req: Array = REQUIRED.cond.get(str(c.get("type", "")), []).duplicate()
		if c.get("who", "") == "obj":
			req.append("obj")
		_check_item(ctx, where + ", condition", go, c, req)


# --- Vagues ---------------------------------------------------------------------------------

func _waves() -> void:
	var plan: Dictionary = doc.wave_plan
	var list: Array = plan.get("list", [])
	var ids := list.map(func(w: Dictionary) -> String: return str(w.get("id", "")))
	var trigs: Array = doc.scenario.get("triggers", [])
	var obj_ids: Array = doc.scenario.get("objectives", []).map(func(o: Dictionary) -> String: return str(o.id))
	for t: Dictionary in trigs:
		var go := {"tab": "events", "id": str(t.id)}
		var ev: Dictionary = t.get("event", {})
		if str(ev.get("type", "")) in ["wave_started", "wave_ended"] and str(ev.get("wave", "")) != "" and not ids.has(str(ev.wave)):
			_err("Déclencheur « %s » : vague introuvable" % t.name, go)
		for a: Dictionary in t.get("actions", []) + t.get("else", []):
			if str(a.get("type", "")) in ["wave_launch", "wave_stop"] and str(a.get("wave", "")) != "" and not ids.has(str(a.wave)):
				_err("Déclencheur « %s » : vague introuvable" % t.name, go)
	if str(plan.get("mode", "auto")) != "custom":
		return
	if list.is_empty():
		_warn("Vagues personnalisées : la liste est vide", {"tab": "waves"})
	var spawns := {}
	for sp in grid.spawn_points:
		spawns["%d,%d" % [sp.x, sp.y]] = true
	var acts := _acts(trigs)
	for w: Dictionary in list:
		var where := "Vague « %s »" % w.get("name", "")
		var go := {"tab": "waves", "id": str(w.get("id", ""))}
		var start := str(w.get("start", "auto"))
		if w.get("groups", []).is_empty():
			_warn("%s : aucun ennemi" % where, go)
		if start == "objective" and not obj_ids.has(str(w.get("objective", ""))):
			_err("%s : choisis l'objectif qui la lance" % where, go)
		if start == "trigger" and not acts.any(func(a: Dictionary) -> bool: return a.get("type", "") == "wave_launch" and str(a.get("wave", "")) == str(w.id)):
			_warn("%s : lancée par un déclencheur, mais aucun ne la lance" % where, go)
		if str(w.get("behavior", "")) == "attack_target" and doc.entity_by_id(int(w.get("target", -1))).is_empty():
			_err("%s : choisis la cible à attaquer" % where, go)
		if str(w.get("behavior", "")) == "attack_zone" and doc.entity_by_id(int(w.get("zone", -1))).is_empty():
			_err("%s : choisis la zone à attaquer" % where, go)
		for g: Dictionary in w.get("groups", []):
			if str(g.get("spawn", "")) != "" and not spawns.has(str(g.spawn)):
				_warn("%s : un point d'apparition n'existe plus (toutes les apparitions seront utilisées)" % where, go)
				break


# --- Factions -------------------------------------------------------------------------------

func _factions() -> void:
	var f := Factions.new(doc.factions)
	var known := f.ids().map(func(x: Array) -> String: return x[0])
	for e: Dictionary in doc.entities:
		if not e.has("faction"):
			continue
		var want := "enemy" if str(e.kind) in ["enemy", "structure"] else "player"
		if not known.has(str(e.faction)):
			_err("« %s » : faction introuvable" % e.get("name", ""), at_ent(e))
		elif f.camp(str(e.faction)) != want:
			_err("« %s » : la faction %s est dans l'autre camp" % [e.get("name", ""), f.name_of(str(e.faction))], at_ent(e))
	for w: Dictionary in doc.wave_plan.get("list", []):
		if w.has("faction") and (not known.has(str(w.faction)) or f.camp(str(w.faction)) != "enemy"):
			_err("Vague « %s » : faction introuvable ou du camp du joueur" % w.get("name", ""), {"tab": "waves", "id": str(w.get("id", ""))})
	for t: Dictionary in doc.scenario.get("triggers", []):
		var items: Array = [t.get("event", {})]
		items.append_array(t.get("actions", []) + t.get("else", []))
		items.append_array(t.get("cond", {}).get("items", []))
		for it: Dictionary in items:
			for k in ["a", "b", "faction"]:
				var v := str(it.get(k, ""))
				if v != "" and str(it.get("type", "")) in ["relation_changed", "relation", "faction_of", "set_relation", "set_faction", "spawn"] and not known.has(v):
					_err("Déclencheur « %s » : faction introuvable" % t.name, {"tab": "events", "id": str(t.id)})
