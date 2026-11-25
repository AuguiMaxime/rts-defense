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
const COLOR_ENEMY_BAR := Color(1.0, 0.35, 0.3)
const COLOR_SELECT_FILL := Color(0.40, 1.0, 0.45, 0.12)

var world: GameWorld
var skin_tint := Color(1, 1, 1)
var focused_site: BuildSite = null
var sel_sites: Array[BuildSite] = []
var show_ranges := false
signal shake(strength: float)
signal base_hit
## Événements du scénario (messages, alertes, objectifs…) pour l'interface.
signal scenario_event(ev: Dictionary)

var tutorial_marker := Vector2.INF # en cases ; INF = aucun repère
var selected: Array[Worker] = []
var sel_units: Array[Unit] = []
var sel_base := false
## Ligne de ralliement du producteur sélectionné (en cases) ; INF = aucune.
var rally_from := Vector2.INF
var rally_to := Vector2.INF
## Bâtiment à poser (mode construction) : fantôme sur la dernière case touchée.
var ghost_kind := ""
var _move_marker := Vector2.INF
var _move_marker_t := 0.0


## Repère d'ordre de déplacement (cercle vert qui se resserre).
func move_marker(p: Vector2) -> void:
	_move_marker = p * TILE
	_move_marker_t = 0.5
var selection_rect := Rect2() # en pixels monde, vide = pas de sélection en cours
var _effects: Array[Dictionary] = []
var _anim := 0.0


func _process(delta: float) -> void:
	_move_marker_t -= delta
	_anim += delta
	if world != null:
		for ev in world.take_events():
			_sound(ev)
			ev["ttl"] = {"death": 0.45, "depleted": 0.8, "orbital": 0.9, "bounty": 0.9, "spawned": 0.5, "chain": 0.22, "wave_fx": 0.4, "crit": 0.8, "ability": 0.6, "heal": 0.35}.get(ev.type,
					0.08 if ev.get("kind", "") in ["gun", "soldier", "warrior", "grenadier"] else (0.3 if ev.get("kind", "") in ["sniper", "sniper_tower"] else (0.2 if ev.get("kind", "") == "flame" else 0.18)))
			ev["life"] = ev.ttl
			_effects.append(ev)
	for ev in _effects:
		ev.ttl -= delta
	_effects = _effects.filter(func(ev: Dictionary) -> bool: return ev.ttl > 0.0)
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	if show_ranges:
		for s in world.sites:
			if s.built and s.is_tower():
				draw_circle((Vector2(s.cell) + Vector2(0.5, 0.5)) * TILE, s.stats().range * TILE, Color(0.13, 0.83, 0.93, 0.06))
				draw_arc((Vector2(s.cell) + Vector2(0.5, 0.5)) * TILE, s.stats().range * TILE, 0, TAU, 64, Color(0.13, 0.83, 0.93, 0.25), 1.5)
	if sel_base:
		var br := Rect2(world.base_rect().position * TILE, world.base_rect().size * TILE).grow(4)
		_draw_corners(br, COLOR_SELECTED)
	if rally_to != Vector2.INF and rally_from != Vector2.INF:
		var a := rally_from * TILE
		var b := rally_to * TILE
		draw_dashed_line(a, b, Color(COLOR_SELECTED, 0.8), 2.5, 10.0)
		draw_line(b, b + Vector2(0, -34), Color(0.9, 1, 0.9), 3.0)
		var wave_k := sin(_anim * 6.0) * 3.0
		draw_colored_polygon(PackedVector2Array([b + Vector2(0, -34), b + Vector2(22, -28 + wave_k), b + Vector2(0, -20)]), COLOR_SELECTED)
		draw_circle(b, 5, COLOR_SELECTED)
	for other in sel_sites:
		if other != focused_site and world.sites.has(other):
			_draw_corners(Rect2(Vector2(other.cell) * TILE, Vector2.ONE * other.size * TILE).grow(4), COLOR_SELECTED)
	if focused_site != null and world.sites.has(focused_site):
		var fc := focused_site.center() * TILE
		_draw_corners(Rect2(Vector2(focused_site.cell) * TILE, Vector2.ONE * focused_site.size * TILE).grow(4), COLOR_SELECTED)
		if focused_site.is_tower():
			var rad: float = focused_site.stats().range * TILE
			draw_circle(fc, rad, Color(0.13, 0.83, 0.93, 0.10))
			draw_arc(fc, rad, 0, TAU, 72, Color(0.13, 0.83, 0.93, 0.7), 2.5)
	for c: Vector2i in world.deposit_left:
		var left: int = world.deposit_left[c]
		var mx := world.deposit_max(c)
		if left > 0 and left < mx:
			var r := Rect2(Vector2(c) * TILE + Vector2(8, TILE + 4), Vector2(TILE - 16, 0))
			_draw_bar(r, float(left) / mx, MapView.COLOR_METAL if world.grid.get_cell(c) == GameGrid.Cell.METAL else MapView.COLOR_ESSENCE, 5.0)
	_draw_mission_layer()
	for s in world.sites:
		_draw_site(s)
	for w in world.workers:
		_draw_worker(w)
	for u in world.units:
		_draw_unit(u)
	for e in world.enemies:
		if not e.flying:
			_draw_enemy(e)
	for e in world.enemies:
		if e.flying:
			_draw_enemy(e)
	_draw_effects()
	if _move_marker_t > 0.0:
		var k := _move_marker_t / 0.5
		draw_arc(_move_marker, 10 + 22 * k, 0, TAU, 28, Color(0.4, 1.0, 0.45, k), 3.0)
		draw_line(_move_marker + Vector2(-7, -7), _move_marker + Vector2(7, 7), Color(0.4, 1.0, 0.45, k), 3.0)
		draw_line(_move_marker + Vector2(7, -7), _move_marker + Vector2(-7, 7), Color(0.4, 1.0, 0.45, k), 3.0)
	_draw_base_hp()
	if tutorial_marker != Vector2.INF:
		var c := tutorial_marker * TILE
		var k := fmod(_anim * 1.2, 1.0)
		draw_arc(c, 34 + 40 * k, 0, TAU, 48, Color(0.13, 0.83, 0.93, 1.0 - k), 4.0)
		draw_arc(c, 34, 0, TAU, 48, Color(0.13, 0.83, 0.93, 0.9), 3.0)
		var bob := sin(_anim * 5.0) * 8.0
		var tip := c + Vector2(0, -46 + bob)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-16, -26), tip + Vector2(16, -26)]), Color(0.13, 0.83, 0.93))
	if selection_rect.has_area():
		draw_rect(selection_rect, COLOR_SELECT_FILL)
		draw_rect(selection_rect, COLOR_SELECTED, false, 2.0)
	if not Ui.debug_view.is_empty():
		_draw_debug()


