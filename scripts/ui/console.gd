class_name Console
extends HBoxContainer
## Console du bas façon StarCraft : minimap | informations de la sélection (+ file) | grille d'actions.

const CARD_COLS := 4
const CARD_ROWS := 2
const CARD_SIZE := Vector2(66, 66)

var game: Node
var minimap: Minimap
var _info_box: VBoxContainer
var _info_panel: PanelContainer
var _card_panel: PanelContainer
var _card_grid: GridContainer
var _card_buttons: Array[Button] = []
var _actions: Array = []
var _context_key := ""
var _info_key := ""
var _refresh_timer := 0.0
var _queue_slots: Array[Button] = []
var _queue_bar: ProgressBar
var _rally_btn: Button
var _info_hp: ProgressBar
var _info_detail: Label
var _pulse_id := ""
var _idle_btn: Button
var _idle_label: Label
var _t := 0.0


func setup(g: Node) -> void:
	game = g
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END

	var mm_panel := _panel(Color(Ui.CYAN, 0.4))
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(150, 106)
	mm_panel.add_child(minimap)
	minimap.setup(g)
	var left := Ui.vbox(6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_vertical = Control.SIZE_SHRINK_END
	_idle_btn = _make_idle_button()
	left.add_child(_idle_btn)
	left.add_child(mm_panel)
	add_child(left)

	add_child(Ui.spacer())
	var info_panel := _panel(Color(Ui.CYAN, 0.4))
	info_panel.custom_minimum_size = Vector2(250, 0)
	_info_box = Ui.vbox(4)
	info_panel.add_child(_info_box)
	add_child(info_panel)
	_info_panel = info_panel

	var card_panel := _panel(Color(Ui.CYAN, 0.55))
	_card_grid = GridContainer.new()
	_card_grid.columns = CARD_COLS
	_card_grid.add_theme_constant_override("h_separation", 6)
	_card_grid.add_theme_constant_override("v_separation", 6)
	for i in CARD_COLS * CARD_ROWS:
		var b := _make_card_button()
		var idx := i
		b.pressed.connect(func() -> void: _on_card(idx))
		_card_grid.add_child(b)
		_card_buttons.append(b)
	card_panel.add_child(_card_grid)
	add_child(card_panel)
	_card_panel = card_panel


func blocks() -> Array[Control]:
	var out: Array[Control] = [_idle_btn]
	for c in get_children():
		if c is PanelContainer:
			out.append(c)
		else:
			for cc in c.get_children():
				if cc is Control:
					out.append(cc)
	return out


## Bouton « ouvriers inactifs » (au-dessus de la minimap) : touche = suivant, double touche = tous.
func _make_idle_button() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sb := Ui.box(Color(0.12, 0.09, 0.02, 0.92), Ui.GOLD, 2, 4)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", Ui.box(Color(Ui.GOLD, 0.35), Ui.GOLD, 2, 4))
	var h := Ui.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var img := TextureRect.new()
	img.texture = Sprites.WORKER
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(30, 30)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(img)
	_idle_label = Ui.label("0", 16, Ui.GOLD, true)
	_idle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_idle_label)
	b.pressed.connect(func() -> void: game.select_idle_worker())
	b.tooltip_text = "Ouvriers inactifs (double touche : tous)"
	return b


