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
	_test_flow_field()
	_test_enemy_reaches_base()
	_test_tower_kills()
	_test_destroyed_tower_reopens()
	_test_defeat()
	_test_wave_composition()
	_test_map01_full_run()
	_test_tower_types()
	_test_house_and_pop()
	_test_repair()
	_test_orbital()
	_test_all_maps()
	_test_config_bonuses()
	_test_upgrade_sell()
	_test_resume_harvest()
	_test_boss()
	_test_stats()
	_test_production_queue()
	_test_rally()
	_test_units_combat()
	_test_buildings_2x2()
	_test_auto_repair()
	_test_map_data()
	_test_idle_assist()
	_test_abilities()
	_test_new_towers()
	_test_attack_move()
	_test_finite_deposits()
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
	world.command_harvest(world.workers.slice(n_workers), Vector2i(1, 5)) # pas d'aide automatique
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


func _test_flow_field() -> void:
	print("Flow field")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.tick(0.01)
	_check(world.flow.distance_at(Vector2i(0, 0)) < FlowField.UNREACHABLE, "le spawn a un chemin vers la base")
	var p := Vector2(0.5, 0.5)
	for i in 400:
		var d := world.flow.direction_at(p)
		if d == Vector2.ZERO:
			break
		p += d * 0.1
	_check(GameWorld._dist_to_rect(p, Rect2(7, 3, 3, 3)) < 1.6, "en suivant le champ on arrive au contact de la base")


func _test_enemy_reaches_base() -> void:
	print("Ennemis")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.spawn_enemy("normal", Vector2i(0, 0), 1.0)
	world.command_harvest(world.workers, Vector2i(1, 5)) # sinon les inactifs réparent la base
	_run(world, 25.0)
	_check(world.base_hp < Balance.BASE_HP, "un ennemi au sol atteint la base et l'attaque (%d PV)" % world.base_hp)
	var world2 := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world2.waves.timer = 9999
	world2.workers.clear()
	world2.spawn_enemy("flying", Vector2i(0, 0), 1.0)
	_run(world2, 10.0)
	_check(world2.base_hp < Balance.BASE_HP, "un volant va droit sur la base")


func _test_tower_kills() -> void:
	print("Tourelles")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.metal = 1000
	var s := world.place_tower(Vector2i(3, 1))
	s.work_done = s.work_needed
	s.built = true
	s.hp = s.max_hp
	world.spawn_enemy("normal", Vector2i(0, 0), 1.0)
	_run(world, 8.0)
	_check(world.enemies.is_empty(), "la tourelle tue un ennemi normal")
	_check(world.base_hp == Balance.BASE_HP, "la base n'a rien pris")
	world.spawn_enemy("armored", Vector2i(0, 0), 1.0)
	var e: Enemy = world.enemies[0]
	world._damage_enemy(e, Balance.TOWER_DAMAGE)
	_check(e.max_hp - e.hp == Balance.TOWER_DAMAGE - e.armor, "l'armure réduit les dégâts")


func _test_destroyed_tower_reopens() -> void:
	print("Destruction")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.metal = 1000
	var s := world.place_tower(Vector2i(2, 2))
	world.tick(0.01)
	s.hp = 0
	world.tick(0.01)
	_check(not world.sites.has(s), "un chantier à 0 PV disparaît")
	_check(world.pathfinder.is_free(Vector2i(2, 2)), "sa case redevient praticable")
	var w := world.workers[0]
	w.hp = 0
	world.tick(0.01)
	_check(not world.workers.has(w), "un ouvrier à 0 PV disparaît")


func _test_defeat() -> void:
	print("Défaite et victoire")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.base_hp = 1
	world.waves.timer = 9999
	world.workers.clear()
	world.spawn_enemy("normal", Vector2i(6, 2), 1.0)
	_run(world, 5.0)
	_check(world.state == GameWorld.State.LOST, "base détruite = défaite")
	var world2 := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world2.waves.wave = world2.waves.total
	world2.tick(0.01)
	_check(world2.state == GameWorld.State.WON, "toutes les waves passées et plus d'ennemis = victoire")
	world2.continue_infinite()
	_check(world2.state == GameWorld.State.PLAYING and world2.waves.has_more_waves(), "le mode infini relance les waves")


