class_name Minimap
extends Control
## Minimap : terrain, bâtiments, ouvriers, unités, ennemis, cadre de la caméra.
## Toucher ou glisser dessus déplace la caméra.

var game: Node
var _terrain: ImageTexture
var _dragging := false


func setup(g: Node) -> void:
	game = g
	mouse_filter = Control.MOUSE_FILTER_STOP
	var grid: GameGrid = g.world.grid
	var img := Image.create(grid.width, grid.height, false, Image.FORMAT_RGBA8)
	var ground: Color = {"grass": Color("1b3324"), "sand": Color("4a3a2a"), "mars": Color("5a2e22"), "metal": Color("2a3038")}.get(g.map_script.GROUND, Color("3a3030"))
	for y in grid.height:
		for x in grid.width:
			var col := ground
			match grid.get_cell(Vector2i(x, y)):
				GameGrid.Cell.ROCK:
					col = Color("6b7280")
				GameGrid.Cell.METAL:
					col = Ui.METAL
				GameGrid.Cell.ESSENCE:
					col = Ui.ESSENCE
				GameGrid.Cell.SPAWN:
					col = Ui.RED
				GameGrid.Cell.BASE:
					col = Ui.CYAN
			img.set_pixel(x, y, col)
	_terrain = ImageTexture.create_from_image(img)


func _map_rect() -> Rect2:
	var grid: GameGrid = game.world.grid
	var k := minf(size.x / grid.width, size.y / grid.height)
	var s := Vector2(grid.width, grid.height) * k
	return Rect2((size - s) / 2.0, s)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	var w: GameWorld = game.world
	var r := _map_rect()
	var k := r.size.x / w.grid.width
	draw_texture_rect(_terrain, r, false)
	for s in w.sites:
		draw_rect(Rect2(r.position + Vector2(s.cell) * k, Vector2.ONE * s.size * k), Ui.CYAN if s.built else Color(Ui.CYAN, 0.5))
	for x in w.workers:
		draw_rect(Rect2(r.position + x.pos * k - Vector2(1.5, 1.5), Vector2(3, 3)), Color("fde68a"))
	for u in w.units:
		draw_rect(Rect2(r.position + u.pos * k - Vector2(2, 2), Vector2(4, 4)), Ui.GREEN)
	for e in w.enemies:
		var sz := 5.0 if e.type == "boss" else 3.0
		draw_rect(Rect2(r.position + e.pos * k - Vector2(sz, sz) / 2, Vector2(sz, sz)), Ui.RED)
	# Cadre de la caméra
	var cam: Camera2D = game.camera
	var vp := get_viewport_rect().size / cam.zoom.x / MapView.TILE
	var c := cam.position / MapView.TILE
	draw_rect(Rect2(r.position + (c - vp / 2) * k, vp * k), Color(1, 1, 1, 0.9), false, 1.5)
	draw_rect(r, Color(Ui.CYAN, 0.6), false, 1.5)


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.INF
	if event is InputEventScreenTouch:
		_dragging = event.pressed
		if event.pressed:
			pos = event.position
	elif event is InputEventScreenDrag and _dragging:
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			pos = event.position
	elif event is InputEventMouseMotion and _dragging:
		pos = event.position
	if pos != Vector2.INF:
		var r := _map_rect()
		var k: float = r.size.x / game.world.grid.width
		game.camera.center_on((pos - r.position) / k * MapView.TILE)
		accept_event()
