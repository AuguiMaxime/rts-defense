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
	_test_group_move()
	_test_objectives()
	_test_research()
	_test_hold()
	_test_coop_base()
	_test_chain_build()
	_test_missions()
	_test_editor_core()
	_test_object_sheet()
	_test_scenario()
	_test_templates()
	_test_custom_waves()
	_test_factions()
	_test_validator_params()
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
		var world := GameWorld.new(MapLoader.from_layout(map.LAYOUT), {"waves": l.waves, "mission": map.mission, "entities": map.entities})
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
	_check(wm._queue.back().t == "boss", "le boss arrive en dernier et n'est pas retiré par la difficulté")
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
		_check(MapData.validate(MapLoader.from_layout(md.LAYOUT), md.mission).is_empty(), "carte intégrée « %s » valide" % md.NAME)
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
	m.mission = {"type": "escort", "briefing": "Test"}
	m.entities = [{"kind": "vip", "type": "commander", "cell": [2, 2]}, {"kind": "zone", "role": "goal", "cell": [5, 5], "radius": 2.5}]
	m.save_to(p)
	var back2 := MapData.load_from(p)
	_check(back2.mission.get("type") == "escort" and back2.entities.size() == 2, "mission et objets enregistrés puis relus")
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
	print("Déplacement (repli)")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.workers.clear()
	var u := _add_unit(world, "soldier", Vector2(0.5, 2.5))
	world.spawn_enemy("normal", Vector2i(3, 0), 1.0)
	var e := world.enemies[0]
	e.speed = 0.0
	world.command_units_move([u], Vector2i(4, 2))
	_check(u.order == Unit.Order.MOVE, "un déplacement est un ordre simple")
	_run(world, 1.0)
	_check(u.target == null, "l'unité ignore l'ennemi croisé (repli possible)")
	_run(world, 6.0)
	_check(u.pos.distance_to(Vector2(4.5, 2.5)) < 0.8 and u.order == Unit.Order.GUARD, "elle arrive au point puis monte la garde")
	_run(world, 10.0)
	_check(world.enemies.is_empty() or e.hp < e.max_hp, "une fois arrivée, elle se défend")


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


func _test_group_move() -> void:
	print("Déplacement de groupe")
	var world := GameWorld.new(MapLoader.from_layout(preload("res://maps/map_01.gd").LAYOUT))
	world.waves.timer = 9999
	world.workers.clear()
	var us: Array = []
	for i in 24:
		us.append(_add_unit(world, ["soldier", "tank", "sniper", "warrior"][i % 4], Vector2(12.5 + i % 6 * 0.3, 10.5 + i / 6 * 0.3)))
	var ok := true
	for target in [Vector2i(25, 14), Vector2i(14, 20), Vector2i(30, 8), Vector2i(25, 14)]:
		world.command_units_move(us, target)
		_run(world, 25.0)
		var moving := us.filter(func(u: Unit) -> bool: return u.order != Unit.Order.GUARD)
		var far := us.filter(func(u: Unit) -> bool: return u.pos.distance_to(Vector2(target)) > 6.0)
		if not moving.is_empty() or not far.is_empty():
			ok = false
			print("    bloquées : %d en mouvement, %d loin de %s" % [moving.size(), far.size(), target])
	_check(ok, "24 unités arrivent et s'arrêtent à chaque ordre")
	var before := us.map(func(u: Unit) -> Vector2: return u.pos)
	_run(world, 5.0)
	var jitter := 0.0
	for i in us.size():
		jitter = maxf(jitter, (us[i] as Unit).pos.distance_to(before[i]))
	_check(jitter < 0.3, "puis restent immobiles (déplacement max %.2f)" % jitter)
	var cells := {}
	for u: Unit in us:
		cells[Vector2i(u.guard_pos.floor())] = true
	_check(cells.size() >= us.size() * 3 / 4, "elles s'étalent en formation (%d cases pour %d unités)" % [cells.size(), us.size()])


const OBJ_MAP := """
S...........
............
TTTTTTYTTTTT
......~.....
======H=====
......~.....
.......BBB..
.......BBB..
.M.....BBB..
"""


func _test_objectives() -> void:
	print("Objectifs bonus")
	var g := MapLoader.from_layout(OBJ_MAP)
	_check(g.is_walkable(Vector2i(2, 2)) and g.is_walkable(Vector2i(6, 4)) and not g.is_walkable(Vector2i(6, 3)), "rails, route et pont praticables, eau bloquante")
	var world := GameWorld.new(g, {"objectives": [{"type": "train", "wave": 1}, {"type": "convoy", "wave": 1}, {"type": "boat", "wave": 1}]})
	_check(world.objective_route("train").size() == 12, "trajet du train : toute la voie (%d cases)" % world.objective_route("train").size())
	_check(world.objective_route("convoy").size() == 12, "trajet du convoi : toute la route")
	_check(world.objective_route("boat").size() == 4, "trajet du bateau : la rivière, ponts compris")
	_check(world.can_place_tower(Vector2i(3, 2)) != "", "on ne construit pas sur les rails")
	world.waves.start_next()
	_run(world, 0.2)
	_check(world.objectives.all(func(o: Dictionary) -> bool: return o.state == "active"), "les objectifs démarrent à leur vague")
	var neutrals := world.enemies.filter(func(e: Enemy) -> bool: return e.neutral)
	_check(neutrals.size() >= 2, "train et bateau apparaissent")
	# Sans défense, le train traverse et l'objectif échoue
	_run(world, 15.0)
	_check(world.objectives[0].state == "failed", "train non détruit = objectif raté")
	# Avec une tourelle, le convoi est détruit
	var w2 := GameWorld.new(MapLoader.from_layout(OBJ_MAP), {"objectives": [{"type": "convoy", "wave": 1}]})
	w2.waves.timer = 9999
	for c in [Vector2i(3, 3), Vector2i(8, 3), Vector2i(3, 5)]:
		var s := _built(w2, "cannon", c)
		s.level = 3
	w2.damage_mult = 6.0
	var m0 := w2.metal
	w2.waves.start_next()
	_run(w2, 15.0)
	_check(w2.objectives[0].state == "done", "convoi détruit = objectif réussi (%s)" % w2.objectives[0].state)
	_check(w2.metal >= m0 + 200 and w2.stats.objectives_done == 1, "récompense versée")


func _test_research() -> void:
	print("Recherches")
	var world := GameWorld.new(MapLoader.from_layout("S...........\n............\n............\n............\n.......BBB..\n.......BBB..\n.M.....BBB..\n............"))
	world.waves.timer = 9999
	world.metal = 5000
	world.essence = 5000
	var forge := _built(world, "forge", Vector2i(2, 0))
	var lab := _built(world, "lab", Vector2i(5, 0))
	_check(forge.producer != null, "la forge peut lancer des recherches")
	var sol := _add_unit(world, "soldier", Vector2(4.5, 7.5))
	var dmg0: int = sol.eff().damage
	_check(world.queue_research(forge.id, "inf_weapons"), "recherche lancée (coût payé)")
	_check(world.queue_research(forge.id, "inf_weapons") and world.research_next_level("inf_weapons") == 3, "le niveau 2 se met en file derrière")
	_check(world.can_research(forge.id, "tw_range") != "", "la forge ne fait pas les recherches du labo")
	_run(world, 26.0)
	_check(int(world.upgrades.get("inf_weapons", 0)) == 1 and sol.eff().damage > dmg0, "armes niv. 1 : +dégâts (%d -> %d)" % [dmg0, sol.eff().damage])
	var m := world.metal
	world.cancel_queue(forge.id, 0)
	_check(world.metal == m + Content.RESEARCH_METAL[1], "annuler rembourse")
	var gun := _built(world, "gun", Vector2i(9, 1))
	var r0: float = gun.stats().range
	world.queue_research(lab.id, "tw_range")
	_run(world, 26.0)
	_check(gun.stats().range > r0, "labo : portée des tourelles augmentée")
	world.queue_research(forge.id, "inf_health")
	var hp0 := sol.max_hp
	_run(world, 26.0)
	_check(sol.max_hp > hp0, "santé : les unités existantes gagnent des PV max")
	for i in 3:
		world.upgrades["mech_armor"] = 3
	var res := _built(world, "research", Vector2i(2, 3))
	_check(world.can_research(res.id, "mech_armor") == "Niveau maximum atteint", "pas plus de 3 niveaux")


