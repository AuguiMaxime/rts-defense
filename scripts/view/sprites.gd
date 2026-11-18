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
const SOLDIER := preload("res://assets/kenney/soldier_grey.png")
const TANK := preload("res://assets/kenney/tank_sand.png")
const TANK_HEAVY := preload("res://assets/kenney/tank_sand.png")
const PLANE := preload("res://assets/kenney/plane_grey.png")
const EXPLOSION := preload("res://assets/kenney/explosion.png")

## Apparence de chaque type d'ennemi : texture, taille en pixels, teinte.
const ENEMY_LOOK := {
	"normal": {"tex": TANK, "size": 52, "tint": Color(1.0, 0.45, 0.40)},
	"fast": {"tex": SOLDIER, "size": 64, "tint": Color(1.0, 0.40, 0.35)},
	"armored": {"tex": TANK_HEAVY, "size": 76, "tint": Color(0.55, 0.30, 0.30)},
	"flying": {"tex": PLANE, "size": 72, "tint": Color(1.0, 0.45, 0.40)},
}

## Les unités du pack regardent vers la droite, les tourelles vers le haut.
const TURRET_ANGLE_OFFSET := PI / 2.0