## Affichage de debug (outils de test F2) : zones, chemins, portées.
func _draw_debug() -> void:
	var font := ThemeDB.fallback_font
	if Ui.debug_view.get("zones", false):
		if world.mission != null:
			for z: Dictionary in world.mission.zones:
				var c: Vector2 = z.pos * TILE
				var rad := float(z.radius) * TILE
				var col: Color = {"capture": Color(1, 0.8, 0.2), "goal": Color(0.4, 1, 0.5), "extraction": Color(0.3, 0.8, 1), "trigger": Color(1, 0.4, 1)}.get(str(z.role), Color.WHITE)
				draw_circle(c, rad, Color(col, 0.08))
				draw_arc(c, rad, 0, TAU, 48, Color(col, 0.9), 2.0)
				var txt := "%s  [%s]" % [z.get("name", ""), z.role]
				if z.role == "capture":
					txt += "  %d %%" % roundi(float(z.progress) * 100.0) if not z.captured else "  prise"
				draw_string(font, c + Vector2(-120, -rad - 6), txt, HORIZONTAL_ALIGNMENT_CENTER, 240, 15, col)
		var names: Dictionary = world.waves.plan_spawn_names
		for sp in world.grid.spawn_points:
			var c := (Vector2(sp) + Vector2(0.5, 0.5)) * TILE
			draw_arc(c, TILE * 0.6, 0, TAU, 24, Color(1, 0.3, 0.3), 2.5)
			draw_string(font, c + Vector2(-90, -TILE * 0.7), str(names.get("%d,%d" % [sp.x, sp.y], "Apparition (%d, %d)" % [sp.x, sp.y])), HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color(1, 0.6, 0.6))
	if Ui.debug_view.get("paths", false):
		for e in world.enemies:
			_draw_debug_path(e.pos, e.path, Color(1, 0.35, 0.3, 0.75))
			if e.goal_pos != Vector2.INF:
				draw_dashed_line(e.pos * TILE, e.goal_pos * TILE, Color(1, 0.6, 0.2, 0.6), 1.5, 8.0)
		for u in world.units:
			_draw_debug_path(u.pos, u.path, Color(0.4, 1, 0.5, 0.75))
	if Ui.debug_view.get("ranges", false):
		for s in world.sites:
			if s.built and s.is_tower():
				var c := s.center() * TILE
				draw_arc(c, s.stats().range * TILE, 0, TAU, 64, Color(0.13, 0.83, 0.93, 0.6), 1.5)
		for u in world.units:
			var r := float(u.stats().get("range", 0.0))
			if r > 0.0:
				draw_arc(u.pos * TILE, r * TILE, 0, TAU, 40, Color(0.4, 1, 0.5, 0.5), 1.5)
		for e in world.enemies:
			if e.hp > 0 and e.attack_range > 0.0:
				draw_arc(e.pos * TILE, e.attack_range * TILE, 0, TAU, 32, Color(1, 0.35, 0.3, 0.45), 1.5)


func _draw_debug_path(from: Vector2, path: Array[Vector2i], col: Color) -> void:
	if path.is_empty():
		return
	var pts := PackedVector2Array([from * TILE])
	for c in path:
		pts.append((Vector2(c) + Vector2(0.5, 0.5)) * TILE)
	draw_polyline(pts, col, 2.0)
	draw_circle(pts[pts.size() - 1], 5, col)


func _draw_worker(w: Worker) -> void:
	var p := w.pos * TILE
	if selected.has(w):
		draw_circle(p, 22, Color(COLOR_SELECTED, 0.18))
		draw_arc(p, 22, 0, TAU, 32, COLOR_SELECTED, 3.0)
	draw_set_transform(p + Vector2(3, 5), w.facing.angle() + PI / 2.0)
	draw_texture_rect(Sprites.WORKER, Rect2(-22, -22, 44, 44), false, Color(0, 0, 0, 0.3))
	draw_set_transform(p, w.facing.angle() + PI / 2.0)
	draw_texture_rect(Sprites.WORKER, Rect2(-22, -22, 44, 44), false)
	draw_set_transform(Vector2.ZERO)
	if w.carry_amount > 0:
		var c := MapView.COLOR_METAL if w.carry_type == GameGrid.Cell.METAL else MapView.COLOR_ESSENCE
		draw_circle(p + Vector2(12, -14), 7, Color(0, 0, 0, 0.6))
		draw_circle(p + Vector2(12, -14), 5.5, c)
	if w.hp < Balance.WORKER_HP:
		_draw_bar(Rect2(p - Vector2(18, 20), Vector2(36, 0)), float(w.hp) / Balance.WORKER_HP)
	if w.state == Worker.State.BUILDING:
		draw_arc(p, 16, -PI * 0.8, -PI * 0.2, 12, COLOR_WORKER, 3.0)


func _draw_site(s: BuildSite) -> void:
	var r := Rect2(Vector2(s.cell) * TILE, Vector2.ONE * s.size * TILE)
	if not s.built:
		var base_tex: Texture2D = Sprites.TOWER_LOOK[s.kind].base if s.is_tower() else Sprites.TOWER_BASE3
		draw_texture_rect(base_tex, r, false, Color(1, 1, 1, 0.2 + 0.4 * s.progress()))
		draw_texture_rect(Sprites.GEN_SITE, r.grow(-2), false, Color(1, 1, 1, 0.9))
		var a := r.grow(-3).position
		var b := r.grow(-3).end
		for seg in [[a, Vector2(b.x, a.y)], [Vector2(b.x, a.y), b], [b, Vector2(a.x, b.y)], [Vector2(a.x, b.y), a]]:
			draw_dashed_line(seg[0], seg[1], COLOR_SITE, 3.0, 8.0)
		_draw_bar(r.grow(-6), s.progress(), COLOR_SITE)
		if s.hp < Balance.SITE_HP:
			_draw_bar(Rect2(r.position + Vector2(6, 64), Vector2(52, 0)), float(s.hp) / Balance.SITE_HP)
		return
	if s.kind == "house":
		draw_texture_rect(Sprites.W_HOUSE, r.grow(-2), false, Color(0, 0, 0, 0.3))
		draw_texture_rect(Sprites.W_HOUSE, r.grow(-4), false)
	elif s.is_producer():
		_draw_producer(s, r)
	else:
		var look: Dictionary = Sprites.TOWER_LOOK[s.kind]
		draw_texture_rect(look.base, r, false)
		if s.beam_target != null and s.beam_target.hp > 0:
			var from := r.get_center()
			var to := (s.beam_target.pos + s.beam_target.visual_offset) * TILE
			draw_line(from, to, Color(0.4, 0.95, 1.0, 0.35), 9.0)
			draw_line(from, to, Color(0.85, 1.0, 1.0, 0.95), 3.0)
			draw_circle(to, 7, Color(0.85, 1.0, 1.0, 0.8))
		var sc: float = look.scale * (1.0 + 0.07 * (s.level - 1))
		var tex: Texture2D = look.turret
		var pivot: Vector2 = look.pivot
		# ombre portée puis tourelle, pivot sur la « tête »
		var rot: float = look.get("rot", Sprites.W_ANGLE_OFFSET)
		draw_set_transform(r.get_center() + Vector2(4, 6), s.aim_angle + rot, Vector2(sc, sc))
		draw_texture(tex, -pivot, Color(0, 0, 0, 0.35))
		draw_set_transform(r.get_center(), s.aim_angle + rot, Vector2(sc, sc))
		draw_texture(tex, -pivot, look.tint * skin_tint)
		draw_set_transform(Vector2.ZERO)
		for i in s.level - 1:
			draw_rect(Rect2(r.position + Vector2(6 + i * 10, r.size.y - 12), Vector2(7, 7)), Color(0.98, 0.75, 0.15))
	if s.hp < s.max_hp:
		_draw_bar(r.grow(-6), float(s.hp) / s.max_hp)
	for w in world.workers:
		if w.target_site == s and w.state == Worker.State.REPAIRING:
			draw_arc(r.get_center(), 36 * s.size, _anim * 4.0, _anim * 4.0 + 1.5, 16, COLOR_BAR, 3.0)
			break


