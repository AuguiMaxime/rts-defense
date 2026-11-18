extends Node2D
## Scène principale d'une partie : charge la map et relie la simulation à l'affichage.

const Map01 := preload("res://maps/map_01.gd")

var grid: GameGrid

@onready var map_view: MapView = $MapView
@onready var camera: CameraController = $Camera
@onready var title_label: Label = $HUD/TitleLabel
@onready var info_label: Label = $HUD/InfoLabel


func _ready() -> void:
	grid = MapLoader.from_layout(Map01.LAYOUT)
	map_view.setup(grid)

	var tile := MapView.TILE
	camera.set_bounds(Rect2(Vector2.ZERO, Vector2(grid.width, grid.height) * tile).grow(tile))
	camera.center_on(grid.get_base_center() * tile)
	camera.tapped.connect(_on_tapped)

	title_label.text = Map01.NAME
	info_label.text = "Touche une case pour l'inspecter"


func _on_tapped(world_pos: Vector2) -> void:
	var c := Vector2i((world_pos / MapView.TILE).floor())
	if not grid.is_inside(c):
		return
	map_view.set_selected(c)
	info_label.text = "%s  (%d, %d)" % [GameGrid.CELL_NAMES[grid.get_cell(c)], c.x, c.y]
