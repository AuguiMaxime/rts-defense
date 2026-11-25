class_name MissionEditor
extends Node2D
## Éditeur de missions (PC, souris et clavier).
## Onglets : CARTE (terrain), OBJETS (catalogue), MISSION (règles).
## Tout changement passe par l'historique : annuler / rétablir sur 100 actions.

const T := MapView.TILE
const MATERIALS := [
	{"id": ".", "name": "Gomme (sol nu)", "key": "E"},
	{"id": "#", "name": "Rocher"},
	{"id": "W", "name": "Mur"},
	{"id": "~", "name": "Eau"},
	{"id": "=", "name": "Route"},
	{"id": "T", "name": "Rails"},
	{"id": "M", "name": "Métal"},
	{"id": "E", "name": "Essence"},
	{"id": "B", "name": "Base joueur 1"},
	{"id": "b", "name": "Base joueur 2"},
	{"id": "S", "name": "Apparition"},
]
const GROUNDS := [["grass", "Herbe"], ["sand", "Sable"], ["dirt", "Terre"], ["mars", "Mars"], ["metal", "Métal"]]
const TOOL_INFO := {
	"select": ["Sélection", "V", "Clic : choisir · glisser : rectangle · glisser la sélection : déplacer · Maj : ajouter"],
	"paint": ["Pinceau", "B", "Clic / glisser : peindre · Maj+clic : ligne droite · Alt+clic : pipette · [ ] : taille"],
	"fill": ["Remplissage", "F", "Clic : remplit la zone de même terrain"],
	"pipette": ["Pipette", "I", "Clic : reprend le terrain ou l'objet et ses réglages"],
	"place": ["Poser", "P", "Clic / glisser : poser · retoucher un objet : lui appliquer les réglages · R : pivoter"],
	"erase": ["Gomme", "E", "Clic / glisser : retirer les objets"],
}
const TAB_TOOLS := {"map": ["select", "paint", "fill", "pipette"], "objects": ["select", "place", "erase", "pipette"], "objectives": [], "events": [], "waves": [], "mission": []}
const TABS := [["map", "Carte"], ["objects", "Objets"], ["objectives", "Objectifs"], ["events", "Événements"], ["waves", "Vagues"], ["mission", "Mission"]]
const WIDE_TABS := ["objectives", "events", "waves"]
const ENEMY_BEHAVIORS := [["guard", "Garde son poste"], ["static", "Immobile"], ["patrol", "Patrouille"], ["defend", "Défend une structure"],
		["aggressive", "Attaque à vue"], ["attack_target", "Attaque une cible"], ["attack_zone", "Attaque une zone"], ["follow", "Suit une unité"],
		["march", "Marche sur la base"], ["wait", "Attend un événement"]]
const ALLY_BEHAVIORS := [["guard", "Garde son poste"], ["hold", "Tient la position"], ["patrol", "Patrouille"], ["follow", "Suit une unité"],
		["hunt", "Chasse les ennemis"]]
const AUTOSAVE_DIR := "user://editor/"
const AUTOSAVE_PATH := "user://editor/autosave.json"
const AUTOSAVE_EVERY := 30.0
const PANEL_W := 252.0
const RIGHT_W := 244.0

# --- Document -----------------------------------------------------------------------------
var doc: EditorDoc
var history: EditorHistory
var layers := EditorLayers.new()
var grid: GameGrid
var issues: Array = [] # erreurs bloquantes (voir MissionValidator)
var warns: Array = [] # avertissements
var _drop_zone: Control
var _fit_zoom := -1.0 # zoom du dernier « cadrer la carte »
var _state_saved := {}
var _state_timer := 0.0
var _rebinding := "" # action dont on attend la nouvelle touche (fenêtre des raccourcis)
var flash_cell := Vector2i(-1, -1) # case signalée par « Aller » dans la validation
var flash_time := 0.0
var _saved_changes := 0
var _autosaved_changes := 0
var _autosave_timer := 0.0
var _view_dirty := true
var _check_dirty := true

# --- Outils -------------------------------------------------------------------------------
var tab := "map"
var tool := "paint"
var terrain_mat := "#"
var brush := 1
var obj_tool := "structure:e_tower_gun"
var obj_opts := EditorOps.DEFAULT_OPTS.duplicate()
var show_grid := true
var show_paths := false
var path_info := {}

# --- Sélection ----------------------------------------------------------------------------
var sel_rect := Rect2i()
var sel_ids: Array[int] = []
var floating := {}
var floating_at := Vector2i.ZERO
var _float_grab := Vector2i.ZERO
var _float_move := false
var clipboard := {}
var band_active := false
var _band_from := Vector2i.ZERO
var _band_to := Vector2i.ZERO
var _band_add := false

# --- Souris -------------------------------------------------------------------------------
var hover := Vector2i(-1, -1)
var _lmb := false
var _press_cell := Vector2i.ZERO
var _press_mode := ""
var _last_paint := Vector2i(-999, -999)
var _last_place := Vector2i(-999, -999)
var _panning := false
var _space := false
var _rmb_moved := 0.0
var _placed_any := false
## Choix sur la carte pour une fiche : {"id", "key", "accept": Callable, "hint"}
var pick := {}
var _fiche_name: LineEdit

# --- Scène et interface -------------------------------------------------------------------
var camera: Camera2D
var map_view: MapView
var canvas: EditorCanvas
var _ui: Control
var _name_edit: LineEdit
var _tab_buttons := {}
var _undo_btn: Button
var _redo_btn: Button
var _left: PanelContainer
var _left_boxes := {}
var _tool_row: HBoxContainer
var _tool_buttons := {}
var _mat_buttons := {}
var _brush_buttons := {}
var _ground_buttons := {}
var catalog: EditorCatalog
var mission_panel: EditorMissionPanel
var objectives_panel: EditorScenarioPanel
var events_panel: EditorScenarioPanel
var waves_panel: EditorScenarioPanel
var _context: VBoxContainer
var _layer_rows := {}
var _grid_btn: Button
var _paths_btn: Button
var _status_cell: Label
var _status_hint: Label
var _status_check: Button
var _status_zoom: Label
var _status_save: Label
var _modal: Control
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_time := 0.0
var _tool_sep: Control


func _ready() -> void:
	map_view = MapView.new()
	add_child(map_view)
	canvas = EditorCanvas.new()
	canvas.ed = self
	add_child(canvas)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = EditorUi.theme()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	Ui.testing = false
	Ui.debug_view.clear()
	_open_initial()


func _open_initial() -> void:
	var s: Variant = Ui.get("editor_session")
	if s is Dictionary and s.get("map") == Ui.editor_map and Ui.editor_map != null:
		_restore_session(s)
		return
	if Ui.editor_map != null:
		_load_doc(EditorDoc.from_map(Ui.editor_map))
		var st0: Dictionary = EditorPrefs.get_v("state", {})
		_apply_state(st0, doc.path != "" and str(st0.get("path", "")) == doc.path)
		return
	# Dernière mission ouverte (état gardé d'une session à l'autre).
	var st: Dictionary = EditorPrefs.get_v("state", {})
	var last := str(st.get("path", ""))
	if last != "" and FileAccess.file_exists(last) and not FileAccess.file_exists(AUTOSAVE_PATH):
		_load_doc(EditorDoc.from_map(MapData.load_from(last)))
		_apply_state(st, true)
		_toast("Reprise de « %s »" % doc.name)
		return
	_load_doc(EditorDoc.from_map(_default_map()))
	_apply_state(st, false)
	if FileAccess.file_exists(AUTOSAVE_PATH):
		_offer_autosave()


## État de l'éditeur mémorisé : onglet, outils, calques, grille, zoom (et la vue si même mission).
func _state_dict() -> Dictionary:
	return {"path": doc.path, "tab": tab, "tool": tool, "terrain_mat": terrain_mat, "brush": brush, "obj_tool": obj_tool,
			"grid": show_grid, "hidden": layers.hidden, "locked": layers.locked, "zoom": camera.zoom.x,
			"cam": [camera.position.x, camera.position.y]}


func _apply_state(st: Dictionary, same_map: bool) -> void:
	if st.is_empty():
		return
	layers.hidden = st.get("hidden", {}).duplicate()
	layers.locked = st.get("locked", {}).duplicate()
	_refresh_layers()
	show_grid = bool(st.get("grid", true))
	_grid_btn.set_pressed_no_signal(show_grid)
	terrain_mat = str(st.get("terrain_mat", terrain_mat))
	for id in _mat_buttons:
		(_mat_buttons[id] as Button).set_pressed_no_signal(id == terrain_mat)
	set_brush(clampi(int(st.get("brush", 1)), 1, 4))
	var ot := str(st.get("obj_tool", obj_tool))
	if EditorCatalog.label_of(ot) != ot:
		obj_tool = ot
		catalog.select(obj_tool)
	set_tab(str(st.get("tab", "map")) if TABS.any(func(t: Array) -> bool: return t[0] == str(st.get("tab", ""))) else "map")
	set_tool(str(st.get("tool", tool)))
	if same_map:
		var z := clampf(float(st.get("zoom", 1.0)), 0.1, 4.0)
		var cam: Array = st.get("cam", [])
		var apply_view := func() -> void:
			camera.zoom = Vector2(z, z)
			if cam.size() == 2:
				camera.position = Vector2(float(cam[0]), float(cam[1]))
		apply_view.call_deferred()
	_view_dirty = true
	_state_saved = _state_dict()


func _save_state() -> void:
	if doc == null:
		return
	var st := _state_dict()
	if st != _state_saved:
		_state_saved = st
		EditorPrefs.set_v("state", st)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		_save_state()


# --- Document -----------------------------------------------------------------------------

func _default_map() -> MapData:
	var m := MapData.new()
	m.NAME = "Nouvelle carte"
	var w := 44
	var h := 28
	var rows: Array[String] = []
	for y in h:
		rows.append(".".repeat(w))
	var d := EditorDoc.new()
	d.rows = rows
	var L := EditorLayers.new()
	EditorOps.stamp_base(d, L, Vector2i(7, h / 2), "B")
	d.set_char(Vector2i(w - 2, h / 2), "S")
	for c in [Vector2i(12, h / 2 - 3), Vector2i(13, h / 2 - 3), Vector2i(12, h / 2 + 3)]:
		d.set_char(c, "M")
	m.LAYOUT = "\n".join(d.rows)
	return m


func _load_doc(d: EditorDoc) -> void:
	doc = d
	history = EditorHistory.new(doc)
	_saved_changes = 0
	_autosaved_changes = 0
	clear_selection()
	floating = {}
	_name_edit.text = doc.name
	after_change()
	_refresh_view()
	fit_camera.call_deferred()
	if doc.converted and doc.path != "":
		_toast("Mission convertie : les objectifs du type « %s » ont été générés (onglet Objectifs)" % Mission.TYPE_NAMES.get(str(doc.mission.get("type", "waves")), ""))


func after_change() -> void:
	_view_dirty = true
	_check_dirty = true
	# Sélection : on oublie les objets qui n'existent plus (annuler…)
	sel_ids.assign(sel_ids.filter(func(id: int) -> bool: return not doc.entity_by_id(id).is_empty()))
	if _name_edit != null and not _name_edit.has_focus():
		_name_edit.text = doc.name
	if mission_panel != null:
		mission_panel.refresh()
	if objectives_panel != null and tab in WIDE_TABS:
		(_left_boxes[tab] as EditorScenarioPanel).refresh()
	_refresh_ground_buttons()
	_refresh_context()
	_refresh_undo()


## Changement de valeur sans reconstruire les formulaires.
func mark_dirty() -> void:
	_view_dirty = true
	_check_dirty = true
	_refresh_undo()


## Objets référencés par l'objectif / le déclencheur affiché (surlignés sur la carte).
func scenario_highlight() -> Array:
	if tab not in WIDE_TABS:
		return []
	var panel: EditorScenarioPanel = _left_boxes[tab]
	var i := panel._sel_index()
	if i < 0 or (tab == "events" and panel.view != "triggers") or (tab == "waves" and panel.view != "list"):
		return []
	var out := []
	_collect_refs(panel._items()[i], out)
	return out


func _collect_refs(v: Variant, out: Array) -> void:
	if v is Dictionary:
		for k in v:
			if k in ["obj", "zone", "target"] and (v[k] is int or v[k] is float) and int(v[k]) >= 0:
				out.append(int(v[k]))
			elif k in ["targets", "zones", "fail_dead"] and v[k] is Array:
				for x in v[k]:
					out.append(int(x))
			else:
				_collect_refs(v[k], out)
	elif v is Array:
		for x in v:
			_collect_refs(x, out)


func _refresh_view() -> void:
	_view_dirty = false
	grid = MapLoader.from_layout("\n".join(doc.rows))
	var shown := layers.display_rows(doc.rows)
	map_view.setup(grid if shown == doc.rows else MapLoader.from_layout("\n".join(shown)), doc.ground)
	if show_paths:
		_compute_paths()