## Plateforme métallique d'un bâtiment 2x2.
func _draw_plate(r: Rect2, mod := Color(1, 1, 1)) -> void:
	var inner := r.grow(-5)
	draw_rect(inner, Color(0.16, 0.2, 0.25) * mod)
	draw_rect(inner.grow(-6), Color(0.24, 0.29, 0.35) * mod)
	draw_rect(inner, Color(0.07, 0.09, 0.12, mod.a), false, 3.0)
	for i in 4:
		var corners: Array[Vector2] = [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]
		var corner: Vector2 = corners[i]
		var dir: Vector2 = (inner.get_center() - corner).sign() * 12.0
		draw_rect(Rect2(corner + Vector2(minf(dir.x, 0), minf(dir.y, 0)), dir.abs()), Color(0.13, 0.83, 0.93, 0.9 * mod.a))


## Caserne et usine : plateforme, emblème, lumière de production.
func _draw_producer(s: BuildSite, r: Rect2) -> void:
	var c := r.get_center()
	var busy := s.producer != null and s.producer.busy()
	var look: Array = Sprites.PRODUCER_LOOK.get(s.kind, [Sprites.W_BARRACKS, Color(1, 1, 1)])
	var tex: Texture2D = look[0]
	draw_texture_rect(tex, Rect2(r.position + Vector2(5, 7), r.size), false, Color(0, 0, 0, 0.35))
	draw_texture_rect(tex, r, false, look[1])
	if s.kind in ["forge", "research", "lab"]:
		# Emblème du bâtiment de recherche
		var em: String = {"forge": "⚒", "research": "⚛", "lab": "⚗"}[s.kind]
		var col: Color = {"forge": Color(1.0, 0.6, 0.25), "research": Color(0.75, 0.55, 1.0), "lab": Color(0.4, 1.0, 0.6)}[s.kind]
		draw_circle(c, 15, Color(0.05, 0.07, 0.1, 0.85))
		draw_arc(c, 15, 0, TAU, 24, col, 2.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(-9, 7), em, HORIZONTAL_ALIGNMENT_CENTER, 18, 20, col)
	if busy and s.kind == "factory":
		for k in 2:
			var ch := r.position + Vector2(30 + k * 68, 22)
			var puff := fmod(_anim * 0.8 + k * 0.5, 1.0)
			draw_circle(ch + Vector2(6, -puff * 22), 6 + puff * 8, Color(0.7, 0.75, 0.8, 0.45 * (1.0 - puff)))
	if busy:
		draw_arc(c, r.size.x * 0.2, _anim * 2.0, _anim * 2.0 + 1.2, 16, Color(0.4, 1.0, 0.45, 0.6), 3.0)
	var lamp := Color(0.4, 1.0, 0.45) if busy else Color(0.3, 0.35, 0.4)
	draw_circle(r.position + Vector2(r.size.x - 18, 18), 6, lamp)
	if busy:
		draw_arc(r.position + Vector2(r.size.x - 18, 18), 11, -PI / 2, -PI / 2 + TAU * s.producer.ratio(), 20, Color(0.4, 1.0, 0.45), 3.0)


var _deco_cache := {}


## Dessine un décor de base.x × base.y cases, pivoté de rot quarts de tour, posé à partir de la case cell.
static func draw_deco(ci: CanvasItem, tex: Texture2D, cell: Vector2i, base: Vector2i, rot: int, t: float, tint := Color.WHITE, flip := false) -> void:
	if tex == null:
		return
	var fp := Vector2(base.y, base.x) if rot % 2 == 1 else Vector2(base)
	var center := (Vector2(cell) + fp * 0.5) * t
	var box := Vector2(base) * t
	# L'image garde ses proportions dans son emprise, légèrement débordante pour éviter les jours.
	var k := minf(box.x / tex.get_width(), box.y / tex.get_height()) * 1.08
	var sz := Vector2(tex.get_width(), tex.get_height()) * k
	ci.draw_set_transform(center, rot * PI / 2.0, Vector2(-1, 1) if flip else Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-sz * 0.5, sz), false, tint)
	ci.draw_set_transform(Vector2.ZERO)


static func deco_texture(name: String) -> Texture2D:
	var p := "res://assets/deco/%s.png" % name
	if ResourceLoader.exists(p):
		return load(p)
	if _file_decos.has(name):
		return _file_decos[name]
	# PNG ajouté sans passer par l'import de Godot, ou décor importé avec un pack : lu directement.
	for path in [p, "user://deco/%s.png" % name]:
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				_file_decos[name] = ImageTexture.create_from_image(img)
				return _file_decos[name]
	return null


static var _file_decos := {} # décors lus directement depuis un PNG