func _test_hold() -> void:
	print("Tenir la position")
	var world := GameWorld.new(MapLoader.from_layout(TEST_MAP))
	world.waves.timer = 9999
	world.workers.clear()
	var u := _add_unit(world, "soldier", Vector2(1.5, 2.5))
	world.command_hold([u])
	var p0 := u.pos
	world.spawn_enemy("normal", Vector2i(5, 2), 1.0)
	var e := world.enemies[0]
	e.speed = 0.0
	e.max_hp = 9999
	e.hp = 9999
	_run(world, 4.0)
	_check(u.pos.distance_to(p0) < 0.05, "elle ne poursuit pas l'ennemi hors de portée")
	var other := _add_unit(world, "soldier", u.pos + Vector2(0.1, 0.0))
	_run(world, 1.0)
	_check(u.pos.distance_to(p0) < 0.05, "elle ne se laisse pas pousser par ses voisines")
	e.pos = Vector2(3.5, 2.5)
	_run(world, 2.0)
	_check(e.hp < 9999, "elle tire sur ce qui passe à portée")
	world.command_units_move([u], Vector2i(0, 4))
	_check(u.order == Unit.Order.MOVE, "un ordre de déplacement la libère")


func _test_coop_base() -> void:
	print("Base du joueur 2 (coop)")
	var layout: String = preload("res://maps/map_01.gd").LAYOUT
	var solo := GameWorld.new(MapLoader.from_layout(layout))
	_check(solo.hq_site == null and solo.grid.base2_cells.size() == 9, "en solo, l'emplacement J2 reste libre")
	_check(solo.pathfinder.is_free(solo.grid.base2_cells[4]), "et praticable")
	var w := GameWorld.new(MapLoader.from_layout(layout), {"coop": true})
	_check(w.hq_site != null and w.hq_site.built and w.hq_site.producer != null, "en coop, la base J2 est posée")
	_check(w.workers.size() == Balance.START_WORKERS + 3, "avec 3 ouvriers de plus")
	_check(w.can_queue(w.hq_site.id, "worker") == "", "elle forme des ouvriers")
	var near: Worker = null
	for x in w.workers:
		if x.pos.distance_to(w.hq_site.center()) < 3.0:
			near = x
	_check(near != null and w._dropoff_cells(near) == w.hq_site.cells(), "ses ouvriers déposent à la base la plus proche")
	_check(MapData.from_grid(w.grid).count("b") == 9 or MapData.from_grid(solo.grid).count("b") == 9, "l'emplacement J2 est conservé à l'enregistrement")


func _test_chain_build() -> void:
	print("Construction à la chaîne")
	var world := GameWorld.new(MapLoader.from_layout(preload("res://maps/map_01.gd").LAYOUT))
	world.waves.timer = 9999
	world.metal = 1000
	var w := world.workers[0]
	world.command_harvest(world.workers.slice(1), world.grid.metal_deposits[0]) # les autres sont occupés
	var bc := Vector2i(world.base_center())
	var placed := 0
	for i in 4:
		var c := bc + Vector2i(3 + i, -4)
		if world.can_place("house", c) == "":
			world.place("house", c)
			placed += 1
	world.command_build([w], world.sites[0])
	_run(world, 60.0)
	var built := world.sites.filter(func(x: BuildSite) -> bool: return x.built).size()
	_check(placed >= 3 and built == placed, "un seul ouvrier enchaîne les %d chantiers voisins (%d construits)" % [placed, built])


const MISSION_MAP := """
S.........................
..........................
..........................
..........................
..........................
...BBB....................
...BBB....................
...BBB....................
.M........................
..........................
"""


func _mission_world(mission: Dictionary, ents: Array) -> GameWorld:
	return GameWorld.new(MapLoader.from_layout(MISSION_MAP), {"mission": mission, "entities": ents})


func _test_missions() -> void:
	print("Missions")
	# Structures et gardes ennemis
	var w := _mission_world({"type": "destroy_base"}, [
		{"kind": "structure", "type": "e_hq", "cell": [20, 3]},
		{"kind": "structure", "type": "e_tower_gun", "cell": [15, 6]},
		{"kind": "enemy", "type": "normal", "cell": [18, 8]},
	])
	_check(w.enemies.size() == 3 and not w.pathfinder.is_free(Vector2i(21, 4)), "base, tourelle et garde ennemis posés (la base bloque le passage)")
	_check(w.waves.timer == INF, "pas de vagues si la mission ne les demande pas")
	var u := _add_unit(w, "soldier", Vector2(15.5, 9.5))
	_run(w, 3.0)
	_check(u.hp < u.max_hp, "la tourelle ennemie tire sur l'unité à portée")
	var guard := w.enemies.filter(func(e: Enemy) -> bool: return e.type == "normal")
	_check(not guard.is_empty() and guard[0].pos.distance_to(Vector2(18.5, 8.5)) < 9.0, "le garde reste près de son poste")
	_check(w.scenario.result() == "" and w.state == GameWorld.State.PLAYING, "mission en cours tant que la base ennemie tient")
	for e in w.enemies:
		if e.type == "e_hq":
			e.hp = 0
	_run(w, 0.2)
	_check(w.state == GameWorld.State.WON, "base ennemie détruite = victoire")
	_check(w.pathfinder.is_free(Vector2i(21, 4)), "ses cases redeviennent praticables")
	# Survie
	var ws := _mission_world({"type": "survive", "time": 20, "waves_enabled": false}, [])
	_run(ws, 21.0)
	_check(ws.state == GameWorld.State.WON, "survie : victoire au bout du chrono")
	# Escorte
	var we := _mission_world({"type": "escort"}, [
		{"kind": "vip", "type": "commander", "cell": [8, 6]},
		{"kind": "zone", "role": "goal", "cell": [20, 6], "radius": 2},
	])
	_check(we.mission.vip != null, "unité VIP posée")
	we.command_units_move([we.mission.vip], Vector2i(20, 6))
	_run(we, 12.0)
	_check(we.state == GameWorld.State.WON, "escorte : VIP arrivé = victoire")
	var we2 := _mission_world({"type": "escort"}, [
		{"kind": "vip", "type": "commander", "cell": [8, 6]},
		{"kind": "zone", "role": "goal", "cell": [20, 6], "radius": 2},
	])
	we2.mission.vip.hp = 0
	_run(we2, 0.2)
	_check(we2.state == GameWorld.State.LOST, "escorte : VIP perdu = défaite")
	# Convoi allié à protéger
	var wd := _mission_world({"type": "escort_defend"}, [
		{"kind": "escortee", "cell": [7, 2]},
		{"kind": "waypoint", "order": 0, "cell": [14, 2]},
		{"kind": "waypoint", "order": 1, "cell": [14, 8]},
		{"kind": "waypoint", "order": 2, "cell": [22, 8]},
	])
	_run(wd, 0.2)
	var truck := wd.unit_by_id(int(wd.mission.convoys[0].uid))
	_check(truck != null and wd.unit_at(truck.pos) == null, "convoi allié parti et non sélectionnable")
	_run(wd, 40.0)
	_check(wd.state == GameWorld.State.WON, "convoi allié arrivé au bout du trajet = victoire")
	# Convois alliés multiples, pause sur un point, ennemis qui visent le convoi
	var wd2 := _mission_world({"type": "escort_defend", "convoy_count": 2, "convoy_need": 2, "convoy_start": 0, "convoy_interval": 3}, [
		{"kind": "waypoint", "order": 0, "cell": [8, 1]},
		{"kind": "waypoint", "order": 1, "cell": [14, 1], "pause": 5},
		{"kind": "waypoint", "order": 2, "cell": [22, 1]},
	])
	_run(wd2, 9.0)
	var t1 := wd2.unit_by_id(int(wd2.mission.convoys[0].uid))
	_check(t1 != null and t1.pos.distance_to(Vector2(14.5, 1.5)) < 0.8, "le convoi marque la pause au point 2")
	_check(wd2.mission.convoys[1].state == "go", "le 2e convoi part à son heure")
	var foe := Enemy.create("normal", Vector2(20.5, 8.5), 1.0)
	foe.id = 999
	wd2.enemies.append(foe)
	_run(wd2, 0.6)
	var d0 := foe.pos.distance_to(t1.pos)
	_run(wd2, 2.0)
	_check(foe.pos.distance_to(t1.pos) < d0 - 0.5, "les ennemis foncent sur le convoi en priorité")
	foe.hp = 0
	_run(wd2, 30.0)
	_check(wd2.state == GameWorld.State.WON, "2 convois arrivés = victoire")
	# Bâtiment à défendre
	var wb := _mission_world({"type": "waves"}, [{"kind": "defend", "type": "barracks", "cell": [12, 4]}])
	_check(wb.mission.defend_ids.size() == 1 and wb.sites[0].built, "bâtiment à défendre posé et construit")
	_check(wb.metal == Balance.START_METAL, "gratuitement")
	wb.sell(wb.sites[0])
	_check(wb.sites.size() == 1, "impossible de vendre le bâtiment à défendre")
	_run(wb, 0.1)
	_check(not wb.focus.is_empty(), "il devient la cible prioritaire des ennemis")
	wb.sites[0].hp = 0
	_run(wb, 0.2)
	_check(wb.state == GameWorld.State.LOST, "bâtiment à défendre détruit = défaite")
	# Survie : base détruite = défaite
	var ws2 := _mission_world({"type": "survive", "time": 60, "waves_enabled": false}, [])
	ws2.base_hp = 0
	_run(ws2, 0.2)
	_check(ws2.state == GameWorld.State.LOST, "survie : base détruite = défaite")
	# Décor sur plusieurs cases, pivoté
	_check(Mission.deco_size("hangar_2x1") == Vector2i(2, 1) and Mission.deco_footprint("hangar_2x1", 1) == Vector2i(1, 2), "taille du décor lue dans son nom, pivot")
	var wdec := _mission_world({"type": "waves"}, [{"kind": "deco", "sprite": "hangar_2x2", "block": true, "cell": [12, 2]}])
	_check(not wdec.pathfinder.is_free(Vector2i(13, 3)) and wdec.pathfinder.is_free(Vector2i(14, 3)), "un décor 2x2 bloque ses 4 cases")
	# Prise de position
	var wc := _mission_world({"type": "capture"}, [
		{"kind": "zone", "role": "capture", "cell": [12, 6], "radius": 2, "time": 5},
		{"kind": "zone", "role": "capture", "cell": [20, 6], "radius": 2, "time": 10},
		{"kind": "ally_unit", "type": "soldier", "cell": [12, 6], "hold": true},
		{"kind": "ally_unit", "type": "soldier", "cell": [20, 6], "hold": true},
	])
	_run(wc, 6.0)
	_check(wc.mission.zones[0].captured and not wc.mission.zones[1].captured, "chaque zone a sa propre durée")
	_run(wc, 5.0)
	_check(wc.state == GameWorld.State.WON, "toutes les positions prises = victoire")
	# Convois en objectif principal
	var conv_map := "S.........................\n..........................\n==========================\n..........................\n...BBB....................\n...BBB....................\n...BBB....................\n.M........................"
	var wv := GameWorld.new(MapLoader.from_layout(conv_map), {"mission": {"type": "convoy", "convoy_kind": "convoy", "convoy_count": 2, "convoy_need": 2, "convoy_start": 1, "convoy_interval": 5}})
	_check(wv.objectives.size() == 2, "2 convois programmés")
	_run(wv, 30.0)
	_check(wv.state == GameWorld.State.LOST, "convois non détruits = défaite")
	# Convoi ennemi sur un trajet tracé, avec pause
	var wr := _mission_world({"type": "convoy", "convoy_kind": "convoy", "convoy_count": 1, "convoy_need": 1, "convoy_start": 0, "convoy_interval": 5}, [
		{"kind": "waypoint", "order": 0, "cell": [10, 1]},
		{"kind": "waypoint", "order": 1, "cell": [16, 1], "pause": 6},
		{"kind": "waypoint", "order": 2, "cell": [16, 9]},
	])
	_check(wr.mission.foe_route.size() == 15 and wr.mission.foe_pauses.has(6), "trajet tracé case par case avec sa pause")
	_run(wr, 9.0)
	var cv := wr.enemies.filter(func(e: Enemy) -> bool: return e.neutral)
	_check(not cv.is_empty() and cv[0].pos.distance_to(Vector2(16.5, 1.5)) < 0.5, "le convoi ennemi s'arrête au point de pause")
	_run(wr, 30.0)
	_check(wr.state == GameWorld.State.LOST, "convoi arrivé au bout = raté")
	# Alliés posés
	var wa := _mission_world({"type": "waves"}, [{"kind": "ally_tower", "type": "cannon", "cell": [10, 4], "level": 2}])
	_check(wa.sites.size() == 1 and wa.sites[0].built and wa.sites[0].level == 2, "tourelle alliée déjà construite au niveau 2")
	_check(wa.metal == Balance.START_METAL, "sans coûter de métal")


