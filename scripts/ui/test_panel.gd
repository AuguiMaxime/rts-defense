class_name TestPanel
extends PanelContainer
## Outils de test d'une mission lancée depuis l'éditeur (F2) : vitesse, invincibilité, ressources,
## forcer un objectif / un déclencheur / une vague, variables, journal du scénario.

var game: Node
var _body: VBoxContainer
var _speed_buttons := {}
var _obj_box: VBoxContainer
var _trig_box: VBoxContainer
var _vars: Label
var _log: Label
var _refresh := 0.0
var _obj_key := ""


func _init(g: Node) -> void:
	game = g
	theme = EditorUi.theme()
	add_theme_stylebox_override("panel", EditorUi.panel_style(6))
	custom_minimum_size = Vector2(340, 0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = EditorUi.vbox(6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	add_child(scroll)
	var head := EditorUi.hbox(4)
	var t := EditorUi.label("OUTILS DE TEST  (F2)", 14, EditorUi.SECTION)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := EditorUi.button("✕", "Fermer (F2)", false, 28)
	close.pressed.connect(func() -> void: visible = false)
	head.add_child(close)
	_body.add_child(head)
	var sp := EditorUi.hbox(3)
	for pair in [[0, "⏸"], [1, "x1"], [2, "x2"], [4, "x4"]]:
		var b := EditorUi.button(pair[1], "Pause" if pair[0] == 0 else "Vitesse %s" % pair[1], true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var n: int = pair[0]
		b.pressed.connect(func() -> void: _set_speed(n))
		_speed_buttons[n] = b
		sp.add_child(b)
	_body.add_child(sp)
	var row := EditorUi.grid(2, 4)
	var inv := EditorUi.button("Invincible", "La base et tes unités ne prennent plus de dégâts", true)
	inv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv.pressed.connect(func() -> void: game.world.cheat_invincible = inv.button_pressed)
	row.add_child(inv)
	var res := EditorUi.button("Ressources ∞", "Métal et essence illimités", true)
	res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res.pressed.connect(func() -> void: game.world.cheat_resources = res.button_pressed)
	row.add_child(res)
	var wave := EditorUi.button("Vague suivante", "Lance la vague suivante maintenant")
	wave.pressed.connect(func() -> void:
		game.world.waves.paused = false
		game.world.waves.start_next())
	row.add_child(wave)
	var spawn := EditorUi.button("Faire apparaître 5", "5 ennemis au premier point d'apparition")
	spawn.pressed.connect(_spawn_test)
	row.add_child(spawn)
	var skip := EditorUi.button("Avancer de 30 s", "Fait passer 30 secondes de jeu")
	skip.pressed.connect(func() -> void:
		for i in 300:
			game.world.tick(0.1))
	row.add_child(skip)
	var restart := EditorUi.button("Redémarrer", "Relance la mission depuis le début")
	restart.pressed.connect(func() -> void: Ui.play_custom(Ui.custom_map))
	row.add_child(restart)
	_body.add_child(row)
	_body.add_child(EditorUi.section("Affichage debug"))
	var dh := EditorUi.hbox(3)
	for pair in [["zones", "Zones"], ["paths", "Chemins"], ["ranges", "Portées"]]:
		var key: String = pair[0]
		var b := EditorUi.button(pair[1], "", true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = Ui.debug_view.get(key, false)
		var tog := func(on: bool) -> void:
			if on:
				Ui.debug_view[key] = true
			else:
				Ui.debug_view.erase(key)
		b.toggled.connect(tog)
		dh.add_child(b)
	_body.add_child(dh)
	_body.add_child(EditorUi.section("Vagues"))
	_waves = EditorUi.label("", 13)
	_waves.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_waves)
	_wave_box = EditorUi.vbox(3)
	_body.add_child(_wave_box)
	_body.add_child(EditorUi.section("Objectifs"))
	_obj_box = EditorUi.vbox(3)
	_body.add_child(_obj_box)
	_body.add_child(EditorUi.section("Déclencheurs (▶ = forcer)"))
	_trig_box = EditorUi.vbox(3)
	_body.add_child(_trig_box)
	_body.add_child(EditorUi.section("Variables"))
	_vars = EditorUi.label("", 13)
	_vars.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_vars)
	_body.add_child(EditorUi.section("Journal"))
	_log = EditorUi.label("", 12, Color(0.7, 0.78, 0.88))
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_log)
	_build_triggers.call_deferred()


func _set_speed(n: int) -> void:
	game.speed = n
	for k in _speed_buttons:
		(_speed_buttons[k] as Button).set_pressed_no_signal(k == n)


func _spawn_test() -> void:
	var w: GameWorld = game.world
	if w.grid.spawn_points.is_empty():
		return
	for i in 5:
		w.spawn_enemy("normal", w.grid.spawn_points[0], w.waves.hp_scale())


var _waves: Label
var _wave_box: VBoxContainer


func _build_waves() -> void:
	var wm: WaveManager = game.world.waves
	for wv: Dictionary in wm.plan:
		var h := EditorUi.hbox(3)
		var id := str(wv.get("id", ""))
		var run := EditorUi.button("▶", "Lancer cette vague maintenant", false, 28)
		run.pressed.connect(func() -> void: wm.launch_id(id))
		h.add_child(run)
		var stop := EditorUi.button("■", "Arrêter cette vague", false, 28)
		stop.pressed.connect(func() -> void: wm.stop(id))
		h.add_child(stop)
		var l := EditorUi.label(str(wv.get("name", id)), 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		h.add_child(l)
		_wave_box.add_child(h)


func _build_triggers() -> void:
	_build_waves()
	var sc: Scenario = game.world.scenario
	for tr in sc.triggers:
		var h := EditorUi.hbox(3)
		var run := EditorUi.button("▶", "Exécuter ses actions sans vérifier les conditions", false, 28)
		var id: String = tr.def.id
		run.pressed.connect(func() -> void: sc.run_trigger(id, true))
		h.add_child(run)
		var l := EditorUi.label(str(tr.def.name), 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.set_meta("tr", tr)
		h.add_child(l)
		_trig_box.add_child(h)
	if sc.triggers.is_empty():
		_trig_box.add_child(EditorUi.muted("Aucun déclencheur"))


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh > 0.0:
		return
	_refresh = 0.25
	for k in _speed_buttons:
		(_speed_buttons[k] as Button).set_pressed_no_signal(k == game.speed)
	var sc: Scenario = game.world.scenario
	var key := ""
	for o in sc.objectives:
		key += "%s|%s|" % [o.state, o.text]
	if key != _obj_key:
		_obj_key = key
		for c in _obj_box.get_children():
			c.queue_free()
		for o in sc.objectives:
			var h := EditorUi.hbox(3)
			var col: Color = {"done": Ui.GREEN, "failed": Ui.RED, "hidden": Color(0.5, 0.55, 0.62)}.get(o.state, Color(0.88, 0.92, 1.0))
			var l := EditorUi.label("%s  [%s]  %s" % [o.def.name, {"active": "en cours", "done": "réussi", "failed": "échoué", "hidden": "caché", "pending": "en attente"}.get(o.state, o.state), o.text], 13, col)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			h.add_child(l)
			var id: String = o.def.id
			var ok := EditorUi.button("✔", "Réussir", false, 26)
			ok.pressed.connect(func() -> void:
				sc.set_objective(id, "active")
				sc.set_objective(id, "done"))
			h.add_child(ok)
			var ko := EditorUi.button("✖", "Faire échouer", false, 26)
			ko.pressed.connect(func() -> void:
				sc.set_objective(id, "active")
				sc.set_objective(id, "failed"))
			h.add_child(ko)
			_obj_box.add_child(h)
		if sc.objectives.is_empty():
			_obj_box.add_child(EditorUi.muted("Aucun objectif (règles du type de mission)"))
	for h in _trig_box.get_children():
		for c in h.get_children():
			if c is Label and c.has_meta("tr"):
				var tr: Dictionary = c.get_meta("tr")
				(c as Label).modulate = Color(1, 1, 1, 1.0 if tr.enabled else 0.45)
				(c as Label).text = "%s  ×%d" % [tr.def.name, tr.count]
	var wm: WaveManager = game.world.waves
	var nxt := "prochaine dans %d s" % ceili(wm.timer) if wm.can_skip() and wm.timer != INF and wm.auto_on else "pas de vague programmée"
	_waves.text = "Vague %d / %d  ·  %s  ·  %d ennemis restants%s%s" % [wm.wave, wm.total, nxt, wm.left,
			"  ·  en pause" if wm.paused else "", "  ·  vitesse ×%.1f" % wm.speed if wm.speed != 1.0 else ""]
	var vs: Array[String] = []
	for k in sc.vars:
		vs.append("%s = %s" % [k, str(sc.vars[k])])
	for k in sc.timers:
		vs.append("⏱ %s : %.1f s" % [k, float(sc.timers[k].left)])
	_vars.text = "\n".join(vs) if not vs.is_empty() else "—"
	_log.text = "\n".join(sc.log.slice(maxi(0, sc.log.size() - 30)))