func _panel(border: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := Ui.box(Color(0.03, 0.06, 0.11, 0.92), border, 2, 4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(Ui.CYAN, 0.12)
	sb.shadow_size = 8
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_END
	return p


# --- Grille d'actions ------------------------------------------------------------------

func _make_card_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	var v := Ui.vbox(0)
	v.name = "V"
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var img := TextureRect.new()
	img.name = "Img"
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size = Vector2(0, 32)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(img)
	var icon := CurrencyIcon.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(24, 28)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	var glyph := Ui.label("", 20, Ui.CYAN, true)
	glyph.name = "Glyph"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.custom_minimum_size = Vector2(0, 28)
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(glyph)
	var name_l := Ui.label("", 10, Ui.TEXT, true)
	name_l.name = "Name"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	var cost := Ui.label("", 11, Ui.METAL, true)
	cost.name = "Cost"
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cost)
	b.add_child(v)
	return b


func _on_card(i: int) -> void:
	if i >= _actions.size():
		return
	var a: Dictionary = _actions[i]
	if a.has("call"):
		a.call.call()
	_context_key = "" # rafraîchit (états actifs, file…)


func _apply_actions(actions: Array) -> void:
	_actions = actions
	for i in _card_buttons.size():
		var b := _card_buttons[i]
		var v := b.get_node("V")
		var img: TextureRect = v.get_node("Img")
		var icon: CurrencyIcon = v.get_node("Icon")
		var glyph: Label = v.get_node("Glyph")
		var name_l: Label = v.get_node("Name")
		var cost: Label = v.get_node("Cost")
		if i >= actions.size():
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.25)
			img.visible = false
			icon.visible = false
			glyph.visible = false
			name_l.text = ""
			cost.text = ""
			b.theme_type_variation = ""
			continue
		var a: Dictionary = actions[i]
		b.disabled = false
		var icon_v: Variant = a.get("icon")
		img.visible = icon_v is Texture2D
		icon.visible = icon_v is String and not str(icon_v).begins_with("#")
		glyph.visible = icon_v is String and str(icon_v).begins_with("#")
		if img.visible:
			img.texture = icon_v
			img.modulate = a.get("tint", Color(1, 1, 1))
		elif icon.visible:
			icon.kind = icon_v
			icon.queue_redraw()
		elif glyph.visible:
			glyph.text = str(icon_v).substr(1)
		name_l.text = a.get("label", "")
		cost.text = a.get("cost", "")
		var active: bool = a.get("active", false)
		b.theme_type_variation = "PrimaryButton" if active else ""
		name_l.add_theme_color_override("font_color", Ui.BG if active else Ui.TEXT)
		cost.add_theme_color_override("font_color", Ui.BG if active else a.get("cost_color", Ui.METAL))
		b.modulate = Color(1, 1, 1) if a.get("enabled", true) else Color(1, 1, 1, 0.5)


## Fait clignoter l'action d'identifiant id (tutoriel). "" = aucune.
func pulse(id: String) -> void:
	_pulse_id = id


# --- Panneau d'informations -------------------------------------------------------------

func _clear_info() -> void:
	for c in _info_box.get_children():
		c.queue_free()
	_queue_slots.clear()
	_queue_bar = null
	_rally_btn = null
	_info_hp = null
	_info_detail = null


func _title_row(text: String, tex: Variant, color := Ui.CYAN) -> void:
	var h := Ui.hbox(6)
	if tex is Texture2D:
		var img := TextureRect.new()
		img.texture = tex
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.custom_minimum_size = Vector2(26, 26)
		h.add_child(img)
	var t := Ui.title(text, 13, color)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.clip_text = true
	h.add_child(t)
	# Bouton de désélection
	var x := Button.new()
	x.text = "✕"
	x.focus_mode = Control.FOCUS_NONE
	x.custom_minimum_size = Vector2(40, 34)
	x.add_theme_font_size_override("font_size", 18)
	x.pressed.connect(func() -> void: game.deselect())
	h.add_child(x)
	_info_box.add_child(h)


func _hp_bar(color := Ui.GREEN) -> void:
	_info_hp = ProgressBar.new()
	_info_hp.show_percentage = false
	_info_hp.custom_minimum_size = Vector2(0, 6)
	_info_hp.add_theme_stylebox_override("fill", Ui.box(color, color, 0, 3))
	_info_box.add_child(_info_hp)


func _detail(text := "", size := 13) -> void:
	_info_detail = Ui.label(text, size, Ui.MUTED)
	_info_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_box.add_child(_info_detail)


