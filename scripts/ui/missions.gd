extends Control
## Missions du jour et bonus de connexion.

var _list: VBoxContainer


func _ready() -> void:
	var root := Ui.screen_root(self)
	root.add_child(Ui.header("MISSIONS DU JOUR"))
	root.add_child(Ui.label("Trois défis renouvelés chaque jour. La progression compte à la fin de chaque partie.", 20, Ui.MUTED))
	_list = Ui.vbox(14)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_list)
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(_login_card())
	var missions := Save.daily_missions()
	for i in missions.size():
		_list.add_child(_mission_card(i, missions[i]))
	var t := Time.get_time_dict_from_system()
	var left_h := 23 - int(t.hour)
	var left_m := 59 - int(t.minute)
	var renew := Ui.label("Nouvelles missions dans %d h %02d" % [left_h, left_m], 18, Ui.MUTED)
	renew.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_list.add_child(renew)


func _row_panel(accent: Color) -> Array:
	var p := Ui.panel()
	p.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.92), Color(accent, 0.5), 2, 10, 0.06))
	var h := Ui.hbox(18)
	p.add_child(h)
	return [p, h]


func _login_card() -> PanelContainer:
	var parts := _row_panel(Ui.GOLD)
	var h: HBoxContainer = parts[1]
	var ic := CurrencyIcon.new()
	ic.kind = "gold"
	ic.custom_minimum_size = Vector2(44, 44)
	h.add_child(ic)
	var v := Ui.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Ui.title("BONUS DE CONNEXION", 18, Ui.GOLD))
	v.add_child(Ui.label("Reviens chaque jour pour gagner de l'or.", 19, Ui.MUTED))
	h.add_child(v)
	var done: bool = Save.data.daily.get("login", false)
	var b := Ui.button("REÇU" if done else "+%d OR" % Content.DAILY_LOGIN_GOLD, false, Vector2(190, 58))
	if done:
		b.disabled = true
	else:
		b.theme_type_variation = "GoldButton"
		b.pressed.connect(func() -> void:
			if Save.claim_login():
				Sfx.play("built", -2.0)
				Ui.toast("+%d or" % Content.DAILY_LOGIN_GOLD, Ui.GOLD)
				_rebuild())
	h.add_child(b)
	return parts[0]


func _mission_card(i: int, m: Dictionary) -> PanelContainer:
	var def := Save.mission_def(m.id)
	var goal: int = def.goal
	var progress: int = mini(int(m.progress), goal)
	var done := progress >= goal
	var parts := _row_panel(Ui.GREEN if done and not m.claimed else Ui.CYAN)
	var h: HBoxContainer = parts[1]
	var v := Ui.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Ui.title((def.text % goal).to_upper(), 18, Ui.MUTED if m.claimed else Ui.TEXT))
	var bar_row := Ui.hbox(12)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = goal
	bar.value = progress
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if done:
		bar.add_theme_stylebox_override("fill", Ui.box(Ui.GREEN, Ui.GREEN, 0, 4))
	bar_row.add_child(bar)
	bar_row.add_child(Ui.label("%d / %d" % [progress, goal], 20, Ui.TEXT, true))
	v.add_child(bar_row)
	h.add_child(v)
	var label := "RÉCUPÉRÉ" if m.claimed else "◆ %d" % def.reward
	var b := Ui.button(label, done and not m.claimed, Vector2(190, 58))
	if m.claimed or not done:
		b.disabled = true
	b.pressed.connect(func() -> void:
		var r := Save.claim_mission(i)
		if r > 0:
			Sfx.play("built", -2.0)
			Ui.toast("+%d crédits" % r, Ui.CYAN)
			_rebuild())
	h.add_child(b)
	return parts[0]
