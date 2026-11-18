extends Node
## Autoload « Save » : progression du joueur, stockée dans user://save.json.

signal changed

const PATH := "user://save.json"
const VERSION := 1

var data := {}


func _ready() -> void:
	load_data()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"credits": 0, # monnaie gagnée en jouant : technos, augments
		"gold": 0, # monnaie premium : skins, tourelles spéciales
		"levels": {}, # "1": {"stars": 3, "best_wave": 10}
		"tech": {}, # id -> niveau
		"augments": {}, # id -> quantité en stock
		"owned": ["skin_classic"],
		"skin": "skin_classic",
		"settings": {"music": 0.8, "sfx": 0.8, "vibration": true, "show_fps": false},
	}


func load_data() -> void:
	data = defaults()
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		for k in parsed:
			data[k] = parsed[k]


func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
	changed.emit()


func reset() -> void:
	data = defaults()
	save_data()


# --- Monnaies -------------------------------------------------------------------

func credits() -> int:
	return int(data.credits)


func gold() -> int:
	return int(data.gold)


func add(currency: String, amount: int) -> void:
	data[currency] = int(data[currency]) + amount
	save_data()


func spend(currency: String, amount: int) -> bool:
	if int(data[currency]) < amount:
		return false
	data[currency] = int(data[currency]) - amount
	save_data()
	return true


# --- Campagne -------------------------------------------------------------------

func level_stars(level_id: int) -> int:
	var l: Variant = data.levels.get(str(level_id))
	return int(l.stars) if l is Dictionary else 0


func is_level_unlocked(level_id: int) -> bool:
	return level_id == 1 or level_stars(level_id - 1) > 0


func record_level(level_id: int, stars: int, wave: int) -> void:
	var key := str(level_id)
	var prev: Dictionary = data.levels.get(key, {"stars": 0, "best_wave": 0})
	data.levels[key] = {"stars": maxi(int(prev.stars), stars), "best_wave": maxi(int(prev.best_wave), wave)}
	save_data()


# --- Technos, augments, boutique ------------------------------------------------

func tech_level(id: String) -> int:
	return int(data.tech.get(id, 0))


func set_tech_level(id: String, lvl: int) -> void:
	data.tech[id] = lvl
	save_data()


func augment_count(id: String) -> int:
	return int(data.augments.get(id, 0))


func change_augment(id: String, delta: int) -> void:
	data.augments[id] = maxi(0, augment_count(id) + delta)
	save_data()


func owns(id: String) -> bool:
	return data.owned.has(id)


func give(id: String) -> void:
	if not owns(id):
		data.owned.append(id)
		save_data()


func setting(key: String) -> Variant:
	return data.settings.get(key, defaults().settings[key])


func set_setting(key: String, value: Variant) -> void:
	data.settings[key] = value
	save_data()
