extends Control
## Écran titre.

var _emblem: Control


func _ready() -> void:
	var root := Ui.screen_root(self)

	var top := Ui.hbox(14)
	top.add_child(Ui.spacer())
	top.add_child(Ui.currency_chip("credits"))
	top.add_child(Ui.currency_chip("gold"))
	root.add_child(top)

	var body := Ui.hbox(40)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	# Colonne gauche : titre + boutons
	var left := Ui.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(left)

	var tag := Ui.label("// SECTEUR 7 — DÉFENSE AUTONOME", 20, Ui.CYAN, true)
	left.add_child(tag)
	var t1 := Ui.title("RTS", 76, Ui.TEXT)
	var t2 := Ui.title("DEFENSE", 76, Ui.CYAN)
	left.add_child(t1)
	left.add_child(t2)
	var line := ColorRect.new()
	line.color = Ui.MAGENTA
	line.custom_minimum_size = Vector2(320, 4)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(line)
	left.add_child(Ui.label("Récolte. Construis. Tiens la ligne.", 24, Ui.MUTED))
	left.add_child(Ui.spacer(Vector2(0, 16), false))

	var play := Ui.button("JOUER", true, Vector2(300, 76))
	play.add_theme_font_size_override("font_size", 28)
	play.pressed.connect(func() -> void: Ui.goto("levels"))
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var play_row := Ui.hbox(14)
	play_row.add_child(play)
	var coop := Ui.button("COOP", false, Vector2(180, 76))
	coop.add_theme_font_size_override("font_size", 24)
	coop.add_theme_color_override("font_color", Ui.MAGENTA)
	coop.pressed.connect(func() -> void: Ui.goto("multi"))
	play_row.add_child(coop)
	left.add_child(play_row)
	var row := Ui.hbox(14)
	var tech := Ui.button("TECHNOLOGIES", false, Vector2(240, 60))
	tech.pressed.connect(func() -> void: Ui.goto("tech"))
	var shop := Ui.button("BOUTIQUE", false, Vector2(200, 60))
	shop.pressed.connect(func() -> void: Ui.goto("shop"))
	row.add_child(tech)
	row.add_child(shop)
	left.add_child(row)
	var row2 := Ui.hbox(14)
	var settings := Ui.button("PARAMÈTRES", false, Vector2(240, 60))
	settings.pressed.connect(func() -> void: Ui.goto("settings"))
	row2.add_child(settings)
	if not OS.has_feature("mobile"):
		var quit := Ui.button("QUITTER", false, Vector2(200, 60))
		quit.pressed.connect(func() -> void: get_tree().quit())
		row2.add_child(quit)
	left.add_child(row2)

	# Colonne droite : emblème animé
	_emblem = MenuEmblem.new()
	_emblem.custom_minimum_size = Vector2(460, 460)
	_emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(_emblem)

	var version := Ui.label("v0.6 · prototype", 16, Ui.MUTED)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(version)

	# Petite animation d'entrée
	left.modulate.a = 0.0
	left.position.x -= 40
	var tw := create_tween().set_parallel()
	tw.tween_property(left, "modulate:a", 1.0, 0.5)
	tw.tween_property(left, "position:x", left.position.x + 40, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
