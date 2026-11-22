class_name WaveManager
extends RefCounted
## Déroulé des waves : minuterie, composition, apparition progressive des ennemis.

var wave := 0 # nombre de waves lancées
var total := Balance.WAVE_COUNT
var infinite := false
var interval := Balance.WAVE_INTERVAL # secondes entre deux vagues
var difficulty := 1.0 # multiplie le nombre d'ennemis de chaque vague
var timer := Balance.FIRST_WAVE_DELAY

var _queue: Array[String] = []
var _spawn_timer := 0.0
var _spawn_index := 0


## Composition de la wave n (1 = première).
static func composition(n: int) -> Array[String]:
	var list: Array[String] = []
	for i in 2 + n * 2 + n * n / 10:
		list.append("normal")
	if n >= 2:
		for i in n:
			list.insert(mini(list.size(), i * 3 + 1), "fast")
	if n >= 4:
		for i in (n - 2) / 2:
			list.append("armored")
	if n >= 5:
		for i in (n - 3) / 2:
			list.insert(list.size() / 2, "flying")
	# Aliens : nuées rapides, cracheurs à distance, carapaces blindées, brutes, artillerie.
	if n >= 4:
		for i in n / 2:
			list.insert(mini(list.size(), i * 4 + 2), "swarmer")
	if n >= 4:
		for i in (n - 2) / 3:
			list.insert(list.size() / 3, "spitter")
	if n >= 7:
		for i in (n - 5) / 3:
			list.append("shell")
	if n >= 8:
		for i in (n - 6) / 4:
			list.append("brute")
	if n >= 11:
		for i in (n - 9) / 3:
			list.append("siege")
	if n % Balance.BOSS_EVERY == 0:
		# Un boss sur deux est le vaisseau-mère volant.
		var air := (n / Balance.BOSS_EVERY) % 2 == 0
		for i in n / Balance.BOSS_EVERY:
			list.append("mothership" if air and i == 0 else "boss")
	return list


static func is_boss_wave(n: int) -> bool:
	return n > 0 and n % Balance.BOSS_EVERY == 0


func tick(delta: float, world: GameWorld) -> void:
	if not _queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			var spawns := world.grid.spawn_points
			world.spawn_enemy(_queue.pop_front(), spawns[_spawn_index % spawns.size()], hp_scale())
			_spawn_index += 1
			_spawn_timer = Balance.SPAWN_INTERVAL
	if has_more_waves():
		timer -= delta
		if timer <= 0.0:
			start_next()


func start_next() -> void:
	if not has_more_waves():
		return
	wave += 1
	var list := composition(wave)
	var bosses := list.filter(func(t: String) -> bool: return Balance.BOSSES.has(t))
	list = list.filter(func(t: String) -> bool: return not Balance.BOSSES.has(t))
	var keep := maxi(2, roundi(list.size() * difficulty))
	# On retire des ennemis répartis dans la liste pour garder le mélange des types.
	while list.size() > keep:
		list.remove_at(list.size() * 2 / 3 if list.size() > 2 else 0)
	var base_count := list.size()
	var i := 0
	while list.size() < keep and base_count > 0:
		# Difficulté > 1 : on ajoute des renforts copiés de la vague, répartis dans la file.
		list.insert(mini(list.size(), i * 2 + 1), list[i % base_count])
		i += 1
	_queue.append_array(list)
	_queue.append_array(bosses) # le boss arrive en dernier
	timer = interval


func has_more_waves() -> bool:
	return infinite or wave < total


func hp_scale() -> float:
	return 1.0 + Balance.WAVE_HP_GROWTH * (wave - 1)


## Toutes les waves de la map ont été envoyées.
func finished() -> bool:
	return not has_more_waves() and _queue.is_empty()
