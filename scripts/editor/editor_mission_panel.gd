class_name EditorMissionPanel
extends VBoxContainer
## Onglet MISSION : type de mission, réglages, vagues, objectifs bonus, briefing.
## Chaque changement est écrit tout de suite dans le document (et peut être annulé).

const OBJECTIVE_DEFAULT_WAVE := {"train": 3, "convoy": 6, "boat": 9}
const HINTS := {
	"waves": ["Survivre à toutes les vagues. Pose un BÂTIMENT À DÉFENDRE : les ennemis le visent en priorité et sa destruction fait perdre la mission.", "★ Poser le bâtiment à défendre", "defend:barracks"],
	"survive": ["Tenir jusqu'à la fin du chrono. Si ta base est détruite, la mission est perdue.", "", ""],
	"destroy_base": ["Pose une ou plusieurs BASES ENNEMIES où tu veux (et leurs défenses) : toutes doivent être détruites.", "✚ Poser une base ennemie", "structure:e_hq"],
	"convoy": ["Trace le trajet avec des POINTS DE PASSAGE (1 = départ) ; règle une PAUSE sur un point pour arrêter le convoi. Sans points : trajet automatique sur rails / route / eau.", "✚ Tracer le trajet", "waypoint:"],
	"escort": ["Pose le VIP et la ZONE D'ARRIVÉE : le joueur le guide lui-même.", "✚ Poser le VIP", "vip:commander"],
	"escort_defend": ["Convoi allié non contrôlable : il part du DÉPART (ou du point 1) et suit les POINTS DE PASSAGE avec leurs pauses. Les ennemis le visent en priorité.", "✚ Tracer le trajet", "waypoint:"],
	"capture": ["Pose les ZONES DE PRISE : chacune a sa durée et son rayon. Unités dedans et aucun ennemi = la prise avance.", "✚ Poser une zone de prise", "zone:capture"],
}

var ed # MissionEditor
var _type_buttons := {}
var _kind_buttons := {}
var _obj_buttons := {}
var _rows := {}
var _time: SpinBox
var _count: SpinBox
var _need: SpinBox
var _start: SpinBox
var _gap: SpinBox
var _waves_btn: Button
var _waves_box: Control
var _nb_waves: SpinBox
var _diff: SpinBox
var _interval: SpinBox
var _hint: Label
var _place: Button
var _place_tool := ""
var _brief: TextEdit
var _loading := false
var _settings_sep: Control
var _settings_title: Control


