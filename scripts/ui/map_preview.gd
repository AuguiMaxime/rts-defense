class_name MapPreview
extends Control
## Miniature d'une map (pour l'écran de campagne).

const GROUND_COLORS := {"grass": Color("1f4d2b"), "sand": Color("6b5236"), "dirt": Color("4a3a34"), "mars": Color("9a5238"), "metal": Color("3a4250")}

var grid: GameGrid
var ground := "grass"
var locked := false


func _draw() -> void:
	if grid == null:
		return
	var cell := minf(size.x / grid.width, size.y / grid.height)
	var origin := (size - Vector2(grid.width, grid.height) * cell) / 2.0
	draw_rect(Rect2(origin, Vector2(grid.width, grid.height) * cell), GROUND_COLORS.get(ground, Color("1f4d2b")))
	for y in grid.height:
		for x in grid.width:
			var col := Color(0, 0, 0, 0)
			match grid.get_cell(Vector2i(x, y)):
				GameGrid.Cell.ROCK:
					col = Color("8a8f98")
				GameGrid.Cell.BASE:
					col = Ui.CYAN
				GameGrid.Cell.METAL:
					col = Ui.METAL
				GameGrid.Cell.ESSENCE:
					col = Ui.ESSENCE
				GameGrid.Cell.SPAWN:
					col = Ui.RED
				GameGrid.Cell.WALL:
					col = Color("5a6270")
				GameGrid.Cell.WATER:
					col = Color("1e6fa8")
				GameGrid.Cell.ROAD, GameGrid.Cell.BRIDGE:
					col = Color("2e3238")
				GameGrid.Cell.RAIL, GameGrid.Cell.RAIL_BRIDGE:
					col = Color("6b5a48")
			if col.a > 0:
				draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), col)
	draw_rect(Rect2(origin, Vector2(grid.width, grid.height) * cell), Color(Ui.CYAN, 0.5), false, 2.0)
	if locked:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Ui.BG, 0.75))
