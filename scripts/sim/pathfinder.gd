class_name Pathfinder
extends RefCounted
## Recherche de chemin pour les unités au sol (A* natif de Godot, en C++).

const NEIGHBOURS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var grid: GameGrid
var _astar := AStarGrid2D.new()


func _init(g: GameGrid) -> void:
	grid = g
	_astar.region = Rect2i(0, 0, g.width, g.height)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in g.height:
		for x in g.width:
			var c := Vector2i(x, y)
			if not g.is_walkable(c):
				_astar.set_point_solid(c, true)


func set_solid(c: Vector2i, solid: bool) -> void:
	if grid.is_inside(c):
		_astar.set_point_solid(c, solid)


func is_free(c: Vector2i) -> bool:
	return grid.is_inside(c) and not _astar.is_point_solid(c)


## Chemin de case en case. Vide si aucun chemin.
## Fonctionne même si l'unité se trouve sur une case devenue bloquante.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not grid.is_inside(from) or not is_free(to):
		return []
	var was_solid := _astar.is_point_solid(from)
	if was_solid:
		_astar.set_point_solid(from, false)
	var path := _astar.get_id_path(from, to)
	if was_solid:
		_astar.set_point_solid(from, true)
	return path


## Cases libres autour d'un ensemble de cases (gisement, base, chantier).
func free_cells_around(targets: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for t in targets:
		for d in NEIGHBOURS:
			var n := t + d
			if is_free(n) and not result.has(n):
				result.append(n)
	return result


## Chemin le plus court vers une case libre collée à l'une des cibles.
func find_path_to_adjacent(from: Vector2i, targets: Array[Vector2i]) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for n in free_cells_around(targets):
		var p := find_path(from, n)
		if not p.is_empty() and (best.is_empty() or p.size() < best.size()):
			best = p
	return best
