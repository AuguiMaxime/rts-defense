extends Control
## Paramètres.

var _reset_armed := false


func _ready() -> void:
	var root := Ui.screen_root(self)
	root.add_child(Ui.header("PARAMÈTRES"))

	var row := Ui.hbox(24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(row)

	var left := Ui.panel()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var lv := Ui.vbox(18)
	lv.add_child(Ui.title("SON ET AFFICHAGE", 20, Ui.CYAN))
	lv.add_child(SettingsForm.create(false))
	var lang := Ui.hbox(16)
	var ll := Ui.label("Langue", 24)
	ll.custom_minimum_size.x = 200
	lang.add_child(ll)
	lang.add_child(Ui.label("Français", 24, Ui.CYAN, true))
	lv.add_child(lang)
	left.add_child(lv)
	row.add_child(left)

	var right := Ui.panel(Vector2(440, 0))
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var rv := Ui.vbox(14)
	rv.add_child(Ui.title("PROGRESSION", 20, Ui.CYAN))
	var done := 0
	for l in Content.LEVELS:
		done += Save.level_stars(l.id)
	rv.add_child(Ui.label("Étoiles : %d / %d" % [done, Content.LEVELS.size() * 3], 22))
	var reset := Ui.button("RÉINITIALISER LA PROGRESSION", false, Vector2(0, 58))
	reset.add_theme_font_size_override("font_size", 15)
	reset.pressed.connect(func() -> void:
		if not _reset_armed:
			_reset_armed = true
			reset.text = "CONFIRMER : TOUT EFFACER ?"
			reset.add_theme_color_override("font_color", Ui.RED)
		else:
			Save.reset()
			Ui.toast("Progression réinitialisée", Ui.RED)
			Ui.goto("menu"))
	rv.add_child(reset)
	rv.add_child(Ui.spacer(Vector2(0, 8), false))
	rv.add_child(Ui.title("CRÉDITS", 20, Ui.CYAN))
	var cr := Ui.label("Graphismes : Kenney.nl (CC0)\nPolices : Orbitron, Rajdhani, Exo 2 (OFL)\nMoteur : Godot Engine", 20, Ui.MUTED)
	rv.add_child(cr)
	right.add_child(rv)
	row.add_child(right)
