class_name ScenarioCheck
extends RefCounted
## Validation du scénario : [erreurs bloquantes, avertissements].

## Paramètres obligatoires (vide = -1 ou []) par élément.
const REQUIRED := {
	"objective": {"hold": ["zone"], "prevent": ["zone"], "reach": ["zone"], "route": ["zones"],
			"control": ["zones"], "interact": ["targets"], "compound": ["children"]},
	"event": {"enter_zone": ["zone"], "leave_zone": ["zone"], "spotted": ["obj"]},
	"action": {"activate": ["obj"], "remove": ["obj"], "move": ["obj", "zone"], "heal": ["obj"], "immobilize": ["obj"], "build": ["zone"],
			"destroy": ["obj"], "behavior": ["obj"], "door_open": ["obj"], "door_close": ["obj"], "marker": ["obj"],
			"obj_reveal": ["objective"], "obj_hide": ["objective"], "obj_complete": ["objective"], "obj_fail": ["objective"],
			"var_set": ["var"], "var_add": ["var"], "var_reset": ["var"], "trigger_enable": ["trigger"], "trigger_run": ["trigger"]},
	"cond": {"alive": ["obj"], "dead": ["obj"], "in_zone": ["zone"], "zone_control": ["zone"], "objective": ["objective"],
			"var": ["var"], "obj_state": ["obj"]},
}


static func check(doc: EditorDoc) -> Array:
	var errors: Array[String] = []
	var warns: Array[String] = []
	var sc: Dictionary = doc.scenario
	var objs: Array = sc.get("objectives", [])
	var trigs: Array = sc.get("triggers", [])
	var vars: Array = sc.get("variables", [])
	var obj_ids := objs.map(func(o: Dictionary) -> String: return str(o.id))
	var trig_ids := trigs.map(func(t: Dictionary) -> String: return str(t.id))
	var var_names := vars.map(func(v: Dictionary) -> String: return str(v.name))
	var ctx := {"doc": doc, "obj_ids": obj_ids, "trig_ids": trig_ids, "var_names": var_names, "errors": errors}
	for o: Dictionary in objs:
		var where := "Objectif « %s »" % o.name
		_check_item(ctx, where, o, REQUIRED.objective.get(str(o.type), []))
		for a in o.get("after", []) + o.get("children", []):
			if not obj_ids.has(str(a)):
				errors.append("%s : objectif lié introuvable" % where)
		if o.get("type", "") == "destroy" and o.get("what", "targets") == "targets" and o.get("targets", []).is_empty():
			errors.append("%s : choisis les objets à détruire" % where)
		if o.get("type", "") == "escort":
			if int(o.get("obj", -1)) < 0 and not _has(doc, "vip", ""):
				errors.append("%s : aucune unité escortée (pose un VIP ou choisis une unité)" % where)
			if int(o.get("zone", -1)) < 0 and not _has(doc, "zone", "goal"):
				errors.append("%s : aucune destination (pose une zone d'arrivée ou choisis une zone)" % where)
		if o.get("type", "") == "capture" and o.get("zones", []).is_empty() and not _has(doc, "zone", "capture"):
			errors.append("%s : aucune zone de prise sur la carte" % where)
		if o.get("type", "") == "condition":
			_check_cond(ctx, where, o.get("cond", {}))
		if str(o.get("start", "visible")) == "hidden":
			var revealed := trigs.any(func(t: Dictionary) -> bool:
				return (t.get("actions", []) + t.get("else", [])).any(func(a: Dictionary) -> bool:
					return a.get("type", "") in ["obj_reveal", "obj_complete", "obj_fail"] and str(a.get("objective", "")) == str(o.id)))
			if not revealed:
				warns.append("%s : caché, mais aucun déclencheur ne le révèle" % where)
	for t: Dictionary in trigs:
		var where := "Déclencheur « %s »" % t.name
		var ev: Dictionary = t.get("event", {})
		var req: Array = REQUIRED.event.get(str(ev.get("type", "")), []).duplicate()
		if ev.get("who", "") == "obj":
			req.append("obj")
		_check_item(ctx, where, ev, req)
		if str(ev.get("type", "")).begins_with("objective_") and str(ev.get("objective", "")) != "" and not obj_ids.has(str(ev.objective)):
			errors.append("%s : objectif introuvable" % where)
		if ev.get("type", "") == "var_changed" and str(ev.get("var", "")) != "" and not var_names.has(str(ev["var"])):
			errors.append("%s : variable introuvable" % where)
		_check_cond(ctx, where, t.get("cond", {}))
		for a: Dictionary in t.get("actions", []) + t.get("else", []):
			_check_item(ctx, "%s, action « %s »" % [where, ScenarioDefs.ACTIONS.get(str(a.get("type", "")), {}).get("label", "?")], a,
					REQUIRED.action.get(str(a.get("type", "")), []))
		if t.get("actions", []).is_empty() and t.get("else", []).is_empty():
			warns.append("%s : aucune action" % where)
		if not t.get("enabled", true):
			var woken := trigs.any(func(x: Dictionary) -> bool:
				return (x.get("actions", []) + x.get("else", [])).any(func(a: Dictionary) -> bool:
					return a.get("type", "") in ["trigger_enable", "trigger_run"] and str(a.get("trigger", "")) == str(t.id)))
			if not woken:
				warns.append("%s : désactivé et jamais réactivé, il ne se déclenchera pas" % where)
	var all := JSON.stringify(trigs) + JSON.stringify(objs)
	for v: Dictionary in vars:
		if not all.contains('"%s"' % v.name) and not all.contains("$%s" % v.name) and not all.contains("{%s}" % v.name):
			warns.append("Variable « %s » jamais utilisée" % v.name)
	for e: Dictionary in doc.entities:
		if e.kind == "zone" and str(e.get("role", "")) in ["extraction", "passage", "trigger"] and not _uses(all, int(e.id)):
			warns.append("%s : zone jamais utilisée par un objectif ou un déclencheur" % e.name)
		if e.get("absent", false) and not _activated(trigs, int(e.id)):
			warns.append("%s : absent au départ, mais aucun déclencheur ne le fait apparaître" % e.name)
		if str(e.get("behavior", "")) == "wait" and not _activated(trigs, int(e.id)):
			warns.append("%s : attend un événement, mais aucun déclencheur ne le réveille" % e.name)
	_check_waves(doc, trigs, obj_ids, errors, warns)
	_check_factions(doc, trigs, errors)
	# Victoire / défaite
	var rules: Dictionary = sc.get("rules", {})
	var actions_all: Array = []
	for t: Dictionary in trigs:
		actions_all.append_array(t.get("actions", []) + t.get("else", []))
	var has_victory_action := actions_all.any(func(a: Dictionary) -> bool: return a.get("type", "") == "victory")
	if str(rules.get("victory", "objectives")) == "manual" and not has_victory_action:
		errors.append("Aucune condition de victoire : ajoute l'action « Victoire » à un déclencheur")
	if not objs.is_empty() and str(rules.get("victory", "objectives")) == "objectives" \
			and not objs.any(func(o: Dictionary) -> bool: return o.get("kind", "main") == "main") and not has_victory_action:
		errors.append("Aucun objectif principal : la mission ne peut pas être gagnée")
	if (not objs.is_empty() or str(rules.get("victory", "")) == "manual") and not bool(rules.get("defeat_base", true)) \
			and not bool(rules.get("defeat_main_failed", true)) and not actions_all.any(func(a: Dictionary) -> bool: return a.get("type", "") == "defeat"):
		warns.append("Aucune condition de défaite : la mission ne peut pas être perdue")
	return [errors, warns]


