class_name BuildSite
extends RefCounted
## Un bâtiment posé par le joueur : tourelle ("gun", "cannon", "missile", "laser") ou "house".
## D'abord un chantier, puis un bâtiment terminé.

var kind := "gun"
var cell := Vector2i.ZERO
var work_needed := Balance.TOWER_BUILD_WORK
var work_done := 0.0
var built := false
var max_hp := 200
var hp := Balance.SITE_HP
var cooldown := 0.0
var aim_angle := -PI / 2.0 # orientation du canon (vers le haut par défaut)
var beam_target: Enemy = null # pour le laser : cible actuelle (affichage)


func _init(k := "gun") -> void:
	kind = k
	max_hp = Content.building(k).hp


func is_tower() -> bool:
	return kind != "house"


func stats() -> Dictionary:
	return Content.building(kind)


func progress() -> float:
	return clampf(work_done / work_needed, 0.0, 1.0)
