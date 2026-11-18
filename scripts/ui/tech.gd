extends Control
## Arbre de technologies : améliorations permanentes payées en crédits.

var _grid: GridContainer


func _ready() -> void:
	var root := Ui.screen_root(self)
	root.add_child(Ui.header("TECHNOLOGIES"))
	root.add_child(Ui.label("Améliorations permanentes, payées avec les crédits gagnés en mission.", 20, Ui.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(_grid)
	_rebuild()


func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for t in Content.TECH:
		_grid.add_child(_card(t))


func _card(t: Dictionary) -> PanelContainer:
	var lvl := Save.tech_level(t.id)
	var max_lvl: int = t.costs.size()
	var maxed := lvl >= max_lvl
	var card := Ui.panel(Vector2(0, 210))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if maxed:
		card.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.92), Color(Ui.GREEN, 0.6), 2, 10))
	var v := Ui.vbox(8)
	card.add_child(v)
	v.add_child(Ui.title(t.name.to_upper(), 19, Ui.GREEN if maxed else Ui.TEXT))
	var d := Ui.label(t.desc, 20, Ui.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 300
	v.add_child(d)

	var pips := Ui.hbox(6)
	for i in max_lvl:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(46, 10)
		pip.color = Ui.CYAN if i < lvl else Color(Ui.PANEL_LIGHT)
		pips.add_child(pip)
	pips.add_child(Ui.spacer())
	pips.add_child(Ui.label("NIV. %d/%d" % [lvl, max_lvl], 18, Ui.CYAN, true))
	v.add_child(pips)
	v.add_child(Ui.spacer(Vector2(0, 4)))

	if maxed:
		var b := Ui.button("MAXIMUM", false, Vector2(0, 54))
		b.disabled = true
		v.add_child(b)
	else:
		var cost: int = t.costs[lvl]
		var b := Ui.button("AMÉLIORER  ◆ %d" % cost, Save.credits() >= cost, Vector2(0, 54))
		b.pressed.connect(func() -> void:
			if Save.spend("credits", cost):
				Save.set_tech_level(t.id, lvl + 1)
				Ui.toast("%s : niveau %d" % [t.name, lvl + 1], Ui.GREEN)
				_rebuild()
			else:
				Ui.toast("Pas assez de crédits — joue une mission pour en gagner", Ui.RED))
		v.add_child(b)
	return card
