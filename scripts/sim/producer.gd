class_name Producer
extends RefCounted
## File de production d'un bâtiment (base, caserne, usine) et son point de ralliement.

const MAX_QUEUE := 5

var queue: Array[String] = []
var progress := 0.0 # secondes écoulées sur l'unité en tête de file
var rally := Vector2i(-1, -1) # case de ralliement ; (-1, -1) = aucune


func busy() -> bool:
	return not queue.is_empty()


func current_time() -> float:
	return float(Content.UNITS[queue[0]].time) if busy() else 1.0


func ratio() -> float:
	return clampf(progress / current_time(), 0.0, 1.0) if busy() else 0.0


func has_rally() -> bool:
	return rally.x >= 0


## Place occupée par la file (comptée dans la population dès la mise en file, comme dans StarCraft).
func queued_pop() -> int:
	var n := 0
	for t in queue:
		n += int(Content.UNITS[t].pop)
	return n
