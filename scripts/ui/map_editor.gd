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
	{"id": "~", "name": "EAU", "color": Color("1e90d6")},
	{"id": "=", "name": "ROUTE", "color": Color("3b3f46")},
	{"id": "T", "name": "RAILS", "color": Color("8a6a4a")},
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
		_begin_stroke()
		_paint(Vector2i((p / TILE).floor()))
		_end_stroke())
	camera.selection_updated.connect(func(a: Vector2, b: Vector2) -> void:
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
	_issues = MapData.validate(grid)
	var warn := ""
	for o in data.objectives:
		var need: Callable = {"train": grid.is_rail, "convoy": grid.is_road, "boat": grid.is_water}[o.type]
		var any := false
		for y in grid.height:
			for x in grid.width:
				if need.call(Vector2i(x, y)):
					any = true
		if not any:
			warn += "\n⚠ %s sans %s" % [Balance.OBJECTIVES[o.type].name, {"train": "rails", "convoy": "route", "boat": "eau"}[o.type]]
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


# --- Peinture ----------------------------------------------------------------------

func _set_char(r: Array[String], c: Vector2i, ch: String) -> void:
	if c.y < 0 or c.y >= r.size() or c.x < 0 or c.x >= r[c.y].length():
		return
	var line := r[c.y]
	r[c.y] = line.substr(0, c.x) + ch + line.substr(c.x + 1)


func _stamp_base(r: Array[String], center: Vector2i) -> void:
	for y in r.size():
		r[y] = r[y].replace("B", ".")
	var w := r[0].length()
	var cx := clampi(center.x, 1, w - 2)
	var cy := clampi(center.y, 1, r.size() - 2)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_set_char(r, Vector2i(cx + dx, cy + dy), "B")


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
	if tool == "B":
		_stamp_base(rows, c)
	else:
		var r := brush - 1
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cc := c + Vector2i(dx, dy)
				if cc.y < 0 or cc.y >= rows.size() or cc.x < 0 or cc.x >= rows[0].length():
					continue
				var cur := rows[cc.y][cc.x]
				if cur == "B" and tool != ".":
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
	if tool == "B":
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
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size = Vector2(190, 44)
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
class _GridOverlay extends Node2D:
	var editor: Node2D

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
		if not g.base_cells.is_empty():
			var r := Rect2(Vector2(g.base_cells[0]) * t, Vector2.ZERO)
			for b in g.base_cells:
				r = r.merge(Rect2(Vector2(b) * t, Vector2(t, t)))
			draw_rect(r.grow(2), Ui.CYAN, false, 3.0)