func _check() -> void:
	_check_dirty = false
	var all := MissionValidator.run(doc, grid)
	issues = MissionValidator.errors(all)
	warns = MissionValidator.warnings(all)
	if issues.is_empty() and warns.is_empty():
		_status_check.text = "✔ Mission valide"
		_status_check.add_theme_color_override("font_color", Ui.GREEN)
	elif issues.is_empty():
		_status_check.text = "⚠ %d avertissement%s" % [warns.size(), "s" if warns.size() > 1 else ""]
		_status_check.add_theme_color_override("font_color", Ui.GOLD)
	else:
		_status_check.text = "✖ %d problème%s" % [issues.size(), "s" if issues.size() > 1 else ""] + ("  ⚠ %d" % warns.size() if not warns.is_empty() else "")
		_status_check.add_theme_color_override("font_color", Ui.RED)


func _process(delta: float) -> void:
	_state_timer += delta
	if _state_timer >= 3.0:
		_state_timer = 0.0
		_save_state()
	var dragging := get_viewport().gui_is_dragging()
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP if dragging else Control.MOUSE_FILTER_IGNORE
	if _view_dirty:
		_refresh_view()
	if _check_dirty:
		_check()
	if flash_time > 0.0:
		flash_time -= delta
		canvas.queue_redraw()
	# Défilement au clavier
	var dir := Vector2.ZERO
	var focus := get_viewport().gui_get_focus_owner()
	if not (focus is LineEdit or focus is TextEdit):
		if Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1
		if Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1
		if Input.is_key_pressed(KEY_UP):
			dir.y -= 1
		if Input.is_key_pressed(KEY_DOWN):
			dir.y += 1
	if dir != Vector2.ZERO:
		camera.position += dir * 900.0 * delta / camera.zoom.x
	# Sauvegarde automatique
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_EVERY:
		_autosave_timer = 0.0
		_autosave()
	_status_zoom.text = "%d %%" % roundi(camera.zoom.x * 100)
	if _toast_panel.visible:
		_toast_time -= delta
		_toast_panel.modulate.a = clampf(_toast_time / 0.4, 0.0, 1.0)
		if _toast_time <= 0.0:
			_toast_panel.visible = false
	var unsaved := history.changes != _saved_changes
	_status_save.text = ("● Modifié" if unsaved else "Enregistré") + (" · sauvegarde auto" if unsaved and history.changes == _autosaved_changes else "")
	_status_save.add_theme_color_override("font_color", Ui.GOLD if unsaved else Color(0.55, 0.62, 0.72))


## Message court en bas de l'écran (remplace le précédent).
func _toast(text: String, color := Ui.CYAN) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.25))
	(_toast_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(color, 0.7)
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	_toast_time = 2.6
	_toast_panel.reset_size()
	var vp := get_viewport_rect().size
	_toast_panel.position = Vector2((vp.x - _toast_panel.size.x) * 0.5, vp.y - 34 - _toast_panel.size.y - 8)


# --- Caméra -------------------------------------------------------------------------------

## Centre la vue sur une case (bouton ◎ des points d'apparition).
func look_at_cell(c: Vector2i) -> void:
	camera.position = (Vector2(c) + Vector2(0.5, 0.5)) * T + Vector2((_left_w() - RIGHT_W) * -0.5, 0) / camera.zoom.x
	_view_dirty = true


## Largeur actuelle du panneau de gauche (plus large dans les onglets sans carte).
func _left_w() -> float:
	return 452.0 if tab in WIDE_TABS else PANEL_W


func fit_camera() -> void:
	var world := Vector2(doc.width(), doc.height()) * T
	var vp := get_viewport_rect().size - Vector2(_left_w() + RIGHT_W + 60, 120)
	var z := clampf(minf(vp.x / world.x, vp.y / world.y), 0.06, 1.5)
	camera.zoom = Vector2(z, z)
	_fit_zoom = z
	camera.position = world * 0.5 + Vector2((_left_w() - RIGHT_W) * -0.5, -8) / z


func _zoom_at(factor: float, screen: Vector2) -> void:
	var before := _screen_to_world(screen)
	var z := clampf(camera.zoom.x * factor, 0.06, 3.0)
	camera.zoom = Vector2(z, z)
	camera.position += before - _screen_to_world(screen)


func _screen_to_world(p: Vector2) -> Vector2:
	return camera.get_canvas_transform().affine_inverse() * p


func _cell_at(screen: Vector2) -> Vector2i:
	return Vector2i((_screen_to_world(screen) / T).floor())


# --- Entrées ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _modal != null:
		if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
			_close_modal()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(1.15, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / 1.15, mb.position)
		elif mb.pressed and (mb.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT] or (mb.button_index == MOUSE_BUTTON_LEFT and _space)):
			_panning = true
			_rmb_moved = 0.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and tool == "select" and pick.is_empty():
			var e := doc.entity_at(_cell_at(mb.position), func(x: Dictionary) -> bool: return layers.entity_visible(x))
			if not e.is_empty() and _fiche_name != null:
				_fiche_name.grab_focus()
				_fiche_name.select_all()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_lmb = true
			_on_press(_cell_at(mb.position), mb.shift_pressed, mb.alt_pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_set_hover(_cell_at((event as InputEventMouseMotion).position))
	elif event is InputEventKey:
		_on_key(event as InputEventKey)


## Glisser et relâcher sont suivis même au-dessus des panneaux.
func _input(event: InputEvent) -> void:
	if _rebinding != "" and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		if not k.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			get_viewport().set_input_as_handled()
			var id := _rebinding
			_rebinding = ""
			if k.keycode != KEY_ESCAPE:
				var stolen := EditorShortcuts.bind(id, EditorShortcuts.event_string(k))
				if stolen != "":
					_toast("« %s » n'a plus de touche" % EditorShortcuts.label_of(stolen), Ui.GOLD)
			_show_help()
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _lmb and get_viewport().gui_get_hovered_control() != null:
			_set_hover(Vector2i(-1, -1))
		if _panning:
			camera.position -= mm.relative / camera.zoom.x
			_rmb_moved += mm.relative.length()
		if _lmb:
			var c := _cell_at(mm.position)
			_set_hover(c)
			_on_drag(c)
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT] or (mb.button_index == MOUSE_BUTTON_LEFT and _panning):
			_panning = false
			if mb.button_index == MOUSE_BUTTON_RIGHT and _rmb_moved < 6.0 and _modal == null \
					and get_viewport().gui_get_hovered_control() == null:
				_right_click(_cell_at(mb.position))
		if mb.button_index == MOUSE_BUTTON_LEFT and _lmb:
			_lmb = false
			_on_release(_cell_at(mb.position))
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE:
		var focus := get_viewport().gui_get_focus_owner()
		if not (focus is LineEdit or focus is TextEdit):
			_space = (event as InputEventKey).pressed


func _set_hover(c: Vector2i) -> void:
	if c == hover:
		return
	hover = c
	if not floating.is_empty() and not _float_move:
		floating_at = c - _float_grab
	_update_status_cell()


func _update_status_cell() -> void:
	if doc == null or not doc.inside(hover):
		_status_cell.text = ""
		return
	var ch := doc.get_char(hover)
	var txt := "x %d · y %d  —  %s" % [hover.x, hover.y, _char_name(ch)]
	var e := doc.entity_at(hover, func(x: Dictionary) -> bool: return layers.entity_visible(x))
	if not e.is_empty():
		txt += "  ·  %s" % e.name
	_status_cell.text = txt


func _char_name(ch: String) -> String:
	if ch == "H":
		return "Pont (route)"
	if ch == "Y":
		return "Pont (rails)"
	if ch == ".":
		return "Sol"
	for m in MATERIALS:
		if m.id == ch:
			return m.name
	return ch


func _on_key(k: InputEventKey) -> void:
	if not k.pressed or k.echo:
		return
	var ctrl := k.ctrl_pressed or k.meta_pressed
	var handled := true
	# Touches fixes
	if ctrl and k.shift_pressed and k.keycode == KEY_Z:
		do_redo()
	elif k.keycode == KEY_ESCAPE:
		escape()
	elif k.keycode == KEY_BACKSPACE and not ctrl:
		do_delete()
	elif k.keycode in [KEY_ENTER, KEY_KP_ENTER] and not pick.is_empty():
		end_pick()
	else:
		# Raccourcis modifiables (F1)
		var id := EditorShortcuts.action_for(k)
		handled = id != "" and run_action(id)
	if handled:
		get_viewport().set_input_as_handled()


## Exécute une action de l'éditeur (raccourci clavier ou menu). Faux si inconnue.
func run_action(id: String) -> bool:
	match id:
		"undo":
			do_undo()
		"redo":
			do_redo()
		"copy":
			do_copy()
		"cut":
			do_cut()
		"paste":
			do_paste()
		"duplicate":
			do_duplicate()
		"select_all":
			select_all()
		"delete":
			do_delete()
		"save":
			save()
		"missions":
			_show_missions()
		"test":
			test()
		"validate":
			_show_issues()
		"help":
			_show_help()
		"fit":
			fit_camera()
		"tab_map", "tab_objects", "tab_objectives", "tab_events", "tab_waves", "tab_mission":
			set_tab(id.trim_prefix("tab_"))
		"tool_select":
			set_tool("select")
		"tool_paint":
			if tab != "map":
				set_tab("map")
			set_tool("paint")
		"tool_fill":
			if tab != "map":
				set_tab("map")
			set_tool("fill")
		"tool_pipette":
			set_tool("pipette")
		"tool_place":
			if tab != "objects":
				set_tab("objects")
			set_tool("place")
		"tool_erase":
			if tab == "objects":
				set_tool("erase")
			else:
				set_terrain_mat(".")
		"grid":
			toggle_grid()
		"rotate":
			rotate_any()
		"mirror":
			mirror_any(true)
		"mirror_v":
			mirror_any(false)
		"brush_minus":
			set_brush(maxi(1, brush - 1))
		"brush_plus":
			set_brush(mini(4, brush + 1))
		"paths":
			toggle_paths()
		_:
			return false
	return true


# --- Outils : souris --------------------------------------------------------------------------

func _on_press(c: Vector2i, shift: bool, alt: bool) -> void:
	_press_cell = c
	_press_mode = ""
	if not pick.is_empty():
		_pick_press(c)
		_lmb = false
		return
	if not floating.is_empty() and not _float_move:
		_drop_paste()
		_lmb = false
		return
	if alt:
		pipette(c)
		_lmb = false
		return
	match tool:
		"paint":
			if not doc.inside(c):
				return
			history.begin("Peindre · " + _char_name(terrain_mat))
			if shift and _last_paint.x > -999:
				EditorOps.paint_line(doc, layers, _last_paint, c, terrain_mat, brush)
			else:
				EditorOps.paint(doc, layers, c, terrain_mat, brush)
			_last_paint = c
			_view_dirty = true
		"fill":
			if history.record("Remplir · " + _char_name(terrain_mat), func() -> void: EditorOps.fill(doc, layers, c, terrain_mat)):
				after_change()
			else:
				_toast("Rien à remplir ici (même terrain ou calque protégé)", Ui.GOLD)
		"pipette":
			pipette(c)
		"place":
			history.begin("Poser · " + _tool_label(obj_tool))
			_place_at(c, true)
			_last_place = c
		"erase":
			history.begin("Retirer des objets")
			_erase_at(c)
		"select":
			_select_press(c, shift)


func _on_drag(c: Vector2i) -> void:
	match tool:
		"paint":
			if history.is_open() and c != _last_paint and doc.inside(c):
				EditorOps.paint_line(doc, layers, _last_paint, c, terrain_mat, brush)
				_last_paint = c
				_view_dirty = true
		"place":
			if history.is_open() and c != _last_place:
				_last_place = c
				# En glissant, on ne pose que sur des cases libres.
				var e := EditorOps.make_entity(obj_tool, c, obj_opts)
				var r := EditorDoc.entity_rect(e)
				if not doc.entities.any(func(x: Dictionary) -> bool: return EditorDoc.entity_rect(x).intersects(r)):
					_place_at(c, false)
		"erase":
			if history.is_open():
				_erase_at(c)
		"select":
			_select_drag(c)


func _on_release(c: Vector2i) -> void:
	match tool:
		"paint", "place", "erase":
			if history.commit():
				after_change()
				if tool == "place" and _placed_any:
					catalog.add_recent(obj_tool)
			_placed_any = false
		"select":
			_select_release(c)


func _place_at(c: Vector2i, report: bool) -> void:
	var res := EditorOps.place(doc, layers, obj_tool, c, obj_opts)
	if res.has("error"):
		if report and res.error != "":
			_toast(res.error, Ui.RED)
		return
	if not res.get("updated", false):
		_placed_any = true
	_view_dirty = true
	_check_dirty = true


func _erase_at(c: Vector2i) -> void:
	var e := doc.entity_at(c, func(x: Dictionary) -> bool: return layers.entity_editable(x))
	if not e.is_empty():
		doc.remove_ids([int(e.id)])
		_check_dirty = true


func pipette(c: Vector2i) -> void:
	if not doc.inside(c):
		return
	var e := doc.entity_at(c, func(x: Dictionary) -> bool: return layers.entity_visible(x))
	if tab == "objects" or (tab != "map" and not e.is_empty()):
		if e.is_empty():
			_toast("Aucun objet ici", Ui.GOLD)
			return
		obj_tool = EditorDoc.entity_tool(e)
		obj_opts = EditorOps.options_of(e)
		catalog.select(obj_tool)
		set_tool("place")
		_toast("Pipette : %s" % _tool_label(obj_tool))
		return
	set_terrain_mat(EditorOps.tool_of_char(doc.get_char(c)))
	set_tool("paint")


