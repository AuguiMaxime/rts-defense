class_name EditorCatalog
extends VBoxContainer
## Catalogue des objets à poser : recherche, catégories repliables, vignettes.

signal picked(tool_id: String)


var _search: LineEdit
var _list: VBoxContainer
var _items := {} # tool_id -> Button
var _cats: Array = [] # [{header: Button, box: Container, items: [[id, label, button]]}]
var _closed := {}
var current := ""
const PREFS := "user://editor/prefs.json"
var favorites: Array = []
var recent: Array = []


func _init() -> void:
	add_theme_constant_override("separation", 6)
	_search = EditorUi.line_edit("Rechercher un objet…")
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t: String) -> void: _filter())
	add_child(_search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = EditorUi.vbox(2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	add_child(scroll)
	_load_prefs()
	_build()


func _load_prefs() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS)) if FileAccess.file_exists(PREFS) else null
	if raw is Dictionary:
		favorites = raw.get("fav", [])
		recent = raw.get("recent", [])


func _save_prefs() -> void:
	DirAccess.make_dir_recursive_absolute(PREFS.get_base_dir())
	var f := FileAccess.open(PREFS, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"fav": favorites, "recent": recent}))


static func label_of(id: String) -> String:
	for cat in palette():
		for it in cat[1]:
			if it[0] == id:
				return it[1]
	return id


func toggle_favorite(id: String) -> void:
	if favorites.has(id):
		favorites.erase(id)
	else:
		favorites.append(id)
	_save_prefs()
	_rebuild()


func add_recent(id: String) -> void:
	if not recent.is_empty() and recent[0] == id:
		return
	recent.erase(id)
	recent.push_front(id)
	recent = recent.slice(0, 8)
	_save_prefs()
	_rebuild()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_items.clear()
	_cats.clear()
	_build()
	select(current)


static var _palette_cache: Array = []


static func palette() -> Array:
	if not _palette_cache.is_empty():
		return _palette_cache
	var cats := []
	var structs := []
	for k in Balance.ENEMY_STRUCTURES:
		if k == "e_generator":
			continue
		structs.append(["structure:" + k, str(Balance.ENEMY_STRUCTURES[k].name)])
	cats.append(["Ennemis · structures", structs])
	var foes := []
	for k in Balance.ENEMIES:
		foes.append(["enemy:" + k, str(EditorDoc.ENEMY_NAMES.get(k, k.capitalize()))])
	cats.append(["Ennemis · unités", foes])
	var towers := []
	for k in Content.TOWER_ORDER:
		towers.append(["ally_tower:" + k, str(Content.TOWERS[k].name)])
	cats.append(["Alliés · tourelles", towers])
	var allies := []
	for k in Content.UNITS:
		if k not in ["worker", "escort_truck", "commander"]:
			allies.append(["ally_unit:" + k, str(Content.UNITS[k].name)])
	cats.append(["Alliés · unités", allies])
	cats.append(["Mission", [["vip:commander", "VIP à escorter"], ["escortee:", "Départ convoi allié"], ["waypoint:", "Point de passage"]]])
	var zones := []
	for r in EditorDoc.ZONE_ROLES:
		zones.append(["zone:" + r, EditorDoc.ZONE_ROLES[r]])
	cats.append(["Zones", zones])
	cats.append(["Interactifs", [["door:", "Porte"], ["structure:e_generator", "Générateur ennemi"], ["shield:", "Bouclier (lié à un générateur)"],
			["terminal:", "Terminal à activer"], ["prisoners:", "Prisonniers à libérer"], ["pickup:", "Objet à récupérer"]]])
	var defend := []
	for k in Content.BUILDING_ORDER:
		defend.append(["defend:" + k, str(Content.building(k).name) + " à défendre"])
	cats.append(["Mission · bâtiment à défendre", defend])
	var start := []
	for k in Content.BUILDING_ORDER:
		start.append(["building:" + k, str(Content.building(k).name)])
	cats.append(["Alliés · bâtiments de départ", start])
	var decos := []
	var seen := {}
	var files := Array(DirAccess.get_files_at("res://assets/deco"))
	files.sort()
	for f in files:
		var fname: String = f.trim_suffix(".import")
		if fname.ends_with(".png") and not seen.has(fname):
			seen[fname] = true
			var base := fname.get_basename()
			var sz := Mission.deco_size(base)
			var label := base.replace("_", " ")
			if sz != Vector2i.ONE:
				label = label.trim_suffix(" %dx%d" % [sz.x, sz.y]) + "  (%d×%d)" % [sz.x, sz.y]
			decos.append(["deco:" + base, label.capitalize() if sz == Vector2i.ONE else label])
	cats.append(["Décors", decos])
	_palette_cache = cats
	return cats


