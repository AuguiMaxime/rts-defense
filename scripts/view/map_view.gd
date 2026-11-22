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
const WATER_TEX := preload("res://assets/gen/terrain/water.png")
const SHORE_TEX := preload("res://assets/gen/terrain/shore.png")
const ASPHALT_TEX := preload("res://assets/gen/terrain/asphalt.png")
const GRAVEL_TEX := preload("res://assets/gen/terrain/gravel.png")
const RAIL_TEX := preload("res://assets/gen/terrain/rail_straight.png")
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

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
				GameGrid.Cell.WATER:
					_draw_water(c, r)
				GameGrid.Cell.ROAD:
					_draw_road(c, r, false)
				GameGrid.Cell.BRIDGE:
					_draw_water(c, r)
					_draw_road(c, r, true)
				GameGrid.Cell.RAIL:
					_draw_rail(c, r, false)
				GameGrid.Cell.RAIL_BRIDGE:
					_draw_water(c, r)
					_draw_rail(c, r, true)
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


## Morceau d'une texture de 128 px qui se raccorde d'une case à l'autre.
func _tiled(tex: Texture2D, c: Vector2i, r: Rect2, mod := Color(1, 1, 1)) -> void:
	var n := tex.get_width() / 2.0
	draw_texture_rect_region(tex, r, Rect2((c.x % 2) * n, (c.y % 2) * n, n, n), mod)


## Eau + berges (rochers et herbe) du côté des cases de terre.
func _draw_water(c: Vector2i, r: Rect2) -> void:
	_tiled(WATER_TEX, c, r)
	var sw := SHORE_TEX.get_width()
	for i in 4:
		var nb: Vector2i = c + DIRS[i]
		if not grid.is_inside(nb) or grid.is_water(nb):
			continue
		# La bande de berge est verticale, terre à gauche : on la tourne vers le côté terre.
		var ang: float = [PI / 2.0, PI, -PI / 2.0, 0.0][i]
		draw_set_transform(r.get_center(), ang)
		var src_h := sw * 2.4
		var oy := float((cell_hash(c) * 37 + i * 53) % int(SHORE_TEX.get_height() - src_h))
		draw_texture_rect_region(SHORE_TEX, Rect2(-TILE / 2.0, -TILE / 2.0, TILE * 0.32, TILE), Rect2(0, oy, sw, src_h))
		draw_set_transform(Vector2.ZERO)


func _links(c: Vector2i, check: Callable) -> Array[bool]:
	var out: Array[bool] = []
	for d in DIRS:
		var nb: Vector2i = c + d
		out.append(check.call(nb) or (not grid.is_inside(nb) and check.call(c)))
	return out


## Route : asphalte, bordures et lignes jaunes côté fermé, pointillés blancs vers chaque liaison.
func _draw_road(c: Vector2i, r: Rect2, bridge: bool) -> void:
	var l := _links(c, grid.is_road)
	_tiled(ASPHALT_TEX, c, r)
	var ctr := r.get_center()
	for i in 4:
		var ang: float = i * PI / 2.0
		draw_set_transform(ctr, ang)
		if l[i]:
			# pointillé du centre vers ce côté
			draw_line(Vector2(0, -8), Vector2(0, -24), Color(0.95, 0.95, 0.9, 0.85), 3.0)
		else:
			if bridge:
				draw_rect(Rect2(-32, -32, 64, 7), Color(0.16, 0.19, 0.24))
				draw_rect(Rect2(-32, -32, 64, 2), Color(0.45, 0.5, 0.58))
				for k in 3:
					draw_circle(Vector2(-22 + k * 22, -28.5), 2.0, Color(0.3, 0.9, 1.0))
			else:
				draw_rect(Rect2(-32, -32, 64, 4), Color(0.55, 0.56, 0.58))
			draw_line(Vector2(-32 if l[(i + 3) % 4] else -26, -24), Vector2(32 if l[(i + 1) % 4] else 26, -24), Color(0.95, 0.72, 0.15, 0.9), 2.5)
		draw_set_transform(Vector2.ZERO)


## Voie ferrée : ballast + rails. Ligne droite = texture complète ; sinon demi-voies vers chaque liaison.
func _draw_rail(c: Vector2i, r: Rect2, bridge: bool) -> void:
	var l := _links(c, grid.is_rail)
	var ctr := r.get_center()
	if not bridge:
		_tiled(GRAVEL_TEX, c, r, Color(0.9, 0.9, 0.9))
	var tw := RAIL_TEX.get_width()
	var th := RAIL_TEX.get_height()
	if l[0] and l[2] and not l[1] and not l[3]:
		draw_texture_rect(RAIL_TEX, r, false)
	elif l[1] and l[3] and not l[0] and not l[2]:
		draw_set_transform(ctr, PI / 2.0)
		draw_texture_rect(RAIL_TEX, Rect2(-32, -32, 64, 64), false)
		draw_set_transform(Vector2.ZERO)
	else:
		for i in 4:
			if l[i]:
				draw_set_transform(ctr, i * PI / 2.0)
				draw_texture_rect_region(RAIL_TEX, Rect2(-32, -32, 64, 34), Rect2(0, 0, tw, th * 34.0 / 64.0))
				draw_set_transform(Vector2.ZERO)
		draw_circle(ctr, 9, Color(0.35, 0.3, 0.26))
		draw_circle(ctr, 5, Color(0.6, 0.62, 0.66))
	if bridge:
		for i in 4:
			if not l[i]:
				draw_set_transform(ctr, i * PI / 2.0)
				draw_rect(Rect2(-32, -32, 64, 7), Color(0.16, 0.19, 0.24))
				draw_rect(Rect2(-32, -32, 64, 2), Color(0.45, 0.5, 0.58))
				for k in 3:
					draw_circle(Vector2(-22 + k * 22, -28.5), 2.0, Color(0.3, 0.9, 1.0))
				draw_set_transform(Vector2.ZERO)


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
