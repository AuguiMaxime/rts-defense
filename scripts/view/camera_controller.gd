class_name CameraController
extends Camera2D
## Caméra du joueur.
## Mobile : 2 doigts pour déplacer et pincer pour zoomer, tap = action,
##          glisser à 1 doigt = sélection par zone.
## PC : clic gauche = action, glisser = sélection par zone, clic droit ou molette enfoncée = déplacer,
##      molette = zoom, ZQSD / WASD / flèches = déplacer.

signal tapped(world_pos: Vector2)
signal selection_updated(world_from: Vector2, world_to: Vector2)
signal selection_ended(world_from: Vector2, world_to: Vector2)
signal selection_cancelled

@export var min_zoom := 0.5
@export var max_zoom := 2.0
@export var keyboard_speed := 900.0

const TAP_MAX_MOVE := 14.0

var bounds := Rect2()
var _shake := 0.0

var _touches := {} # index du doigt -> position écran
var _pinch_start_dist := 0.0
var _pinch_start_zoom := 1.0
var _tap_candidate := false
var _tap_start := Vector2.ZERO
var _mouse_panning := false
var _select_drag := false

## Renvoie true si la position écran est sur un bouton de l'interface.
var is_over_ui: Callable = func(_p: Vector2) -> bool: return false


func set_bounds(r: Rect2) -> void:
	bounds = r
	_clamp()


func center_on(world_pos: Vector2) -> void:
	position = world_pos
	_clamp()


func screen_to_world(screen_pos: Vector2) -> Vector2:
	var half := get_viewport_rect().size * 0.5
	return position + (screen_pos - half) / zoom.x


## Secousse d'écran (explosions, frappe orbitale).
func add_shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func _process(delta: float) -> void:
	if _shake > 0.1:
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = lerpf(_shake, 0.0, minf(1.0, delta * 9.0))
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO
		_shake = 0.0
	var dir := Vector2.ZERO
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return # on tape du texte : les touches ne déplacent pas la caméra
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
		dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * keyboard_speed * delta / zoom.x
		_clamp()


## Un doigt posé sur la carte reste suivi même s'il glisse ou se lève au-dessus de l'interface
## (sinon le cadre de sélection restait bloqué quand on relâchait sur un panneau).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and _touches.has(event.index):
		_on_touch(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_on_drag(event)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_panning:
		position -= event.relative / zoom.x
		_clamp()


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			var on_ui: bool = is_over_ui.call(event.position)
			_tap_candidate = not on_ui
			_tap_start = event.position
			_select_drag = false
		else:
			_tap_candidate = false
			if _select_drag:
				_select_drag = false
				selection_cancelled.emit()
			_start_pinch()
	else:
		_touches.erase(event.index)
		if _touches.is_empty():
			if _tap_candidate and event.position.distance_to(_tap_start) <= TAP_MAX_MOVE:
				tapped.emit(screen_to_world(event.position))
			elif _select_drag:
				selection_ended.emit(screen_to_world(_tap_start), screen_to_world(event.position))
			_tap_candidate = false
			_select_drag = false
		elif _touches.size() >= 2:
			_start_pinch()


func _on_drag(event: InputEventScreenDrag) -> void:
	var old_center := _touch_center()
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		var new_center := _touch_center()
		position -= (new_center - old_center) / zoom.x
		if _pinch_start_dist > 0.0:
			_zoom_at(_pinch_start_zoom * _touch_distance() / _pinch_start_dist, new_center)
		_clamp()
	else:
		if _tap_candidate and event.position.distance_to(_tap_start) > TAP_MAX_MOVE:
			_tap_candidate = false
			_select_drag = true
		if _select_drag:
			selection_updated.emit(screen_to_world(_tap_start), screen_to_world(event.position))


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_at(zoom.x * 1.1, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_at(zoom.x / 1.1, event.position)
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			_mouse_panning = event.pressed


func _start_pinch() -> void:
	_pinch_start_dist = _touch_distance()
	_pinch_start_zoom = zoom.x


func _touch_center() -> Vector2:
	if _touches.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in _touches.values():
		sum += p
	return sum / _touches.size()


func _touch_distance() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1])


## Zoome en gardant le point du monde situé sous screen_pos au même endroit à l'écran.
func _zoom_at(z: float, screen_pos: Vector2) -> void:
	z = clampf(z, min_zoom, max_zoom)
	var anchor := screen_to_world(screen_pos)
	zoom = Vector2(z, z)
	var half := get_viewport_rect().size * 0.5
	position = anchor - (screen_pos - half) / z
	_clamp()


## Éditeur : la caméra peut aller jusqu'aux bords de la carte (pour la sortir de sous les panneaux).
var free_pan := false


func _clamp() -> void:
	if bounds.size == Vector2.ZERO:
		return
	if free_pan:
		position = position.clamp(bounds.position, bounds.end)
		return
	var half := get_viewport_rect().size * 0.5 / zoom.x
	var p := position
	if bounds.size.x <= half.x * 2.0:
		p.x = bounds.get_center().x
	else:
		p.x = clampf(p.x, bounds.position.x + half.x, bounds.end.x - half.x)
	if bounds.size.y <= half.y * 2.0:
		p.y = bounds.get_center().y
	else:
		p.y = clampf(p.y, bounds.position.y + half.y, bounds.end.y - half.y)
	position = p
