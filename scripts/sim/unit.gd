class_name Unit
extends RefCounted
## Unité de combat du joueur (soldat, grenadier, sniper, char, mécha AA). Position en cases.

enum Order { GUARD, MOVE, ATTACK, AMOVE, HOLD } # AMOVE = déplacement offensif (attaque en chemin)

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
var ability_cd := 0.0 # recharge du pouvoir
var buff_time := 0.0 # durée restante du pouvoir actif
var sieged := false # char en mode siège
var crit_ready := true # sniper : prochain tir critique
var last_target_id := -1
var heal_acc := 0.0
var vip := false # unité à escorter (mission escorte)
var locked := false # véhicule allié piloté par la mission (non sélectionnable)
var dest := Vector2.ZERO
var stuck_t := 0.0 # temps sans progrès vers la destination
var stuck_pos := Vector2.INF # position de référence (détection de blocage)
var stuck_tries := 0 # destination d'un déplacement offensif
## Réglages de la fiche de l'éditeur.
var eid := -1
var faction := "p1" # voir Factions
var hunt := false # allié IA : part chercher les ennemis hostiles sur la carte
var ai := false # unité alliée pilotée par l'ordinateur (non sélectionnable)
var invulnerable := false
var mul_dmg := 1.0
var mul_spd := 1.0
var mul_rng := 1.0
var patrol: Array[Vector2i] = []
var patrol_i := 0
var follow_eid := -1


static func create(type_name: String, at: Vector2) -> Unit:
	var u := Unit.new()
	u.type = type_name
	u.pos = at
	u.guard_pos = at
	u.max_hp = roundi(Content.UNITS[type_name].hp * Research.hp_mult(type_name))
	u.hp = u.max_hp
	return u


func stats() -> Dictionary:
	return Content.UNITS[type]


## Statistiques effectives (pouvoir actif, mode siège).
func eff() -> Dictionary:
	var st: Dictionary = Research.apply_unit(type, stats())
	if mul_dmg != 1.0 or mul_spd != 1.0 or mul_rng != 1.0:
		st = st.duplicate()
		st.damage = roundi(st.damage * mul_dmg)
		st.speed = st.speed * mul_spd
		st.range = st.range * mul_rng
	if buff_time <= 0.0 and not sieged:
		return st
	var e := st.duplicate()
	if sieged:
		e.range = Content.SIEGE_RANGE
		e.damage = roundi(e.damage * 1.4)
		e.splash = 1.0
		e.speed = 0.0
	if buff_time > 0.0:
		match st.get("ability", ""):
			"stim":
				e.damage = roundi(e.damage * 1.25)
				e.speed = e.speed * 1.25
			"charge":
				e.speed = e.speed * 1.6
			"bastion":
				e.armor = int(e.armor) + 4
			"salvo":
				e.delay = e.delay * 0.5
	return e


func ability() -> String:
	return stats().get("ability", "")


## Le joueur peut-il la sélectionner et lui donner des ordres ?
func controllable() -> bool:
	return not locked and not ai


func cell() -> Vector2i:
	return Vector2i(pos.floor())


func pop() -> int:
	return int(stats().pop)
