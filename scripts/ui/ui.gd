extends Node
## Autoload « Ui » : thème futuriste global, petits composants réutilisables,
## navigation entre écrans avec fondu, notifications.

const BG := Color("070b14")
const PANEL := Color("0c1424")
const PANEL_LIGHT := Color("13203a")
const CYAN := Color("22d3ee")
const CYAN_DIM := Color("0e7490")
const MAGENTA := Color("f472b6")
const GOLD := Color("fbbf24")
const GREEN := Color("4ade80")
const RED := Color("f87171")
const TEXT := Color("e6f1ff")
const MUTED := Color("7c8ba1")
const METAL := Color("9ec5ff")
const ESSENCE := Color("ffa63d")

const SCREENS := {
	"menu": "res://scenes/main_menu.tscn",
	"levels": "res://scenes/level_select.tscn",
	"shop": "res://scenes/shop.tscn",
	"tech": "res://scenes/tech.tscn",
	"settings": "res://scenes/settings.tscn",
	"game": "res://scenes/game.tscn",
	"multi": "res://scenes/multiplayer.tscn",
	"missions": "res://scenes/missions.tscn",
	"editor": "res://scenes/map_editor.tscn",
}

var font_title: FontVariation
var font_body: FontFile
var font_bold: FontFile
var theme: Theme

## Niveau à lancer quand on ouvre l'écran de jeu.
var current_level := 1
## true = mode Survie (vagues infinies) sur la map choisie.
var survival := false
## Carte de l'éditeur à jouer (MapData) ; null = campagne.
var custom_map: MapData = null
## Carte ouverte dans l'éditeur (pour y revenir après un test).
var editor_map: MapData = null
## Session de l'éditeur gardée pendant un test (historique, outils, caméra).
var editor_session: Variant = null
## Partie lancée depuis l'éditeur (outils de test disponibles).
var testing := false

var _fade: ColorRect
var _toast_layer: CanvasLayer


func _ready() -> void:
	_load_fonts()
	theme = _build_theme()
	get_tree().root.theme = theme
	RenderingServer.set_default_clear_color(BG)

	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = BG
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	layer.add_child(_fade)
	_toast_layer = layer


# --- Navigation -------------------------------------------------------------------

func goto(screen: String) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.18)
	await tw.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(SCREENS[screen])
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "modulate:a", 0.0, 0.25)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func play_level(id: int, survival_mode := false) -> void:
	current_level = id
	survival = survival_mode
	custom_map = null
	goto("game")


func play_custom(m: MapData) -> void:
	custom_map = m
	survival = false
	goto("game")


func toast(text: String, color := CYAN) -> void:
	var p := PanelContainer.new()
	p.theme = theme
	p.add_theme_stylebox_override("panel", box(Color(PANEL, 0.95), color, 2, 6))
	var l := label(text, 24, TEXT)
	p.add_child(l)
	_toast_layer.add_child(p)
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	p.position = Vector2((vp.x - p.size.x) / 2, vp.y - p.size.y - 140)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## Marges à laisser pour l'encoche et les bords arrondis des téléphones (en unités du jeu).
## Renvoie [gauche, haut, droite, bas].
func safe_margins() -> Array[float]:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or not OS.has_feature("mobile"):
		return [0.0, 0.0, 0.0, 0.0]
	var vp := get_viewport().get_visible_rect().size
	var k := vp.x / float(win.x)
	return [maxf(0.0, safe.position.x * k), maxf(0.0, safe.position.y * k),
			maxf(0.0, (win.x - safe.end.x) * k), maxf(0.0, (win.y - safe.end.y) * k)]


# --- Composants ---------------------------------------------------------------------