# --- Sélection ------------------------------------------------------------------------------

func selection_bounds() -> Rect2i:
	var r := sel_rect
	for id in sel_ids:
		var e := doc.entity_by_id(id)
		if not e.is_empty():
			r = EditorDoc.entity_rect(e) if not r.has_area() else r.merge(EditorDoc.entity_rect(e))
	return r


func has_selection() -> bool:
	return sel_rect.has_area() or not sel_ids.is_empty()


func clear_selection() -> void:
	sel_rect = Rect2i()
	sel_ids.clear()
	band_active = false
	_refresh_context()


func band_rect() -> Rect2i:
	var a := Vector2i(mini(_band_from.x, _band_to.x), mini(_band_from.y, _band_to.y))
	var b := Vector2i(maxi(_band_from.x, _band_to.x), maxi(_band_from.y, _band_to.y))
	var r := Rect2i(a, b - a + Vector2i.ONE)
	return r.intersection(Rect2i(0, 0, doc.width(), doc.height()))


func _in_selection(c: Vector2i) -> bool:
	if sel_rect.has_point(c):
		return true
	for id in sel_ids:
		var e := doc.entity_by_id(id)
		if not e.is_empty() and EditorDoc.entity_rect(e).has_point(c):
			return true
	return false


func _select_press(c: Vector2i, shift: bool) -> void:
	if has_selection() and not shift and _in_selection(c):
		_press_mode = "move_pending"
		return
	var e := doc.entity_at(c, func(x: Dictionary) -> bool: return layers.entity_visible(x))
	if not e.is_empty():
		if shift:
			if sel_ids.has(int(e.id)):
				sel_ids.erase(int(e.id))
			else:
				sel_ids.append(int(e.id))
			_press_mode = ""
		else:
			sel_rect = Rect2i()
			sel_ids = [int(e.id)]
			_press_mode = "move_pending"
		_refresh_context()
		return
	_press_mode = "band"
	_band_from = c
	_band_to = c
	_band_add = shift
	band_active = true


func _select_drag(c: Vector2i) -> void:
	match _press_mode:
		"band":
			_band_to = c
		"move_pending":
			if c != _press_cell:
				if _lift(_press_cell):
					_press_mode = "moving"
					floating_at = c - _float_grab
		"moving":
			floating_at = c - _float_grab


func _select_release(_c: Vector2i) -> void:
	match _press_mode:
		"band":
			band_active = false
			var r := band_rect()
			if r.size == Vector2i.ONE and _band_from == _band_to and not _band_add:
				clear_selection()
				return
			var ids: Array[int] = []
			for e: Dictionary in doc.entities:
				if layers.entity_visible(e) and EditorDoc.entity_rect(e).intersects(r):
					ids.append(int(e.id))
			if _band_add:
				for id in ids:
					if not sel_ids.has(id):
						sel_ids.append(id)
				if tab == "map":
					sel_rect = r if not sel_rect.has_area() else sel_rect.merge(r)
			else:
				sel_ids = ids
				sel_rect = r if tab == "map" else Rect2i()
			_refresh_context()
		"moving":
			_drop_move()
	_press_mode = ""


## Soulève la sélection (déplacement). Renvoie false si rien n'est déplaçable.
func _lift(grab_cell: Vector2i) -> bool:
	var ids := sel_ids.filter(func(id: int) -> bool: return layers.entity_editable(doc.entity_by_id(id)))
	history.begin("Déplacer")
	var clip := EditorOps.extract(doc, layers, sel_rect, ids)
	if clip.is_empty():
		history.cancel()
		return false
	EditorOps.clear(doc, clip)
	floating = clip
	_float_move = true
	_float_grab = grab_cell - clip.origin
	floating_at = clip.origin
	_view_dirty = true
	return true


func _drop_move() -> void:
	var delta := floating_at - (floating.origin as Vector2i)
	var ids := EditorOps.paste(doc, layers, floating, floating_at, true)
	if sel_rect.has_area():
		sel_rect = Rect2i(sel_rect.position + delta, sel_rect.size).intersection(Rect2i(0, 0, doc.width(), doc.height()))
	sel_ids = ids
	floating = {}
	_float_move = false
	if history.commit():
		after_change()


func _drop_paste() -> void:
	var clip := floating
	var at := floating_at
	var out := []
	history.record("Coller", func() -> void: out.append_array(EditorOps.paste(doc, layers, clip, at, false)))
	sel_ids.assign(out)
	var has_chars := (clip.chars as Array).any(func(l: String) -> bool: return l.replace("?", "") != "")
	sel_rect = Rect2i(at, clip.size).intersection(Rect2i(0, 0, doc.width(), doc.height())) if has_chars else Rect2i()
	floating = {}
	after_change()


func select_all() -> void:
	set_tool("select")
	sel_rect = Rect2i(0, 0, doc.width(), doc.height()) if tab == "map" else Rect2i()
	sel_ids.clear()
	for e: Dictionary in doc.entities:
		if layers.entity_visible(e):
			sel_ids.append(int(e.id))
	_refresh_context()


func _selection_clip() -> Dictionary:
	var ids := sel_ids.filter(func(id: int) -> bool: return layers.entity_editable(doc.entity_by_id(id)))
	return EditorOps.extract(doc, layers, sel_rect, ids)


func do_copy() -> void:
	var clip := _selection_clip()
	if clip.is_empty():
		_toast("Rien à copier : sélectionne d'abord (V)", Ui.GOLD)
		return
	clipboard = clip
	_toast("Copié : %s" % _clip_summary(clip))


func do_cut() -> void:
	var clip := _selection_clip()
	if clip.is_empty():
		return
	clipboard = clip
	history.record("Couper", func() -> void: EditorOps.clear(doc, clip))
	clear_selection()
	after_change()


func do_paste() -> void:
	if clipboard.is_empty():
		_toast("Presse-papiers vide", Ui.GOLD)
		return
	_start_floating(clipboard.duplicate(true))


func do_duplicate() -> void:
	var clip := _selection_clip()
	if clip.is_empty():
		_toast("Rien à dupliquer : sélectionne d'abord (V)", Ui.GOLD)
		return
	_start_floating(clip)


func _start_floating(clip: Dictionary) -> void:
	set_tool("select")
	floating = clip
	_float_move = false
	_float_grab = (clip.size as Vector2i) / 2
	floating_at = (hover if doc.inside(hover) else Vector2i(doc.width() / 2, doc.height() / 2)) - _float_grab
	_toast("Clic pour poser · R pivoter · M miroir · Échap annuler")


func do_delete() -> void:
	var clip := _selection_clip()
	if clip.is_empty():
		return
	var go := func() -> void:
		history.record("Supprimer", func() -> void: EditorOps.clear(doc, clip))
		clear_selection()
		after_change()
	# Sécurité : prévenir si un objectif, un déclencheur ou une vague utilise ces objets.
	var uses: Array[String] = []
	for id in sel_ids:
		for u in entity_uses(id):
			if not uses.has(u):
				uses.append(u)
	if uses.is_empty():
		go.call()
		return
	_confirm("Supprimer ?", "Utilisé par %d élément%s : %s.\nCes références seront signalées par la validation." % [uses.size(), "s" if uses.size() > 1 else "",
			", ".join(uses.slice(0, 6)) + ("…" if uses.size() > 6 else "")], "Supprimer", go)


func _can_drop(at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("rts_tool")):
		return false
	# Aperçu de l'objet sous le curseur pendant le glisser.
	if obj_tool != str(data.rts_tool) or tool != "place":
		obj_tool = str(data.rts_tool)
		if tab != "objects":
			set_tab("objects")
		catalog.select(obj_tool)
		set_tool("place")
	_set_hover(_cell_at(at))
	canvas.queue_redraw()
	return doc.inside(_cell_at(at))


func _drop(at: Vector2, data: Variant) -> void:
	var c := _cell_at(at)
	obj_tool = str(data.rts_tool)
	set_tool("place")
	_on_press(c, false, false)
	_on_release(c)


## Objectifs, déclencheurs, vagues et objets qui font référence à l'objet `id`.
func entity_uses(id: int) -> Array[String]:
	var out: Array[String] = []
	for o: Dictionary in doc.scenario.get("objectives", []):
		if MissionValidator._uses(JSON.stringify(o), id):
			out.append("objectif « %s »" % o.get("name", ""))
	for t: Dictionary in doc.scenario.get("triggers", []):
		if MissionValidator._uses(JSON.stringify(t), id):
			out.append("déclencheur « %s »" % t.get("name", ""))
	for w: Dictionary in doc.wave_plan.get("list", []):
		if int(w.get("target", -1)) == id or int(w.get("zone", -1)) == id:
			out.append("vague « %s »" % w.get("name", ""))
	for e: Dictionary in doc.entities:
		if int(e.id) != id and (int(e.get("target", -1)) == id or int(e.get("link", -1)) == id):
			out.append(str(e.get("name", "")))
	return out


func rotate_any() -> void:
	if not floating.is_empty():
		floating = EditorOps.rotate_clip(floating)
		_float_grab = Vector2i(_float_grab.y, _float_grab.x)
		return
	if tool == "place" and obj_tool.begins_with("deco:"):
		obj_opts.rot = (int(obj_opts.rot) + 1) % 4
		_refresh_context()
		return
	_transform_selection("Pivoter", func(c: Dictionary) -> Dictionary: return EditorOps.rotate_clip(c))


func mirror_any(horizontal: bool) -> void:
	if not floating.is_empty():
		floating = EditorOps.mirror_clip(floating, horizontal)
		return
	_transform_selection("Miroir", func(c: Dictionary) -> Dictionary: return EditorOps.mirror_clip(c, horizontal))


func _transform_selection(label: String, f: Callable) -> void:
	var clip := _selection_clip()
	if clip.is_empty():
		_toast("Sélectionne d'abord ce qu'il faut transformer (V)", Ui.GOLD)
		return
	var had_rect := sel_rect.has_area()
	var ids := []
	var out: Dictionary = f.call(clip)
	history.record(label, func() -> void:
		EditorOps.clear(doc, clip)
		ids.append_array(EditorOps.paste(doc, layers, out, clip.origin, true)))
	sel_ids.assign(ids)
	sel_rect = Rect2i(clip.origin, out.size).intersection(Rect2i(0, 0, doc.width(), doc.height())) if had_rect else Rect2i()
	after_change()


func escape() -> void:
	if not pick.is_empty():
		end_pick()
		return
	if not floating.is_empty():
		if _float_move:
			history.cancel()
			_view_dirty = true
		floating = {}
		_float_move = false
		_lmb = false
		_press_mode = ""
		return
	if band_active:
		band_active = false
		_press_mode = ""
		return
	if has_selection():
		clear_selection()


func _clip_summary(clip: Dictionary) -> String:
	var n := 0
	for line: String in clip.chars:
		n += line.length() - line.count("?")
	var parts: Array[String] = []
	if n > 0:
		parts.append("%d case%s" % [n, "s" if n > 1 else ""])
	if not clip.entities.is_empty():
		parts.append("%d objet%s" % [clip.entities.size(), "s" if clip.entities.size() > 1 else ""])
	return ", ".join(parts)


# --- Historique ------------------------------------------------------------------------------

func do_undo() -> void:
	if not floating.is_empty():
		escape()
	var l := history.undo()
	if l == "":
		_toast("Rien à annuler", Ui.GOLD)
		return
	_toast("Annulé : %s" % l)
	after_change()


func do_redo() -> void:
	var l := history.redo()
	if l == "":
		_toast("Rien à rétablir", Ui.GOLD)
		return
	_toast("Rétabli : %s" % l)
	after_change()


func _refresh_undo() -> void:
	if _undo_btn == null:
		return
	_undo_btn.disabled = not history.can_undo()
	_redo_btn.disabled = not history.can_redo()
	_undo_btn.tooltip_text = "Annuler (Ctrl+Z)" + (" : " + history.undo_label() if history.can_undo() else "")
	_redo_btn.tooltip_text = "Rétablir (Ctrl+Y)" + (" : " + history.redo_label() if history.can_redo() else "")


# --- Changement d'outil / onglet --------------------------------------------------------------

func set_tab(t: String) -> void:
	# Le panneau de gauche s'élargit ou rétrécit : la vue glisse d'autant, la carte reste au même endroit à l'écran.
	var old_w := _left_w()
	tab = t
	if camera != null and old_w != _left_w():
		# Vue cadrée sur toute la carte : on recadre ; sinon on garde le zoom et on décale.
		if is_equal_approx(camera.zoom.x, _fit_zoom):
			fit_camera()
		else:
			camera.position.x -= (_left_w() - old_w) * 0.5 / camera.zoom.x
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == t)
	for k in _left_boxes:
		(_left_boxes[k] as Control).visible = k == t
	_tool_row.visible = not TAB_TOOLS[t].is_empty()
	_tool_sep.visible = _tool_row.visible
	_left.custom_minimum_size.x = 452.0 if t in WIDE_TABS else PANEL_W
	if t in WIDE_TABS:
		(_left_boxes[t] as EditorScenarioPanel).refresh()
	for id in _tool_buttons:
		(_tool_buttons[id] as Button).visible = TAB_TOOLS[t].has(id)
	if not TAB_TOOLS[t].is_empty() and not TAB_TOOLS[t].has(tool):
		set_tool("paint" if t == "map" else "place")
	else:
		set_tool(tool) # met aussi à jour l'aide de la barre du bas