func _editor_doc(w := 12, h := 8) -> EditorDoc:
	var m := MapData.new()
	var r: Array[String] = []
	for y in h:
		r.append(".".repeat(w))
	m.LAYOUT = "\n".join(r)
	return EditorDoc.from_map(m)


func _test_editor_core() -> void:
	print("Éditeur : document, historique, calques, opérations")
	# Migration : identifiants et noms
	var m := MapData.load_from("res://maps/map_07.gd")
	var d := EditorDoc.from_map(m)
	var ids := {}
	for e: Dictionary in d.entities:
		ids[e.id] = true
	_check(ids.size() == d.entities.size() and d.entities.all(func(e: Dictionary) -> bool: return str(e.name) != ""), "migration : chaque objet a un identifiant unique et un nom")
	var back := EditorDoc.from_map(d.to_map())
	_check(JSON.stringify(back.entities) == JSON.stringify(d.entities) and back.rows == d.rows, "aller-retour document <-> fichier sans perte")
	_check(MapData.new().to_dict().version == EditorDoc.VERSION, "le fichier porte sa version")
	var all_ok := true
	for lv in Content.LEVELS:
		var src := MapData.load_from(lv.map)
		var conv := EditorDoc.from_map(src).to_map()
		if conv.LAYOUT != src.LAYOUT.strip_edges() and "\n".join(EditorDoc.from_map(src).rows) != conv.LAYOUT:
			all_ok = false
		if not MapData.validate(MapLoader.from_layout(conv.LAYOUT), conv.mission).is_empty():
			all_ok = false
	_check(all_ok, "les 7 cartes de campagne s'ouvrent dans l'éditeur et restent valides")
	# Peinture, ponts, verrou
	d = _editor_doc()
	var L := EditorLayers.new()
	var H := EditorHistory.new(d)
	H.begin("eau")
	EditorOps.paint_line(d, L, Vector2i(5, 0), Vector2i(5, 7), "~")
	H.commit()
	H.record("route", func() -> void: EditorOps.paint_line(d, L, Vector2i(0, 3), Vector2i(11, 3), "="))
	_check(d.get_char(Vector2i(5, 3)) == "H" and d.get_char(Vector2i(4, 3)) == "=", "route sur l'eau = pont")
	H.record("rocher", func() -> void: EditorOps.paint(d, L, Vector2i(4, 5), "#"))
	L.locked["water"] = true
	H.record("gomme", func() -> void: EditorOps.paint(d, L, Vector2i(5, 5), ".", 2))
	_check(d.get_char(Vector2i(5, 5)) == "~" and d.get_char(Vector2i(4, 5)) == ".", "calque verrouillé protégé de la gomme")
	L.locked.clear()
	_check(H.undo() == "gomme" and H.undo() == "rocher" and H.undo() == "route" and d.get_char(Vector2i(5, 3)) == "~", "annuler revient en arrière action par action")
	_check(H.redo() == "route" and d.get_char(Vector2i(5, 3)) == "H", "rétablir")
	_check(not H.record("rien", func() -> void: pass), "une action sans effet n'est pas enregistrée")
	# Remplissage
	d = _editor_doc()
	EditorOps.paint_line(d, L, Vector2i(4, 0), Vector2i(4, 7), "#")
	_check(EditorOps.fill(d, L, Vector2i(1, 1), "~") == 32 and d.get_char(Vector2i(6, 1)) == ".", "remplissage limité par les rochers")
	# Base unique
	EditorOps.paint(d, L, Vector2i(8, 4), "B")
	EditorOps.paint(d, L, Vector2i(8, 2), "B")
	var nb := 0
	for r in d.rows:
		nb += r.count("B")
	_check(nb == 9, "une seule base 3x3")
	# Objets : pose, réglage, nommage
	d = _editor_doc()
	var o := EditorOps.DEFAULT_OPTS.duplicate()
	var a := EditorOps.place(d, L, "ally_tower:gun", Vector2i(2, 2), o)
	var b := EditorOps.place(d, L, "ally_tower:gun", Vector2i(3, 2), o)
	_check(a.entity.name != b.entity.name and a.entity.id != b.entity.id, "deux tourelles : deux noms, deux identifiants")
	o.level = 3
	var up := EditorOps.place(d, L, "ally_tower:gun", Vector2i(2, 2), o)
	_check(up.get("updated", false) and int(d.entity_by_id(a.entity.id).level) == 3 and d.entities.size() == 2, "retoucher un objet = lui appliquer les réglages")
	L.locked["units"] = true
	_check(EditorOps.place(d, L, "enemy:normal", Vector2i(6, 6), o).has("error"), "pas de pose sur un calque verrouillé")
	L.locked.clear()
	# Copier / coller / déplacer / pivoter / symétrie
	d = _editor_doc()
	EditorOps.paint(d, L, Vector2i(1, 1), "#")
	EditorOps.paint(d, L, Vector2i(2, 1), "M")
	var dec: Dictionary = EditorOps.place(d, L, "deco:chantier", Vector2i(1, 2), o).entity
	EditorOps.place(d, L, "waypoint:", Vector2i(3, 2), o)
	var clip := EditorOps.extract(d, L, Rect2i(1, 1, 3, 2), d.entities.map(func(e: Dictionary) -> int: return int(e.id)))
	_check(clip.size == Vector2i(3, 2) and clip.chars[0] == "#M?" and clip.entities.size() == 2, "extrait : lettres et objets")
	var pasted := EditorOps.paste(d, L, clip, Vector2i(6, 4), false)
	_check(d.get_char(Vector2i(6, 4)) == "#" and d.get_char(Vector2i(7, 4)) == "M" and pasted.size() == 2 and d.entities.size() == 4, "coller une copie")
	_check(d.entities.filter(func(e: Dictionary) -> bool: return e.kind == "waypoint").map(func(e: Dictionary) -> int: return int(e.order)) == [0, 1], "points de passage renumérotés après copie")
	var rc := EditorOps.rotate_clip(clip)
	_check(rc.size == Vector2i(2, 3) and rc.chars[0] == "?#" and rc.chars[1] == "?M", "rotation d'un quart de tour")
	var dr: Dictionary = rc.entities.filter(func(e: Dictionary) -> bool: return e.kind == "deco")[0]
	_check(int(dr.rot) == 1 and Vector2i(int(dr.cell[0]), int(dr.cell[1])) == Vector2i(0, 0), "le décor tourne avec l'extrait")
	var mc := EditorOps.mirror_clip(clip, true)
	_check(mc.chars[0] == "?M#" and bool(mc.entities.filter(func(e: Dictionary) -> bool: return e.kind == "deco")[0].flip), "symétrie gauche-droite")
	var mv := EditorOps.extract(d, L, Rect2i(1, 1, 3, 2), [dec.id])
	EditorOps.clear(d, mv)
	EditorOps.paste(d, L, mv, Vector2i(1, 5), true)
	_check(d.get_char(Vector2i(1, 1)) == "." and d.get_char(Vector2i(1, 5)) == "#" and EditorDoc.cell_of(d.entity_by_id(dec.id)) == Vector2i(1, 6), "déplacer garde le même objet")
	# Calques masqués à l'affichage
	L.hidden["obstacles"] = true
	_check(L.display_rows(d.rows)[5][1] == ".", "calque masqué : non affiché")
	L.hidden.clear()
	# Décors multi-cases et taille
	var big := EditorOps.place(d, L, "deco:hangar_2x2", Vector2i(10, 6), o)
	_check(big.has("entity") and EditorDoc.entity_cells(big.entity).size() == 4, "décor 2x2 posé sur 4 cases")
	_check(EditorOps.place(d, L, "deco:hangar_2x2", Vector2i(11, 0), o).has("error"), "un décor qui déborde est refusé")


