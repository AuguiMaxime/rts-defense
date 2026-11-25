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
var _hint: Label
var _place: Button
var _place_tool := ""
var _brief: TextEdit
var _loading := false
var _tpl_label: Label
var _waves_info: Label
var _params := {}
var _time_out: OptionButton
var _players: OptionButton
var _stars: OptionButton
var _preview: TextureRect
var _preview_info: Label
var _preview_key := ""

## [clé, libellé, min, max, pas, aide] ; valeur absente = réglage par défaut du jeu.
const PARAMS := [
	["metal", "Métal de départ", 0, 99999, 10, "Les technos « Réserves » du joueur s'ajoutent"],
	["essence", "Essence de départ", 0, 99999, 10, ""],
	["workers", "Ouvriers de départ", 0, 30, 1, "Les unités et bâtiments de départ se posent dans l'onglet Objets"],
	["base_hp", "PV de la base", 100, 50000, 50, "Les technos « Coque » du joueur s'ajoutent"],
	["time_limit", "Durée maximale (s, 0 = aucune)", 0, 7200, 10, "Au bout de ce temps, la partie s'arrête"],
]
const PLAYERS := [["solo", "Solo"], ["coop", "Coop (2 joueurs)"], ["both", "Solo ou coop"]]
var _fac_info: Label
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
	_tpl_label = EditorUi.muted("")
	add_child(_tpl_label)
	var th := EditorUi.hbox()
	var see := EditorUi.button("Voir les objectifs", "Ouvre l'onglet Objectifs pour modifier ceux du modèle")
	see.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	see.pressed.connect(func() -> void: ed.set_tab("objectives"))
	th.add_child(see)
	var regen := EditorUi.button("Régénérer le modèle", "Remplace les objectifs et déclencheurs du modèle par ceux d'origine. Tes ajouts sont conservés.")
	regen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	regen.pressed.connect(_regenerate)
	th.add_child(regen)
	add_child(th)

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
	_waves_info = EditorUi.muted("")
	add_child(_waves_info)
	var gw := EditorUi.button("Régler les vagues (onglet Vagues)")
	gw.pressed.connect(func() -> void: ed.set_tab("waves"))
	add_child(gw)
	add_child(EditorUi.sep())
	add_child(EditorUi.section("Factions et relations"))
	_fac_info = EditorUi.muted("")
	_fac_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_fac_info)
	var fb := EditorUi.button("Factions et relations…", "Factions personnalisées et tableau des relations")
	fb.pressed.connect(func() -> void: EditorFactions.new(ed).open())
	add_child(fb)

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
	add_child(EditorUi.section("Paramètres de la partie"))
	var gp := EditorUi.grid(2, 6)
	for row in PARAMS:
		var l := EditorUi.label(row[1])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.tooltip_text = row[5]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		var sp := EditorUi.spin(row[2], row[3], row[4], 0)
		var key: String = row[0]
		sp.value_changed.connect(func(v: float) -> void: _set_param(key, v))
		gp.add_child(l)
		gp.add_child(sp)
		_params[key] = sp
	var tl := EditorUi.label("À la fin du temps")
	gp.add_child(tl)
	_time_out = OptionButton.new()
	_time_out.focus_mode = Control.FOCUS_NONE
	_time_out.add_item("Défaite", 0)
	_time_out.add_item("Victoire", 1)
	_time_out.item_selected.connect(func(i: int) -> void: _set_param("time_out", "victory" if i == 1 else "defeat"))
	gp.add_child(_time_out)
	gp.add_child(EditorUi.label("Joueurs"))
	_players = OptionButton.new()
	_players.focus_mode = Control.FOCUS_NONE
	for i in PLAYERS.size():
		_players.add_item(PLAYERS[i][1], i)
	_players.item_selected.connect(func(i: int) -> void: _set_param("players", PLAYERS[i][0]))
	gp.add_child(_players)
	gp.add_child(EditorUi.label("Difficulté affichée"))
	_stars = OptionButton.new()
	_stars.focus_mode = Control.FOCUS_NONE
	for i in 5:
		_stars.add_item("★".repeat(i + 1) + "☆".repeat(4 - i), i)
	_stars.item_selected.connect(func(i: int) -> void: _set_param("stars", i + 1))
	gp.add_child(_stars)
	add_child(gp)
	add_child(EditorUi.muted("Unités et bâtiments de départ : pose-les dans l'onglet Objets (Alliés · unités, tourelles, bâtiments de départ)."))
	add_child(EditorUi.section("Aperçu"))
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(0, 150)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_preview)
	_preview_info = EditorUi.muted("")
	add_child(_preview_info)
	var ph := EditorUi.hbox()
	var gen := EditorUi.button("Générer depuis la carte", "Miniature de la carte, rangée dans le fichier de la mission")
	gen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gen.pressed.connect(func() -> void: _set_param("preview", MissionPreview.encode(MissionPreview.render(ed.doc))))
	ph.add_child(gen)
	var pick := EditorUi.button("Choisir une image…", "PNG ou JPG (réduite à 360 × 225)")
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.pressed.connect(_pick_preview)
	ph.add_child(pick)
	var clear := EditorUi.button("✕", "Retirer l'aperçu", false, 30)
	clear.pressed.connect(func() -> void: _set_param("preview", ""))
	ph.add_child(clear)
	add_child(ph)

	add_child(EditorUi.sep())
	add_child(EditorUi.section("Briefing"))
	_brief = TextEdit.new()
	_brief.custom_minimum_size = Vector2(0, 110)
	_brief.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_brief.placeholder_text = "Texte affiché au début de la mission"
	_brief.add_theme_font_size_override("font_size", 13)
	_brief.focus_exited.connect(func() -> void: _set_mission("briefing", _brief.text.strip_edges()))
	add_child(_brief)


