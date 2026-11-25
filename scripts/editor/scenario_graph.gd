class_name ScenarioGraph
extends Control
## Vue des dépendances (lecture seule) : déclencheurs, objectifs et variables, et leurs liens.
## Colonne de gauche : déclencheurs · milieu : variables · droite : objectifs.

var sc: Dictionary = {}
var _nodes := {} # clé -> Rect2
var _edges: Array = [] # [de, vers, couleur, libellé]


func setup(scenario: Dictionary) -> void:
	sc = scenario
	custom_minimum_size = Vector2(0, 420)
	_layout()
	queue_redraw()


func _layout() -> void:
	_nodes.clear()
	_edges.clear()
	var trig: Array = sc.get("triggers", [])
	var objs: Array = sc.get("objectives", [])
	var vars: Array = sc.get("variables", [])
	var w := maxf(size.x, 400.0)
	var colw := (w - 40.0) / 3.0
	var y := 30.0
	for t: Dictionary in trig:
		_nodes["t:" + str(t.id)] = Rect2(8, y, colw, 44)
		y += 54
	var h1 := y
	y = 30.0
	for v: Dictionary in vars:
		_nodes["v:" + str(v.name)] = Rect2(20 + colw, y, colw, 30)
		y += 40
	var h2 := y
	y = 30.0
	for o: Dictionary in objs:
		_nodes["o:" + str(o.id)] = Rect2(32 + colw * 2, y, colw, 44)
		y += 54
	custom_minimum_size.y = maxf(maxf(h1, h2), y) + 20
	for t: Dictionary in trig:
		var me := "t:" + str(t.id)
		var ev: Dictionary = t.get("event", {})
		if str(ev.get("type", "")).begins_with("objective_") and str(ev.get("objective", "")) != "":
			_edges.append(["o:" + str(ev.objective), me, Color(0.4, 0.8, 1.0), "QUAND"])
		if ev.get("type", "") == "var_changed" and str(ev.get("var", "")) != "":
			_edges.append(["v:" + str(ev["var"]), me, Color(0.4, 0.8, 1.0), "QUAND"])
		for c in t.get("cond", {}).get("items", []):
			if c.get("type", "") == "objective":
				_edges.append(["o:" + str(c.get("objective", "")), me, Color(1.0, 0.8, 0.3), "SI"])
			if c.get("type", "") == "var":
				_edges.append(["v:" + str(c.get("var", "")), me, Color(1.0, 0.8, 0.3), "SI"])
		for list_key in ["actions", "else"]:
			for a in t.get(list_key, []):
				var at := str(a.get("type", ""))
				if at.begins_with("obj_"):
					_edges.append([me, "o:" + str(a.get("objective", "")), Color(0.4, 1.0, 0.5), "ALORS"])
				elif at.begins_with("var_"):
					_edges.append([me, "v:" + str(a.get("var", "")), Color(0.4, 1.0, 0.5), "ALORS"])
				elif at in ["trigger_run", "trigger_enable"]:
					_edges.append([me, "t:" + str(a.get("trigger", "")), Color(0.8, 0.6, 1.0), "ALORS"])
	for o: Dictionary in objs:
		for a in o.get("after", []):
			_edges.append(["o:" + str(a), "o:" + str(o.id), Color(0.7, 0.75, 0.85), "après"])
		for c in o.get("children", []):
			_edges.append(["o:" + str(c), "o:" + str(o.id), Color(0.7, 0.75, 0.85), "fait partie de"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not sc.is_empty():
		_layout()
		queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := maxf(size.x, 400.0)
	var colw := (w - 40.0) / 3.0
	for pair in [[8.0, "DÉCLENCHEURS"], [20.0 + colw, "VARIABLES"], [32.0 + colw * 2, "OBJECTIFS"]]:
		draw_string(font, Vector2(pair[0], 18), pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, EditorUi.SECTION)
	for e in _edges:
		if not _nodes.has(e[0]) or not _nodes.has(e[1]):
			continue
		var a: Rect2 = _nodes[e[0]]
		var b: Rect2 = _nodes[e[1]]
		var p0 := Vector2(a.end.x if a.position.x < b.position.x else a.position.x, a.get_center().y)
		var p1 := Vector2(b.position.x if a.position.x < b.position.x else b.end.x, b.get_center().y)
		if is_equal_approx(a.position.x, b.position.x):
			p0 = Vector2(a.end.x, a.get_center().y)
			p1 = Vector2(b.end.x, b.get_center().y)
			var mid := Vector2(a.end.x + 24, (p0.y + p1.y) * 0.5)
			draw_polyline(PackedVector2Array([p0, Vector2(mid.x, p0.y), Vector2(mid.x, p1.y), p1]), Color(e[2], 0.8), 2.0)
		else:
			draw_line(p0, p1, Color(e[2], 0.8), 2.0)
		var dir := (p1 - p0).normalized() if p1 != p0 else Vector2.RIGHT
		draw_colored_polygon(PackedVector2Array([p1, p1 - dir * 9 + dir.orthogonal() * 5, p1 - dir * 9 - dir.orthogonal() * 5]), e[2])
	var names := {}
	for t: Dictionary in sc.get("triggers", []):
		names["t:" + str(t.id)] = [str(t.name), Color(0.13, 0.83, 0.93), t.get("enabled", true)]
	for v: Dictionary in sc.get("variables", []):
		names["v:" + str(v.name)] = ["$" + str(v.name), Color(1.0, 0.8, 0.3), true]
	for o: Dictionary in sc.get("objectives", []):
		names["o:" + str(o.id)] = [("◆ " if o.get("kind", "main") == "main" else "◇ ") + str(o.name), Color(0.4, 1.0, 0.5), true]
	for k in _nodes:
		var r: Rect2 = _nodes[k]
		var info: Array = names.get(k, [k, Color.WHITE, true])
		draw_rect(r, Color(0.06, 0.09, 0.15))
		draw_rect(r, Color(info[1], 0.8 if info[2] else 0.3), false, 1.5)
		var txt := str(info[0])
		var tcol := Color(0.9, 0.94, 1.0, 1.0 if info[2] else 0.5)
		var maxw := r.size.x - 12
		if font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= maxw or r.size.y < 40:
			draw_string(font, r.position + Vector2(6, r.size.y * 0.5 + 5), txt, HORIZONTAL_ALIGNMENT_LEFT, maxw, 12, tcol)
		else:
			draw_multiline_string(font, r.position + Vector2(6, 17), txt, HORIZONTAL_ALIGNMENT_LEFT, maxw, 12, 2, tcol)
	if _nodes.is_empty():
		draw_string(font, Vector2(8, 50), "Rien à afficher : ajoute des déclencheurs ou des objectifs.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.65, 0.75))
