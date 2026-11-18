class_name GameHud
extends Control
## Interface en jeu : ressources, vague, base, construction, pause, fin de partie.

var game: Node # scripts/game.gd

var _metal: Label
var _essence: Label
var _pop: Label
var _info: Label
var _wave_title: Label
var _wave_bar: ProgressBar
var _wave_detail: Label
var _next_btn: Button
var _base_bar: ProgressBar
var _base_label: Label
var _speed_btn: Button
var _selection_panel: PanelContainer
var _selection_label: Label
var _site_panel: PanelContainer
var _site_title: Label
var _site_stats: Label
var _site_hp: ProgressBar
var _upgrade_btn: Button
var _repair_btn: Button
var _sell_btn: Button
var _build_cards := {} # kind -> Button
var _orbital_label: Label
var _worker_label: Label
var _fps: Label
var _boss_panel: PanelContainer
var _boss_bar: ProgressBar
var _pause_layer: Control
var _pause_sub: Label
var _end_layer: Control
var _blocks: Array[Control] = [] # zones qui bloquent les gestes sur la map
var _flash_time := 0.0
var _column: VBoxContainer


func setup(g: Node) -> void:
	game = g
	theme = Ui.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column = Ui.vbox(8)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(_column)
	_build_top_bar()
	_info = Ui.label("", 20, Ui.MUTED)
	_info.add_theme_constant_override("outline_size", 6)
	_column.add_child(_info)
	_build_boss_bar()
	var gap := Ui.spacer()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(gap)
	_build_bottom_bar()
	_build_pause()
	_fps = Ui.label("", 16, Ui.MUTED)
	_fps.position = Vector2(12, 0)
	_fps.visible = Save.setting("show_fps")
	add_child(_fps)
	refresh_build_buttons()


func is_over_ui(p: Vector2) -> bool:
	if _pause_layer.visible or (_end_layer != null and _end_layer.visible):
		return true
	for b in _blocks:
		if b.is_visible_in_tree() and b.get_global_rect().has_point(p):
			return true
	return false


# --- Construction de l'interface --------------------------------------------------------

func _chip(kind: String) -> Label:
	var h := Ui.hbox(6)
	var icon := CurrencyIcon.new()
	icon.kind = kind
	h.add_child(icon)
	var l := Ui.label("0", 24, Ui.TEXT, true)
	l.custom_minimum_size.x = 54
	h.add_child(l)
	return l


func _build_top_bar() -> void:
	var row := Ui.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(row)

	# Ressources
	var res := Ui.panel()
	res.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.88), Color(Ui.CYAN, 0.35), 2, 8, 0.12))
	var rh := Ui.hbox(14)
	_metal = _chip("metal")
	_essence = _chip("essence")
	_pop = _chip("pop")
	rh.add_child(_metal.get_parent())
	rh.add_child(_essence.get_parent())
	rh.add_child(_pop.get_parent())
	res.add_child(rh)
	res.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(res)
	_blocks.append(res)

	row.add_child(Ui.spacer())

	# Vague
	var wave := Ui.panel(Vector2(310, 0))
	wave.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.88), Color(Ui.RED, 0.45), 2, 8, 0.12))
	var wv := Ui.vbox(4)
	var wt := Ui.hbox(10)
	var wicon := CurrencyIcon.new()
	wicon.kind = "wave"
	wt.add_child(wicon)
	_wave_title = Ui.title("VAGUE 0/10", 20)
	_wave_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wt.add_child(_wave_title)
	_next_btn = Ui.button("▶▶", false, Vector2(64, 36))
	_next_btn.add_theme_font_size_override("font_size", 16)
	_next_btn.tooltip_text = "Lancer la vague suivante"
	_next_btn.pressed.connect(func() -> void: game.world.waves.start_next())
	wt.add_child(_next_btn)
	wv.add_child(wt)
	_wave_bar = ProgressBar.new()
	_wave_bar.show_percentage = false
	_wave_bar.custom_minimum_size = Vector2(0, 10)
	_wave_bar.add_theme_stylebox_override("fill", Ui.box(Ui.RED, Ui.RED, 0, 4))
	wv.add_child(_wave_bar)
	_wave_detail = Ui.label("", 18, Ui.MUTED)
	wv.add_child(_wave_detail)
	wave.add_child(wv)
	wave.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(wave)
	_blocks.append(wave)

	row.add_child(Ui.spacer())

	# Base + pause + vitesse
	var base := Ui.panel(Vector2(210, 0))
	base.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.88), Color(Ui.CYAN, 0.35), 2, 8, 0.12))
	var bv := Ui.vbox(6)
	var bt := Ui.hbox(8)
	var bicon := CurrencyIcon.new()
	bicon.kind = "base"
	bt.add_child(bicon)
	bt.add_child(Ui.title("BASE", 18))
	_base_label = Ui.label("", 20, Ui.TEXT, true)
	_base_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bt.add_child(_base_label)
	bv.add_child(bt)
	_base_bar = ProgressBar.new()
	_base_bar.show_percentage = false
	_base_bar.custom_minimum_size = Vector2(0, 12)
	bv.add_child(_base_bar)
	base.add_child(bv)
	base.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(base)
	_blocks.append(base)

	_speed_btn = Ui.button("x1", false, Vector2(68, 68))
	_speed_btn.pressed.connect(func() -> void:
		game.toggle_speed()
		_speed_btn.text = "x%d" % game.speed)
	_speed_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_speed_btn)
	_blocks.append(_speed_btn)
	var pause := Ui.button("II", true, Vector2(68, 68))
	pause.pressed.connect(open_pause)
	pause.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pause)
	_blocks.append(pause)


