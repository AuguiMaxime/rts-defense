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
var console: Console
var _fps: Label
var _boss_panel: PanelContainer
var _boss_seen := -1
var _boss_banner := 0.0
var _pause_layer: Control
var _pause_sub: Label
var _end_layer: Control
var _blocks: Array[Control] = [] # zones qui bloquent les gestes sur la map
var _flash_time := 0.0
var _column: VBoxContainer
var _coop_badge: Label
var _damage_vignette: ColorRect
var _damage_alpha := 0.0


func setup(g: Node) -> void:
	game = g
	theme = Ui.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_vignette = ColorRect.new()
	_damage_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_vignette.color = Color(Ui.RED, 0.0)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float strength = 0.0;\nvoid fragment() {\n\tfloat d = distance(UV, vec2(0.5));\n\tCOLOR = vec4(0.97, 0.2, 0.25, smoothstep(0.35, 0.75, d) * strength);\n}"
	mat.shader = sh
	_damage_vignette.material = mat
	add_child(_damage_vignette)
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := Ui.safe_margins()
	m.add_theme_constant_override("margin_left", 14 + int(sm[0]))
	m.add_theme_constant_override("margin_top", 14 + int(sm[1]))
	m.add_theme_constant_override("margin_right", 14 + int(sm[2]))
	m.add_theme_constant_override("margin_bottom", 14 + int(sm[3]))
	add_child(m)
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column = Ui.vbox(8)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(_column)
	_build_top_bar()
	var info_row := Ui.hbox(10)
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if game.coop:
		_coop_badge = Ui.label("", 18, Ui.MAGENTA, true)
		_coop_badge.add_theme_constant_override("outline_size", 6)
		info_row.add_child(_coop_badge)
	_info = Ui.label("", 20, Ui.MUTED)
	_info.add_theme_constant_override("outline_size", 6)
	info_row.add_child(_info)
	_column.add_child(info_row)
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


func is_over_ui(p: Vector2) -> bool:
	if game.tutorial != null and is_instance_valid(game.tutorial) and game.tutorial.blocks(p):
		return true
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

	# Colonne de droite : (base + vitesse + pause) puis la vague en dessous
	var right := Ui.vbox(8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(right)
	var right_top := Ui.hbox(12)
	right_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(right_top)
	row = right_top

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

	# Vague
	var wave := Ui.panel(Vector2(0, 0))
	wave.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.88), Color(Ui.RED, 0.45), 2, 8, 0.12))
	var wv := Ui.vbox(4)
	var wt := Ui.hbox(10)
	var wicon := CurrencyIcon.new()
	wicon.kind = "wave"
	wt.add_child(wicon)
	_wave_title = Ui.title("VAGUE 0/10", 17)
	_wave_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wt.add_child(_wave_title)
	_next_btn = Ui.button("▶▶", false, Vector2(56, 32))
	_next_btn.add_theme_font_size_override("font_size", 16)
	_next_btn.tooltip_text = "Lancer la vague suivante"
	_next_btn.pressed.connect(func() -> void: game.issue({"t": "next_wave"}))
	wt.add_child(_next_btn)
	wv.add_child(wt)
	_wave_bar = ProgressBar.new()
	_wave_bar.show_percentage = false
	_wave_bar.custom_minimum_size = Vector2(0, 8)
	_wave_bar.add_theme_stylebox_override("fill", Ui.box(Ui.RED, Ui.RED, 0, 4))
	wv.add_child(_wave_bar)
	_wave_detail = Ui.label("", 15, Ui.MUTED)
	wv.add_child(_wave_detail)
	wave.add_child(wv)
	wave.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.add_child(wave)
	_obj_panel = Ui.panel(Vector2(0, 0))
	_obj_panel.add_theme_stylebox_override("panel", Ui.box(Color(Ui.PANEL, 0.85), Color(Ui.GOLD, 0.5), 2, 6, 0.12))
	_obj_box = Ui.vbox(2)
	_obj_panel.add_child(_obj_box)
	_obj_panel.visible = false
	_obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_obj_panel)
	_blocks.append(wave)



