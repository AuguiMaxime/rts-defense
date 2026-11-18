class_name SettingsForm
extends RefCounted
## Réglages partagés entre l'écran Paramètres et le menu pause.


static func create(compact := false) -> VBoxContainer:
	var v := Ui.vbox(10 if compact else 18)
	v.add_child(_slider("Musique", "music"))
	v.add_child(_slider("Effets sonores", "sfx"))
	v.add_child(_toggle("Vibrations", "vibration"))
	if not compact:
		v.add_child(_toggle("Afficher les FPS", "show_fps"))
	return v


static func _row(text: String) -> HBoxContainer:
	var h := Ui.hbox(16)
	var l := Ui.label(text, 24, Ui.TEXT)
	l.custom_minimum_size.x = 200
	h.add_child(l)
	return h


static func _slider(text: String, key: String) -> HBoxContainer:
	var h := _row(text)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Save.setting(key)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(220, 32)
	var pct := Ui.label("%d %%" % roundi(s.value * 100), 22, Ui.CYAN, true)
	pct.custom_minimum_size.x = 64
	s.value_changed.connect(func(val: float) -> void:
		pct.text = "%d %%" % roundi(val * 100)
		Save.set_setting(key, val))
	h.add_child(s)
	h.add_child(pct)
	return h


static func _toggle(text: String, key: String) -> HBoxContainer:
	var h := _row(text)
	h.add_child(Ui.spacer())
	var t := CheckButton.new()
	t.button_pressed = Save.setting(key)
	t.focus_mode = Control.FOCUS_NONE
	t.toggled.connect(func(on: bool) -> void: Save.set_setting(key, on))
	h.add_child(t)
	return h