func _test_object_sheet() -> void:
	print("Fiches d'objets : comportements, réglages, objets interactifs")
	var w := _mission_world({"type": "destroy_base"}, [
		{"kind": "enemy", "type": "normal", "cell": [12, 1], "id": 1, "behavior": "patrol", "patrol": [[12, 1], [20, 1]]},
		{"kind": "enemy", "type": "armored", "cell": [22, 8], "id": 2, "hp_mul": 2.0, "inv": true},
		{"kind": "ally_unit", "type": "soldier", "cell": [8, 8], "id": 3, "selectable": false, "behavior": "patrol", "patrol": [[8, 8], [8, 6]]},
		{"kind": "ally_tower", "type": "gun", "cell": [16, 9], "id": 4, "building": true},
		{"kind": "structure", "type": "e_hq", "cell": [22, 0], "id": 9},
	])
	var pat: Enemy = w.find_by_eid(1)
	var ai0: Unit = w.find_by_eid(3)
	var min_y := 99.0
	for i in 50:
		w.tick(0.1)
		min_y = minf(min_y, ai0.pos.y)
	_check(pat.pos.x > 14.5, "patrouille : l'ennemi part vers le point suivant")
	var tank: Enemy = w.find_by_eid(2)
	_check(tank.max_hp == Balance.ENEMIES.armored.hp * 2, "PV ×2 appliqués")
	w._damage_enemy(tank, 50)
	_check(tank.hp == tank.max_hp, "ennemi invulnérable")
	var ai: Unit = w.find_by_eid(3)
	_check(ai.ai and w.unit_at(ai.pos) == null, "unité alliée IA non sélectionnable")
	_check(min_y < 7.2, "l'unité IA suit sa patrouille")
	var site: BuildSite = w.find_by_eid(4)
	_check(site != null and not site.built, "tourelle posée en chantier")
	# Attaque une cible, repli
	var w2 := _mission_world({"type": "destroy_base"}, [
		{"kind": "ally_tower", "type": "gun", "cell": [20, 8], "id": 5, "inv": true},
		{"kind": "enemy", "type": "normal", "cell": [10, 2], "id": 6, "behavior": "attack_target", "target": 5},
		{"kind": "enemy", "type": "normal", "cell": [14, 2], "id": 7, "retreat": 50},
		{"kind": "structure", "type": "e_hq", "cell": [22, 0], "id": 9},
	])
	var att: Enemy = w2.find_by_eid(6)
	var d0 := att.pos.distance_to(Vector2(20.5, 8.5))
	_run(w2, 2.0)
	_check(att.pos.distance_to(Vector2(20.5, 8.5)) < d0 - 1.5, "attaque une cible : l'ennemi fonce sur la tourelle désignée")
	var ret: Enemy = w2.find_by_eid(7)
	ret.pos = Vector2(18.5, 6.5)
	ret.hp = ret.max_hp / 3
	_run(w2, 0.5)
	_check(ret.retreating, "repli sous 50 % de PV")
	# Générateur, bouclier, porte, terminal, prisonniers, objet
	var w3 := _mission_world({"type": "destroy_base"}, [
		{"kind": "structure", "type": "e_generator", "cell": [20, 2], "id": 10},
		{"kind": "structure", "type": "e_tower_gun", "cell": [16, 2], "id": 11},
		{"kind": "shield", "cell": [16, 2], "id": 12, "link": 10, "radius": 3},
		{"kind": "door", "cell": [12, 0], "id": 13, "len": 3, "vertical": true, "link": 10},
		{"kind": "terminal", "cell": [8, 4], "id": 14, "time": 2},
		{"kind": "door", "cell": [12, 6], "id": 15, "len": 2, "link": 14},
		{"kind": "prisoners", "cell": [9, 8], "id": 16, "count": 3},
		{"kind": "pickup", "cell": [10, 8], "id": 17},
		{"kind": "structure", "type": "e_hq", "cell": [22, 7], "id": 9},
	])
	_check(not w3.pathfinder.is_free(Vector2i(12, 1)), "porte fermée : infranchissable")
	_run(w3, 0.2)
	var tw: Enemy = w3.find_by_eid(11)
	w3._damage_enemy(tw, 100)
	_check(tw.hp == tw.max_hp, "bouclier actif : la tourelle ne prend pas de dégâts")
	var gen: Enemy = w3.find_by_eid(10)
	gen.hp = 0
	_run(w3, 0.2)
	w3._damage_enemy(tw, 100)
	_check(tw.hp < tw.max_hp and not w3.mission.shields[0].active, "générateur détruit : bouclier coupé")
	_check(w3.mission.doors[0].open and w3.pathfinder.is_free(Vector2i(12, 1)), "générateur détruit : la porte liée s'ouvre")
	var s1 := _add_unit(w3, "soldier", Vector2(8.5, 5.5))
	s1.order = Unit.Order.HOLD
	_run(w3, 2.5)
	_check(w3.mission.terminals[0].done and w3.mission.doors[1].open, "terminal activé : sa porte s'ouvre")
	var before := w3.units.size()
	s1.pos = Vector2(9.5, 8.5)
	_run(w3, 0.3)
	_check(w3.mission.prisoners[0].freed and w3.units.size() == before + 3, "prisonniers libérés : 3 unités rejoignent le joueur")
	s1.pos = Vector2(10.5, 8.5)
	_run(w3, 0.2)
	_check(w3.mission.pickups[0].taken and w3.mission.collected == 1, "objet récupéré")
	var st := w3.mission.inter_state()
	var copy := GameWorld.new(MapLoader.from_layout(MISSION_MAP), {"mission": {"type": "destroy_base"}, "entities": w3.mission.entities})
	copy.mission.apply_inter_state(st)
	_check(copy.mission.doors[1].open and copy.mission.prisoners[0].freed, "état des objets transmis au 2e joueur")