func box(bg: Color, border := CYAN_DIM, border_w := 2, radius := 8, skew := 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.corner_detail = 4
	s.skew = Vector2(skew, 0)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


func label(text: String, size := 22, color := TEXT, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold)
	return l


func title(text: String, size := 40, color := TEXT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", font_title)
	l.add_theme_constant_override("outline_size", 0)
	return l


func button(text: String, primary := false, min_size := Vector2(240, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	if primary:
		b.theme_type_variation = "PrimaryButton"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func() -> void: Sfx.play("click", -6.0))
	return b


func panel(min_size := Vector2.ZERO, glow := false) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	if glow:
		p.theme_type_variation = "GlowPanel"
	return p


func vbox(sep := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func hbox(sep := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func spacer(min_size := Vector2(0, 0), expand := true) -> Control:
	var c := Control.new()
	c.custom_minimum_size = min_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE # un espace vide ne doit jamais bloquer les touchers
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Pastille de monnaie : « ◆ 120 ».
func currency_chip(kind: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(Color(PANEL, 0.85), Color(GOLD if kind == "gold" else CYAN, 0.6), 2, 20))
	var h := hbox(8)
	var icon := CurrencyIcon.new()
	icon.kind = kind
	h.add_child(icon)
	var l := label("", 24, TEXT, true)
	l.name = "Value"
	h.add_child(l)
	p.add_child(h)
	var refresh := func() -> void: l.text = str(Save.gold() if kind == "gold" else Save.credits())
	refresh.call()
	Save.changed.connect(refresh)
	p.tree_exiting.connect(func() -> void: Save.changed.disconnect(refresh))
	return p


## En-tête commun aux écrans secondaires : bouton retour, titre, monnaies.
func header(title_text: String, back_to := "menu") -> HBoxContainer:
	var h := hbox(18)
	var back := button("‹  RETOUR", false, Vector2(190, 58))
	back.pressed.connect(func() -> void: goto(back_to))
	h.add_child(back)
	var t := title(title_text, 34)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(t)
	h.add_child(currency_chip("credits"))
	h.add_child(currency_chip("gold"))
	return h


## Structure standard d'un écran : fond animé + marges + colonne.
func screen_root(owner_node: Control) -> VBoxContainer:
	owner_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := MenuBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner_node.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := safe_margins()
	m.add_theme_constant_override("margin_left", 32 + int(sm[0]))
	m.add_theme_constant_override("margin_top", 24 + int(sm[1]))
	m.add_theme_constant_override("margin_right", 32 + int(sm[2]))
	m.add_theme_constant_override("margin_bottom", 32 + int(sm[3]))
	owner_node.add_child(m)
	var v := vbox(20)
	m.add_child(v)
	return v


# --- Thème ------------------------------------------------------------------------

func _load_fonts() -> void:
	var exo: FontFile = load("res://assets/fonts/Exo2.ttf")
	font_body = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	font_bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	font_body.fallbacks = [exo]
	font_bold.fallbacks = [exo]
	var orbitron: FontFile = load("res://assets/fonts/Orbitron.ttf")
	orbitron.fallbacks = [exo]
	font_title = FontVariation.new()
	font_title.base_font = orbitron
	font_title.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	font_title.spacing_glyph = 2


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_body
	t.default_font_size = 22

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))

	# Panneaux
	var pnl := box(Color(PANEL, 0.92), Color(CYAN, 0.35), 2, 10)
	pnl.content_margin_left = 22
	pnl.content_margin_right = 22
	pnl.content_margin_top = 18
	pnl.content_margin_bottom = 18
	t.set_stylebox("panel", "PanelContainer", pnl)
	t.set_stylebox("panel", "Panel", pnl)
	var glow := pnl.duplicate() as StyleBoxFlat
	glow.border_color = CYAN
	glow.shadow_color = Color(CYAN, 0.25)
	glow.shadow_size = 18
	t.set_type_variation("GlowPanel", "PanelContainer")
	t.set_stylebox("panel", "GlowPanel", glow)

	# Boutons : biseautés, bordure néon
	t.set_font("font", "Button", font_title)
	t.set_font_size("font_size", "Button", 20)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.7))
	t.set_stylebox("normal", "Button", box(Color(PANEL_LIGHT, 0.95), Color(CYAN, 0.45), 2, 4, 0.18))
	t.set_stylebox("hover", "Button", box(Color("1a2d4f"), CYAN, 2, 4, 0.18))
	t.set_stylebox("pressed", "Button", box(Color(CYAN_DIM, 0.9), CYAN, 2, 4, 0.18))
	t.set_stylebox("hover_pressed", "Button", box(Color(CYAN_DIM, 0.9), CYAN, 2, 4, 0.18))
	t.set_stylebox("disabled", "Button", box(Color(PANEL, 0.7), Color(MUTED, 0.3), 2, 4, 0.18))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	t.set_type_variation("PrimaryButton", "Button")
	t.set_color("font_color", "PrimaryButton", BG)
	t.set_color("font_hover_color", "PrimaryButton", BG)
	t.set_color("font_pressed_color", "PrimaryButton", BG)
	t.set_stylebox("normal", "PrimaryButton", box(CYAN, Color("a5f3fc"), 2, 4, 0.18))
	t.set_stylebox("hover", "PrimaryButton", box(Color("67e8f9"), Color.WHITE, 2, 4, 0.18))
	t.set_stylebox("pressed", "PrimaryButton", box(Color("0891b2"), Color.WHITE, 2, 4, 0.18))

	t.set_type_variation("GoldButton", "Button")
	t.set_color("font_color", "GoldButton", BG)
	t.set_color("font_hover_color", "GoldButton", BG)
	t.set_stylebox("normal", "GoldButton", box(GOLD, Color("fde68a"), 2, 4, 0.18))
	t.set_stylebox("hover", "GoldButton", box(Color("fcd34d"), Color.WHITE, 2, 4, 0.18))
	t.set_stylebox("pressed", "GoldButton", box(Color("d97706"), Color.WHITE, 2, 4, 0.18))

	# Curseurs et cases à cocher
	var track := box(Color(PANEL_LIGHT), Color(CYAN, 0.3), 1, 4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(CYAN, CYAN, 0, 4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _circle_texture(14, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", _circle_texture(16, CYAN))
	t.set_icon("checked", "CheckButton", _toggle_texture(true))
	t.set_icon("unchecked", "CheckButton", _toggle_texture(false))
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())

	# Barres de progression
	t.set_stylebox("background", "ProgressBar", box(Color(PANEL_LIGHT), Color(CYAN, 0.25), 1, 4))
	t.set_stylebox("fill", "ProgressBar", box(CYAN, CYAN, 0, 4))
	t.set_constant("outline_size", "ProgressBar", 0)

	t.set_stylebox("panel", "TooltipPanel", box(PANEL, CYAN, 1, 6))
	t.set_stylebox("normal", "LineEdit", box(Color(PANEL_LIGHT), Color(CYAN, 0.4), 2, 6))
	t.set_stylebox("focus", "LineEdit", box(Color(PANEL_LIGHT), CYAN, 2, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", CYAN)
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	return t


func _circle_texture(radius: int, color: Color) -> ImageTexture:
	var img := Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	for y in radius * 2:
		for x in radius * 2:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(radius, radius))
			img.set_pixel(x, y, Color(color, clampf(radius - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _toggle_texture(on: bool) -> ImageTexture:
	var w := 64
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := CYAN_DIM if on else Color(PANEL_LIGHT)
	var knob_x := w - h / 2.0 if on else h / 2.0
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, h / 2.0, w - h / 2.0)
			var in_track := p.distance_to(Vector2(cx, h / 2.0)) <= h / 2.0
			var in_knob := p.distance_to(Vector2(knob_x, h / 2.0)) <= h / 2.0 - 4
			var c := Color(0, 0, 0, 0)
			if in_track:
				c = track
			if in_knob:
				c = CYAN if on else MUTED
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