func _build_boss_bar() -> void:
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel = PanelContainer.new()
	var sb := Ui.box(Color(0.15, 0.03, 0.06, 0.85), Ui.RED, 1, 4, 0.12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_boss_panel.add_theme_stylebox_override("panel", sb)
	_boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_panel.visible = false
	var t := Ui.title("☠  LE BOSS EST APPARU", 14, Ui.RED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_panel.add_child(t)
	c.add_child(_boss_panel)
	_column.add_child(c)


func _build_bottom_bar() -> void:
	console = Console.new()
	console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(console)
	console.setup(game)
	for c in console.blocks():
		_blocks.append(c)


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
	quit.pressed.connect(func() -> void:
		if game.coop:
			Net.leave()
		Ui.goto("editor" if game.level.id == 0 else "menu"))
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
	if game.coop:
		_pause_sub.text = "Coop %s · la partie continue pendant la pause" % ("(hôte)" if Net.is_host else "")
	elif game.survival:
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
	var menu := Ui.button("ÉDITEUR" if game.level.id == 0 else "MENU", false, Vector2(150, 62))
	menu.pressed.connect(func() -> void:
		if game.coop:
			Net.leave()
		Ui.goto("editor" if game.level.id == 0 else ("menu" if game.coop else "levels")))
	buttons.add_child(menu)
	var again := Ui.button("SALON" if game.coop else "REJOUER", false, Vector2(170, 62))
	again.pressed.connect(func() -> void: game.restart())
	buttons.add_child(again)
	var next_id: int = game.next_level_id()
	if won and next_id > 0 and not game.coop:
		var nxt := Ui.button("SUIVANT", true, Vector2(180, 62))
		nxt.pressed.connect(func() -> void: Ui.play_level(next_id))
		buttons.add_child(nxt)
	v.add_child(buttons)
	if won and not Net.is_client():
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

## Voile rouge sur les bords quand la base est touchée.
func flash_damage() -> void:
	_damage_alpha = minf(0.75, _damage_alpha + 0.25)


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


## Fait clignoter une action de la console (tutoriel). id "" = aucune.
func pulse_card(id: String, _t: float = 0.0) -> void:
	console.pulse(id)


var _obj_panel: PanelContainer
var _obj_box: VBoxContainer
var _obj_key := ""


## Objectifs bonus de la mission (sous le panneau des vagues).
func _update_objectives(w: GameWorld) -> void:
	if w.objectives.is_empty():
		return
	_obj_panel.visible = true
	var key := ""
	for o in w.objectives:
		key += "%s%d|" % [o.state, o.destroyed]
	if key == _obj_key:
		return
	# Annonce des changements d'état
	if _obj_key != "":
		var old := _obj_key.split("|")
		for i in w.objectives.size():
			var o: Dictionary = w.objectives[i]
			var def: Dictionary = Balance.OBJECTIVES[o.type]
			if i < old.size() and not old[i].begins_with(o.state):
				match o.state:
					"active":
						flash("★ OBJECTIF BONUS : %s !" % def.name, Ui.GOLD)
						Sfx.play("wave", -6.0)
					"done":
						flash("★ Objectif réussi : +%d métal  +%d essence" % [def.metal, def.essence], Ui.GREEN)
						Sfx.play("victory", -6.0)
					"failed":
						flash("Objectif raté : la cible s'est échappée", Ui.RED)
	_obj_key = key
	for c in _obj_box.get_children():
		c.queue_free()
	_obj_box.add_child(Ui.label("★ OBJECTIFS BONUS", 13, Ui.GOLD, true))
	for o in w.objectives:
		var def: Dictionary = Balance.OBJECTIVES[o.type]
		var txt: String = def.name
		var col := Ui.MUTED
		match o.state:
			"pending":
				txt += "  ·  vague %d" % o.wave
			"active":
				txt += "  ·  %d/%d" % [o.destroyed, o.total] if o.total > 1 else "  ·  EN COURS"
				col = Ui.GOLD
			"done":
				txt = "✔ " + txt
				col = Ui.GREEN
			"failed":
				txt = "✖ " + txt
				col = Ui.RED
		_obj_box.add_child(Ui.label(txt, 13, col))


func _process(delta: float) -> void:
	if game == null:
		return
	var w: GameWorld = game.world
	_update_objectives(w)
	_metal.text = str(w.metal)
	_essence.text = str(w.essence)
	var used := w.pop_used()
	_pop.text = "%d/%d" % [used, w.pop_cap]
	_pop.add_theme_color_override("font_color", Ui.RED if used >= w.pop_cap else Ui.TEXT)

	var wv := w.waves
	_wave_title.text = "VAGUE %d/%s" % [wv.wave, "∞" if wv.infinite else str(wv.total)]
	_next_btn.visible = wv.has_more_waves()
	if wv.has_more_waves():
		var span := Balance.FIRST_WAVE_DELAY if wv.wave == 0 else wv.interval
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

	# Bandeau boss : affiché 3 s à l'apparition, puis la barre de PV suit le boss sur la carte.
	var boss := w.boss()
	if boss != null and boss.id != _boss_seen:
		_boss_seen = boss.id
		_boss_banner = 3.0
	_boss_banner -= delta
	_boss_panel.visible = _boss_banner > 0.0
	_boss_panel.modulate.a = clampf(_boss_banner / 0.5, 0.0, 1.0)

	if _flash_time > 0.0:
		_flash_time -= delta
	else:
		_info.add_theme_color_override("font_color", Ui.MUTED)
		if game.build_kind == "" and game.selected.is_empty() and w.waves.wave == 0 and not is_instance_valid(game.tutorial):
			_info.text = "Touche la base pour former des unités · retouche ou ✕ pour désélectionner"
		else:
			_info.text = ""
	if _coop_badge != null:
		_coop_badge.text = "● COOP %s ·" % ("HÔTE" if Net.is_host else "INVITÉ") if Net.partner_connected else "○ COOP · seul ·"
	if _damage_alpha > 0.0:
		_damage_alpha = maxf(0.0, _damage_alpha - delta * 1.2)
		(_damage_vignette.material as ShaderMaterial).set_shader_parameter("strength", _damage_alpha)
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()
