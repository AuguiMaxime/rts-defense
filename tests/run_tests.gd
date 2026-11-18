extends SceneTree
## Tests de la simulation, sans affichage.
## Lancer : godot --headless --script res://tests/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_map_01()
	_test_grid_rules()
	print("RESULTAT : %s" % ("OK" if _failures == 0 else "%d echec(s)" % _failures))
	quit(_failures)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		_failures += 1
		print("  FAIL ", label)


func _test_map_01() -> void:
	print("Map 01")
	var grid := MapLoader.from_layout(preload("res://maps/map_01.gd").LAYOUT)
	_check(grid.width == 48 and grid.height == 30, "taille 48 x 30")
	_check(grid.base_cells.size() == 9, "base de 3 x 3 cases")
	_check(grid.spawn_points.size() == 2, "2 points d'apparition")
	_check(grid.metal_deposits.size() > 0, "gisements de métal présents")
	_check(grid.essence_deposits.size() > 0, "gisements d'essence présents")
	_check(grid.get_base_center().is_equal_approx(Vector2(7.5, 14.5)), "centre de la base en (7.5, 14.5)")


func _test_grid_rules() -> void:
	print("Règles de la grille")
	var grid := MapLoader.from_layout("..#\n.B.\nS..")
	_check(grid.is_walkable(Vector2i(0, 0)), "terrain libre praticable")
	_check(not grid.is_walkable(Vector2i(2, 0)), "rocher bloquant")
	_check(not grid.is_walkable(Vector2i(1, 1)), "base bloquante")
	_check(grid.is_walkable(Vector2i(0, 2)), "point d'apparition praticable")
	_check(not grid.is_walkable(Vector2i(-1, 0)), "hors map bloquant")