func _init(editor) -> void:
	ed = editor
	add_theme_constant_override("separation", 6)
	add_child(EditorUi.section("Type de mission"))
	var tg := EditorUi.grid(2)
	for t in Mission.TYPES:
		var b := EditorUi.button(str(Mission.TYPE_NAMES[t]), "", true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 108
		var tt: String = t
		b.pressed.connect(func() -> void: _set_mission("type", tt))
		_type_buttons[t] = b
		tg.add_child(b)
	add_child(tg)
	_hint = EditorUi.muted("")
	add_child(_hint)
	_place = EditorUi.button("")
	_place.pressed.connect(func() -> void: ed.start_place(_place_tool))
	add_child(_place)

	_settings_sep = EditorUi.sep()
	add_child(_settings_sep)
	_settings_title = EditorUi.section("Réglages")
	add_child(_settings_title)
	var g := EditorUi.grid(2, 6)
	_time = EditorUi.spin(10, 3600, 10, 300)
	_count = EditorUi.spin(1, 20, 1, 3)
	_need = EditorUi.spin(1, 20, 1, 3)
	_start = EditorUi.spin(0, 900, 5, 20)
	_gap = EditorUi.spin(5, 300, 5, 40)
	for row in [["time", "Durée (s)", _time, "time"], ["count", "Nombre de convois", _count, "convoy_count"],
			["need", "À détruire", _need, "convoy_need"], ["start", "Premier départ (s)", _start, "convoy_start"],
			["gap", "Écart (s)", _gap, "convoy_interval"]]:
		var l := EditorUi.label(row[1])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sp: SpinBox = row[2]
		var key: String = row[3]
		sp.value_changed.connect(func(v: float) -> void: _set_mission(key, int(v) if key in ["time", "convoy_count", "convoy_need"] else v))
		g.add_child(l)
		g.add_child(sp)
		_rows[row[0]] = [l, sp]
	add_child(g)
	var kh := EditorUi.hbox()
	for pair in [["train", "Train"], ["convoy", "Camions"], ["boat", "Bateau"]]:
		var b := EditorUi.button(pair[1], "Véhicule des convois ennemis", true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k: String = pair[0]
		b.pressed.connect(func() -> void: _set_mission("convoy_kind", k))
		_kind_buttons[k] = b
		kh.add_child(b)
	add_child(kh)
	_rows["kind"] = [kh]

	add_child(EditorUi.sep())
	add_child(EditorUi.section("Vagues ennemies"))
	_waves_btn = EditorUi.button("Vagues : oui", "Active ou coupe les vagues pour ce type de mission", true)
	_waves_btn.pressed.connect(func() -> void: _set_mission("waves_enabled", _waves_btn.button_pressed))
	add_child(_waves_btn)
	var wg := EditorUi.grid(2, 6)
	_nb_waves = EditorUi.spin(1, 60, 1, 10)
	_diff = EditorUi.spin(0.5, 3.0, 0.05, 1.0)
	_interval = EditorUi.spin(8, 120, 1, 30)
	for row in [["Nombre", _nb_waves, "waves"], ["Difficulté", _diff, "difficulty"], ["Intervalle (s)", _interval, "interval"]]:
		var l := EditorUi.label(row[0])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wg.add_child(l)
		var sp: SpinBox = row[1]
		var key: String = row[2]
		sp.value_changed.connect(func(v: float) -> void: _set_doc(key, v))
		wg.add_child(sp)
	_waves_box = wg
	add_child(wg)

	add_child(EditorUi.sep())
	add_child(EditorUi.section("Objectifs bonus"))
	var oh := EditorUi.hbox()
	for pair in [["train", "Train"], ["convoy", "Convoi"], ["boat", "Bateau"]]:
		var b := EditorUi.button(pair[1], "Objectif bonus : détruire ce véhicule", true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var typ: String = pair[0]
		b.pressed.connect(func() -> void: _toggle_objective(typ))
		_obj_buttons[typ] = b
		oh.add_child(b)
	add_child(oh)

	add_child(EditorUi.sep())
	add_child(EditorUi.section("Briefing"))
	_brief = TextEdit.new()
	_brief.custom_minimum_size = Vector2(0, 110)
	_brief.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_brief.placeholder_text = "Texte affiché au début de la mission"
	_brief.add_theme_font_size_override("font_size", 13)
	_brief.focus_exited.connect(func() -> void: _set_mission("briefing", _brief.text.strip_edges()))
	add_child(_brief)


## Relit le document (chargement, annuler / rétablir).
func refresh() -> void:
	_loading = true
	var m: Dictionary = ed.doc.mission
	var t := str(m.get("type", "waves"))
	var ally := t == "escort_defend"
	for k in _type_buttons:
		(_type_buttons[k] as Button).set_pressed_no_signal(k == t)
	_time.set_value_no_signal(float(m.get("time", 300)))
	_count.set_value_no_signal(float(m.get("convoy_count", 1 if ally else 3)))
	_need.set_value_no_signal(float(m.get("convoy_need", 1 if ally else 3)))
	_start.set_value_no_signal(float(m.get("convoy_start", 0 if ally else 20)))
	_gap.set_value_no_signal(float(m.get("convoy_interval", 40)))
	var kind := str(m.get("convoy_kind", "convoy"))
	for k in _kind_buttons:
		(_kind_buttons[k] as Button).set_pressed_no_signal(k == kind)
	var convoys := t in ["convoy", "escort_defend"]
	var show := {"time": t == "survive", "count": convoys, "need": convoys, "start": convoys, "gap": convoys, "kind": t == "convoy"}
	for k in _rows:
		for n in _rows[k]:
			(n as Control).visible = show.get(k, false)
	(_rows.need[0] as Label).text = "À faire arriver" if ally else "À détruire"
	_settings_sep.visible = t in ["survive", "convoy", "escort_defend"]
	_settings_title.visible = _settings_sep.visible
	var waves_on := Mission.new(m).waves_enabled()
	_waves_btn.set_pressed_no_signal(waves_on)
	_waves_btn.text = "Vagues : %s" % ("oui" if waves_on else "non")
	_waves_btn.disabled = t == "waves"
	_waves_box.visible = waves_on
	_nb_waves.set_value_no_signal(ed.doc.waves)
	_diff.set_value_no_signal(ed.doc.difficulty)
	_interval.set_value_no_signal(ed.doc.interval)
	for typ in _obj_buttons:
		(_obj_buttons[typ] as Button).set_pressed_no_signal(ed.doc.objectives.any(func(o: Dictionary) -> bool: return o.type == typ))
	var h: Array = HINTS.get(t, ["", "", ""])
	_hint.text = h[0]
	_place.text = h[1]
	_place.visible = h[1] != ""
	_place_tool = h[2]
	if not _brief.has_focus():
		_brief.text = str(m.get("briefing", ""))
	_loading = false


func _set_mission(key: String, value: Variant) -> void:
	if _loading:
		return
	var change := func() -> void:
		ed.doc.mission[key] = value
		if key == "type" and value == "waves":
			ed.doc.mission.waves_enabled = true
	ed.history.record("Mission : réglage", change)
	ed.after_change()


func _set_doc(key: String, value: float) -> void:
	if _loading:
		return
	var change := func() -> void:
		if key == "waves":
			ed.doc.waves = int(value)
		elif key == "difficulty":
			ed.doc.difficulty = value
		else:
			ed.doc.interval = value
	ed.history.record("Vagues : réglage", change)
	ed.after_change()


func _toggle_objective(typ: String) -> void:
	var change := func() -> void:
		var found := -1
		for i in ed.doc.objectives.size():
			if ed.doc.objectives[i].type == typ:
				found = i
		if found >= 0:
			ed.doc.objectives.remove_at(found)
		else:
			ed.doc.objectives.append({"type": typ, "wave": OBJECTIVE_DEFAULT_WAVE[typ]})
	ed.history.record("Objectif bonus", change)
	ed.after_change()


## Avertissements propres au type de mission (ne bloquent pas le test).
static func warnings(doc: EditorDoc, grid: GameGrid) -> Array[String]:
	var w: Array[String] = []
	var kinds := {}
	var wps := 0
	for e: Dictionary in doc.entities:
		kinds[str(e.kind) + ":" + str(e.get("type", e.get("role", "")))] = true
		kinds[e.kind] = true
		if e.kind == "waypoint":
			wps += 1
		if e.kind == "deco" and UnitsView.deco_texture(str(e.get("sprite", ""))) == null:
			w.append("Image de décor introuvable : %s" % e.get("sprite", ""))
	# Fiches : liens et réglages incomplets
	for e: Dictionary in doc.entities:
		var beh := str(e.get("behavior", ""))
		if beh == "patrol" and e.get("patrol", []).size() < 2:
			w.append("%s : la patrouille a besoin d'au moins 2 points" % e.name)
		if beh in ["defend", "attack_target", "attack_zone", "follow"] and int(e.get("target", -1)) < 0:
			w.append("%s : choisis sa cible dans sa fiche" % e.name)
		for key in ["target", "link"]:
			if int(e.get(key, -1)) >= 0 and doc.entity_by_id(int(e[key])).is_empty():
				w.append("%s : l'objet lié n'existe plus" % e.name)
		if e.kind == "shield" and int(e.get("link", -1)) < 0:
			w.append("%s : sans générateur, il reste actif toute la partie" % e.name)
	var t := str(doc.mission.get("type", "waves"))
	match t:
		"destroy_base":
			if not kinds.has("structure:e_hq"):
				w.append("Pose une BASE ENNEMIE (onglet Objets)")
		"escort":
			if not kinds.has("vip") or not kinds.has("zone:goal"):
				w.append("Il faut un VIP et une ZONE D'ARRIVÉE")
		"escort_defend":
			if wps < (1 if kinds.has("escortee") else 2):
				w.append("Trace le trajet du convoi : au moins 2 POINTS DE PASSAGE")
		"capture":
			if not kinds.has("zone:capture"):
				w.append("Pose au moins une ZONE DE PRISE")
		"convoy":
			if wps == 1:
				w.append("Un trajet a besoin d'au moins 2 POINTS DE PASSAGE")
			var kind := str(doc.mission.get("convoy_kind", "convoy"))
			if wps < 2 and not _has_terrain(grid, kind):
				w.append("Les convois ont besoin de %s" % {"train": "rails", "convoy": "route", "boat": "eau"}[kind])
	for o: Dictionary in doc.objectives:
		if not _has_terrain(grid, o.type):
			w.append("%s sans %s" % [Balance.OBJECTIVES[o.type].name, {"train": "rails", "convoy": "route", "boat": "eau"}[o.type]])
	return w


static func _has_terrain(grid: GameGrid, kind: String) -> bool:
	var need: Callable = {"train": grid.is_rail, "convoy": grid.is_road, "boat": grid.is_water}[kind]
	for y in grid.height:
		for x in grid.width:
			if need.call(Vector2i(x, y)):
				return true
	return false
