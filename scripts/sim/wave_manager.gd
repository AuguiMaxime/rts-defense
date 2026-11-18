class_name WaveManager
extends RefCounted
## Déroulé des waves : minuterie, composition, apparition progressive des ennemis.

var wave := 0 # nombre de waves lancées
var total := Balance.WAVE_COUNT
var infinite := false
var timer := Balance.FIRST_WAVE_DELAY

var _queue: Array[String] = []
var _spawn_timer := 0.0
var _spawn_index := 0


## Composition de la wave n (1 = première).
static func composition(n: int) -> Array[String]:
	var list: Array[String] = []
	for i in 3 + n * 3:
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
	return list


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
	_queue.append_array(composition(wave))
	timer = Balance.WAVE_INTERVAL


func has_more_waves() -> bool:
	return infinite or wave < total


func hp_scale() -> float:
	return 1.0 + Balance.WAVE_HP_GROWTH * (wave - 1)


## Toutes les waves de la map ont été envoyées.
func finished() -> bool:
	return not has_more_waves() and _queue.is_empty()
