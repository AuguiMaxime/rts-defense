class_name StarIcon
extends Control
## Étoile de score (pleine ou vide).

var filled := true


func _init() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var pts := PackedVector2Array()
	for i in 10:
		var r := size.x * (0.48 if i % 2 == 0 else 0.2)
		pts.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * r)
	if filled:
		draw_colored_polygon(pts, Ui.GOLD)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("fde68a"), 2.0)
	else:
		draw_colored_polygon(pts, Color(Ui.PANEL_LIGHT))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Ui.MUTED, 0.6), 2.0)