func _test_wave_composition() -> void:
	print("Composition des waves")
	_check(WaveManager.composition(1).size() == 4, "wave 1 : 4 ennemis")
	_check(not WaveManager.composition(3).has("armored"), "pas de blindé avant la wave 4")
	_check(WaveManager.composition(4).has("armored"), "blindés dès la wave 4")
	_check(WaveManager.composition(5).has("flying"), "volants dès la wave 5")


## Partie complète sans aucune défense : la base doit tomber, et sans planter.
func _test_map01_full_run() -> void:
	print("Map 1 sans défense")
	var world := GameWorld.new(MapLoader.from_layout(preload("res://maps/map_01.gd").LAYOUT))
	var t := 0.0
	while world.state == GameWorld.State.PLAYING and t < 900.0:
		world.tick(0.05)
		t += 0.05
	_check(world.state == GameWorld.State.LOST, "sans tourelle, la base tombe (vague %d, %.0f s)" % [world.waves.wave, t])


func _built(world: GameWorld, kind: String, c: Vector2i) -> BuildSite:
	world.metal = 9999
	world.essence = 9999
	var s := world.place(kind, c)
	s.work_done = s.work_needed
	world._finish_site(s)
	return s


func _test_tower_types() -> void:
	print("Types de tourelles")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.workers.clear()
	_built(world, "missile", Vector2i(3, 1))
	world.spawn_enemy("normal", Vector2i(0, 0), 1.0)
	_run(world, 2.0)
	_check(world.enemies.size() == 1 and world.enemies[0].hp == world.enemies[0].max_hp, "l'anti-air ignore les ennemis au sol")
	world.enemies.clear()
	world.spawn_enemy("flying", Vector2i(0, 0), 1.0)
	_run(world, 1.5)
	_check(world.enemies.is_empty() or world.enemies[0].hp < world.enemies[0].max_hp, "l'anti-air touche les volants")
	var w2 := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	w2.waves.timer = 9999
	w2.workers.clear()
	_built(w2, "cannon", Vector2i(3, 1))
	for i in 3:
		w2.spawn_enemy("normal", Vector2i(0, 0), 1.0)
	w2.tick(0.01)
	for e in w2.enemies:
		e.pos = Vector2(1.5, 1.5)
	w2.tick(0.05)
	var hit := w2.enemies.filter(func(e: Enemy) -> bool: return e.hp < e.max_hp).size()
	_check(hit >= 2 or w2.enemies.size() < 3, "le canon fait des dégâts de zone (%d touchés)" % hit)
	var w3 := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	w3.metal = 9999
	w3.essence = 9999
	_check(w3.can_place("laser", Vector2i(2, 2)) != "", "le laser est verrouillé sans achat")
	var w4 := GameWorld.new(MapLoader.from_layout(TEST_MAP), {"laser": true})
	w4.metal = 9999
	w4.essence = 9999
	_check(w4.can_place("laser", Vector2i(2, 2)) == "", "le laser se pose une fois débloqué")
	var w5 := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	w5.metal = 9999
	w5.essence = 0
	_check(w5.can_place("cannon", Vector2i(2, 2)).contains("essence"), "le canon demande de l'essence")


func _test_house_and_pop() -> void:
	print("Habitats et population")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.metal = 9999
	world.waves.timer = 9999
	for i in Content.BASE_POP - world.workers.size():
		world.train_worker()
		_run(world, Balance.WORKER_TRAIN_TIME + 0.1)
	_check(world.can_train_worker().contains("Population"), "population max bloque la formation")
	_built(world, "house", Vector2i(2, 2))
	_check(world.pop_cap == Content.BASE_POP + Content.HOUSE.pop, "un habitat ajoute +3")
	_check(world.can_train_worker() == "", "on peut de nouveau former")


func _test_repair() -> void:
	print("Réparation")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	var s := _built(world, "gun", Vector2i(6, 1))
	s.hp = 50
	world.command_repair([world.workers[0]], s)
	_run(world, 20.0)
	_check(s.hp == s.max_hp, "l'ouvrier répare la tourelle jusqu'au max")
	_check(world.workers[0].state == Worker.State.IDLE, "puis il s'arrête")


func _test_orbital() -> void:
	print("Frappe orbitale")
	var locked := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	_check(not locked.orbital_unlocked(), "verrouillée sans la techno")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP), {"orbital": true})
	world.waves.timer = 9999
	world.spawn_enemy("normal", Vector2i(0, 0), 1.0)
	_check(world.cast_orbital(world.enemies[0].pos), "elle se lance")
	world.tick(0.01)
	_check(world.enemies.is_empty(), "elle tue un ennemi normal")
	_check(not world.orbital_ready(), "puis elle recharge")


