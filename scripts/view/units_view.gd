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
var selection_rect := Rect2() # en pixels monde, vide = pas de sélection en cours
var _effects: Array[Dictionary] = []
var _anim := 0.0


func _process(delta: float) -> void:
	_anim += delta
	if world != null:
		for ev in world.take_events():
			_sound(ev)
			ev["ttl"] = {"death": 0.45, "orbital": 0.9, "bounty": 0.9}.get(ev.type, 0.08 if ev.get("kind", "") == "gun" else 0.18)
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
	if focused_site != null and world.sites.has(focused_site):
		var fc := (Vector2(focused_site.cell) + Vector2(0.5, 0.5)) * TILE
		draw_rect(Rect2(Vector2(focused_site.cell) * TILE, Vector2(TILE, TILE)).grow(3), Color(0.13, 0.83, 0.93), false, 3.0)
		if focused_site.is_tower():
			var rad: float = focused_site.stats().range * TILE
			draw_circle(fc, rad, Color(0.13, 0.83, 0.93, 0.10))
			draw_arc(fc, rad, 0, TAU, 72, Color(0.13, 0.83, 0.93, 0.7), 2.5)
	for s in world.sites:
		_draw_site(s)
	for w in world.workers:
		_draw_worker(w)
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
	var r := Rect2(Vector2(s.cell) * TILE, Vector2(TILE, TILE))
	if not s.built:
		var base_tex: Texture2D = Sprites.TOWER_LOOK[s.kind].base if s.is_tower() else Sprites.TOWER_BASE3
		draw_texture_rect(base_tex, r, false, Color(1, 1, 1, 0.25 + 0.5 * s.progress()))
		draw_texture_rect(Sprites.SITE, r.grow(-8), false, Color(1, 1, 1, 0.9))
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
			draw_arc(r.get_center(), 36, _anim * 4.0, _anim * 4.0 + 1.5, 16, COLOR_BAR, 3.0)
			break


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
	draw_set_transform(Vector2.ZERO)
	if e.hp < e.max_hp:
		_draw_bar(Rect2(p - Vector2(20, 22), Vector2(40, 0)), float(e.hp) / e.max_hp, COLOR_ENEMY_BAR)


func _draw_effects() -> void:
	for ev in _effects:
		match ev.type:
			"shot":
				var k: float = ev.ttl / ev.life
				match ev.get("kind", "gun"):
					"missile":
						var p: Vector2 = ev.to.lerp(ev.from, k) * TILE
						draw_set_transform(p, (ev.to - ev.from).angle() + PI / 2.0)
						draw_texture_rect(Sprites.ROCKET, Rect2(-14, -14, 28, 28), false)
						draw_set_transform(Vector2.ZERO)
					"cannon":
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
				"cannon":
					Sfx.play("cannon", -4.0, 0.12)
				"missile":
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
