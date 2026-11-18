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
}

const REPAIR_RATE := 12.0 # PV rendus par seconde et par ouvrier
const HOUSE_BUILD_WORK := 6.0

const BOSS_EVERY := 5 # un boss toutes les 5 vagues

## Métal gagné en détruisant un ennemi.
const KILL_BOUNTY := {"normal": 1, "fast": 1, "armored": 3, "flying": 2, "boss": 25}
