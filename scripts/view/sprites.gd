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
static var TOWER_LOOK := {
	"gun": _w(4, 1, 0.66),
	"cannon": _w(1, 2, 0.62),
	"missile": _w(6, 3, 0.58),
	"laser": _w(5, 4, 0.62, Color(0.8, 0.95, 1.1)),
	"flame": _w(8, 5, 0.64, Color(1.15, 0.9, 0.75)),
	"sniper_tower": _w(3, 6, 0.66),
	"tesla": _w(2, 7, 0.62, Color(0.95, 0.85, 1.2)),
	"cryo": _w(7, 8, 0.6, Color(0.75, 1.0, 1.3)),
	"stun": _w(9, 5, 0.62),
}

## Sol de chaque map : texture et teinte.
# --- Wenrexa (CC0) : tourelles vue de dessus, plateformes, bâtiments ---------------
const W_TURRETS := [
	preload("res://assets/wenrexa/turret_01.png"), preload("res://assets/wenrexa/turret_02.png"),
	preload("res://assets/wenrexa/turret_03.png"), preload("res://assets/wenrexa/turret_04.png"),
	preload("res://assets/wenrexa/turret_05.png"), preload("res://assets/wenrexa/turret_06.png"),
	preload("res://assets/wenrexa/turret_07.png"), preload("res://assets/wenrexa/turret_08.png"),
	preload("res://assets/wenrexa/turret_09.png"), preload("res://assets/wenrexa/turret_10.png"),
]
## Centre de rotation (la « tête ») de chaque tourelle Wenrexa, en pixels de la texture.
const W_PIVOT_Y := [40, 40, 33, 34, 36, 42, 44, 34, 34, 34]
const W_PLATFORMS := [
	preload("res://assets/wenrexa/platform_1.png"), preload("res://assets/wenrexa/platform_2.png"),
	preload("res://assets/wenrexa/platform_3.png"), preload("res://assets/wenrexa/platform_4.png"),
	preload("res://assets/wenrexa/platform_5.png"), preload("res://assets/wenrexa/platform_6.png"),
	preload("res://assets/wenrexa/platform_7.png"), preload("res://assets/wenrexa/platform_8.png"),
]
const W_BASE := preload("res://assets/wenrexa/building_b12.png")
const W_BARRACKS := preload("res://assets/wenrexa/building_b02.png")
const W_FACTORY := preload("res://assets/wenrexa/building_b09.png")
const W_HOUSE := preload("res://assets/wenrexa/building_b26.png")
## Les tourelles Wenrexa pointent vers le bas : décalage de rotation.
const W_ANGLE_OFFSET := -PI / 2.0

# --- Kenney Sci-fi RTS (CC0) : minerais, sol martien, décor -----------------------
const ORE_METAL := preload("res://assets/kenney_scifi/ore_metal.png")
const ORE_ESSENCE := preload("res://assets/kenney_scifi/ore_essence.png")
const ROCK_MARS := preload("res://assets/kenney_scifi/rock_mars.png")
const ROCK_MARS2 := preload("res://assets/kenney_scifi/rock_mars2.png")
const GROUND_MARS := preload("res://assets/kenney_scifi/ground_mars.png")
const GROUND_MARS2 := preload("res://assets/kenney_scifi/ground_mars2.png")
const PLANT_GREEN := preload("res://assets/kenney_scifi/plant_green.png")
const PLANT_PURPLE := preload("res://assets/kenney_scifi/plant_purple.png")


static func _w(turret: int, platform: int, scale := 0.66, tint := Color(1, 1, 1)) -> Dictionary:
	var tex: Texture2D = W_TURRETS[turret - 1]
	return {"base": W_PLATFORMS[platform - 1], "turret": tex, "tint": tint, "scale": scale,
			"pivot": Vector2(tex.get_width() / 2.0, W_PIVOT_Y[turret - 1])}

const GROUND_LOOK := {
	"grass": {"tex": GRASS, "tint": Color(0.34, 0.46, 0.38)},
	"sand": {"tex": SAND, "tint": Color(0.70, 0.58, 0.48)},
	"dirt": {"tex": DIRT, "tint": Color(0.55, 0.50, 0.50)},
	"mars": {"tex": GROUND_MARS, "tint": Color(0.82, 0.78, 0.78)},
}
