class_name NetSync
extends RefCounted
## Photo de l'état du jeu envoyée par l'hôte, et application de cette photo côté client.
## Formats compacts (tableaux) pour limiter la taille des paquets.

const ENEMY_TYPES: Array[String] = ["normal", "fast", "armored", "flying", "boss"]
const TOWER_KINDS: Array[String] = ["gun", "cannon", "missile", "laser", "house"]


static func snapshot(w: GameWorld) -> Dictionary:
	var workers := []
	for x in w.workers:
		workers.append([x.id, x.pos.x, x.pos.y, x.facing.x, x.facing.y, x.state, x.job, x.carry_type, x.carry_amount, x.hp])
	var enemies := []
	for e in w.enemies:
		if e.hp > 0:
			enemies.append([e.id, ENEMY_TYPES.find(e.type), e.pos.x, e.pos.y, e.facing.x, e.facing.y, e.hp, e.max_hp,
					e.visual_offset.x, e.visual_offset.y])
	var sites := []
	for s in w.sites:
		sites.append([s.id, TOWER_KINDS.find(s.kind), s.cell.x, s.cell.y, s.built, s.work_done, s.work_needed,
				s.hp, s.max_hp, s.level, s.aim_angle, s.beam_target.id if s.beam_target != null else -1])
	return {
		"r": [w.metal, w.essence, w.base_hp, w.max_base_hp, w.pop_cap, w.train_queue, w.kills, w.state, w.orbital_cooldown],
		"v": [w.waves.wave, w.waves.total, w.waves.infinite, w.waves.timer, w.waves.interval],
		"w": workers,
		"e": enemies,
		"s": sites,
		"ev": w.take_net_events(),
	}


static func apply(w: GameWorld, snap: Dictionary) -> void:
	var r: Array = snap.r
	w.metal = r[0]
	w.essence = r[1]
	w.base_hp = r[2]
	w.max_base_hp = r[3]
	w.pop_cap = r[4]
	w.train_queue = r[5]
	w.kills = r[6]
	w.state = r[7]
	w.orbital_cooldown = r[8]
	var v: Array = snap.v
	w.waves.wave = v[0]
	w.waves.total = v[1]
	w.waves.infinite = v[2]
	w.waves.timer = v[3]
	w.waves.interval = v[4]

	# Ouvriers
	var by_id := {}
	for x in w.workers:
		by_id[x.id] = x
	var workers: Array[Worker] = []
	for a in snap.w:
		var x: Worker = by_id.get(int(a[0]))
		var target := Vector2(a[1], a[2])
		if x == null:
			x = Worker.new()
			x.id = a[0]
			x.pos = target
		x.net_target = target
		x.facing = Vector2(a[3], a[4])
		x.state = a[5]
		x.job = a[6]
		x.carry_type = a[7]
		x.carry_amount = a[8]
		x.hp = a[9]
		workers.append(x)
	for old in w.workers:
		if not workers.has(old):
			old.alive = false
	w.workers = workers

	# Ennemis
	by_id.clear()
	for e in w.enemies:
		by_id[e.id] = e
	var enemies: Array[Enemy] = []
	for a in snap.e:
		var e: Enemy = by_id.get(int(a[0]))
		var target := Vector2(a[2], a[3])
		if e == null:
			e = Enemy.create(ENEMY_TYPES[a[1]], target, 1.0)
			e.id = a[0]
		e.net_target = target
		e.facing = Vector2(a[4], a[5])
		e.hp = a[6]
		e.max_hp = a[7]
		e.visual_offset = Vector2(a[8], a[9])
		enemies.append(e)
	w.enemies = enemies

	# Bâtiments (et cases bloquées, pour que le client puisse vérifier ses placements)
	var site_by_id := {}
	for s in w.sites:
		site_by_id[s.id] = s
	var enemy_by_id := {}
	for e in enemies:
		enemy_by_id[e.id] = e
	var sites: Array[BuildSite] = []
	for a in snap.s:
		var s: BuildSite = site_by_id.get(int(a[0]))
		if s == null:
			s = BuildSite.new(TOWER_KINDS[a[1]])
			s.id = a[0]
			s.cell = Vector2i(a[2], a[3])
			w.pathfinder.set_solid(s.cell, true)
		s.built = a[4]
		s.work_done = a[5]
		s.work_needed = a[6]
		s.hp = a[7]
		s.max_hp = a[8]
		s.level = a[9]
		s.aim_angle = a[10]
		s.beam_target = enemy_by_id.get(int(a[11]))
		sites.append(s)
	for old in w.sites:
		if not sites.has(old):
			old.alive = false
			w.pathfinder.set_solid(old.cell, false)
	w.sites = sites

	for ev in snap.ev:
		w.events.append(ev)


## Rapproche en douceur les positions affichées des positions reçues (client).
static func interpolate(w: GameWorld, delta: float) -> void:
	var k := minf(1.0, delta * 12.0)
	for x in w.workers:
		if x.net_target != Vector2.INF:
			x.pos = x.pos.lerp(x.net_target, k)
	for e in w.enemies:
		if e.net_target != Vector2.INF:
			e.pos = e.pos.lerp(e.net_target, k)
