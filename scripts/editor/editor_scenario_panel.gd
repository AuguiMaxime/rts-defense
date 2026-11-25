class_name EditorScenarioPanel
extends VBoxContainer
## Onglets OBJECTIFS, ÉVÉNEMENTS et VAGUES : liste à gauche en haut, formulaire en dessous.
## Toutes les modifications passent par l'historique de l'éditeur (annuler / rétablir).

const KIND_LABELS := [["main", "Principal"], ["secondary", "Secondaire"], ["optional", "Facultatif"]]
const START_LABELS := [["visible", "Visible dès le début"], ["hidden", "Caché (révélé par un déclencheur)"], ["after", "Après d'autres objectifs"]]

var ed # MissionEditor
var mode := "objectives" # ou "events", "waves"
var view := "triggers" # events : triggers / variables / graph
var selected := ""
var _list: VBoxContainer
var _form: VBoxContainer
var _form_scroll: ScrollContainer
var _view_buttons := {}
var _graph: Control


func _init(editor, m: String) -> void:
	ed = editor
	mode = m
	add_theme_constant_override("separation", 6)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if mode == "waves":
		view = "list"
	if mode in ["events", "waves"]:
		var vh := EditorUi.hbox(3)
		var views := [["triggers", "Déclencheurs"], ["variables", "Variables"], ["graph", "Dépendances"]] if mode == "events" \
				else [["list", "Vagues"], ["spawns", "Points d'apparition"]]
		for pair in views:
			var b := EditorUi.button(pair[1], "", true)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var v: String = pair[0]
			b.pressed.connect(func() -> void:
				view = v
				refresh())
			_view_buttons[v] = b
			vh.add_child(b)
		add_child(vh)
	var tools := EditorUi.hbox(3)
	var add := MenuButton.new()
	add.text = "+ Ajouter ▾"
	add.flat = false
	add.focus_mode = Control.FOCUS_NONE
	add.custom_minimum_size = Vector2(0, EditorUi.BTN_H)
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_add_menu(add.get_popup())
	tools.add_child(add)
	for a in [["Dupliquer", _duplicate], ["Supprimer", _delete], ["↑", func() -> void: _move(-1)], ["↓", func() -> void: _move(1)]]:
		var b := EditorUi.button(a[0], "", false, 34 if a[0].length() == 1 else 0.0)
		b.pressed.connect(a[1])
		tools.add_child(b)
	add_child(tools)
	_list_tools = tools
	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(0, 170)
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = EditorUi.vbox(2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(_list)
	add_child(ls)
	_list_scroll = ls
	add_child(EditorUi.sep())
	_form_scroll = ScrollContainer.new()
	_form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_form = EditorUi.vbox(6)
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form_scroll.add_child(_form)
	add_child(_form_scroll)
	_graph = ScenarioGraph.new()
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph.visible = false
	add_child(_graph)


var _list_tools: Control
var _list_scroll: Control


func _sc() -> Dictionary:
	return ed.doc.scenario


func _items() -> Array:
	if mode == "waves":
		if not ed.doc.wave_plan.has("list"):
			ed.doc.wave_plan["list"] = []
		return ed.doc.wave_plan.list
	var key := "objectives" if mode == "objectives" else ("variables" if view == "variables" else "triggers")
	if not _sc().has(key):
		_sc()[key] = []
	return _sc()[key]


## Modifie le scénario avec annulation. rebuild = reconstruire la liste et le formulaire.
func edit(label: String, change: Callable, rebuild := false) -> void:
	if not ed.doc.scenario.has("objectives"):
		ed.doc.scenario["objectives"] = []
	if ed.history.record(label, change):
		if rebuild:
			ed.after_change()
		else:
			ed.mark_dirty()
			_refresh_list()


# --- Ajout, suppression, ordre -------------------------------------------------------------

func _fill_add_menu(pm: PopupMenu) -> void:
	pm.add_theme_font_size_override("font_size", 14)
	pm.clear()
	if mode == "objectives":
		var cat := ""
		var i := 0
		for p in ScenarioDefs.PRESETS:
			if p[0] != cat:
				cat = p[0]
				pm.add_separator(cat)
			pm.add_item(p[1], i)
			i += 1
		pm.id_pressed.connect(func(id: int) -> void: _add_objective(ScenarioDefs.PRESETS[id]))
	elif mode == "waves":
		pm.add_item("Vague vide", 0)
		pm.add_item("Vague de boss avec escorte", 1)
		pm.add_item("Embuscade (lancée par un déclencheur)", 2)
		pm.add_item("Harcèlement (répétée)", 3)
		pm.add_separator()
		pm.add_item("Remplacer par les vagues automatiques actuelles", 10)
		pm.id_pressed.connect(_add_wave)
	else:
		pm.add_item("Déclencheur vide", 0)
		pm.add_item("Variable", 1)
		pm.add_separator("Modèles")
		pm.add_item("Message au début de la mission", 2)
		pm.add_item("Renforts quand le joueur entre dans une zone", 3)
		pm.add_item("Compte à rebours puis vague", 4)
		pm.id_pressed.connect(_add_event_item)


func _new_id(prefix: String, list: Array) -> String:
	var n := 1
	var ids := list.map(func(x: Dictionary) -> String: return str(x.get("id", "")))
	while ids.has("%s%d" % [prefix, n]):
		n += 1
	return "%s%d" % [prefix, n]


func _add_objective(preset: Array) -> void:
	var o := ScenarioDefs.new_objective(preset, _new_id("o", _sc().get("objectives", [])))
	if preset[1] == "Défendre la base":
		o.targets = []
	edit("Ajouter un objectif", func() -> void:
		if not _sc().has("objectives"):
			_sc()["objectives"] = []
		_sc().objectives.append(o), true)
	selected = o.id
	refresh()


func _add_event_item(id: int) -> void:
	if id == 1:
		view = "variables"
		var v := {"name": _new_var_name(), "type": "int", "value": 0}
		edit("Ajouter une variable", func() -> void:
			if not _sc().has("variables"):
				_sc()["variables"] = []
			_sc().variables.append(v), true)
		refresh()
		return
	view = "triggers"
	var t := ScenarioDefs.new_trigger(_new_id("t", _sc().get("triggers", [])))
	match id:
		2:
			t.name = "Message d'introduction"
			t.actions = [{"type": "message", "speaker": "QG", "text": "Commandant, la colonie compte sur vous.", "seconds": 6.0}]
		3:
			t.name = "Renforts ennemis"
			t.event = {"type": "enter_zone", "zone": -1, "who": "player", "obj": -1}
			t.actions = [{"type": "alert", "text": "Embuscade !"}, ScenarioDefs.new_item(ScenarioDefs.ACTIONS, "spawn")]
		4:
			t.name = "Compte à rebours"
			t.actions = [{"type": "timer_start", "timer": "assaut", "seconds": 60.0, "label": "Assaut dans", "show": true}]
			var t2 := ScenarioDefs.new_trigger(_new_id("t", _sc().get("triggers", []) + [t]))
			t2.name = "Assaut"
			t2.event = {"type": "timer_end", "timer": "assaut"}
			t2.actions = [{"type": "alert", "text": "Assaut !"}, {"type": "wave_launch"}]
			edit("Ajouter des déclencheurs", func() -> void:
				if not _sc().has("triggers"):
					_sc()["triggers"] = []
				_sc().triggers.append(t)
				_sc().triggers.append(t2), true)
			selected = t.id
			refresh()
			return
	edit("Ajouter un déclencheur", func() -> void:
		if not _sc().has("triggers"):
			_sc()["triggers"] = []
		_sc().triggers.append(t), true)
	selected = t.id
	refresh()


func _new_var_name() -> String:
	var names: Array = _sc().get("variables", []).map(func(v: Dictionary) -> String: return str(v.name))
	var n := 1
	while names.has("var%d" % n):
		n += 1
	return "var%d" % n


func _sel_index() -> int:
	var list := _items()
	for i in list.size():
		if str(list[i].get("id", list[i].get("name", ""))) == selected:
			return i
	return -1


func _duplicate() -> void:
	var i := _sel_index()
	if i < 0:
		return
	var list := _items()
	var c: Dictionary = list[i].duplicate(true)
	c.erase("tpl")
	if c.has("id"):
		c.id = _new_id({"objectives": "o", "waves": "w"}.get(mode, "t"), list)
		c.name = str(c.name) + " (copie)"
		selected = c.id
	else:
		c.name = _new_var_name()
		selected = c.name
	edit("Dupliquer", func() -> void: _items().insert(i + 1, c), true)


func _delete() -> void:
	var i := _sel_index()
	if i < 0:
		return
	var it: Dictionary = _items()[i]
	var refs := _references(str(it.get("id", it.get("name", ""))))
	var go := func() -> void:
		edit("Supprimer « %s »" % it.get("name", ""), func() -> void: _items().remove_at(i), true)
		selected = ""
		refresh()
	if refs > 0:
		ed._confirm("Supprimer ?", "« %s » est utilisé à %d endroit%s. Les liens deviendront invalides (signalés par la validation)." % [it.get("name", ""), refs, "s" if refs > 1 else ""], "Supprimer", go)
	else:
		go.call()


## Nombre d'utilisations d'un objectif / déclencheur / variable ailleurs dans le scénario.
func _references(key: String) -> int:
	var txt := JSON.stringify(_sc())
	var n := txt.count('"%s"' % key) + txt.count('"$%s"' % key)
	return maxi(0, n - 1)


func _move(d: int) -> void:
	var i := _sel_index()
	var list := _items()
	if i < 0 or i + d < 0 or i + d >= list.size():
		return
	edit("Réordonner", func() -> void:
		var x: Dictionary = list[i]
		list.remove_at(i)
		list.insert(i + d, x), true)


# --- Liste ------------------------------------------------------------------------------------

func refresh() -> void:
	for k in _view_buttons:
		(_view_buttons[k] as Button).set_pressed_no_signal(k == view)
	var graph := mode == "events" and view == "graph"
	var flat := mode == "waves" and (view == "spawns" or str(ed.doc.wave_plan.get("mode", "auto")) != "custom")
	_graph.visible = graph
	_form_scroll.visible = not graph
	_list_scroll.visible = not graph and not flat
	_list_tools.visible = not graph and not flat
	if graph:
		_graph.call("setup", _sc())
		return
	if _sel_index() < 0:
		var list := _items()
		selected = str(list[0].get("id", list[0].get("name", ""))) if not list.is_empty() else ""
	_refresh_list()
	_build_form()


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var list := _items()
	if list.is_empty():
		_list.add_child(EditorUi.muted("Rien pour l'instant : « + Ajouter » en haut." if mode == "events" or view != "variables" else "Aucune variable.", 13))
	for it: Dictionary in list:
		var key := str(it.get("id", it.get("name", "")))
		var b := EditorUi.button(_row_text(it), "", true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.button_pressed = key == selected
		b.custom_minimum_size.y = 30
		if it.get("enabled", true) == false:
			b.modulate = Color(1, 1, 1, 0.5)
		b.pressed.connect(func() -> void:
			selected = key
			refresh())
		_list.add_child(b)


func _row_text(it: Dictionary) -> String:
	if mode == "waves":
		var n := 0
		for g: Dictionary in it.get("groups", []):
			n += int(g.get("count", 0)) * (1 + int(g.get("escort", 0)))
		var st: String = {"auto": "après %ds" % int(it.get("delay", 0)), "clear": "éliminée +%ds" % int(it.get("delay", 0)),
				"trigger": "déclencheur", "objective": "objectif"}.get(str(it.get("start", "auto")), "")
		var rep_txt := "  · ×%d" % (1 + int(it.get("repeat", 0))) if int(it.get("repeat", 0)) > 0 else ""
		return "%s  ·  %s  ·  %d ennemis%s" % [it.get("name", ""), st, n, rep_txt]
	if mode == "objectives":
		var mark: String = {"main": "◆", "secondary": "◇", "optional": "○"}.get(str(it.get("kind", "main")), "◆")
		var hid := "  (caché)" if it.get("start", "visible") != "visible" else ""
		return "%s %s%s%s" % [mark, it.get("name", ""), hid, "  · modèle" if it.get("tpl", false) else ""]
	if view == "variables":
		return "%s  ·  %s = %s" % [it.name, _label_of(ScenarioDefs.VAR_TYPES, str(it.get("type", "int"))), str(it.get("value", ""))]
	var ev: Dictionary = it.get("event", {})
	var lbl: String = ScenarioDefs.EVENTS.get(str(ev.get("type", "")), {}).get("label", "?")
	return "%s%s  ·  QUAND %s · %d action%s" % [it.get("name", ""), " (modèle)" if it.get("tpl", false) else "", lbl.to_lower(), it.get("actions", []).size(), "s" if it.get("actions", []).size() > 1 else ""]


static func _label_of(items: Array, key: String) -> String:
	for p in items:
		if p[0] == key:
			return p[1]
	return key


# --- Formulaires -----------------------------------------------------------------------------

func _build_form() -> void:
	for c in _form.get_children():
		c.queue_free()
	if mode == "objectives":
		_rules_form()
	if mode == "waves":
		_waves_mode_form()
		if view == "spawns":
			_spawns_form()
			return
		if str(ed.doc.wave_plan.get("mode", "auto")) != "custom":
			return
	var i := _sel_index()
	if i < 0:
		return
	var it: Dictionary = _items()[i]
	if mode == "objectives":
		_objective_form(it)
	elif mode == "waves":
		_wave_form(it)
	elif view == "variables":
		_variable_form(it)
	else:
		_trigger_form(it)


func _rules_form() -> void:
	var r: Dictionary = _sc().get("rules", {})
	var g := EditorUi.grid(2, 6)
	var vic := _option([["objectives", "Tous les objectifs principaux réussis"], ["manual", "Seulement par l'action Victoire"]], str(r.get("victory", "objectives")),
			func(v: String) -> void: _set_rule("victory", v))
	_row(g, "Victoire", vic)
	var base := _toggle(bool(r.get("defeat_base", true)), "Base détruite = défaite", "Base détruite : on continue", func(v: bool) -> void: _set_rule("defeat_base", v))
	_row(g, "Défaite", base)
	var mainf := _toggle(bool(r.get("defeat_main_failed", true)), "Objectif principal échoué = défaite", "Objectif principal échoué : on continue",
			func(v: bool) -> void: _set_rule("defeat_main_failed", v))
	_row(g, "", mainf)
	_form.add_child(EditorUi.section("Règles de la mission"))
	_form.add_child(g)
	if _sc().get("objectives", []).is_empty():
		_form.add_child(EditorUi.muted("Sans objectif, la mission suit les règles de son type (onglet Mission)."))
	_form.add_child(EditorUi.sep())


func _set_rule(key: String, v: Variant) -> void:
	edit("Règles", func() -> void:
		if not _sc().has("rules"):
			_sc()["rules"] = {}
		_sc().rules[key] = v)


func _objective_form(o: Dictionary) -> void:
	var id: String = o.id
	var getter := func() -> Dictionary: return _find("objectives", id)
	_form.add_child(EditorUi.section("Objectif"))
	var g := EditorUi.grid(2, 6)
	_row(g, "Nom", _text(str(o.name), func(t: String) -> void: _setp(getter, "name", t)))
	_row(g, "Importance", _option(KIND_LABELS, str(o.get("kind", "main")), func(v: String) -> void: _setp(getter, "kind", v)))
	_row(g, "Départ", _option(START_LABELS, str(o.get("start", "visible")), func(v: String) -> void: _setp(getter, "start", v, true)))
	_form.add_child(g)
	var desc := TextEdit.new()
	desc.placeholder_text = "Description affichée sous l'objectif (facultatif)"
	desc.text = str(o.get("desc", ""))
	desc.custom_minimum_size = Vector2(0, 54)
	desc.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	desc.focus_exited.connect(func() -> void: _setp(getter, "desc", desc.text.strip_edges()))
	_form.add_child(desc)
	if o.get("start", "") == "after":
		_list_param(getter, ["after", "objectives", "Après ces objectifs", []])
	_form.add_child(EditorUi.section("Type : " + str(ScenarioDefs.OBJECTIVE_TYPES[o.type].label)))
	var tg := EditorUi.grid(2, 6)
	var types := []
	for k in ScenarioDefs.OBJECTIVE_TYPES:
		types.append([k, ScenarioDefs.OBJECTIVE_TYPES[k].label])
	_row(tg, "Changer de type", _option(types, str(o.type), func(v: String) -> void:
		edit("Type d'objectif", func() -> void:
			var x: Dictionary = getter.call()
			x.type = v
			for k in ScenarioDefs.defaults(ScenarioDefs.OBJECTIVE_TYPES[v].params):
				if not x.has(k):
					x[k] = ScenarioDefs.defaults(ScenarioDefs.OBJECTIVE_TYPES[v].params)[k], true)))
	_form.add_child(tg)
	_params(getter, ScenarioDefs.OBJECTIVE_TYPES[o.type].params)
	_form.add_child(EditorUi.section("Échec et récompense"))
	var fg := EditorUi.grid(2, 6)
	_row(fg, "Délai maximum (s, 0 = aucun)", _spin(float(o.get("deadline", 0.0)), 0, 7200, 5, func(v: float) -> void: _setp(getter, "deadline", v)))
	var rw: Dictionary = o.get("reward", {})
	_row(fg, "Récompense : métal", _spin(float(rw.get("metal", 0)), 0, 99999, 50, func(v: float) -> void: _set_sub(getter, "reward", "metal", int(v))))
	_row(fg, "Récompense : essence", _spin(float(rw.get("essence", 0)), 0, 99999, 50, func(v: float) -> void: _set_sub(getter, "reward", "essence", int(v))))
	_form.add_child(fg)
	_list_param(getter, ["fail_dead", "objs", "Échoue si l'un de ces objets est détruit", []])
	_form.add_child(EditorUi.muted("Un objectif caché se révèle avec l'action « Révéler un objectif ». Les objectifs principaux décident de la victoire."))


func _variable_form(v: Dictionary) -> void:
	var name: String = v.name
	var getter := func() -> Dictionary: return _find("variables", name, "name")
	_form.add_child(EditorUi.section("Variable"))
	var g := EditorUi.grid(2, 6)
	_row(g, "Nom", _text(name, func(t: String) -> void:
		var n := t.strip_edges().replace(" ", "_")
		if n == "" or n == name or _sc().variables.any(func(x: Dictionary) -> bool: return x.name == n):
			return
		selected = n
		edit("Renommer la variable", func() -> void:
			getter.call().name = n
			_rename_var(name, n), true)))
	_row(g, "Type", _option(ScenarioDefs.VAR_TYPES, str(v.get("type", "int")), func(x: String) -> void: _setp(getter, "type", x, true)))
	_row(g, "Valeur de départ", _text(str(v.get("value", 0)), func(t: String) -> void: _setp(getter, "value", t if v.get("type", "int") == "text" else (t.to_float() if t.is_valid_float() else t))))
	_form.add_child(g)
	_form.add_child(EditorUi.muted("Utilisable dans les conditions, les actions, et dans les textes avec {%s}. Une référence garde l'identifiant d'un objet : « $%s » dans un champ objet." % [name, name]))


func _rename_var(old: String, n: String) -> void:
	var txt := JSON.stringify(_sc().get("triggers", []))
	txt = txt.replace('"var":"%s"' % old, '"var":"%s"' % n).replace('"$%s"' % old, '"$%s"' % n)
	_sc().triggers = JSON.parse_string(txt)


func _trigger_form(t: Dictionary) -> void:
	var id: String = t.id
	var getter := func() -> Dictionary: return _find("triggers", id)
	_form.add_child(EditorUi.section("Déclencheur"))
	var g := EditorUi.grid(2, 6)
	_row(g, "Nom", _text(str(t.name), func(x: String) -> void: _setp(getter, "name", x)))
	_row(g, "État au départ", _toggle(bool(t.get("enabled", true)), "Actif", "Désactivé", func(v: bool) -> void: _setp(getter, "enabled", v)))
	_row(g, "Exécution", _toggle(bool(t.get("once", true)), "Une seule fois", "À chaque fois", func(v: bool) -> void: _setp(getter, "once", v)))
	_row(g, "Priorité", _spin(float(t.get("priority", 0)), -99, 99, 1, func(v: float) -> void: _setp(getter, "priority", int(v))))
	_row(g, "Délai avant les actions (s)", _spin(float(t.get("delay", 0.0)), 0, 3600, 0.5, func(v: float) -> void: _setp(getter, "delay", v)))
	_form.add_child(g)
	# QUAND
	_form.add_child(_band("QUAND", Ui.CYAN))
	var evs := []
	for k in ScenarioDefs.EVENTS:
		evs.append([k, "%s · %s" % [ScenarioDefs.EVENTS[k].cat, ScenarioDefs.EVENTS[k].label]])
	var ev_get := func() -> Dictionary: return getter.call().event
	_form.add_child(_option(evs, str(t.event.get("type", "start")), func(v: String) -> void:
		edit("Événement", func() -> void: getter.call().event = ScenarioDefs.new_item(ScenarioDefs.EVENTS, v), true)))
	_params(ev_get, ScenarioDefs.EVENTS[str(t.event.get("type", "start"))].params)
	# SI
	_form.add_child(_band("SI", Ui.GOLD))
	_cond_editor(func() -> Dictionary:
		var x: Dictionary = getter.call()
		if not x.has("cond") or x.cond.is_empty():
			x.cond = {"op": "and", "items": []}
		return x.cond)
	# ALORS / SINON
	_form.add_child(_band("ALORS", Ui.GREEN))
	_actions_editor(getter, "actions")
	_form.add_child(_band("SINON (si les conditions sont fausses)", Color(0.75, 0.6, 1.0)))
	_actions_editor(getter, "else")


func _band(text: String, col: Color) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.16)
	sb.border_color = Color(col, 0.6)
	sb.border_width_left = 3
	sb.content_margin_left = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(EditorUi.label(text, 13, col.lerp(Color.WHITE, 0.3)))
	return p


func _cond_editor(getter: Callable) -> void:
	var c: Dictionary = getter.call()
	var h := EditorUi.hbox(4)
	h.add_child(EditorUi.label("Toutes les conditions", 13) if c.get("op", "and") == "and" else EditorUi.label("Au moins une condition", 13))
	var sw := EditorUi.button("ET" if c.get("op", "and") == "and" else "OU", "ET : toutes vraies · OU : une seule suffit", false, 44)
	sw.pressed.connect(func() -> void:
		edit("Conditions ET / OU", func() -> void:
			var x: Dictionary = getter.call()
			x.op = "or" if x.get("op", "and") == "and" else "and", true))
	h.add_child(sw)
	_form.add_child(h)
	var items: Array = c.get("items", [])
	if items.is_empty():
		_form.add_child(EditorUi.muted("Aucune condition : les actions s'exécutent toujours."))
	var conds := []
	for k in ScenarioDefs.CONDITIONS:
		conds.append([k, ScenarioDefs.CONDITIONS[k].label])
	for i in items.size():
		var idx: int = i
		var it_get := func() -> Dictionary: return getter.call().items[idx]
		var it: Dictionary = items[i]
		var row := EditorUi.hbox(3)
		var neg := EditorUi.button("NON", "Inverse la condition", true, 46)
		neg.button_pressed = it.get("not", false)
		neg.pressed.connect(func() -> void: _setp(it_get, "not", neg.button_pressed))
		row.add_child(neg)
		var o := _option(conds, str(it.get("type", "")), func(v: String) -> void:
			edit("Condition", func() -> void: getter.call().items[idx] = ScenarioDefs.new_item(ScenarioDefs.CONDITIONS, v), true))
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(o)
		var x := EditorUi.button("✕", "Retirer", false, 28)
		x.pressed.connect(func() -> void: edit("Retirer une condition", func() -> void: getter.call().items.remove_at(idx), true))
		row.add_child(x)
		_form.add_child(row)
		_params(it_get, ScenarioDefs.CONDITIONS[str(it.type)].params, 12)
	var add := EditorUi.button("+ Condition")
	add.pressed.connect(func() -> void:
		edit("Ajouter une condition", func() -> void: getter.call().items.append(ScenarioDefs.new_item(ScenarioDefs.CONDITIONS, "alive")), true))
	_form.add_child(add)


func _actions_editor(getter: Callable, key: String) -> void:
	var list: Array = getter.call().get(key, [])
	var acts := []
	for k in ScenarioDefs.ACTIONS:
		acts.append([k, "%s · %s" % [ScenarioDefs.ACTIONS[k].cat, ScenarioDefs.ACTIONS[k].label]])
	for i in list.size():
		var idx: int = i
		var a_get := func() -> Dictionary: return getter.call()[key][idx]
		var a: Dictionary = list[i]
		var row := EditorUi.hbox(3)
		row.add_child(EditorUi.label("%d." % (i + 1), 13, EditorUi.SECTION))
		var o := _option(acts, str(a.get("type", "")), func(v: String) -> void:
			edit("Action", func() -> void: getter.call()[key][idx] = ScenarioDefs.new_item(ScenarioDefs.ACTIONS, v), true))
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(o)
		for m in [["↑", -1], ["↓", 1]]:
			var mb := EditorUi.button(m[0], "Déplacer", false, 26)
			var dd: int = m[1]
			mb.pressed.connect(func() -> void:
				var arr: Array = getter.call()[key]
				if idx + dd < 0 or idx + dd >= arr.size():
					return
				edit("Réordonner les actions", func() -> void:
					var y: Dictionary = arr[idx]
					arr.remove_at(idx)
					arr.insert(idx + dd, y), true))
			row.add_child(mb)
		var x := EditorUi.button("✕", "Retirer", false, 26)
		x.pressed.connect(func() -> void: edit("Retirer une action", func() -> void: getter.call()[key].remove_at(idx), true))
		row.add_child(x)
		_form.add_child(row)
		_params(a_get, ScenarioDefs.ACTIONS[str(a.type)].params, 12, str(a.type))
	var add := EditorUi.button("+ Action")
	add.pressed.connect(func() -> void:
		edit("Ajouter une action", func() -> void:
			var x: Dictionary = getter.call()
			if not x.has(key):
				x[key] = []
			x[key].append(ScenarioDefs.new_item(ScenarioDefs.ACTIONS, "message")), true))
	_form.add_child(add)


func _find(list_key: String, id: String, field := "id") -> Dictionary:
	for x: Dictionary in _sc().get(list_key, []):
		if str(x.get(field, "")) == id:
			return x
	return {}


func _setp(getter: Callable, key: String, v: Variant, rebuild := false) -> void:
	edit("Modifier", func() -> void:
		var x: Dictionary = getter.call()
		if v == null:
			x.erase(key)
		else:
			x[key] = v, rebuild)


func _set_sub(getter: Callable, key: String, sub: String, v: Variant) -> void:
	edit("Modifier", func() -> void:
		var x: Dictionary = getter.call()
		if not x.has(key) or not x[key] is Dictionary:
			x[key] = {}
		x[key][sub] = v)


# --- Champs génériques ---------------------------------------------------------------------------

## Formulaire des paramètres d'un élément (événement, condition, action, objectif).
func _params(getter: Callable, params: Array, indent := 0, action := "") -> void:
	var g := EditorUi.grid(2, 6)
	var item: Dictionary = getter.call()
	for p in params:
		var key: String = p[0]
		var type: String = p[1]
		# Champs inutiles selon le reste du formulaire
		if key == "obj" and item.has("who") and item.get("who", "") != "obj":
			continue
		if action == "spawn" and key == "enemy_type" and item.get("team", "enemy") != "enemy":
			continue
		if action == "spawn" and key == "unit_type" and item.get("team", "enemy") == "enemy":
			continue
		if action == "spawn" and key == "behavior" and item.get("team", "enemy") != "enemy":
			continue
		if key == "targets" and item.get("what", "targets") != "targets" and item.has("what"):
			continue
		if key == "count" and item.has("what") and item.get("what", "") != "targets":
			continue
		if key == "n" and item.get("mode", "") != "atleast":
			continue
		if type in ["objs", "zones", "objectives"]:
			_form.add_child(g)
			g = EditorUi.grid(2, 6)
			_list_param(getter, p)
			continue
		if type == "cond":
			_form.add_child(g)
			g = EditorUi.grid(2, 6)
			_form.add_child(EditorUi.muted("Réussi quand cette condition est vraie :"))
			_cond_editor(func() -> Dictionary:
				var x: Dictionary = getter.call()
				if not x.has("cond") or x.cond.is_empty():
					x.cond = {"op": "and", "items": []}
				return x.cond)
			continue
		var ctl := _field(getter, p)
		if ctl != null:
			_row(g, str(p[2]), ctl)
	if g.get_child_count() > 0:
		if indent > 0:
			var m := MarginContainer.new()
			m.add_theme_constant_override("margin_left", indent)
			m.add_child(g)
			_form.add_child(m)
		else:
			_form.add_child(g)


func _field(getter: Callable, p: Array) -> Control:
	var key: String = p[0]
	var type: String = p[1]
	var cur: Variant = getter.call().get(key, p[3])
	var setv := func(v: Variant) -> void: _setp(getter, key, v, key in ["who", "team", "what", "mode", "start"])
	match type:
		"int":
			return _spin(float(cur), -99999, 99999, 1, func(v: float) -> void: setv.call(int(v)))
		"float":
			return _spin(float(cur), -99999, 99999, 0.5, func(v: float) -> void: setv.call(v))
		"text", "timer":
			return _text(str(cur), func(t: String) -> void: setv.call(t))
		"value":
			return _text(str(cur), func(t: String) -> void: setv.call(t.to_float() if t.is_valid_float() else t), "Nombre, texte ou $variable")
		"bool":
			return _toggle(bool(cur), "Oui", "Non", func(v: bool) -> void: setv.call(v))
		"choice":
			return _option(p[4], str(cur), setv)
		"team":
			return _option(ScenarioDefs.TEAM, str(cur), setv)
		"who":
			return _option(ScenarioDefs.WHO, str(cur), setv)
		"cmp":
			return _option(ScenarioDefs.CMP, str(cur), setv)
		"res":
			return _option(ScenarioDefs.RES, str(cur), setv)
		"sound":
			var snd := []
			for k in Sfx.SOUNDS:
				snd.append([k, k])
			return _option(snd, str(cur), setv)
		"enemy_type":
			var l := []
			for k in Balance.ENEMIES:
				l.append([k, str(EditorDoc.ENEMY_NAMES.get(k, k))])
			return _option(l, str(cur), setv)
		"unit_type":
			var l := []
			for k in Content.UNITS:
				if k not in ["worker", "escort_truck"]:
					l.append([k, str(Content.UNITS[k].name)])
			return _option(l, str(cur), setv)
		"build_type":
			var l := []
			for k in Content.TOWER_ORDER:
				l.append([k, str(Content.TOWERS[k].name)])
			for k in Content.BUILDING_ORDER:
				l.append([k, str(Content.building(k).name)])
			return _option(l, str(cur), setv)
		"behavior":
			return _option(ScenarioDefs.ENEMY_BEHAVIORS, str(cur), setv)
		"var":
			var l: Array = _sc().get("variables", []).map(func(v: Dictionary) -> Array: return [v.name, v.name])
			if l.is_empty():
				return EditorUi.label("Crée d'abord une variable", 12, Ui.GOLD)
			return _option(l, str(cur), setv)
		"objective":
			var l: Array = _sc().get("objectives", []).map(func(o: Dictionary) -> Array: return [o.id, o.name])
			if l.is_empty():
				return EditorUi.label("Aucun objectif", 12, Ui.GOLD)
			return _option(l, str(cur), setv)
		"trigger":
			var l: Array = _sc().get("triggers", []).map(func(t: Dictionary) -> Array: return [t.id, t.name])
			return _option(l, str(cur), setv)
		"faction":
			var fl: Array = Factions.new(ed.doc.factions).ids()
			if str(p[3]) == "" or str(p[2]).contains("vide"):
				fl.push_front(["", "—"])
			return _option(fl, str(cur), setv)
		"wave":
			var l: Array = [["", "—"]]
			for wv: Dictionary in ed.doc.wave_plan.get("list", []):
				l.append([wv.id, wv.name])
			if l.size() == 1:
				return EditorUi.label("Aucune vague personnalisée (onglet Vagues)", 12, Ui.MUTED)
			return _option(l, str(cur), setv)
		"obj", "obj_enemy", "obj_player", "zone":
			return _obj_field(getter, key, type, cur)
	return null


static func accept_for(type: String) -> Callable:
	match type:
		"zone", "zones":
			return func(x: Dictionary) -> bool: return x.kind == "zone"
		"obj_enemy":
			return func(x: Dictionary) -> bool: return x.kind in ["enemy", "structure"]
		"obj_player":
			return func(x: Dictionary) -> bool: return x.kind in ["ally_tower", "defend", "building", "ally_unit", "vip"]
	return func(x: Dictionary) -> bool: return x.kind not in ["waypoint", "deco"]


func _obj_field(getter: Callable, key: String, type: String, cur: Variant) -> Control:
	var h := EditorUi.hbox(3)
	var acc := accept_for(type)
	var items := [[-1, "— aucun —"]]
	for e: Dictionary in ed.doc.entities:
		if acc.call(e):
			items.append([int(e.id), str(e.name)])
	for v: Dictionary in _sc().get("variables", []):
		if v.get("type", "") == "ref":
			items.append(["$" + str(v.name), "$" + str(v.name) + " (variable)"])
	var curk: Variant = cur if (cur is String and (cur as String).begins_with("$")) else int(cur)
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(0, EditorUi.BTN_H)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.fit_to_longest_item = false
	o.clip_text = true
	for i in items.size():
		o.add_item(str(items[i][1]), i)
		if items[i][0] == curk:
			o.select(i)
	o.item_selected.connect(func(i: int) -> void: _setp(getter, key, items[i][0]))
	h.add_child(o)
	var pk := EditorUi.button("◎", "Choisir sur la carte", false, 28)
	pk.pressed.connect(func() -> void:
		ed.start_pick_cb(acc, "zone" if type == "zone" else "objet", func(e: Dictionary) -> void:
			_setp(getter, key, int(e.id), true)))
	h.add_child(pk)
	return h


## Liste d'objets / zones / objectifs (ajout, retrait).
func _list_param(getter: Callable, p: Array) -> void:
	var key: String = p[0]
	var type: String = p[1]
	var cur: Array = getter.call().get(key, [])
	_form.add_child(EditorUi.label(str(p[2]), 13))
	for i in cur.size():
		var idx: int = i
		var row := EditorUi.hbox(3)
		var name := ""
		if type == "objectives":
			name = str(_find("objectives", str(cur[i])).get("name", "? " + str(cur[i])))
		else:
			name = str(ed.doc.entity_by_id(int(cur[i])).get("name", "? (supprimé)"))
		var l := EditorUi.label("· " + name, 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		var x := EditorUi.button("✕", "Retirer", false, 26)
		x.pressed.connect(func() -> void: edit("Retirer", func() -> void: getter.call()[key].remove_at(idx), true))
		row.add_child(x)
		_form.add_child(row)
	var h := EditorUi.hbox(3)
	var items := []
	if type == "objectives":
		for o: Dictionary in _sc().get("objectives", []):
			if not cur.has(o.id) and o != getter.call():
				items.append([o.id, o.name])
	else:
		var acc := accept_for(type)
		for e: Dictionary in ed.doc.entities:
			if acc.call(e) and not cur.has(int(e.id)):
				items.append([int(e.id), e.name])
	var add := OptionButton.new()
	add.focus_mode = Control.FOCUS_NONE
	add.custom_minimum_size = Vector2(0, EditorUi.BTN_H)
	add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add.clip_text = true
	add.add_item("+ Ajouter…", 0)
	for i in items.size():
		add.add_item(str(items[i][1]), i + 1)
	add.select(0)
	var append_one := func(v: Variant) -> void:
		edit("Ajouter", func() -> void:
			var x: Dictionary = getter.call()
			if not x.has(key):
				x[key] = []
			if not x[key].has(v):
				x[key].append(v), true)
	add.item_selected.connect(func(i: int) -> void:
		if i > 0:
			append_one.call(items[i - 1][0]))
	h.add_child(add)
	if type != "objectives":
		var pk := EditorUi.button("◎", "Choisir sur la carte (plusieurs clics possibles)", false, 28)
		pk.pressed.connect(func() -> void: ed.start_pick_cb(accept_for(type), "zone" if type == "zones" else "objet", func(e: Dictionary) -> void: append_one.call(int(e.id)), true))
		h.add_child(pk)
	_form.add_child(h)


# --- Petits contrôles ----------------------------------------------------------------------------

func _row(g: GridContainer, label: String, ctl: Control) -> void:
	var l := EditorUi.label(label, 13)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 150
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctl.custom_minimum_size.x = maxf(ctl.custom_minimum_size.x, 190)
	g.add_child(ctl)


func _option(items: Array, cur: String, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(0, EditorUi.BTN_H)
	o.fit_to_longest_item = false
	o.clip_text = true
	o.get_popup().add_theme_font_size_override("font_size", 14)
	for i in items.size():
		o.add_item(str(items[i][1]), i)
		if str(items[i][0]) == cur:
			o.select(i)
	o.item_selected.connect(func(i: int) -> void: cb.call(items[i][0]))
	return o


func _text(cur: String, cb: Callable, placeholder := "") -> LineEdit:
	var e := EditorUi.line_edit(placeholder)
	e.text = cur
	e.text_submitted.connect(func(t: String) -> void:
		cb.call(t)
		e.release_focus())
	e.focus_exited.connect(func() -> void:
		if e.text != cur:
			cb.call(e.text))
	return e


func _spin(cur: float, lo: float, hi: float, step: float, cb: Callable) -> SpinBox:
	var s := EditorUi.spin(lo, hi, step, cur)
	s.value_changed.connect(cb)
	return s


func _toggle(cur: bool, on: String, off: String, cb: Callable) -> Button:
	var b := EditorUi.button(on if cur else off, "", true)
	b.button_pressed = cur
	b.clip_text = true
	b.pressed.connect(func() -> void:
		b.text = on if b.button_pressed else off
		cb.call(b.button_pressed))
	return b


# --- Onglet VAGUES -----------------------------------------------------------------------------

func _plan() -> Dictionary:
	return ed.doc.wave_plan


## Points d'apparition de la carte (cases S), avec leur nom : [clé "x,y", nom, case].
func spawn_points() -> Array:
	var out := []
	for y in ed.doc.rows.size():
		var row: String = ed.doc.rows[y]
		for x in row.length():
			if row[x] == "S":
				var key := "%d,%d" % [x, y]
				out.append([key, str(_plan().get("spawn_names", {}).get(key, "Apparition %d" % (out.size() + 1))), Vector2i(x, y)])
	return out


func _set_plan(label: String, key: String, v: Variant) -> void:
	edit(label, func() -> void: _plan()[key] = v, true)


func _waves_mode_form() -> void:
	var g := EditorUi.grid(2, 6)
	var m: Dictionary = ed.doc.mission
	var t := str(m.get("type", "waves"))
	var on := Mission.new(m).waves_enabled()
	var tog := _toggle(on, "Oui", "Non (seulement par déclencheur)", func(v: bool) -> void:
		ed.history.record("Vagues : activer", func() -> void: ed.doc.mission["waves_enabled"] = v)
		ed.after_change())
	tog.disabled = t == "waves"
	tog.tooltip_text = "En mission Défense, les vagues sont toujours actives." if t == "waves" else "Sinon, les vagues ne partent que par des déclencheurs."
	_row(g, "Vagues automatiques", tog)
	var cur := str(_plan().get("mode", "auto"))
	_row(g, "Mode", _option([["auto", "Automatique (nombre, difficulté)"], ["custom", "Personnalisées (liste)"]], cur, _set_wave_mode))
	_form.add_child(EditorUi.section("Vagues ennemies"))
	_form.add_child(g)
	if cur != "custom":
		var g2 := EditorUi.grid(2, 6)
		_row(g2, "Nombre de vagues", _spin(ed.doc.waves, 1, 60, 1, func(v: float) -> void: _set_doc_wave("waves", v)))
		_row(g2, "Difficulté (× ennemis)", _spin(ed.doc.difficulty, 0.5, 3.0, 0.05, func(v: float) -> void: _set_doc_wave("difficulty", v)))
		_row(g2, "Intervalle (s)", _spin(ed.doc.interval, 8, 120, 1, func(v: float) -> void: _set_doc_wave("interval", v)))
		_form.add_child(g2)
		_form.add_child(EditorUi.muted("Chaque vague grossit, avec un boss toutes les %d vagues. Première vague après %d s.\nPasse en « Personnalisées » pour régler chaque vague." % [Balance.BOSS_EVERY, int(Balance.FIRST_WAVE_DELAY)]))
	else:
		_form.add_child(EditorUi.muted("Les vagues « après la précédente » et « éliminée » s'enchaînent dans l'ordre de la liste. Les autres partent par un déclencheur ou un objectif. Actions utiles : Lancer, Arrêter, Suspendre, Accélérer."))
	_form.add_child(EditorUi.sep())


func _set_wave_mode(v: String) -> void:
	if v == "custom" and _plan().get("list", []).is_empty():
		edit("Vagues personnalisées", func() -> void:
			_plan()["mode"] = "custom"
			_plan()["list"] = WaveManager.from_auto(ed.doc.waves, ed.doc.difficulty, ed.doc.interval), true)
		ed._toast("Les vagues automatiques ont été converties : modifie-les une par une")
	else:
		_set_plan("Mode des vagues", "mode", v)
	selected = ""
	refresh()


func _set_doc_wave(key: String, v: float) -> void:
	var change := func() -> void:
		if key == "waves":
			ed.doc.waves = int(v)
		elif key == "difficulty":
			ed.doc.difficulty = v
		else:
			ed.doc.interval = v
	edit("Vagues : réglage", change)


func _add_wave(id: int) -> void:
	if id == 10:
		ed._confirm("Remplacer les vagues ?", "La liste sera remplacée par %d vagues équivalentes au mode automatique." % ed.doc.waves, "Remplacer", func() -> void:
			edit("Vagues automatiques converties", func() -> void: _plan()["list"] = WaveManager.from_auto(ed.doc.waves, ed.doc.difficulty, ed.doc.interval), true)
			selected = ""
			refresh())
		return
	var list := _items()
	var w := WaveManager.new_wave(_new_id("w", list), "Vague %d" % (list.size() + 1))
	if id == 1:
		w.name = "Boss"
		w.groups = [{"type": "boss", "count": 1, "spawn": "", "escort": 4, "escort_type": "armored"}]
	elif id == 2:
		w.name = "Embuscade"
		w.start = "trigger"
		w.order = "simultaneous"
		w.behavior = "aggressive"
		w.groups = [{"type": "fast", "count": 6, "spawn": "", "escort": 0, "escort_type": "normal"}]
	elif id == 3:
		w.name = "Harcèlement"
		w.start = "trigger"
		w.repeat = 5
		w.every = 20.0
		w.groups = [{"type": "swarmer", "count": 4, "spawn": "", "escort": 0, "escort_type": "normal"}]
	selected = w.id
	edit("Ajouter une vague", func() -> void: _items().append(w), true)
	if id in [2, 3]:
		ed._toast("Lance-la avec l'action « Lancer une vague » (onglet Événements)")


func _enemy_types(with_random: bool) -> Array:
	var l := [["random", "Aléatoire"]] if with_random else []
	for k in Balance.ENEMIES:
		l.append([k, str(EditorDoc.ENEMY_NAMES.get(k, k))])
	return l


func _wave_form(wv: Dictionary) -> void:
	var id: String = wv.id
	var getter := func() -> Dictionary: return _find_wave(id)
	_form.add_child(EditorUi.section("Vague"))
	var g := EditorUi.grid(2, 6)
	_row(g, "Nom", _text(str(wv.name), func(t: String) -> void: _setp(getter, "name", t)))
	var start := str(wv.get("start", "auto"))
	_row(g, "Lancement", _option(WaveManager.START_LABELS, start, func(v: String) -> void: _setp(getter, "start", v, true)))
	if start != "trigger":
		_row(g, "Délai après la précédente (s)" if start == "auto" else "Délai (s)", _spin(float(wv.get("delay", 0.0)), 0, 900, 1, func(v: float) -> void: _setp(getter, "delay", v)))
	if start == "objective":
		_row(g, "Objectif", _field(getter, ["objective", "objective", "Objectif", ""]))
	var order := str(wv.get("order", "progressive"))
	_row(g, "Arrivée", _option(WaveManager.ORDER_LABELS, order, func(v: String) -> void: _setp(getter, "order", v, true)))
	if order == "progressive":
		_row(g, "Écart entre ennemis (s)", _spin(float(wv.get("spacing", 0.7)), 0.1, 10, 0.1, func(v: float) -> void: _setp(getter, "spacing", v)))
	_row(g, "PV (×)", _spin(float(wv.get("hp", 1.0)), 0.1, 20, 0.05, func(v: float) -> void: _setp(getter, "hp", v)))
	_row(g, "Faction", _option(Factions.new(ed.doc.factions).ids("enemy"), str(wv.get("faction", "enemy")), func(v: String) -> void: _setp(getter, "faction", v)))
	var beh := str(wv.get("behavior", "base"))
	_row(g, "Comportement", _option(WaveManager.BEHAVIOR_LABELS, beh, func(v: String) -> void: _setp(getter, "behavior", v, true)))
	if beh == "attack_target":
		_row(g, "Cible", _obj_field(getter, "target", "obj_player", wv.get("target", -1)))
	if beh == "attack_zone":
		_row(g, "Zone", _obj_field(getter, "zone", "zone", wv.get("zone", -1)))
	_row(g, "Répétitions", _spin(int(wv.get("repeat", 0)), 0, 99, 1, func(v: float) -> void: _setp(getter, "repeat", int(v), true)))
	if int(wv.get("repeat", 0)) > 0:
		_row(g, "Toutes les (s)", _spin(float(wv.get("every", 30.0)), 1, 900, 1, func(v: float) -> void: _setp(getter, "every", v)))
	_form.add_child(g)
	if start == "trigger" and not _launched_by_trigger(id):
		var warn := EditorUi.label("⚠ Aucun déclencheur ne lance cette vague (action « Lancer une vague »).", 12, Ui.GOLD)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_form.add_child(warn)
	_groups_editor(wv, getter)


func _groups_editor(wv: Dictionary, getter: Callable) -> void:
	_form.add_child(EditorUi.sep())
	_form.add_child(EditorUi.section("Ennemis"))
	var spawns := [["", "Toutes les apparitions"]]
	for sp in spawn_points():
		spawns.append([sp[0], sp[1]])
	var groups: Array = wv.get("groups", [])
	var total := 0
	for i in groups.size():
		var gi: int = i
		var gr: Dictionary = groups[i]
		var gget := func() -> Dictionary: return getter.call().groups[gi]
		total += int(gr.get("count", 0)) * (1 + int(gr.get("escort", 0)))
		var row := EditorUi.hbox(3)
		var typ := _option(_enemy_types(true), str(gr.get("type", "normal")), func(v: String) -> void: _setp(gget, "type", v))
		typ.custom_minimum_size.x = 120
		typ.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(typ)
		var cnt := _spin(int(gr.get("count", 1)), 1, 200, 1, func(v: float) -> void: _setp(gget, "count", int(v)))
		cnt.custom_minimum_size.x = 70
		row.add_child(cnt)
		var sp := _option(spawns, str(gr.get("spawn", "")), func(v: String) -> void: _setp(gget, "spawn", v))
		sp.custom_minimum_size.x = 120
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		var x := EditorUi.button("✕", "Retirer ce groupe", false, 26)
		x.pressed.connect(func() -> void: edit("Retirer un groupe", func() -> void: getter.call().groups.remove_at(gi), true))
		row.add_child(x)
		_form.add_child(row)
		var er := EditorUi.hbox(3)
		er.add_child(EditorUi.label("      escorte : chacun avec", 12, Ui.MUTED))
		var esc := _spin(int(gr.get("escort", 0)), 0, 20, 1, func(v: float) -> void: _setp(gget, "escort", int(v)))
		esc.custom_minimum_size.x = 64
		er.add_child(esc)
		var et := _option(_enemy_types(true), str(gr.get("escort_type", "normal")), func(v: String) -> void: _setp(gget, "escort_type", v))
		et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		er.add_child(et)
		_form.add_child(er)
	var add := EditorUi.button("+ Groupe d'ennemis")
	add.pressed.connect(func() -> void:
		edit("Ajouter un groupe", func() -> void: getter.call().groups.append({"type": "normal", "count": 5, "spawn": "", "escort": 0, "escort_type": "normal"}), true))
	_form.add_child(add)
	_form.add_child(EditorUi.muted("Total : %d ennemis%s." % [total, " par lancement" if int(wv.get("repeat", 0)) > 0 else ""]))
	if spawn_points().is_empty():
		_form.add_child(EditorUi.label("⚠ Aucun point d'apparition sur la carte (onglet Carte, calque Apparitions).", 12, Ui.GOLD))


func _find_wave(id: String) -> Dictionary:
	for x: Dictionary in _plan().get("list", []):
		if str(x.id) == id:
			return x
	return {}


func _launched_by_trigger(id: String) -> bool:
	return _sc().get("triggers", []).any(func(t: Dictionary) -> bool:
		return (t.get("actions", []) + t.get("else", [])).any(func(a: Dictionary) -> bool:
			return a.get("type", "") == "wave_launch" and str(a.get("wave", "")) == id))


func _spawns_form() -> void:
	var sps := spawn_points()
	_form.add_child(EditorUi.section("Points d'apparition"))
	if sps.is_empty():
		_form.add_child(EditorUi.muted("Aucun point d'apparition : pose-en dans l'onglet Carte (calque Apparitions)."))
		return
	_form.add_child(EditorUi.muted("Nomme-les pour les choisir facilement dans les vagues (« Nord », « Rivière »…)."))
	for sp in sps:
		var key: String = sp[0]
		var row := EditorUi.hbox(3)
		var e := _text(str(sp[1]), func(t: String) -> void: _rename_spawn(key, t))
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(e)
		var at := EditorUi.label("(%s)" % key.replace(",", ", "), 12, Ui.MUTED)
		at.custom_minimum_size.x = 70
		row.add_child(at)
		var c: Vector2i = sp[2]
		var look := EditorUi.button("◎", "Voir sur la carte", false, 28)
		look.pressed.connect(func() -> void: ed.look_at_cell(c))
		row.add_child(look)
		_form.add_child(row)
		var used: Array = _plan().get("list", []).filter(func(w: Dictionary) -> bool:
			return w.get("groups", []).any(func(gr: Dictionary) -> bool: return str(gr.get("spawn", "")) == key))
		if not used.is_empty():
			_form.add_child(EditorUi.muted("      utilisé par : " + ", ".join(used.map(func(w: Dictionary) -> String: return str(w.name)))))


func _rename_spawn(key: String, t: String) -> void:
	var change := func() -> void:
		if not _plan().has("spawn_names"):
			_plan()["spawn_names"] = {}
		_plan().spawn_names[key] = t.strip_edges()
	edit("Renommer un point d'apparition", change, true)