## Vignette d'un objet de la palette.
static func icon_for(tool_id: String) -> Texture2D:
	var parts := tool_id.split(":")
	var t := parts[1] if parts.size() > 1 else ""
	match parts[0]:
		"structure":
			var look := str(Balance.ENEMY_STRUCTURES.get(t, {}).get("look", ""))
			if look == "hq":
				return Sprites.W_BASE
			if look in ["barracks", "bunker"]:
				return Sprites.W_BARRACKS
			if Sprites.TOWER_LOOK.has(look):
				return Sprites.TOWER_LOOK[look].turret
			return Sprites.ENEMY_LOOK.siege.tex
		"enemy":
			return Sprites.ENEMY_LOOK.get(t, {}).get("tex", null)
		"ally_tower":
			return Sprites.TOWER_LOOK.get(t, {}).get("turret", null)
		"ally_unit", "vip":
			return Sprites.UNIT_LOOK.get(t, {}).get("tex", null)
		"defend", "building":
			return Sprites.PRODUCER_LOOK.get(t, [Sprites.W_HOUSE])[0]
		"deco":
			return UnitsView.deco_texture(t)
	return null


func _build() -> void:
	var cats: Array = []
	var known := {}
	for cat in palette():
		for it in cat[1]:
			known[it[0]] = it[1]
	if not favorites.is_empty():
		cats.append(["★ Favoris", favorites.filter(func(id: String) -> bool: return known.has(id)).map(func(id: String) -> Array: return [id, known[id]])])
	if not recent.is_empty():
		cats.append(["Récents", recent.filter(func(id: String) -> bool: return known.has(id)).map(func(id: String) -> Array: return [id, known[id]])])
	cats.append_array(palette())
	for cat in cats:
		var header := EditorUi.button("", "Replier / déplier")
		header.flat = true
		header.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header.add_theme_color_override("font_color", EditorUi.SECTION)
		header.add_theme_font_size_override("font_size", 11)
		_list.add_child(header)
		var box := EditorUi.vbox(2)
		_list.add_child(box)
		var entry := {"name": cat[0], "header": header, "box": box, "items": []}
		for it in cat[1]:
			var id: String = it[0]
			var b := EditorUi.button(it[1], id, true)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.custom_minimum_size.y = 30
			var ic := icon_for(id)
			if ic != null:
				b.icon = ic
				b.expand_icon = true
				b.add_theme_constant_override("icon_max_width", 24)
			b.pressed.connect(func() -> void: picked.emit(id))
			b.tooltip_text = "%s\nClic droit : %s les favoris" % [id, "retirer des" if favorites.has(id) else "ajouter aux"]
			if favorites.has(id):
				b.text = "★ " + b.text
			b.gui_input.connect(func(ev: InputEvent) -> void:
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					toggle_favorite.call_deferred(id))
			box.add_child(b)
			if not _items.has(id):
				_items[id] = b
			else:
				_items[id + "#" + str(box.get_instance_id())] = b
			entry.items.append([id, str(it[1]).to_lower(), b])
		header.pressed.connect(func() -> void:
			_closed[entry.name] = not _closed.get(entry.name, false)
			_filter())
		_cats.append(entry)
	_filter()


func _filter() -> void:
	var q := _search.text.strip_edges().to_lower()
	for cat: Dictionary in _cats:
		var shown := 0
		for it: Array in cat.items:
			var ok := q == "" or (it[1] as String).contains(q) or (it[0] as String).contains(q)
			(it[2] as Button).visible = ok
			if ok:
				shown += 1
		var open: bool = q != "" or not _closed.get(cat.name, false)
		(cat.box as Control).visible = open and shown > 0
		(cat.header as Button).visible = shown > 0
		(cat.header as Button).text = "%s %s  (%d)" % ["▾" if open else "▸", str(cat.name).to_upper(), shown]


func select(tool_id: String) -> void:
	current = tool_id
	for id in _items:
		(_items[id] as Button).set_pressed_no_signal(str(id).split("#")[0] == tool_id)
