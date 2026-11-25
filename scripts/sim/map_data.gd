class_name MapData
extends RefCounted
## Une carte jouable : plan en texte + réglages (sol, vagues, difficulté).
## Se charge depuis une carte intégrée (maps/*.gd) ou une carte de l'éditeur (*.json).

const SYMBOL_OF := {
	GameGrid.Cell.EMPTY: ".", GameGrid.Cell.ROCK: "#", GameGrid.Cell.BASE: "B",
	GameGrid.Cell.METAL: "M", GameGrid.Cell.ESSENCE: "E", GameGrid.Cell.SPAWN: "S",
	GameGrid.Cell.WATER: "~", GameGrid.Cell.ROAD: "=", GameGrid.Cell.RAIL: "T",
	GameGrid.Cell.BRIDGE: "H", GameGrid.Cell.RAIL_BRIDGE: "Y", GameGrid.Cell.WALL: "W",
}
## Dossier des cartes de l'éditeur : dans le projet quand on lance depuis Godot (pour les versionner),
## sinon dans les données de l'appli.
const CUSTOM_DIR_EDITOR := "res://maps/custom/"
const CUSTOM_DIR_USER := "user://maps/"

var NAME := "Nouvelle carte" # majuscules : mêmes noms que les constantes des cartes .gd
var GROUND := "grass"
var LAYOUT := ""
var waves := 10
var difficulty := 1.0
var interval := 30.0
## Objectifs bonus : [{"type": "train" | "convoy" | "boat", "wave": n}]
var objectives: Array = []
## Mission (voir Mission) et entités posées dans l'éditeur.
var mission: Dictionary = {}
var entities: Array = []
## Scénario : objectifs, déclencheurs, variables, règles (voir Scenario).
var scenario: Dictionary = {}
## Vagues personnalisées et noms des points d'apparition (voir WaveManager).
var wave_plan: Dictionary = {}
## Factions personnalisées et relations (voir Factions).
var factions: Dictionary = {}
var path := "" # fichier d'origine


static func custom_dir() -> String:
	return CUSTOM_DIR_EDITOR if OS.has_feature("editor") else CUSTOM_DIR_USER


static func load_from(p: String) -> MapData:
	var m := MapData.new()
	m.path = p
	if p.ends_with(".gd"):
		var script: Variant = load(p)
		m.NAME = script.NAME
		m.GROUND = script.GROUND
		m.LAYOUT = script.LAYOUT
		var consts: Dictionary = script.get_script_constant_map()
		if consts.has("OBJECTIVES"):
			m.objectives = script.OBJECTIVES.duplicate(true)
		if consts.has("MISSION"):
			m.mission = script.MISSION.duplicate(true)
		if consts.has("ENTITIES"):
			m.entities = script.ENTITIES.duplicate(true)
		if consts.has("SCENARIO"):
			m.scenario = script.SCENARIO.duplicate(true)
		if consts.has("WAVE_PLAN"):
			m.wave_plan = script.WAVE_PLAN.duplicate(true)
		if consts.has("FACTIONS"):
			m.factions = script.FACTIONS.duplicate(true)
		return m
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not parsed is Dictionary:
		push_error("Carte illisible : %s" % p)
		return m
	m.NAME = parsed.get("name", m.NAME)
	m.GROUND = parsed.get("ground", m.GROUND)
	var rows: Variant = parsed.get("layout", [])
	m.LAYOUT = "\n".join(rows) if rows is Array else str(rows)
	m.waves = int(parsed.get("waves", m.waves))
	m.difficulty = float(parsed.get("difficulty", m.difficulty))
	m.interval = float(parsed.get("interval", m.interval))
	m.objectives = parsed.get("objectives", [])
	m.mission = parsed.get("mission", {})
	m.entities = parsed.get("entities", [])
	m.scenario = parsed.get("scenario", {})
	m.wave_plan = parsed.get("wave_plan", {})
	m.factions = parsed.get("factions", {})
	return m


static func from_grid(g: GameGrid) -> String:
	var rows: Array[String] = []
	for y in g.height:
		var row := ""
		for x in g.width:
			var c := Vector2i(x, y)
			row += "b" if g.base2_cells.has(c) and g.get_cell(c) == GameGrid.Cell.EMPTY else SYMBOL_OF[g.get_cell(c)]
		rows.append(row)
	return "\n".join(rows)


func to_dict() -> Dictionary:
	var rows: Array = []
	for line in LAYOUT.split("\n"):
		if line.strip_edges() != "":
			rows.append(line.strip_edges())
	return {"version": EditorDoc.VERSION, "name": NAME, "ground": GROUND, "waves": waves, "difficulty": difficulty, "interval": interval, "objectives": objectives,
			"mission": mission, "entities": entities, "scenario": scenario, "wave_plan": wave_plan, "factions": factions, "layout": rows}


func save_to(p: String) -> Error:
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	path = p
	return OK


static func slug(name: String) -> String:
	var s := name.to_lower().strip_edges()
	var out := ""
	for ch in s:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif out != "" and not out.ends_with("-"):
			out += "-"
	return out.trim_suffix("-") if out != "" else "carte"


## Cartes de l'éditeur disponibles (chemins).
static func list_custom() -> Array[String]:
	var out: Array[String] = []
	for dir in [CUSTOM_DIR_EDITOR, CUSTOM_DIR_USER]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			if f.ends_with(".json"):
				out.append(dir + f)
	return out


## Problèmes qui empêchent de jouer la carte (liste vide = carte valide).
static func validate(g: GameGrid, mission := {}) -> Array[String]:
	var issues: Array[String] = []
	var needs_spawn := Mission.new(mission).waves_enabled()
	if g.base_cells.size() != 9:
		issues.append("Il faut une base (3x3)")
	if g.spawn_points.is_empty() and needs_spawn:
		issues.append("Il faut au moins un point d'apparition")
	if g.metal_deposits.is_empty():
		issues.append("Il faut au moins un gisement de métal")
	if issues.is_empty():
		var pf := Pathfinder.new(g)
		for sp in g.spawn_points:
			if pf.find_path_to_adjacent(sp, g.base_cells).is_empty():
				issues.append("L'apparition (%d, %d) n'a aucun chemin vers la base" % [sp.x, sp.y])
		var start: Array[Vector2i] = pf.free_cells_around(g.base_cells)
		if start.is_empty():
			issues.append("La base est entièrement entourée de rochers")
		else:
			for m in g.metal_deposits:
				if pf.find_path_to_adjacent(start[0], [m] as Array[Vector2i]).is_empty():
					issues.append("Le métal (%d, %d) est inaccessible" % [m.x, m.y])
					break
		if not g.base2_cells.is_empty():
			if g.base2_cells.size() != 9:
				issues.append("La base du joueur 2 doit faire 3x3")
			elif pf.find_path_to_adjacent(start[0] if not start.is_empty() else g.base_cells[0], g.base2_cells).is_empty():
				issues.append("La base du joueur 2 n'est pas reliée à la base principale")
	return issues
