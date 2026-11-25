class_name EditorFactions
extends RefCounted
## Fenêtre « Factions et relations » de l'éditeur (bouton de l'onglet Mission).
##
## Les 6 factions intégrées ne se renomment pas ; on peut ajouter des factions personnalisées
## (nom, couleur, camp). Le tableau règle la relation entre chaque faction du camp joueur et
## chaque faction du camp ennemi.

const PALETTE := ["c070ff", "ff8a3d", "3dffd0", "ff4fa8", "a8ff3d", "4f7dff"]

var ed: MissionEditor


func _init(editor: MissionEditor) -> void:
	ed = editor


func data() -> Dictionary:
	return ed.doc.factions


func open() -> void:
	var v := ed._modal_frame("Factions et relations", 640)
	var expl := EditorUi.muted("Deux camps s'affrontent. Les factions d'un même camp sont toujours alliées. Entre les deux camps, choisis pour chaque paire : Ennemi, Neutre (on s'ignore) ou Hostile si attaqué (neutre jusqu'à la première attaque du joueur). Un déclencheur peut tout changer en cours de partie.", 12)
	expl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	expl.custom_minimum_size.x = 600
	v.add_child(expl)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var body := EditorUi.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_theme_constant_override("margin_right", 16)
	mc.add_child(body)
	scroll.add_child(mc)
	v.add_child(scroll)
	_factions(body)
	body.add_child(EditorUi.sep())
	_relations(body)
	ed._close_row(v)


func _factions(body: VBoxContainer) -> void:
	body.add_child(EditorUi.section("Factions"))
	var all := Factions.all(data())
	for f: Dictionary in all:
		var custom := not Factions.BUILTIN.any(func(b: Dictionary) -> bool: return b.id == f.id)
		var h := EditorUi.hbox(6)
		var sw := ColorPickerButton.new()
		sw.custom_minimum_size = Vector2(34, EditorUi.BTN_H)
		sw.color = Color.from_string(str(f.color), Color.WHITE)
		sw.edit_alpha = false
		sw.disabled = not custom
		var fid := str(f.id)
		sw.popup_closed.connect(func() -> void: _set_custom(fid, "color", sw.color.to_html(false)))
		h.add_child(sw)
		if custom:
			var e := EditorUi.line_edit("Nom de la faction")
			e.text = str(f.name)
			e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			e.text_submitted.connect(func(t: String) -> void: _set_custom(fid, "name", t.strip_edges()))
			e.focus_exited.connect(func() -> void:
				if e.text.strip_edges() != str(f.name):
					_set_custom(fid, "name", e.text.strip_edges()))
			h.add_child(e)
			var camp := OptionButton.new()
			camp.focus_mode = Control.FOCUS_NONE
			camp.custom_minimum_size = Vector2(170, EditorUi.BTN_H)
			for i in Factions.CAMPS.size():
				camp.add_item(Factions.CAMPS[i][1], i)
				if Factions.CAMPS[i][0] == f.camp:
					camp.select(i)
			camp.item_selected.connect(func(i: int) -> void: _set_custom(fid, "camp", Factions.CAMPS[i][0]))
			h.add_child(camp)
			var del := EditorUi.button("✕", "Supprimer cette faction", false, 30)
			del.pressed.connect(func() -> void: _delete(fid, str(f.name)))
			h.add_child(del)
		else:
			var l := EditorUi.label(str(f.name), 14)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l)
			h.add_child(EditorUi.label("camp du joueur" if f.camp == "player" else "camp ennemi", 12, Ui.MUTED))
		body.add_child(h)
	var add := EditorUi.button("+ Faction personnalisée")
	add.pressed.connect(_add)
	body.add_child(add)