func _test_all_maps() -> void:
	print("Toutes les maps")
	for l in Content.LEVELS:
		var map := MapData.load_from(l.map)
		var world := GameWorld.new(MapLoader.from_layout(map.LAYOUT), {"waves": l.waves})
		_check(world.grid.base_cells.size() == 9 and world.enemies_can_reach_base() and world.workers.size() == 3,
				"map %d « %s » valide (%d spawns)" % [l.id, map.NAME, world.grid.spawn_points.size()])


func _test_config_bonuses() -> void:
	print("Bonus de progression")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP), {"start_metal": 400, "start_workers": 5, "base_hp": 1500, "carry_bonus": 2})
	_check(world.metal == 400 and world.workers.size() == 5 and world.base_hp == 1500, "métal, ouvriers et PV de départ")
	world.command_harvest([world.workers[0]], Vector2i(1, 5))
	_run(world, 30.0)
	_check((world.metal - 400) % (Balance.CARRY_CAPACITY + 2) == 0 and world.metal > 400, "charge des ouvriers augmentée")


func _test_upgrade_sell() -> void:
	print("Amélioration et vente")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	var s := _built(world, "gun", Vector2i(2, 2))
	world.metal = 1000
	var dmg1: int = s.stats().damage
	_check(world.upgrade(s) and s.level == 2, "amélioration au niveau 2")
	_check(s.stats().damage > dmg1 and s.max_hp > Content.TOWERS.gun.hp, "dégâts et PV augmentés")
	world.upgrade(s)
	_check(world.can_upgrade(s) == "Niveau maximum", "niveau 3 maximum")
	var before := world.metal
	var refund: int = s.sell_value().metal
	world.sell(s)
	_check(not world.sites.has(s) and world.metal == before + refund and refund > 0, "vente : +%d métal" % refund)
	_check(world.pathfinder.is_free(Vector2i(2, 2)), "la case se libère")
	var site := world.place("gun", Vector2i(3, 3))
	var m := world.metal
	world.sell(site)
	_check(world.metal == m + Content.TOWERS.gun.metal, "chantier pas commencé remboursé à 100 %")


func _test_resume_harvest() -> void:
	print("Retour à la récolte")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	var w := world.workers[0]
	world.command_harvest([w], Vector2i(1, 5))
	world.metal = 1000
	var s := world.place("gun", Vector2i(3, 3))
	world.command_build([w], s)
	_run(world, 20.0)
	_check(s.built, "chantier fini")
	_check(w.job == Worker.Job.HARVEST, "l'ouvrier retourne à son gisement tout seul")


func _test_boss() -> void:
	print("Boss")
	_check(WaveManager.composition(5).has("boss") and not WaveManager.composition(4).has("boss"), "boss à la vague 5, pas à la 4")
	var wm := WaveManager.new()
	wm.difficulty = 0.5
	wm.wave = 4
	wm.start_next()
	_check(wm._queue.back() == "boss", "le boss arrive en dernier et n'est pas retiré par la difficulté")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.spawn_enemy("boss", Vector2i(0, 0), 1.0)
	_check(world.boss() != null, "boss repéré pour la barre de vie")


func _test_stats() -> void:
	print("Compteurs de partie (missions)")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	var s := _built(world, "gun", Vector2i(2, 2))
	_built(world, "house", Vector2i(3, 3))
	world.upgrade(s)
	world.train_worker()
	world.spawn_enemy("boss", Vector2i(0, 0), 1.0)
	world._damage_enemy(world.enemies[0], 99999)
	world.command_harvest([world.workers[0]], Vector2i(1, 5))
	_run(world, 15.0)
	var st := world.stats
	_check(st.towers_built == 1 and st.houses_built == 1 and st.upgrades == 1, "tourelles, habitats, améliorations comptés")
	_check(st.workers_trained == 1 and st.boss_kills == 1 and st.metal_harvested > 0, "ouvriers, boss et métal récolté comptés")


