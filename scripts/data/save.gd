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
		"survival": {}, # "1": meilleure vague en mode Survie
		"tutorial_done": false,
		"daily": {}, # {"date": "AAAA-MM-JJ", "missions": [{"id", "progress", "claimed"}], "login": bool}
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


func survival_record(level_id: int) -> int:
	return int(data.survival.get(str(level_id), 0))


## Renvoie true si c'est un nouveau record.
func record_survival(level_id: int, wave: int) -> bool:
	if wave <= survival_record(level_id):
		return false
	data.survival[str(level_id)] = wave
	save_data()
	return true


# --- Missions du jour -------------------------------------------------------------

func today() -> String:
	return Time.get_date_string_from_system()


## Tire les 3 missions du jour si la date a changé.
func ensure_daily() -> void:
	var d: Dictionary = data.get("daily", {})
	if d.get("date", "") == today():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today())
	var pool := Content.MISSIONS.duplicate()
	var picked := []
	var stats_used := []
	while picked.size() < 3 and not pool.is_empty():
		var m: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		if stats_used.has(m.stat):
			continue
		stats_used.append(m.stat)
		picked.append({"id": m.id, "progress": 0, "claimed": false})
	data.daily = {"date": today(), "missions": picked, "login": false}
	save_data()


func daily_missions() -> Array:
	ensure_daily()
	return data.daily.missions


func mission_def(id: String) -> Dictionary:
	for m in Content.MISSIONS:
		if m.id == id:
			return m
	return {}


## Ajoute les compteurs d'une partie terminée aux missions du jour.
func add_mission_progress(game_stats: Dictionary) -> void:
	for m in daily_missions():
		var def := mission_def(m.id)
		if not def.is_empty() and not m.claimed:
			m.progress = mini(int(def.goal), int(m.progress) + int(game_stats.get(def.stat, 0)))
	save_data()


func claimable_count() -> int:
	var n := 0
	for m in daily_missions():
		if not m.claimed and int(m.progress) >= int(mission_def(m.id).get("goal", 1)):
			n += 1
	if not data.daily.get("login", false):
		n += 1
	return n


func claim_mission(index: int) -> int:
	var m: Dictionary = daily_missions()[index]
	var def := mission_def(m.id)
	if m.claimed or int(m.progress) < int(def.goal):
		return 0
	m.claimed = true
	add("credits", int(def.reward))
	return int(def.reward)


func claim_login() -> bool:
	ensure_daily()
	if data.daily.get("login", false):
		return false
	data.daily.login = true
	add("gold", Content.DAILY_LOGIN_GOLD)
	return true


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
