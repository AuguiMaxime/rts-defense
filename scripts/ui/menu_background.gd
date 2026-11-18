class_name MenuBackground
extends Control
## Fond animé des menus : grille en perspective qui défile, halos et particules.

var _t := 0.0
var _stars: Array[Vector3] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.3, 1.0)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Ui.BG)

	# Halos de couleur
	_glow(Vector2(w * 0.18, h * 0.25), h * 0.7, Color(Ui.CYAN, 0.10))
	_glow(Vector2(w * 0.85, h * 0.8), h * 0.8, Color(Ui.MAGENTA, 0.08))

	# Particules
	for s in _stars:
		var y := fmod(s.y + _t * 0.02 * s.z, 1.0) * h
		draw_circle(Vector2(s.x * w, h - y), 1.5 * s.z, Color(Ui.CYAN, 0.35 * s.z))

	# Grille au sol en perspective
	var horizon := h * 0.58
	var vp := Vector2(w * 0.5, horizon)
	for i in range(-14, 15):
		var x := w * 0.5 + i * w * 0.12
		draw_line(vp, Vector2(x + (x - vp.x) * 2.0, h), Color(Ui.CYAN, 0.10), 1.0)
	var offset := fmod(_t * 0.25, 1.0)
	for i in 14:
		var k := (i + offset) / 14.0
		var y := horizon + (h - horizon) * k * k
		draw_line(Vector2(0, y), Vector2(w, y), Color(Ui.CYAN, 0.04 + 0.16 * k), 1.0)
	draw_line(Vector2(0, horizon), Vector2(w, horizon), Color(Ui.CYAN, 0.35), 2.0)

	# Liseré haut et bas
	draw_rect(Rect2(0, 0, w, 3), Color(Ui.CYAN, 0.5))
	draw_rect(Rect2(0, h - 3, w, 3), Color(Ui.MAGENTA, 0.35))


func _glow(c: Vector2, r: float, color: Color) -> void:
	for i in 28:
		var k := 1.0 - i / 28.0
		draw_circle(c, r * k, Color(color, color.a * 0.06))
