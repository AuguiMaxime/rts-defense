class_name Sprites
extends RefCounted
## Textures du jeu (pack Kenney « Tower Defense top-down », licence CC0).
## Pour changer de style graphique, il suffit de remplacer les images de assets/kenney/.

const GRASS := preload("res://assets/kenney/grass.png")
const STONE := preload("res://assets/kenney/stone.png")
const ROCK_BIG := preload("res://assets/kenney/rock_big.png")
const ROCK_SMALL := preload("res://assets/kenney/rock_small.png")
const ORE := preload("res://assets/kenney/ore.png")
const BUSH := preload("res://assets/kenney/bush.png")
const BUSH_SMALL := preload("res://assets/kenney/bush_small.png")
const SCORCH := preload("res://assets/kenney/scorch.png")
const SITE := preload("res://assets/kenney/site.png")
const TOWER_BASE := preload("res://assets/kenney/tower_base.png")
const TURRET_GUN := preload("res://assets/kenney/turret_gun.png")
const BASE_CORE := preload("res://assets/kenney/base_core.png")
const WORKER := preload("res://assets/kenney/worker.png")

## Les unités du pack regardent vers la droite, les tourelles vers le haut.
const TURRET_ANGLE_OFFSET := PI / 2.0
