class_name CurrencyIcon
extends Control
## Icône dessinée : pièce d'or, crédit (losange cyan), métal, essence, population.

var kind := "credits"
var icon_size := 26.0


func _init() -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 1.0
	match kind:
		"gold":
			draw_circle(c, r, Color("b45309"))
			draw_circle(c, r - 2.5, Ui.GOLD)
			draw_circle(c, r - 7, Color("fde68a"))
			draw_circle(c, r - 9, Ui.GOLD)
		"credits":
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			draw_colored_polygon(pts, Ui.CYAN)
			var inner := PackedVector2Array([c + Vector2(0, -r * 0.5), c + Vector2(r * 0.5, 0), c + Vector2(0, r * 0.5), c + Vector2(-r * 0.5, 0)])
			draw_colored_polygon(inner, Color("cffafe"))
		"metal":
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(c + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * r)
			draw_colored_polygon(hex, Ui.METAL)
			draw_polyline(hex + PackedVector2Array([hex[0]]), Color("1e3a5f"), 2.0)
		"essence":
			var drop := PackedVector2Array([c + Vector2(0, -r)])
			for i in 9:
				drop.append(c + Vector2(0, r * 0.25) + Vector2.from_angle(-PI * 0.15 + PI * 1.3 * i / 8.0) * r * 0.72)
			draw_colored_polygon(drop, Ui.ESSENCE)
		"pop":
			draw_circle(c + Vector2(0, -r * 0.35), r * 0.38, Ui.GREEN)
			draw_circle(c + Vector2(0, r * 0.75), r * 0.7, Ui.GREEN)
		"wave":
			draw_arc(c, r * 0.9, PI * 0.15, PI * 1.85, 24, Ui.RED, 3.0)
			draw_circle(c, r * 0.35, Ui.RED)
		"orbital":
			draw_arc(c, r * 0.9, 0, TAU, 32, Ui.CYAN, 2.5)
			draw_arc(c, r * 0.5, 0, TAU, 24, Color(Ui.CYAN, 0.7), 2.0)
			draw_rect(Rect2(c.x - 3, c.y - r * 1.1, 6, r * 1.1), Color("cffafe"))
			draw_circle(c, 4, Color.WHITE)
		"base":
			draw_rect(Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), Ui.CYAN, false, 3.0)
			draw_rect(Rect2(c - Vector2(r, r) * 0.35, Vector2(r, r) * 0.7), Ui.CYAN)