func _build_boss_bar() -> void:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel = Ui.panel(Vector2(520, 0))
	_boss_panel.add_theme_stylebox_override("panel", Ui.box(Color(0.15, 0.03, 0.06, 0.9), Ui.RED, 2, 6, 0.12))
	_boss_panel.visible = false
	var v := Ui.vbox(4)
	var t := Ui.title("☠  CUIRASSÉ — BOSS", 18, Ui.RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(0, 14)
	_boss_bar.add_theme_stylebox_override("fill", Ui.box(Ui.RED, Ui.RED, 0, 3))
	v.add_child(_boss_bar)
	_boss_panel.add_child(v)
	c.add_child(_boss_panel)
	_column.add_child(c)


func _build_bottom_bar() -> void:
	var row := Ui.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	_column.add_child(row)

	_selection_panel = Ui.panel()
	_selection_panel.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.9), Color(Ui.GREEN, 0.6), 2, 8, 0.12))
	var sv := Ui.vbox(6)
	_selection_label = Ui.title("", 18, Ui.GREEN)
	sv.add_child(_selection_label)
	sv.add_child(Ui.label("Touche un gisement, un chantier,\nune tourelle abîmée ou le sol", 18, Ui.MUTED))
	var des := Ui.button("DÉSÉLECTIONNER", false, Vector2(0, 44))
	des.add_theme_font_size_override("font_size", 15)
	des.pressed.connect(func() -> void: game.deselect())
	sv.add_child(des)
	_selection_panel.add_child(sv)
	_selection_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_selection_panel)
	_blocks.append(_selection_panel)
	_build_site_panel(row)

	row.add_child(Ui.spacer())

	var bar := Ui.panel()
	bar.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.9), Color(Ui.CYAN, 0.35), 2, 10, 0.0))
	var cards := Ui.hbox(8)
	bar.add_child(cards)
	row.add_child(bar)
	_blocks.append(bar)

	var worker := _card(Sprites.WORKER, "OUVRIER", Balance.WORKER_COST_METAL, 0)
	_worker_label = worker.get_node("V/Name")
	worker.pressed.connect(func() -> void: game.train_worker())
	cards.add_child(worker)
	var sep := ColorRect.new()
	sep.color = Color(Ui.CYAN, 0.25)
	sep.custom_minimum_size = Vector2(2, 0)
	cards.add_child(sep)
	for kind in Content.TOWER_ORDER:
		if kind == "laser" and not game.world.laser_unlocked:
			continue
		var t: Dictionary = Content.TOWERS[kind]
		var card := _card(Sprites.TOWER_LOOK[kind].turret, t.name.to_upper(), t.metal, t.essence)
		(card.get_node("V").get_child(0) as TextureRect).modulate = Sprites.TOWER_LOOK[kind].tint
		card.pressed.connect(func() -> void: game.set_build_kind("" if game.build_kind == kind else kind))
		_build_cards[kind] = card
		cards.add_child(card)
	var house := _card(null, "HABITAT", Content.HOUSE.metal, 0, "pop")
	house.pressed.connect(func() -> void: game.set_build_kind("" if game.build_kind == "house" else "house"))
	_build_cards["house"] = house
	cards.add_child(house)
	if game.world.orbital_unlocked():
		var orb := _card(null, "ORBITALE", 0, 0, "orbital")
		_orbital_label = orb.get_node("V/Cost")
		orb.pressed.connect(func() -> void:
			if game.world.orbital_ready():
				game.set_build_kind("" if game.build_kind == "orbital" else "orbital")
			else:
				flash("Frappe orbitale en recharge", Ui.RED))
		_build_cards["orbital"] = orb
		cards.add_child(orb)