func _test_production_queue() -> void:
	print("File de production")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.metal = 1000
	world.waves.timer = 9999
	for i in 5:
		world.queue_unit(GameWorld.BASE_ID, "worker")
	_check(world.can_queue(GameWorld.BASE_ID, "worker").contains("File pleine"), "file limitée à 5")
	var m := world.metal
	world.cancel_queue(GameWorld.BASE_ID, 4)
	_check(world.metal == m + 50 and world.train_queue == 4, "annulation remboursée")
	_check(world.base_producer.ratio() == 0.0, "progression à zéro au départ")
	world.tick(1.0)
	_check(world.base_producer.ratio() > 0.2, "la barre de progression avance")
	var n := world.workers.size()
	_run(world, 4.0 * 4 + 0.5)
	_check(world.workers.size() == n + 4 and world.train_queue == 0, "les 4 ouvriers sortent l'un après l'autre")
	world.queue_unit(GameWorld.BASE_ID, "soldier")
	_run(world, 5.2)
	_check(world.units.size() == 1 and world.units[0].type == "soldier", "la base forme un soldat")


func _test_rally() -> void:
	print("Point de ralliement")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.set_rally(GameWorld.BASE_ID, Vector2i(1, 5))
	world.queue_unit(GameWorld.BASE_ID, "worker")
	_run(world, 4.1)
	var w := world.workers.back() as Worker
	_check(w.job == Worker.Job.HARVEST and w.target_deposit == Vector2i(1, 5), "ralliement sur un minerai : le nouvel ouvrier récolte")
	world.set_rally(GameWorld.BASE_ID, Vector2i(2, 1))
	world.queue_unit(GameWorld.BASE_ID, "soldier")
	_run(world, 12.0)
	_check(world.units[0].pos.distance_to(Vector2(2.5, 1.5)) < 1.0, "ralliement sur le sol : le soldat y va")


func _test_units_combat() -> void:
	print("Unités de combat")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.workers.clear()
	world.metal = 1000
	world.queue_unit(GameWorld.BASE_ID, "soldier")
	world.queue_unit(GameWorld.BASE_ID, "soldier")
	_run(world, 10.5)
	world.command_units_move(world.units, Vector2i(4, 2))
	_run(world, 4.0)
	world.spawn_enemy("normal", Vector2i(0, 0), 1.0)
	_run(world, 12.0)
	_check(world.enemies.is_empty() and world.kills == 1, "les soldats en garde abattent l'ennemi qui approche")
	world.spawn_enemy("normal", Vector2i(0, 0), 1.0)
	world.command_units_attack(world.units, world.enemies[0])
	_check(world.units[0].order == Unit.Order.ATTACK, "ordre d'attaque sur une cible")
	_run(world, 12.0)
	_check(world.kills == 2, "les soldats poursuivent et détruisent la cible")
	var aa := Unit.create("aa_mech", Vector2(3.5, 3.5))
	world.units.append(aa)
	world.spawn_enemy("normal", Vector2i(0, 0), 1.0)
	world.command_units_attack([aa], world.enemies[0])
	_check(aa.order != Unit.Order.ATTACK, "le mécha anti-air refuse une cible au sol")


func _test_buildings_2x2() -> void:
	print("Caserne et usine (2x2)")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.metal = 5000
	world.essence = 5000
	_check(world.can_place("barracks", Vector2i(4, 0)) != "", "une caserne ne peut pas chevaucher un rocher")
	var b := _built(world, "barracks", Vector2i(1, 1))
	_check(b.size == 2 and not world.pathfinder.is_free(Vector2i(2, 2)) and world.site_at(Vector2i(2, 2)) == b, "la caserne occupe 4 cases")
	_check(b.producer != null, "la caserne a une file de production")
	_check(world.can_queue(b.id, "tank") != "", "la caserne ne forme pas de char")
	world.queue_unit(b.id, "grenadier")
	_run(world, 7.5)
	_check(world.units.size() == 1 and world.units[0].type == "grenadier", "la caserne forme un grenadier")
	world.sell(b)
	_check(world.pathfinder.is_free(Vector2i(2, 2)), "vendue : ses 4 cases se libèrent")


func _test_auto_repair() -> void:
	print("Réparation automatique")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	var s := _built(world, "gun", Vector2i(6, 1))
	s.hp = 40
	var w := world.workers[0]
	world.command_harvest([w], Vector2i(1, 5))
	world.set_auto_repair([w], true)
	_run(world, 25.0)
	_check(s.hp == s.max_hp, "l'ouvrier en réparation auto répare la tourelle abîmée")
	_check(w.job == Worker.Job.HARVEST, "puis il retourne récolter")
	world.base_hp = 500
	_run(world, 60.0)
	_check(world.base_hp > 900, "il répare aussi la base (%d PV)" % world.base_hp)