func set_tool(t: String) -> void:
	tool = t
	for id in _tool_buttons:
		(_tool_buttons[id] as Button).set_pressed_no_signal(id == t)
	_status_hint.text = TOOL_INFO.get(t, ["", "", ""])[2] if not TAB_TOOLS[tab].is_empty() else {
		"mission": "Réglages de la mission à gauche · F5 pour tester",
		"objectives": "Objectifs de la mission · ◎ pour choisir un objet ou une zone sur la carte · F5 pour tester",
		"events": "Déclencheurs QUAND / SI / ALORS · ◎ pour choisir sur la carte · F2 en test pour forcer un déclencheur",
		"waves": "Vagues automatiques ou personnalisées · Points d'apparition : les nommer · F5 pour tester",
	}.get(tab, "")
	_refresh_context()


func set_terrain_mat(m: String) -> void:
	terrain_mat = m
	for id in _mat_buttons:
		(_mat_buttons[id] as Button).set_pressed_no_signal(id == m)
	if tab != "map":
		set_tab("map")
	if tool not in ["paint", "fill"]:
		set_tool("paint")


func set_brush(n: int) -> void:
	brush = n
	for k in _brush_buttons:
		(_brush_buttons[k] as Button).set_pressed_no_signal(k == n)


func start_place(tool_id: String) -> void:
	obj_tool = tool_id
	set_tab("objects")
	set_tool("place")
	catalog.select(tool_id)


func toggle_grid() -> void:
	show_grid = not show_grid
	_grid_btn.set_pressed_no_signal(show_grid)


func _tool_label(id: String) -> String:
	for cat in EditorCatalog.palette():
		for it in cat[1]:
			if it[0] == id:
				return it[1]
	return id


# --- Vérification des passages ---------------------------------------------------------------

func _compute_paths() -> void:
	var g := MapLoader.from_layout("\n".join(doc.rows))
	var pf := Pathfinder.new(g)
	for e: Dictionary in doc.entities:
		if e.kind == "structure" or (e.kind == "deco" and e.get("block", false)):
			for c in EditorDoc.entity_cells(e):
				if g.is_inside(c):
					pf.set_solid(c, true)
	var reach := {}
	var q: Array[Vector2i] = []
	if g.base_cells.size() == 9:
		q = pf.free_cells_around(g.base_cells)
	for c in q:
		reach[c] = true
	var head := 0
	while head < q.size():
		var p := q[head]
		head += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = p + d
			if g.is_inside(n) and not reach.has(n) and pf.is_free(n):
				reach[n] = true
				q.append(n)
	var unreachable: Array[Vector2i] = []
	for y in g.height:
		for x in g.width:
			var c := Vector2i(x, y)
			if pf.is_free(c) and not reach.has(c) and not g.base_cells.has(c):
				unreachable.append(c)
	var routes: Array = []
	var blocked: Array[Vector2i] = []
	for sp in g.spawn_points:
		var path := pf.find_path_to_adjacent(sp, g.base_cells) if g.base_cells.size() == 9 else ([] as Array[Vector2i])
		if path.is_empty():
			blocked.append(sp)
		else:
			routes.append([sp] + path)
	for dep in g.metal_deposits + g.essence_deposits:
		var ok := false
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if reach.has(dep + d):
				ok = true
		if not ok:
			blocked.append(dep)
	path_info = {"unreachable": unreachable, "routes": routes, "blocked": blocked}


func toggle_paths() -> void:
	show_paths = not show_paths
	_paths_btn.set_pressed_no_signal(show_paths)
	if show_paths:
		_compute_paths()
		var n: int = path_info.blocked.size()
		_toast("Passages : tout est accessible" if n == 0 and path_info.unreachable.is_empty() else
				"Passages : %d point(s) bloqué(s) en rouge" % n, Ui.GREEN if n == 0 else Ui.GOLD)
	else:
		path_info = {}


# --- Fichiers ---------------------------------------------------------------------------------

func _sync_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n != "" and n != doc.name:
		history.record("Renommer la carte", func() -> void: doc.name = n)


func save() -> void:
	_sync_name()
	var m := doc.to_map()
	var p := doc.path if doc.path.ends_with(".json") and doc.path.begins_with(MapData.custom_dir()) \
			else MapData.custom_dir() + MapData.slug(doc.name) + ".json"
	var err := m.save_to(p)
	if err == OK:
		doc.path = p
		_saved_changes = history.changes
		_autosaved_changes = history.changes
		DirAccess.remove_absolute(AUTOSAVE_PATH)
		_toast("Enregistrée : %s" % p.get_file(), Ui.GREEN)
	else:
		_toast("Échec de l'enregistrement (%d)" % err, Ui.RED)


func _autosave() -> void:
	if doc == null or history.changes == _autosaved_changes or history.changes == _saved_changes:
		return
	DirAccess.make_dir_recursive_absolute(AUTOSAVE_DIR)
	var d := doc.to_map().to_dict()
	d["autosave_time"] = Time.get_datetime_string_from_system(false, true)
	d["autosave_source"] = doc.path
	var f := FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "\t"))
		_autosaved_changes = history.changes


func _offer_autosave() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUTOSAVE_PATH))
	if not raw is Dictionary:
		return
	var when := str(raw.get("autosave_time", ""))
	var resume := func() -> void:
		var m := MapData.load_from(AUTOSAVE_PATH)
		m.path = str(raw.get("autosave_source", ""))
		_load_doc(EditorDoc.from_map(m))
		history.changes = 1 # pas encore enregistrée dans son fichier
		_autosaved_changes = 1
	var drop := func() -> void: DirAccess.remove_absolute(AUTOSAVE_PATH)
	_confirm("Travail non enregistré", "Une sauvegarde automatique existe :\n« %s » du %s.\n\nLa reprendre ?" % [raw.get("name", "?"), when.replace("T", " à ")],
			"Reprendre", resume, "Ignorer", drop)


func _unsaved() -> bool:
	return history.changes != _saved_changes


## Demande confirmation avant de perdre des modifications.
func _guard(action: Callable) -> void:
	if not _unsaved():
		action.call()
		return
	var save_then := func() -> void:
		save()
		action.call()
	_confirm("Modifications non enregistrées", "La carte « %s » a des modifications non enregistrées." % doc.name,
			"Enregistrer puis continuer", save_then, "Continuer sans enregistrer", action)


func new_map() -> void:
	_guard(func() -> void: _load_doc(EditorDoc.from_map(_default_map())))


func test() -> void:
	_sync_name()
	_refresh_view()
	_check()
	if not issues.is_empty():
		_show_issues()
		return
	_autosave()
	var m := doc.to_map()
	Ui.editor_map = m
	_store_session(m)
	Ui.testing = true
	Ui.play_custom(doc.to_map())


func back_to_menu() -> void:
	_sync_name()
	_autosave()
	var m := doc.to_map()
	Ui.editor_map = m
	_store_session(m)
	Ui.goto("menu")


func _store_session(m: MapData) -> void:
	Ui.set("editor_session", {
		"map": m, "doc": doc, "history": history, "layers": layers, "tab": tab, "tool": tool, "terrain_mat": terrain_mat,
		"brush": brush, "obj_tool": obj_tool, "obj_opts": obj_opts, "cam": camera.position, "zoom": camera.zoom.x,
		"grid": show_grid, "paths": show_paths, "saved": _saved_changes, "autosaved": _autosaved_changes,
	})


func _restore_session(s: Dictionary) -> void:
	doc = s.doc
	history = s.history
	layers = s.layers
	_saved_changes = s.saved
	_autosaved_changes = s.autosaved
	_name_edit.text = doc.name
	set_tab(s.tab)
	set_tool(s.tool)
	terrain_mat = s.terrain_mat
	for id in _mat_buttons:
		(_mat_buttons[id] as Button).set_pressed_no_signal(id == terrain_mat)
	set_brush(s.brush)
	obj_tool = s.obj_tool
	obj_opts = s.obj_opts
	catalog.select(obj_tool)
	show_grid = s.grid
	_grid_btn.set_pressed_no_signal(show_grid)
	show_paths = s.paths
	_paths_btn.set_pressed_no_signal(show_paths)
	_refresh_layers()
	after_change()
	_refresh_view()
	camera.position = s.cam
	camera.zoom = Vector2(s.zoom, s.zoom)


func open_map(m: MapData) -> void:
	_guard(func() -> void: _load_doc(EditorDoc.from_map(m)))


func resize_map(w: int, h: int) -> void:
	if w == doc.width() and h == doc.height():
		return
	if history.record("Taille de la carte", func() -> void: doc.resize(w, h)):
		clear_selection()
		after_change()
		fit_camera()


func set_ground(gk: String) -> void:
	if not layers.editable("terrain"):
		_toast("Calque Terrain verrouillé", Ui.RED)
		return
	if history.record("Sol", func() -> void: doc.ground = gk):
		after_change()


# =============================================================================================
# Interface
# =============================================================================================

func _build_ui() -> void:
	# Zone de dépôt (glisser-déposer depuis le catalogue) : sous les panneaux, active seulement
	# pendant un glisser, pour ne pas gêner la souris sur la carte.
	_drop_zone = Control.new()
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_drop_zone)
	_drop_zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drop_zone.set_drag_forwarding(Callable(), _can_drop, _drop)
	var root := EditorUi.vbox(0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_build_top())
	var mid := EditorUi.hbox(0)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mid)
	mid.add_child(_build_left())
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(gap)
	mid.add_child(_build_right())
	root.add_child(_build_status())
	# Messages courts, au-dessus de la barre d'état
	_toast_panel = PanelContainer.new()
	var tsb := EditorUi.panel_style(4)
	tsb.bg_color = Color(0.02, 0.04, 0.08, 0.94)
	tsb.content_margin_top = 4
	tsb.content_margin_bottom = 4
	_toast_panel.add_theme_stylebox_override("panel", tsb)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = EditorUi.label("", 14)
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false
	_ui.add_child(_toast_panel)
	set_tab("map")
	set_tool("paint")
	set_terrain_mat("#")
	set_brush(1)


func _build_top() -> Control:
	var p := EditorUi.panel()
	var sb := EditorUi.panel_style(0)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var h := EditorUi.hbox(6)
	var back := EditorUi.button("‹ Menu", "Retour au menu (le travail est gardé)")
	back.pressed.connect(back_to_menu)
	h.add_child(back)
	var file := MenuButton.new()
	file.text = "Fichier ▾"
	file.flat = false
	file.focus_mode = Control.FOCUS_NONE
	file.custom_minimum_size = Vector2(0, EditorUi.BTN_H)
	file.add_theme_font_size_override("font_size", EditorUi.FONT)
	var pm := file.get_popup()
	pm.add_theme_font_size_override("font_size", 14)
	pm.add_item("Nouvelle mission", 0)
	pm.add_item("Mes missions…  (Ctrl+O)", 1)
	pm.add_item("Enregistrer  (Ctrl+S)", 2)
	pm.add_item("Enregistrer sous…", 3)
	pm.add_separator()
	pm.add_item("Importer…", 6)
	pm.add_item("Exporter cette mission…", 7)
	pm.add_separator()
	pm.add_item("Paramètres de la carte…", 4)
	pm.add_item("Raccourcis clavier…  (F1)", 5)
	pm.id_pressed.connect(_file_menu)
	h.add_child(file)
	_name_edit = EditorUi.line_edit("Nom de la mission", 150)
	_name_edit.text_submitted.connect(func(_t: String) -> void:
		_sync_name()
		_name_edit.release_focus())
	_name_edit.focus_exited.connect(_sync_name)
	h.add_child(_name_edit)
	h.add_child(VSeparator.new())
	for i in TABS.size():
		var pair: Array = TABS[i]
		var b := EditorUi.button(pair[1], "Onglet %s (%d)" % [pair[1], i + 1], true, 64)
		var t: String = pair[0]
		b.pressed.connect(func() -> void: set_tab(t))
		_tab_buttons[t] = b
		h.add_child(b)
	h.add_child(VSeparator.new())
	_undo_btn = EditorUi.button("↶", "Annuler (Ctrl+Z)", false, 34)
	_undo_btn.pressed.connect(do_undo)
	h.add_child(_undo_btn)
	_redo_btn = EditorUi.button("↷", "Rétablir (Ctrl+Y)", false, 34)
	_redo_btn.pressed.connect(do_redo)
	h.add_child(_redo_btn)
	# Édition : menu compact (les mêmes actions sont au clic droit et dans la fiche).
	var edit := MenuButton.new()
	edit.text = "Édition ▾"
	edit.flat = false
	edit.focus_mode = Control.FOCUS_NONE
	edit.tooltip_text = "Copier, couper, coller, dupliquer, supprimer"
	edit.custom_minimum_size = Vector2(0, EditorUi.BTN_H)
	edit.add_theme_font_size_override("font_size", EditorUi.FONT)
	var em := edit.get_popup()
	em.add_theme_font_size_override("font_size", 14)
	var edit_items := [["copy", "Copier"], ["cut", "Couper"], ["paste", "Coller"], ["duplicate", "Dupliquer"], ["delete", "Supprimer"], ["select_all", "Tout sélectionner"]]
	edit.about_to_popup.connect(func() -> void:
		em.clear()
		var keys := EditorShortcuts.keys()
		for i in edit_items.size():
			var k: String = keys.get(edit_items[i][0], "")
			em.add_item("%s%s" % [edit_items[i][1], ("    " + EditorShortcuts.pretty(k)) if k != "" else ""], i))
	em.id_pressed.connect(func(i: int) -> void: run_action(edit_items[i][0]))
	h.add_child(edit)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sp)
	var val := EditorUi.button("Valider", "Liste des problèmes et avertissements")
	val.pressed.connect(_show_issues)
	h.add_child(val)
	var save_b := EditorUi.button("Enregistrer", "Enregistrer (Ctrl+S)")
	save_b.pressed.connect(save)
	h.add_child(save_b)
	var test_b := EditorUi.primary("▶ Tester", "Lancer la mission (F5)", 90)
	test_b.pressed.connect(test)
	h.add_child(test_b)
	p.add_child(h)
	return p


