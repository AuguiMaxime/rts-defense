extends Node2D
## Éditeur de cartes (outil de développement, désactivable via Content.DEV_TOOLS).
## Pinceaux : terrain libre, rocher, métal, essence, base 3x3, point d'apparition.
## Un doigt = peindre ; deux doigts / clic droit / ZQSD = déplacer ; pincer / molette = zoom.

const TILE := MapView.TILE
const TOOLS := [
	{"id": ".", "name": "GOMME", "color": Color("1f4d2b")},
	{"id": "#", "name": "ROCHER", "color": Color("8a8f98")},
	{"id": "M", "name": "MÉTAL", "color": Color("9ec5ff")},
	{"id": "E", "name": "ESSENCE", "color": Color("ffa63d")},
	{"id": "B", "name": "BASE 3x3", "color": Color("22d3ee")},
	{"id": "S", "name": "APPARITION", "color": Color("f87171")},
	{"id": "b", "name": "BASE J2", "color": Color("fbbf24")},
	{"id": "~", "name": "EAU", "color": Color("1e90d6")},
	{"id": "=", "name": "ROUTE", "color": Color("3b3f46")},
	{"id": "T", "name": "RAILS", "color": Color("8a6a4a")},
	{"id": "W", "name": "MUR", "color": Color("5a6270")},
]
const OBJECTIVE_DEFAULT_WAVE := {"train": 3, "convoy": 6, "boat": 9}

var data: MapData
var rows: Array[String] = []
var grid: GameGrid
var tool := "#"
var brush := 1
var _undo: Array = []
var _stroke_open := false
var _last_paint := Vector2i(-999, -999)
var _issues: Array[String] = []

var map_view: MapView
var camera: CameraController
var _ui: Control
var _tool_buttons := {}
var _brush_buttons := {}
var _ground_buttons := {}
var _obj_buttons := {}
var _name_edit: LineEdit
var _w_spin: SpinBox
var _h_spin: SpinBox
var _waves_spin: SpinBox
var _diff_spin: SpinBox
var _interval_spin: SpinBox
var _status: Label
var _open_layer: Control
## Onglets : "terrain" (peindre le sol), "objects" (poser des objets), "mission" (règles)
var mode := "terrain"
var _tab_buttons := {}
var _left_terrain: PanelContainer
var _left_objects: PanelContainer
var _left_mission: PanelContainer
var obj_tool := "structure:e_tower_gun"
var obj_hold := false
var obj_level := 1
var obj_block := false
var _palette_buttons := {}
var _opt_buttons := {}
var _mission_type_buttons := {}
var _m_rows := {}
var _m_time: SpinBox
var _m_count: SpinBox
var _m_need: SpinBox
var _m_start: SpinBox
var _m_gap: SpinBox
var _m_kind_buttons := {}
var _m_waves_btn: Button
var _m_brief: TextEdit
var _m_type := "waves"
var _m_kind := "convoy"
var _m_waves := true


func _ready() -> void:
	map_view = MapView.new()
	add_child(map_view)
	camera = CameraController.new()
	camera.min_zoom = 0.1
	camera.free_pan = true
	add_child(camera)
	var overlay := _GridOverlay.new()
	overlay.editor = self
	add_child(overlay)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = Ui.theme
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	camera.tapped.connect(func(p: Vector2) -> void:
		if mode == "objects":
			_object_tap(Vector2i((p / TILE).floor()))
			return
		if mode != "terrain":
			return
		_begin_stroke()
		_paint(Vector2i((p / TILE).floor()))
		_end_stroke())
	camera.selection_updated.connect(func(a: Vector2, b: Vector2) -> void:
		if mode != "terrain":
			return
		var start := _last_paint if _stroke_open else Vector2i((a / TILE).floor())
		_begin_stroke()
		_paint_line(start, Vector2i((b / TILE).floor())))
	camera.selection_ended.connect(func(_a: Vector2, _b: Vector2) -> void: _end_stroke())
	camera.selection_cancelled.connect(_end_stroke)
	camera.is_over_ui = _is_over_ui

	_load(Ui.editor_map if Ui.editor_map != null else _default_map())


# --- Données ----------------------------------------------------------------------

func _default_map() -> MapData:
	var m := MapData.new()
	m.NAME = "Nouvelle carte"
	var w := 44
	var h := 28
	var g: Array[String] = []
	for y in h:
		g.append(".".repeat(w))
	m.LAYOUT = "\n".join(g)
	var tmp := _rows_from(m.LAYOUT)
	_stamp_base(tmp, Vector2i(7, h / 2))
	_set_char(tmp, Vector2i(w - 2, h / 2), "S")
	for c in [Vector2i(12, h / 2 - 3), Vector2i(13, h / 2 - 3), Vector2i(12, h / 2 + 3)]:
		_set_char(tmp, c, "M")
	m.LAYOUT = "\n".join(tmp)
	return m


func _rows_from(layout: String) -> Array[String]:
	var out: Array[String] = []
	for line in layout.split("\n"):
		if line.strip_edges() != "":
			out.append(line.strip_edges())
	return out


func _load(m: MapData) -> void:
	data = m
	rows = _rows_from(m.LAYOUT)
	_undo.clear()
	_name_edit.text = data.NAME
	_w_spin.set_value_no_signal(rows[0].length())
	_h_spin.set_value_no_signal(rows.size())
	_waves_spin.set_value_no_signal(data.waves)
	_diff_spin.set_value_no_signal(data.difficulty)
	_interval_spin.set_value_no_signal(data.interval)
	_load_mission_ui()
	_refresh(true)
	_fit_camera()
	_highlight()