func _test_map_data() -> void:
	print("Cartes de l'éditeur")
	for l in Content.LEVELS:
		var md := MapData.load_from(l.map)
		_check(MapData.validate(MapLoader.from_layout(md.LAYOUT)).is_empty(), "carte intégrée « %s » valide" % md.NAME)
	var m := MapData.new()
	m.NAME = "Test éditeur"
	m.LAYOUT = TEST_MAP
	m.waves = 7
	m.difficulty = 1.3
	var p := "user://_test_map.json"
	_check(m.save_to(p) == OK, "enregistrement JSON")
	var back := MapData.load_from(p)
	_check(back.NAME == "Test éditeur" and back.waves == 7 and is_equal_approx(back.difficulty, 1.3), "relecture des réglages")
	_check(MapData.from_grid(MapLoader.from_layout(back.LAYOUT)) == MapData.from_grid(MapLoader.from_layout(TEST_MAP)), "plan identique")
	DirAccess.remove_absolute(p)
	var closed := MapLoader.from_layout("#####\n#B.S#\n#####")
	_check(not MapData.validate(closed).is_empty(), "carte invalide détectée")


func _test_idle_assist() -> void:
	print("Ouvriers inactifs")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.metal = 1000
	_check(world.idle_workers().size() == world.workers.size(), "au départ, tous les ouvriers sont inactifs")
	var site := world.place_tower(Vector2i(6, 1))
	_run(world, 20.0)
	_check(site.built, "les inactifs construisent seuls le chantier en attente")
	site.hp = 30
	_run(world, 20.0)
	_check(site.hp == site.max_hp, "puis réparent seuls le bâtiment endommagé")
	world.base_hp = 700
	_run(world, 30.0)
	_check(world.base_hp > 700, "et la base aussi")
	world.command_harvest(world.workers, Vector2i(1, 5))
	_run(world, 2.0)
	_check(world.idle_workers().is_empty(), "un ouvrier qui récolte n'est pas inactif")


func _add_unit(world: GameWorld, type_name: String, at: Vector2) -> Unit:
	var u := Unit.create(type_name, at)
	u.id = world._next_unit_id
	world._next_unit_id += 1
	world.units.append(u)
	return u


func _test_abilities() -> void:
	print("Pouvoirs des unités")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.workers.clear()
	var sol := _add_unit(world, "soldier", Vector2(2.5, 2.5))
	var base_dmg: int = sol.eff().damage
	_check(world.use_ability([sol], "stim") == 1, "stimulant activé")
	_check(sol.eff().damage > base_dmg and sol.eff().speed > sol.stats().speed, "+dégâts et +vitesse")
	_check(world.use_ability([sol], "stim") == 0, "pas de relance pendant la recharge")
	_run(world, 6.0)
	_check(sol.eff().damage == base_dmg, "effet terminé après 5 s")
	var gre := _add_unit(world, "grenadier", Vector2(3.5, 2.5))
	world.use_ability([gre], "bastion")
	_check(gre.max_hp > int(gre.stats().hp) and int(gre.eff().armor) == int(gre.stats().armor) + 4, "bastion : PV max et armure")
	_run(world, 6.0)
	_check(gre.max_hp == int(gre.stats().hp) and gre.hp <= gre.max_hp, "bastion terminé, PV ramenés au max")
	var tank := _add_unit(world, "tank", Vector2(1.5, 1.5))
	world.use_ability([tank], "siege")
	_check(tank.sieged and tank.eff().range == Content.SIEGE_RANGE, "char en mode siège : portée 9")
	var p0 := tank.pos
	world.command_units_move([tank], Vector2i(4, 0))
	_run(world, 2.0)
	_check(tank.pos == p0, "le char en siège ne bouge pas")
	world.spawn_enemy("normal", Vector2i(9, 2), 1.0)
	world.enemies[0].speed = 0.0
	var hp0 := world.enemies[0].hp
	_run(world, 3.0)
	_check(world.enemies.is_empty() or world.enemies[0].hp < hp0, "il touche un ennemi à 8 cases")
	var med := _add_unit(world, "medic", Vector2(2.0, 3.0))
	sol.hp = 20
	_run(world, 3.0)
	_check(sol.hp > 35, "le médic soigne en continu (%d PV)" % sol.hp)
	sol.hp = 10
	world.use_ability([med], "nanoheal")
	_check(sol.hp >= 60, "nanosoin : +60 PV")
	# Sniper : premier tir critique
	var w2 := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	w2.waves.timer = 9999
	w2.workers.clear()
	_add_unit(w2, "sniper", Vector2(1.5, 1.5))
	w2.spawn_enemy("armored", Vector2i(4, 1), 1.0)
	var e := w2.enemies[0]
	e.speed = 0.0
	e.max_hp = 9999
	e.hp = 9999
	w2.tick(0.05)
	w2.tick(0.05)
	var first := 9999 - e.hp
	_run(w2, 2.0)
	var second := 9999 - e.hp - first
	_check(first > 0 and first > second * 2, "sniper : 1er tir critique (%d puis %d)" % [first, second])


