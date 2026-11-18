class_name MenuEmblem
extends Control
## Emblème animé du menu : radar qui tourne autour de la base, tourelles en orbite.

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.46

	# Anneaux
	draw_circle(c, r, Color(Ui.CYAN, 0.04))
	draw_arc(c, r, 0, TAU, 96, Color(Ui.CYAN, 0.35), 2.0)
	draw_arc(c, r * 0.72, 0, TAU, 96, Color(Ui.CYAN, 0.18), 1.5)
	draw_arc(c, r * 0.45, 0, TAU, 96, Color(Ui.CYAN, 0.12), 1.0)
	for i in 4:
		var a := _t * 0.4 + i * PI / 2.0
		draw_arc(c, r + 10, a, a + 0.5, 16, Ui.CYAN, 4.0)
	for i in 3:
		var a := -_t * 0.7 + i * TAU / 3.0
		draw_arc(c, r * 0.72 + 8, a, a + 0.35, 12, Color(Ui.MAGENTA, 0.8), 3.0)

	# Balayage radar
	var sweep := _t * 1.4
	for i in 20:
		var a := sweep - i * 0.04
		draw_line(c, c + Vector2.from_angle(a) * r, Color(Ui.CYAN, 0.25 * (1.0 - i / 20.0)), 3.0)

	# Échos ennemis
	for i in 5:
		var a := i * 1.3 + 0.4
		var p := c + Vector2.from_angle(a) * r * (0.55 + 0.08 * i)
		var age := fposmod(sweep - a, TAU)
		draw_circle(p, 6, Color(Ui.RED, clampf(1.0 - age / 2.5, 0.0, 1.0)))

	# Base et tourelles en orbite
	var core := r * 0.42
	draw_texture_rect(Sprites.TOWER_BASE, Rect2(c - Vector2(core, core), Vector2(core, core) * 2), false)
	draw_texture_rect(Sprites.BASE_CORE, Rect2(c - Vector2(core, core) * 0.7, Vector2(core, core) * 1.4), false, Color(0.75, 0.9, 1.0))
	for i in 3:
		var a := _t * 0.25 + i * TAU / 3.0
		var p := c + Vector2.from_angle(a) * r * 0.72
		draw_texture_rect(Sprites.TOWER_BASE, Rect2(p - Vector2(30, 30), Vector2(60, 60)), false)
		draw_set_transform(p, a + PI / 2.0)
		draw_texture_rect(Sprites.TURRET_GUN, Rect2(-28, -28, 56, 56), false)
		draw_set_transform(Vector2.ZERO)
