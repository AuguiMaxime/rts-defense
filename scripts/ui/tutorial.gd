class_name Tutorial
extends Control
## Tutoriel guidé de la première partie (map 1). Les vagues attendent la fin des étapes.

var game: Node
var _step := 0
var _panel: PanelContainer
var _title: Label
var _text: Label
var _next: Button
var _t := 0.0

const STEPS := [
	{"title": "SÉLECTIONNE TES OUVRIERS", "text": "Glisse un doigt autour des petits robots près de la base pour les sélectionner."},
	{"title": "RÉCOLTE DU MÉTAL", "text": "Touche un gisement bleu : tes ouvriers font les allers-retours tout seuls."},
	{"title": "CONSTRUIS UNE DÉFENSE", "text": "Avec un ouvrier sélectionné, touche MITRAILLEUSE en bas à droite, puis une case libre entre la base et les ennemis."},
	{"title": "FORME DES UNITÉS", "text": "Touche la base, puis OUVRIER ou SOLDAT. Touche ensuite un minerai : les nouveaux ouvriers iront y récolter tout seuls."},
	{"title": "PRÊT AU COMBAT", "text": "Les ennemis sortent des cercles rouges. Construis une caserne ou une usine pour une armée, et touche un bâtiment pour l'améliorer, le réparer ou le vendre."},
]


func setup(g: Node) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	c.offset_top = -390
	c.offset_bottom = -225
	_panel = Ui.panel(Vector2(520, 0), true)
	var v := Ui.vbox(8)
	var top := Ui.hbox(10)
	_title = Ui.title("", 19, Ui.CYAN)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	var skip := Ui.button("PASSER", false, Vector2(110, 40))
	skip.add_theme_font_size_override("font_size", 13)
	skip.pressed.connect(finish)
	top.add_child(skip)
	v.add_child(top)
	_text = Ui.label("", 21, Ui.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 470
	v.add_child(_text)
	_next = Ui.button("C'EST PARTI", true, Vector2(0, 52))
	_next.pressed.connect(finish)
	v.add_child(_next)
	_panel.add_child(v)
	c.add_child(_panel)
	_show(0)


func blocks(p: Vector2) -> bool:
	return visible and _panel.get_global_rect().has_point(p)


func _show(i: int) -> void:
	_step = i
	_title.text = "%d/%d · %s" % [i + 1, STEPS.size(), STEPS[i].title]
	_text.text = STEPS[i].text
	_next.visible = i == STEPS.size() - 1
	_panel.modulate.a = 0.0
	_panel.create_tween().tween_property(_panel, "modulate:a", 1.0, 0.25)
	Sfx.play("built", -8.0, 0.1)


func _process(delta: float) -> void:
	if game == null or not visible:
		return
	_t += delta
	var w: GameWorld = game.world
	if w.waves.wave > 0:
		# Le joueur a lancé une vague lui-même : il n'a plus besoin du tutoriel.
		finish()
		return
	# Les vagues attendent que le joueur ait fini les étapes d'apprentissage.
	if _step < STEPS.size() - 1:
		w.waves.timer = maxf(w.waves.timer, Balance.FIRST_WAVE_DELAY)
	match _step:
		0:
			_marker(_workers_center())
			if not game.selected.is_empty():
				_show(1)
		1:
			_marker(_nearest_metal())
			if w.workers.any(func(x: Worker) -> bool: return x.job == Worker.Job.HARVEST):
				_show(2)
		2:
			_marker(_workers_center() if game.selected.is_empty() else Vector2.INF)
			_pulse_card("gun")
			if not w.sites.is_empty():
				_show(3)
		3:
			_marker(Vector2.INF if game.sel_base else w.base_center())
			_pulse_card("worker" if game.sel_base else "")
			if w.train_queue > 0 or w.workers.size() > Balance.START_WORKERS or not w.units.is_empty():
				_pulse_card("")
				_show(4)
		4:
			_marker(Vector2.INF)


func finish() -> void:
	_marker(Vector2.INF)
	_pulse_card("")
	Save.data.tutorial_done = true
	Save.save_data()
	visible = false
	queue_free()


func _marker(world_cells: Vector2) -> void:
	game.units_view.tutorial_marker = world_cells


func _pulse_card(kind: String) -> void:
	game.hud.pulse_card(kind, _t)


func _workers_center() -> Vector2:
	var w: GameWorld = game.world
	if w.workers.is_empty():
		return Vector2.INF
	var sum := Vector2.ZERO
	for x in w.workers:
		sum += x.pos
	return sum / w.workers.size()


func _nearest_metal() -> Vector2:
	var w: GameWorld = game.world
	var best := Vector2.INF
	for c in w.grid.metal_deposits:
		var p := Vector2(c) + Vector2(0.5, 0.5)
		if best == Vector2.INF or p.distance_to(w.base_center()) < best.distance_to(w.base_center()):
			best = p
	return best