## Décor, zones et trajet du convoi allié (sous les unités).
func _draw_mission_layer() -> void:
	var m: Mission = world.mission
	if m == null:
		return
	for d in m.decos:
		if not _deco_cache.has(d.sprite):
			_deco_cache[d.sprite] = deco_texture(d.sprite)
		draw_deco(self, _deco_cache[d.sprite], d.cell, d.base, d.rot, float(TILE), Color.WHITE, d.get("flip", false))
	_draw_interactive(m)
	# Marqueurs posés par les déclencheurs
	if world.scenario != null:
		for mk in world.scenario.markers:
			var c: Vector2 = mk.pos * TILE
			var k := fmod(_anim, 1.2) / 1.2
			draw_arc(c, 30 + 40 * k, 0, TAU, 32, Color(1.0, 0.85, 0.2, 1.0 - k), 4.0)
			draw_arc(c, 26, 0, TAU, 32, Color(1.0, 0.85, 0.2), 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-12, -60), c + Vector2(12, -60), c + Vector2(0, -36)]), Color(1.0, 0.85, 0.2))
			if str(mk.text) != "":
				draw_string(ThemeDB.fallback_font, c + Vector2(-90, -68), str(mk.text), HORIZONTAL_ALIGNMENT_CENTER, 180, 18, Color(1.0, 0.9, 0.4))
	for z in m.zones:
		var c: Vector2 = z.pos * TILE
		var rad: float = z.radius * TILE
		if z.role == "goal":
			draw_circle(c, rad, Color(0.3, 1.0, 0.45, 0.10))
			draw_arc(c, rad, _anim, _anim + TAU, 48, Color(0.3, 1.0, 0.45, 0.8), 3.0)
			draw_string(ThemeDB.fallback_font, c + Vector2(-40, 8), "ARRIVÉE", HORIZONTAL_ALIGNMENT_CENTER, 80, 20, Color(0.3, 1.0, 0.45))
		else:
			var col := Color(0.3, 1.0, 0.45) if z.captured else Color(1.0, 0.8, 0.2)
			draw_circle(c, rad, Color(col, 0.10))
			draw_arc(c, rad, 0, TAU, 48, Color(col, 0.7), 3.0)
			var k: float = 1.0 if z.captured else z.progress / maxf(1.0, float(m.data.get("time", 30.0)))
			draw_arc(c, rad - 8, -PI / 2, -PI / 2 + TAU * k, 48, col, 6.0)
			draw_line(c + Vector2(0, 18), c + Vector2(0, -26), Color(0.9, 0.9, 0.9), 3.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26), c + Vector2(22, -19 + sin(_anim * 6.0) * 2), c + Vector2(0, -12)]), col)
	# Trajet restant de chaque convoi allié en route.
	for cv in m.convoys:
		if cv.state != "go":
			continue
		var u := world.unit_by_id(int(cv.uid))
		if u == null:
			continue
		var prev := u.pos * TILE
		for i in range(int(cv.i), m.route_cells.size()):
			var q := (Vector2(m.route_cells[i]) + Vector2(0.5, 0.5)) * TILE
			draw_dashed_line(prev, q, Color(0.3, 1.0, 0.45, 0.5), 3.0, 12.0)
			draw_circle(q, 6, Color(0.3, 1.0, 0.45, 0.8))
			prev = q
	# Trajet des convois ennemis tracé dans l'éditeur.
	if m.foe_route.size() >= 2:
		for i in range(1, m.foe_route.size()):
			draw_line(m.foe_route[i - 1] * TILE, m.foe_route[i] * TILE, Color(1.0, 0.35, 0.3, 0.18), 6.0)
	# Bâtiments à défendre.
	for id in m.defend_ids:
		var s := world.site_by_id(id)
		if s == null:
			continue
		var r := Rect2(s.rect().position * TILE, s.rect().size * TILE).grow(6)
		draw_rect(r, Color(1.0, 0.8, 0.2, 0.55 + 0.35 * sin(_anim * 4.0)), false, 4.0)
		draw_string(ThemeDB.fallback_font, Vector2(r.get_center().x - 100, r.position.y - 6), "★ À DÉFENDRE", HORIZONTAL_ALIGNMENT_CENTER, 200, 18, Color(1.0, 0.85, 0.3))


## Portes, boucliers, terminaux, prisonniers, objets à récupérer (dessins provisoires).
func _draw_interactive(m: Mission) -> void:
	var font := ThemeDB.fallback_font
	var t := float(TILE)
	for d in m.doors:
		var cells: Array = d.cells
		if cells.is_empty():
			continue
		var r := Rect2(Vector2(cells[0]) * t, Vector2(t, t))
		for c in cells:
			r = r.merge(Rect2(Vector2(c) * t, Vector2(t, t)))
		if d.open:
			# Battants rangés sur les côtés
			if d.vertical:
				draw_rect(Rect2(r.position, Vector2(t, 10)), Color(0.35, 0.38, 0.42))
				draw_rect(Rect2(Vector2(r.position.x, r.end.y - 10), Vector2(t, 10)), Color(0.35, 0.38, 0.42))
			else:
				draw_rect(Rect2(r.position, Vector2(10, t)), Color(0.35, 0.38, 0.42))
				draw_rect(Rect2(Vector2(r.end.x - 10, r.position.y), Vector2(10, t)), Color(0.35, 0.38, 0.42))
		else:
			var inner := r.grow(-6)
			draw_rect(r.grow(-2), Color(0.12, 0.13, 0.15))
			draw_rect(inner, Color(0.42, 0.46, 0.52))
			var n := int((inner.size.x if not d.vertical else inner.size.y) / 14.0)
			for i in n:
				var k := i * 14.0
				if d.vertical:
					draw_line(Vector2(inner.position.x, inner.position.y + k), Vector2(inner.end.x, inner.position.y + k + 10), Color(1.0, 0.78, 0.1, 0.9), 5.0)
				else:
					draw_line(Vector2(inner.position.x + k, inner.end.y), Vector2(inner.position.x + k + 10, inner.position.y), Color(1.0, 0.78, 0.1, 0.9), 5.0)
			draw_rect(r.grow(-2), Color(0.05, 0.05, 0.06), false, 3.0)
	for sh in m.shields:
		if not sh.active:
			continue
		var c: Vector2 = sh.pos * t
		var rad: float = sh.radius * t
		draw_circle(c, rad, Color(0.35, 0.65, 1.0, 0.10 + 0.04 * sin(_anim * 3.0)))
		draw_arc(c, rad, 0, TAU, 64, Color(0.5, 0.8, 1.0, 0.7), 3.0)
	for tm in m.terminals:
		var c := (Vector2(tm.cell) + Vector2(0.5, 0.5)) * t
		draw_rect(Rect2(c - Vector2(22, 18), Vector2(44, 36)), Color(0.12, 0.15, 0.2))
		draw_rect(Rect2(c - Vector2(16, 12), Vector2(32, 18)), Color(0.2, 1.0, 0.6, 0.85) if tm.done else Color(0.2, 0.7, 1.0, 0.6 + 0.3 * sin(_anim * 4.0)))
		draw_rect(Rect2(c - Vector2(22, 18), Vector2(44, 36)), Color(0.05, 0.05, 0.06), false, 2.0)
		if not tm.done and tm.progress > 0.0:
			draw_arc(c, 30, -PI / 2, -PI / 2 + TAU * tm.progress / tm.time, 32, Color(0.3, 1.0, 0.6), 5.0)
	for p in m.prisoners:
		if p.freed:
			continue
		var r := Rect2(Vector2(p.cell) * t + Vector2(4, 4), Vector2(t - 8, t - 8))
		draw_rect(r, Color(0.15, 0.12, 0.1, 0.8))
		for i in mini(int(p.count), 6):
			draw_circle(r.position + Vector2(12 + (i % 3) * 18, 16 + (i / 3) * 22), 6, Color(0.4, 0.75, 1.0))
		for i in 5:
			var x := r.position.x + i * (r.size.x / 4.0)
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.55, 0.58, 0.62), 3.0)
		draw_rect(r, Color(0.55, 0.58, 0.62), false, 3.0)
	for k in m.pickups:
		if k.taken:
			continue
		var c := (Vector2(k.cell) + Vector2(0.5, 0.5)) * t
		var b := 3.0 * sin(_anim * 4.0)
		draw_circle(c, 22 + b, Color(1.0, 0.85, 0.3, 0.18))
		draw_rect(Rect2(c - Vector2(13, 11), Vector2(26, 22)), Color(0.85, 0.65, 0.2))
		draw_rect(Rect2(c - Vector2(13, 11), Vector2(26, 22)), Color(0.3, 0.2, 0.05), false, 2.0)
		draw_string(font, c + Vector2(-60, -24), str(k.label), HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1.0, 0.9, 0.5))