func _build_site_panel(row: HBoxContainer) -> void:
	_site_panel = Ui.panel(Vector2(330, 0))
	_site_panel.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.94), Color(Ui.CYAN, 0.6), 2, 8, 0.0))
	_site_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	_site_panel.visible = false
	var v := Ui.vbox(6)
	var top := Ui.hbox(8)
	_site_title = Ui.title("", 17, Ui.CYAN)
	_site_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_site_title)
	var close := Ui.button("✕", false, Vector2(44, 36))
	close.add_theme_font_size_override("font_size", 14)
	close.pressed.connect(func() -> void: game.focus_site(null))
	top.add_child(close)
	v.add_child(top)
	_site_hp = ProgressBar.new()
	_site_hp.show_percentage = false
	_site_hp.custom_minimum_size = Vector2(0, 10)
	_site_hp.add_theme_stylebox_override("fill", Ui.box(Ui.GREEN, Ui.GREEN, 0, 4))
	v.add_child(_site_hp)
	_site_stats = Ui.label("", 18, Ui.MUTED)
	v.add_child(_site_stats)
	var btns := Ui.hbox(6)
	_upgrade_btn = Ui.button("", true, Vector2(0, 50))
	_upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_btn.add_theme_font_size_override("font_size", 13)
	_upgrade_btn.pressed.connect(func() -> void: game.upgrade_focused())
	btns.add_child(_upgrade_btn)
	_repair_btn = Ui.button("RÉPARER", false, Vector2(96, 50))
	_repair_btn.add_theme_font_size_override("font_size", 13)
	_repair_btn.pressed.connect(func() -> void: game.repair_focused())
	btns.add_child(_repair_btn)
	_sell_btn = Ui.button("", false, Vector2(96, 50))
	_sell_btn.add_theme_font_size_override("font_size", 13)
	_sell_btn.pressed.connect(func() -> void: game.sell_focused())
	btns.add_child(_sell_btn)
	v.add_child(btns)
	_site_panel.add_child(v)
	row.add_child(_site_panel)
	_blocks.append(_site_panel)


func _update_site_panel() -> void:
	var s: BuildSite = game.focused_site
	_site_panel.visible = s != null
	if s == null:
		return
	var st := s.stats()
	_site_title.text = "%s  ·  NIV. %d" % [st.name.to_upper(), s.level] if s.is_tower() else st.name.to_upper()
	_site_hp.max_value = s.max_hp
	_site_hp.value = s.hp
	if not s.built:
		_site_stats.text = "Chantier : %d %%" % roundi(s.progress() * 100)
	elif s.is_tower():
		var targets: String = {"both": "sol + air", "ground": "sol", "air": "air"}[st.targets]
		_site_stats.text = "%d/%d PV · %d dégâts · portée %.1f · %s" % [s.hp, s.max_hp, st.damage, st.range, targets]
	else:
		_site_stats.text = "%d/%d PV · +%d population" % [s.hp, s.max_hp, Content.HOUSE.pop]
	var can_up := s.built and s.is_tower() and s.level < BuildSite.MAX_LEVEL
	_upgrade_btn.visible = can_up
	if can_up:
		var cost := s.upgrade_cost()
		_upgrade_btn.text = "AMÉLIORER %dM%s" % [cost.metal, (" %dE" % cost.essence) if cost.essence > 0 else ""]
		var ok: bool = game.world.can_upgrade(s) == ""
		_upgrade_btn.modulate = Color(1, 1, 1) if ok else Color(1, 1, 1, 0.55)
	_repair_btn.visible = s.built and s.hp < s.max_hp
	var refund := s.sell_value()
	_sell_btn.text = "VENDRE +%d" % refund.metal


