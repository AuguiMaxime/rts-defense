class_name EditorCanvas
extends Node2D
## Tout ce que l'éditeur dessine par-dessus la carte : grille, objets, sélection,
## aperçus des outils, vérification des passages.

const T := float(MapView.TILE)
const CHAR_COLORS := {
	".": Color("1f4d2b"), "#": Color("8a8f98"), "W": Color("5a6270"), "M": Color("9ec5ff"), "E": Color("ffa63d"),
	"B": Color("22d3ee"), "b": Color("fbbf24"), "S": Color("f87171"), "~": Color("1e90d6"), "=": Color("3b3f46"),
	"T": Color("8a6a4a"), "H": Color("6b7280"), "Y": Color("8a6a4a"),
}

var ed # MissionEditor (pas de type pour éviter la dépendance circulaire)
var _tex := {}


func _ready() -> void:
	z_index = 5


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var doc: EditorDoc = ed.doc
	if doc == null or ed.grid == null:
		return
	var g: GameGrid = ed.grid
	var w := doc.width()
	var h := doc.height()
	var z: float = ed.camera.zoom.x
	var px := 1.0 / z # un pixel écran, en unités monde
	# Grille
	if ed.show_grid:
		var col := Color(1, 1, 1, 0.09 if z > 0.35 else 0.05)
		for x in w + 1:
			draw_line(Vector2(x * T, 0), Vector2(x * T, h * T), Color(1, 1, 1, 0.16) if x % 5 == 0 else col, px)
		for y in h + 1:
			draw_line(Vector2(0, y * T), Vector2(w * T, y * T), Color(1, 1, 1, 0.16) if y % 5 == 0 else col, px)
	draw_rect(Rect2(0, 0, w * T, h * T), Color(Ui.CYAN, 0.7), false, 2.0 * px)
	var L: EditorLayers = ed.layers
	# Repères de la carte
	if L.visible("spawns"):
		for sp in g.spawn_points:
			var c := (Vector2(sp) + Vector2(0.5, 0.5)) * T
			draw_circle(c, T * 0.42, Color(Ui.RED, 0.3))
			draw_arc(c, T * 0.42, 0, TAU, 24, Ui.RED, 3.0)
	if L.visible("bases"):
		if not g.base2_cells.is_empty():
			var r2 := _cells_rect(g.base2_cells)
			draw_rect(r2, Color(1.0, 0.75, 0.15, 0.22))
			draw_rect(r2.grow(2), Color(1.0, 0.75, 0.15), false, 3.0)
			draw_string(ThemeDB.fallback_font, r2.get_center() + Vector2(-18, 10), "J2", HORIZONTAL_ALIGNMENT_CENTER, 36, 30, Color(1.0, 0.8, 0.2))
		if not g.base_cells.is_empty():
			draw_rect(_cells_rect(g.base_cells).grow(2), Ui.CYAN, false, 3.0)
	if ed.show_paths:
		_draw_paths()
	# Objets
	var wps: Array = []
	for e: Dictionary in doc.entities:
		if not L.entity_visible(e):
			continue
		if e.kind == "waypoint":
			wps.append(e)
		else:
			draw_entity(e, 1.0)
	_draw_waypoints(wps, 1.0)
	# Sélection
	if not ed.floating.is_empty():
		_draw_clip(ed.floating, ed.floating_at)
	else:
		var sb: Rect2i = ed.selection_bounds()
		if sb.has_area():
			var r := Rect2(Vector2(sb.position) * T, Vector2(sb.size) * T)
			draw_rect(r, Color(Ui.CYAN, 0.08))
			draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), Ui.CYAN, 2 * px, 8 * px)
			draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, Ui.CYAN, 2 * px, 8 * px)
			draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), Ui.CYAN, 2 * px, 8 * px)
			draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, Ui.CYAN, 2 * px, 8 * px)
		for id in ed.sel_ids:
			var e := doc.entity_by_id(int(id))
			if not e.is_empty():
				var er := EditorDoc.entity_rect(e)
				draw_rect(Rect2(Vector2(er.position) * T, Vector2(er.size) * T).grow(3), Color.WHITE, false, 2.5 * px)
	_draw_relations(px)
	for id in ed.scenario_highlight():
		var he := doc.entity_by_id(int(id))
		if not he.is_empty():
			var hr := EditorDoc.entity_rect(he)
			var rr := Rect2(Vector2(hr.position) * T, Vector2(hr.size) * T).grow(5)
			draw_rect(rr, Color(Ui.GOLD, 0.18))
			draw_rect(rr, Ui.GOLD, false, 2.5 * px)
			draw_string(ThemeDB.fallback_font, rr.position + Vector2(0, -6), str(he.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Ui.GOLD)
	if ed.band_active:
		var br: Rect2i = ed.band_rect()
		var r := Rect2(Vector2(br.position) * T, Vector2(br.size) * T)
		draw_rect(r, Color(Ui.CYAN, 0.12))
		draw_rect(r, Ui.CYAN, false, 1.5 * px)
	_draw_hover(px)


## Liens de l'objet sélectionné (patrouille, cible, porte, bouclier) et choix en cours sur la carte.
func _draw_relations(px: float) -> void:
	var doc: EditorDoc = ed.doc
	var font := ThemeDB.fallback_font
	var shown: Array = ed.sel_ids.duplicate()
	if not ed.pick.is_empty() and not shown.has(int(ed.pick.id)):
		shown.append(int(ed.pick.id))
	for id in shown:
		var e := doc.entity_by_id(int(id))
		if e.is_empty():
			continue
		var from := _center(e)
		var pts: Array = e.get("patrol", [])
		if not pts.is_empty() and str(e.get("behavior", "")) == "patrol" or (not ed.pick.is_empty() and ed.pick.key == "patrol" and int(ed.pick.id) == int(id)):
			var prev := from
			for i in pts.size():
				var q := (Vector2(int(pts[i][0]), int(pts[i][1])) + Vector2(0.5, 0.5)) * T
				draw_dashed_line(prev, q, Color(Ui.GOLD, 0.8), 3.0, 10.0)
				draw_circle(q, 11, Color(0.1, 0.1, 0.1, 0.85))
				draw_arc(q, 11, 0, TAU, 16, Ui.GOLD, 2.0)
				draw_string(font, q + Vector2(-8, 5), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 16, 13, Ui.GOLD)
				prev = q
			if pts.size() >= 2:
				var first := (Vector2(int(pts[0][0]), int(pts[0][1])) + Vector2(0.5, 0.5)) * T
				draw_dashed_line(prev, first, Color(Ui.GOLD, 0.35), 2.0, 10.0)
		for key in ["target", "link"]:
			var t := doc.entity_by_id(int(e.get(key, -1)))
			if t.is_empty():
				continue
			var to := _center(t)
			var col: Color = Ui.RED if e.kind == "enemy" else Ui.CYAN
			draw_line(from, to, Color(col, 0.85), 3.0)
			var dir := (to - from).normalized()
			draw_colored_polygon(PackedVector2Array([to - dir * 6, to - dir * 26 + dir.orthogonal() * 10, to - dir * 26 - dir.orthogonal() * 10]), col)
			draw_arc(to, 30, 0, TAU, 24, Color(col, 0.7), 2.0)
	if not ed.pick.is_empty() and ed.pick.key != "patrol":
		var accept: Callable = ed.pick.accept
		for x: Dictionary in doc.entities:
			if int(x.id) != int(ed.pick.id) and ed.layers.entity_visible(x) and accept.call(x):
				var r := EditorDoc.entity_rect(x)
				draw_rect(Rect2(Vector2(r.position) * T, Vector2(r.size) * T).grow(4), Color(Ui.GOLD, 0.25 + 0.2 * sin(Time.get_ticks_msec() * 0.008)))
				draw_rect(Rect2(Vector2(r.position) * T, Vector2(r.size) * T).grow(4), Ui.GOLD, false, 2.0 * px)


func _center(e: Dictionary) -> Vector2:
	var r := EditorDoc.entity_rect(e)
	return (Vector2(r.position) + Vector2(r.size) * 0.5) * T


func _cells_rect(cells: Array[Vector2i]) -> Rect2:
	var r := Rect2(Vector2(cells[0]) * T, Vector2(T, T))
	for b in cells:
		r = r.merge(Rect2(Vector2(b) * T, Vector2(T, T)))
	return r


# --- Aperçus d'outils ----------------------------------------------------------------------

func _draw_hover(px: float) -> void:
	var c: Vector2i = ed.hover
	var doc: EditorDoc = ed.doc
	if not doc.inside(c) or not ed.floating.is_empty() or ed.band_active:
		return
	match str(ed.tool):
		"paint":
			if ed.terrain_mat in ["B", "b"]:
				var cx := clampi(c.x, 1, doc.width() - 2)
				var cy := clampi(c.y, 1, doc.height() - 2)
				draw_rect(Rect2(Vector2(cx - 1, cy - 1) * T, Vector2(3, 3) * T), Color(CHAR_COLORS[ed.terrain_mat], 0.35))
			else:
				var r := int(ed.brush) - 1
				var rect := Rect2(Vector2(c - Vector2i(r, r)) * T, Vector2(2 * r + 1, 2 * r + 1) * T)
				draw_rect(rect, Color(CHAR_COLORS.get(ed.terrain_mat, Color.WHITE), 0.3))
				draw_rect(rect, Color.WHITE, false, 1.5 * px)
		"fill", "pipette":
			draw_rect(Rect2(Vector2(c) * T, Vector2(T, T)), Color.WHITE, false, 2 * px)
		"place":
			var e := EditorOps.make_entity(ed.obj_tool, c, ed.obj_opts)
			var er := EditorDoc.entity_rect(e)
			var ok := doc.inside(er.position) and doc.inside(er.end - Vector2i.ONE)
			var tint := Color(1, 1, 1, 0.55) if ok else Color(1, 0.3, 0.3, 0.55)
			if e.kind == "waypoint":
				draw_circle((Vector2(c) + Vector2(0.5, 0.5)) * T, 14, Color(tint, 0.5))
			else:
				draw_entity(e, 0.55, tint)
			draw_rect(Rect2(Vector2(er.position) * T, Vector2(er.size) * T), Ui.GREEN if ok else Ui.RED, false, 2 * px)
		"erase":
			var e2 := doc.entity_at(c, func(x: Dictionary) -> bool: return ed.layers.entity_editable(x))
			if not e2.is_empty():
				var er2 := EditorDoc.entity_rect(e2)
				draw_rect(Rect2(Vector2(er2.position) * T, Vector2(er2.size) * T), Color(Ui.RED, 0.25))
				draw_rect(Rect2(Vector2(er2.position) * T, Vector2(er2.size) * T), Ui.RED, false, 2 * px)
		"select":
			var e3 := doc.entity_at(c, func(x: Dictionary) -> bool: return ed.layers.entity_visible(x))
			if not e3.is_empty():
				var er3 := EditorDoc.entity_rect(e3)
				draw_rect(Rect2(Vector2(er3.position) * T, Vector2(er3.size) * T).grow(2), Color(1, 1, 1, 0.5), false, 1.5 * px)


## Extrait flottant (coller, déplacer) dessiné à sa position.
func _draw_clip(clip: Dictionary, at: Vector2i) -> void:
	var sz: Vector2i = clip.size
	for y in sz.y:
		for x in sz.x:
			var ch: String = clip.chars[y][x]
			if ch != "?":
				draw_rect(Rect2(Vector2(at + Vector2i(x, y)) * T, Vector2(T, T)), Color(CHAR_COLORS.get(ch, Color.WHITE), 0.7))
	var wps: Array = []
	for src: Dictionary in clip.entities:
		var e: Dictionary = src.duplicate()
		var c := at + Vector2i(int(e.cell[0]), int(e.cell[1]))
		e.cell = [c.x, c.y]
		if e.kind == "waypoint":
			wps.append(e)
		else:
			draw_entity(e, 0.75)
	_draw_waypoints(wps, 0.75)
	var r := Rect2(Vector2(at) * T, Vector2(sz) * T)
	draw_rect(r, Color(Ui.GOLD, 0.08))
	draw_rect(r, Ui.GOLD, false, 2.0 / ed.camera.zoom.x)


# --- Vérification des passages --------------------------------------------------------------

func _draw_paths() -> void:
	var info: Dictionary = ed.path_info
	if info.is_empty():
		return
	for c: Vector2i in info.unreachable:
		draw_rect(Rect2(Vector2(c) * T, Vector2(T, T)), Color(1, 0.15, 0.15, 0.28))
	for p: Array in info.routes:
		var pts := PackedVector2Array()
		for c: Vector2i in p:
			pts.append((Vector2(c) + Vector2(0.5, 0.5)) * T)
		if pts.size() >= 2:
			draw_polyline(pts, Color(1.0, 0.65, 0.2, 0.85), 4.0)
	for c: Vector2i in info.blocked:
		var q := (Vector2(c) + Vector2(0.5, 0.5)) * T
		draw_line(q - Vector2(18, 18), q + Vector2(18, 18), Ui.RED, 5.0)
		draw_line(q + Vector2(-18, 18), q + Vector2(18, -18), Ui.RED, 5.0)


# --- Objets --------------------------------------------------------------------------------

func tex(sprite: String) -> Texture2D:
	if not _tex.has(sprite):
		_tex[sprite] = UnitsView.deco_texture(sprite)
	return _tex[sprite]


func draw_entity(e: Dictionary, alpha := 1.0, tint := Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	var c := Vector2(int(e.cell[0]), int(e.cell[1]))
	var center := (c + Vector2(0.5, 0.5)) * T
	var m := Color(tint, tint.a * alpha)
	match str(e.kind):
		"structure":
			var def: Dictionary = Balance.ENEMY_STRUCTURES.get(e.type, {})
			var sz := float(def.get("size", 1)) * T
			var r := Rect2(c * T, Vector2(sz, sz))
			var look := str(def.get("look", ""))
			var tx: Texture2D = Sprites.W_BASE if look == "hq" else (Sprites.W_BARRACKS if look in ["barracks", "bunker"] else null)
			if tx == null and Sprites.TOWER_LOOK.has(look):
				draw_texture_rect(Sprites.TOWER_LOOK[look].base, r, false, Color(1, 0.5, 0.45, m.a))
				var k := r.size.x * 0.9
				draw_texture_rect(Sprites.TOWER_LOOK[look].turret, Rect2(r.get_center() - Vector2(k, k) / 2, Vector2(k, k)), false, Color(1, 0.6, 0.55, m.a))
			elif look == "generator":
				draw_rect(r.grow(-6), Color(0.18, 0.1, 0.12, m.a))
				draw_circle(r.get_center(), sz * 0.28, Color(1.0, 0.3, 0.25, m.a))
				draw_arc(r.get_center(), sz * 0.36, 0, TAU, 32, Color(1.0, 0.55, 0.3, m.a), 4.0)
			elif tx != null:
				draw_texture_rect(tx, r, false, Color(1, 0.5, 0.45, m.a))
			else:
				draw_texture_rect(Sprites.ENEMY_LOOK.siege.tex, r, false, m)
			draw_rect(r, Color(1, 0.2, 0.2, m.a), false, 3.0)
		"enemy":
			var lk: Dictionary = Sprites.ENEMY_LOOK.get(e.type, {})
			if not lk.is_empty():
				draw_texture_rect(lk.tex, Rect2(center - Vector2(28, 28), Vector2(56, 56)), false, m)
			draw_arc(center, T * 0.45, 0, TAU, 20, Color(1, 0.25, 0.2, m.a), 2.5)
			if e.get("hold", false) or e.get("behavior", "") == "static":
				draw_string(font, center + Vector2(-6, -18), "■", HORIZONTAL_ALIGNMENT_CENTER, 12, 14, Color(1, 0.4, 0.3, m.a))
		"ally_tower":
			var tl: Dictionary = Sprites.TOWER_LOOK.get(e.type, {})
			if not tl.is_empty():
				draw_texture_rect(tl.base, Rect2(c * T, Vector2(T, T)), false, m)
				draw_texture_rect(tl.turret, Rect2(center - Vector2(T, T) * 0.45, Vector2(T, T) * 0.9), false, m)
			draw_rect(Rect2(c * T, Vector2(T, T)), Color(Ui.GREEN, m.a), false, 2.5)
			draw_string(font, c * T + Vector2(4, 16), "N%d" % int(e.get("level", 1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Ui.GREEN, m.a))
		"ally_unit", "vip":
			var ul: Dictionary = Sprites.UNIT_LOOK.get(e.get("type", "soldier"), {})
			if not ul.is_empty():
				draw_texture_rect(ul.tex, Rect2(center - Vector2(26, 26), Vector2(52, 52)), false, Color(ul.tint, m.a))
			draw_arc(center, T * 0.45, 0, TAU, 20, Color(Ui.GOLD if e.kind == "vip" else Ui.GREEN, m.a), 2.5)
			if e.kind == "vip":
				draw_string(font, center + Vector2(-20, -24), "VIP", HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(Ui.GOLD, m.a))
			elif not e.get("selectable", true):
				draw_string(font, center + Vector2(-20, -24), "IA", HORIZONTAL_ALIGNMENT_CENTER, 40, 15, Color(Ui.GREEN, m.a))
		"door":
			var r := Rect2(c * T, Vector2(EditorDoc.entity_size(e)) * T)
			if e.get("open", false):
				draw_rect(r.grow(-4), Color(0.42, 0.46, 0.52, m.a), false, 3.0)
			else:
				draw_rect(r.grow(-4), Color(0.42, 0.46, 0.52, m.a))
				var n := int(maxf(r.size.x, r.size.y) / 16.0)
				for i in n:
					var k := 8.0 + i * 16.0
					if e.get("vertical", false):
						draw_line(Vector2(r.position.x + 6, r.position.y + k), Vector2(r.end.x - 6, r.position.y + k + 8), Color(1.0, 0.78, 0.1, m.a), 4.0)
					else:
						draw_line(Vector2(r.position.x + k, r.end.y - 6), Vector2(r.position.x + k + 8, r.position.y + 6), Color(1.0, 0.78, 0.1, m.a), 4.0)
			draw_rect(r.grow(-2), Color(0.05, 0.05, 0.06, m.a), false, 3.0)
			draw_string(font, r.position + Vector2(4, -6), "PORTE" + (" (ouverte)" if e.get("open", false) else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.9, 1.0, m.a))
		"shield":
			var rad := float(e.get("radius", 4.0)) * T
			draw_circle(center, rad, Color(0.35, 0.65, 1.0, 0.08 * m.a))
			draw_arc(center, rad, 0, TAU, 48, Color(0.5, 0.8, 1.0, 0.8 * m.a), 3.0)
			draw_circle(center, 14, Color(0.3, 0.6, 1.0, m.a))
			draw_string(font, center + Vector2(-40, -20), "BOUCLIER", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color(0.6, 0.85, 1.0, m.a))
		"terminal":
			draw_rect(Rect2(center - Vector2(22, 18), Vector2(44, 36)), Color(0.12, 0.15, 0.2, m.a))
			draw_rect(Rect2(center - Vector2(16, 12), Vector2(32, 18)), Color(0.2, 0.7, 1.0, 0.8 * m.a))
			draw_string(font, center + Vector2(-40, -24), "TERMINAL %d s" % int(e.get("time", 5)), HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(0.6, 0.85, 1.0, m.a))
		"prisoners":
			var r := Rect2(c * T + Vector2(4, 4), Vector2(T - 8, T - 8))
			draw_rect(r, Color(0.15, 0.12, 0.1, 0.8 * m.a))
			for i in 5:
				var x := r.position.x + i * (r.size.x / 4.0)
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.55, 0.58, 0.62, m.a), 3.0)
			draw_string(font, center + Vector2(-40, -26), "PRISONNIERS ×%d" % int(e.get("count", 3)), HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(0.6, 0.85, 1.0, m.a))
		"pickup":
			draw_rect(Rect2(center - Vector2(13, 11), Vector2(26, 22)), Color(0.85, 0.65, 0.2, m.a))
			draw_string(font, center + Vector2(-50, -18), str(e.get("label", "Objet")), HORIZONTAL_ALIGNMENT_CENTER, 100, 13, Color(1.0, 0.9, 0.5, m.a))
		"escortee":
			draw_rect(Rect2(center - Vector2(22, 16), Vector2(44, 32)), Color(0.3, 0.6, 0.4, m.a))
			draw_arc(center, T * 0.5, 0, TAU, 20, Color(Ui.GREEN, m.a), 3.0)
			draw_string(font, center + Vector2(-30, -26), "DÉPART", HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color(Ui.GREEN, m.a))
		"defend":
			var sz := float(Content.building(str(e.type)).get("size", 1)) * T
			var r := Rect2(c * T, Vector2(sz, sz))
			var lk: Array = Sprites.PRODUCER_LOOK.get(e.type, [Sprites.W_HOUSE, Color.WHITE])
			draw_texture_rect(lk[0], r, false, Color(lk[1], m.a))
			draw_rect(r.grow(3), Color(Ui.GOLD, m.a), false, 4.0)
			draw_string(font, Vector2(r.position.x, r.position.y - 6), "★ À DÉFENDRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Ui.GOLD, m.a))
		"zone":
			var rad := float(e.get("radius", 2.5)) * T
			var role := str(e.get("role", "capture"))
			var col: Color = {"goal": Ui.GREEN, "capture": Ui.GOLD, "extraction": Ui.CYAN, "passage": Color(0.7, 0.6, 1.0), "trigger": Ui.MAGENTA}.get(role, Ui.GOLD)
			draw_circle(center, rad, Color(col, 0.12 * m.a))
			draw_arc(center, rad, 0, TAU, 40, Color(col, m.a), 3.0)
			var lbl := str(e.get("name", "")) if role != "capture" else "%s · %d s" % [e.get("name", ""), int(e.get("time", 30))]
			draw_string(font, center + Vector2(-60, 6), lbl, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(col, m.a))
		"deco":
			var sp := str(e.get("sprite", ""))
			var rot := int(e.get("rot", 0))
			var fp := Mission.deco_footprint(sp, rot)
			var t := tex(sp)
			if t == null:
				draw_rect(Rect2(c * T, Vector2(fp) * T), Color(1, 0, 1, 0.35 * m.a))
				draw_string(font, c * T + Vector2(4, 18), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.MAGENTA)
			else:
				UnitsView.draw_deco(self, t, Vector2i(c), Mission.deco_size(sp), rot, T, m, e.get("flip", false))
			if e.get("block", false):
				draw_rect(Rect2(c * T, Vector2(fp) * T), Color(1, 1, 1, 0.45 * m.a), false, 2.0)


func _draw_waypoints(wps: Array, alpha: float) -> void:
	if wps.is_empty():
		return
	var font := ThemeDB.fallback_font
	wps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	var wcol: Color = Ui.RED if ed.doc.mission.get("type", "") == "convoy" else Ui.GREEN
	wcol.a = alpha
	var prev := Vector2.ZERO
	for i in wps.size():
		var e: Dictionary = wps[i]
		var p := (Vector2(int(e.cell[0]), int(e.cell[1])) + Vector2(0.5, 0.5)) * T
		if i > 0:
			draw_dashed_line(prev, p, Color(wcol, 0.7 * alpha), 3.0, 12.0)
		draw_circle(p, 14, Color(0.1, 0.1, 0.1, 0.85 * alpha))
		draw_arc(p, 14, 0, TAU, 20, wcol, 2.5)
		draw_string(font, p + Vector2(-10, 6), str(int(e.get("order", i)) + 1), HORIZONTAL_ALIGNMENT_CENTER, 20, 16, wcol)
		if float(e.get("pause", 0.0)) > 0.0:
			draw_string(font, p + Vector2(-30, -20), "⏸ %d s" % int(e.pause), HORIZONTAL_ALIGNMENT_CENTER, 60, 15, Color(Ui.GOLD, alpha))
		prev = p
