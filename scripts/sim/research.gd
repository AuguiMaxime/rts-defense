class_name Research
extends RefCounted
## Améliorations recherchées (forge, centre de recherche, labo).
## Les niveaux sont partagés via une variable statique : chaque GameWorld y place les siens.

static var levels := {}
static var version := 0 # incrémenté à chaque recherche terminée (invalide les caches)

const INFANTRY: Array[String] = ["soldier", "warrior", "grenadier", "sniper", "medic"]
const MECH: Array[String] = ["tank", "aa_mech", "heavy_tank"]


static func level(id: String) -> int:
	return int(levels.get(id, 0))


static func active() -> bool:
	return not levels.is_empty()


## Bonus appliqués à une unité (renvoie une copie modifiée des stats si besoin).
static func apply_unit(type_name: String, st: Dictionary) -> Dictionary:
	if levels.is_empty():
		return st
	var e := st
	if INFANTRY.has(type_name):
		var w := level("inf_weapons")
		var a := level("inf_armor")
		if w > 0 or a > 0:
			e = st.duplicate()
			e.damage = roundi(e.damage * (1.0 + 0.15 * w))
			e.armor = int(e.armor) + a
	elif MECH.has(type_name):
		var w := level("mech_weapons")
		var a := level("mech_armor")
		var s := level("mech_engines")
		if w > 0 or a > 0 or s > 0:
			e = st.duplicate()
			e.damage = roundi(e.damage * (1.0 + 0.15 * w))
			e.armor = int(e.armor) + 2 * a
			e.speed = e.speed * (1.0 + 0.10 * s)
	return e


## Bonus de PV max (infanterie).
static func hp_mult(type_name: String) -> float:
	if INFANTRY.has(type_name):
		return 1.0 + 0.10 * level("inf_health")
	return 1.0


## Bonus appliqués aux tourelles.
static func apply_tower(st: Dictionary) -> void:
	st.damage = roundi(st.damage * (1.0 + 0.10 * level("tw_damage")))
	st.range = st.range + 0.3 * level("tw_range")
	st.delay = st.delay * (1.0 - 0.08 * level("tw_rate"))
