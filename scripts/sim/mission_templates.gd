class_name MissionTemplates
extends RefCounted
## Les 7 types de mission sont des modèles : chacun génère ses objectifs et déclencheurs,
## marqués "tpl": true, que l'on peut ensuite modifier dans l'éditeur.
##
## Les objets du modèle se réfèrent à la carte de façon générique (« le VIP », « les zones de prise »,
## « le réglage de l'onglet Mission ») : poser ou déplacer ces objets ne les casse pas.

const SUMMARY := {
	"waves": "◆ Repousser toutes les vagues",
	"survive": "◆ Tenir la durée choisie",
	"destroy_base": "◆ Détruire toutes les bases ennemies",
	"convoy": "◆ Détruire les convois ennemis",
	"escort": "◆ Escorter le VIP jusqu'à la zone d'arrivée",
	"escort_defend": "◆ Faire arriver les convois alliés",
	"capture": "◆ Prendre toutes les positions",
}


## Objectifs, déclencheurs et règles générés pour un type de mission.
static func build(mission: Dictionary, entities: Array) -> Dictionary:
	var t := str(mission.get("type", "waves"))
	if not Mission.TYPES.has(t):
		t = "waves"
	var objs: Array = []
	var trig: Array = []
	match t:
		"waves":
			objs.append(_obj("Repousser toutes les vagues", "survive_waves", {"waves": 0}))
		"survive":
			objs.append(_obj("Tenir jusqu'à l'évacuation", "survive_time", {"time": 0.0}))
			var total := float(mission.get("time", 300.0))
			if total >= 120.0:
				var tr := _trig("Dernière minute", {"type": "time", "seconds": total - 60.0})
				tr.actions.append({"type": "alert", "text": "Plus qu'une minute !"})
				trig.append(tr)
		"destroy_base":
			objs.append(_obj("Détruire la base ennemie", "destroy", {"what": "bases", "targets": [], "count": 0}))
		"convoy":
			objs.append(_obj("Détruire les convois ennemis", "convoys_destroyed", {"count": 0}))
		"escort":
			var o := _obj("Escorter le VIP jusqu'à la zone d'arrivée", "escort", {"obj": -1, "zone": -1})
			o.desc = "Si le VIP est tué, la mission est perdue."
			objs.append(o)
		"escort_defend":
			objs.append(_obj("Faire arriver les convois alliés", "convoys", {"count": 0}))
			var tr := _trig("Convoi arrivé", {"type": "convoy_arrived"})
			tr.once = false
			tr.actions.append({"type": "notify", "text": "Convoi arrivé à destination"})
			trig.append(tr)
		"capture":
			objs.append(_obj("Prendre les positions", "capture", {"zones": [], "need": 0, "time": 0.0, "obj": -1}))
	if _has_defend(entities):
		objs.append(_defend_obj())
	for i in objs.size():
		objs[i].id = "tpl_o%d" % (i + 1)
	for i in trig.size():
		trig[i].id = "tpl_t%d" % (i + 1)
	return {"objectives": objs, "triggers": trig}


static func _obj(name: String, type: String, params: Dictionary) -> Dictionary:
	var o := {"id": "", "name": name, "desc": "", "kind": "main", "start": "visible", "after": [], "type": type,
			"deadline": 0.0, "fail_dead": [], "reward": {"metal": 0, "essence": 0}, "tpl": true}
	o.merge(ScenarioDefs.defaults(ScenarioDefs.OBJECTIVE_TYPES[type].params))
	for k in params:
		o[k] = params[k]
	return o


static func _trig(name: String, event: Dictionary) -> Dictionary:
	var t := ScenarioDefs.new_trigger("")
	t.name = name
	t.event = event
	t.tpl = true
	return t


static func _defend_obj() -> Dictionary:
	var o := _obj("Défendre les bâtiments", "protect", {"targets": [], "time": 0.0})
	o.desc = "Un bâtiment à défendre détruit = défaite."
	return o


static func _has_defend(entities: Array) -> bool:
	return entities.any(func(e: Dictionary) -> bool: return str(e.get("kind", "")) == "defend")


## Le scénario d'une mission sans objectifs reçoit ceux de son type (missions d'avant la livraison 4,
## campagne). Renvoie une copie ; `data` n'est pas modifié.
static func ensure(data: Dictionary, mission: Dictionary, entities: Array) -> Dictionary:
	var sc: Dictionary = data.duplicate(true) if data != null else {}
	var rules: Dictionary = sc.get("rules", {})
	if sc.get("objectives", []).is_empty() and str(rules.get("victory", "objectives")) != "manual":
		var gen := build(mission, entities)
		sc.objectives = gen.objectives
		var trig: Array = sc.get("triggers", [])
		trig.append_array(gen.triggers)
		sc.triggers = trig
	elif _has_defend(entities) and not _covers_defend(sc.get("objectives", [])):
		# Un bâtiment « à défendre » fait toujours perdre s'il est détruit.
		var o := _defend_obj()
		o.id = _free_id(sc.objectives, "tpl_defend")
		sc.objectives.append(o)
	return sc


static func _covers_defend(objs: Array) -> bool:
	return objs.any(func(o: Dictionary) -> bool: return str(o.get("type", "")) == "protect" and o.get("targets", []).is_empty())


static func _free_id(objs: Array, base: String) -> String:
	var id := base
	var n := 2
	while objs.any(func(o: Dictionary) -> bool: return str(o.get("id", "")) == id):
		id = "%s%d" % [base, n]
		n += 1
	return id


## Remplace les objets du modèle (tpl) par ceux du type actuel. Les objectifs et déclencheurs
## ajoutés à la main sont conservés. Modifie `sc` sur place.
static func regenerate(sc: Dictionary, mission: Dictionary, entities: Array) -> void:
	var gen := build(mission, entities)
	var objs: Array = sc.get("objectives", []).filter(func(o: Dictionary) -> bool: return not o.get("tpl", false))
	var trig: Array = sc.get("triggers", []).filter(func(t: Dictionary) -> bool: return not t.get("tpl", false))
	var new_objs: Array = gen.objectives
	for o: Dictionary in new_objs:
		o.id = _free_id(objs, str(o.id))
	var new_trig: Array = gen.triggers
	for t: Dictionary in new_trig:
		t.id = _free_id(trig, str(t.id))
	new_objs.append_array(objs)
	new_trig.append_array(trig)
	sc.objectives = new_objs
	sc.triggers = new_trig


static func has_template(sc: Dictionary) -> bool:
	return sc.get("objectives", []).any(func(o: Dictionary) -> bool: return o.get("tpl", false))
