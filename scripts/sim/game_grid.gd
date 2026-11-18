class_name GameGrid
extends RefCounted
## Grille logique de la map.
## Simulation pure : aucune dépendance à l'affichage, pour pouvoir tourner
## plus tard côté serveur en multijoueur.

enum Cell { EMPTY, ROCK, BASE, METAL, ESSENCE, SPAWN }

const CELL_NAMES := {
	Cell.EMPTY: "Terrain libre",
	Cell.ROCK: "Rocher",
	Cell.BASE: "Base",
	Cell.METAL: "Gisement de métal",
	Cell.ESSENCE: "Gisement d'essence",
	Cell.SPAWN: "Point d'apparition ennemi",
}

var width := 0
var height := 0
var base_cells: Array[Vector2i] = []
var spawn_points: Array[Vector2i] = []
var metal_deposits: Array[Vector2i] = []
var essence_deposits: Array[Vector2i] = []

var _cells := PackedByteArray()


func _init(w: int, h: int) -> void:
	width = w
	height = h
	_cells.resize(w * h) # rempli de 0 = Cell.EMPTY


func is_inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func get_cell(c: Vector2i) -> int:
	if not is_inside(c):
		return Cell.ROCK
	return _cells[c.y * width + c.x]


func set_cell(c: Vector2i, type: int) -> void:
	if not is_inside(c):
		return
	_cells[c.y * width + c.x] = type
	match type:
		Cell.BASE:
			base_cells.append(c)
		Cell.SPAWN:
			spawn_points.append(c)
		Cell.METAL:
			metal_deposits.append(c)
		Cell.ESSENCE:
			essence_deposits.append(c)


## Une case où les unités au sol peuvent marcher.
func is_walkable(c: Vector2i) -> bool:
	var t := get_cell(c)
	return t == Cell.EMPTY or t == Cell.SPAWN


## Centre de la base, en coordonnées de cases (fractionnaires).
func get_base_center() -> Vector2:
	if base_cells.is_empty():
		return Vector2(width, height) * 0.5
	var sum := Vector2.ZERO
	for c in base_cells:
		sum += Vector2(c)
	return sum / base_cells.size() + Vector2(0.5, 0.5)
