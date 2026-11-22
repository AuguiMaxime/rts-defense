class_name Content
extends RefCounted
## Catalogue du jeu : tourelles, bâtiments, technos, augments, skins, niveaux.
## Tout ce qui se règle sans toucher aux mécaniques est ici ou dans Balance.

## Outils de développement (éditeur de cartes). À passer à false pour la mise en ligne.
const DEV_TOOLS := true

## targets : "ground", "air" ou "both". splash : rayon de dégâts de zone en cases.
## unlock : "default" ou "gold" (à acheter dans la boutique).
const TOWERS := {
	"gun": {
		"name": "Mitrailleuse", "desc": "Tir rapide, touche le sol et l'air.",
		"metal": 75, "essence": 0, "range": 4.0, "damage": 12, "delay": 0.5,
		"targets": "both", "splash": 0.0, "hp": 200, "unlock": "default",
	},
	"cannon": {
		"name": "Canon lourd", "desc": "Gros dégâts de zone, perce l'armure. Sol uniquement.",
		"metal": 100, "essence": 20, "range": 4.5, "damage": 45, "delay": 1.6,
		"targets": "ground", "splash": 0.9, "hp": 260, "unlock": "default",
	},
	"missile": {
		"name": "Anti-air", "desc": "Missiles longue portée contre les volants.",
		"metal": 80, "essence": 15, "range": 6.5, "damage": 34, "delay": 0.9,
		"targets": "air", "splash": 0.0, "hp": 180, "unlock": "default",
	},
	"laser": {
		"name": "Laser", "desc": "Rayon continu, courte portée. Sol et air.",
		"metal": 90, "essence": 30, "range": 3.2, "damage": 4, "delay": 0.1,
		"targets": "both", "splash": 0.0, "hp": 180, "unlock": "gold", "price_gold": 300,
	},
	"flame": {
		"name": "Lance-flammes", "desc": "Cône de feu à courte portée : brûle tous les ennemis au sol devant lui.",
		"metal": 90, "essence": 20, "range": 2.6, "damage": 7, "delay": 0.2,
		"targets": "ground", "splash": 0.0, "hp": 260, "unlock": "default", "effect": "cone",
	},
	"sniper_tower": {
		"name": "Tour sniper", "desc": "Portée immense, un tir dévastateur toutes les 3 s.",
		"metal": 110, "essence": 30, "range": 9.0, "damage": 95, "delay": 2.8,
		"targets": "both", "splash": 0.0, "hp": 160, "unlock": "default",
	},
	"tesla": {
		"name": "Tour électrique", "desc": "Arc électrique qui rebondit sur 4 ennemis proches.",
		"metal": 100, "essence": 25, "range": 4.0, "damage": 20, "delay": 1.1,
		"targets": "both", "splash": 0.0, "hp": 200, "unlock": "default", "effect": "chain", "chain": 4, "chain_range": 2.2,
	},
	"cryo": {
		"name": "Tour cryo", "desc": "Gèle une zone : -50 % de vitesse pendant 2 s.",
		"metal": 85, "essence": 20, "range": 4.0, "damage": 5, "delay": 0.9,
		"targets": "both", "splash": 1.1, "hp": 200, "unlock": "default", "effect": "slow", "slow": 0.5, "slow_time": 2.0,
	},
	"stun": {
		"name": "Tour à impulsion", "desc": "Onde de choc qui étourdit les ennemis 1 s (0,5 s pour un boss).",
		"metal": 120, "essence": 40, "range": 3.5, "damage": 12, "delay": 3.5,
		"targets": "both", "splash": 1.5, "hp": 220, "unlock": "default", "effect": "stun", "stun": 1.0,
	},
}

const TOWER_ORDER: Array[String] = ["gun", "cannon", "missile", "laser", "flame", "sniper_tower", "tesla", "cryo", "stun"]
const BUILDING_ORDER: Array[String] = ["house", "barracks", "factory"]

const HOUSE := {"name": "Habitat", "desc": "+5 de population max.", "metal": 60, "essence": 0, "hp": 150, "pop": 5, "size": 1, "build": 6.0}
const BASE_POP := 10

## Bâtiments de production (2x2 cases). produces = unités formées.
const PRODUCTION := {
	"barracks": {
		"name": "Caserne", "desc": "Forme l'infanterie : soldat, guerrier, grenadier, sniper, médic.",
		"metal": 150, "essence": 0, "hp": 500, "size": 2, "build": 14.0,
		"produces": ["soldier", "warrior", "grenadier", "sniper", "medic"],
	},
	"factory": {
		"name": "Usine", "desc": "Fabrique les unités mécaniques : char, mécha anti-air.",
		"metal": 200, "essence": 60, "hp": 650, "size": 2, "build": 18.0,
		"produces": ["tank", "aa_mech"],
	},
}
const BUILD_ORDER: Array[String] = TOWER_ORDER + BUILDING_ORDER

## Ce que forme la base.
const BASE_PRODUCES: Array[String] = ["worker", "soldier"]

