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
const TOWER_BASE2 := preload("res://assets/kenney/tower_base2.png")
const TOWER_BASE3 := preload("res://assets/kenney/tower_base3.png")
const TURRET_DOUBLE := preload("res://assets/kenney/turret_double.png")
const TURRET_MISSILE := preload("res://assets/kenney/turret_missile.png")
const TURRET_LIGHT := preload("res://assets/kenney/turret_light.png")
const ROCKET := preload("res://assets/kenney/rocket.png")
const SAND := preload("res://assets/kenney/sand.png")
const DIRT := preload("res://assets/kenney/dirt.png")
const TURRET_GUN := preload("res://assets/kenney/turret_gun.png")
const BASE_CORE := preload("res://assets/kenney/base_core.png")
const WORKER := preload("res://assets/kenney/worker.png")
const SOLDIER := preload("res://assets/kenney/soldier_grey.png")
const TANK := preload("res://assets/kenney/tank_sand.png")
const TANK_HEAVY := preload("res://assets/kenney/tank_sand.png")
const PLANE := preload("res://assets/kenney/plane_grey.png")
const EXPLOSION := preload("res://assets/kenney/explosion.png")
const SOLDIER_GREEN := preload("res://assets/kenney/soldier_green.png")
const SOLDIER_BROWN := preload("res://assets/kenney/soldier_brown.png")
const TANK_GREEN := preload("res://assets/kenney/tank_green.png")
const TANK_TURRET_GREEN := preload("res://assets/kenney/tank_turret_green.png")
const TANK_TURRET_SAND := preload("res://assets/kenney/tank_turret_sand.png")
const TURRET_FLAME := preload("res://assets/kenney/turret_flame.png")
const TURRET_HEAVY := preload("res://assets/kenney/turret_heavy.png")
const TURRET_BLOCK := preload("res://assets/kenney/turret_block.png")
const TURRET_SHIELD := preload("res://assets/kenney/turret_shield.png")
const FLAME := preload("res://assets/kenney/flame.png")

## Unités du joueur : corps, tourelle éventuelle (qui vise), taille en pixels, teinte.
const UNIT_LOOK := {
	"soldier": {"tex": SOLDIER_GREEN, "size": 96, "tint": Color(1, 1, 1)},
	"warrior": {"tex": SOLDIER_BROWN, "size": 96, "tint": Color(1.0, 0.8, 0.6)},
	"grenadier": {"tex": SOLDIER_BROWN, "size": 112, "tint": Color(0.8, 0.7, 0.6)},
	"sniper": {"tex": SOLDIER, "size": 96, "tint": Color(0.65, 0.95, 1.0)},
	"medic": {"tex": SOLDIER, "size": 96, "tint": Color(1.0, 1.0, 1.0)},
	"tank": {"tex": TANK_GREEN, "size": 84, "tint": Color(1, 1, 1), "turret": TANK_TURRET_GREEN, "turret_size": 84},
	"aa_mech": {"tex": TANK_GREEN, "size": 68, "tint": Color(0.70, 1.0, 0.95), "turret": TURRET_MISSILE, "turret_size": 56},
}

## Apparence de chaque type d'ennemi : texture, taille en pixels, teinte.
const ENEMY_LOOK := {
	"normal": {"tex": TANK, "size": 52, "tint": Color(1.0, 0.45, 0.40), "turret": TANK_TURRET_SAND},
	"fast": {"tex": SOLDIER, "size": 64, "tint": Color(1.0, 0.40, 0.35)},
	"armored": {"tex": TANK_HEAVY, "size": 76, "tint": Color(0.55, 0.30, 0.30), "turret": TANK_TURRET_SAND},
	"flying": {"tex": PLANE, "size": 72, "tint": Color(1.0, 0.45, 0.40)},
	"boss": {"tex": TANK_HEAVY, "size": 120, "tint": Color(0.75, 0.22, 0.28), "turret": TANK_TURRET_SAND},
}

## Les unités du pack regardent vers la droite, les tourelles vers le haut.
const TURRET_ANGLE_OFFSET := PI / 2.0

## Apparence de chaque tourelle : plateforme, canon, teinte du canon.
const TOWER_LOOK := {
	"gun": {"base": TOWER_BASE, "turret": TURRET_GUN, "tint": Color(1, 1, 1)},
	"cannon": {"base": TOWER_BASE2, "turret": TURRET_DOUBLE, "tint": Color(1, 1, 1)},
	"missile": {"base": TOWER_BASE3, "turret": TURRET_MISSILE, "tint": Color(1, 1, 1)},
	"laser": {"base": TOWER_BASE2, "turret": TURRET_LIGHT, "tint": Color(0.55, 0.95, 1.0)},
	"flame": {"base": TOWER_BASE, "turret": TURRET_FLAME, "tint": Color(1.0, 0.62, 0.4)},
	"sniper_tower": {"base": TOWER_BASE3, "turret": TURRET_HEAVY, "tint": Color(0.75, 0.85, 1.0)},
	"tesla": {"base": TOWER_BASE2, "turret": TURRET_LIGHT, "tint": Color(0.8, 0.6, 1.0)},
	"cryo": {"base": TOWER_BASE, "turret": TURRET_BLOCK, "tint": Color(0.6, 0.92, 1.0)},
	"stun": {"base": TOWER_BASE3, "turret": TURRET_SHIELD, "tint": Color(1.0, 0.88, 0.4)},
}

## Sol de chaque map : texture et teinte.
const GROUND_LOOK := {
	"grass": {"tex": GRASS, "tint": Color(0.34, 0.46, 0.38)},
	"sand": {"tex": SAND, "tint": Color(0.70, 0.58, 0.48)},
	"dirt": {"tex": DIRT, "tint": Color(0.55, 0.50, 0.50)},
}
