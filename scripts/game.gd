extends Node2D
## Écran de jeu : relie la simulation (GameWorld) à l'affichage, aux contrôles et au HUD.

const TILE := MapView.TILE

var world: GameWorld
var level: Dictionary
var map_script: Variant
var selected: Array[Worker] = []
var focused_site: BuildSite = null
var build_kind := "" # "" = pas en mode construction ; "orbital" = ciblage du pouvoir
var speed := 1
var paused := false
var survival := false
var new_record := false
var tutorial: Tutorial = null
var _ended := false
var _granted_waves := 0
var _granted_kills := 0
var _last_wave := 0

@onready var map_view: MapView = $MapView
@onready var units_view: UnitsView = $UnitsView
@onready var camera: CameraController = $Camera
@onready var hud: GameHud = GameHud.new()


func _ready() -> void:
	level = Content.level(Ui.current_level)
	map_script = load(level.map)
	survival = Ui.survival
	world = GameWorld.new(MapLoader.from_layout(map_script.LAYOUT), _build_config())
	if survival:
		world.waves.infinite = true
	map_view.setup(world.grid, map_script.GROUND)
	units_view.world = world
	units_view.skin_tint = Content.skin(Save.data.skin).tint

	camera.set_bounds(Rect2(Vector2.ZERO, Vector2(world.grid.width, world.grid.height) * TILE).grow(TILE))
	camera.center_on(world.base_center() * TILE)
	camera.is_over_ui = func(p: Vector2) -> bool: return hud.is_over_ui(p)
	camera.tapped.connect(_on_tapped)
	camera.selection_updated.connect(func(a: Vector2, b: Vector2) -> void: units_view.selection_rect = Rect2(a, b - a).abs())
	camera.selection_ended.connect(_on_selection_ended)
	camera.selection_cancelled.connect(func() -> void: units_view.selection_rect = Rect2())

	$HUD.add_child(hud)
	hud.setup(self)
	if level.id == 1 and not survival and not Save.data.get("tutorial_done", false):
		tutorial = Tutorial.new()
		tutorial.theme = Ui.theme
		$HUD.add_child(tutorial)
		tutorial.setup(self)


## Bonus de technos et augments appliqués à la partie.
func _build_config() -> Dictionary:
	var cfg := {
		"waves": level.waves,
		"difficulty": 1.0 if Ui.survival else level.difficulty,
		"wave_interval": level.get("interval", Balance.WAVE_INTERVAL),
		"start_metal": Balance.START_METAL + int(Content.tech("reserves").value) * Save.tech_level("reserves"),
		"start_workers": Balance.START_WORKERS,
		"base_hp": roundi(Balance.BASE_HP * (1.0 + Content.tech("hull").value * Save.tech_level("hull"))),
		"damage_mult": 1.0 + Content.tech("ammo").value * Save.tech_level("ammo"),
		"worker_speed_mult": 1.0 + Content.tech("logistics").value * Save.tech_level("logistics"),
		"carry_bonus": Save.tech_level("logistics"),
		"orbital": Save.tech_level("orbital") > 0,
		"laser": Save.owns("tower_laser"),
	}
	var used: Array[String] = []
	if Save.augment_count("starter_kit") > 0:
		cfg.start_metal += 150
		used.append("starter_kit")
	if Save.augment_count("extra_workers") > 0:
		cfg.start_workers += 2
		used.append("extra_workers")
	if Save.augment_count("shield") > 0:
		cfg.base_hp += 300
		used.append("shield")
	for id in used:
		Save.change_augment(id, -1)
	if not used.is_empty():
		Ui.toast.call_deferred("%d augment(s) activé(s)" % used.size(), Ui.GREEN)
	return cfg


func _process(delta: float) -> void:
	if not paused:
		for i in speed:
			world.tick(delta)
	if focused_site != null and not world.sites.has(focused_site):
		focus_site(null)
	if selected.any(func(w: Worker) -> bool: return not world.workers.has(w)):
		_set_selection(selected.filter(func(w: Worker) -> bool: return world.workers.has(w)))
	if world.waves.wave != _last_wave:
		_last_wave = world.waves.wave
		Sfx.play("wave", -2.0, 1.0)
		Sfx.vibrate(60)
		if WaveManager.is_boss_wave(_last_wave):
			hud.flash("ALERTE : BOSS EN APPROCHE", Ui.RED)
			Sfx.vibrate(150)
		else:
			hud.flash("VAGUE %d EN APPROCHE" % _last_wave, Ui.RED)
	if world.state != GameWorld.State.PLAYING and not _ended:
		_ended = true
		hud.show_end(world.state == GameWorld.State.WON)


# --- Contrôles --------------------------------------------------------------------

