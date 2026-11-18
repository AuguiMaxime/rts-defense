class_name MapView
extends Node2D
## Affiche la grille : sol, rochers, gisements, base, points d'apparition.
## Le décor est statique, il n'est redessiné que si la map ou la sélection change.

const TILE := 64

const COLOR_GROUND := Color(0.19, 0.25, 0.17)
const COLOR_GRID := Color(1, 1, 1, 0.05)
const COLOR_ROCK := Color(0.36, 0.34, 0.31)
const COLOR_ROCK_EDGE := Color(0.25, 0.23, 0.21)
const COLOR_METAL := Color(0.66, 0.74, 0.84)
const COLOR_ESSENCE := Color(0.96, 0.62, 0.16)
const COLOR_SPAWN := Color(0.86, 0.22, 0.22, 0.55)
const COLOR_BASE := Color(0.26, 0.56, 1.0)
const COLOR_SELECT := Color(1, 1, 1, 0.9)

var grid: GameGrid
var selected := Vector2i(-1, -1)


func setup(g: GameGrid) -> void:
	grid = g
	queue_redraw()


func set_selected(c: Vector2i) -> void:
	selected = c
	queue_redraw()


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c) * TILE, Vector2(TILE, TILE))


func _draw() -> void:
	if grid == null:
		return
	var map_size := Vector2(grid.width, grid.height) * TILE
	draw_rect(Rect2(Vector2.ZERO, map_size), COLOR_GROUND)

	for x in grid.width + 1:
		draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, map_size.y), COLOR_GRID)
	for y in grid.height + 1:
		draw_line(Vector2(0, y * TILE), Vector2(map_size.x, y * TILE), COLOR_GRID)

	for y in grid.height:
		for x in grid.width:
			var c := Vector2i(x, y)
			var r := cell_rect(c)
			match grid.get_cell(c):
				GameGrid.Cell.ROCK:
					draw_rect(r.grow(-2), COLOR_ROCK)
					draw_rect(r.grow(-2), COLOR_ROCK_EDGE, false, 3.0)
				GameGrid.Cell.METAL:
					_draw_deposit(r, COLOR_METAL)
				GameGrid.Cell.ESSENCE:
					_draw_deposit(r, COLOR_ESSENCE)
				GameGrid.Cell.SPAWN:
					draw_circle(r.get_center(), TILE * 0.45, COLOR_SPAWN)
					draw_arc(r.get_center(), TILE * 0.45, 0, TAU, 32, Color(1, 0.3, 0.3), 3.0)

	_draw_base()

	if grid.is_inside(selected):
		draw_rect(cell_rect(selected).grow(-1), COLOR_SELECT, false, 3.0)


func _draw_deposit(r: Rect2, color: Color) -> void:
	var c := r.get_center()
	draw_circle(c + Vector2(-12, 8), 12, color.darkened(0.25))
	draw_circle(c + Vector2(12, 6), 10, color.darkened(0.1))
	draw_circle(c + Vector2(0, -10), 14, color)


func _draw_base() -> void:
	if grid.base_cells.is_empty():
		return
	var area := cell_rect(grid.base_cells[0])
	for c in grid.base_cells:
		area = area.merge(cell_rect(c))
	area = area.grow(-6)
	draw_rect(area, COLOR_BASE.darkened(0.55))
	draw_rect(area, COLOR_BASE, false, 5.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(area.position.x, area.get_center().y + 10), "BASE",
			HORIZONTAL_ALIGNMENT_CENTER, area.size.x, 30, Color.WHITE)