func _queue_row(producer_id: int) -> void:
	var h := Ui.hbox(4)
	for i in Producer.MAX_QUEUE:
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
		b.focus_mode = Control.FOCUS_NONE
		var img := TextureRect.new()
		img.name = "Img"
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(img)
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.offset_left = -4
		img.offset_top = -4
		img.offset_right = 4
		img.offset_bottom = 4
		var idx := i
		b.pressed.connect(func() -> void: game.cancel_queue(producer_id, idx))
		h.add_child(b)
		_queue_slots.append(b)
	_info_box.add_child(h)
	_queue_bar = ProgressBar.new()
	_queue_bar.show_percentage = false
	_queue_bar.custom_minimum_size = Vector2(0, 6)
	_queue_bar.add_theme_stylebox_override("fill", Ui.box(Ui.GREEN, Ui.GREEN, 0, 3))
	_info_box.add_child(_queue_bar)
	_rally_btn = Button.new()
	_rally_btn.focus_mode = Control.FOCUS_NONE
	_rally_btn.custom_minimum_size = Vector2(0, 34)
	_rally_btn.add_theme_font_size_override("font_size", 13)
	_rally_btn.pressed.connect(func() -> void: game.toggle_rally_mode())
	_info_box.add_child(_rally_btn)


static func unit_icon(type_name: String) -> Texture2D:
	if type_name == "worker":
		return Sprites.WORKER
	return Sprites.UNIT_LOOK[type_name].tex


func _build_info() -> void:
	_clear_info()
	var w: GameWorld = game.world
	match game.selection_kind():
		"base":
			_title_row("BASE", Sprites.BASE_CORE)
			_hp_bar(Ui.CYAN)
			_queue_row(GameWorld.BASE_ID)
			_detail()
		"site":
			var s: BuildSite = game.focused_site
			var st := s.stats()
			var name: String = st.name.to_upper()
			if s.is_tower() and s.built:
				name += "  ·  NIV. %d" % s.level
			var tex: Variant = Sprites.TOWER_LOOK[s.kind].turret if s.is_tower() else null
			_title_row(name, tex)
			_hp_bar()
			if s.built and s.is_producer():
				_queue_row(s.id)
			_detail()
		"mobile":
			var ws: Array = game.selected
			var us: Array = game.sel_units
			if ws.size() + us.size() == 1:
				var one: Variant = ws[0] if not ws.is_empty() else us[0]
				var type_name := "worker" if one is Worker else (one as Unit).type
				_title_row(str(Content.UNITS[type_name].name).to_upper(), unit_icon(type_name), Ui.GREEN)
				_hp_bar()
				_detail()
			else:
				var parts: Array[String] = []
				if not ws.is_empty():
					parts.append("%d OUVRIER%s" % [ws.size(), "S" if ws.size() > 1 else ""])
				if not us.is_empty():
					parts.append("%d UNITÉ%s" % [us.size(), "S" if us.size() > 1 else ""])
				_title_row("  ·  ".join(parts), null, Ui.GREEN)
				var grid := GridContainer.new()
				grid.columns = 9
				grid.add_theme_constant_override("h_separation", 2)
				grid.add_theme_constant_override("v_separation", 2)
				var all: Array = ws + us
				for x in all.slice(0, 18):
					var img := TextureRect.new()
					img.texture = Sprites.WORKER if x is Worker else unit_icon((x as Unit).type)
					img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					img.custom_minimum_size = Vector2(24, 24)
					grid.add_child(img)
				_info_box.add_child(grid)
				_detail()
		_:
			pass