## Structures ennemies posées (tourelles, bunker, caserne, base).
func _draw_structure(e: Enemy) -> void:
	var def: Dictionary = Balance.ENEMY_STRUCTURES[e.type]
	var p := e.pos * TILE
	var sz := float(e.size) * TILE
	var r := Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
	var red := Color(1.0, 0.55, 0.5)
	match str(def.look):
		"gun", "cannon", "missile", "laser":
			var look: Dictionary = Sprites.TOWER_LOOK[def.look]
			draw_texture_rect(look.base, r, false, Color(1.0, 0.5, 0.45))
			var sc: float = look.scale
			var tex: Texture2D = look.turret
			draw_set_transform(p, e.aim_angle + look.rot, Vector2(sc, sc))
			draw_texture(tex, -look.pivot, Color(1.0, 0.6, 0.55))
			draw_set_transform(Vector2.ZERO)
		"siege":
			var lk: Dictionary = Sprites.ENEMY_LOOK.siege
			draw_set_transform(p, e.aim_angle + lk.rot)
			draw_texture_rect(lk.tex, Rect2(-43, -43, 86, 86), false)
			draw_set_transform(Vector2.ZERO)
			for i in 4:
				var a := PI / 4.0 + i * PI / 2.0
				draw_line(p + Vector2.from_angle(a) * 26, p + Vector2.from_angle(a) * 40, Color(0.5, 0.2, 0.2), 5.0)
		"bunker", "barracks":
			draw_texture_rect(Sprites.W_BARRACKS, Rect2(r.position + Vector2(5, 7), r.size), false, Color(0, 0, 0, 0.35))
			draw_texture_rect(Sprites.W_BARRACKS if def.look == "barracks" else Sprites.W_FACTORY, r, false, red)
		"generator":
			draw_rect(r.grow(-6), Color(0.18, 0.1, 0.12))
			var pulse := 0.6 + 0.4 * sin(_anim * 5.0)
			draw_circle(p, sz * 0.28, Color(1.0, 0.3, 0.25, pulse))
			draw_arc(p, sz * 0.36, 0, TAU, 32, Color(1.0, 0.55, 0.3), 4.0)
			for i in 4:
				var a := PI / 4.0 + i * PI / 2.0
				draw_line(p + Vector2.from_angle(a) * sz * 0.38, p + Vector2.from_angle(a) * sz * 0.48, Color(1.0, 0.5, 0.3), 6.0)
		"hq":
			draw_texture_rect(Sprites.W_BASE, Rect2(r.position + Vector2(6, 9), r.size), false, Color(0, 0, 0, 0.35))
			draw_texture_rect(Sprites.W_BASE, r.grow(4), false, Color(1.0, 0.45, 0.4))
	draw_rect(r.grow(2), Color(1.0, 0.25, 0.2, 0.5), false, 2.0)
	if e.hp < e.max_hp or e.size >= 2:
		_draw_bar(Rect2(r.position + Vector2(4, -8), Vector2(r.size.x - 8, 0)), float(e.hp) / e.max_hp, COLOR_ENEMY_BAR, 6.0)


func _draw_unit(u: Unit) -> void:
	if u.type == "escort_truck":
		_draw_escortee(u)
		return
	var look: Dictionary = Sprites.UNIT_LOOK[u.type]
	var p := u.pos * TILE
	var size: float = look.size
	var ring := 34.0 if u.type == "heavy_tank" else (28.0 if u.type in ["tank", "aa_mech"] else 20.0)
	if sel_units.has(u):
		draw_circle(p, ring, Color(COLOR_SELECTED, 0.18))
		draw_arc(p, ring, 0, TAU, 32, COLOR_SELECTED, 3.0)
	elif u.faction != "p1":
		# Allié IA, civil, faction personnalisée : anneau à sa couleur.
		var fc := world.factions.color_of(u.faction)
		draw_circle(p, ring - 2, Color(fc, 0.14))
		draw_arc(p, ring - 2, 0, TAU, 24, Color(fc, 0.85), 2.5)
	else:
		draw_arc(p, ring - 2, 0, TAU, 24, Color(0.4, 1.0, 0.45, 0.35), 2.0)
	if look.get("upright", false):
		# Sprite vu de face : pas de rotation, retourné quand l'unité va (ou vise) vers la gauche.
		var dir_x := (u.target.pos.x - u.pos.x) if u.target != null else u.facing.x
		var flip := -1.0 if dir_x < -0.05 else 1.0
		var bob := sin(_anim * 9.0 + u.id) * 1.5 if not u.path.is_empty() else 0.0
		draw_circle(p + Vector2(0, size * 0.36), size * 0.24, Color(0, 0, 0, 0.28))
		draw_set_transform(p + Vector2(0, bob - size * 0.08), 0.0, Vector2(flip, 1.0))
		draw_texture_rect(look.tex, Rect2(-size / 2, -size / 2, size, size), false, look.tint)
	else:
		var rot: float = look.get("rot", 0.0)
		draw_set_transform(p + Vector2(4, 7), u.facing.angle() + rot)
		draw_texture_rect(look.tex, Rect2(-size / 2, -size / 2, size, size), false, Color(0, 0, 0, 0.25))
		draw_set_transform(p, u.facing.angle() + rot)
		draw_texture_rect(look.tex, Rect2(-size / 2, -size / 2, size, size), false, look.tint)
		if look.has("turret"):
			var ts: float = look.turret_size
			draw_set_transform(p, (u.aim_angle if u.target != null else u.facing.angle()) + rot)
			draw_texture_rect(look.turret, Rect2(-ts / 2, -ts / 2, ts, ts), false, look.tint * skin_tint)
	draw_set_transform(Vector2.ZERO)
	if u.buff_time > 0.0:
		var glow := 0.5 + 0.5 * sin(_anim * 10.0)
		draw_arc(p, ring + 3, 0, TAU, 32, Color(1.0, 0.7, 0.2, 0.5 + 0.4 * glow), 3.0)
	if u.sieged:
		for i in 4:
			var a := PI / 4.0 + i * PI / 2.0
			draw_line(p + Vector2.from_angle(a) * 22, p + Vector2.from_angle(a) * 36, Color(0.75, 0.8, 0.7), 5.0)
		if sel_units.has(u):
			draw_arc(p, Content.SIEGE_RANGE * TILE, 0, TAU, 96, Color(1.0, 0.7, 0.2, 0.45), 2.0)
	if u.hp < u.max_hp:
		_draw_bar(Rect2(p - Vector2(20, ring + 4), Vector2(40, 0)), float(u.hp) / u.max_hp)
	if u.vip:
		draw_arc(p, ring + 6, 0, TAU, 32, Color(1.0, 0.8, 0.2, 0.6 + 0.3 * sin(_anim * 5.0)), 3.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(-8, -ring - 10), "★", HORIZONTAL_ALIGNMENT_CENTER, 16, 20, Color(1.0, 0.8, 0.2))