func _test_new_towers() -> void:
	print("Nouvelles tourelles")
	for kind in ["flame", "sniper_tower", "tesla", "cryo", "stun"]:
		var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
		world.waves.timer = 9999
		world.workers.clear()
		_built(world, kind, Vector2i(3, 2))
		for c in ([Vector2i(4, 2), Vector2i(5, 2), Vector2i(4, 2)] if kind == "flame" else [Vector2i(4, 1), Vector2i(5, 2), Vector2i(4, 3)]):
			world.spawn_enemy("normal", c, 1.0)
		for en in world.enemies:
			en.speed = 0.0
			en.max_hp = 5000
			en.hp = 5000
		_run(world, 3.0)
		var hurt := world.enemies.filter(func(x: Enemy) -> bool: return x.hp < 5000).size()
		var extra := ""
		match kind:
			"flame", "tesla":
				extra = " (zone : %d touchés)" % hurt
				_check(hurt >= 2, "%s touche plusieurs ennemis%s" % [kind, extra])
				continue
			"cryo":
				_check(world.enemies.any(func(x: Enemy) -> bool: return x.slow_timer > 0.0), "cryo ralentit")
			"stun":
				_check(world.enemies.any(func(x: Enemy) -> bool: return x.stun_timer > 0.0) or hurt > 0, "impulsion étourdit")
		_check(hurt >= 1, "%s inflige des dégâts" % kind)


func _test_attack_move() -> void:
	print("Déplacement offensif")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.workers.clear()
	var u := _add_unit(world, "soldier", Vector2(0.5, 2.5))
	world.spawn_enemy("normal", Vector2i(3, 0), 1.0)
	var e := world.enemies[0]
	e.speed = 0.0
	world.command_units_move([u], Vector2i(4, 2))
	_check(u.order == Unit.Order.AMOVE, "l'ordre de déplacement est offensif")
	_run(world, 1.0)
	_check(u.target == e, "l'unité engage l'ennemi croisé en chemin")
	_run(world, 25.0)
	_check(world.enemies.is_empty(), "l'ennemi est détruit")
	_check(u.pos.distance_to(Vector2(4.5, 2.5)) < 0.8 and u.order == Unit.Order.GUARD, "puis l'unité reprend la route jusqu'au point")


func _test_finite_deposits() -> void:
	print("Gisements limités")
	var world := GameWorld.new(MapLoader.from_layout("S.........\n..........\n.......BBB\n.M.....BBB\n.......BBB\n.....M...."))
	world.waves.timer = 9999
	var first := Vector2i(1, 3)
	var second := Vector2i(5, 5)
	_check(world.deposit_left[first] == Balance.METAL_PER_DEPOSIT, "un gisement démarre plein")
	world.deposit_left[first] = 20 # presque vide
	world.command_harvest(world.workers, first)
	_run(world, 40.0)
	_check(world.grid.get_cell(first) == GameGrid.Cell.EMPTY and world.depleted.has(first), "le gisement épuisé disparaît")
	_check(world.pathfinder.is_free(first), "sa case redevient praticable")
	_check(world.workers.all(func(w: Worker) -> bool: return w.target_deposit == second), "les ouvriers partent vers le gisement le plus proche")
	var before: int = world.deposit_left[second]
	_run(world, 20.0)
	_check(world.deposit_left[second] < before, "et le récoltent")
	world.deposit_left[second] = 1
	_run(world, 30.0)
	_check(world.workers.all(func(w: Worker) -> bool: return world.is_idle(w)), "plus aucun gisement : les ouvriers deviennent inactifs")
