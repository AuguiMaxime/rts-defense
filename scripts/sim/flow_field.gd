class_name FlowField
extends RefCounted
## Champ de direction vers la base, partagé par tous les ennemis au sol.
## Un seul calcul pour toute la map, refait quand une tourelle apparaît ou disparaît.

const UNREACHABLE := 1.0e9
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var grid: GameGrid
var pathfinder: Pathfinder
var _dist := PackedFloat32Array()
var _next := PackedInt32Array() # index dans DIRS, -1 = déjà au contact de la base


func _init(g: GameGrid, pf: Pathfinder) -> void:
	grid = g
	pathfinder = pf
	_dist.resize(g.width * g.height)
	_next.resize(g.width * g.height)


## goals : cases d'arrivée (par défaut, les cases collées à la base).
func rebuild(goals: Array[Vector2i] = []) -> void:
	_dist.fill(UNREACHABLE)
	_next.fill(-1)
	# Parcours en largeur depuis les cases d'arrivée (coût 1 par case).
	var frontier: Array[Vector2i] = []
	if goals.is_empty():
		goals = pathfinder.free_cells_around(grid.base_cells)
	for c in goals:
		if not grid.is_inside(c) or _dist[_idx(c)] == 0.0:
			continue
		_dist[_idx(c)] = 0.0
		frontier.append(c)
	var head := 0
	while head < frontier.size():
		var c := frontier[head]
		head += 1
		var d := _dist[_idx(c)] + 1.0
		for k in 4:
			var n := c + DIRS[k]
			if pathfinder.is_free(n) and _dist[_idx(n)] > d:
				_dist[_idx(n)] = d
				frontier.append(n)
	# Direction : la voisine la plus proche de la base (diagonale seulement si les deux côtés sont libres).
	for y in grid.height:
		for x in grid.width:
			var c := Vector2i(x, y)
			var i := _idx(c)
			if _dist[i] == 0.0:
				continue
			var best := _dist[i] if pathfinder.is_free(c) else UNREACHABLE
			for k in DIRS.size():
				var dv := DIRS[k]
				var n := c + dv
				if not pathfinder.is_free(n):
					continue
				if k >= 4 and not (pathfinder.is_free(c + Vector2i(dv.x, 0)) and pathfinder.is_free(c + Vector2i(0, dv.y))):
					continue
				var nd := _dist[_idx(n)] + (0.4 if k >= 4 else 0.0)
				if nd < best:
					best = nd
					_next[i] = k


func distance_at(c: Vector2i) -> float:
	return _dist[_idx(c)] if grid.is_inside(c) else UNREACHABLE


## Direction normalisée à suivre depuis une position, ou ZERO si au contact de la base / bloqué.
func direction_at(p: Vector2) -> Vector2:
	var c := Vector2i(p.floor())
	if not grid.is_inside(c):
		return Vector2.ZERO
	var k := _next[_idx(c)]
	if k < 0:
		return Vector2.ZERO
	var target := Vector2(c + DIRS[k]) + Vector2(0.5, 0.5)
	return (target - p).normalized()


func _idx(c: Vector2i) -> int:
	return c.y * grid.width + c.x