## Unités du joueur. time = secondes de formation ; pop = place occupée ;
## targets : "ground", "air", "both" ("none" = ne combat pas) ; splash = rayon de zone en cases.
## ability : pouvoir activable (id dans ABILITIES) ; passive : effet permanent.
const UNITS := {
	"worker": {"name": "Ouvrier", "desc": "Récolte, construit et répare.", "metal": 50, "essence": 0, "time": 4.0, "pop": 1},
	"soldier": {
		"name": "Soldat", "desc": "Infanterie polyvalente, sol et air.", "metal": 50, "essence": 0, "time": 5.0, "pop": 1,
		"hp": 60, "speed": 2.2, "damage": 7, "range": 3.5, "delay": 0.6, "armor": 0, "targets": "both", "splash": 0.0,
		"ability": "stim",
	},
	"warrior": {
		"name": "Guerrier", "desc": "Fantassin de corps à corps, solide et pas cher. Sol uniquement.", "metal": 50, "essence": 0, "time": 5.0, "pop": 1,
		"hp": 100, "speed": 2.4, "damage": 10, "range": 0.9, "delay": 0.7, "armor": 1, "targets": "ground", "splash": 0.0,
		"ability": "charge", "melee": true,
	},
	"grenadier": {
		"name": "Grenadier", "desc": "Colosse de corps à corps, frappe de zone. Sol uniquement.", "metal": 80, "essence": 25, "time": 7.0, "pop": 1,
		"hp": 150, "speed": 1.9, "damage": 20, "range": 1.0, "delay": 1.1, "armor": 2, "targets": "ground", "splash": 0.7,
		"ability": "bastion", "melee": true,
	},
	"sniper": {
		"name": "Sniper", "desc": "Très longue portée, gros dégâts. Passif : son premier tir sur une cible est critique (x3).", "metal": 90, "essence": 40, "time": 8.0, "pop": 1,
		"hp": 45, "speed": 2.0, "damage": 42, "range": 6.5, "delay": 1.8, "armor": 0, "targets": "both", "splash": 0.0,
		"passive": "first_crit",
	},
	"medic": {
		"name": "Médic", "desc": "Soigne en continu les unités proches (10 PV/s).", "metal": 60, "essence": 20, "time": 6.0, "pop": 1,
		"hp": 55, "speed": 2.2, "damage": 0, "range": 3.0, "delay": 1.0, "armor": 0, "targets": "none", "splash": 0.0,
		"heal": 10.0, "ability": "nanoheal",
	},
	"tank": {
		"name": "Char", "desc": "Blindé, canon lourd à dégâts de zone. Mode siège : immobile, portée énorme. Sol uniquement.", "metal": 150, "essence": 75, "time": 12.0, "pop": 3,
		"hp": 280, "speed": 1.5, "damage": 32, "range": 4.5, "delay": 1.4, "armor": 4, "targets": "ground", "splash": 0.8,
		"ability": "siege",
	},
	"aa_mech": {
		"name": "Mécha AA", "desc": "Marcheur anti-aérien, rafales de missiles.", "metal": 120, "essence": 60, "time": 10.0, "pop": 2,
		"hp": 190, "speed": 1.8, "damage": 16, "range": 5.5, "delay": 0.5, "armor": 2, "targets": "air", "splash": 0.0,
		"ability": "salvo",
	},
}

## Pouvoirs des unités. cd = recharge (s), dur = durée (s). toggle = bascule (mode siège).
const ABILITIES := {
	"stim": {"name": "Stimulant", "short": "STIM", "desc": "+25 % de dégâts et de vitesse pendant 5 s", "cd": 30.0, "dur": 5.0},
	"charge": {"name": "Charge", "short": "CHARGE", "desc": "+60 % de vitesse pendant 4 s", "cd": 20.0, "dur": 4.0},
	"bastion": {"name": "Bastion", "short": "BASTION", "desc": "+4 armure et +50 % de PV max pendant 5 s", "cd": 30.0, "dur": 5.0},
	"nanoheal": {"name": "Nanosoin", "short": "NANOSOIN", "desc": "Soigne 60 PV aux unités dans un rayon de 3 cases", "cd": 25.0, "dur": 0.0, "amount": 60, "radius": 3.0},
	"siege": {"name": "Mode siège", "short": "SIÈGE", "desc": "Immobile mais portée 9 et +40 % de dégâts", "cd": 2.0, "dur": 0.0, "toggle": true},
	"salvo": {"name": "Salve", "short": "SALVE", "desc": "Cadence de tir doublée pendant 5 s", "cd": 30.0, "dur": 5.0},
}
const SIEGE_RANGE := 9.0

const ORBITAL := {"name": "Frappe orbitale", "damage": 140, "radius": 2.0, "cooldown": 40.0}