func _draw_corners(r: Rect2, color: Color) -> void:
	var l := minf(18.0, r.size.x / 3)
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var dx := l if corner.x == r.position.x else -l
		var dy := l if corner.y == r.position.y else -l
		draw_line(corner, corner + Vector2(dx, 0), color, 3.0)
		draw_line(corner, corner + Vector2(0, dy), color, 3.0)


func _draw_house(r: Rect2) -> void:
	draw_texture_rect(Sprites.TOWER_BASE3, r, false)
	var c := r.get_center()
	draw_circle(c, 23, Color(0.12, 0.2, 0.26))
	draw_circle(c, 19, Color(0.30, 0.88, 0.62))
	draw_circle(c + Vector2(-6, -6), 7, Color(0.85, 1.0, 0.9, 0.85))
	draw_arc(c, 23, 0, TAU, 24, Color(0.85, 1.0, 0.95, 0.9), 2.0)


var _trails := {} # id d'entité d'objectif -> positions passées (pour les wagons)


## Train, camions, bateau : dessinés en vectoriel en attendant des sprites dédiés.
func _draw_neutral(e: Enemy) -> void:
	var p := e.pos * TILE
	var trail: Array = _trails.get(e.id, [])
	if trail.is_empty() or (trail[-1] as Vector2).distance_to(p) > 3.0:
		trail.append(p)
		if trail.size() > 160:
			trail.pop_front()
		_trails[e.id] = trail
	var ang := e.facing.angle()
	var pulse := 0.5 + 0.5 * sin(_anim * 4.0)
	match e.type:
		"train":
			for k in range(3, 0, -1):
				var wp := _trail_point(trail, p, k * 58.0)
				var wa := (_trail_point(trail, p, k * 58.0 - 6.0) - wp).angle()
				_draw_box(wp, wa, Vector2(54, 30), [Color(0.55, 0.28, 0.16), Color(0.15, 0.4, 0.45), Color(0.4, 0.42, 0.18)][k % 3], true)
			_draw_box(p, ang, Vector2(60, 34), Color(0.22, 0.24, 0.28), false)
			draw_set_transform(p, ang)
			draw_rect(Rect2(-30, -5, 60, 10), Color(0.85, 0.18, 0.2))
			draw_circle(Vector2(28, -10), 4, Color(1, 0.95, 0.6))
			draw_circle(Vector2(28, 10), 4, Color(1, 0.95, 0.6))
			draw_rect(Rect2(-18, -12, 22, 24), Color(0.3, 0.85, 1.0, 0.7))
			draw_set_transform(Vector2.ZERO)
		"truck":
			_draw_box(p - e.facing * 8, ang, Vector2(34, 26), Color(0.5, 0.47, 0.38), true)
			draw_set_transform(p, ang)
			draw_rect(Rect2(10, -12, 16, 24), Color(0.25, 0.27, 0.3))
			draw_rect(Rect2(20, -10, 5, 20), Color(0.35, 0.85, 1.0, 0.8))
			draw_circle(Vector2(26, -9), 2.5, Color(1, 0.95, 0.6))
			draw_circle(Vector2(26, 9), 2.5, Color(1, 0.95, 0.6))
			draw_set_transform(Vector2.ZERO)
		"boat":
			for k in 4:
				var wp := _trail_point(trail, p, 20.0 + k * 14.0)
				var spread := 8.0 + k * 6.0
				var n := e.facing.orthogonal()
				draw_circle(wp + n * spread, 3.5 - k * 0.6, Color(1, 1, 1, 0.5 - k * 0.1))
				draw_circle(wp - n * spread, 3.5 - k * 0.6, Color(1, 1, 1, 0.5 - k * 0.1))
			draw_set_transform(p, ang)
			var hull := PackedVector2Array([Vector2(40, 0), Vector2(18, -18), Vector2(-34, -18), Vector2(-38, 0), Vector2(-34, 18), Vector2(18, 18)])
			draw_colored_polygon(hull, Color(0.28, 0.3, 0.34))
			draw_polyline(hull + PackedVector2Array([hull[0]]), Color(0.1, 0.11, 0.13), 3.0)
			draw_rect(Rect2(-22, -10, 26, 20), Color(0.82, 0.2, 0.22))
			draw_rect(Rect2(-14, -6, 12, 12), Color(0.35, 0.85, 1.0, 0.8))
			draw_set_transform(Vector2.ZERO)
	# Repère d'objectif bonus : anneau doré + barre de PV
	draw_arc(p, 34 + pulse * 4, 0, TAU, 32, Color(1.0, 0.8, 0.2, 0.55 + 0.35 * pulse), 2.5)
	_draw_bar(Rect2(p - Vector2(30, 34), Vector2(60, 0)), float(e.hp) / e.max_hp, Color(1.0, 0.8, 0.2), 7.0)


func _trail_point(trail: Array, head: Vector2, dist: float) -> Vector2:
	var left := dist
	var prev := head
	for i in range(trail.size() - 1, -1, -1):
		var q: Vector2 = trail[i]
		var d := prev.distance_to(q)
		if d >= left and d > 0.0:
			return prev.lerp(q, left / d)
		left -= d
		prev = q
	return prev


func _draw_box(at: Vector2, ang: float, sz: Vector2, col: Color, ridges: bool) -> void:
	draw_set_transform(at + Vector2(3, 5), ang)
	draw_rect(Rect2(-sz / 2, sz), Color(0, 0, 0, 0.3))
	draw_set_transform(at, ang)
	draw_rect(Rect2(-sz / 2, sz), col)
	draw_rect(Rect2(-sz / 2, sz), Color(0.08, 0.09, 0.1), false, 2.0)
	if ridges:
		for k in int(sz.x / 9):
			var x := -sz.x / 2 + 5 + k * 9
			draw_line(Vector2(x, -sz.y / 2 + 3), Vector2(x, sz.y / 2 - 3), Color(0, 0, 0, 0.25), 2.0)
	draw_set_transform(Vector2.ZERO)


