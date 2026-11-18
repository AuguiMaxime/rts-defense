class_name Balance
extends RefCounted
## Tous les chiffres d'équilibrage au même endroit.

const START_METAL := 150
const START_ESSENCE := 0
const START_WORKERS := 3

const WORKER_COST_METAL := 50
const WORKER_TRAIN_TIME := 4.0 # secondes
const WORKER_SPEED := 2.5 # cases par seconde
const CARRY_CAPACITY := 5 # minerai rapporté par voyage
const HARVEST_TIME := 2.0 # secondes au gisement

const TOWER_COST_METAL := 75
const TOWER_BUILD_WORK := 10.0 # secondes pour 1 ouvrier, divisé par le nombre d'ouvriers
const TOWER_HP := 200
