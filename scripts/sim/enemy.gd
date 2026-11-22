class_name Enemy
extends RefCounted
## Un ennemi. Position en cases.

enum Target { NONE, BASE, WORKER, SITE, UNIT }

var id := 0
var type := "normal"
var net_target := Vector2.INF # coop : position reçue de l'hôte (interpolation)
var pos := Vector2.ZERO
var facing := Vector2.RIGHT
var hp := 1
var max_hp := 1
var speed := 1.0
var damage := 1
var attack_range := 1.0
var cooldown := 1.0
var armor := 0
var flying := false

var attack_timer := 0.0
var retarget_timer := 0.0
var target_kind := Target.NONE
var target_ref: Variant = null
var slow_timer := 0.0
var slow_mult := 1.0
var stun_timer := 0.0
var visual_offset := Vector2.ZERO # petit décalage pour ne pas tous se superposer à l'écran


static func create(type_name: String, at: Vector2, hp_scale: float) -> Enemy:
	var d: Dictionary = Balance.ENEMIES[type_name]
	var e := Enemy.new()
	e.type = type_name
	e.pos = at
	e.max_hp = roundi(d.hp * hp_scale)
	e.hp = e.max_hp
	e.speed = d.speed
	e.damage = d.damage
	e.attack_range = d.range
	e.cooldown = d.cooldown
	e.armor = d.armor
	e.flying = d.flying
	return e