func _draw_escortee(u: Unit) -> void:
	var p := u.pos * TILE
	var ang := u.facing.angle()
	draw_arc(p, 34, 0, TAU, 32, Color(0.3, 1.0, 0.45, 0.6), 2.5)
	_draw_box(p - u.facing * 10, ang, Vector2(40, 30), Color(0.28, 0.4, 0.3), true)
	draw_set_transform(p, ang)
	draw_rect(Rect2(12, -14, 18, 28), Color(0.2, 0.24, 0.28))
	draw_rect(Rect2(22, -12, 6, 24), Color(0.35, 0.9, 1.0, 0.8))
	draw_set_transform(Vector2.ZERO)
	_draw_bar(Rect2(p - Vector2(30, 34), Vector2(60, 0)), float(u.hp) / u.max_hp, Color(0.3, 1.0, 0.45), 7.0)


func _draw_enemy(e: Enemy) -> void:
	if e.is_structure():
		_draw_structure(e)
		return
	if e.neutral:
		_draw_neutral(e)
		return
	var look: Dictionary = Sprites.ENEMY_LOOK[e.type]
	var p := (e.pos + e.visual_offset) * TILE
	var size: float = look.size
	if e.is_boss():
		var pulse := 0.5 + 0.5 * sin(_anim * 5.0)
		draw_circle(p, size * 0.55, Color(1.0, 0.1, 0.2, 0.18 + 0.12 * pulse))
		draw_arc(p, size * 0.55, 0, TAU, 40, Color(1.0, 0.3, 0.35, 0.8), 3.0)
	elif e.faction != "enemy":
		# Créature neutre ou faction personnalisée : cercle à sa couleur (en pointillé si non hostile).
		var fc := world.factions.color_of(e.faction)
		draw_circle(p, size * 0.42, Color(fc, 0.22))
		if not world.factions.hostile(e.faction, "p1"):
			for k in 12:
				draw_arc(p, size * 0.46, TAU * k / 12.0, TAU * (k + 0.5) / 12.0, 4, Color(fc, 0.9), 2.5)
		else:
			draw_arc(p, size * 0.46, 0, TAU, 28, Color(fc, 0.9), 2.5)
	elif not e.flying:
		draw_circle(p, size * 0.42, Color(0.9, 0.1, 0.1, 0.28))
		draw_set_transform(p + Vector2(6, 10), e.facing.angle() + look.get("rot", 0.0))
		draw_texture_rect(look.tex, Rect2(-size / 2, -size / 2, size, size), false, Color(0, 0, 0, 0.3))
	draw_set_transform(p, e.facing.angle() + look.get("rot", 0.0))
	draw_texture_rect(look.tex, Rect2(-size / 2, -size / 2, size, size), false, look.tint)
	if look.has("turret"):
		var ts: float = look.get("turret_size", size)
		draw_texture_rect(look.turret, Rect2(-ts / 2, -ts / 2, ts, ts), false, look.tint)
	draw_set_transform(Vector2.ZERO)
	if e.slow_timer > 0.0:
		draw_circle(p, size * 0.38, Color(0.5, 0.85, 1.0, 0.35))
	if e.stun_timer > 0.0:
		for i in 3:
			var a := _anim * 6.0 + i * TAU / 3.0
			draw_circle(p + Vector2(cos(a) * 16, -size * 0.35 + sin(a) * 5), 4, Color(1.0, 0.9, 0.3))
	if e.is_boss():
		var half := 46.0
		_draw_bar(Rect2(p - Vector2(half, size * 0.55 + 4), Vector2(half * 2, 0)), float(e.hp) / e.max_hp, COLOR_ENEMY_BAR, 10.0)
	elif e.hp < e.max_hp:
		_draw_bar(Rect2(p - Vector2(20, 22), Vector2(40, 0)), float(e.hp) / e.max_hp, COLOR_ENEMY_BAR)


