class_name EditorDoc
extends RefCounted
## Mission en cours d'édition : carte (une lettre par case), objets nommés, réglages.
## Chargée depuis / convertie vers MapData (fichier unique, versionné).

const VERSION := 2
## Rôles des zones (seules la prise et l'arrivée ont un effet sans déclencheur).
const ZONE_ROLES := {"capture": "Zone de prise", "goal": "Zone d'arrivée", "extraction": "Zone d'extraction",
		"passage": "Zone de passage", "trigger": "Zone déclencheur"}
## Noms affichés des ennemis.
const ENEMY_NAMES := {
	"normal": "Rampant", "fast": "Coureur", "armored": "Blindé", "flying": "Volant", "boss": "Boss",
	"swarmer": "Nuée", "spitter": "Cracheur", "brute": "Brute", "shell": "Carapace", "siege": "Char de siège",
	"mothership": "Vaisseau-mère",
}

var name := "Nouvelle carte"
var ground := "grass"
var rows: Array[String] = []
var entities: Array = [] # {id, name, kind, cell:[x,y], ...}
var mission: Dictionary = {}
var waves := 10
var difficulty := 1.0
var interval := 30.0
var objectives: Array = []
var scenario: Dictionary = {}
var wave_plan: Dictionary = {}
var factions: Dictionary = {}
## Vrai si l'ouverture a généré les objectifs du modèle (mission d'une ancienne version).
var converted := false
var path := ""
var next_id := 1


# --- Chargement / enregistrement ---------------------------------------------------------

static func from_map(m: MapData) -> EditorDoc:
	var d := EditorDoc.new()
	d.name = m.NAME
	d.ground = m.GROUND
	for line in m.LAYOUT.split("\n"):
		if line.strip_edges() != "":
			d.rows.append(line.strip_edges())
	# Lignes de longueurs différentes : on complète avec du sol.
	var w := 0
	for r in d.rows:
		w = maxi(w, r.length())
	for i in d.rows.size():
		d.rows[i] += ".".repeat(w - d.rows[i].length())
	d.entities = m.entities.duplicate(true)
	d.mission = m.mission.duplicate(true)
	d.waves = m.waves
	d.difficulty = m.difficulty
	d.interval = m.interval
	d.objectives = m.objectives.duplicate(true)
	d.scenario = m.scenario.duplicate(true)
	d.wave_plan = m.wave_plan.duplicate(true)
	d.factions = m.factions.duplicate(true)
	d.path = m.path
	d.migrate()
	return d


func to_map() -> MapData:
	var m := MapData.new()
	m.NAME = name
	m.GROUND = ground
	m.LAYOUT = "\n".join(rows)
	m.entities = entities.duplicate(true)
	m.mission = mission.duplicate(true)
	m.waves = waves
	m.difficulty = difficulty
	m.interval = interval
	m.objectives = objectives.duplicate(true)
	m.scenario = scenario.duplicate(true)
	m.wave_plan = wave_plan.duplicate(true)
	m.factions = factions.duplicate(true)
	m.path = path
	return m


## Met à niveau une mission d'une version antérieure : identifiant et nom pour chaque objet,
## cases au format [x, y], ordre des points de passage sans trou.
func migrate() -> void:
	var used := {}
	for e: Dictionary in entities:
		if e.has("id"):
			used[int(e.id)] = true
	next_id = 1
	for k in used:
		next_id = maxi(next_id, int(k) + 1)
	for e: Dictionary in entities:
		var c: Variant = e.get("cell", [0, 0])
		if c is Vector2i:
			e.cell = [c.x, c.y]
		else:
			e.cell = [int(c[0]), int(c[1])]
		if not e.has("id"):
			e.id = next_id
			next_id += 1
		e.id = int(e.id)
	# Doublons d'identifiant (fichier édité à la main) : on renumérote.
	var seen := {}
	for e: Dictionary in entities:
		if seen.has(e.id):
			e.id = next_id
			next_id += 1
		seen[e.id] = true
	for e: Dictionary in entities:
		if str(e.get("name", "")) == "":
			e.name = unique_name(base_name(e), e.id)
	renumber_waypoints()
	# Missions d'avant les modèles : le type de mission génère ses objectifs et déclencheurs.
	if not MissionTemplates.has_template(scenario) and scenario.get("objectives", []).is_empty() \
			and str(scenario.get("rules", {}).get("victory", "objectives")) != "manual":
		scenario = MissionTemplates.ensure(scenario, mission, entities)
		converted = true


# --- Grille -------------------------------------------------------------------------------

func width() -> int:
	return rows[0].length() if not rows.is_empty() else 0


func height() -> int:
	return rows.size()


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.y < rows.size() and c.x < rows[c.y].length()


func get_char(c: Vector2i) -> String:
	return rows[c.y][c.x] if inside(c) else ""


func set_char(c: Vector2i, ch: String) -> void:
	if inside(c):
		var line := rows[c.y]
		rows[c.y] = line.substr(0, c.x) + ch + line.substr(c.x + 1)


func resize(w: int, h: int) -> void:
	var out: Array[String] = []
	for y in h:
		var line := rows[y] if y < rows.size() else ""
		line = line.substr(0, w)
		line += ".".repeat(w - line.length())
		out.append(line)
	rows = out
	entities = entities.filter(func(e: Dictionary) -> bool:
		return entity_cells(e).all(func(c: Vector2i) -> bool: return c.x < w and c.y < h))


# --- Objets -------------------------------------------------------------------------------

static func cell_of(e: Dictionary) -> Vector2i:
	return Vector2i(int(e.cell[0]), int(e.cell[1]))


