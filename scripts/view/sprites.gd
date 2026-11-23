class_name Sprites
extends RefCounted
## Textures du jeu (pack Kenney « Tower Defense top-down », licence CC0).
## Pour changer de style graphique, il suffit de remplacer les images de assets/kenney/.

const GRASS := preload("res://assets/gen/ground_grass.png")
const STONE := preload("res://assets/kenney/stone.png")
const ROCK_BIG := preload("res://assets/gen/rock_big.png")
const ROCK_SMALL := preload("res://assets/gen/rock_small.png")
const ORE := preload("res://assets/kenney/ore.png")
const BUSH := preload("res://assets/kenney/bush.png")
const BUSH_SMALL := preload("res://assets/gen/plant.png")
const SCORCH := preload("res://assets/gen/scorch.png")
const SITE := preload("res://assets/kenney/site.png")
const GEN_SITE := preload("res://assets/gen/site.png")
const TOWER_BASE := preload("res://assets/kenney/tower_base.png")
const TOWER_BASE2 := preload("res://assets/kenney/tower_base2.png")
const TOWER_BASE3 := preload("res://assets/kenney/tower_base3.png")
const TURRET_DOUBLE := preload("res://assets/kenney/turret_double.png")
const TURRET_MISSILE := preload("res://assets/kenney/turret_missile.png")
const TURRET_LIGHT := preload("res://assets/kenney/turret_light.png")
const ROCKET := preload("res://assets/gen/fx_rocket.png")
const SAND := preload("res://assets/gen/ground_sand.png")
const DIRT := preload("res://assets/gen/ground_dirt.png")
const TURRET_GUN := preload("res://assets/kenney/turret_gun.png")
const BASE_CORE := preload("res://assets/kenney/base_core.png")
const WORKER := preload("res://assets/gen/u_worker.png")
const SOLDIER := preload("res://assets/kenney/soldier_grey.png")
const TANK := preload("res://assets/kenney/tank_sand.png")
const TANK_HEAVY := preload("res://assets/kenney/tank_sand.png")
const PLANE := preload("res://assets/kenney/plane_grey.png")
const EXPLOSION := preload("res://assets/gen/fx_explosion.png")
const SOLDIER_GREEN := preload("res://assets/kenney/soldier_green.png")
const SOLDIER_BROWN := preload("res://assets/kenney/soldier_brown.png")
const TANK_GREEN := preload("res://assets/kenney/tank_green.png")
const TANK_TURRET_GREEN := preload("res://assets/kenney/tank_turret_green.png")
const TANK_TURRET_SAND := preload("res://assets/kenney/tank_turret_sand.png")
const TURRET_FLAME := preload("res://assets/kenney/turret_flame.png")
const TURRET_HEAVY := preload("res://assets/kenney/turret_heavy.png")
const TURRET_BLOCK := preload("res://assets/kenney/turret_block.png")
const TURRET_SHIELD := preload("res://assets/kenney/turret_shield.png")
const FLAME := preload("res://assets/gen/fx_flame.png")