func _draw_effects() -> void:
	for ev in _effects:
		match ev.type:
			"shot":
				var k: float = ev.ttl / ev.life
				match ev.get("kind", "gun"):
					"missile", "aa_mech":
						var p: Vector2 = ev.to.lerp(ev.from, k) * TILE
						draw_set_transform(p, (ev.to - ev.from).angle() + PI / 2.0)
						draw_texture_rect(Sprites.ROCKET, Rect2(-14, -14, 28, 28), false)
						draw_set_transform(Vector2.ZERO)
					"cannon", "tank", "heavy_tank":
						var p: Vector2 = ev.to.lerp(ev.from, k) * TILE
						draw_circle(p, 7, Color(0.2, 0.2, 0.2))
						draw_circle(ev.to * TILE, 50 * (1.0 - k), Color(1, 0.6, 0.2, 0.5 * k))
					"warrior", "grenadier":
						var c: Vector2 = ev.to * TILE
						var a0: float = (ev.to - ev.from).angle()
						draw_arc(c - Vector2.from_angle(a0) * 10, 26 if ev.kind == "grenadier" else 18, a0 - 1.0, a0 + 1.0, 12, Color(1, 1, 0.85, k), 4.0)
					"flame":
						var from: Vector2 = ev.from * TILE
						var to: Vector2 = ev.to * TILE
						var ang := (to - from).angle()
						for i in 6:
							var t := (i + 1) / 6.0
							var jitter := Vector2.from_angle(ang + PI / 2.0) * sin(_anim * 30.0 + i) * 10.0 * t
							var fs := 22.0 + 34.0 * t
							draw_set_transform(from.lerp(to, t) + jitter, ang + PI / 2.0)
							draw_texture_rect(Sprites.FLAME, Rect2(-fs / 2, -fs / 2, fs, fs), false, Color(1, 1, 1, 0.9 * k + 0.1))
						draw_set_transform(Vector2.ZERO)
					"sniper", "sniper_tower":
						draw_line(ev.from * TILE, ev.to * TILE, Color(0.7, 0.95, 1.0, k * 0.5), 7.0)
						draw_line(ev.from * TILE, ev.to * TILE, Color(1, 1, 1, k), 2.0)
						draw_circle(ev.to * TILE, 9 * k, Color(1, 1, 1, k))
					_:
						draw_line(ev.from * TILE, ev.to * TILE, Color(1, 0.95, 0.6, k), 3.0)
						draw_circle(ev.to * TILE, 5, Color(1, 0.9, 0.5, k))
			"chain":
				var k: float = ev.ttl / ev.life
				var pts: Array = ev.pts
				for i in pts.size() - 1:
					var a: Vector2 = pts[i] * TILE
					var b: Vector2 = pts[i + 1] * TILE
					var line := PackedVector2Array([a])
					var normal := (b - a).normalized().orthogonal()
					for j in range(1, 6):
						line.append(a.lerp(b, j / 6.0) + normal * randf_range(-12, 12))
					line.append(b)
					draw_polyline(line, Color(0.7, 0.55, 1.0, 0.45 * k), 8.0)
					draw_polyline(line, Color(0.95, 0.9, 1.0, k), 2.5)
					draw_circle(b, 8 * k, Color(0.9, 0.8, 1.0, k))
			"wave_fx":
				var t: float = 1.0 - ev.ttl / ev.life
				var c: Vector2 = ev.pos * TILE
				var col := Color(0.55, 0.9, 1.0) if ev.kind == "cryo" else Color(1.0, 0.88, 0.35)
				draw_line(ev.from * TILE, c, Color(col, 0.6 * (1.0 - t)), 3.0)
				draw_circle(c, ev.r * TILE * (0.4 + 0.6 * t), Color(col, 0.25 * (1.0 - t)))
				draw_arc(c, ev.r * TILE * (0.4 + 0.6 * t), 0, TAU, 40, Color(col, 1.0 - t), 3.0)
			"crit":
				var t: float = 1.0 - ev.ttl / ev.life
				var font := ThemeDB.fallback_font
				var at: Vector2 = ev.pos * TILE + Vector2(-26, -30 - 30 * t)
				draw_string_outline(font, at, "CRITIQUE !", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color(0, 0, 0, 1.0 - t))
				draw_string(font, at, "CRITIQUE !", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.8, 0.2, 1.0 - t))
			"ability":
				var t: float = 1.0 - ev.ttl / ev.life
				var col := Color(0.4, 1.0, 0.5) if ev.id == "nanoheal" else Color(1.0, 0.7, 0.2)
				var rad := (Content.ABILITIES.nanoheal.radius * TILE if ev.id == "nanoheal" else 40.0) * (0.3 + 0.7 * t)
				draw_arc(ev.pos * TILE, rad, 0, TAU, 40, Color(col, 1.0 - t), 4.0)
			"heal":
				var k: float = ev.ttl / ev.life
				draw_line(ev.from * TILE, ev.to * TILE, Color(0.4, 1.0, 0.5, 0.6 * k), 3.0)
				draw_circle(ev.to * TILE, 10 * k, Color(0.4, 1.0, 0.5, 0.5 * k))
			"bounty":
				var t: float = 1.0 - ev.ttl / ev.life
				var font := ThemeDB.fallback_font
				draw_string_outline(font, ev.pos * TILE + Vector2(-12, -20 - 40 * t), "+%d" % ev.amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0, 1.0 - t))
				draw_string(font, ev.pos * TILE + Vector2(-12, -20 - 40 * t), "+%d" % ev.amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.62, 0.77, 1.0, 1.0 - t))
			"depleted":
				var t: float = 1.0 - ev.ttl / ev.life
				var col := MapView.COLOR_METAL if ev.metal else MapView.COLOR_ESSENCE
				draw_circle(ev.pos * TILE, 10 + 40 * t, Color(col, 0.4 * (1.0 - t)))
				draw_arc(ev.pos * TILE, 10 + 40 * t, 0, TAU, 32, Color(col, 1.0 - t), 3.0)
			"spawned":
				var t: float = 1.0 - ev.ttl / ev.life
				draw_arc(ev.pos * TILE, 14 + 30 * t, 0, TAU, 32, Color(0.4, 1.0, 0.45, 1.0 - t), 3.0)
			"orbital":
				var t: float = 1.0 - ev.ttl / ev.life
				var c: Vector2 = ev.pos * TILE
				var rad: float = Content.ORBITAL.radius * TILE
				draw_circle(c, rad * (0.3 + t), Color(0.4, 0.95, 1.0, 0.35 * (1.0 - t)))
				draw_arc(c, rad * (0.3 + t), 0, TAU, 48, Color(0.85, 1, 1, 1.0 - t), 4.0)
				draw_rect(Rect2(c.x - 14 * (1.0 - t), c.y - 900, 28 * (1.0 - t), 900), Color(0.7, 1, 1, 0.8 * (1.0 - t)))
			"hit":
				if ev.ranged:
					draw_line(ev.from * TILE, ev.to * TILE, Color(1, 0.4, 0.3, ev.ttl / ev.life), 2.0)
				draw_circle(ev.to * TILE, 6, Color(1, 0.35, 0.25, ev.ttl / ev.life))
			"death":
				var t: float = 1.0 - ev.ttl / ev.life
				var size: float = (200.0 if ev.get("boss", false) else (90.0 if ev.big else 60.0)) * (0.6 + t * 0.6)
				draw_texture_rect(Sprites.EXPLOSION, Rect2(ev.pos * TILE - Vector2(size, size) / 2, Vector2(size, size)),
						false, Color(1, 1, 1, 1.0 - t))


func _draw_base_hp() -> void:
	if world.grid.base_cells.is_empty():
		return
	var c := world.base_center() * TILE
	var r := Rect2(c + Vector2(-80, 118), Vector2(160, 0))
	_draw_bar(r, float(world.base_hp) / world.max_base_hp, MapView.COLOR_TEAM, 12.0)


func _draw_bar(r: Rect2, ratio: float, color := COLOR_BAR, height := 7.0) -> void:
	var bar := Rect2(r.position + Vector2(0, -12), Vector2(r.size.x, height))
	draw_rect(bar.grow(1), COLOR_BAR_BG)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0, 1), bar.size.y)), color)


func _sound(ev: Dictionary) -> void:
	if str(ev.type).begins_with("scn_") or ev.type in ["door_open", "terminal_done", "prisoners_freed", "pickup"]:
		scenario_event.emit(ev)
	match ev.type:
		"shot":
			match ev.get("kind", "gun"):
				"cannon", "tank", "heavy_tank", "sniper_tower":
					Sfx.play("cannon", -4.0, 0.12)
				"flame":
					Sfx.play("shot", -16.0, 0.15)
				"missile", "aa_mech":
					Sfx.play("missile", -6.0, 0.15)
				_:
					Sfx.play("shot", -10.0, 0.07)
		"chain", "wave_fx":
			Sfx.play("missile", -8.0, 0.2)
		"ability":
			Sfx.play("click", -2.0, 0.1)
		"base_hit":
			base_hit.emit()
		"death":
			Sfx.play("explosion", -5.0 if ev.big else -9.0, 0.08)
			if ev.big:
				shake.emit(14.0 if ev.get("boss", false) else 5.0)
			if ev.get("boss", false):
				Sfx.play("victory", -4.0, 1.0)
				Sfx.vibrate(250)
		"orbital":
			shake.emit(16.0)
			Sfx.play("orbital", 0.0, 0.5)
			Sfx.vibrate(120)
		"built":
			Sfx.play("built", -4.0, 0.2)
		"spawned":
			Sfx.play("click", -2.0, 0.15)
