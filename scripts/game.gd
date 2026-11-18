extends Node2D
## Scène principale d'une partie : relie la simulation (GameWorld) à l'affichage et aux contrôles.

const Map01 := preload("res://maps/map_01.gd")
const TILE := MapView.TILE

var world: GameWorld
var selected: Array[Worker] = []
var build_mode := false
var _message_time := 0.0

@onready var map_view: MapView = $MapView
@onready var units_view: UnitsView = $UnitsView
@onready var camera: CameraController = $Camera
@onready var title_label: Label = $HUD/TitleLabel
@onready var resources_label: Label = $HUD/ResourcesLabel
@onready var info_label: Label = $HUD/InfoLabel
@onready var message_label: Label = $HUD/MessageLabel
@onready var worker_button: Button = $HUD/Buttons/WorkerButton
@onready var tower_button: Button = $HUD/Buttons/TowerButton
@onready var deselect_button: Button = $HUD/Buttons/DeselectButton
@onready var wave_label: Label = $HUD/WaveLabel
@onready var next_wave_button: Button = $HUD/NextWaveButton
@onready var end_panel: Control = $HUD/EndPanel
@onready var end_label: Label = $HUD/EndPanel/Box/EndLabel
@onready var end_detail: Label = $HUD/EndPanel/Box/EndDetail
@onready var infinite_button: Button = $HUD/EndPanel/Box/EndButtons/InfiniteButton


func _ready() -> void:
	world = GameWorld.new(MapLoader.from_layout(Map01.LAYOUT))
	map_view.setup(world.grid)
	units_view.world = world

	camera.set_bounds(Rect2(Vector2.ZERO, Vector2(world.grid.width, world.grid.height) * TILE).grow(TILE))
	camera.center_on(world.grid.get_base_center() * TILE)
	camera.is_over_ui = _is_over_ui
	camera.tapped.connect(_on_tapped)
	camera.selection_updated.connect(_on_selection_updated)
	camera.selection_ended.connect(_on_selection_ended)
	camera.selection_cancelled.connect(func() -> void: units_view.selection_rect = Rect2())

	worker_button.pressed.connect(_on_worker_button)
	tower_button.pressed.connect(func() -> void: _set_build_mode(not build_mode))
	deselect_button.pressed.connect(func() -> void: _set_selection([]))
	next_wave_button.pressed.connect(func() -> void: world.waves.start_next())
	$HUD/EndPanel/Box/EndButtons/RestartButton.pressed.connect(func() -> void: get_tree().reload_current_scene())
	infinite_button.pressed.connect(func() -> void:
		world.continue_infinite()
		end_panel.visible = false)

	title_label.text = Map01.NAME
	_update_hud()


func _process(delta: float) -> void:
	world.tick(delta)
	if selected.any(func(w: Worker) -> bool: return not world.workers.has(w)):
		_set_selection(selected.filter(func(w: Worker) -> bool: return world.workers.has(w)))
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			message_label.text = ""
	_update_hud()


# --- Contrôles -----------------------------------------------------------------

func _on_tapped(world_px: Vector2) -> void:
	var p := world_px / TILE
	var c := Vector2i(p.floor())

	if build_mode:
		_try_place_tower(c)
		return

	var w := world.worker_at(p)
	if w != null:
		_set_selection([w])
		return

	if selected.is_empty():
		if world.grid.is_inside(c):
			map_view.set_selected(c)
			info_label.text = "%s  (%d, %d)" % [GameGrid.CELL_NAMES[world.grid.get_cell(c)], c.x, c.y]
		return

	var site := world.site_at(c)
	if site != null and not site.built:
		world.command_build(selected, site)
		return
	match world.grid.get_cell(c):
		GameGrid.Cell.METAL, GameGrid.Cell.ESSENCE:
			world.command_harvest(selected, c)
		_:
			world.command_move(selected, c)


func _try_place_tower(c: Vector2i) -> void:
	var reason := world.can_place_tower(c)
	if reason != "":
		_show_message(reason)
		return
	var site := world.place_tower(c)
	var builders: Array = selected.duplicate()
	if builders.is_empty():
		var nearest := world.nearest_available_worker(c)
		if nearest != null:
			builders.append(nearest)
	world.command_build(builders, site)
	_set_build_mode(false)


func _on_selection_updated(a: Vector2, b: Vector2) -> void:
	units_view.selection_rect = Rect2(a, b - a).abs()


func _on_selection_ended(a: Vector2, b: Vector2) -> void:
	units_view.selection_rect = Rect2()
	var r := Rect2(a / TILE, (b - a) / TILE).abs()
	_set_selection(world.workers_in_rect(r))


func _on_worker_button() -> void:
	if not world.train_worker():
		_show_message("Pas assez de métal (%d)" % Balance.WORKER_COST_METAL)


func _set_selection(ws: Array) -> void:
	selected.assign(ws)
	units_view.selected = selected
	map_view.set_selected(Vector2i(-1, -1))


func _set_build_mode(on: bool) -> void:
	build_mode = on
	tower_button.set_pressed_no_signal(on)
	if on:
		_show_message("Touche une case libre pour poser la tourelle", 3.0)


func _is_over_ui(screen_pos: Vector2) -> bool:
	if end_panel.visible:
		return true
	for b: Button in [worker_button, tower_button, deselect_button, next_wave_button]:
		if b.visible and b.get_global_rect().has_point(screen_pos):
			return true
	return false


# --- Interface -----------------------------------------------------------------

func _show_message(text: String, duration := 2.0) -> void:
	message_label.text = text
	_message_time = duration


func _update_hud() -> void:
	resources_label.text = "Métal %d    Essence %d    Ouvriers %d" % [world.metal, world.essence, world.workers.size()]
	var queue := "  (+%d)" % world.train_queue if world.train_queue > 0 else ""
	worker_button.text = "+ Ouvrier  %d%s" % [Balance.WORKER_COST_METAL, queue]
	tower_button.text = "Tourelle  %d" % Balance.TOWER_COST_METAL
	deselect_button.visible = not selected.is_empty()
	_update_waves()
	if not selected.is_empty():
		info_label.text = "%d ouvrier(s) sélectionné(s) : touche un gisement, un chantier ou le sol" % selected.size()
	elif build_mode:
		info_label.text = "Mode construction"
	elif info_label.text.begins_with("Mode") or info_label.text.contains("sélectionné"):
		info_label.text = "Glisse pour sélectionner des ouvriers"


func _update_waves() -> void:
	var wv := world.waves
	var total := "∞" if wv.infinite else str(wv.total)
	var text := "Vague %d/%s" % [wv.wave, total]
	if wv.has_more_waves():
		text += "  ·  prochaine dans %d s" % ceili(wv.timer)
	text += "  ·  Ennemis %d  ·  Base %d" % [world.enemies.size(), world.base_hp]
	wave_label.text = text
	next_wave_button.visible = wv.has_more_waves()

	if world.state != GameWorld.State.PLAYING and not end_panel.visible:
		end_panel.visible = true
		var won := world.state == GameWorld.State.WON
		end_label.text = "Victoire !" if won else "Défaite"
		end_detail.text = ("Les %d vagues ont été repoussées" % wv.wave) if won else ("Base détruite à la vague %d" % wv.wave)
		infinite_button.visible = won
