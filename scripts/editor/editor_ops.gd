class_name EditorOps
extends RefCounted
## Opérations de l'éditeur, sans interface (testables) : peinture, remplissage, objets,
## extraits (copier / couper / coller), rotation, symétrie.

## Lettres qui ne se dupliquent pas (une seule base par joueur).
const UNIQUE_CHARS := ["B", "b"]
## Objets uniques sur une carte.
const UNIQUE_KINDS := ["vip", "escortee"]


# --- Terrain ------------------------------------------------------------------------------

## Lettre obtenue en posant `ch` sur `cur` : routes et rails sur l'eau font des ponts.
static func merge_char(cur: String, ch: String) -> String:
	if ch == "=" and cur in ["~", "Y"]:
		return "H"
	if ch == "T" and cur in ["~", "H"]:
		return "Y"
	if ch == "~" and cur in ["=", "H"]:
		return "H"
	if ch == "~" and cur in ["T", "Y"]:
		return "Y"
	return ch


## Outil de peinture correspondant à une lettre (pipette) : un pont redonne sa route / ses rails.
static func tool_of_char(ch: String) -> String:
	return {"H": "=", "Y": "T"}.get(ch, ch)


static func can_paint(layers: EditorLayers, cur: String, ch: String) -> bool:
	if cur == ch:
		return false
	if not layers.char_editable(cur):
		return false
	if ch != "." and not layers.editable(EditorLayers.of_char(ch)):
		return false
	if cur in UNIQUE_CHARS and ch != ".":
		return false # on ne peint pas par-dessus une base (gomme exceptée)
	return true


## Pinceau carré de côté 2 × brush − 1 centré sur c. Les bases se posent en 3x3.
static func paint(doc: EditorDoc, layers: EditorLayers, c: Vector2i, ch: String, brush := 1) -> void:
	if ch in UNIQUE_CHARS:
		stamp_base(doc, layers, c, ch)
		return
	var r := brush - 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cc := c + Vector2i(dx, dy)
			if not doc.inside(cc):
				continue
			var cur := doc.get_char(cc)
			var out := merge_char(cur, ch)
			if can_paint(layers, cur, out if ch != "." else "."):
				doc.set_char(cc, out)


static func stamp_base(doc: EditorDoc, layers: EditorLayers, center: Vector2i, ch: String) -> void:
	if not layers.editable("bases") or doc.width() < 3 or doc.height() < 3:
		return
	var cx := clampi(center.x, 1, doc.width() - 2)
	var cy := clampi(center.y, 1, doc.height() - 2)
	for y in doc.height():
		doc.rows[y] = doc.rows[y].replace(ch, ".")
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			doc.set_char(Vector2i(cx + dx, cy + dy), ch)


## Trace une ligne de peinture (un glissé rapide ne laisse pas de trous).
static func paint_line(doc: EditorDoc, layers: EditorLayers, a: Vector2i, b: Vector2i, ch: String, brush := 1) -> void:
	if ch in UNIQUE_CHARS:
		stamp_base(doc, layers, b, ch)
		return
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxf(n, 1)
		paint(doc, layers, Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t))), ch, brush)


## Remplit la zone de même lettre (4 voisins) qui contient c. Renvoie le nombre de cases.
static func fill(doc: EditorDoc, layers: EditorLayers, c: Vector2i, ch: String) -> int:
	if not doc.inside(c) or ch in UNIQUE_CHARS:
		return 0
	var target := doc.get_char(c)
	if target in UNIQUE_CHARS or not can_paint(layers, target, merge_char(target, ch)):
		return 0
	var out := merge_char(target, ch)
	var seen := {c: true}
	var q: Array[Vector2i] = [c]
	var head := 0
	while head < q.size():
		var p := q[head]
		head += 1
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = p + d
			if doc.inside(n) and not seen.has(n) and doc.get_char(n) == target:
				seen[n] = true
				q.append(n)
	for p in q:
		doc.set_char(p, out)
	return q.size()


# --- Objets ---------------------------------------------------------------------------

## Réglages par défaut d'un objet posé.
const DEFAULT_OPTS := {"hold": false, "level": 1, "block": false, "rot": 0, "flip": false, "pause": 0.0, "ztime": 30.0, "zrad": 2.5}


static func apply_options(e: Dictionary, o: Dictionary) -> void:
	match str(e.kind):
		"enemy", "ally_unit":
			e.hold = o.get("hold", false)
		"ally_tower":
			e.level = o.get("level", 1)
		"deco":
			e.block = o.get("block", false)
			e.rot = o.get("rot", 0)
			e.flip = o.get("flip", false)
		"waypoint":
			e.pause = o.get("pause", 0.0)
		"zone":
			e.radius = o.get("zrad", 2.5)
			if e.get("role", "") == "capture":
				e.time = o.get("ztime", 30.0)


