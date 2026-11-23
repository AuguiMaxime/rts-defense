class_name BuildSite
extends RefCounted
## Un bâtiment posé par le joueur : tourelle ("gun", "cannon", "missile", "laser"), "house",
## ou bâtiment de production 2x2 ("barracks", "factory"). D'abord un chantier, puis un bâtiment terminé.

var id := 0
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
var alive := true # false une fois détruit ou vendu
var target: Enemy = null # cible actuelle de la tourelle
var retarget_timer := 0.0
var level := 1 # niveau d'amélioration (1 à MAX_LEVEL)
var invested_metal := 0
var invested_essence := 0
var size := 1 # côté en cases (2 pour la caserne et l'usine)
var producer: Producer = null # file de production (caserne, usine), créée à la fin du chantier

const MAX_LEVEL := 3

var _stats_cache := {}
var _stats_level := 0
var _stats_version := -1


func _init(k := "gun") -> void:
	kind = k
	max_hp = Content.building(k).hp
	invested_metal = Content.building(k).metal
	invested_essence = Content.building(k).essence
	size = int(Content.building(k).get("size", 1))
	work_needed = float(Content.building(k).get("build", Balance.TOWER_BUILD_WORK))


func is_tower() -> bool:
	return Content.is_tower(kind)


func is_producer() -> bool:
	return Content.PRODUCTION.has(kind)


## Cases occupées (1 ou 4).
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in size:
		for dx in size:
			out.append(cell + Vector2i(dx, dy))
	return out


func rect() -> Rect2:
	return Rect2(Vector2(cell), Vector2(size, size))


func center() -> Vector2:
	return Vector2(cell) + Vector2(size, size) * 0.5


func contains(c: Vector2i) -> bool:
	return c.x >= cell.x and c.y >= cell.y and c.x < cell.x + size and c.y < cell.y + size


## Caractéristiques au niveau actuel : +35 % de dégâts, +10 % de portée, +25 % de PV par niveau.
func stats() -> Dictionary:
	if _stats_level != level or _stats_version != Research.version:
		_stats_version = Research.version
		_stats_cache = Content.building(kind).duplicate()
		if is_tower():
			var k := level - 1
			_stats_cache.damage = roundi(_stats_cache.damage * (1.0 + 0.35 * k))
			_stats_cache.range = _stats_cache.range * (1.0 + 0.10 * k)
			_stats_cache.hp = roundi(_stats_cache.hp * (1.0 + 0.25 * k))
			Research.apply_tower(_stats_cache)
		_stats_level = level
	return _stats_cache


## Coût du prochain niveau : 60 % du prix de base par niveau visé.
func upgrade_cost() -> Dictionary:
	var base := Content.building(kind)
	return {"metal": roundi(base.metal * 0.6 * level), "essence": roundi(base.essence * 0.6 * level)}


## Remboursement à la vente : 50 % de ce qui a été investi (100 % si le chantier n'a pas commencé).
func sell_value() -> Dictionary:
	var ratio := 1.0 if (not built and work_done <= 0.0) else 0.5
	return {"metal": roundi(invested_metal * ratio), "essence": roundi(invested_essence * ratio)}


func progress() -> float:
	return clampf(work_done / work_needed, 0.0, 1.0)