## Taille (en cases) occupée par un objet.
static func entity_size(e: Dictionary) -> Vector2i:
	match str(e.get("kind", "")):
		"structure":
			if Balance.ENEMY_STRUCTURES.has(e.get("type", "")):
				return Vector2i.ONE * int(Balance.ENEMY_STRUCTURES[e.type].size)
		"defend", "building":
			return Vector2i.ONE * int(Content.building(str(e.type)).get("size", 1))
		"deco":
			return Mission.deco_footprint(str(e.get("sprite", "")), int(e.get("rot", 0)))
		"door":
			var n := clampi(int(e.get("len", 2)), 1, 8)
			return Vector2i(1, n) if e.get("vertical", false) else Vector2i(n, 1)
	return Vector2i.ONE


static func entity_rect(e: Dictionary) -> Rect2i:
	return Rect2i(cell_of(e), entity_size(e))


static func entity_cells(e: Dictionary) -> Array[Vector2i]:
	var r := entity_rect(e)
	var out: Array[Vector2i] = []
	for dy in r.size.y:
		for dx in r.size.x:
			out.append(r.position + Vector2i(dx, dy))
	return out


## Identifiant d'outil de la palette correspondant à un objet ("genre:type").
static func entity_tool(e: Dictionary) -> String:
	return str(e.kind) + ":" + str(e.get("type", e.get("role", e.get("sprite", ""))))


func entity_by_id(id: int) -> Dictionary:
	for e: Dictionary in entities:
		if int(e.id) == id:
			return e
	return {}


## Objet le plus en haut sous une case (le dernier posé l'emporte), ou {}.
func entity_at(c: Vector2i, filter := Callable()) -> Dictionary:
	for i in range(entities.size() - 1, -1, -1):
		var e: Dictionary = entities[i]
		if entity_rect(e).has_point(c) and (not filter.is_valid() or filter.call(e)):
			return e
	return {}


## Nom par défaut d'un objet : « Tourelle canon », « Zone de prise », « Décor caisses »…
static func base_name(e: Dictionary) -> String:
	var t := str(e.get("type", ""))
	match str(e.get("kind", "")):
		"structure":
			return str(Balance.ENEMY_STRUCTURES.get(t, {}).get("name", "Structure"))
		"enemy":
			return str(ENEMY_NAMES.get(t, "Ennemi " + t))
		"ally_tower":
			return str(Content.TOWERS.get(t, {}).get("name", "Tourelle"))
		"ally_unit":
			return str(Content.UNITS.get(t, {}).get("name", "Unité"))
		"vip":
			return "VIP"
		"escortee":
			return "Départ convoi"
		"defend":
			return str(Content.building(t).get("name", "Bâtiment")) + " à défendre"
		"building":
			return str(Content.building(t).get("name", "Bâtiment"))
		"waypoint":
			return "Point"
		"zone":
			return str(ZONE_ROLES.get(str(e.get("role", "capture")), "Zone"))
		"door":
			return "Porte"
		"shield":
			return "Bouclier"
		"terminal":
			return "Terminal"
		"prisoners":
			return "Prisonniers"
		"pickup":
			return "Objet à récupérer"
		"deco":
			return "Décor " + str(e.get("sprite", "")).replace("_", " ")
	return "Objet"


## « Tourelle canon 3 » : premier numéro libre pour ce nom.
func unique_name(base: String, except_id := -1) -> String:
	var taken := {}
	for e: Dictionary in entities:
		if int(e.get("id", -1)) != except_id:
			taken[str(e.get("name", ""))] = true
	var n := 1
	while taken.has("%s %d" % [base, n]):
		n += 1
	return "%s %d" % [base, n]


## Ajoute un objet en lui donnant un identifiant et un nom.
func add_entity(e: Dictionary) -> Dictionary:
	e.id = next_id
	next_id += 1
	if str(e.get("name", "")) == "" or entities.any(func(x: Dictionary) -> bool: return x.get("name", "") == e.name):
		e.name = unique_name(base_name(e))
	entities.append(e)
	return e


func remove_ids(ids: Array) -> void:
	entities = entities.filter(func(e: Dictionary) -> bool: return not ids.has(int(e.id)))
	renumber_waypoints()


## Points de passage numérotés 0, 1, 2… dans leur ordre actuel.
func renumber_waypoints() -> void:
	var wps := entities.filter(func(e: Dictionary) -> bool: return e.kind == "waypoint")
	wps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	for i in wps.size():
		wps[i].order = i
		wps[i].name = "Point %d" % (i + 1)


func next_waypoint_order() -> int:
	var n := 0
	for e: Dictionary in entities:
		if e.kind == "waypoint":
			n = maxi(n, int(e.get("order", 0)) + 1)
	return n


# --- Historique -------------------------------------------------------------------------

## État complet modifiable (pour annuler / rétablir).
func snapshot() -> Dictionary:
	return {"rows": rows.duplicate(), "entities": entities.duplicate(true), "mission": mission.duplicate(true),
			"waves": waves, "difficulty": difficulty, "interval": interval, "objectives": objectives.duplicate(true),
			"name": name, "ground": ground, "next_id": next_id, "scenario": scenario.duplicate(true), "wave_plan": wave_plan.duplicate(true), "factions": factions.duplicate(true)}


func restore(s: Dictionary) -> void:
	rows.assign(s.rows)
	entities = s.entities.duplicate(true)
	mission = s.mission.duplicate(true)
	waves = s.waves
	difficulty = s.difficulty
	interval = s.interval
	objectives = s.objectives.duplicate(true)
	name = s.name
	ground = s.ground
	next_id = s.next_id
	scenario = s.get("scenario", {}).duplicate(true)
	wave_plan = s.get("wave_plan", {}).duplicate(true)
	factions = s.get("factions", {}).duplicate(true)