## Réglages lus sur un objet (pipette).
static func options_of(e: Dictionary) -> Dictionary:
	var o := DEFAULT_OPTS.duplicate()
	o.hold = e.get("hold", false)
	o.level = int(e.get("level", 1))
	o.block = e.get("block", false)
	o.rot = int(e.get("rot", 0))
	o.flip = e.get("flip", false)
	o.pause = float(e.get("pause", 0.0))
	o.ztime = float(e.get("time", 30.0))
	o.zrad = float(e.get("radius", 2.5))
	return o


## Nouvel objet (sans identifiant) pour un outil de la palette "genre:type".
static func make_entity(tool_id: String, c: Vector2i, opts: Dictionary) -> Dictionary:
	var parts := tool_id.split(":")
	var e := {"kind": parts[0], "cell": [c.x, c.y]}
	match parts[0]:
		"structure", "enemy", "ally_tower", "ally_unit", "vip", "defend", "building":
			e.type = parts[1]
		"zone":
			e.role = parts[1]
		"deco":
			e.sprite = parts[1]
		"door":
			e.len = 2
		"shield":
			e.radius = 4.0
		"terminal":
			e.time = 5.0
		"prisoners":
			e.count = 3
			e.unit = "soldier"
		"pickup":
			e.label = "Données"
	apply_options(e, opts)
	return e


## Pose un objet. Renvoie {"entity": …} ou {"error": "…"}.
## Le même objet déjà à cet endroit reçoit simplement les réglages.
static func place(doc: EditorDoc, layers: EditorLayers, tool_id: String, c: Vector2i, opts: Dictionary) -> Dictionary:
	if not doc.inside(c):
		return {"error": ""}
	var e := make_entity(tool_id, c, opts)
	if not layers.entity_editable(e):
		return {"error": "Calque « %s » masqué ou verrouillé" % _layer_name(EditorLayers.of_entity(e))}
	var same := doc.entity_at(c, func(x: Dictionary) -> bool: return EditorDoc.entity_tool(x) == tool_id)
	if not same.is_empty():
		apply_options(same, opts)
		return {"entity": same, "updated": true}
	for cc in EditorDoc.entity_cells(e):
		if not doc.inside(cc):
			return {"error": "Ne rentre pas dans la carte ici"}
	var covered := EditorDoc.entity_rect(e)
	var blockers := doc.entities.filter(func(x: Dictionary) -> bool:
		return EditorDoc.entity_rect(x).intersects(covered) and not layers.entity_editable(x))
	if not blockers.is_empty():
		return {"error": "Un objet d'un calque verrouillé occupe la place"}
	doc.remove_ids(doc.entities.filter(func(x: Dictionary) -> bool: return EditorDoc.entity_rect(x).intersects(covered)).map(
			func(x: Dictionary) -> int: return int(x.id)))
	if e.kind in UNIQUE_KINDS:
		doc.remove_ids(doc.entities.filter(func(x: Dictionary) -> bool: return x.kind == e.kind).map(
				func(x: Dictionary) -> int: return int(x.id)))
	if e.kind == "waypoint":
		e.order = doc.next_waypoint_order()
	doc.add_entity(e)
	if e.kind == "waypoint":
		doc.renumber_waypoints()
	return {"entity": e}


static func _layer_name(id: String) -> String:
	for l in EditorLayers.LIST:
		if l.id == id:
			return l.name
	return id


# --- Extraits : copier, couper, coller, pivoter, symétrie ---------------------------------

## Extrait : {"size": Vector2i, "chars": Array[String] ("?" = case non prise), "entities": [... cases relatives]}.
## Prend les lettres modifiables de `rect` (sauf le sol nu) et les objets `ids`.
static func extract(doc: EditorDoc, layers: EditorLayers, rect: Rect2i, ids: Array) -> Dictionary:
	var ents: Array = []
	var bounds := rect if rect.has_area() else Rect2i()
	for id in ids:
		var e := doc.entity_by_id(int(id))
		if e.is_empty():
			continue
		ents.append(e)
		bounds = EditorDoc.entity_rect(e) if not bounds.has_area() else bounds.merge(EditorDoc.entity_rect(e))
	if not bounds.has_area():
		return {}
	var chars: Array[String] = []
	for y in bounds.size.y:
		var line := ""
		for x in bounds.size.x:
			var c := bounds.position + Vector2i(x, y)
			var ch := doc.get_char(c)
			line += ch if rect.has_point(c) and ch != "." and ch != "" and layers.char_editable(ch) else "?"
		chars.append(line)
	var rel: Array = []
	for e: Dictionary in ents:
		var cp: Dictionary = e.duplicate(true)
		var cc := EditorDoc.cell_of(e) - bounds.position
		cp.cell = [cc.x, cc.y]
		rel.append(cp)
	return {"size": bounds.size, "origin": bounds.position, "chars": chars, "entities": rel}