func _fit_camera() -> void:
	var world := Vector2(rows[0].length(), rows.size()) * TILE
	var vp := get_viewport_rect().size - Vector2(500, 160) # place prise par les panneaux
	var z := clampf(minf(vp.x / world.x, vp.y / world.y), camera.min_zoom, 1.0)
	camera.zoom = Vector2(z, z)
	camera.center_on(world * 0.5 + Vector2(-20, -30) / z)


func _refresh(full_check := false) -> void:
	grid = MapLoader.from_layout("\n".join(rows))
	map_view.setup(grid, data.GROUND)
	camera.set_bounds(Rect2(Vector2.ZERO, Vector2(grid.width, grid.height) * TILE).grow(TILE * 2))
	if full_check:
		_validate()


func _validate() -> void:
	if data == null or grid == null:
		return
	_issues = MapData.validate(grid, _mission_dict())
	var warn := _mission_warnings()
	if _issues.is_empty():
		_status.text = "✔ Carte valide · %d x %d · %d apparition(s) · %d métal · %d essence" % [
				grid.width, grid.height, grid.spawn_points.size(), grid.metal_deposits.size(), grid.essence_deposits.size()] + warn
		_status.add_theme_color_override("font_color", Ui.GREEN)
	else:
		_status.text = "✖ " + "\n✖ ".join(_issues)
		_status.add_theme_color_override("font_color", Ui.RED)


func _sync_data() -> void:
	data.NAME = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Sans nom"
	data.LAYOUT = "\n".join(rows)
	data.waves = int(_waves_spin.value)
	data.difficulty = _diff_spin.value
	data.interval = _interval_spin.value
	data.mission = _mission_dict()


# --- Peinture ----------------------------------------------------------------------

func _set_char(r: Array[String], c: Vector2i, ch: String) -> void:
	if c.y < 0 or c.y >= r.size() or c.x < 0 or c.x >= r[c.y].length():
		return
	var line := r[c.y]
	r[c.y] = line.substr(0, c.x) + ch + line.substr(c.x + 1)


func _stamp_base(r: Array[String], center: Vector2i, ch := "B") -> void:
	for y in r.size():
		r[y] = r[y].replace(ch, ".")
	var w := r[0].length()
	var cx := clampi(center.x, 1, w - 2)
	var cy := clampi(center.y, 1, r.size() - 2)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_set_char(r, Vector2i(cx + dx, cy + dy), ch)


func _begin_stroke() -> void:
	if not _stroke_open:
		_stroke_open = true
		_undo.append(rows.duplicate())
		if _undo.size() > 40:
			_undo.pop_front()


func _end_stroke() -> void:
	if _stroke_open:
		_stroke_open = false
		_validate()


func _paint(c: Vector2i, refresh := true) -> void:
	_last_paint = c
	if tool == "B" or tool == "b":
		_stamp_base(rows, c, tool)
	else:
		var r := brush - 1
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cc := c + Vector2i(dx, dy)
				if cc.y < 0 or cc.y >= rows.size() or cc.x < 0 or cc.x >= rows[0].length():
					continue
				var cur := rows[cc.y][cc.x]
				if (cur == "B" or cur == "b") and tool != ".":
					continue # on ne peint pas par-dessus la base (gomme exceptée)
				var ch := tool
				# Ponts automatiques : route ou rails sur l'eau (et l'inverse)
				if tool == "=" and cur in ["~", "Y"]:
					ch = "H"
				elif tool == "T" and cur in ["~", "H"]:
					ch = "Y"
				elif tool == "~" and cur in ["=", "H"]:
					ch = "H"
				elif tool == "~" and cur in ["T", "Y"]:
					ch = "Y"
				_set_char(rows, cc, ch)
	if refresh:
		_refresh()


## Peint toutes les cases entre deux points (un glissé rapide ne laisse pas de trous).
func _paint_line(a: Vector2i, b: Vector2i) -> void:
	if tool == "B" or tool == "b":
		_paint(b)
		_last_paint = b
		return
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxf(n, 1)
		var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if c != _last_paint or i == 0:
			_paint(c, false)
	_last_paint = b
	_refresh()


func _undo_last() -> void:
	if _undo.is_empty():
		Ui.toast("Rien à annuler")
		return
	rows = _undo.pop_back()
	_refresh(true)


func _resize(w: int, h: int) -> void:
	_undo.append(rows.duplicate())
	var out: Array[String] = []
	for y in h:
		var line := rows[y] if y < rows.size() else ""
		line = line.substr(0, w)
		line += ".".repeat(w - line.length())
		out.append(line)
	rows = out
	_refresh(true)


# --- Interface ----------------------------------------------------------------------

