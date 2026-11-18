extends SceneTree
## Tests de la simulation, sans affichage.
## Lancer : godot --headless --script res://tests/run_tests.gd

var _failures := 0


func _init() -> void:
	_test_map_01()
	_test_grid_rules()
	_test_harvest()
	_test_build_speed()
	_test_anti_block()
	_test_worker_training()
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


const TEST_MAP := """
S....#....
.....#....
..........
.....#.BBB
.....#.BBB
.M...#.BBB
"""


func _run(world: GameWorld, seconds: float, step := 0.05) -> void:
	var t := 0.0
	while t < seconds:
		world.tick(step)
		t += step


func _test_harvest() -> void:
	print("Récolte")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	var start := world.metal
	world.command_harvest([world.workers[0]], Vector2i(1, 5))
	_check(world.workers[0].state == Worker.State.MOVING, "l'ouvrier part vers le gisement")
	_run(world, 30.0)
	_check(world.metal >= start + Balance.CARRY_CAPACITY * 2, "au moins 2 voyages en 30 s (+%d métal)" % (world.metal - start))
	_check(world.workers[0].job == Worker.Job.HARVEST, "l'ouvrier continue de récolter en boucle")


func _time_to_build(n_workers: int) -> float:
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.metal = 1000
	var site := world.place_tower(Vector2i(6, 1))
	world.command_build(world.workers.slice(0, n_workers), site)
	var t := 0.0
	while not site.built and t < 60.0:
		world.tick(0.05)
		t += 0.05
	return t


func _test_build_speed() -> void:
	print("Construction")
	var t1 := _time_to_build(1)
	var t2 := _time_to_build(2)
	_check(t1 < 60.0, "1 ouvrier finit la tourelle (%.1f s)" % t1)
	_check(t2 < t1 - Balance.TOWER_BUILD_WORK * 0.4, "2 ouvriers vont nettement plus vite (%.1f s)" % t2)


func _test_anti_block() -> void:
	print("Anti-blocage")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.metal = 1000
	_check(world.can_place_tower(Vector2i(5, 2)) != "", "boucher le seul passage est refusé")
	_check(world.can_place_tower(Vector2i(2, 2)) == "", "une case libre ailleurs est acceptée")
	_check(world.can_place_tower(Vector2i(5, 0)) != "", "un rocher est refusé")
	world.metal = 0
	_check(world.can_place_tower(Vector2i(2, 2)) != "", "sans métal, refusé")


func _test_worker_training() -> void:
	print("Production d'ouvriers")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	var n := world.workers.size()
	_check(world.train_worker(), "achat d'un ouvrier")
	_check(world.metal == Balance.START_METAL - Balance.WORKER_COST_METAL, "métal débité")
	_run(world, Balance.WORKER_TRAIN_TIME + 0.2)
	_check(world.workers.size() == n + 1, "l'ouvrier apparaît après le temps de formation")
