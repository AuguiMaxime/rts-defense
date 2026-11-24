class_name Balance
extends RefCounted
## Tous les chiffres d'équilibrage au même endroit.

const START_METAL := 200
const START_ESSENCE := 0
const START_WORKERS := 3

const WORKER_COST_METAL := 50
const WORKER_TRAIN_TIME := 4.0 # secondes
const WORKER_SPEED := 2.5 # cases par seconde
const CARRY_CAPACITY := 8 # minerai rapporté par voyage
const HARVEST_TIME := 2.0 # secondes au gisement
const METAL_PER_DEPOSIT := 1200 # quantité d'un gisement de métal (≈ 150 voyages)
const ESSENCE_PER_DEPOSIT := 1200 # quantité d'un gisement d'essence

const TOWER_COST_METAL := 75
const TOWER_BUILD_WORK := 10.0 # secondes pour 1 ouvrier, divisé par le nombre d'ouvriers
const TOWER_HP := 200

const BASE_HP := 1000
const WORKER_HP := 60
const SITE_HP := 60 # PV d'un chantier pas encore terminé

# Tourelle de base (l'étape 4 ajoutera les autres types)
const TOWER_RANGE := 4.0 # cases
const TOWER_DAMAGE := 12
const TOWER_FIRE_DELAY := 0.5 # secondes entre deux tirs

# Waves
const FIRST_WAVE_DELAY := 50.0 # temps pour lancer son économie
const WAVE_INTERVAL := 30.0
const WAVE_COUNT := 10 # waves à survivre pour gagner la map
const SPAWN_INTERVAL := 0.7
const WAVE_HP_GROWTH := 0.16 # +16 % de PV ennemis par vague