## Unités du joueur : corps, tourelle éventuelle (qui vise), taille en pixels, teinte.
## Unités (sprites générés). upright = dessin de face, non tourné (retourné gauche/droite) ;
## sinon le sprite pointe vers le haut et tourne avec l'unité (rot = décalage d'angle).
const UNIT_LOOK := {
	"soldier": {"tex": preload("res://assets/gen/u_soldier.png"), "size": 56, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"warrior": {"tex": preload("res://assets/gen/u_warrior.png"), "size": 56, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"grenadier": {"tex": preload("res://assets/gen/u_grenadier.png"), "size": 64, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"sniper": {"tex": preload("res://assets/gen/u_sniper.png"), "size": 62, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"medic": {"tex": preload("res://assets/gen/u_medic.png"), "size": 54, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"tank": {"tex": preload("res://assets/gen/tank_hull.png"), "size": 76, "tint": Color(1, 1, 1), "rot": PI / 2.0,
			"turret": preload("res://assets/gen/tank_turret.png"), "turret_size": 88},
	"aa_mech": {"tex": preload("res://assets/gen/mech_turret.png"), "size": 70, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"commander": {"tex": preload("res://assets/gen/u_soldier.png"), "size": 64, "tint": Color(1.25, 1.1, 0.7), "rot": PI / 2.0},
	"escort_truck": {"tex": preload("res://assets/gen/tank_hull.png"), "size": 70, "tint": Color(0.7, 1.0, 0.75), "rot": PI / 2.0},
	"heavy_tank": {"tex": preload("res://assets/gen/htank_hull.png"), "size": 92, "tint": Color(1, 1, 1), "rot": PI / 2.0,
			"turret": preload("res://assets/gen/htank_turret.png"), "turret_size": 96},
}

## Apparence de chaque type d'ennemi : texture, taille en pixels, teinte.
const ENEMY_LOOK := {
	"normal": {"tex": preload("res://assets/gen/e_normal_hull.png"), "size": 62, "tint": Color(1, 1, 1), "rot": PI / 2.0,
			"turret": preload("res://assets/gen/e_normal_turret.png"), "turret_size": 44},
	"fast": {"tex": preload("res://assets/gen/e_fast.png"), "size": 54, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"armored": {"tex": preload("res://assets/gen/e_armored.png"), "size": 80, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"flying": {"tex": preload("res://assets/gen/e_flying.png"), "size": 80, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"boss": {"tex": preload("res://assets/gen/e_boss.png"), "size": 140, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"swarmer": {"tex": preload("res://assets/gen/e_swarmer.png"), "size": 40, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"spitter": {"tex": preload("res://assets/gen/e_spitter.png"), "size": 58, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"brute": {"tex": preload("res://assets/gen/e_brute.png"), "size": 92, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"shell": {"tex": preload("res://assets/gen/e_shell.png"), "size": 68, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"siege": {"tex": preload("res://assets/gen/e_siege.png"), "size": 86, "tint": Color(1, 1, 1), "rot": PI / 2.0},
	"mothership": {"tex": preload("res://assets/gen/e_mothership.png"), "size": 170, "tint": Color(1, 1, 1), "rot": PI / 2.0},
}

## Les unités du pack regardent vers la droite, les tourelles vers le haut.
const TURRET_ANGLE_OFFSET := PI / 2.0

## Apparence de chaque tourelle : plateforme, canon, teinte du canon.
## Tourelles générées : socle + canon (pointe vers le haut, pivot au centre de l'image).
static func _g(kind: String) -> Dictionary:
	var tex: Texture2D = load("res://assets/gen/turret_%s.png" % kind)
	return {"base": load("res://assets/gen/tbase_%s.png" % kind), "turret": tex, "tint": Color(1, 1, 1),
			"scale": 0.42 * 256.0 / tex.get_width(), "pivot": Vector2(tex.get_width(), tex.get_height()) / 2.0, "rot": PI / 2.0}


static var TOWER_LOOK := {
	"gun": _g("gun"), "cannon": _g("cannon"), "missile": _g("missile"), "laser": _g("laser"), "flame": _g("flame"),
	"sniper_tower": _g("sniper_tower"), "tesla": _g("tesla"), "cryo": _g("cryo"), "stun": _g("stun"),
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
const W_BASE := preload("res://assets/gen/base.png")
const W_BARRACKS := preload("res://assets/gen/barracks.png")
const W_FACTORY := preload("res://assets/gen/factory.png")
const W_HOUSE := preload("res://assets/gen/house.png")
## Bâtiments de production / recherche : [texture, teinte] (provisoire pour forge, centre de recherche, labo).
static var PRODUCER_LOOK := {
	"barracks": [W_BARRACKS, Color(1, 1, 1)],
	"factory": [W_FACTORY, Color(1, 1, 1)],
	"forge": [W_BARRACKS, Color(1.15, 0.8, 0.6)],
	"research": [W_FACTORY, Color(0.85, 0.75, 1.15)],
	"lab": [W_HOUSE, Color(0.75, 1.1, 0.9)],
	"hq": [W_BASE, Color(1.0, 0.85, 0.75)],
}
## Les tourelles Wenrexa pointent vers le bas : décalage de rotation.
const W_ANGLE_OFFSET := -PI / 2.0

# --- Kenney Sci-fi RTS (CC0) : minerais, sol martien, décor -----------------------
const ORE_METAL := preload("res://assets/gen/ore_metal.png")
const ORE_ESSENCE := preload("res://assets/gen/ore_essence.png")
const ROCK_MARS := preload("res://assets/gen/rock_big.png")
const ROCK_MARS2 := preload("res://assets/gen/rock_small.png")
const GROUND_MARS := preload("res://assets/gen/ground_mars.png")
const GROUND_MARS2 := preload("res://assets/gen/ground_mars.png")
const PLANT_GREEN := preload("res://assets/kenney_scifi/plant_green.png")
const PLANT_PURPLE := preload("res://assets/kenney_scifi/plant_purple.png")


static func _w(turret: int, platform: int, scale := 0.66, tint := Color(1, 1, 1)) -> Dictionary:
	var tex: Texture2D = W_TURRETS[turret - 1]
	return {"base": W_PLATFORMS[platform - 1], "turret": tex, "tint": tint, "scale": scale,
			"pivot": Vector2(tex.get_width() / 2.0, W_PIVOT_Y[turret - 1])}

const GROUND_LOOK := {
	"grass": {"tex": GRASS, "tint": Color(0.78, 0.82, 0.78)},
	"sand": {"tex": SAND, "tint": Color(0.86, 0.84, 0.82)},
	"dirt": {"tex": DIRT, "tint": Color(0.85, 0.85, 0.85)},
	"mars": {"tex": GROUND_MARS, "tint": Color(0.86, 0.84, 0.84)},
	"metal": {"tex": preload("res://assets/gen/ground_metal.png"), "tint": Color(0.85, 0.85, 0.88)},
}
