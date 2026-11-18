class_name Content
extends RefCounted
## Catalogue du jeu : tourelles, bâtiments, technos, augments, skins, niveaux.
## Tout ce qui se règle sans toucher aux mécaniques est ici ou dans Balance.

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
}

const TOWER_ORDER: Array[String] = ["gun", "cannon", "missile", "laser"]

const HOUSE := {"name": "Habitat", "desc": "+3 de population max.", "metal": 60, "essence": 0, "hp": 150, "pop": 3}
const BASE_POP := 6

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

const LEVELS: Array[Dictionary] = [
	{"id": 1, "map": "res://maps/map_01.gd", "waves": 10, "difficulty": 0.75},
	{"id": 2, "map": "res://maps/map_02.gd", "waves": 12, "difficulty": 0.9},
	{"id": 3, "map": "res://maps/map_03.gd", "waves": 15, "difficulty": 1.0},
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


## Coût d'un bâtiment ("house" ou un type de tourelle).
static func building(kind: String) -> Dictionary:
	return HOUSE if kind == "house" else TOWERS[kind]
