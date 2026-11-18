class_name UnitsView
extends Node2D
## Affiche ce qui bouge : ouvriers, chantiers, tourelles, rectangle de sélection.

const TILE := MapView.TILE

const COLOR_WORKER := Color(0.98, 0.80, 0.30)
const COLOR_WORKER_EDGE := Color(0.25, 0.18, 0.05)
const COLOR_SELECTED := Color(0.40, 1.0, 0.45)
const COLOR_TOWER := Color(0.55, 0.62, 0.70)
const COLOR_TOWER_EDGE := Color(0.20, 0.24, 0.28)
const COLOR_SITE := Color(0.98, 0.80, 0.30, 0.8)
const COLOR_BAR_BG := Color(0, 0, 0, 0.6)
const COLOR_BAR := Color(0.40, 1.0, 0.45)
const COLOR_SELECT_FILL := Color(0.40, 1.0, 0.45, 0.12)

var world: GameWorld
var selected: Array[Worker] = []
var selection_rect := Rect2() # en pixels monde, vide = pas de sélection en cours


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	for s in world.sites:
		_draw_site(s)
	for w in world.workers:
		_draw_worker(w)
	if selection_rect.has_area():
		draw_rect(selection_rect, COLOR_SELECT_FILL)
		draw_rect(selection_rect, COLOR_SELECTED, false, 2.0)


func _draw_worker(w: Worker) -> void:
	var p := w.pos * TILE
	if selected.has(w):
		draw_circle(p, 22, Color(COLOR_SELECTED, 0.18))
		draw_arc(p, 22, 0, TAU, 32, COLOR_SELECTED, 3.0)
	draw_set_transform(p, w.facing.angle())
	draw_texture_rect(Sprites.WORKER, Rect2(-42, -42, 84, 84), false)
	draw_set_transform(Vector2.ZERO)
	if w.carry_amount > 0:
		var c := MapView.COLOR_METAL if w.carry_type == GameGrid.Cell.METAL else MapView.COLOR_ESSENCE
		draw_circle(p + Vector2(12, -14), 7, Color(0, 0, 0, 0.6))
		draw_circle(p + Vector2(12, -14), 5.5, c)
	if w.state == Worker.State.BUILDING:
		draw_arc(p, 16, -PI * 0.8, -PI * 0.2, 12, COLOR_WORKER, 3.0)


func _draw_site(s: BuildSite) -> void:
	var r := Rect2(Vector2(s.cell) * TILE, Vector2(TILE, TILE))
	if s.built:
		draw_texture_rect(Sprites.TOWER_BASE, r, false)
		draw_set_transform(r.get_center(), s.aim_angle + Sprites.TURRET_ANGLE_OFFSET)
		draw_texture_rect(Sprites.TURRET_GUN, Rect2(-30, -30, 60, 60), false)
		draw_set_transform(Vector2.ZERO)
		if s.hp < s.max_hp:
			_draw_bar(r.grow(-6), float(s.hp) / s.max_hp)
	else:
		draw_texture_rect(Sprites.TOWER_BASE, r, false, Color(1, 1, 1, 0.25 + 0.5 * s.progress()))
		draw_texture_rect(Sprites.SITE, r.grow(-8), false, Color(1, 1, 1, 0.9))
		var a := r.grow(-3).position
		var b := r.grow(-3).end
		for seg in [[a, Vector2(b.x, a.y)], [Vector2(b.x, a.y), b], [b, Vector2(a.x, b.y)], [Vector2(a.x, b.y), a]]:
			draw_dashed_line(seg[0], seg[1], COLOR_SITE, 3.0, 8.0)
		_draw_bar(r.grow(-6), s.progress())


func _draw_bar(r: Rect2, ratio: float) -> void:
	var bar := Rect2(r.position + Vector2(0, -12), Vector2(r.size.x, 7))
	draw_rect(bar, COLOR_BAR_BG)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), COLOR_BAR)