func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := Ui.box(Color(0.03, 0.06, 0.11, 0.93), Color(Ui.CYAN, 0.45), 2, 6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	return p


func _spin(min_v: float, max_v: float, step: float, value: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(110, 44)
	s.get_line_edit().add_theme_font_size_override("font_size", 20)
	return s


func _small_button(text: String, w := 0.0) -> Button:
	var b := Ui.button(text, false, Vector2(w, 46))
	b.add_theme_font_size_override("font_size", 14)
	return b


func _build_ui() -> void:
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	_ui.add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col := Ui.vbox(10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(col)

	# Barre du haut : retour, nom, sol, taille
	var top := _panel()
	var th := Ui.hbox(10)
	var back := _small_button("‹ MENU", 110)
	back.pressed.connect(func() -> void:
		_sync_data()
		Ui.editor_map = data
		Ui.goto("menu"))
	th.add_child(back)
	th.add_child(Ui.title("ÉDITEUR", 18, Ui.CYAN))
	for pair in [["terrain", "TERRAIN"], ["objects", "OBJETS"], ["mission", "MISSION"]]:
		var tb := _small_button(pair[1], 100)
		var md: String = pair[0]
		tb.pressed.connect(func() -> void: _set_mode(md))
		_tab_buttons[md] = tb
		th.add_child(tb)
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(170, 44)
	_name_edit.add_theme_font_size_override("font_size", 20)
	_name_edit.placeholder_text = "Nom de la carte"
	th.add_child(_name_edit)
	var tgap := Ui.spacer()
	tgap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(tgap)
	_w_spin = _spin(20, 80, 1, 44)
	_h_spin = _spin(14, 50, 1, 28)
	_w_spin.custom_minimum_size.x = 88
	_h_spin.custom_minimum_size.x = 88
	th.add_child(_w_spin)
	th.add_child(Ui.label("×", 20))
	th.add_child(_h_spin)
	var apply := _small_button("TAILLE ✓", 100)
	apply.pressed.connect(func() -> void: _resize(int(_w_spin.value), int(_h_spin.value)))
	th.add_child(apply)
	top.add_child(th)
	col.add_child(top)

	var mid := Ui.hbox(10)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(mid)

	# Outils à gauche
	var left := _panel()
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var lv := Ui.vbox(5)
	lv.add_child(Ui.label("PINCEAU", 16, Ui.MUTED, true))
	var tg := GridContainer.new()
	tg.columns = 2
	tg.add_theme_constant_override("h_separation", 4)
	tg.add_theme_constant_override("v_separation", 4)
	lv.add_child(tg)
	for t in TOOLS:
		var b := _small_button(t.name, 73)
		b.custom_minimum_size.y = 38
		b.add_theme_font_size_override("font_size", 11)
		var sw := ColorRect.new()
		sw.color = t.color
		sw.custom_minimum_size = Vector2(8, 8)
		sw.size = Vector2(8, 8)
		sw.position = Vector2(5, 5)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(sw)
		var id: String = t.id
		b.pressed.connect(func() -> void:
			tool = id
			_highlight())
		_tool_buttons[id] = b
		tg.add_child(b)
	lv.add_child(Ui.label("TAILLE", 16, Ui.MUTED, true))
	var bh := Ui.hbox(4)
	for n in [1, 2, 3]:
		var b := _small_button(str(n), 46)
		var size: int = n
		b.pressed.connect(func() -> void:
			brush = size
			_highlight())
		_brush_buttons[n] = b
		bh.add_child(b)
	lv.add_child(bh)
	lv.add_child(Ui.label("SOL", 16, Ui.MUTED, true))
	var gg := GridContainer.new()
	gg.columns = 2
	gg.add_theme_constant_override("h_separation", 4)
	gg.add_theme_constant_override("v_separation", 4)
	for pair in [["grass", "HERBE"], ["sand", "SABLE"], ["dirt", "TERRE"], ["mars", "MARS"], ["metal", "MÉTAL"]]:
		var b := _small_button(pair[1], 73)
		b.custom_minimum_size.y = 38
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func() -> void:
			data.GROUND = pair[0]
			_refresh()
			_highlight())
		_ground_buttons[pair[0]] = b
		gg.add_child(b)
	lv.add_child(gg)
	var undo := _small_button("↶ ANNULER", 150)
	undo.pressed.connect(_undo_last)
	lv.add_child(undo)
	# Zoom et recadrage (utile au doigt)
	var zh := Ui.hbox(4)
	for z in [["−", 0.8], ["+", 1.25]]:
		var zb := _small_button(z[0], 46)
		zb.custom_minimum_size.y = 40
		var f: float = z[1]
		zb.pressed.connect(func() -> void: camera._zoom_at(camera.zoom.x * f, get_viewport_rect().size * 0.5))
		zh.add_child(zb)
	var fit := _small_button("CADRER", 54)
	fit.custom_minimum_size.y = 40
	fit.add_theme_font_size_override("font_size", 11)
	fit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fit.pressed.connect(_fit_camera)
	zh.add_child(fit)
	lv.add_child(zh)
	left.add_child(lv)
	mid.add_child(left)
	_left_terrain = left
	_left_objects = _build_object_panel()
	mid.add_child(_left_objects)
	_left_mission = _build_mission_panel()
	mid.add_child(_left_mission)
	_set_mode("terrain")

	var gap := Ui.spacer()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE # sinon il avale les touchers sur la carte
	mid.add_child(gap)

	# Réglages et fichiers à droite
	var right := _panel()
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.custom_minimum_size = Vector2(290, 0)
	var rv := Ui.vbox(8)
	rv.add_child(Ui.label("VAGUES", 16, Ui.MUTED, true))
	var g := GridContainer.new()
	g.add_theme_constant_override("v_separation", 6)
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_child(Ui.label("Nombre", 18))
	_waves_spin = _spin(3, 40, 1, 10)
	_waves_spin.custom_minimum_size.x = 100
	g.add_child(_waves_spin)
	g.add_child(Ui.label("Difficulté", 18))
	_diff_spin = _spin(0.5, 2.5, 0.05, 1.0)
	g.add_child(_diff_spin)
	g.add_child(Ui.label("Intervalle (s)", 18))
	_interval_spin = _spin(12, 60, 1, 30)
	g.add_child(_interval_spin)
	rv.add_child(g)
	rv.add_child(Ui.label("OBJECTIFS BONUS", 14, Ui.GOLD, true))
	var oh := Ui.hbox(4)
	for pair in [["train", "TRAIN"], ["convoy", "CONVOI"], ["boat", "BATEAU"]]:
		var b := _small_button(pair[1], 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
		b.add_theme_font_size_override("font_size", 12)
		var typ: String = pair[0]
		b.pressed.connect(func() -> void: _toggle_objective(typ))
		_obj_buttons[typ] = b
		oh.add_child(b)
	rv.add_child(oh)
	var files := Ui.hbox(6)
	var new_b := _small_button("NOUVELLE", 0)
	new_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_b.pressed.connect(func() -> void: _load(_default_map()))
	files.add_child(new_b)
	var open_b := _small_button("OUVRIR", 0)
	open_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_b.pressed.connect(_show_open)
	files.add_child(open_b)
	rv.add_child(files)
	var save_b := Ui.button("ENREGISTRER", false, Vector2(0, 50))
	save_b.add_theme_font_size_override("font_size", 16)
	save_b.pressed.connect(_save)
	rv.add_child(save_b)
	var test_b := Ui.button("▶ TESTER", true, Vector2(0, 56))
	test_b.pressed.connect(_test)
	rv.add_child(test_b)
	_status = Ui.label("", 16, Ui.GREEN)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(266, 0)
	rv.add_child(_status)
	right.add_child(rv)
	mid.add_child(right)

	var hint := Ui.label("1 doigt : peindre  ·  2 doigts : déplacer / zoomer  ·  PC : clic = peindre, clic droit + ZQSD = déplacer, molette = zoom", 16, Ui.MUTED)
	hint.add_theme_constant_override("outline_size", 6)
	col.add_child(hint)

	_open_layer = Control.new()
	_open_layer.visible = false
	_ui.add_child(_open_layer)
	_open_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _toggle_objective(typ: String) -> void:
	var found := -1
	for i in data.objectives.size():
		if data.objectives[i].type == typ:
			found = i
	if found >= 0:
		data.objectives.remove_at(found)
	else:
		data.objectives.append({"type": typ, "wave": OBJECTIVE_DEFAULT_WAVE[typ]})
	_highlight()
	_validate()


func _highlight() -> void:
	for typ in _obj_buttons:
		var on := data != null and data.objectives.any(func(o: Dictionary) -> bool: return o.type == typ)
		(_obj_buttons[typ] as Button).theme_type_variation = "PrimaryButton" if on else ""
	for id in _tool_buttons:
		(_tool_buttons[id] as Button).theme_type_variation = "PrimaryButton" if id == tool else ""
	for n in _brush_buttons:
		(_brush_buttons[n] as Button).theme_type_variation = "PrimaryButton" if n == brush else ""
	for gk in _ground_buttons:
		(_ground_buttons[gk] as Button).theme_type_variation = "PrimaryButton" if data != null and gk == data.GROUND else ""


func _is_over_ui(p: Vector2) -> bool:
	if _open_layer.visible:
		return true
	return _hit(_ui, p)


func _hit(node: Control, p: Vector2) -> bool:
	for c in node.get_children():
		if c is Control and c.visible:
			if (c is PanelContainer or c is Button) and c.get_global_rect().has_point(p):
				return true
			if _hit(c, p):
				return true
	return false


# --- Fichiers et test ------------------------------------------------------------------

func _save() -> void:
	_sync_data()
	var p := data.path if data.path.ends_with(".json") and data.path.begins_with(MapData.custom_dir()) \
			else MapData.custom_dir() + MapData.slug(data.NAME) + ".json"
	var err := data.save_to(p)
	if err == OK:
		Ui.toast("Carte enregistrée : %s" % p.get_file(), Ui.GREEN)
	else:
		Ui.toast("Échec de l'enregistrement (%d)" % err, Ui.RED)


func _test() -> void:
	_sync_data()
	_validate()
	if not _issues.is_empty():
		Ui.toast(_issues[0], Ui.RED)
		return
	Ui.editor_map = data
	var copy := MapData.new()
	copy.NAME = data.NAME
	copy.GROUND = data.GROUND
	copy.LAYOUT = data.LAYOUT
	copy.waves = data.waves
	copy.difficulty = data.difficulty
	copy.interval = data.interval
	copy.mission = data.mission.duplicate(true)
	copy.entities = data.entities.duplicate(true)
	copy.objectives = data.objectives.duplicate(true)
	Ui.play_custom(copy)


func _show_open() -> void:
	for c in _open_layer.get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(Ui.BG, 0.8)
	_open_layer.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_open_layer.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := Ui.panel(Vector2(560, 0), true)
	var v := Ui.vbox(8)
	v.add_child(Ui.title("OUVRIR UNE CARTE", 22, Ui.CYAN))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := Ui.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(Ui.label("Campagne (ouverte en copie)", 16, Ui.MUTED, true))
	for l in Content.LEVELS:
		var md := MapData.load_from(l.map)
		_open_entry(list, "%02d · %s" % [l.id, md.NAME], func() -> void:
			md.path = ""
			md.waves = l.waves
			md.difficulty = l.difficulty
			md.interval = l.get("interval", 30.0)
			_load(md))
	var customs := MapData.list_custom()
	list.add_child(Ui.label("Mes cartes", 16, Ui.MUTED, true))
	if customs.is_empty():
		list.add_child(Ui.label("Aucune carte enregistrée pour l'instant", 16, Ui.MUTED))
	for path in customs:
		var md := MapData.load_from(path)
		_open_entry(list, md.NAME, func() -> void: _load(md))
	scroll.add_child(list)
	v.add_child(scroll)
	var close := Ui.button("FERMER", false, Vector2(0, 50))
	close.pressed.connect(func() -> void: _open_layer.visible = false)
	v.add_child(close)
	p.add_child(v)
	center.add_child(p)
	_open_layer.visible = true


func _open_entry(list: VBoxContainer, text: String, on_open: Callable) -> void:
	var b := Ui.button(text, false, Vector2(0, 50))
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(func() -> void:
		on_open.call()
		_open_layer.visible = false)
	list.add_child(b)



## Quadrillage + repères (base, apparitions) pour peindre précisément.
# --- Onglets ------------------------------------------------------------------------

func _set_mode(m: String) -> void:
	mode = m
	_left_terrain.visible = m == "terrain"
	_left_objects.visible = m == "objects"
	_left_mission.visible = m == "mission"
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).theme_type_variation = "PrimaryButton" if k == m else ""


# --- Objets ------------------------------------------------------------------------

## Palette : [identifiant "genre:type", libellé]
func _palette() -> Array:
	var cats := []
	var structs := []
	for k in Balance.ENEMY_STRUCTURES:
		structs.append(["structure:" + k, str(Balance.ENEMY_STRUCTURES[k].name).to_upper()])
	cats.append(["ENNEMIS · STRUCTURES", structs])
	var foes := []
	for k in Balance.ENEMIES:
		foes.append(["enemy:" + k, k.to_upper()])
	cats.append(["ENNEMIS · UNITÉS (EN GARDE)", foes])
	var towers := []
	for k in Content.TOWER_ORDER:
		towers.append(["ally_tower:" + k, str(Content.TOWERS[k].name).to_upper()])
	cats.append(["ALLIÉS · TOURELLES", towers])
	var allies := []
	for k in Content.UNITS:
		if k not in ["worker", "escort_truck", "commander"]:
			allies.append(["ally_unit:" + k, str(Content.UNITS[k].name).to_upper()])
	cats.append(["ALLIÉS · UNITÉS", allies])
	cats.append(["MISSION", [["vip:commander", "VIP À ESCORTER"], ["escortee:", "CONVOI ALLIÉ"], ["waypoint:", "POINT DE PASSAGE"],
			["zone:goal", "ZONE D'ARRIVÉE"], ["zone:capture", "ZONE DE PRISE"]]])
	var decos := []
	for f in DirAccess.get_files_at("res://assets/deco"):
		var fname := f.trim_suffix(".import")
		if fname.ends_with(".png") and not decos.any(func(x: Array) -> bool: return x[0] == "deco:" + fname.get_basename()):
			decos.append(["deco:" + fname.get_basename(), fname.get_basename().to_upper()])
	cats.append(["DÉCOR (dossier assets/deco)", decos])
	return cats


func _build_object_panel() -> PanelContainer:
	var p := _panel()
	p.custom_minimum_size = Vector2(300, 0)
	var v := Ui.vbox(6)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(290, 410)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := Ui.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var er := _small_button("✖ GOMME OBJETS", 0)
	er.custom_minimum_size.y = 36
	er.pressed.connect(func() -> void:
		obj_tool = "erase"
		_highlight_objects())
	_palette_buttons["erase"] = er
	list.add_child(er)
	for cat in _palette():
		list.add_child(Ui.label(cat[0], 12, Ui.GOLD, true))
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override("h_separation", 4)
		g.add_theme_constant_override("v_separation", 4)
		for it in cat[1]:
			var b := _small_button(it[1], 136)
			b.custom_minimum_size.y = 34
			b.add_theme_font_size_override("font_size", 10)
			b.clip_text = true
			var id: String = it[0]
			b.pressed.connect(func() -> void:
				obj_tool = id
				_highlight_objects())
			_palette_buttons[id] = b
			g.add_child(b)
		list.add_child(g)
	scroll.add_child(list)
	v.add_child(scroll)
	var opts := Ui.hbox(4)
	for o in [["hold", "IMMOBILE"], ["lvl", "NIV 1"], ["block", "BLOQUE"]]:
		var b := _small_button(o[1], 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 34
		b.add_theme_font_size_override("font_size", 10)
		var key: String = o[0]
		b.pressed.connect(func() -> void:
			match key:
				"hold":
					obj_hold = not obj_hold
				"lvl":
					obj_level = obj_level % 3 + 1
				"block":
					obj_block = not obj_block
			_highlight_objects())
		_opt_buttons[key] = b
		opts.add_child(b)
	v.add_child(opts)
	v.add_child(Ui.label("Toucher = poser · gomme = retirer\nIMMOBILE : unités · NIV : tourelles · BLOQUE : décor", 11, Ui.MUTED))
	p.add_child(v)
	_highlight_objects.call_deferred()
	return p


func _highlight_objects() -> void:
	for id in _palette_buttons:
		(_palette_buttons[id] as Button).theme_type_variation = "PrimaryButton" if id == obj_tool else ""
	if _opt_buttons.has("hold"):
		(_opt_buttons.hold as Button).theme_type_variation = "PrimaryButton" if obj_hold else ""
		(_opt_buttons.block as Button).theme_type_variation = "PrimaryButton" if obj_block else ""
		(_opt_buttons.lvl as Button).text = "NIV %d" % obj_level


## Cases couvertes par un objet (les structures font 1, 2 ou 3 cases de côté).
static func entity_cells(e: Dictionary) -> Array[Vector2i]:
	var c := Vector2i(int(e.cell[0]), int(e.cell[1]))
	var size := 1
	if e.kind == "structure" and Balance.ENEMY_STRUCTURES.has(e.type):
		size = int(Balance.ENEMY_STRUCTURES[e.type].size)
	var out: Array[Vector2i] = []
	for dy in size:
		for dx in size:
			out.append(c + Vector2i(dx, dy))
	return out


func _object_tap(c: Vector2i) -> void:
	if not grid.is_inside(c):
		return
	# Un objet déjà là : la gomme le retire, sinon on le remplace.
	for i in range(data.entities.size() - 1, -1, -1):
		if entity_cells(data.entities[i]).has(c):
			data.entities.remove_at(i)
			if obj_tool == "erase":
				_validate()
				return
	if obj_tool == "erase":
		return
	var parts := obj_tool.split(":")
	var e := {"kind": parts[0], "cell": [c.x, c.y]}
	match parts[0]:
		"structure", "enemy", "ally_tower", "ally_unit", "vip":
			e.type = parts[1]
		"zone":
			e.role = parts[1]
			e.radius = 2.5
		"deco":
			e.sprite = parts[1]
			e.block = obj_block
		"waypoint":
			e.order = data.entities.filter(func(x: Dictionary) -> bool: return x.kind == "waypoint").size()
	if parts[0] in ["enemy", "ally_unit"]:
		e.hold = obj_hold
	if parts[0] == "ally_tower":
		e.level = obj_level
	if parts[0] in ["vip", "escortee"]:
		# Un seul VIP / convoi allié par carte
		data.entities = data.entities.filter(func(x: Dictionary) -> bool: return x.kind != parts[0])
	data.entities.append(e)
	_validate()


# --- Mission ------------------------------------------------------------------------

func _build_mission_panel() -> PanelContainer:
	var p := _panel()
	p.custom_minimum_size = Vector2(300, 0)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := Ui.vbox(5)
	v.add_child(Ui.label("TYPE DE MISSION", 13, Ui.GOLD, true))
	var tg := GridContainer.new()
	tg.columns = 2
	tg.add_theme_constant_override("h_separation", 4)
	tg.add_theme_constant_override("v_separation", 4)
	for t in Mission.TYPES:
		var b := _small_button(str(Mission.TYPE_NAMES[t]).to_upper(), 136)
		b.custom_minimum_size.y = 34
		b.add_theme_font_size_override("font_size", 10)
		var tt: String = t
		b.pressed.connect(func() -> void:
			_m_type = tt
			_mission_ui_refresh())
		_mission_type_buttons[t] = b
		tg.add_child(b)
	v.add_child(tg)
	var grid_box := GridContainer.new()
	grid_box.columns = 2
	grid_box.add_theme_constant_override("v_separation", 4)
	_m_time = _spin(10, 3600, 10, 300)
	_m_count = _spin(1, 20, 1, 3)
	_m_need = _spin(1, 20, 1, 3)
	_m_start = _spin(0, 600, 5, 20)
	_m_gap = _spin(5, 300, 5, 40)
	for row in [["time", "Durée (s)", _m_time], ["count", "Nb de convois", _m_count], ["need", "À détruire", _m_need],
			["start", "Départ (s)", _m_start], ["gap", "Écart (s)", _m_gap]]:
		var l := Ui.label(row[1], 14)
		var sp: SpinBox = row[2]
		sp.custom_minimum_size = Vector2(110, 36)
		sp.value_changed.connect(func(_x: float) -> void: _validate())
		grid_box.add_child(l)
		grid_box.add_child(sp)
		_m_rows[row[0]] = [l, sp]
	v.add_child(grid_box)
	var kh := Ui.hbox(4)
	for pair in [["train", "TRAIN"], ["convoy", "CAMIONS"], ["boat", "BATEAU"]]:
		var b := _small_button(pair[1], 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 32
		b.add_theme_font_size_override("font_size", 10)
		var k: String = pair[0]
		b.pressed.connect(func() -> void:
			_m_kind = k
			_mission_ui_refresh())
		_m_kind_buttons[k] = b
		kh.add_child(b)
	v.add_child(kh)
	_m_rows["kind"] = [kh]
	_m_waves_btn = _small_button("VAGUES ENNEMIES : OUI", 0)
	_m_waves_btn.custom_minimum_size.y = 34
	_m_waves_btn.add_theme_font_size_override("font_size", 11)
	_m_waves_btn.pressed.connect(func() -> void:
		_m_waves = not _m_waves
		_mission_ui_refresh())
	v.add_child(_m_waves_btn)
	v.add_child(Ui.label("BRIEFING", 13, Ui.GOLD, true))
	_m_brief = TextEdit.new()
	_m_brief.custom_minimum_size = Vector2(280, 90)
	_m_brief.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_m_brief.placeholder_text = "Texte affiché au début de la mission"
	_m_brief.add_theme_font_size_override("font_size", 14)
	v.add_child(_m_brief)
	p.add_child(v)
	return p


func _load_mission_ui() -> void:
	var m: Dictionary = data.mission
	_m_type = str(m.get("type", "waves"))
	_m_time.set_value_no_signal(float(m.get("time", 300)))
	_m_count.set_value_no_signal(float(m.get("convoy_count", 3)))
	_m_need.set_value_no_signal(float(m.get("convoy_need", 3)))
	_m_start.set_value_no_signal(float(m.get("convoy_start", 20)))
	_m_gap.set_value_no_signal(float(m.get("convoy_interval", 40)))
	_m_kind = str(m.get("convoy_kind", "convoy"))
	_m_waves = Mission.new(m).waves_enabled()
	_m_brief.text = str(m.get("briefing", ""))
	_mission_ui_refresh()


func _mission_ui_refresh() -> void:
	for t in _mission_type_buttons:
		(_mission_type_buttons[t] as Button).theme_type_variation = "PrimaryButton" if t == _m_type else ""
	for k in _m_kind_buttons:
		(_m_kind_buttons[k] as Button).theme_type_variation = "PrimaryButton" if k == _m_kind else ""
	var show := {
		"time": _m_type in ["survive", "capture"],
		"count": _m_type == "convoy", "need": _m_type == "convoy", "start": _m_type == "convoy",
		"gap": _m_type == "convoy", "kind": _m_type == "convoy",
	}
	for k in _m_rows:
		for n in _m_rows[k]:
			(n as Control).visible = show.get(k, false)
	(_m_rows.time[0] as Label).text = "Durée (s)" if _m_type == "survive" else "Tenir chaque zone (s)"
	if _m_type == "waves":
		_m_waves = true
	_m_waves_btn.text = "VAGUES ENNEMIES : %s" % ("OUI" if _m_waves else "NON")
	_m_waves_btn.disabled = _m_type == "waves"
	_validate()


func _mission_dict() -> Dictionary:
	if _m_brief == null:
		return data.mission if data != null else {}
	var m := {"type": _m_type, "waves_enabled": _m_waves, "briefing": _m_brief.text.strip_edges()}
	match _m_type:
		"survive", "capture":
			m.time = int(_m_time.value)
		"convoy":
			m.convoy_kind = _m_kind
			m.convoy_count = int(_m_count.value)
			m.convoy_need = mini(int(_m_need.value), int(_m_count.value))
			m.convoy_start = _m_start.value
			m.convoy_interval = _m_gap.value
	return m


func _mission_warnings() -> String:
	var w := ""
	var kinds := {}
	for e in data.entities:
		kinds[e.kind + ":" + str(e.get("type", e.get("role", "")))] = true
		kinds[e.kind] = true
	match _m_type:
		"destroy_base":
			if not kinds.has("structure:e_hq"):
				w += "\n⚠ Pose une BASE ENNEMIE (onglet Objets)"
		"escort":
			if not kinds.has("vip") or not kinds.has("zone:goal"):
				w += "\n⚠ Il faut un VIP et une ZONE D'ARRIVÉE"
		"escort_defend":
			if not kinds.has("escortee") or not kinds.has("waypoint"):
				w += "\n⚠ Il faut un CONVOI ALLIÉ et des POINTS DE PASSAGE"
		"capture":
			if not kinds.has("zone:capture"):
				w += "\n⚠ Pose au moins une ZONE DE PRISE"
		"convoy":
			var need: Callable = {"train": grid.is_rail, "convoy": grid.is_road, "boat": grid.is_water}[_m_kind]
			var any := false
			for y in grid.height:
				for x in grid.width:
					if need.call(Vector2i(x, y)):
						any = true
			if not any:
				w += "\n⚠ Les convois ont besoin de %s" % {"train": "rails", "convoy": "route", "boat": "eau"}[_m_kind]
	for o in data.objectives:
		var need: Callable = {"train": grid.is_rail, "convoy": grid.is_road, "boat": grid.is_water}[o.type]
		var any := false
		for y in grid.height:
			for x in grid.width:
				if need.call(Vector2i(x, y)):
					any = true
		if not any:
			w += "\n⚠ %s sans %s" % [Balance.OBJECTIVES[o.type].name, {"train": "rails", "convoy": "route", "boat": "eau"}[o.type]]
	return w


class _GridOverlay extends Node2D:
	var editor: Node2D
	var _tex_cache := {}

	func _ready() -> void:
		z_index = 5

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var g: GameGrid = editor.grid
		if g == null:
			return
		var t := float(TILE)
		var col := Color(1, 1, 1, 0.07)
		for x in g.width + 1:
			draw_line(Vector2(x * t, 0), Vector2(x * t, g.height * t), col, 1.0)
		for y in g.height + 1:
			draw_line(Vector2(0, y * t), Vector2(g.width * t, y * t), col, 1.0)
		draw_rect(Rect2(0, 0, g.width * t, g.height * t), Color(Ui.CYAN, 0.6), false, 3.0)
		for sp in g.spawn_points:
			var c := (Vector2(sp) + Vector2(0.5, 0.5)) * t
			draw_circle(c, t * 0.42, Color(Ui.RED, 0.35))
			draw_arc(c, t * 0.42, 0, TAU, 24, Ui.RED, 3.0)
		if not g.base2_cells.is_empty():
			var r2 := Rect2(Vector2(g.base2_cells[0]) * t, Vector2.ZERO)
			for b in g.base2_cells:
				r2 = r2.merge(Rect2(Vector2(b) * t, Vector2(t, t)))
			draw_rect(r2, Color(1.0, 0.75, 0.15, 0.25))
			draw_rect(r2.grow(2), Color(1.0, 0.75, 0.15), false, 3.0)
			draw_string(ThemeDB.fallback_font, r2.get_center() + Vector2(-18, 10), "J2", HORIZONTAL_ALIGNMENT_CENTER, 36, 30, Color(1.0, 0.8, 0.2))
		_draw_entities(t)
		if not g.base_cells.is_empty():
			var r := Rect2(Vector2(g.base_cells[0]) * t, Vector2.ZERO)
			for b in g.base_cells:
				r = r.merge(Rect2(Vector2(b) * t, Vector2(t, t)))
			draw_rect(r.grow(2), Ui.CYAN, false, 3.0)


	func _draw_entities(t: float) -> void:
		var d: MapData = editor.data
		if d == null:
			return
		var font := ThemeDB.fallback_font
		var wps: Array = []
		for e: Dictionary in d.entities:
			var c := Vector2(int(e.cell[0]), int(e.cell[1]))
			var center := (c + Vector2(0.5, 0.5)) * t
			match str(e.kind):
				"structure":
					var def: Dictionary = Balance.ENEMY_STRUCTURES.get(e.type, {})
					var sz := float(def.get("size", 1)) * t
					var r := Rect2(c * t, Vector2(sz, sz))
					var tex: Texture2D = Sprites.W_BASE if def.get("look", "") == "hq" else (Sprites.W_BARRACKS if def.get("look", "") in ["barracks", "bunker"] else null)
					if tex == null and Sprites.TOWER_LOOK.has(def.get("look", "")):
						draw_texture_rect(Sprites.TOWER_LOOK[def.look].base, r, false, Color(1, 0.5, 0.45))
						tex = Sprites.TOWER_LOOK[def.look].turret
						var k := r.size.x * 0.9
						draw_texture_rect(tex, Rect2(r.get_center() - Vector2(k, k) / 2, Vector2(k, k)), false, Color(1, 0.6, 0.55))
					elif tex != null:
						draw_texture_rect(tex, r, false, Color(1, 0.5, 0.45))
					else:
						draw_texture_rect(Sprites.ENEMY_LOOK.siege.tex, r, false)
					draw_rect(r, Color(1, 0.2, 0.2), false, 3.0)
				"enemy":
					var lk: Dictionary = Sprites.ENEMY_LOOK.get(e.type, {})
					if not lk.is_empty():
						draw_texture_rect(lk.tex, Rect2(center - Vector2(28, 28), Vector2(56, 56)), false)
					draw_arc(center, t * 0.45, 0, TAU, 20, Color(1, 0.25, 0.2), 2.5)
					if e.get("hold", false):
						draw_string(font, center + Vector2(-6, -18), "■", HORIZONTAL_ALIGNMENT_CENTER, 12, 14, Color(1, 0.4, 0.3))
				"ally_tower":
					var tl: Dictionary = Sprites.TOWER_LOOK.get(e.type, {})
					if not tl.is_empty():
						draw_texture_rect(tl.base, Rect2(c * t, Vector2(t, t)), false)
						draw_texture_rect(tl.turret, Rect2(center - Vector2(t, t) * 0.45, Vector2(t, t) * 0.9), false)
					draw_rect(Rect2(c * t, Vector2(t, t)), Ui.GREEN, false, 2.5)
					draw_string(font, c * t + Vector2(4, 16), "N%d" % int(e.get("level", 1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ui.GREEN)
				"ally_unit", "vip":
					var ul: Dictionary = Sprites.UNIT_LOOK.get(e.get("type", "soldier"), {})
					if not ul.is_empty():
						draw_texture_rect(ul.tex, Rect2(center - Vector2(26, 26), Vector2(52, 52)), false, ul.tint)
					draw_arc(center, t * 0.45, 0, TAU, 20, Ui.GOLD if e.kind == "vip" else Ui.GREEN, 2.5)
					if e.kind == "vip":
						draw_string(font, center + Vector2(-20, -24), "VIP", HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Ui.GOLD)
				"escortee":
					draw_rect(Rect2(center - Vector2(22, 16), Vector2(44, 32)), Color(0.3, 0.6, 0.4))
					draw_arc(center, t * 0.5, 0, TAU, 20, Ui.GREEN, 3.0)
					draw_string(font, center + Vector2(-30, -26), "CONVOI", HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Ui.GREEN)
				"waypoint":
					wps.append([int(e.get("order", 0)), center])
				"zone":
					var rad := float(e.get("radius", 2.5)) * t
					var col := Ui.GREEN if e.role == "goal" else Ui.GOLD
					draw_circle(center, rad, Color(col, 0.12))
					draw_arc(center, rad, 0, TAU, 40, col, 3.0)
					draw_string(font, center + Vector2(-50, 6), "ARRIVÉE" if e.role == "goal" else "PRISE", HORIZONTAL_ALIGNMENT_CENTER, 100, 18, col)
				"deco":
					var sp := str(e.get("sprite", ""))
					if not _tex_cache.has(sp):
						_tex_cache[sp] = UnitsView.deco_texture(sp)
					var tex2: Texture2D = _tex_cache[sp]
					if tex2 != null:
						draw_texture_rect(tex2, Rect2(c * t, Vector2(t, t)), false)
					if e.get("block", false):
						draw_rect(Rect2(c * t, Vector2(t, t)), Color(1, 1, 1, 0.5), false, 2.0)
		wps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for i in wps.size():
			if i > 0:
				draw_dashed_line(wps[i - 1][1], wps[i][1], Color(Ui.GREEN, 0.7), 3.0, 12.0)
			draw_circle(wps[i][1], 14, Color(0.1, 0.3, 0.15))
			draw_arc(wps[i][1], 14, 0, TAU, 20, Ui.GREEN, 2.5)
			draw_string(font, wps[i][1] + Vector2(-10, 6), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 20, 16, Ui.GREEN)
