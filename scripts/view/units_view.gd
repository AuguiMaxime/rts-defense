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
var show_ranges := false
signal shake(strength: float)
signal base_hit

var tutorial_marker := Vector2.INF # en cases ; INF = aucun repère
var selected: Array[Worker] = []
var sel_units: Array[Unit] = []
var sel_base := false
## Ligne de ralliement du producteur sélectionné (en cases) ; INF = aucune.
var rally_from := Vector2.INF
var rally_to := Vector2.INF
## Bâtiment à poser (mode construction) : fantôme sur la dernière case touchée.
var ghost_kind := ""
var selection_rect := Rect2() # en pixels monde, vide = pas de sélection en cours
var _effects: Array[Dictionary] = []
var _anim := 0.0


func _process(delta: float) -> void:
	_anim += delta
	if world != null:
		for ev in world.take_events():
			_sound(ev)
			ev["ttl"] = {"death": 0.45, "orbital": 0.9, "bounty": 0.9, "spawned": 0.5}.get(ev.type, 0.08 if ev.get("kind", "") in ["gun", "soldier", "sniper"] else 0.18)
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
	if focused_site != null and world.sites.has(focused_site):
		var fc := focused_site.center() * TILE
		_draw_corners(Rect2(Vector2(focused_site.cell) * TILE, Vector2.ONE * focused_site.size * TILE).grow(4), COLOR_SELECTED)
		if focused_site.is_tower():
			var rad: float = focused_site.stats().range * TILE
			draw_circle(fc, rad, Color(0.13, 0.83, 0.93, 0.10))
			draw_arc(fc, rad, 0, TAU, 72, Color(0.13, 0.83, 0.93, 0.7), 2.5)
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
	if w.hp < Balance.WORKER_HP:
		_draw_bar(Rect2(p - Vector2(18, 20), Vector2(36, 0)), float(w.hp) / Balance.WORKER_HP)
	if w.state == Worker.State.BUILDING:
		draw_arc(p, 16, -PI * 0.8, -PI * 0.2, 12, COLOR_WORKER, 3.0)


func _draw_site(s: BuildSite) -> void:
	var r := Rect2(Vector2(s.cell) * TILE, Vector2.ONE * s.size * TILE)
	if not s.built:
		var base_tex: Texture2D = Sprites.TOWER_LOOK[s.kind].base if s.is_tower() else Sprites.TOWER_BASE3
		if s.is_producer():
			_draw_plate(r, Color(1, 1, 1, 0.25 + 0.5 * s.progress()))
		else:
			draw_texture_rect(base_tex, r, false, Color(1, 1, 1, 0.25 + 0.5 * s.progress()))
		var icon_r := Rect2(r.get_center() - Vector2(24, 24), Vector2(48, 48))
		draw_texture_rect(Sprites.SITE, icon_r, false, Color(1, 1, 1, 0.9))
		var a := r.grow(-3).position
		var b := r.grow(-3).end
		for seg in [[a, Vector2(b.x, a.y)], [Vector2(b.x, a.y), b], [b, Vector2(a.x, b.y)], [Vector2(a.x, b.y), a]]:
			draw_dashed_line(seg[0], seg[1], COLOR_SITE, 3.0, 8.0)
		_draw_bar(r.grow(-6), s.progress(), COLOR_SITE)
		if s.hp < Balance.SITE_HP:
			_draw_bar(Rect2(r.position + Vector2(6, 64), Vector2(52, 0)), float(s.hp) / Balance.SITE_HP)
		return
	if s.kind == "house":
		_draw_house(r)
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
		draw_set_transform(r.get_center(), s.aim_angle + Sprites.TURRET_ANGLE_OFFSET)
		var ts := 60.0 + 4.0 * (s.level - 1)
		draw_texture_rect(look.turret, Rect2(-ts / 2, -ts / 2, ts, ts), false, look.tint * skin_tint)
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
	_draw_plate(r)
	var c := r.get_center()
	var busy := s.producer != null and s.producer.busy()
	if s.kind == "barracks":
		for i in 3:
			draw_rect(Rect2(r.position + Vector2(18, 20 + i * 10), Vector2(r.size.x - 36, 5)), Color(0.10, 0.13, 0.17))
		draw_circle(c + Vector2(0, 10), 30, Color(0.10, 0.13, 0.17))
		draw_set_transform(c + Vector2(0, 10), -PI / 2)
		draw_texture_rect(Sprites.SOLDIER_GREEN, Rect2(-30, -30, 60, 60), false)
		draw_set_transform(Vector2.ZERO)
	else:
		for i in 6:
			var x := r.position.x + 14 + i * 18
			draw_line(Vector2(x, r.end.y - 16), Vector2(x + 10, r.end.y - 26), Color(0.98, 0.75, 0.15, 0.9), 5.0)
		for k in 2:
			var ch := r.position + Vector2(26 + k * 22, 26)
			draw_circle(ch, 10, Color(0.10, 0.13, 0.17))
			if busy:
				var puff := fmod(_anim * 0.8 + k * 0.5, 1.0)
				draw_circle(ch + Vector2(6, -puff * 22), 6 + puff * 8, Color(0.7, 0.75, 0.8, 0.45 * (1.0 - puff)))
		draw_set_transform(c + Vector2(14, 6), -PI / 2)
		draw_texture_rect(Sprites.TANK_GREEN, Rect2(-28, -28, 56, 56), false)
		draw_texture_rect(Sprites.TANK_TURRET_GREEN, Rect2(-28, -28, 56, 56), false)
		draw_set_transform(Vector2.ZERO)
	var lamp := Color(0.4, 1.0, 0.45) if busy else Color(0.3, 0.35, 0.4)
	draw_circle(r.position + Vector2(r.size.x - 18, 18), 6, lamp)
	if busy:
		draw_arc(r.position + Vector2(r.size.x - 18, 18), 11, -PI / 2, -PI / 2 + TAU * s.producer.ratio(), 20, Color(0.4, 1.0, 0.45), 3.0)


