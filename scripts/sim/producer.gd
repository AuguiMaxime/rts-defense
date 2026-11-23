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
	if not busy():
		return 1.0
	return item_time(queue[0])


## Élément de file : un type d'unité, ou "r:<id>:<niveau>" pour une recherche.
static func is_research(item: String) -> bool:
	return item.begins_with("r:")


static func research_id(item: String) -> String:
	return item.split(":")[1]


static func research_level(item: String) -> int:
	return int(item.split(":")[2])


static func item_time(item: String) -> float:
	if is_research(item):
		return Content.RESEARCH_TIME[research_level(item) - 1]
	return float(Content.UNITS[item].time)


static func item_name(item: String) -> String:
	if is_research(item):
		return "%s %d" % [Content.RESEARCH[research_id(item)].name, research_level(item)]
	return Content.UNITS[item].name


static func item_cost(item: String) -> Dictionary:
	if is_research(item):
		var l := research_level(item) - 1
		return {"metal": Content.RESEARCH_METAL[l], "essence": Content.RESEARCH_ESSENCE[l]}
	return {"metal": int(Content.UNITS[item].metal), "essence": int(Content.UNITS[item].essence)}


func ratio() -> float:
	return clampf(progress / current_time(), 0.0, 1.0) if busy() else 0.0


func has_rally() -> bool:
	return rally.x >= 0


## Place occupée par la file (comptée dans la population dès la mise en file, comme dans StarCraft).
func queued_pop() -> int:
	var n := 0
	for t in queue:
		if not is_research(t):
			n += int(Content.UNITS[t].pop)
	return n