func _relations(body: VBoxContainer) -> void:
	body.add_child(EditorUi.section("Relations"))
	var all := Factions.all(data())
	var pl := all.filter(func(f: Dictionary) -> bool: return f.camp == "player")
	var en := all.filter(func(f: Dictionary) -> bool: return f.camp == "enemy")
	var g := EditorUi.grid(en.size() + 1, 4)
	g.add_child(EditorUi.label("", 12))
	for e: Dictionary in en:
		var hl := EditorUi.label(str(e.name), 13, Color.from_string(str(e.color), Color.WHITE))
		hl.custom_minimum_size.x = 150
		g.add_child(hl)
	var rel: Dictionary = data().get("rel", {})
	for p: Dictionary in pl:
		var rl := EditorUi.label(str(p.name), 13, Color.from_string(str(p.color), Color.WHITE))
		rl.custom_minimum_size.x = 110
		g.add_child(rl)
		for e: Dictionary in en:
			var k := Factions.key(str(p.id), str(e.id))
			var cur := str(rel.get(k, Factions.default_rel(str(p.id), str(e.id))))
			var o := OptionButton.new()
			o.focus_mode = Control.FOCUS_NONE
			o.custom_minimum_size = Vector2(150, EditorUi.BTN_H)
			o.clip_text = true
			for i in Factions.RELATIONS.size():
				o.add_item(Factions.RELATIONS[i][1], i)
				if Factions.RELATIONS[i][0] == cur:
					o.select(i)
			var col := {"enemy": Ui.RED, "neutral": Color(0.75, 0.8, 0.88), "provoked": Ui.GOLD}
			o.add_theme_color_override("font_color", col.get(cur, Color.WHITE))
			o.item_selected.connect(func(i: int) -> void: _set_rel(k, Factions.RELATIONS[i][0]))
			g.add_child(o)
	body.add_child(g)


func _change(label: String, fn: Callable) -> void:
	var wrapped := func() -> void:
		if not ed.doc.factions.has("list"):
			ed.doc.factions["list"] = []
		if not ed.doc.factions.has("rel"):
			ed.doc.factions["rel"] = {}
		fn.call()
	ed.history.record(label, wrapped)
	ed.after_change()
	open()


func _set_rel(k: String, v: String) -> void:
	_change("Relation entre factions", func() -> void: ed.doc.factions.rel[k] = v)


func _set_custom(id: String, field: String, v: Variant) -> void:
	if field == "name" and str(v) == "":
		return
	var fn := func() -> void:
		for f: Dictionary in ed.doc.factions.list:
			if str(f.id) == id:
				f[field] = v
		if field == "camp":
			# Les relations de cette faction n'ont plus de sens dans l'autre camp.
			for k: String in ed.doc.factions.rel.keys():
				if k.split("|").has(id):
					ed.doc.factions.rel.erase(k)
	_change("Faction : réglage", fn)


func _add() -> void:
	var list: Array = data().get("list", [])
	var n := 1
	while list.any(func(f: Dictionary) -> bool: return str(f.id) == "f%d" % n):
		n += 1
	var f := {"id": "f%d" % n, "name": "Faction %d" % n, "camp": "enemy", "color": PALETTE[(n - 1) % PALETTE.size()]}
	_change("Ajouter une faction", func() -> void: ed.doc.factions.list.append(f))


## Objets, vagues et déclencheurs qui utilisent une faction.
func uses(id: String) -> int:
	var n := ed.doc.entities.filter(func(e: Dictionary) -> bool: return str(e.get("faction", "")) == id).size()
	n += ed.doc.wave_plan.get("list", []).filter(func(w: Dictionary) -> bool: return str(w.get("faction", "")) == id).size()
	var txt := JSON.stringify(ed.doc.scenario)
	n += txt.count('"%s"' % id) if id.begins_with("f") else 0
	return n


func _delete(id: String, name: String) -> void:
	var n := uses(id)
	var fn := func() -> void:
		ed.doc.factions.list = ed.doc.factions.list.filter(func(f: Dictionary) -> bool: return str(f.id) != id)
		for k: String in ed.doc.factions.rel.keys():
			if k.split("|").has(id):
				ed.doc.factions.rel.erase(k)
		# Ce qui l'utilisait revient à la faction par défaut de son camp.
		for e: Dictionary in ed.doc.entities:
			if str(e.get("faction", "")) == id:
				e.erase("faction")
		for w: Dictionary in ed.doc.wave_plan.get("list", []):
			if str(w.get("faction", "")) == id:
				w.erase("faction")
	var go := func() -> void: _change("Supprimer une faction", fn)
	if n == 0:
		go.call()
		return
	ed._confirm("Supprimer « %s » ?" % name, "Cette faction est utilisée %d fois (objets, vagues ou déclencheurs). Les objets et vagues reviendront à la faction par défaut ; les déclencheurs qui la citent seront signalés par la validation." % n,
			"Supprimer", go, "Annuler", open)