func _card(tex: Texture2D, title: String, metal: int, essence: int, icon_kind := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(104, 112)
	b.focus_mode = Control.FOCUS_NONE
	var v := Ui.vbox(2)
	v.name = "V"
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(0, 52)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(img)
	else:
		var ic := CurrencyIcon.new()
		ic.kind = icon_kind
		ic.custom_minimum_size = Vector2(44, 52)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
	var n := Ui.label(title, 14, Ui.TEXT, true)
	n.name = "Name"
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(n)
	var cost := Ui.label("", 16, Ui.METAL, true)
	cost.name = "Cost"
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts: Array[String] = []
	if metal > 0:
		parts.append("%d M" % metal)
	if essence > 0:
		parts.append("%d E" % essence)
	cost.text = "  ".join(parts)
	v.add_child(cost)
	b.add_child(v)
	return b


func _build_pause() -> void:
	_pause_layer = _overlay()
	var p := Ui.panel(Vector2(520, 0), true)
	var v := Ui.vbox(14)
	p.add_child(v)
	var t := Ui.title("PAUSE", 44, Ui.CYAN)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_pause_sub = Ui.label("", 20, Ui.MUTED)
	_pause_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_pause_sub)
	var resume := Ui.button("REPRENDRE", true, Vector2(0, 66))
	resume.pressed.connect(close_pause)
	v.add_child(resume)
	var restart := Ui.button("RECOMMENCER", false, Vector2(0, 58))
	restart.pressed.connect(func() -> void: game.restart())
	v.add_child(restart)
	v.add_child(SettingsForm.create(true))
	var quit := Ui.button("QUITTER LA PARTIE", false, Vector2(0, 58))
	quit.pressed.connect(func() -> void: Ui.goto("menu"))
	v.add_child(quit)
	_center(_pause_layer, p)