func _on_tapped(world_px: Vector2) -> void:
	if paused:
		return
	var p := world_px / TILE
	var c := Vector2i(p.floor())

	if build_kind == "orbital":
		if world.cast_orbital(p):
			set_build_kind("")
		return
	if build_kind != "":
		_try_place(c)
		return

	var w := world.worker_at(p)
	if w != null:
		_set_selection([w])
		return

	var site := world.site_at(c)
	if selected.is_empty():
		if site != null:
			focus_site(site)
			return
		focus_site(null)
		map_view.set_selected(c)
		if world.grid.is_inside(c):
			hud.show_info(GameGrid.CELL_NAMES[world.grid.get_cell(c)])
		return

	if site != null:
		if not site.built:
			world.command_build(selected, site)
		elif site.hp < site.max_hp:
			world.command_repair(selected, site)
			hud.flash("Réparation en cours", Ui.GREEN)
		return
	match world.grid.get_cell(c):
		GameGrid.Cell.METAL, GameGrid.Cell.ESSENCE:
			world.command_harvest(selected, c)
		_:
			world.command_move(selected, c)


func focus_site(s: BuildSite) -> void:
	focused_site = s
	units_view.focused_site = s
	if s != null:
		_set_selection([])
		map_view.set_selected(Vector2i(-1, -1))


func upgrade_focused() -> void:
	var s := focused_site
	if s == null:
		return
	var reason := world.can_upgrade(s)
	if reason != "":
		hud.flash(reason, Ui.RED)
	else:
		world.upgrade(s)
		hud.flash("%s niveau %d" % [s.stats().name, s.level], Ui.GREEN)


func repair_focused() -> void:
	var s := focused_site
	if s == null:
		return
	var crew: Array = []
	for i in 2:
		var w := world.nearest_available_worker(s.cell)
		if w == null:
			break
		world.command_repair([w], s)
		crew.append(w)
	hud.flash("%d ouvrier(s) envoyé(s) en réparation" % crew.size() if not crew.is_empty() else "Aucun ouvrier disponible", Ui.GREEN if not crew.is_empty() else Ui.RED)


func sell_focused() -> void:
	if focused_site == null:
		return
	var refund := focused_site.sell_value()
	world.sell(focused_site)
	hud.flash("Vendu : +%d métal" % refund.metal, Ui.GOLD)
	focus_site(null)


func _try_place(c: Vector2i) -> void:
	var reason := world.can_place(build_kind, c)
	if reason != "":
		hud.flash(reason, Ui.RED)
		return
	var site := world.place(build_kind, c)
	var builders: Array = selected.duplicate()
	if builders.is_empty():
		var nearest := world.nearest_available_worker(c)
		if nearest != null:
			builders.append(nearest)
	world.command_build(builders, site)
	set_build_kind("")


func _on_selection_ended(a: Vector2, b: Vector2) -> void:
	units_view.selection_rect = Rect2()
	_set_selection(world.workers_in_rect(Rect2(a / TILE, (b - a) / TILE).abs()))


func _set_selection(ws: Array) -> void:
	selected.assign(ws)
	if not ws.is_empty() and focused_site != null:
		focused_site = null
		units_view.focused_site = null
	units_view.selected = selected
	map_view.set_selected(Vector2i(-1, -1))


func set_build_kind(kind: String) -> void:
	build_kind = kind
	units_view.show_ranges = kind in Content.TOWERS
	if kind != "":
		focus_site(null)
	hud.refresh_build_buttons()
	if kind == "orbital":
		hud.flash("Touche la zone à frapper", Ui.CYAN)
	elif kind != "":
		hud.flash("Touche une case libre pour construire : %s" % Content.building(kind).name, Ui.CYAN)


func deselect() -> void:
	_set_selection([])


func train_worker() -> void:
	var reason := world.can_train_worker()
	if reason != "":
		hud.flash(reason, Ui.RED)
	else:
		world.train_worker()


func toggle_speed() -> void:
	speed = 2 if speed == 1 else 1


func set_paused(on: bool) -> void:
	paused = on


func _notification(what: int) -> void:
	# Mise en pause automatique quand l'appli passe en arrière-plan sur mobile.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _ended and is_node_ready():
		hud.open_pause()


# --- Fin de partie -------------------------------------------------------------------

## Étoiles : 3 si la base a gardé 70 % de ses PV, 2 au-dessus de 35 %, sinon 1.
func stars() -> int:
	if world.state != GameWorld.State.WON:
		return 0
	var ratio := float(world.base_hp) / world.max_base_hp
	return 3 if ratio >= 0.7 else (2 if ratio >= 0.35 else 1)


## Crédits gagnés, enregistre la progression. À n'appeler qu'une fois par fin.
func grant_rewards() -> int:
	var won := world.state == GameWorld.State.WON
	var waves_done := world.waves.wave if won else maxi(0, world.waves.wave - 1)
	var credits := (waves_done - _granted_waves) * 12 + (world.kills - _granted_kills)
	if won and _granted_waves == 0:
		credits += 80 + stars() * 25
	credits = maxi(0, credits)
	_granted_waves = maxi(_granted_waves, waves_done)
	_granted_kills = world.kills
	Save.add("credits", credits)
	if survival:
		new_record = Save.record_survival(level.id, world.waves.wave)
	elif won:
		Save.record_level(level.id, stars(), world.waves.wave)
	return credits


func restart() -> void:
	Ui.play_level(level.id, survival)


func next_level_id() -> int:
	for l in Content.LEVELS:
		if l.id == level.id + 1:
			return l.id
	return -1


func continue_infinite() -> void:
	_ended = false
	world.continue_infinite()