func _scn_world(scn: Dictionary, ents: Array, mission := {"type": "destroy_base"}) -> GameWorld:
	return GameWorld.new(MapLoader.from_layout(MISSION_MAP), {"mission": mission, "entities": ents, "scenario": scn})


func _scn_events(w: GameWorld, t: String) -> Array:
	return w.take_events().filter(func(e: Dictionary) -> bool: return e.type == t)


func _test_scenario() -> void:
	print("Scénario : objectifs, déclencheurs, variables")
	var Z := {"kind": "zone", "role": "trigger", "cell": [15, 5], "radius": 2.0, "id": 50, "name": "Pont"}
	# Déclencheurs : début, message, variable, entrée en zone, SINON, attente
	var scn := {
		"variables": [{"name": "vies", "type": "int", "value": 3}],
		"triggers": [
			{"id": "t1", "name": "Intro", "once": true, "event": {"type": "start"}, "cond": {}, "actions": [
				{"type": "message", "speaker": "QG", "text": "Il reste {vies} vies", "seconds": 4.0},
				{"type": "wait", "seconds": 1.0},
				{"type": "var_add", "var": "vies", "value": 2}]},
			{"id": "t2", "name": "Embuscade", "once": true, "event": {"type": "enter_zone", "zone": 50, "who": "player"},
				"cond": {"op": "and", "items": [{"type": "var", "var": "vies", "cmp": ">=", "value": 5}]},
				"actions": [{"type": "spawn", "team": "enemy", "enemy_type": "normal", "count": 4, "zone": 50, "behavior": "aggressive"}],
				"else": [{"type": "notify", "text": "raté"}]},
			{"id": "t3", "name": "Boucle", "once": false, "event": {"type": "var_changed", "var": "boucle"}, "cond": {},
				"actions": [{"type": "var_add", "var": "boucle", "value": 1}]},
			{"id": "t4", "name": "Relance", "once": true, "event": {"type": "time", "seconds": 0.5}, "cond": {},
				"actions": [{"type": "var_set", "var": "boucle", "value": 1}]},
		]}
	var w := _scn_world(scn, [Z, {"kind": "structure", "type": "e_hq", "cell": [22, 0], "id": 9}])
	w.tick(0.1)
	var msgs := _scn_events(w, "scn_message")
	_check(msgs.size() == 1 and msgs[0].text == "Il reste 3 vies", "QUAND début → message avec variable")
	_check(int(w.scenario.vars.vies) == 3, "l'action après « Attendre 1 s » n'est pas encore jouée")
	_run(w, 1.2)
	_check(int(w.scenario.vars.vies) == 5, "puis elle s'exécute")
	var foes := w.enemies.size()
	var u := _add_unit(w, "soldier", Vector2(15.5, 5.5))
	u.order = Unit.Order.HOLD
	_run(w, 0.3)
	_check(w.enemies.size() == foes + 4, "QUAND une unité entre dans la zone, SI vies ≥ 5 → 4 ennemis créés")
	_run(w, 3.0)
	_check(int(w.scenario.vars.get("boucle", 0)) > 1 and w.state == GameWorld.State.PLAYING, "un déclencheur qui se relance lui-même ne bloque pas le jeu")
	# SINON
	var w2 := _scn_world({"triggers": [{"id": "a", "name": "A", "event": {"type": "start"}, "cond": {"op": "and", "items": [{"type": "time", "cmp": ">", "value": 100}]},
		"actions": [{"type": "notify", "text": "oui"}], "else": [{"type": "notify", "text": "non"}]}]}, [{"kind": "structure", "type": "e_hq", "cell": [22, 0], "id": 9}])
	w2.tick(0.1)
	var nt := _scn_events(w2, "scn_notify")
	_check(nt.size() == 1 and nt[0].text == "non", "condition fausse → SINON")
	# Objectifs : détruire, enchaînement, récompense, victoire
	var o_scn := {"objectives": [
		{"id": "o1", "name": "Détruire les tourelles", "kind": "main", "start": "visible", "type": "destroy", "what": "targets", "targets": [11, 12], "count": 0, "reward": {"metal": 300}},
		{"id": "o2", "name": "Raser la base", "kind": "main", "start": "after", "after": ["o1"], "type": "destroy", "what": "bases"},
		{"id": "o3", "name": "Bonus", "kind": "secondary", "start": "visible", "type": "survive_time", "time": 2.0, "deadline": 0.0},
	]}
	var w3 := _scn_world(o_scn, [
		{"kind": "structure", "type": "e_tower_gun", "cell": [15, 1], "id": 11},
		{"kind": "structure", "type": "e_tower_gun", "cell": [18, 1], "id": 12},
		{"kind": "structure", "type": "e_hq", "cell": [22, 6], "id": 9}])
	w3.tick(0.1)
	_check(w3.scenario.objectives[1].state == "hidden" and w3.scenario.objectives[0].text == "0 / 2", "objectif suivant caché, progression 0 / 2")
	var m0 := w3.metal
	w3.find_by_eid(11).hp = 0
	w3.find_by_eid(12).hp = 0
	_run(w3, 0.3)
	_check(w3.scenario.objectives[0].state == "done" and w3.scenario.objectives[1].state == "active", "objectif réussi → le suivant se révèle")
	_check(w3.metal >= m0 + 300, "récompense versée")
	_check(w3.state == GameWorld.State.PLAYING, "pas de victoire tant qu'un objectif principal reste")
	w3.find_by_eid(9).hp = 0
	_run(w3, 0.3)
	_check(w3.state == GameWorld.State.WON, "tous les objectifs principaux réussis → victoire")
	# Échecs : délai, objet à protéger, secondaire sans défaite
	var w4 := _scn_world({"objectives": [
		{"id": "p", "name": "Protéger", "kind": "main", "type": "protect", "targets": [5], "time": 0.0},
		{"id": "s", "name": "Vite", "kind": "secondary", "type": "survive_time", "time": 99.0, "deadline": 1.0}]},
		[{"kind": "ally_tower", "type": "gun", "cell": [12, 4], "id": 5}, {"kind": "structure", "type": "e_hq", "cell": [22, 0], "id": 9}])
	_run(w4, 1.5)
	_check(w4.scenario.objectives[1].state == "failed" and w4.state == GameWorld.State.PLAYING, "objectif secondaire hors délai : échoué, mission continue")
	w4.find_by_eid(5).hp = 0
	_run(w4, 0.3)
	_check(w4.state == GameWorld.State.LOST, "objet à protéger détruit → défaite")
	# Capture X sur Y, atteindre + extraction, combinaison, collecte
	var w5 := _scn_world({"objectives": [
		{"id": "c", "name": "Capturer", "kind": "main", "type": "capture", "zones": [60, 61, 62], "need": 2, "time": 1.0},
		{"id": "x", "name": "Extraire", "kind": "secondary", "type": "reach", "zone": 63, "who": "player", "count": 1, "extract": true},
		{"id": "k", "name": "Au moins un", "kind": "secondary", "type": "compound", "children": ["x", "c"], "mode": "atleast", "n": 1}]},
		[{"kind": "zone", "role": "capture", "cell": [10, 1], "radius": 1.5, "id": 60},
		{"kind": "zone", "role": "capture", "cell": [14, 1], "radius": 1.5, "id": 61},
		{"kind": "zone", "role": "capture", "cell": [18, 1], "radius": 1.5, "id": 62},
		{"kind": "zone", "role": "extraction", "cell": [10, 8], "radius": 1.5, "id": 63},
		{"kind": "structure", "type": "e_hq", "cell": [22, 6], "id": 9}])
	for cx in [10, 14]:
		var s := _add_unit(w5, "soldier", Vector2(cx + 0.5, 1.5))
		s.order = Unit.Order.HOLD
	var ex := _add_unit(w5, "soldier", Vector2(10.5, 8.5))
	ex.order = Unit.Order.HOLD
	_run(w5, 0.5)
	_check(not ex.alive and w5.scenario.objectives[1].state == "done", "extraction : l'unité quitte la carte, objectif réussi")
	_check(w5.scenario.objectives[2].state == "done", "combinaison « au moins 1 » réussie")
	_run(w5, 1.0)
	_check(w5.state == GameWorld.State.WON, "2 zones sur 3 capturées → victoire")
	# Règles : base détruite sans défaite, victoire par action
	var w6 := _scn_world({"rules": {"defeat_base": false, "victory": "manual"}, "triggers": [
		{"id": "v", "name": "Fin", "event": {"type": "base_destroyed"}, "actions": [{"type": "wait", "seconds": 0.5}, {"type": "victory", "text": "Bravo"}]}]},
		[{"kind": "structure", "type": "e_hq", "cell": [22, 0], "id": 9}])
	w6.base_hp = 0
	_run(w6, 0.2)
	_check(w6.state == GameWorld.State.PLAYING, "règle : base détruite sans défaite")
	_run(w6, 0.6)
	_check(w6.state == GameWorld.State.WON and w6.scenario.end_text == "Bravo", "action Victoire")
	# Objet absent puis activé, ennemi en attente réveillé
	var w7 := _scn_world({"triggers": [{"id": "r", "name": "Renforts", "event": {"type": "time", "seconds": 1.0}, "actions": [
		{"type": "activate", "obj": 30}, {"type": "activate", "obj": 31}]}]},
		[{"kind": "enemy", "type": "normal", "cell": [12, 2], "id": 30, "absent": true},
		{"kind": "enemy", "type": "normal", "cell": [14, 2], "id": 31, "behavior": "wait"},
		{"kind": "structure", "type": "e_hq", "cell": [22, 0], "id": 9}])
	_check(w7.find_by_eid(30) == null and w7.find_by_eid(31).mode == "wait", "objet absent au départ, ennemi en attente")
	_run(w7, 1.3)
	_check(w7.find_by_eid(30) != null and w7.find_by_eid(31).mode == "guard", "le déclencheur le fait apparaître et réveille l'autre")
	# Chrono, vague, coop
	var w8 := _scn_world({"triggers": [
		{"id": "c1", "name": "Chrono", "event": {"type": "start"}, "actions": [{"type": "timer_start", "timer": "r", "seconds": 1.0, "label": "Renforts", "show": true}]},
		{"id": "c2", "name": "Fin chrono", "event": {"type": "timer_end", "timer": "r"}, "actions": [{"type": "give", "res": "essence", "amount": 77}]}]},
		[{"kind": "structure", "type": "e_hq", "cell": [22, 0], "id": 9}])
	w8.tick(0.1)
	_check(w8.scenario.shown_timers().size() == 1, "chrono affiché")
	var e0 := w8.essence
	_run(w8, 1.2)
	_check(w8.essence == e0 + 77, "QUAND le chrono se termine → ressources")
	var copy := _scn_world(w3.scenario.data, [])
	copy.scenario.apply_net_state(w3.scenario.net_state())
	_check(copy.scenario.objectives[0].state == "done", "état des objectifs transmis au 2e joueur")