func _param_default(key: String) -> float:
	match key:
		"metal":
			return Balance.START_METAL
		"essence":
			return Balance.START_ESSENCE
		"workers":
			return Balance.START_WORKERS
		"base_hp":
			return Balance.BASE_HP
	return 0.0


func _set_param(key: String, v: Variant) -> void:
	if _loading:
		return
	var change := func() -> void:
		if not ed.doc.mission.has("params"):
			ed.doc.mission["params"] = {}
		var p: Dictionary = ed.doc.mission.params
		if v is float and key in ["metal", "essence", "workers", "base_hp"]:
			p[key] = int(v)
		elif key == "preview" and str(v) == "":
			p.erase("preview")
		else:
			p[key] = v
	ed.history.record("Paramètre : " + key, change)
	ed.after_change()


func _pick_preview() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	fd.title = "Image d'aperçu de la mission"
	fd.use_native_dialog = true
	fd.file_selected.connect(func(path: String) -> void:
		var b64 := MissionPreview.from_file(path)
		if b64 == "":
			ed._toast("Image illisible", Ui.RED)
		else:
			_set_param("preview", b64)
		fd.queue_free())
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered_ratio(0.6)


## Relit le document (chargement, annuler / rétablir).
func refresh() -> void:
	_loading = true
	var m: Dictionary = ed.doc.mission
	var pp: Dictionary = m.get("params", {})
	for k in _params:
		(_params[k] as SpinBox).set_value_no_signal(float(pp.get(k, _param_default(k))))
	_time_out.select(1 if str(pp.get("time_out", "defeat")) == "victory" else 0)
	_time_out.disabled = float(pp.get("time_limit", 0.0)) <= 0.0
	var pi := 0
	for i in PLAYERS.size():
		if PLAYERS[i][0] == str(pp.get("players", "solo")):
			pi = i
	_players.select(pi)
	_stars.select(clampi(int(pp.get("stars", 2)) - 1, 0, 4))
	var b64 := str(pp.get("preview", ""))
	if b64 != _preview_key:
		_preview_key = b64
		_preview.texture = MissionPreview.texture(b64)
	_preview.visible = _preview.texture != null
	_preview_info.text = "" if _preview.texture != null else "Pas d'aperçu : génère-le depuis la carte ou choisis une image."
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
	_waves_info.text = EditorMissionPanel.waves_summary(ed.doc)
	_fac_info.text = factions_summary(ed.doc)
	for typ in _obj_buttons:
		(_obj_buttons[typ] as Button).set_pressed_no_signal(ed.doc.objectives.any(func(o: Dictionary) -> bool: return o.type == typ))
	var mine: Array = ed.doc.scenario.get("objectives", []).filter(func(o: Dictionary) -> bool: return o.get("tpl", false))
	var lines: Array[String] = []
	for o: Dictionary in mine:
		lines.append(("◆ " if o.get("kind", "main") == "main" else "◇ ") + str(o.name))
	_tpl_label.text = ("Objectifs du modèle :\n" + "\n".join(lines)) if not lines.is_empty() else \
			"Objectifs personnalisés (aucun objectif du modèle). « Régénérer » les ajoute."
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
		if key == "type":
			MissionTemplates.regenerate(ed.doc.scenario, ed.doc.mission, ed.doc.entities)
	ed.history.record("Mission : type" if key == "type" else "Mission : réglage", change)
	ed.after_change()
	if key == "type":
		ed._toast("Objectifs du modèle « %s » générés" % Mission.TYPE_NAMES[value])


func _regenerate() -> void:
	ed.history.record("Régénérer le modèle", func() -> void:
		MissionTemplates.regenerate(ed.doc.scenario, ed.doc.mission, ed.doc.entities))
	ed.after_change()
	ed._toast("Objectifs du modèle régénérés")


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


static func factions_summary(doc: EditorDoc) -> String:
	var f := Factions.new(doc.factions)
	var custom: int = doc.factions.get("list", []).size()
	var changed := []
	for p in f.ids("player"):
		for e in f.ids("enemy"):
			var r := f.relation(p[0], e[0])
			if r != Factions.default_rel(p[0], e[0]):
				changed.append("%s / %s : %s" % [p[1], e[1], {"enemy": "ennemis", "neutral": "neutres", "provoked": "hostiles si attaqués"}[r]])
	var t := "6 factions de base" + (" + %d personnalisée%s" % [custom, "s" if custom > 1 else ""] if custom > 0 else "") + "."
	if not changed.is_empty():
		t += " Modifié : " + ", ".join(changed.slice(0, 3)) + ("…" if changed.size() > 3 else "")
	return t


## Résumé des vagues de la mission (onglets Mission et Vagues).
static func waves_summary(doc: EditorDoc) -> String:
	if not Mission.new(doc.mission).waves_enabled():
		return "Pas de vagues automatiques (seulement lancées par des déclencheurs)." if doc.wave_plan.get("mode", "auto") == "custom" else "Pas de vagues."
	if str(doc.wave_plan.get("mode", "auto")) == "custom":
		var n: int = doc.wave_plan.get("list", []).size()
		return "Vagues personnalisées : %d vague%s." % [n, "s" if n > 1 else ""]
	return "Vagues automatiques : %d vagues, difficulté ×%.2f, toutes les %d s." % [doc.waves, doc.difficulty, int(doc.interval)]
