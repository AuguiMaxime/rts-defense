class_name BuildSite
extends RefCounted
## Une tourelle : d'abord un chantier, puis une tourelle construite.

var cell := Vector2i.ZERO
var work_needed := Balance.TOWER_BUILD_WORK
var work_done := 0.0
var built := false
var max_hp := Balance.TOWER_HP
var hp := Balance.SITE_HP
var cooldown := 0.0
var aim_angle := -PI / 2.0 # orientation du canon (vers le haut par défaut)


func progress() -> float:
	return clampf(work_done / work_needed, 0.0, 1.0)