static func _has(doc: EditorDoc, kind: String, role: String) -> bool:
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


static func _check_item(ctx: Dictionary, where: String, it: Dictionary, required: Array) -> void:
	var doc: EditorDoc = ctx.doc
	var errors: Array = ctx.errors
	for k in required:
		var v: Variant = it.get(k, -1)
		var empty: bool = v == null or (v is Array and v.is_empty()) or (v is String and v == "") or ((v is int or v is float) and int(v) < 0)
		if empty:
			errors.append("%s : paramètre « %s » à remplir" % [where, k])
	for k in ["obj", "zone", "target"]:
		var v: Variant = it.get(k, -1)
		if (v is int or v is float) and int(v) >= 0 and doc.entity_by_id(int(v)).is_empty():
			errors.append("%s : objet référencé introuvable" % where)
		if v is String and (v as String).begins_with("$") and not ctx.var_names.has((v as String).substr(1)):
			errors.append("%s : variable %s introuvable" % [where, v])
	for k in ["targets", "zones", "fail_dead"]:
		for x in it.get(k, []):
			if doc.entity_by_id(int(x)).is_empty():
				errors.append("%s : objet référencé introuvable" % where)
	if it.has("objective") and str(it.objective) != "" and not ctx.obj_ids.has(str(it.objective)):
		errors.append("%s : objectif introuvable" % where)
	if it.has("trigger") and str(it.trigger) != "" and not ctx.trig_ids.has(str(it.trigger)):
		errors.append("%s : déclencheur introuvable" % where)
	if it.has("var") and str(it["var"]) != "" and not ctx.var_names.has(str(it["var"])):
		errors.append("%s : variable introuvable" % where)