## Retire du document ce qu'un extrait contient (couper / déplacer / supprimer).
static func clear(doc: EditorDoc, clip: Dictionary) -> void:
	if clip.is_empty():
		return
	var o: Vector2i = clip.origin
	for y in clip.size.y:
		for x in clip.size.x:
			if clip.chars[y][x] != "?":
				doc.set_char(o + Vector2i(x, y), ".")
	doc.remove_ids(clip.entities.map(func(e: Dictionary) -> int: return int(e.id)))


## Colle un extrait avec son coin haut-gauche en `at`. keep_ids = déplacement (mêmes objets),
## sinon copie (nouveaux objets, bases ignorées). Renvoie les identifiants des objets collés.
static func paste(doc: EditorDoc, layers: EditorLayers, clip: Dictionary, at: Vector2i, keep_ids: bool) -> Array[int]:
	var out: Array[int] = []
	if clip.is_empty():
		return out
	for y in clip.size.y:
		for x in clip.size.x:
			var ch: String = clip.chars[y][x]
			if ch == "?":
				continue
			var c := at + Vector2i(x, y)
			if not doc.inside(c):
				continue
			if ch in UNIQUE_CHARS:
				if not keep_ids or not layers.editable("bases"):
					continue
				doc.set_char(c, ch)
				continue
			var cur := doc.get_char(c)
			var merged := merge_char(cur, ch)
			if cur == merged or can_paint(layers, cur, merged):
				doc.set_char(c, merged)
	var wp_base := doc.next_waypoint_order()
	var ents: Array = clip.entities.duplicate(true)
	ents.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
	for src: Dictionary in ents:
		var e: Dictionary = src.duplicate(true)
		var c := at + Vector2i(int(e.cell[0]), int(e.cell[1]))
		e.cell = [c.x, c.y]
		if not layers.entity_editable(e):
			continue
		if not EditorDoc.entity_cells(e).all(func(cc: Vector2i) -> bool: return doc.inside(cc)):
			continue
		if not keep_ids and e.kind in UNIQUE_KINDS and doc.entities.any(func(x: Dictionary) -> bool: return x.kind == e.kind):
			continue
		var r := EditorDoc.entity_rect(e)
		doc.remove_ids(doc.entities.filter(func(x: Dictionary) -> bool:
			return EditorDoc.entity_rect(x).intersects(r) and layers.entity_editable(x)).map(func(x: Dictionary) -> int: return int(x.id)))
		if keep_ids:
			doc.entities.append(e)
		else:
			if e.kind == "waypoint":
				e.order = wp_base + int(e.get("order", 0))
			e.erase("id")
			e.erase("name")
			doc.add_entity(e)
		out.append(int(e.id))
	doc.renumber_waypoints()
	return out


## Quart de tour dans le sens des aiguilles d'une montre.
static func rotate_clip(clip: Dictionary) -> Dictionary:
	var w: int = clip.size.x
	var h: int = clip.size.y
	var chars: Array[String] = []
	for ny in w:
		var line := ""
		for nx in h:
			line += clip.chars[h - 1 - nx][ny]
		chars.append(line)
	var ents: Array = []
	for src: Dictionary in clip.entities:
		var e: Dictionary = src.duplicate(true)
		var r := EditorDoc.entity_rect(e)
		if e.kind == "deco":
			e.rot = (int(e.get("rot", 0)) + 1) % 4
		e.cell = [h - (r.position.y + r.size.y), r.position.x]
		ents.append(e)
	return {"size": Vector2i(h, w), "origin": clip.origin, "chars": chars, "entities": ents}


## Symétrie gauche-droite (horizontal) ou haut-bas.
static func mirror_clip(clip: Dictionary, horizontal: bool) -> Dictionary:
	var w: int = clip.size.x
	var h: int = clip.size.y
	var chars: Array[String] = []
	for y in h:
		var src: String = clip.chars[h - 1 - y] if not horizontal else clip.chars[y]
		chars.append(src.reverse() if horizontal else src)
	var ents: Array = []
	for s: Dictionary in clip.entities:
		var e: Dictionary = s.duplicate(true)
		var r := EditorDoc.entity_rect(e)
		if horizontal:
			e.cell = [w - (r.position.x + r.size.x), r.position.y]
		else:
			e.cell = [r.position.x, h - (r.position.y + r.size.y)]
		if e.kind == "deco":
			# miroir écran = rotation inverse + retournement de l'image
			var rot := int(e.get("rot", 0))
			e.rot = (4 - rot) % 4 if horizontal else (6 - rot) % 4
			e.flip = not e.get("flip", false)
		ents.append(e)
	return {"size": clip.size, "origin": clip.origin, "chars": chars, "entities": ents}