func _test_templates() -> void:
	print("Modèles de mission")
	for t in Mission.TYPES:
		var gen := MissionTemplates.build({"type": t}, [])
		_check(not gen.objectives.is_empty() and gen.objectives.all(func(o: Dictionary) -> bool: return o.tpl and str(o.id) != ""), "modèle %s : objectifs générés" % t)
		var w := _mission_world({"type": t}, [])
		_check(not w.scenario.objectives.is_empty(), "modèle %s : la partie tourne sur le scénario" % t)
	# Bâtiment à défendre : objectif ajouté au modèle
	var gd := MissionTemplates.build({"type": "survive"}, [{"kind": "defend", "type": "barracks", "cell": [1, 1]}])
	_check(gd.objectives.any(func(o: Dictionary) -> bool: return o.type == "protect"), "bâtiment à défendre = objectif Défendre")
	# Objectifs perso sans « défendre » : il est ajouté quand même
	var own := {"objectives": [{"id": "a", "name": "A", "kind": "main", "type": "survive_time", "time": 5.0}]}
	var ens := MissionTemplates.ensure(own, {"type": "waves"}, [{"kind": "defend", "type": "barracks", "cell": [1, 1]}])
	_check(ens.objectives.size() == 2 and own.objectives.size() == 1, "défendre ajouté aux objectifs perso, sans modifier l'original")
	_check(MissionTemplates.ensure({"rules": {"victory": "manual"}}, {"type": "waves"}, []).get("objectives", []).is_empty(), "victoire manuelle : pas de modèle imposé")
	# Régénération : garde les ajouts manuels
	var sc := MissionTemplates.ensure({}, {"type": "survive", "time": 300}, [])
	sc.objectives.append({"id": "mine", "name": "Perso", "type": "collect", "kind": "optional"})
	MissionTemplates.regenerate(sc, {"type": "capture"}, [])
	_check(sc.objectives.size() == 2 and sc.objectives[0].type == "capture" and sc.objectives[1].id == "mine", "changer de type remplace le modèle, garde le reste")
	_check(not sc.triggers.any(func(t: Dictionary) -> bool: return t.name == "Dernière minute"), "et ses déclencheurs")
	# Survie : la durée suit l'onglet Mission
	var ws := _mission_world({"type": "survive", "time": 12, "waves_enabled": false}, [])
	_run(ws, 6.0)
	_check(ws.state == GameWorld.State.PLAYING and str(ws.scenario.objectives[0].text) in ["0:06", "0:07"], "survie : chrono lu dans l'onglet Mission")
	_run(ws, 7.0)
	_check(ws.state == GameWorld.State.WON, "survie : victoire")
	# Défense : continuer en infini ne relance pas la victoire
	var wv := _mission_world({"type": "waves"}, [])
	wv.waves.wave = wv.waves.total
	_run(wv, 0.1)
	_check(wv.state == GameWorld.State.WON, "défense : vagues finies = victoire")
	wv.continue_infinite()
	_run(wv, 1.0)
	_check(wv.state == GameWorld.State.PLAYING, "mode infini : la partie continue")
	# Convois ennemis : trop de convois échappés = défaite
	var wc := _mission_world({"type": "convoy", "convoy_count": 2, "convoy_need": 2}, [])
	wc.objectives[0].state = "failed"
	_run(wc, 0.1)
	_check(wc.state == GameWorld.State.LOST, "convois : un convoi échappé sur 2 requis = défaite")
	# Briefing
	_check(_mission_world({"type": "destroy_base"}, []).scenario.brief_text().begins_with("◆ Détruire"), "briefing : objectifs du modèle")
	# Campagne : toutes les cartes ont des objectifs
	for i in range(1, 8):
		var m := MapData.load_from("res://maps/map_%02d.gd" % i)
		var wm := GameWorld.new(MapLoader.from_layout(m.LAYOUT), {"mission": m.mission, "entities": m.entities, "scenario": m.scenario})
		_check(not wm.scenario.objectives.is_empty(), "campagne carte %d : objectifs du nouveau moteur" % i)


func _wave_world(plan: Array, scn := {}, mission := {"type": "waves"}) -> GameWorld:
	var rows := MISSION_MAP.strip_edges().split("\n")
	rows[9] = rows[9].substr(0, 25) + "S"
	var g := MapLoader.from_layout("\n".join(rows))
	return GameWorld.new(g, {"mission": mission, "scenario": scn, "wave_plan": {"mode": "custom", "list": plan}})


func _wave_def(id: String, start: String, delay: float, groups: Array, extra := {}) -> Dictionary:
	var d := WaveManager.new_wave(id, id)
	d.start = start
	d.delay = delay
	d.groups = groups
	d.merge(extra, true)
	return d