static func _check_cond(ctx: Dictionary, where: String, node: Dictionary) -> void:
	for c: Dictionary in node.get("items", []):
		var req: Array = REQUIRED.cond.get(str(c.get("type", "")), []).duplicate()
		if c.get("who", "") == "obj":
			req.append("obj")
		_check_item(ctx, where + ", condition", c, req)


static func _check_waves(doc: EditorDoc, trigs: Array, obj_ids: Array, errors: Array[String], warns: Array[String]) -> void:
	var plan: Dictionary = doc.wave_plan
	var list: Array = plan.get("list", [])
	var ids := list.map(func(w: Dictionary) -> String: return str(w.get("id", "")))
	var acts: Array = []
	for t: Dictionary in trigs:
		acts.append_array(t.get("actions", []) + t.get("else", []))
	for t: Dictionary in trigs:
		var ev: Dictionary = t.get("event", {})
		if str(ev.get("type", "")) in ["wave_started", "wave_ended"] and str(ev.get("wave", "")) != "" and not ids.has(str(ev.wave)):
			errors.append("Déclencheur « %s » : vague introuvable" % t.name)
	for a: Dictionary in acts:
		if str(a.get("type", "")) in ["wave_launch", "wave_stop"] and str(a.get("wave", "")) != "" and not ids.has(str(a.wave)):
			errors.append("Action « %s » : vague introuvable" % ScenarioDefs.ACTIONS[a.type].label)
	if str(plan.get("mode", "auto")) != "custom":
		return
	if list.is_empty():
		warns.append("Vagues personnalisées : la liste est vide")
	var spawns := {}
	for y in doc.rows.size():
		for x in doc.rows[y].length():
			if doc.rows[y][x] == "S":
				spawns["%d,%d" % [x, y]] = true
	for w: Dictionary in list:
		var where := "Vague « %s »" % w.get("name", "")
		var start := str(w.get("start", "auto"))
		if w.get("groups", []).is_empty():
			warns.append("%s : aucun ennemi" % where)
		if start == "objective" and not obj_ids.has(str(w.get("objective", ""))):
			errors.append("%s : choisis l'objectif qui la lance" % where)
		if start == "trigger" and not acts.any(func(a: Dictionary) -> bool: return a.get("type", "") == "wave_launch" and str(a.get("wave", "")) == str(w.id)):
			warns.append("%s : lancée par un déclencheur, mais aucun ne la lance" % where)
		if str(w.get("behavior", "")) == "attack_target" and doc.entity_by_id(int(w.get("target", -1))).is_empty():
			errors.append("%s : choisis la cible à attaquer" % where)
		if str(w.get("behavior", "")) == "attack_zone" and doc.entity_by_id(int(w.get("zone", -1))).is_empty():
			errors.append("%s : choisis la zone à attaquer" % where)
		for g: Dictionary in w.get("groups", []):
			if str(g.get("spawn", "")) != "" and not spawns.has(str(g.spawn)):
				warns.append("%s : un point d'apparition n'existe plus (toutes les apparitions seront utilisées)" % where)
				break


static func _check_factions(doc: EditorDoc, trigs: Array, errors: Array[String]) -> void:
	var f := Factions.new(doc.factions)
	var known := f.ids().map(func(x: Array) -> String: return x[0])
	for e: Dictionary in doc.entities:
		if not e.has("faction"):
			continue
		var want := "enemy" if str(e.kind) in ["enemy", "structure"] else "player"
		if not known.has(str(e.faction)):
			errors.append("« %s » : faction introuvable" % e.get("name", ""))
		elif f.camp(str(e.faction)) != want:
			errors.append("« %s » : la faction %s est dans l'autre camp" % [e.get("name", ""), f.name_of(str(e.faction))])
	for w: Dictionary in doc.wave_plan.get("list", []):
		if w.has("faction") and (not known.has(str(w.faction)) or f.camp(str(w.faction)) != "enemy"):
			errors.append("Vague « %s » : faction introuvable ou du camp du joueur" % w.get("name", ""))
	for t: Dictionary in trigs:
		var items: Array = [t.get("event", {})]
		items.append_array(t.get("actions", []) + t.get("else", []))
		items.append_array(t.get("cond", {}).get("items", []))
		for it: Dictionary in items:
			for k in ["a", "b", "faction"]:
				var v := str(it.get(k, ""))
				if v != "" and str(it.get("type", "")) in ["relation_changed", "relation", "faction_of", "set_relation", "set_faction", "spawn"] and not known.has(v):
					errors.append("Déclencheur « %s » : faction introuvable" % t.name)

