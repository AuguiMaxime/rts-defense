class_name EditorLayers
extends RefCounted
## Calques de l'éditeur. Chaque lettre de la carte et chaque objet appartient à un calque.
## Un calque masqué ou verrouillé ne peut pas être modifié (on ne touche pas à ce qu'on ne voit pas).

const LIST := [
	{"id": "terrain", "name": "Terrain"},
	{"id": "obstacles", "name": "Obstacles"},
	{"id": "water", "name": "Eau et ponts"},
	{"id": "roads", "name": "Routes et rails"},
	{"id": "resources", "name": "Ressources"},
	{"id": "bases", "name": "Bases"},
	{"id": "spawns", "name": "Apparitions"},
	{"id": "zones", "name": "Zones"},
	{"id": "units", "name": "Unités et structures"},
	{"id": "mission", "name": "Objets de mission"},
	{"id": "deco", "name": "Décors"},
]

const CHAR_LAYER := {
	".": "terrain", "#": "obstacles", "W": "obstacles", "~": "water", "=": "roads", "T": "roads",
	"H": "water", "Y": "water", "M": "resources", "E": "resources", "B": "bases", "b": "bases", "S": "spawns",
}
const KIND_LAYER := {
	"structure": "units", "enemy": "units", "ally_tower": "units", "ally_unit": "units",
	"vip": "mission", "escortee": "mission", "waypoint": "mission", "defend": "mission",
	"zone": "zones", "deco": "deco",
	"door": "mission", "shield": "mission", "terminal": "mission", "prisoners": "mission", "pickup": "mission",
}

var hidden := {}
var locked := {}


static func of_char(ch: String) -> String:
	return CHAR_LAYER.get(ch, "terrain")


static func of_entity(e: Dictionary) -> String:
	return KIND_LAYER.get(str(e.get("kind", "")), "mission")


func visible(layer: String) -> bool:
	return not hidden.get(layer, false)


func editable(layer: String) -> bool:
	return not hidden.get(layer, false) and not locked.get(layer, false)


## Un pont appartient aussi au calque des routes / rails.
func char_editable(ch: String) -> bool:
	if ch == ".":
		return true # le sol nu se recouvre toujours
	if ch == "H":
		return editable("water") and editable("roads")
	if ch == "Y":
		return editable("water") and editable("roads")
	return editable(of_char(ch))


func entity_visible(e: Dictionary) -> bool:
	return visible(of_entity(e))


func entity_editable(e: Dictionary) -> bool:
	return editable(of_entity(e))


## Carte telle qu'affichée : les lettres des calques masqués deviennent du sol.
func display_rows(rows: Array[String]) -> Array[String]:
	if hidden.values().all(func(v: bool) -> bool: return not v):
		return rows
	var out: Array[String] = []
	for r in rows:
		var line := ""
		for ch in r:
			line += _display_char(ch)
		out.append(line)
	return out


func _display_char(ch: String) -> String:
	if ch == "H" or ch == "Y":
		var water := visible("water")
		var road := visible("roads")
		if water and road:
			return ch
		if water:
			return "~"
		if road:
			return "=" if ch == "H" else "T"
		return "."
	return ch if visible(of_char(ch)) else "."