func _build_left() -> Control:
	_left = EditorUi.panel()
	_left.custom_minimum_size = Vector2(PANEL_W, 0)
	var v := EditorUi.vbox(8)
	_tool_row = EditorUi.hbox(3)
	for id in ["select", "paint", "fill", "place", "erase", "pipette"]:
		var info: Array = TOOL_INFO[id]
		var b := EditorUi.button(info[0], "%s (%s)\n%s" % [info[0], info[1], info[2]], true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		var tid: String = id
		b.pressed.connect(func() -> void: set_tool(tid))
		_tool_buttons[id] = b
		_tool_row.add_child(b)
	v.add_child(_tool_row)
	_tool_sep = EditorUi.sep()
	v.add_child(_tool_sep)

	# Onglet CARTE
	var mapbox := EditorUi.vbox(6)
	mapbox.add_child(EditorUi.section("Terrain"))
	var mg := EditorUi.grid(2, 3)
	for m in MATERIALS:
		var b := EditorUi.button(m.name, m.name + (" (%s)" % m.key if m.has("key") else ""), true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 112
		b.clip_text = true
		EditorUi.swatch(b, EditorCanvas.CHAR_COLORS[m.id])
		var id: String = m.id
		b.pressed.connect(func() -> void: set_terrain_mat(id))
		_mat_buttons[id] = b
		mg.add_child(b)
	mapbox.add_child(mg)
	mapbox.add_child(EditorUi.section("Taille du pinceau  [ ]"))
	var bh := EditorUi.hbox(3)
	for n in [1, 2, 3, 4]:
		var b := EditorUi.button("%d×%d" % [2 * n - 1, 2 * n - 1], "", true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nn: int = n
		b.pressed.connect(func() -> void: set_brush(nn))
		_brush_buttons[n] = b
		bh.add_child(b)
	mapbox.add_child(bh)
	mapbox.add_child(EditorUi.section("Sol"))
	var gh := EditorUi.grid(3, 3)
	for pair in GROUNDS:
		var b := EditorUi.button(pair[1], "", true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gk: String = pair[0]
		b.pressed.connect(func() -> void: set_ground(gk))
		_ground_buttons[gk] = b
		gh.add_child(b)
	mapbox.add_child(gh)
	mapbox.add_child(EditorUi.muted("Routes et rails posés sur l'eau deviennent des ponts. Une seule base par joueur."))
	v.add_child(mapbox)
	_left_boxes["map"] = mapbox

	# Onglet OBJETS
	catalog = EditorCatalog.new()
	catalog.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog.picked.connect(func(id: String) -> void:
		obj_tool = id
		catalog.select(id)
		set_tool("place"))
	v.add_child(catalog)
	_left_boxes["objects"] = catalog
	catalog.select(obj_tool)

	# Onglets OBJECTIFS et ÉVÉNEMENTS
	objectives_panel = EditorScenarioPanel.new(self, "objectives")
	v.add_child(objectives_panel)
	_left_boxes["objectives"] = objectives_panel
	events_panel = EditorScenarioPanel.new(self, "events")
	v.add_child(events_panel)
	_left_boxes["events"] = events_panel
	waves_panel = EditorScenarioPanel.new(self, "waves")
	v.add_child(waves_panel)
	_left_boxes["waves"] = waves_panel

	# Onglet MISSION
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mission_panel = EditorMissionPanel.new(self)
	mission_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(mission_panel)
	v.add_child(scroll)
	_left_boxes["mission"] = scroll
	_left.add_child(v)
	return _left


func _build_right() -> Control:
	var p := EditorUi.panel()
	p.custom_minimum_size = Vector2(RIGHT_W, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := EditorUi.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_context = EditorUi.vbox(6)
	v.add_child(_context)
	v.add_child(EditorUi.sep())
	v.add_child(EditorUi.section("Calques"))
	for l in EditorLayers.LIST:
		var row := EditorUi.hbox(3)
		var eye := EditorUi.button("", "Afficher / masquer", true, 30)
		eye.icon = EditorUi.icon("eye")
		eye.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var lock := EditorUi.button("", "Verrouiller (non modifiable)", true, 30)
		lock.icon = EditorUi.icon("lock")
		lock.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var lid: String = l.id
		eye.button_pressed = true
		eye.pressed.connect(func() -> void:
			layers.hidden[lid] = not eye.button_pressed
			_layers_changed())
		lock.pressed.connect(func() -> void:
			layers.locked[lid] = lock.button_pressed
			_layers_changed())
		if lid == "terrain":
			eye.disabled = true
			eye.tooltip_text = "Le sol reste toujours affiché"
		var name := EditorUi.label(l.name, 13)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		row.add_child(eye)
		row.add_child(lock)
		row.add_child(name)
		v.add_child(row)
		_layer_rows[lid] = [eye, lock, name]
	var lh := EditorUi.hbox(3)
	var all_on := EditorUi.button("Tout afficher")
	all_on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_on.pressed.connect(func() -> void:
		layers.hidden.clear()
		layers.locked.clear()
		_layers_changed())
	lh.add_child(all_on)
	v.add_child(lh)
	v.add_child(EditorUi.sep())
	v.add_child(EditorUi.section("Affichage"))
	var dh := EditorUi.hbox(3)
	_grid_btn = EditorUi.button("Grille", "Afficher la grille (G)", true)
	_grid_btn.button_pressed = true
	_grid_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_btn.pressed.connect(toggle_grid)
	dh.add_child(_grid_btn)
	_paths_btn = EditorUi.button("Passages", "Vérifier les passages : chemins des vagues, zones inaccessibles, gisements bloqués", true)
	_paths_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paths_btn.pressed.connect(toggle_paths)
	dh.add_child(_paths_btn)
	v.add_child(dh)
	var fit := EditorUi.button("Cadrer la carte", "Ctrl+0")
	fit.pressed.connect(fit_camera)
	v.add_child(fit)
	scroll.add_child(v)
	p.add_child(scroll)
	return p


func _build_status() -> Control:
	var p := PanelContainer.new()
	var sb := EditorUi.panel_style(0)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var h := EditorUi.hbox(14)
	_status_cell = EditorUi.label("", 12)
	_status_cell.custom_minimum_size.x = 300
	h.add_child(_status_cell)
	_status_hint = EditorUi.label("", 12, Color(0.55, 0.62, 0.72))
	_status_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_hint.clip_text = true
	h.add_child(_status_hint)
	_status_save = EditorUi.label("", 12)
	h.add_child(_status_save)
	_status_check = EditorUi.button("", "Voir les problèmes")
	_status_check.flat = true
	_status_check.custom_minimum_size.y = 22
	_status_check.pressed.connect(_show_issues)
	h.add_child(_status_check)
	_status_zoom = EditorUi.label("", 12, Color(0.55, 0.62, 0.72))
	_status_zoom.custom_minimum_size.x = 48
	h.add_child(_status_zoom)
	p.add_child(h)
	return p


func _layers_changed() -> void:
	_refresh_layers()
	_view_dirty = true
	# Ce qui devient masqué sort de la sélection.
	sel_ids.assign(sel_ids.filter(func(id: int) -> bool: return layers.entity_visible(doc.entity_by_id(id))))
	_refresh_context()


func _refresh_layers() -> void:
	for lid in _layer_rows:
		var r: Array = _layer_rows[lid]
		(r[0] as Button).set_pressed_no_signal(layers.visible(lid))
		(r[1] as Button).set_pressed_no_signal(layers.locked.get(lid, false))
		(r[2] as Label).modulate = Color(1, 1, 1, 1.0 if layers.editable(lid) else 0.45)


func _refresh_ground_buttons() -> void:
	for gk in _ground_buttons:
		(_ground_buttons[gk] as Button).set_pressed_no_signal(doc != null and gk == doc.ground)


# --- Panneau de contexte (droite, en haut) ---------------------------------------------------------

func _refresh_context() -> void:
	if _context == null or doc == null:
		return
	for c in _context.get_children():
		c.queue_free()
	if has_selection() and tab != "mission":
		_context_selection()
	elif tab == "map":
		_context.add_child(EditorUi.section(TOOL_INFO[tool][0] if TOOL_INFO.has(tool) else "Carte"))
		if tool in ["paint", "fill"]:
			_context.add_child(EditorUi.label("Terrain : %s" % _char_name(terrain_mat)))
		_context.add_child(EditorUi.muted(TOOL_INFO.get(tool, ["", "", ""])[2]))
	elif tab == "objects":
		if tool == "place":
			_context.add_child(EditorUi.section("À poser"))
			var l := EditorUi.label(_tool_label(obj_tool))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_context.add_child(l)
			_options_ui(obj_tool.split(":")[0], obj_tool, obj_opts, func(k: String, v: Variant) -> void: obj_opts[k] = v)
		else:
			_context.add_child(EditorUi.section(TOOL_INFO[tool][0]))
		_context.add_child(EditorUi.muted(TOOL_INFO.get(tool, ["", "", ""])[2]))
	else:
		_context.add_child(EditorUi.section("Mission"))
		_context.add_child(EditorUi.muted("Les objets de mission (VIP, trajets, zones, bâtiment à défendre) se posent dans l'onglet Objets."))


func _context_selection() -> void:
	var nb := sel_ids.size()
	var cells := 0
	if sel_rect.has_area():
		for y in sel_rect.size.y:
			for x in sel_rect.size.x:
				var ch := doc.get_char(sel_rect.position + Vector2i(x, y))
				if ch != "." and layers.char_editable(ch):
					cells += 1
	_context.add_child(EditorUi.section("Sélection"))
	var parts: Array[String] = []
	if sel_rect.has_area():
		parts.append("%d×%d (%d case%s de terrain)" % [sel_rect.size.x, sel_rect.size.y, cells, "s" if cells > 1 else ""])
	if nb > 0:
		parts.append("%d objet%s" % [nb, "s" if nb > 1 else ""])
	_context.add_child(EditorUi.label(", ".join(parts), 12))
	_fiche_name = null
	if nb == 1:
		_fiche(doc.entity_by_id(sel_ids[0]))
	var g := EditorUi.grid(3, 3)
	for a in [["↻ Pivoter", "R", rotate_any], ["⇋ Miroir", "M", func() -> void: mirror_any(true)], ["⇅ Miroir", "Maj+M", func() -> void: mirror_any(false)],
			["Copier", "Ctrl+C", do_copy], ["Dupliquer", "Ctrl+D", do_duplicate], ["Supprimer", "Suppr", do_delete]]:
		var b := EditorUi.button(a[0], a[1])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(a[2])
		g.add_child(b)
	_context.add_child(g)
	_context.add_child(EditorUi.muted("Glisser la sélection pour la déplacer · Échap pour désélectionner"))


# --- Fiche d'un objet ----------------------------------------------------------------------------

func _right_click(c: Vector2i) -> void:
	if not pick.is_empty():
		end_pick()
		return
	if not floating.is_empty():
		escape()
		return
	var e := doc.entity_at(c, func(x: Dictionary) -> bool: return layers.entity_visible(x))
	var pm := PopupMenu.new()
	pm.add_theme_font_size_override("font_size", 14)
	if e.is_empty():
		clear_selection()
		pm.add_item("Coller ici  (Ctrl+V)", 20)
		pm.set_item_disabled(pm.get_item_index(20), clipboard.is_empty())
		if doc.inside(c):
			pm.add_item("Pipette : %s" % _char_name(doc.get_char(c)), 21)
		pm.add_item("Centrer la vue ici", 22)
		pm.add_separator()
		pm.add_item("Tout sélectionner  (Ctrl+A)", 23)
	else:
		if tab == "mission":
			set_tab("objects")
		set_tool("select")
		sel_rect = Rect2i()
		sel_ids = [int(e.id)]
		_refresh_context()
		pm.add_separator(str(e.get("name", "")))
		pm.add_item("Renommer", 1)
		pm.add_item("Dupliquer  (Ctrl+D)", 2)
		pm.add_item("Copier  (Ctrl+C)", 3)
		pm.add_item("Pivoter  (R)", 4)
		var uses := entity_uses(int(e.id))
		pm.add_item("Utilisé par : %d élément%s" % [uses.size(), "s" if uses.size() > 1 else ""] if not uses.is_empty() else "Utilisé par : rien", 5)
		pm.set_item_disabled(pm.get_item_index(5), uses.is_empty())
		pm.add_separator()
		pm.add_item("Supprimer  (Suppr)", 6)
	var eid := int(e.get("id", -1))
	pm.id_pressed.connect(func(id: int) -> void: _context_action(id, c, eid))
	pm.popup_hide.connect(pm.queue_free)
	_ui.add_child(pm)
	pm.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))


func _context_action(id: int, c: Vector2i, eid: int) -> void:
	match id:
		1:
			if _fiche_name != null:
				_fiche_name.grab_focus()
				_fiche_name.select_all()
		2:
			do_duplicate()
		3:
			do_copy()
		4:
			rotate_any()
		5:
			_toast("Utilisé par : " + ", ".join(entity_uses(eid)))
		6:
			do_delete()
		20:
			do_paste()
		21:
			pipette(c)
		22:
			look_at_cell(c)
		23:
			select_all()


func start_pick(id: int, key: String, accept: Callable, hint: String) -> void:
	pick = {"id": id, "key": key, "accept": accept, "hint": hint}
	_status_hint.text = hint + "  ·  Échap / clic droit : terminer"
	_toast("Clique sur : " + hint.to_lower() if key != "patrol" else hint)


## Choix d'un objet sur la carte pour un formulaire (objectifs, déclencheurs) : cb(objet).
func start_pick_cb(accept: Callable, hint: String, cb: Callable, multi := false) -> void:
	pick = {"id": -1, "key": "cb", "accept": accept, "hint": hint, "cb": cb, "multi": multi}
	_status_hint.text = "Clique sur : " + hint.to_lower() + "  ·  Échap / clic droit : terminer"
	_toast("Clique sur : " + hint.to_lower())


func end_pick() -> void:
	pick = {}
	set_tool(tool)


func _pick_press(c: Vector2i) -> void:
	if pick.key == "cb":
		var acc: Callable = pick.accept
		var hit := doc.entity_at(c, func(x: Dictionary) -> bool: return layers.entity_visible(x) and acc.call(x))
		if hit.is_empty():
			_toast("Clique sur : " + str(pick.hint).to_lower(), Ui.GOLD)
			return
		(pick.cb as Callable).call(hit)
		if not pick.get("multi", false):
			end_pick()
		return
	var id := int(pick.id)
	var e := doc.entity_by_id(id)
	if e.is_empty():
		end_pick()
		return
	if pick.key == "patrol":
		if not doc.inside(c):
			return
		var add_point := func() -> void:
			var pts: Array = doc.entity_by_id(id).get("patrol", []).duplicate()
			pts.append([c.x, c.y])
			doc.entity_by_id(id).patrol = pts
		if history.record("Patrouille · " + str(e.name), add_point):
			after_change()
		return
	var accept: Callable = pick.accept
	var t := doc.entity_at(c, func(x: Dictionary) -> bool: return layers.entity_visible(x) and int(x.id) != id and accept.call(x))
	if t.is_empty():
		_toast("Clique sur : " + str(pick.hint).to_lower(), Ui.GOLD)
		return
	var key: String = pick.key
	var tid := int(t.id)
	if history.record("Lien · " + str(e.name), func() -> void: doc.entity_by_id(id)[key] = tid):
		after_change()
	_toast("%s → %s" % [e.name, t.name], Ui.GREEN)
	end_pick()


## Modifie une propriété d'un objet (avec annulation). rebuild = redessiner la fiche.
func _set_prop(id: int, key: String, value: Variant, rebuild := false) -> void:
	var e := doc.entity_by_id(id)
	if e.is_empty():
		return
	var change := func() -> void:
		var x := doc.entity_by_id(id)
		if value == null:
			x.erase(key)
		else:
			x[key] = value
	var ok := history.record("Fiche · " + str(e.name), change)
	if not ok:
		return
	if rebuild:
		after_change()
	else:
		_view_dirty = true
		_check_dirty = true
		_refresh_undo()


func _fiche_row(g: GridContainer, label: String, ctl: Control, tip := "") -> void:
	var l := EditorUi.label(label, 13)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(l)
	g.add_child(ctl)


func _fiche_toggle(id: int, key: String, on: bool, text_on: String, text_off: String, rebuild := false) -> Button:
	var b := EditorUi.button(text_on if on else text_off, "", true, 104)
	b.button_pressed = on
	b.pressed.connect(func() -> void:
		b.text = text_on if b.button_pressed else text_off
		_set_prop(id, key, b.button_pressed, rebuild))
	return b


func _fiche_spin(id: int, key: String, value: float, lo: float, hi: float, step: float, suffix := "", scale := 1.0) -> SpinBox:
	var s := EditorUi.spin(lo, hi, step, value * scale, 104)
	s.suffix = suffix
	s.value_changed.connect(func(v: float) -> void: _set_prop(id, key, v / scale))
	return s


## Faction d'un objet posé (valeur par défaut selon son type).
static func entity_faction(e: Dictionary) -> String:
	if e.has("faction"):
		return str(e.faction)
	match str(e.get("kind", "")):
		"enemy", "structure":
			return "enemy"
		"ally_unit":
			return "p1" if e.get("selectable", true) else "ally"
	return "p1"


func _fiche_options(id: int, key: String, items: Array, current: String, rebuild := true) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(0, EditorUi.BTN_H)
	o.add_theme_font_size_override("font_size", 13)
	o.get_popup().add_theme_font_size_override("font_size", 14)
	for i in items.size():
		o.add_item(items[i][1], i)
		if items[i][0] == current:
			o.select(i)
	o.item_selected.connect(func(i: int) -> void: _set_prop(id, key, items[i][0], rebuild))
	return o


func _fiche_link(id: int, key: String, label: String, accept: Callable, hint: String) -> void:
	var e := doc.entity_by_id(id)
	var tid := int(e.get(key, -1))
	var t := doc.entity_by_id(tid) if tid >= 0 else {}
	var h := EditorUi.hbox(4)
	var l := EditorUi.label("%s : %s" % [label, t.name if not t.is_empty() else "aucun"], 13, Color(0.85, 0.9, 0.97) if not t.is_empty() else Ui.GOLD)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	h.add_child(l)
	var b := EditorUi.button("Choisir…", hint)
	b.pressed.connect(func() -> void: start_pick(id, key, accept, hint))
	h.add_child(b)
	if not t.is_empty():
		var x := EditorUi.button("✕", "Retirer le lien", false, 26)
		x.pressed.connect(func() -> void: _set_prop(id, key, null, true))
		h.add_child(x)
	_context.add_child(h)


func _fiche(e: Dictionary) -> void:
	var id := int(e.id)
	var kind := str(e.kind)
	var name := EditorUi.line_edit("Nom")
	name.text = str(e.name)
	name.text_submitted.connect(func(t: String) -> void:
		_rename(id, t)
		name.release_focus())
	name.focus_exited.connect(func() -> void: _rename(id, name.text))
	_fiche_name = name
	_context.add_child(name)
	_context.add_child(EditorUi.muted("%s · id %d · case %d, %d" % [_tool_label(EditorDoc.entity_tool(e)), id, int(e.cell[0]), int(e.cell[1])]))
	# Comportement
	if kind in ["enemy", "ally_unit"]:
		_context.add_child(EditorUi.section("Comportement"))
		var items: Array = ENEMY_BEHAVIORS if kind == "enemy" else ALLY_BEHAVIORS
		var beh := str(e.get("behavior", ("static" if kind == "enemy" else "hold") if e.get("hold", false) else "guard"))
		_context.add_child(_fiche_options(id, "behavior", items, beh))
		match beh:
			"patrol":
				var pts: Array = e.get("patrol", [])
				var h := EditorUi.hbox(4)
				var l := EditorUi.label("%d point%s" % [pts.size(), "s" if pts.size() > 1 else ""], 13, Ui.GOLD if pts.size() < 2 else Color(0.85, 0.9, 0.97))
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(l)
				var tr := EditorUi.button("Tracer…", "Clique les points de patrouille sur la carte, dans l'ordre")
				tr.pressed.connect(func() -> void: start_pick(id, "patrol", Callable(), "Clique les points de patrouille dans l'ordre"))
				h.add_child(tr)
				var clr := EditorUi.button("Effacer")
				clr.pressed.connect(func() -> void: _set_prop(id, "patrol", [], true))
				h.add_child(clr)
				_context.add_child(h)
			"defend":
				_fiche_link(id, "target", "Structure", func(x: Dictionary) -> bool: return x.kind == "structure", "Une structure ennemie à défendre")
			"attack_target":
				_fiche_link(id, "target", "Cible", func(x: Dictionary) -> bool: return x.kind in ["ally_tower", "ally_unit", "defend", "building", "vip"], "Une tourelle, une unité ou un bâtiment allié")
			"attack_zone":
				_fiche_link(id, "target", "Zone", func(x: Dictionary) -> bool: return x.kind == "zone", "Une zone")
			"follow":
				var allies := kind == "ally_unit"
				_fiche_link(id, "target", "Suit", func(x: Dictionary) -> bool: return (x.kind in ["ally_unit", "vip"]) if allies else (x.kind in ["enemy", "structure"]),
						"Une unité alliée ou le VIP" if allies else "Un ennemi")
		var g := EditorUi.grid(2, 6)
		if kind == "enemy":
			_fiche_row(g, "Repli sous", _fiche_spin(id, "retreat", float(e.get("retreat", 0)), 0, 90, 5, " %"), "Retourne à son point de départ quand ses PV passent sous ce seuil (0 = jamais)")
		else:
			if Content.UNITS.get(str(e.type), {}).get("ability", "") == "siege":
				_fiche_row(g, "Départ", _fiche_toggle(id, "sieged", e.get("sieged", false), "En siège", "Mobile"))
		_context.add_child(g)
	# Faction
	if kind in ["enemy", "structure", "ally_unit", "vip"]:
		var camp := "enemy" if kind in ["enemy", "structure"] else "player"
		var facs := Factions.new(doc.factions).ids(camp)
		var cur := str(e.get("faction", entity_faction(e)))
		var gf := EditorUi.grid(2, 6)
		var fo := _fiche_options(id, "faction", facs, cur)
		_fiche_row(gf, "Faction", fo, "Joueur 1 / 2 : contrôlée par le joueur. Les autres factions sont pilotées par l'ordinateur." if camp == "player" else "Neutres et factions personnalisées : relations réglées dans l'onglet Mission")
		_context.add_child(gf)
	# Statistiques
	if kind in ["enemy", "structure", "ally_unit", "ally_tower", "defend", "building", "vip"]:
		_context.add_child(EditorUi.section("Statistiques"))
		var g := EditorUi.grid(2, 6)
		_fiche_row(g, "Points de vie", _fiche_spin(id, "hp_mul", float(e.get("hp_mul", 1.0)), 10, 1000, 10, " %", 100.0))
		if kind not in ["defend", "building", "vip"] and e.get("type", "") != "e_generator":
			_fiche_row(g, "Dégâts", _fiche_spin(id, "dmg_mul", float(e.get("dmg_mul", 1.0)), 0, 1000, 10, " %", 100.0))
			_fiche_row(g, "Portée", _fiche_spin(id, "rng_mul", float(e.get("rng_mul", 1.0)), 10, 400, 10, " %", 100.0))
		if kind in ["enemy", "ally_unit"]:
			_fiche_row(g, "Vitesse", _fiche_spin(id, "spd_mul", float(e.get("spd_mul", 1.0)), 10, 400, 10, " %", 100.0))
		_context.add_child(g)
		var g2 := EditorUi.grid(2, 6)
		_fiche_row(g2, "Dégâts subis", _fiche_toggle(id, "inv", e.get("inv", false), "Invulnérable", "Normal"))
		if kind == "ally_tower":
			var lv := EditorUi.spin(1, BuildSite.MAX_LEVEL, 1, int(e.get("level", 1)), 104)
			lv.value_changed.connect(func(v: float) -> void: _set_prop(id, "level", int(v)))
			_fiche_row(g2, "Niveau", lv)
		if kind in ["ally_tower", "defend", "building"]:
			_fiche_row(g2, "État", _fiche_toggle(id, "building", e.get("building", false), "En chantier", "Construit"), "En chantier : les ouvriers doivent le terminer")
		_context.add_child(g2)
	# Réglages propres
	var g3 := EditorUi.grid(2, 6)
	match kind:
		"deco":
			var rh := EditorUi.hbox(2)
			for r in 4:
				var rb := EditorUi.button("%d°" % (r * 90), "Rotation (R)", true, 34)
				rb.add_theme_font_size_override("font_size", 11)
				rb.button_pressed = int(e.get("rot", 0)) == r
				var rr: int = r
				rb.pressed.connect(func() -> void: _set_prop(id, "rot", rr, true))
				rh.add_child(rb)
			_fiche_row(g3, "Rotation", rh)
			_fiche_row(g3, "Miroir", _fiche_toggle(id, "flip", e.get("flip", false), "Retourné", "Normal"))
			_fiche_row(g3, "Passage", _fiche_toggle(id, "block", e.get("block", false), "Bloque", "Libre"))
		"waypoint":
			_fiche_row(g3, "Pause", _fiche_spin(id, "pause", float(e.get("pause", 0.0)), 0, 600, 1, " s"))
		"zone":
			var roles := []
			for r in EditorDoc.ZONE_ROLES:
				roles.append([r, EditorDoc.ZONE_ROLES[r]])
			_context.add_child(_fiche_options(id, "role", roles, str(e.get("role", "capture"))))
			_fiche_row(g3, "Rayon", _fiche_spin(id, "radius", float(e.get("radius", 2.5)), 1, 12, 0.5, " cases"))
			if e.get("role", "") == "capture":
				_fiche_row(g3, "Temps à tenir", _fiche_spin(id, "time", float(e.get("time", 30.0)), 5, 900, 5, " s"))
			if e.get("role", "") in ["extraction", "passage", "trigger"]:
				_context.add_child(EditorUi.muted("Rôle utilisé par les objectifs et déclencheurs (livraison 3)."))
		"door":
			_fiche_row(g3, "Longueur", _fiche_spin(id, "len", float(e.get("len", 2)), 1, 8, 1, " cases"))
			_fiche_row(g3, "Sens", _fiche_toggle(id, "vertical", e.get("vertical", false), "Verticale", "Horizontale", true))
			_fiche_row(g3, "Au départ", _fiche_toggle(id, "open", e.get("open", false), "Ouverte", "Fermée"))
			_context.add_child(g3)
			g3 = EditorUi.grid(2, 6)
			_fiche_link(id, "link", "S'ouvre via", func(x: Dictionary) -> bool: return x.kind in ["terminal", "structure", "enemy"],
					"Un terminal (activé) ou un objet ennemi (détruit)")
		"shield":
			_fiche_row(g3, "Rayon", _fiche_spin(id, "radius", float(e.get("radius", 4.0)), 1, 12, 0.5, " cases"))
			_context.add_child(g3)
			g3 = EditorUi.grid(2, 6)
			_fiche_link(id, "link", "Générateur", func(x: Dictionary) -> bool: return x.kind == "structure", "Le générateur qui alimente le bouclier")
		"terminal":
			_fiche_row(g3, "Temps d'activation", _fiche_spin(id, "time", float(e.get("time", 5.0)), 1, 120, 1, " s"), "Temps passé par une unité du joueur à côté")
		"prisoners":
			_fiche_row(g3, "Nombre", _fiche_spin(id, "count", float(e.get("count", 3)), 1, 12, 1))
			var units := []
			for k in Content.UNITS:
				if k not in ["worker", "escort_truck", "commander"]:
					units.append([k, str(Content.UNITS[k].name)])
			_fiche_row(g3, "Unités", _fiche_options(id, "unit", units, str(e.get("unit", "soldier")), false))
		"pickup":
			var le := EditorUi.line_edit("Libellé", 104)
			le.text = str(e.get("label", "Données"))
			le.text_submitted.connect(func(t: String) -> void: _set_prop(id, "label", t))
			le.focus_exited.connect(func() -> void: _set_prop(id, "label", le.text))
			_fiche_row(g3, "Libellé", le)
	if g3.get_child_count() > 0:
		_context.add_child(g3)
	if kind in Mission.LATE_KINDS:
		var g4 := EditorUi.grid(2, 6)
		_fiche_row(g4, "Au départ", _fiche_toggle(id, "absent", e.get("absent", false), "Absent", "Présent"),
				"Absent : apparaît avec l'action « Faire apparaître / réveiller » d'un déclencheur")
		_context.add_child(g4)
	if kind in ["ally_unit", "enemy", "structure", "ally_tower", "defend", "building", "vip", "door", "shield", "terminal", "prisoners", "pickup"]:
		_context.add_child(EditorUi.muted("Clic droit sur un objet : sa fiche · double clic : renommer"))
	_context.add_child(EditorUi.sep())


func _rename(id: int, t: String) -> void:
	var n := t.strip_edges()
	var e := doc.entity_by_id(id)
	if e.is_empty() or n == "" or n == str(e.name):
		return
	if doc.entities.any(func(x: Dictionary) -> bool: return int(x.id) != id and str(x.name) == n):
		_toast("Ce nom est déjà pris", Ui.RED)
		_refresh_context()
		return
	if history.record("Renommer · " + n, func() -> void: doc.entity_by_id(id).name = n):
		after_change()


## Réglages d'un objet (à poser ou sélectionné). setter(clé, valeur).
func _options_ui(kind: String, tool_id: String, o: Dictionary, setter: Callable) -> void:
	var g := EditorUi.grid(2, 6)
	var add_row := func(label: String, ctl: Control) -> void:
		var l := EditorUi.label(label, 12)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(l)
		g.add_child(ctl)
	match kind:
		"enemy", "ally_unit":
			var b := EditorUi.button("Immobile" if o.hold else "Mobile", "Immobile : ne quitte jamais son poste", true, 96)
			b.button_pressed = o.hold
			b.pressed.connect(func() -> void:
				setter.call("hold", b.button_pressed)
				b.text = "Immobile" if b.button_pressed else "Mobile")
			add_row.call("Comportement", b)
		"ally_tower":
			var s := EditorUi.spin(1, 3, 1, o.level)
			s.value_changed.connect(func(v: float) -> void: setter.call("level", int(v)))
			add_row.call("Niveau", s)
		"deco":
			var sz := Mission.deco_size(tool_id.split(":")[1])
			add_row.call("Taille", EditorUi.label("%d × %d cases" % [sz.x, sz.y], 12))
			var rh := EditorUi.hbox(2)
			for r in 4:
				var rb := EditorUi.button("%d°" % (r * 90), "Rotation (R)", true, 34)
				rb.add_theme_font_size_override("font_size", 11)
				rb.button_pressed = int(o.rot) == r
				var rr: int = r
				rb.pressed.connect(func() -> void:
					setter.call("rot", rr)
					for c in rh.get_children():
						(c as Button).set_pressed_no_signal(c == rb))
				rh.add_child(rb)
			add_row.call("Rotation", rh)
			var fl := EditorUi.button("Retourné", "Image retournée (miroir)", true)
			fl.button_pressed = o.flip
			fl.pressed.connect(func() -> void: setter.call("flip", fl.button_pressed))
			add_row.call("Miroir", fl)
			var bl := EditorUi.button("Bloque", "Infranchissable pour les unités", true)
			bl.button_pressed = o.block
			bl.pressed.connect(func() -> void: setter.call("block", bl.button_pressed))
			add_row.call("Passage", bl)
		"waypoint":
			var s := EditorUi.spin(0, 600, 1, o.pause)
			s.suffix = "s"
			s.value_changed.connect(func(v: float) -> void: setter.call("pause", v))
			add_row.call("Pause", s)
		"zone":
			var r := EditorUi.spin(1, 12, 0.5, o.zrad)
			r.value_changed.connect(func(v: float) -> void: setter.call("zrad", v))
			add_row.call("Rayon (cases)", r)
			if tool_id == "zone:capture":
				var t := EditorUi.spin(5, 900, 5, o.ztime)
				t.suffix = "s"
				t.value_changed.connect(func(v: float) -> void: setter.call("ztime", v))
				add_row.call("Temps à tenir", t)
	if g.get_child_count() > 0:
		_context.add_child(g)


# --- Fenêtres ------------------------------------------------------------------------------------

func _modal_frame(title: String, w := 460.0) -> VBoxContainer:
	_close_modal()
	_modal = Control.new()
	_ui.add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	_modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_modal.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := EditorUi.panel()
	var sb := EditorUi.panel_style(8)
	sb.border_color = Color(Ui.CYAN, 0.6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(w, 0)
	var v := EditorUi.vbox(10)
	v.add_child(EditorUi.label(title, 17, Ui.CYAN))
	p.add_child(v)
	center.add_child(p)
	return v


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null


func _confirm(title: String, text: String, ok_text: String, on_ok: Callable, no_text := "Annuler", on_no := Callable()) -> void:
	var v := _modal_frame(title)
	var l := EditorUi.label(text, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var h := EditorUi.hbox(8)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var no := EditorUi.button(no_text)
	no.pressed.connect(func() -> void:
		_close_modal()
		if on_no.is_valid():
			on_no.call())
	h.add_child(no)
	var ok := EditorUi.primary(ok_text)
	ok.pressed.connect(func() -> void:
		_close_modal()
		on_ok.call())
	h.add_child(ok)
	v.add_child(h)


func _close_row(v: VBoxContainer, extra: Array = []) -> void:
	var h := EditorUi.hbox(8)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	for b in extra:
		h.add_child(b)
	var close := EditorUi.button("Fermer")
	close.pressed.connect(_close_modal)
	h.add_child(close)
	v.add_child(h)


func _show_issues() -> void:
	_check()
	var v := _modal_frame("Validation de la mission", 600)
	if issues.is_empty() and warns.is_empty():
		v.add_child(EditorUi.label("✔ Aucun problème : la mission peut être testée.", 14, Ui.GREEN))
	else:
		v.add_child(EditorUi.muted("%d erreur%s (empêchent de tester), %d avertissement%s. « Aller » montre l'élément en cause." % [
				issues.size(), "s" if issues.size() > 1 else "", warns.size(), "s" if warns.size() > 1 else ""], 12))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, mini(420, 40 + 38 * (issues.size() + warns.size())))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := EditorUi.vbox(4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for it: Dictionary in issues + warns:
		var err: bool = it.lvl == "error"
		var h := EditorUi.hbox(6)
		var l := EditorUi.label(("✖ " if err else "⚠ ") + str(it.text), 14, Ui.RED if err else Ui.GOLD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var go: Dictionary = it.get("go", {})
		if not go.is_empty():
			var b := EditorUi.button("Aller", "Montrer l'élément en cause", false, 64)
			b.pressed.connect(func() -> void:
				_close_modal()
				go_to(go))
			h.add_child(b)
		list.add_child(h)
	if not issues.is_empty() or not warns.is_empty():
		v.add_child(scroll)
	var paths := EditorUi.button("Voir les passages")
	paths.pressed.connect(func() -> void:
		_close_modal()
		if not show_paths:
			toggle_paths())
	_close_row(v, [paths])


## Montre l'élément en cause d'un problème de validation.
func go_to(go: Dictionary) -> void:
	var tab := str(go.get("tab", "map"))
	match tab:
		"objects":
			var e := doc.entity_by_id(int(go.get("id", -1)))
			if e.is_empty():
				return
			set_tab("objects")
			sel_rect = Rect2i()
			sel_ids = [int(e.id)]
			_refresh_context()
			var c := Vector2i(int(e.cell[0]), int(e.cell[1]))
			look_at_cell(c)
			_flash(c)
		"map":
			set_tab("map")
			if go.has("cell"):
				var c := Vector2i(int(go.cell[0]), int(go.cell[1]))
				look_at_cell(c)
				_flash(c)
		"objectives", "events", "waves":
			set_tab(tab)
			var panel: EditorScenarioPanel = {"objectives": objectives_panel, "events": events_panel, "waves": waves_panel}[tab]
			if tab == "events":
				panel.view = str(go.get("view", "triggers"))
			elif tab == "waves":
				panel.view = "list"
			if go.has("id"):
				panel.selected = str(go.id)
			panel.refresh()
		_:
			set_tab(tab)


func _flash(c: Vector2i) -> void:
	flash_cell = c
	flash_time = 2.0
	canvas.queue_redraw()


func _show_open() -> void:
	_show_missions()


## Écran « Mes missions » : ouvrir, dupliquer, renommer, exporter, supprimer, importer.
func _show_missions() -> void:
	var v := _modal_frame("Mes missions", 760)
	var top := EditorUi.hbox(6)
	var nw := EditorUi.primary("+ Nouvelle mission")
	nw.pressed.connect(func() -> void:
		_close_modal()
		new_map())
	top.add_child(nw)
	var imp := EditorUi.button("Importer…", "Une mission (.json) ou un pack (.%s) avec ses décors" % MissionLibrary.PACK_EXT)
	imp.pressed.connect(_import_dialog)
	top.add_child(imp)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var exp := EditorUi.button("Exporter la sélection…", "Un pack avec les missions cochées et leurs décors")
	top.add_child(exp)
	v.add_child(top)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := EditorUi.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	v.add_child(scroll)
	var checked: Array = []
	var infos := MissionLibrary.list()
	list.add_child(EditorUi.section("Mes missions (%d)" % infos.size()))
	if infos.is_empty():
		list.add_child(EditorUi.muted("Aucune mission enregistrée pour l'instant. « Enregistrer » (Ctrl+S) range la mission ici.", 13))
	for inf: Dictionary in infos:
		list.add_child(_mission_row(inf, checked))
	exp.pressed.connect(func() -> void:
		if checked.is_empty():
			_toast("Coche les missions à exporter", Ui.GOLD)
			return
		_export_dialog(checked.duplicate()))
	list.add_child(EditorUi.section("Campagne (ouverte en copie)"))
	for l in Content.LEVELS:
		var md := MapData.load_from(l.map)
		md.path = ""
		md.waves = l.waves
		md.difficulty = l.difficulty
		md.interval = l.get("interval", 30.0)
		_open_entry(list, "%02d · %s" % [l.id, md.NAME], md)
	_close_row(v)


func _mission_row(inf: Dictionary, checked: Array) -> Control:
	var path: String = inf.path
	var row := PanelContainer.new()
	var sb := EditorUi.panel_style(6)
	sb.bg_color = Color(0.1, 0.13, 0.17)
	sb.border_color = Color(Ui.CYAN, 0.7) if path == doc.path else Color(0.25, 0.3, 0.36)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", sb)
	var h := EditorUi.hbox(10)
	row.add_child(h)
	var cb := CheckBox.new()
	cb.focus_mode = Control.FOCUS_NONE
	cb.tooltip_text = "À inclure dans le pack exporté"
	var on_toggle := func(on: bool) -> void:
		if on:
			checked.append(path)
		else:
			checked.erase(path)
	cb.toggled.connect(on_toggle)
	h.add_child(cb)
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(96, 60)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.texture = MissionPreview.texture(str(inf.preview))
	if thumb.texture == null:
		thumb.texture = ImageTexture.create_from_image(MissionPreview.render(EditorDoc.from_map(inf.map)))
	h.add_child(thumb)
	var txt := EditorUi.vbox(2)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_child(EditorUi.label(str(inf.name) + ("   · ouverte" if path == doc.path else ""), 15, Ui.CYAN if path == doc.path else Color.WHITE))
	var date := Time.get_datetime_string_from_unix_time(int(inf.modified) + int(Time.get_time_zone_from_system().bias) * 60, true)
	var players: String = {"solo": "Solo", "coop": "Coop", "both": "Solo / coop"}.get(str(inf.players), "Solo")
	var sub := "%s  ·  %s  ·  %s  ·  modifiée le %s" % [Mission.TYPE_NAMES.get(str(inf.type), str(inf.type)),
			"★".repeat(int(inf.stars)) + "☆".repeat(5 - int(inf.stars)), players, date.replace(" ", " à ").left(-3)]
	txt.add_child(EditorUi.label(sub, 12, Ui.MUTED))
	txt.add_child(EditorUi.label(path.get_file() + ("   ⚠ version plus récente (v%d)" % int(inf.version) if int(inf.version) > EditorDoc.VERSION else ""), 11, Color(0.5, 0.56, 0.64)))
	h.add_child(txt)
	var open := EditorUi.button("Ouvrir")
	open.pressed.connect(func() -> void:
		_close_modal()
		open_map(MapData.load_from(path)))
	h.add_child(open)
	var more := MenuButton.new()
	more.text = "⋯"
	more.flat = false
	more.focus_mode = Control.FOCUS_NONE
	more.custom_minimum_size = Vector2(36, EditorUi.BTN_H)
	var pm := more.get_popup()
	pm.add_theme_font_size_override("font_size", 14)
	pm.add_item("Dupliquer", 0)
	pm.add_item("Renommer…", 1)
	pm.add_item("Exporter…", 2)
	pm.add_separator()
	pm.add_item("Supprimer…", 3)
	pm.id_pressed.connect(func(id: int) -> void: _mission_action(id, path, str(inf.name)))
	h.add_child(more)
	return row


func _mission_action(id: int, path: String, name: String) -> void:
	match id:
		0:
			var np := MissionLibrary.duplicate_mission(path)
			_toast("Copie créée : %s" % np.get_file() if np != "" else "Échec de la copie", Ui.GREEN if np != "" else Ui.RED)
			_show_missions()
		1:
			_rename_dialog(path, name)
		2:
			_export_dialog([path])
		3:
			var go := func() -> void:
				if MissionLibrary.delete(path):
					_toast("« %s » supprimée (corbeille)" % name, Ui.GOLD)
					if path == doc.path:
						doc.path = ""
						_saved_changes = -1
				else:
					_toast("Suppression impossible", Ui.RED)
				_show_missions()
			_confirm("Supprimer « %s » ?" % name, "Le fichier %s part à la corbeille.%s" % [path.get_file(),
					"\nC'est la mission ouverte : elle reste à l'écran, non enregistrée." if path == doc.path else ""],
					"Supprimer", go, "Annuler", _show_missions)


func _rename_dialog(path: String, name: String) -> void:
	var v := _modal_frame("Renommer la mission")
	var e := EditorUi.line_edit("Nom")
	e.text = name
	v.add_child(e)
	var ok := EditorUi.primary("Renommer")
	var go := func() -> void:
		var n := e.text.strip_edges()
		if n == "" or n == name:
			_show_missions()
			return
		var np := MissionLibrary.rename(path, n)
		if np == "":
			_toast("Échec du renommage", Ui.RED)
		elif path == doc.path:
			doc.path = np
			history.record("Renommer la carte", func() -> void: doc.name = n)
			_name_edit.text = n
			_saved_changes = history.changes
		_show_missions()
	ok.pressed.connect(go)
	e.text_submitted.connect(func(_t: String) -> void: go.call())
	_close_row(v, [ok])
	e.grab_focus.call_deferred()
	e.select_all.call_deferred()


## Boîte de dialogue de fichier du système.
func _file_dialog(save_mode: bool, filters: PackedStringArray, title: String, default_name: String, cb: Callable) -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save_mode else FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = filters
	fd.title = title
	fd.use_native_dialog = true
	fd.current_dir = str(EditorPrefs.get_v("last_dir", OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)))
	if default_name != "":
		fd.current_file = default_name
	fd.file_selected.connect(func(p: String) -> void:
		EditorPrefs.set_v("last_dir", p.get_base_dir())
		fd.queue_free()
		cb.call(p))
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered_ratio(0.6)


func _export_dialog(paths: Array) -> void:
	var first := MapData.load_from(paths[0]).NAME if paths.size() == 1 else "pack-%d-missions" % paths.size()
	_file_dialog(true, PackedStringArray(["*.%s ; Pack RTS Defense" % MissionLibrary.PACK_EXT]), "Exporter", MapData.slug(first) + "." + MissionLibrary.PACK_EXT,
			func(dest: String) -> void:
				if not dest.ends_with("." + MissionLibrary.PACK_EXT):
					dest += "." + MissionLibrary.PACK_EXT
				var err := MissionLibrary.export_pack(paths, dest)
				_toast(("Exporté : %s" % dest.get_file()) if err == OK else "Échec de l'export (%d)" % err, Ui.GREEN if err == OK else Ui.RED))


func _import_dialog() -> void:
	_file_dialog(false, PackedStringArray(["*.%s, *.json ; Missions RTS Defense" % MissionLibrary.PACK_EXT]), "Importer", "",
			func(src: String) -> void: _show_import_report(MissionLibrary.import_file(src)))


func _show_import_report(rep: Dictionary) -> void:
	var v := _modal_frame("Import", 560)
	if not rep.ok:
		v.add_child(EditorUi.label("✖ " + str(rep.error), 14, Ui.RED))
	else:
		var n: int = rep.missions.size()
		v.add_child(EditorUi.label("✔ %d mission%s importée%s : %s" % [n, "s" if n > 1 else "", "s" if n > 1 else "", ", ".join(rep.missions)], 14, Ui.GREEN))
		if int(rep.decos) > 0:
			v.add_child(EditorUi.label("%d image%s de décor ajoutée%s." % [rep.decos, "s" if rep.decos > 1 else "", "s" if rep.decos > 1 else ""], 13))
	if not rep.missing.is_empty():
		var l := EditorUi.label("⚠ Décors introuvables (ils ne s'afficheront pas) : " + ", ".join(rep.missing), 13, Ui.GOLD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	for w in rep.warnings:
		var l := EditorUi.label("⚠ " + str(w), 13, Ui.GOLD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	var extra: Array = []
	if rep.ok and rep.paths.size() == 1:
		var open := EditorUi.primary("Ouvrir")
		var p: String = rep.paths[0]
		open.pressed.connect(func() -> void:
			_close_modal()
			open_map(MapData.load_from(p)))
		extra.append(open)
	var back := EditorUi.button("Mes missions")
	back.pressed.connect(_show_missions)
	extra.append(back)
	_close_row(v, extra)


func _open_entry(list: VBoxContainer, text: String, md: MapData) -> void:
	var b := EditorUi.button(text)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 32
	b.pressed.connect(func() -> void:
		_close_modal()
		open_map(md))
	list.add_child(b)


func _file_menu(id: int) -> void:
	match id:
		0:
			new_map()
		1:
			_show_missions()
		2:
			save()
		3:
			_show_save_as()
		4:
			_show_params()
		5:
			_show_help()
		6:
			_import_dialog()
		7:
			if doc.path == "" or _unsaved():
				save()
			if doc.path != "":
				_export_dialog([doc.path])


func _show_save_as() -> void:
	var v := _modal_frame("Enregistrer sous")
	v.add_child(EditorUi.label("Nom de la carte", 13))
	var e := EditorUi.line_edit("Nom")
	e.text = doc.name
	v.add_child(e)
	v.add_child(EditorUi.muted("Fichier : %s<nom>.json" % MapData.custom_dir(), 12))
	var ok := EditorUi.primary("Enregistrer")
	ok.pressed.connect(func() -> void:
		var n := e.text.strip_edges()
		if n == "":
			return
		history.record("Renommer la carte", func() -> void: doc.name = n)
		_name_edit.text = n
		var p := MapData.custom_dir() + MapData.slug(n) + ".json"
		var write := func() -> void:
			doc.path = p
			save()
		_close_modal()
		if FileAccess.file_exists(p) and p != doc.path:
			_confirm("Remplacer ?", "Le fichier %s existe déjà." % p.get_file(), "Remplacer", write)
		else:
			write.call())
	_close_row(v, [ok])
	e.grab_focus.call_deferred()


func _show_params() -> void:
	var v := _modal_frame("Paramètres de la carte")
	var g := EditorUi.grid(2, 8)
	g.add_child(EditorUi.label("Nom", 13))
	var name := EditorUi.line_edit("Nom", 240)
	name.text = doc.name
	g.add_child(name)
	g.add_child(EditorUi.label("Largeur (cases)", 13))
	var w := EditorUi.spin(12, 120, 1, doc.width())
	g.add_child(w)
	g.add_child(EditorUi.label("Hauteur (cases)", 13))
	var h := EditorUi.spin(10, 80, 1, doc.height())
	g.add_child(h)
	v.add_child(g)
	v.add_child(EditorUi.muted("Agrandir ajoute du sol à droite et en bas. Réduire coupe le terrain et retire les objets qui dépassent.", 12))
	var ok := EditorUi.primary("Appliquer")
	ok.pressed.connect(func() -> void:
		_close_modal()
		var n := name.text.strip_edges()
		if n != "" and n != doc.name:
			history.record("Renommer la carte", func() -> void: doc.name = n)
		resize_map(int(w.value), int(h.value))
		after_change())
	_close_row(v, [ok])


func _show_help() -> void:
	var v := _modal_frame("Raccourcis clavier", 640)
	v.add_child(EditorUi.muted("Clique sur une touche pour la changer, puis appuie sur la nouvelle (Échap : annuler). Les réglages sont gardés.", 12))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var g := EditorUi.grid(4, 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(g)
	var keys := EditorShortcuts.keys()
	for a in EditorShortcuts.ACTIONS:
		var id: String = a[0]
		var l := EditorUi.label(a[1], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(l)
		var cur: String = keys[id]
		var b := EditorUi.button(("…" if _rebinding == id else (EditorShortcuts.pretty(cur) if cur != "" else "—")), "Changer la touche", false, 120)
		if _rebinding == id:
			b.add_theme_color_override("font_color", Ui.GOLD)
		b.pressed.connect(func() -> void:
			_rebinding = id
			_show_help())
		g.add_child(b)
	v.add_child(scroll)
	v.add_child(EditorUi.section("Souris (fixes)"))
	var g2 := EditorUi.grid(2, 4)
	for row in [["Molette", "Zoom sur le curseur"], ["Clic milieu / Espace + glisser", "Déplacer la vue"], ["Clic droit", "Menu de l'objet ou de la case"],
			["Glisser depuis le catalogue", "Poser l'objet là où on lâche"], ["Maj+clic", "Pinceau : ligne droite · Sélection : ajouter"], ["Alt+clic", "Pipette"],
			["Double clic", "Renommer l'objet"], ["Échap / Retour arrière", "Désélectionner / supprimer"]]:
		g2.add_child(EditorUi.label(row[0], 12, Ui.CYAN))
		g2.add_child(EditorUi.label(row[1], 12))
	v.add_child(g2)
	var reset := EditorUi.button("Touches par défaut")
	reset.pressed.connect(func() -> void:
		EditorShortcuts.reset()
		_rebinding = ""
		_show_help())
	_close_row(v, [reset])