## Arbre de technos (crédits). value = bonus par niveau.
const TECH: Array[Dictionary] = [
	{"id": "hull", "name": "Coque renforcée", "desc": "+15 % de PV pour la base", "costs": [60, 140, 260], "value": 0.15},
	{"id": "ammo", "name": "Munitions perforantes", "desc": "+10 % de dégâts des tourelles", "costs": [80, 180, 320], "value": 0.10},
	{"id": "logistics", "name": "Logistique", "desc": "+10 % de vitesse et +1 de charge des ouvriers", "costs": [70, 160, 300], "value": 0.10},
	{"id": "reserves", "name": "Réserves", "desc": "+50 de métal au départ", "costs": [50, 120, 220], "value": 50},
	{"id": "orbital", "name": "Frappe orbitale", "desc": "Débloque le pouvoir de base : rayon depuis l'orbite", "costs": [250], "value": 1},
]

## Augments : bonus à usage unique, consommés au lancement d'une partie (crédits).
const AUGMENTS: Array[Dictionary] = [
	{"id": "starter_kit", "name": "Kit de démarrage", "desc": "+150 de métal au début de la prochaine partie", "cost": 40},
	{"id": "extra_workers", "name": "Équipe de renfort", "desc": "+2 ouvriers au début de la prochaine partie", "cost": 60},
	{"id": "shield", "name": "Bouclier de base", "desc": "+300 PV de base pour la prochaine partie", "cost": 75},
]

## Skins de tourelles (or) : purement cosmétiques.
const SKINS: Array[Dictionary] = [
	{"id": "skin_classic", "name": "Classique", "tint": Color(1, 1, 1), "price_gold": 0},
	{"id": "skin_cobalt", "name": "Cobalt", "tint": Color(0.55, 0.80, 1.0), "price_gold": 120},
	{"id": "skin_magma", "name": "Magma", "tint": Color(1.0, 0.62, 0.45), "price_gold": 120},
	{"id": "skin_spectre", "name": "Spectre", "tint": Color(0.85, 0.65, 1.0), "price_gold": 200},
]

## Packs d'or (achat réel, à brancher sur le Play Store plus tard).
const GOLD_PACKS: Array[Dictionary] = [
	{"gold": 100, "price": "0,99 €"},
	{"gold": 550, "price": "4,99 €"},
	{"gold": 1200, "price": "9,99 €"},
]
const AD_REWARD_GOLD := 25

## Missions du jour : 3 tirées au hasard chaque jour. stat = compteur de partie (GameWorld.stats).
const MISSIONS: Array[Dictionary] = [
	{"id": "kills", "text": "Détruis %d ennemis", "stat": "kills", "goal": 150, "reward": 40},
	{"id": "kills_big", "text": "Détruis %d ennemis", "stat": "kills", "goal": 400, "reward": 90},
	{"id": "towers", "text": "Construis %d tourelles", "stat": "towers_built", "goal": 15, "reward": 40},
	{"id": "upgrades", "text": "Améliore %d tourelles", "stat": "upgrades", "goal": 5, "reward": 45},
	{"id": "workers", "text": "Forme %d ouvriers", "stat": "workers_trained", "goal": 10, "reward": 35},
	{"id": "waves", "text": "Survis à %d vagues", "stat": "waves", "goal": 20, "reward": 50},
	{"id": "boss", "text": "Détruis %d boss", "stat": "boss_kills", "goal": 2, "reward": 70},
	{"id": "win", "text": "Gagne %d partie(s)", "stat": "wins", "goal": 1, "reward": 60},
	{"id": "houses", "text": "Construis %d habitats", "stat": "houses_built", "goal": 4, "reward": 35},
	{"id": "metal", "text": "Récolte %d métal", "stat": "metal_harvested", "goal": 1500, "reward": 45},
]
const DAILY_LOGIN_GOLD := 10

const LEVELS: Array[Dictionary] = [
	{"id": 1, "map": "res://maps/map_01.gd", "waves": 10, "difficulty": 1.0},
	{"id": 2, "map": "res://maps/map_02.gd", "waves": 12, "difficulty": 1.15},
	{"id": 3, "map": "res://maps/map_03.gd", "waves": 15, "difficulty": 1.3},
	{"id": 4, "map": "res://maps/map_04.gd", "waves": 16, "difficulty": 1.35, "interval": 26.0},
	{"id": 5, "map": "res://maps/map_05.gd", "waves": 16, "difficulty": 1.5, "interval": 22.0},
]


static func level(id: int) -> Dictionary:
	for l in LEVELS:
		if l.id == id:
			return l
	return LEVELS[0]


static func tech(id: String) -> Dictionary:
	for t in TECH:
		if t.id == id:
			return t
	return {}


static func skin(id: String) -> Dictionary:
	for s in SKINS:
		if s.id == id:
			return s
	return SKINS[0]


## Fiche d'un bâtiment : tourelle, "house", "barracks" ou "factory".
static func building(kind: String) -> Dictionary:
	if kind == "house":
		return HOUSE
	if PRODUCTION.has(kind):
		return PRODUCTION[kind]
	return TOWERS[kind]


static func is_tower(kind: String) -> bool:
	return TOWERS.has(kind)