func _test_custom_waves() -> void:
	print("Vagues personnalisées")
	var plan := [
		_wave_def("w1", "auto", 2.0, [{"type": "normal", "count": 3, "spawn": "25,9"}]),
		_wave_def("w2", "clear", 1.0, [{"type": "fast", "count": 2, "spawn": ""}, {"type": "boss", "count": 1, "spawn": "0,0", "escort": 2, "escort_type": "armored"}],
				{"order": "simultaneous", "hp": 2.0}),
		_wave_def("amb", "trigger", 0.0, [{"type": "normal", "count": 2, "spawn": "0,0"}], {"behavior": "aggressive"}),
		_wave_def("rep", "trigger", 0.0, [{"type": "normal", "count": 1, "spawn": "0,0"}], {"repeat": 2, "every": 3.0}),
	]
	var scn := {"variables": [{"name": "fin", "type": "int", "value": 0}],
		"triggers": [
			{"id": "t1", "name": "Embuscade", "enabled": true, "once": true, "event": {"type": "wave_ended", "wave": "w1"},
				"cond": {"op": "and", "items": []}, "actions": [{"type": "var_set", "var": "fin", "value": 1}, {"type": "wave_launch", "wave": "amb"}], "else": []}],
		"objectives": [{"id": "o", "name": "Vagues", "kind": "main", "type": "survive_waves", "waves": 0}]}
	var w := _wave_world(plan, scn)
	_check(w.waves.custom() and w.waves.total == 2, "plan personnalisé : 2 vagues enchaînées (les autres partent sur événement)")
	_run(w, 1.9)
	_check(w.waves.wave == 0, "délai initial respecté")
	_run(w, 0.3)
	_check(w.waves.wave == 1 and w.waves.last_id == "w1", "vague 1 lancée après son délai")
	_run(w, 3.0)
	var e1 := w.enemies.filter(func(e: Enemy) -> bool: return e.wave_no == 1)
	_check(e1.size() == 3 and e1.all(func(e: Enemy) -> bool: return e.pos.distance_to(Vector2(25.5, 9.5)) < 6.0), "3 ennemis au point d'apparition choisi")
	_check(w.waves.left == 3, "compteur d'ennemis restants")
	_run(w, 3.0)
	_check(w.waves.wave == 1, "vague « éliminée » : attend que la précédente soit détruite")
	for e in e1:
		e.hp = 0
	_run(w, 0.2)
	_check(w.scenario.vars.get("fin") == 1 and w.waves.wave == 2 and w.waves.last_id == "amb", "vague éliminée → déclencheur → embuscade lancée")
	_check(w.enemies.filter(func(e: Enemy) -> bool: return e.wave_no == 2).all(func(e: Enemy) -> bool: return e.mode == "aggressive"), "comportement de la vague appliqué")
	_run(w, 1.1)
	var e3 := w.enemies.filter(func(e: Enemy) -> bool: return e.wave_no == 3)
	_check(w.waves.wave == 3 and e3.size() == 5, "vague 2 : groupes + escorte du boss (2 rapides, 1 boss, 2 blindés)")
	_check(e3.filter(func(e: Enemy) -> bool: return e.type == "armored").size() == 2, "l'escorte suit son type")
	var fast := e3.filter(func(e: Enemy) -> bool: return e.type == "fast")
	_check(not fast.is_empty() and fast[0].max_hp == roundi(Balance.ENEMIES.fast.hp * 2.0), "PV × 2 appliqués")
	# Répétition
	w.scenario.execute({"type": "wave_launch", "wave": "rep"})
	_run(w, 0.1)
	_check(w.waves.wave == 4, "vague répétée : 1er lancement")
	_run(w, 6.5)
	_check(w.waves.wave == 6 and w.waves.total == 6, "répétée 2 fois toutes les 3 s (le total suit)")
	_check(not w.waves.has_more_waves(), "plus rien à lancer")
	# Accélérer, suspendre, arrêter
	var w2 := _wave_world([_wave_def("a", "auto", 10.0, [{"type": "normal", "count": 4}]), _wave_def("b", "auto", 10.0, [{"type": "normal", "count": 4}])])
	w2.scenario.execute({"type": "wave_speed", "factor": 2.0})
	_run(w2, 5.2)
	_check(w2.waves.wave == 1, "accéléré x2 : 10 s de délai en 5 s")
	w2.scenario.execute({"type": "wave_pause"})
	var before := w2.enemies.size()
	_run(w2, 3.0)
	_check(w2.enemies.size() == before and w2.waves.wave == 1, "suspendu : plus d'apparitions ni de compte à rebours")
	w2.scenario.execute({"type": "wave_resume"})
	w2.scenario.execute({"type": "wave_stop", "wave": ""})
	_run(w2, 20.0)
	_check(w2.waves.wave == 1 and w2.waves.queue_empty() and not w2.waves.has_more_waves(), "arrêter toutes les vagues")
	# Lancement par objectif
	var w3 := _wave_world([_wave_def("x", "objective", 1.0, [{"type": "normal", "count": 1}], {"objective": "o2"})],
			{"objectives": [{"id": "o2", "name": "T", "kind": "secondary", "type": "survive_time", "time": 2.0}]})
	_run(w3, 2.5)
	_check(w3.waves.wave == 0, "attend l'objectif + son délai")
	_run(w3, 1.0)
	_check(w3.waves.wave == 1, "vague lancée par un objectif réussi")
	# Conversion du mode automatique
	var conv := WaveManager.from_auto(10, 1.0, 30.0)
	_check(conv.size() == 10 and conv[4].groups.any(func(g: Dictionary) -> bool: return g.type == "boss"), "conversion : 10 vagues, boss à la 5")
	var n5 := 0
	for g in conv[4].groups:
		n5 += int(g.count)
	_check(n5 == WaveManager.composition(5).size(), "conversion : même composition")
	# Sauvegarde
	var m := MapData.new()
	m.wave_plan = {"mode": "custom", "list": plan, "spawn_names": {"25,9": "Est"}}
	var p := "user://test_waves.json"
	m.save_to(p)
	var back := MapData.load_from(p)
	_check(back.wave_plan.list.size() == 4 and back.wave_plan.spawn_names["25,9"] == "Est", "vagues et noms des apparitions sauvegardés")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _test_factions() -> void:
	print("Factions")
	var f := Factions.new({"list": [{"id": "f1", "name": "Pirates", "camp": "enemy", "color": "ff00ff"}],
			"rel": {"ally|f1": "neutral", "p1|f1": "provoked"}})
	_check(f.relation("p1", "ally") == "ally" and f.relation("enemy", "neutral") == "ally", "même camp = alliés")
	_check(f.hostile("p1", "enemy") and f.hostile("enemy", "p1"), "joueur / ennemis : hostiles par défaut")
	_check(f.relation("p1", "neutral") == "neutral" and not f.hostile("neutral", "civil"), "neutres : non hostiles par défaut")
	_check(f.relation("f1", "ally") == "neutral" and f.relation("p1", "f1") == "provoked", "relations réglées dans l'éditeur")
	f.provoke("f1", "p1")
	_check(f.relation("p1", "f1") == "enemy" and f.relation("ally", "f1") == "neutral" and f.pending.size() == 1, "hostile si attaqué : bascule à la 1re attaque")
	var f2 := Factions.new({"rel": {"p1|neutral": "provoked", "ally|neutral": "enemy"}})
	f2.provoke("neutral", "ally")
	_check(f2.relation("p1", "neutral") == "provoked", "attaqués par un allié IA : le joueur reste en paix")
	# En jeu
	var fac := {"list": [{"id": "f1", "name": "Pirates", "camp": "enemy", "color": "ff00ff"}], "rel": {"p1|f1": "provoked"}}
	var cfg := {"mission": {"type": "waves", "waves_enabled": false}, "factions": fac, "entities": [
		{"kind": "enemy", "type": "normal", "cell": [12, 4], "id": 1, "faction": "neutral", "behavior": "guard"},
		{"kind": "enemy", "type": "normal", "cell": [20, 4], "id": 2, "faction": "f1", "behavior": "guard"},
		{"kind": "ally_unit", "type": "soldier", "cell": [12, 6], "id": 3, "behavior": "hold"},
		{"kind": "ally_unit", "type": "soldier", "cell": [20, 6], "id": 4, "behavior": "hold"},
		{"kind": "ally_unit", "type": "soldier", "cell": [4, 2], "id": 5, "faction": "ally", "behavior": "hunt"},
		{"kind": "enemy", "type": "normal", "cell": [4, 9], "id": 6, "behavior": "static"},
	], "scenario": {"triggers": [{"id": "t1", "name": "R", "enabled": true, "once": true, "event": {"type": "relation_changed", "a": "f1", "b": ""},
			"cond": {"op": "and", "items": []}, "actions": [{"type": "message", "text": "Les pirates attaquent !"}], "else": []}]}}
	var w := GameWorld.new(MapLoader.from_layout(MISSION_MAP), cfg)
	var neu: Enemy = w.find_by_eid(1)
	var pir: Enemy = w.find_by_eid(2)
	var al: Unit = w.find_by_eid(5)
	_check(neu.faction == "neutral" and pir.faction == "f1" and al.faction == "ally" and al.ai, "factions posées dans l'éditeur")
	_check((w.find_by_eid(3) as Unit).faction == "p1" and not (w.find_by_eid(3) as Unit).ai, "unité du joueur par défaut")
	var hp_n := neu.hp
	var hp_p := pir.hp
	_run(w, 3.0)
	_check(neu.hp == hp_n and pir.hp == hp_p, "les unités du joueur ignorent les neutres")
	_check((w.find_by_eid(3) as Unit).hp == (w.find_by_eid(3) as Unit).max_hp, "et les neutres ne les attaquent pas")
	_check(al.pos.distance_to(Vector2(4.5, 9.5)) < Vector2(4.5, 2.5).distance_to(Vector2(4.5, 9.5)) - 1.0, "allié IA « chasse » : part vers l'ennemi")
	# Provocation : le joueur attaque un pirate
	var u4: Unit = w.find_by_eid(4)
	u4.target = pir
	u4.order = Unit.Order.ATTACK
	_run(w, 2.0)
	_check(w.factions.relation("p1", "f1") == "enemy", "pirates provoqués : deviennent ennemis")
	_check(w.scenario.log.any(func(l: String) -> bool: return l.contains("relation")), "événement « relation changée »")
	# Déclencheur : changer une relation, changer de faction
	w.scenario.execute({"type": "set_relation", "a": "p1", "b": "neutral", "rel": "enemy"})
	_check(w.factions.hostile("neutral", "p1"), "action : changer une relation")
	w.scenario.execute({"type": "set_faction", "obj": 3, "faction": "ally"})
	_check((w.find_by_eid(3) as Unit).faction == "ally" and (w.find_by_eid(3) as Unit).ai, "action : l'unité passe aux alliés IA")
	w.scenario.execute({"type": "set_faction", "obj": 3, "faction": "enemy"})
	_check((w.find_by_eid(3) as Unit).faction == "ally", "changement de camp refusé")
	_check(w.scenario.eval_cond({"op": "and", "items": [{"type": "relation", "a": "p1", "b": "neutral", "rel": "enemy"}, {"type": "faction_of", "obj": 1, "faction": "neutral"}]}), "conditions relation et faction")
	# Vagues d'une autre faction
	var wv := WaveManager.new_wave("w", "w")
	wv.faction = "neutral"
	wv.delay = 0.5
	var w2 := GameWorld.new(MapLoader.from_layout(MISSION_MAP), {"mission": {"type": "waves"}, "wave_plan": {"mode": "custom", "list": [wv]}})
	_run(w2, 2.0)
	_check(not w2.enemies.is_empty() and w2.enemies.all(func(e: Enemy) -> bool: return e.faction == "neutral"), "vague d'une faction choisie")
	# Coop : relations et factions transmises
	var snap := NetSync.snapshot(w)
	var c := GameWorld.new(MapLoader.from_layout(MISSION_MAP), cfg)
	NetSync.apply(c, snap)
	_check(c.factions.relation("p1", "f1") == "enemy" and c.enemies.any(func(e: Enemy) -> bool: return e.faction == "f1"), "coop : relations et factions transmises")