func _overlay() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.visible = false
	var dim := ColorRect.new()
	dim.color = Color(Ui.BG, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	add_child(layer)
	return layer


func _center(layer: Control, content: Control) -> void:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(content)
	layer.add_child(c)


func open_pause() -> void:
	if _end_layer != null and _end_layer.visible:
		return
	game.set_paused(true)
	var lvl: Dictionary = game.level
	if game.survival:
		_pause_sub.text = "%s · Survie · vague %d" % [game.map_script.NAME, game.world.waves.wave]
	else:
		_pause_sub.text = "%s · vague %d/%d" % [game.map_script.NAME, game.world.waves.wave, lvl.waves]
	_pause_layer.visible = true


func close_pause() -> void:
	_pause_layer.visible = false
	game.set_paused(false)


# --- Fin de partie ------------------------------------------------------------------

func show_end(won: bool) -> void:
	Sfx.play("victory" if won else "defeat", 0.0, 1.0)
	Sfx.vibrate(200)
	var credits: int = game.grant_rewards()
	if _end_layer != null:
		_end_layer.queue_free()
	_end_layer = _overlay()
	_end_layer.visible = true
	var p := Ui.panel(Vector2(620, 0), true)
	var v := Ui.vbox(14)
	p.add_child(v)
	var title_text := "VICTOIRE" if won else "DÉFAITE"
	if game.survival:
		title_text = "NOUVEAU RECORD" if game.new_record else "FIN DE LA SURVIE"
	var t := Ui.title(title_text, 50, Ui.CYAN if (won or game.new_record) else Ui.RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub_text: String = game.map_script.NAME
	if game.survival:
		sub_text += " · Survie · record : vague %d" % Save.survival_record(game.level.id)
	var sub := Ui.label(sub_text, 22, Ui.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var stars := Ui.hbox(18)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	var n: int = game.stars()
	for i in 3:
		var s := StarIcon.new()
		s.filled = i < n
		stars.add_child(s)
		s.scale = Vector2.ZERO
		s.pivot_offset = s.custom_minimum_size / 2
		var tw := s.create_tween()
		tw.tween_interval(0.25 + i * 0.2)
		tw.tween_property(s, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if won:
		v.add_child(stars)

	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 40)
	stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for pair in [["Vagues", "%d" % game.world.waves.wave], ["Ennemis détruits", "%d" % game.world.kills],
			["Base", "%d / %d PV" % [game.world.base_hp, game.world.max_base_hp]]]:
		stats.add_child(Ui.label(pair[0], 22, Ui.MUTED))
		stats.add_child(Ui.label(pair[1], 22, Ui.TEXT, true))
	v.add_child(stats)

	var reward := Ui.hbox(10)
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := CurrencyIcon.new()
	ic.kind = "credits"
	reward.add_child(ic)
	reward.add_child(Ui.label("+%d crédits" % credits, 28, Ui.CYAN, true))
	v.add_child(reward)

	var buttons := Ui.hbox(12)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var menu := Ui.button("MENU", false, Vector2(150, 62))
	menu.pressed.connect(func() -> void: Ui.goto("levels"))
	buttons.add_child(menu)
	var again := Ui.button("REJOUER", false, Vector2(170, 62))
	again.pressed.connect(func() -> void: game.restart())
	buttons.add_child(again)
	var next_id: int = game.next_level_id()
	if won and next_id > 0:
		var nxt := Ui.button("SUIVANT", true, Vector2(180, 62))
		nxt.pressed.connect(func() -> void: Ui.play_level(next_id))
		buttons.add_child(nxt)
	v.add_child(buttons)
	if won:
		var inf := Ui.button("CONTINUER EN MODE INFINI", false, Vector2(0, 54))
		inf.add_theme_font_size_override("font_size", 16)
		inf.pressed.connect(func() -> void:
			_end_layer.visible = false
			game.continue_infinite())
		v.add_child(inf)
	_center(_end_layer, p)
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.3)


# --- Mise à jour ----------------------------------------------------------------------

func show_info(text: String) -> void:
	_info.text = text
	_info.add_theme_color_override("font_color", Ui.MUTED)
	_flash_time = 4.0


func flash(text: String, color := Ui.CYAN) -> void:
	if color == Ui.RED and not text.begins_with("VAGUE"):
		Sfx.play("error", -6.0, 0.3)
	_info.text = text
	_info.add_theme_color_override("font_color", color)
	_flash_time = 2.5


func refresh_build_buttons() -> void:
	for kind in _build_cards:
		var b: Button = _build_cards[kind]
		b.theme_type_variation = "PrimaryButton" if game.build_kind == kind else ""
		var on: bool = game.build_kind == kind
		(b.get_node("V/Name") as Label).add_theme_color_override("font_color", Ui.BG if on else Ui.TEXT)
		(b.get_node("V/Cost") as Label).add_theme_color_override("font_color", Ui.BG if on else Ui.METAL)


func _process(delta: float) -> void:
	if game == null:
		return
	var w: GameWorld = game.world
	_metal.text = str(w.metal)
	_essence.text = str(w.essence)
	_pop.text = "%d/%d" % [w.workers.size() + w.train_queue, w.pop_cap]
	_pop.add_theme_color_override("font_color", Ui.RED if w.workers.size() + w.train_queue >= w.pop_cap else Ui.TEXT)

	var wv := w.waves
	_wave_title.text = "VAGUE %d/%s" % [wv.wave, "∞" if wv.infinite else str(wv.total)]
	_next_btn.visible = wv.has_more_waves()
	if wv.has_more_waves():
		var span := Balance.FIRST_WAVE_DELAY if wv.wave == 0 else Balance.WAVE_INTERVAL
		_wave_bar.max_value = span
		_wave_bar.value = span - wv.timer
		_wave_detail.text = "Prochaine dans %d s  ·  %d ennemis" % [ceili(wv.timer), w.enemies.size()]
	else:
		_wave_bar.max_value = 1
		_wave_bar.value = 1
		_wave_detail.text = "Dernière vague  ·  %d ennemis" % w.enemies.size()

	_base_bar.max_value = w.max_base_hp
	_base_bar.value = w.base_hp
	var low := float(w.base_hp) / w.max_base_hp < 0.35
	_base_bar.add_theme_stylebox_override("fill", Ui.box(Ui.RED if low else Ui.CYAN, Ui.RED if low else Ui.CYAN, 0, 4))
	_base_label.text = str(w.base_hp)

	_selection_panel.visible = not game.selected.is_empty()
	_update_site_panel()
	var boss := w.boss()
	_boss_panel.visible = boss != null
	if boss != null:
		_boss_bar.max_value = boss.max_hp
		_boss_bar.value = boss.hp
	_selection_label.text = "%d OUVRIER%s" % [game.selected.size(), "S" if game.selected.size() > 1 else ""]
	_worker_label.text = "OUVRIER (+%d)" % w.train_queue if w.train_queue > 0 else "OUVRIER"

	for kind in _build_cards:
		if kind == "orbital":
			continue
		var cost := Content.building(kind)
		var ok: bool = w.metal >= cost.metal and w.essence >= cost.essence
		(_build_cards[kind] as Button).modulate = Color(1, 1, 1) if ok else Color(1, 1, 1, 0.55)
	if _orbital_label != null and game.build_kind != "orbital":
		_orbital_label.text = "PRÊTE" if w.orbital_ready() else "%d s" % ceili(w.orbital_cooldown)
		_orbital_label.add_theme_color_override("font_color", Ui.GREEN if w.orbital_ready() else Ui.MUTED)

	if _flash_time > 0.0:
		_flash_time -= delta
	else:
		_info.add_theme_color_override("font_color", Ui.MUTED)
		if game.build_kind == "" and game.selected.is_empty() and w.waves.wave == 0:
			_info.text = "Glisse un doigt pour sélectionner tes ouvriers, puis touche un gisement"
		else:
			_info.text = ""
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
