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
## Objectif bonus : entité neutre qui suit un trajet fixe (train, camion, bateau).
var neutral := false
var route: Array[Vector2] = []
var route_i := 0
var objective := -1 # index de l'objectif dans GameWorld.objectives
var route_pauses := {} # index du point de trajet -> secondes d'arrêt (trajet tracé dans l'éditeur)
var pause_timer := 0.0
## Comportement : "march" (vague : marche vers la base), "guard" (posé : défend sa zone),
## "static" (structure ou unité qui tient sa position : ne bouge jamais).
var mode := "march"
var guard_pos := Vector2.ZERO
var radius := 0.0 # demi-taille pour les grosses structures (portée mesurée au bord)
var size := 0 # côté en cases d'une structure (0 = pas une structure)
var path: Array[Vector2i] = []
var repath_timer := 0.0
var spawn_timer := 0.0
var aim_angle := 0.0
## Objet de l'éditeur (identifiant), réglages de la fiche et comportement.
var eid := -1
var invulnerable := false
var shielded := false # protégé par un bouclier dont le générateur est en vie
var home := Vector2.ZERO # position de départ (repli)
var patrol: Array[Vector2i] = []
var patrol_i := 0
var target_eid := -1 # défendre / attaquer / suivre cet objet
var goal_pos := Vector2.INF # zone à attaquer
var retreat_pct := 0.0 # se replie sous cette part de PV (0 = jamais)
var retreating := false
var wave_no := 0 # numéro de la vague qui l'a fait apparaître (0 = posé ou produit)
var visual_offset := Vector2.ZERO # petit décalage pour ne pas tous se superposer à l'écran


func is_boss() -> bool:
	return Balance.BOSSES.has(type)


static func create(type_name: String, at: Vector2, hp_scale: float) -> Enemy:
	var d: Dictionary = Balance.ENEMIES.get(type_name, Balance.OBJECTIVE_ENTITIES.get(type_name, Balance.ENEMY_STRUCTURES.get(type_name, {})))
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
	e.neutral = Balance.OBJECTIVE_ENTITIES.has(type_name)
	if Balance.ENEMY_STRUCTURES.has(type_name):
		e.mode = "static"
		e.size = int(d.size)
		e.radius = d.size * 0.5
		e.spawn_timer = float(d.get("spawn_every", 0.0))
	return e


func is_structure() -> bool:
	return size > 0