## armor : retiré à chaque coup reçu (minimum 1 dégât).
const ENEMIES := {
	"normal": {"hp": 40, "speed": 1.3, "damage": 6, "range": 0.8, "cooldown": 1.0, "armor": 0, "flying": false},
	"fast": {"hp": 22, "speed": 2.6, "damage": 4, "range": 0.7, "cooldown": 0.7, "armor": 0, "flying": false},
	"armored": {"hp": 150, "speed": 0.8, "damage": 15, "range": 0.9, "cooldown": 1.4, "armor": 5, "flying": false},
	"flying": {"hp": 35, "speed": 1.8, "damage": 5, "range": 2.5, "cooldown": 1.2, "armor": 0, "flying": true},
	"boss": {"hp": 600, "speed": 0.55, "damage": 40, "range": 1.2, "cooldown": 1.5, "armor": 5, "flying": false},
	# Nouveaux ennemis
	"swarmer": {"hp": 14, "speed": 3.0, "damage": 3, "range": 0.6, "cooldown": 0.6, "armor": 0, "flying": false},
	"spitter": {"hp": 40, "speed": 1.1, "damage": 6, "range": 2.8, "cooldown": 1.8, "armor": 0, "flying": false},
	"brute": {"hp": 200, "speed": 0.9, "damage": 25, "range": 1.0, "cooldown": 1.3, "armor": 2, "flying": false},
	"shell": {"hp": 100, "speed": 0.9, "damage": 10, "range": 0.8, "cooldown": 1.2, "armor": 6, "flying": false},
	"siege": {"hp": 170, "speed": 0.6, "damage": 18, "range": 2.6, "cooldown": 2.8, "armor": 4, "flying": false},
	"mothership": {"hp": 900, "speed": 0.45, "damage": 30, "range": 3.0, "cooldown": 1.4, "armor": 3, "flying": true},
}
## Structures et unités ennemies posées dans l'éditeur de missions.
## size = côté en cases (bloque le passage) ; spawn = type d'ennemi produit toutes les spawn_every secondes.
const ENEMY_STRUCTURES := {
	"e_tower_gun": {"name": "Tourelle ennemie", "hp": 300, "speed": 0.0, "damage": 10, "range": 4.5, "cooldown": 0.6, "armor": 2, "flying": false, "size": 1, "look": "gun"},
	"e_tower_cannon": {"name": "Canon ennemi", "hp": 400, "speed": 0.0, "damage": 30, "range": 5.0, "cooldown": 1.8, "armor": 3, "flying": false, "size": 1, "look": "cannon"},
	"e_tower_missile": {"name": "Lance-missiles ennemi", "hp": 300, "speed": 0.0, "damage": 18, "range": 6.0, "cooldown": 1.2, "armor": 2, "flying": false, "size": 1, "look": "missile"},
	"e_tower_laser": {"name": "Laser ennemi", "hp": 280, "speed": 0.0, "damage": 22, "range": 5.0, "cooldown": 0.9, "armor": 2, "flying": false, "size": 1, "look": "laser"},
	"e_siege_tank": {"name": "Char ennemi en siège", "hp": 350, "speed": 0.0, "damage": 35, "range": 8.0, "cooldown": 3.0, "armor": 5, "flying": false, "size": 1, "look": "siege"},
	"e_bunker": {"name": "Bunker ennemi", "hp": 650, "speed": 0.0, "damage": 12, "range": 4.0, "cooldown": 0.8, "armor": 4, "flying": false, "size": 2, "look": "bunker"},
	"e_barracks": {"name": "Caserne ennemie", "hp": 800, "speed": 0.0, "damage": 0, "range": 0.0, "cooldown": 1.0, "armor": 3, "flying": false, "size": 2, "look": "barracks", "spawn": "normal", "spawn_every": 30.0},
	"e_generator": {"name": "Générateur ennemi", "hp": 600, "speed": 0.0, "damage": 0, "range": 0.0, "cooldown": 1.0, "armor": 3, "flying": false, "size": 2, "look": "generator"},
	"e_hq": {"name": "Base ennemie", "hp": 2500, "speed": 0.0, "damage": 20, "range": 4.5, "cooldown": 1.5, "armor": 4, "flying": false, "size": 3, "look": "hq", "spawn": "armored", "spawn_every": 45.0},
}
## Objectifs bonus (neutres : ne combattent pas, suivent la voie ferrée / la route / l'eau).
const OBJECTIVE_ENTITIES := {
	"train": {"hp": 700, "speed": 1.7, "damage": 0, "range": 0.0, "cooldown": 1.0, "armor": 3, "flying": false},
	"truck": {"hp": 180, "speed": 1.5, "damage": 0, "range": 0.0, "cooldown": 1.0, "armor": 2, "flying": false},
	"boat": {"hp": 450, "speed": 1.1, "damage": 0, "range": 0.0, "cooldown": 1.0, "armor": 2, "flying": false},
}
const OBJECTIVES := {
	"train": {"name": "Détruire le train", "entity": "train", "count": 1, "metal": 250, "essence": 80, "credits": 40},
	"convoy": {"name": "Détruire le convoi", "entity": "truck", "count": 3, "metal": 200, "essence": 60, "credits": 40},
	"boat": {"name": "Couler le bateau", "entity": "boat", "count": 1, "metal": 220, "essence": 100, "credits": 40},
}
## Ennemis considérés comme boss (barre de PV, bandeau, étourdissement réduit…).
const BOSSES: Array[String] = ["boss", "mothership"]

const REPAIR_RATE := 12.0 # PV rendus par seconde et par ouvrier
const HOUSE_BUILD_WORK := 6.0
const AUTO_REPAIR_RADIUS := 8.0 # cases autour de l'ouvrier
const IDLE_ASSIST_RADIUS := 14.0 # un ouvrier inactif va construire / réparer dans ce rayon

const BOSS_EVERY := 5 # un boss toutes les 5 vagues

## Métal gagné en détruisant un ennemi.
const KILL_BOUNTY := {"normal": 1, "fast": 1, "armored": 3, "flying": 2, "boss": 25,
		"swarmer": 0, "spitter": 2, "brute": 5, "shell": 4, "siege": 5, "mothership": 30}
