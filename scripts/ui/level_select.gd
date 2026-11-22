extends Control
## Campagne : choix de la map.


func _ready() -> void:
	var root := Ui.screen_root(self)
	root.add_child(Ui.header("CAMPAGNE"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(scroll)
	var cards := Ui.hbox(20)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards)
	var i := 0
	for l in Content.LEVELS:
		var card := _level_card(l)
		cards.add_child(card)
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(card, "modulate:a", 1.0, 0.3)
		i += 1

	if Content.DEV_TOOLS:
		for path in MapData.list_custom():
			cards.add_child(_custom_card(MapData.load_from(path)))

	var aug := Ui.hbox(12)
	aug.alignment = BoxContainer.ALIGNMENT_CENTER
	var stock: Array[String] = []
	for a in Content.AUGMENTS:
		var n := Save.augment_count(a.id)
		if n > 0:
			stock.append("%s ×%d" % [a.name, n])
	var txt := "Augments prêts pour la prochaine partie : " + ", ".join(stock) if not stock.is_empty() \
			else "Aucun augment en stock — passe à la boutique pour t'équiper"
	aug.add_child(Ui.label(txt, 20, Ui.GREEN if not stock.is_empty() else Ui.MUTED))
	root.add_child(aug)


func _level_card(l: Dictionary) -> PanelContainer:
	var map := MapData.load_from(l.map)
	var unlocked := Save.is_level_unlocked(l.id) or Content.DEV_TOOLS # outils de dev : tout est ouvert
	var stars := Save.level_stars(l.id)
	var card := Ui.panel(Vector2(330, 0), unlocked and stars == 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := Ui.vbox(10)
	card.add_child(v)

	var top := Ui.hbox(8)
	top.add_child(Ui.label("SECTEUR %02d" % l.id, 18, Ui.CYAN, true))
	top.add_child(Ui.spacer())
	top.add_child(Ui.label("%d VAGUES" % l.waves, 18, Ui.MUTED, true))
	v.add_child(top)
	v.add_child(Ui.title(map.NAME.to_upper(), 21))

	var preview := MapPreview.new()
	preview.grid = MapLoader.from_layout(map.LAYOUT)
	preview.ground = map.GROUND
	preview.locked = not unlocked
	preview.custom_minimum_size = Vector2(286, 170)
	v.add_child(preview)

	var srow := Ui.hbox(8)
	for i in 3:
		var s := StarIcon.new()
		s.custom_minimum_size = Vector2(34, 34)
		s.filled = i < stars
		srow.add_child(s)
	srow.add_child(Ui.spacer())
	srow.add_child(Ui.label("%d apparitions" % preview.grid.spawn_points.size(), 18, Ui.RED))
	v.add_child(srow)

	if unlocked:
		var buttons := Ui.hbox(10)
		var play := Ui.button("JOUER" if stars == 0 else "REJOUER", stars == 0, Vector2(0, 62))
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		play.pressed.connect(func() -> void: Ui.play_level(l.id))
		buttons.add_child(play)
		if stars > 0:
			var surv := Ui.button("SURVIE", false, Vector2(140, 62))
			surv.add_theme_color_override("font_color", Ui.MAGENTA)
			surv.pressed.connect(func() -> void: Ui.play_level(l.id, true))
			buttons.add_child(surv)
		v.add_child(buttons)
		var rec := Save.survival_record(l.id)
		if stars > 0:
			v.add_child(Ui.label("Survie : record vague %d" % rec if rec > 0 else "Survie débloquée : vagues infinies", 18, Ui.MAGENTA))
	else:
		var lock := Ui.button("VERROUILLÉ", false, Vector2(0, 62))
		lock.disabled = true
		v.add_child(lock)
		v.add_child(Ui.label("Termine le secteur %02d pour débloquer" % (l.id - 1), 18, Ui.MUTED))
	return card


## Carte de l'éditeur (outil de développement).
func _custom_card(md: MapData) -> PanelContainer:
	var card := Ui.panel(Vector2(330, 0))
	card.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.92), Color(Ui.GOLD, 0.6), 2, 10))
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := Ui.vbox(10)
	card.add_child(v)
	var top := Ui.hbox(8)
	top.add_child(Ui.label("CARTE PERSO", 18, Ui.GOLD, true))
	top.add_child(Ui.spacer())
	top.add_child(Ui.label("%d VAGUES" % md.waves, 18, Ui.MUTED, true))
	v.add_child(top)
	v.add_child(Ui.title(md.NAME.to_upper(), 21))
	var preview := MapPreview.new()
	preview.grid = MapLoader.from_layout(md.LAYOUT)
	preview.ground = md.GROUND
	preview.custom_minimum_size = Vector2(286, 170)
	v.add_child(preview)
	var row := Ui.hbox(10)
	var play := Ui.button("JOUER", true, Vector2(0, 62))
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(func() -> void: Ui.play_custom(md))
	row.add_child(play)
	var edit := Ui.button("ÉDITER", false, Vector2(130, 62))
	edit.pressed.connect(func() -> void:
		Ui.editor_map = md
		Ui.goto("editor"))
	row.add_child(edit)
	v.add_child(row)
	return card