func _draw_unit(u: Unit) -> void:
	var look: Dictionary = Sprites.UNIT_LOOK[u.type]
	var p := u.pos * TILE
	var size: float = look.size
	var ring := 28.0 if u.type in ["tank", "aa_mech"] else 20.0
	if sel_units.has(u):
		draw_circle(p, ring, Color(COLOR_SELECTED, 0.18))
		draw_arc(p, ring, 0, TAU, 32, COLOR_SELECTED, 3.0)
	else:
		draw_arc(p, ring - 2, 0, TAU, 24, Color(0.4, 1.0, 0.45, 0.35), 2.0)
	draw_set_transform(p + Vector2(4, 7), u.facing.angle())
	draw_texture_rect(look.tex, Rect2(-size / 2, -size / 2, size, size), false, Color(0, 0, 0, 0.25))
	draw_set_transform(p, u.facing.angle())
	draw_texture_rect(look.tex, Rect2(-size / 2, -size / 2, size, size), false, look.tint)
	if look.has("turret"):
		var ts: float = look.turret_size
		var off := 0.0 if look.turret == Sprites.TANK_TURRET_GREEN else Sprites.TURRET_ANGLE_OFFSET
		draw_set_transform(p, (u.aim_angle if u.target != null else u.facing.angle()) + off)
		draw_texture_rect(look.turret, Rect2(-ts / 2, -ts / 2, ts, ts), false, look.tint * skin_tint)
	draw_set_transform(Vector2.ZERO)
	if u.hp < u.max_hp:
		_draw_bar(Rect2(p - Vector2(20, ring + 4), Vector2(40, 0)), float(u.hp) / u.max_hp)


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


func _draw_enemy(e: Enemy) -> void:
	var look: Dictionary = Sprites.ENEMY_LOOK[e.type]
	var p := (e.pos + e.visual_offset) * TILE
	var size: float = look.size
	if e.type == "boss":
		var pulse := 0.5 + 0.5 * sin(_anim * 5.0)
		draw_circle(p, size * 0.55, Color(1.0, 0.1, 0.2, 0.18 + 0.12 * pulse))
		draw_arc(p, size * 0.55, 0, TAU, 40, Color(1.0, 0.3, 0.35, 0.8), 3.0)
	elif not e.flying:
		draw_circle(p, size * 0.42, Color(0.9, 0.1, 0.1, 0.28))
		draw_set_transform(p + Vector2(10, 18), e.facing.angle())
		draw_texture_rect(look.tex, Rect2(-size / 2, -size / 2, size, size), false, Color(0, 0, 0, 0.3))
	draw_set_transform(p, e.facing.angle())
	draw_texture_rect(look.tex, Rect2(-size / 2, -size / 2, size, size), false, look.tint)
	if look.has("turret"):
		draw_texture_rect(look.turret, Rect2(-size / 2, -size / 2, size, size), false, look.tint)
	draw_set_transform(Vector2.ZERO)
	if e.type == "boss":
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
					"cannon", "grenadier", "tank":
						var p: Vector2 = ev.to.lerp(ev.from, k) * TILE
						draw_circle(p, 7, Color(0.2, 0.2, 0.2))
						draw_circle(ev.to * TILE, 50 * (1.0 - k), Color(1, 0.6, 0.2, 0.5 * k))
					_:
						draw_line(ev.from * TILE, ev.to * TILE, Color(1, 0.95, 0.6, k), 3.0)
						draw_circle(ev.to * TILE, 5, Color(1, 0.9, 0.5, k))
			"bounty":
				var t: float = 1.0 - ev.ttl / ev.life
				var font := ThemeDB.fallback_font
				draw_string_outline(font, ev.pos * TILE + Vector2(-12, -20 - 40 * t), "+%d" % ev.amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(0, 0, 0, 1.0 - t))
				draw_string(font, ev.pos * TILE + Vector2(-12, -20 - 40 * t), "+%d" % ev.amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.62, 0.77, 1.0, 1.0 - t))
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
	match ev.type:
		"shot":
			match ev.get("kind", "gun"):
				"cannon", "tank", "grenadier":
					Sfx.play("cannon", -4.0, 0.12)
				"missile", "aa_mech":
					Sfx.play("missile", -6.0, 0.15)
				_:
					Sfx.play("shot", -10.0, 0.07)
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
