class_name EditorUi
extends RefCounted
## Petits éléments d'interface de l'éditeur (style compact pour la souris).

const FONT := 14
const BTN_H := 28
const PANEL_BG := Color(0.035, 0.06, 0.105, 1.0)
const PANEL_EDGE := Color(0.13, 0.83, 0.93, 0.28)
const SECTION := Color("7dd3fc")
const ACTIVE := Color(0.13, 0.83, 0.93)


static var _theme: Theme
static var _icons := {}


## Thème de l'éditeur : police lisible (Rajdhani), tailles compactes.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = Ui.font_body
	t.default_font_size = FONT
	for type in ["Button", "MenuButton", "Label", "LineEdit", "TextEdit", "SpinBox", "PopupMenu", "TooltipLabel", "CheckBox"]:
		t.set_font("font", type, Ui.font_body)
		t.set_font_size("font_size", type, FONT)
	t.set_color("font_color", "Label", Color(0.85, 0.9, 0.97))
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.02, 0.04, 0.08, 0.96)
	tip.border_color = Color(ACTIVE, 0.5)
	tip.set_border_width_all(1)
	tip.set_corner_radius_all(4)
	tip.set_content_margin_all(6)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", Color(0.9, 0.95, 1.0))
	var field := StyleBoxFlat.new()
	field.bg_color = Color(0.02, 0.04, 0.08)
	field.border_color = Color(1, 1, 1, 0.12)
	field.set_border_width_all(1)
	field.set_corner_radius_all(4)
	field.content_margin_left = 6
	field.content_margin_right = 6
	var focus := field.duplicate() as StyleBoxFlat
	focus.border_color = ACTIVE
	for type in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type, field)
		t.set_stylebox("focus", type, focus)
	var pop := StyleBoxFlat.new()
	pop.bg_color = Color(0.04, 0.07, 0.12)
	pop.border_color = Color(ACTIVE, 0.4)
	pop.set_border_width_all(1)
	pop.set_content_margin_all(6)
	t.set_stylebox("panel", "PopupMenu", pop)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(ACTIVE, 0.25)
	t.set_stylebox("hover", "PopupMenu", hov)
	_theme = t
	return t


## Petites icônes dessinées (œil, cadenas), sans dépendre de la police.
static func icon(kind: String) -> Texture2D:
	if _icons.has(kind):
		return _icons[kind]
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Color(0.9, 0.95, 1.0)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var on := false
			match kind:
				"eye":
					var e := Vector2((p.x - 8) / 7.0, (p.y - 8) / 3.8)
					var d := e.length()
					on = (d <= 1.0 and d >= 0.72) or p.distance_to(Vector2(8, 8)) <= 2.2
				"lock":
					var body := Rect2(3, 7, 10, 8)
					var arc := p.distance_to(Vector2(8, 7))
					on = body.has_point(p) or (p.y < 7.5 and arc >= 3.0 and arc <= 4.6)
			if on:
				img.set_pixel(x, y, c)
	_icons[kind] = ImageTexture.create_from_image(img)
	return _icons[kind]


static func panel_style(radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	return p


static func _btn_style(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb


## Bouton compact. toggle = bouton à état (surligné quand actif).
static func button(text: String, tip := "", toggle := false, w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, BTN_H)
	b.add_theme_font_size_override("font_size", FONT)
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.09, 0.13, 0.2), Color(1, 1, 1, 0.08)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.12, 0.18, 0.28), Color(ACTIVE, 0.5)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.05, 0.32, 0.4), ACTIVE))
	b.add_theme_stylebox_override("hover_pressed", _btn_style(Color(0.06, 0.38, 0.47), ACTIVE))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(0.07, 0.09, 0.13), Color(1, 1, 1, 0.04)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", Color(0.85, 0.91, 1.0))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.25))
	return b


## Bouton principal (action forte : Tester).
static func primary(text: String, tip := "", w := 0.0) -> Button:
	var b := button(text, tip, false, w)
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.05, 0.45, 0.55), ACTIVE))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.08, 0.55, 0.66), Color.WHITE))
	b.add_theme_color_override("font_color", Color.WHITE)
	return b


static func label(text: String, size := FONT, color := Color(0.82, 0.88, 0.97)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func section(text: String) -> Label:
	var l := label(text.to_upper(), 12, SECTION)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func muted(text: String, size := 12) -> Label:
	var l := label(text, size, Color(0.55, 0.62, 0.72))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func spin(min_v: float, max_v: float, step: float, value: float, w := 84.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(w, BTN_H)
	s.get_line_edit().add_theme_font_size_override("font_size", FONT)
	s.select_all_on_focus = true
	return s


static func line_edit(placeholder := "", w := 0.0) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(w, BTN_H)
	e.add_theme_font_size_override("font_size", FONT)
	return e


static func hbox(sep := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func grid(cols: int, sep := 4) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


static func sep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 6)
	return s


## Pastille de couleur posée à gauche d'un bouton.
static func swatch(b: Button, col: Color) -> void:
	var sw := ColorRect.new()
	sw.color = col
	sw.size = Vector2(10, 10)
	sw.position = Vector2(6, (BTN_H - 10) * 0.5)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sw)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "    " + b.text