func _test_validator_params() -> void:
	print("Validation et paramètres")
	# Cartes de la campagne : aucune erreur bloquante
	for i in range(1, 8):
		var d := EditorDoc.from_map(MapData.load_from("res://maps/map_%02d.gd" % i))
		var res := MissionValidator.run(d, MapLoader.from_layout("\n".join(d.rows)))
		_check(MissionValidator.errors(res).is_empty(), "campagne carte %d : aucune erreur" % i)
	# Erreurs avec « aller à »
	var d := EditorDoc.from_map(MapData.load_from("res://maps/map_01.gd"))
	var g := MapLoader.from_layout("\n".join(d.rows))
	var rock := Vector2i(-1, -1)
	for y in g.height:
		for x in g.width:
			if rock.x < 0 and g.get_cell(Vector2i(x, y)) == GameGrid.Cell.ROCK:
				rock = Vector2i(x, y)
	d.entities.append({"id": 900, "kind": "enemy", "type": "normal", "cell": [rock.x, rock.y], "name": "Coincé"})
	d.entities.append({"id": 901, "kind": "enemy", "type": "normal", "cell": [2, 2], "name": "Doublon"})
	d.entities.append({"id": 902, "kind": "enemy", "type": "normal", "cell": [3, 2], "name": "Doublon"})
	d.scenario = {"objectives": [{"id": "o1", "name": "Tenir", "kind": "main", "type": "hold", "zone": -1}],
			"triggers": [{"id": "t1", "name": "Cassé", "enabled": true, "once": true, "event": {"type": "start"}, "cond": {"op": "and", "items": []},
				"actions": [{"type": "wave_launch", "wave": "nope"}], "else": []}]}
	d.wave_plan = {"mode": "custom", "list": [{"id": "w1", "name": "V", "start": "objective", "objective": "zz", "groups": []}]}
	d.mission["params"] = {"players": "coop", "time_limit": 100, "metal": 0, "workers": 0}
	d.mission["type"] = "survive"
	d.mission["time"] = 200
	var res := MissionValidator.run(d, g)
	var find := func(part: String) -> Dictionary:
		for it: Dictionary in res:
			if str(it.text).contains(part):
				return it
		return {}
	_check(find.call("Coincé : posé sur un obstacle").get("go", {}).get("id", -1) == 900, "objet sur un obstacle → aller à l'objet")
	_check(not find.call("s'appellent « Doublon »").is_empty(), "noms en double signalés")
	_check(find.call("paramètre « zone »").get("go", {}) == {"tab": "objectives", "id": "o1"}, "objectif incomplet → aller à l'objectif")
	_check(find.call("Cassé").get("go", {}).get("tab", "") == "events", "déclencheur cassé → aller au déclencheur")
	_check(find.call("choisis l'objectif qui la lance").get("go", {}) == {"tab": "waves", "id": "w1"}, "vague cassée → aller à la vague")
	_check(find.call("base du joueur 2").get("lvl", "") == ("" if g.base2_cells.size() == 9 else "error"), "coop sans 2e base = erreur")
	_check(not find.call("plus courte que la survie").is_empty(), "durée maximale incohérente")
	_check(find.call("ni ouvrier").get("lvl", "") == "warn", "départ sans ressources signalé")
	_check(res.find(find.call("posé sur un obstacle")) < res.find(find.call("ni ouvrier")), "erreurs avant les avertissements")
	# Paramètres en jeu
	var cfg := {"mission": {"type": "waves", "params": {"time_limit": 5.0}}, "start_metal": 777, "start_essence": 55, "start_workers": 1,
		"entities": [{"kind": "building", "type": "barracks", "cell": [12, 6], "id": 1}, {"kind": "building", "type": "house", "cell": [16, 6], "id": 2, "building": true}]}
	var w := GameWorld.new(MapLoader.from_layout(MISSION_MAP), cfg)
	_check(w.metal == 777 and w.essence == 55 and w.workers.size() == 1, "ressources et ouvriers de départ")
	var bar := w.sites.filter(func(s: BuildSite) -> bool: return s.kind == "barracks")
	var hou := w.sites.filter(func(s: BuildSite) -> bool: return s.kind == "house")
	_check(bar.size() == 1 and bar[0].built and hou.size() == 1 and not hou[0].built, "bâtiments de départ (construit / en chantier)")
	_check(w.scenario.shown_timers().any(func(t: Array) -> bool: return t[0] == "Temps restant"), "durée maximale affichée")
	_run(w, 5.5)
	_check(w.state == GameWorld.State.LOST and w.scenario.end_text == "Temps écoulé", "durée maximale atteinte = défaite")
	var w2 := GameWorld.new(MapLoader.from_layout(MISSION_MAP), {"mission": {"type": "waves", "params": {"time_limit": 2.0, "time_out": "victory"}}})
	_run(w2, 2.5)
	_check(w2.state == GameWorld.State.WON, "ou victoire si choisi")
	# Aperçu
	var img := MissionPreview.render(d)
	var b64 := MissionPreview.encode(img)
	var tex := MissionPreview.texture(b64)
	_check(img.get_width() <= MissionPreview.MAX_SIZE.x and tex != null and tex.get_width() == img.get_width(), "aperçu généré, rangé en base64, relu")