func _update_info() -> void:
	var w: GameWorld = game.world
	var kind: String = game.selection_kind()
	if kind == "base":
		_info_hp.max_value = w.max_base_hp
		_info_hp.value = w.base_hp
		_update_queue(w.base_producer)
		_info_detail.text = _rally_text(w.base_producer)
	elif kind == "site":
		var s: BuildSite = game.focused_site
		_info_hp.max_value = s.max_hp
		_info_hp.value = s.hp
		var st := s.stats()
		if not s.built:
			_info_detail.text = "Chantier : %d %%  ·  %d/%d PV" % [roundi(s.progress() * 100), s.hp, s.max_hp]
		elif s.is_tower():
			var targets: String = {"both": "sol + air", "ground": "sol", "air": "air"}[st.targets]
			_info_detail.text = "%d/%d PV  ·  %d dégâts  ·  portée %.1f  ·  %s" % [s.hp, s.max_hp, st.damage, st.range, targets]
		elif s.is_producer():
			_update_queue(s.producer)
			_info_detail.text = _rally_text(s.producer)
		else:
			_info_detail.text = "%d/%d PV  ·  +%d population" % [s.hp, s.max_hp, Content.HOUSE.pop]
	elif kind == "mobile" and _info_detail != null:
		var ws: Array = game.selected
		var us: Array = game.sel_units
		if ws.size() + us.size() == 1:
			if not ws.is_empty():
				var x: Worker = ws[0]
				_info_hp.max_value = Balance.WORKER_HP
				_info_hp.value = x.hp
				var job: String = {Worker.Job.HARVEST: "récolte", Worker.Job.BUILD: "construit", Worker.Job.REPAIR: "répare"}.get(x.job, "en attente")
				_info_detail.text = "%d/%d PV  ·  %s%s" % [x.hp, Balance.WORKER_HP, job, "  ·  réparation auto" if x.auto_repair else ""]
			else:
				var u: Unit = us[0]
				var st := u.stats()
				_info_hp.max_value = u.max_hp
				_info_hp.value = u.hp
				var targets: String = {"both": "sol + air", "ground": "sol", "air": "air"}[st.targets]
				_info_detail.text = "%d/%d PV  ·  %d dégâts  ·  portée %.1f  ·  armure %d  ·  %s" % [u.hp, u.max_hp, st.damage, st.range, st.armor, targets]
		else:
			var auto := ws.filter(func(x: Worker) -> bool: return x.auto_repair).size()
			_info_detail.text = "Réparation auto : %d/%d ouvriers" % [auto, ws.size()] if not ws.is_empty() else "Touche un ennemi pour l'attaquer, le sol pour te déplacer"


func _rally_text(p: Producer) -> String:
	if _rally_btn != null:
		var on: bool = game.rally_mode
		_rally_btn.text = "⚑ TOUCHE LA CARTE…" if on else ("⚑ DÉPLACER LE RALLIEMENT" if p.has_rally() else "⚑ PLACER LE RALLIEMENT")
		_rally_btn.theme_type_variation = "PrimaryButton" if on else ""
	if not p.busy():
		return "File vide"
	return "%s : %.1f s" % [Content.UNITS[p.queue[0]].name, p.current_time() - p.progress]


func _update_queue(p: Producer) -> void:
	for i in _queue_slots.size():
		var b := _queue_slots[i]
		var img: TextureRect = b.get_node("Img")
		if i < p.queue.size():
			img.texture = unit_icon(p.queue[i])
			b.modulate = Color(1, 1, 1)
		else:
			img.texture = null
			b.modulate = Color(1, 1, 1, 0.35)
	if _queue_bar != null:
		_queue_bar.value = p.ratio() * 100.0


func _process(delta: float) -> void:
	if game == null:
		return
	_t += delta
	var idle := (game.world as GameWorld).idle_workers().size()
	_idle_btn.visible = idle > 0
	_idle_label.text = "INACTIF%s %d" % ["S" if idle > 1 else "", idle]
	_idle_btn.self_modulate = Color(1, 1, 1).lerp(Color(1.5, 1.3, 0.7), 0.5 + 0.5 * sin(_t * 4.0))
	var key: String = game.selection_key()
	if key != _info_key:
		_info_key = key
		_build_info()
		_context_key = ""
		_info_panel.visible = game.selection_kind() != "none"
	if _info_hp != null:
		_update_info()
	_refresh_timer -= delta
	if key + game.build_kind != _context_key or _refresh_timer <= 0.0:
		_refresh_timer = 0.25
		_context_key = key + game.build_kind
		_apply_actions(game.card_actions())
		_card_panel.visible = not _actions.is_empty()
	for i in _actions.size():
		var b := _card_buttons[i]
		if _pulse_id != "" and _actions[i].get("id", "") == _pulse_id:
			b.self_modulate = Color(1, 1, 1).lerp(Color(0.4, 1.6, 1.8), 0.5 + 0.5 * sin(_t * 6.0))
		else:
			b.self_modulate = Color(1, 1, 1)
