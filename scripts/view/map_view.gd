class_name MapView
extends Node2D
## Affiche le décor : sol, rochers, gisements, base, points d'apparition.
## Statique : redessiné seulement quand la map ou la sélection de case change.

const TILE := 64

const COLOR_GRID := Color(0, 0, 0, 0.07)
const GRASS_TINT := Color(0.44, 0.58, 0.44)
const COLOR_METAL := Color(0.62, 0.80, 1.0)
const COLOR_ESSENCE := Color(1.0, 0.62, 0.18)
const COLOR_TEAM := Color(0.30, 0.62, 1.0)
const COLOR_SPAWN := Color(1.0, 0.30, 0.25)
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


## Petit hasard déterministe par case, pour varier le décor sans changer à chaque partie.
static func cell_hash(c: Vector2i) -> int:
	return absi((c.x * 73856093) ^ (c.y * 19349663)) % 1000


func _draw() -> void:
	if grid == null:
		return
	for y in grid.height:
		for x in grid.width:
			var c := Vector2i(x, y)
			var r := cell_rect(c)
			var t := grid.get_cell(c)
			if t == GameGrid.Cell.BASE:
				draw_texture_rect(Sprites.STONE, r, false)
			else:
				var shade := 1.0 - (cell_hash(c) % 5) * 0.007
				draw_texture_rect(Sprites.GRASS, r, false, GRASS_TINT * Color(shade, shade, shade))
			match t:
				GameGrid.Cell.ROCK:
					var tex := Sprites.ROCK_BIG if cell_hash(c) % 3 != 0 else Sprites.ROCK_SMALL
					draw_texture_rect(tex, r.grow(6), false)
				GameGrid.Cell.METAL:
					_draw_deposit(r, COLOR_METAL)
				GameGrid.Cell.ESSENCE:
					_draw_deposit(r, COLOR_ESSENCE)
				GameGrid.Cell.SPAWN:
					draw_texture_rect(Sprites.SCORCH, r.grow(24), false, Color(1, 1, 1, 0.9))
					draw_arc(r.get_center(), TILE * 0.42, 0, TAU, 40, COLOR_SPAWN, 3.0)
				GameGrid.Cell.EMPTY:
					var h := cell_hash(c)
					if h < 30:
						draw_texture_rect(Sprites.BUSH_SMALL, r.grow(-10), false, Color(0.75, 0.85, 0.72, 0.8))

	for x in grid.width + 1:
		draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, grid.height * TILE), COLOR_GRID)
	for y in grid.height + 1:
		draw_line(Vector2(0, y * TILE), Vector2(grid.width * TILE, y * TILE), COLOR_GRID)

	_draw_base()

	if grid.is_inside(selected):
		draw_rect(cell_rect(selected).grow(-1), COLOR_SELECT, false, 3.0)


func _draw_deposit(r: Rect2, color: Color) -> void:
	var c := r.get_center()
	draw_circle(c, TILE * 0.46, Color(color, 0.30))
	draw_texture_rect(Sprites.ORE, r.grow(4), false, color.lightened(0.2))
	draw_circle(c + Vector2(14, -14), 5, color.lightened(0.5))


func _draw_base() -> void:
	if grid.base_cells.is_empty():
		return
	var area := cell_rect(grid.base_cells[0])
	for c in grid.base_cells:
		area = area.merge(cell_rect(c))
	var center := area.get_center()
	draw_arc(center, area.size.x * 0.52, 0, TAU, 64, COLOR_TEAM, 5.0)
	var plate := Rect2(center - area.size * 0.45, area.size * 0.9)
	draw_texture_rect(Sprites.TOWER_BASE, plate, false)
	var core := Rect2(center - area.size * 0.32, area.size * 0.64)
	draw_texture_rect(Sprites.BASE_CORE, core, false, Color(0.75, 0.88, 1.0))
