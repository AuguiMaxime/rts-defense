class_name Unit
extends RefCounted
## Unité de combat du joueur (soldat, grenadier, sniper, char, mécha AA). Position en cases.

enum Order { GUARD, MOVE, ATTACK }

const AGGRO_EXTRA := 3.0 # repère les ennemis un peu au-delà de sa portée
const LEASH := 7.0 # ne s'éloigne pas plus de son poste en mode garde

var id := 0
var type := "soldier"
var pos := Vector2.ZERO
var facing := Vector2.RIGHT
var aim_angle := 0.0
var hp := 1
var max_hp := 1
var order := Order.GUARD
var path: Array[Vector2i] = []
var guard_pos := Vector2.ZERO
var target: Enemy = null
var cooldown := 0.0
var retarget_timer := 0.0
var repath_timer := 0.0
var alive := true
var net_target := Vector2.INF # coop : position reçue de l'hôte (interpolation)


static func create(type_name: String, at: Vector2) -> Unit:
	var u := Unit.new()
	u.type = type_name
	u.pos = at
	u.guard_pos = at
	u.max_hp = Content.UNITS[type_name].hp
	u.hp = u.max_hp
	return u


func stats() -> Dictionary:
	return Content.UNITS[type]


func cell() -> Vector2i:
	return Vector2i(pos.floor())


func pop() -> int:
	return int(stats().pop)
