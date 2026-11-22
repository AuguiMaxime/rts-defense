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
var ground := "grass"
var selected := Vector2i(-1, -1)


func setup(g: GameGrid, ground_kind := "grass") -> void:
	grid = g
	ground = ground_kind
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
			if true:
				var look: Dictionary = Sprites.GROUND_LOOK[ground]
				var shade := 1.0 - (cell_hash(c) % 5) * 0.007
				var gtex: Texture2D = look.tex
				if ground == "mars" and cell_hash(c) % 4 == 0:
					gtex = Sprites.GROUND_MARS2
				draw_texture_rect(gtex, r, false, look.tint * Color(shade, shade, shade))
			match t:
				GameGrid.Cell.ROCK:
					if ground == "mars":
						var mtex := Sprites.ROCK_MARS if cell_hash(c) % 2 == 0 else Sprites.ROCK_MARS2
						draw_texture_rect(mtex, r.grow(4), false)
					else:
						var tex := Sprites.ROCK_BIG if cell_hash(c) % 3 != 0 else Sprites.ROCK_SMALL
						draw_texture_rect(tex, r.grow(6), false)
				GameGrid.Cell.METAL:
					_draw_deposit(r, COLOR_METAL, Sprites.ORE_METAL)
				GameGrid.Cell.ESSENCE:
					_draw_deposit(r, COLOR_ESSENCE, Sprites.ORE_ESSENCE)
				GameGrid.Cell.SPAWN:
					draw_texture_rect(Sprites.SCORCH, r.grow(24), false, Color(1, 1, 1, 0.9))
					draw_arc(r.get_center(), TILE * 0.42, 0, TAU, 40, COLOR_SPAWN, 3.0)
				GameGrid.Cell.EMPTY:
					var h := cell_hash(c)
					if h < 30 and ground == "grass":
						draw_texture_rect(Sprites.BUSH_SMALL, r.grow(-10), false, Color(0.75, 0.85, 0.72, 0.8))
					elif h < 18 and ground == "mars":
						draw_texture_rect(Sprites.PLANT_PURPLE if h % 2 == 0 else Sprites.PLANT_GREEN, r.grow(-14), false, Color(1, 1, 1, 0.85))

	for x in grid.width + 1:
		draw_line(Vector2(x * TILE, 0), Vector2(x * TILE, grid.height * TILE), COLOR_GRID)
	for y in grid.height + 1:
		draw_line(Vector2(0, y * TILE), Vector2(grid.width * TILE, y * TILE), COLOR_GRID)

	_draw_base()

	if grid.is_inside(selected):
		draw_rect(cell_rect(selected).grow(-1), COLOR_SELECT, false, 3.0)


func _draw_deposit(r: Rect2, color: Color, tex: Texture2D) -> void:
	var c := r.get_center()
	draw_circle(c, TILE * 0.48, Color(color, 0.28))
	draw_arc(c, TILE * 0.48, 0, TAU, 28, Color(color, 0.6), 2.0)
	draw_texture_rect(tex, r.grow(2), false)
	draw_circle(c + Vector2(16, -16), 4, color.lightened(0.6))


func _draw_base() -> void:
	if grid.base_cells.is_empty():
		return
	var area := cell_rect(grid.base_cells[0])
	for c in grid.base_cells:
		area = area.merge(cell_rect(c))
	var center := area.get_center()
	draw_arc(center, area.size.x * 0.54, 0, TAU, 64, COLOR_TEAM, 5.0)
	var body := Rect2(center - area.size * 0.52, area.size * 1.04)
	draw_texture_rect(Sprites.W_BASE, Rect2(body.position + Vector2(6, 9), body.size), false, Color(0, 0, 0, 0.35))
	draw_texture_rect(Sprites.W_BASE, body, false)
