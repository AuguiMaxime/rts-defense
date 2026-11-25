class_name MissionPreview
extends RefCounted
## Image d'aperçu d'une mission, rangée dans le fichier de la mission (PNG en base64,
## `mission.params.preview`) : un seul fichier à partager.

const MAX_SIZE := Vector2i(360, 225)
const PX := 6 # pixels par case pour l'aperçu généré
const GROUND := {"grass": Color("1f4d2b"), "sand": Color("6b5236"), "dirt": Color("4a3a34"), "mars": Color("9a5238"), "metal": Color("3a4250")}
const CYAN := Color("22d3ee")
const GOLD := Color("fbbf24")
const METAL := Color("9ec5ff")
const ESSENCE := Color("ffa63d")
const RED := Color("f87171")


## Aperçu généré depuis la carte : terrain, base, gisements, apparitions et objets posés.
static func render(doc: EditorDoc) -> Image:
	var g := MapLoader.from_layout("\n".join(doc.rows))
	var img := Image.create(g.width * PX, g.height * PX, false, Image.FORMAT_RGB8)
	img.fill(GROUND.get(doc.ground, Color("1f4d2b")))
	for y in g.height:
		for x in g.width:
			var col := Color(0, 0, 0, 0)
			match g.get_cell(Vector2i(x, y)):
				GameGrid.Cell.ROCK:
					col = Color("8a8f98")
				GameGrid.Cell.BASE:
					col = CYAN
				GameGrid.Cell.METAL:
					col = METAL
				GameGrid.Cell.ESSENCE:
					col = ESSENCE
				GameGrid.Cell.SPAWN:
					col = RED
				GameGrid.Cell.WALL:
					col = Color("5a6270")
				GameGrid.Cell.WATER:
					col = Color("1e6fa8")
				GameGrid.Cell.ROAD, GameGrid.Cell.BRIDGE:
					col = Color("2e3238")
				GameGrid.Cell.RAIL, GameGrid.Cell.RAIL_BRIDGE:
					col = Color("6b5a48")
			if col.a > 0:
				img.fill_rect(Rect2i(x * PX, y * PX, PX, PX), col)
	for c in g.base2_cells:
		img.fill_rect(Rect2i(c.x * PX, c.y * PX, PX, PX), GOLD)
	for e: Dictionary in doc.entities:
		var c := Vector2i(int(e.cell[0]), int(e.cell[1]))
		var sz := EditorDoc.entity_size(e)
		var col: Variant = null
		match str(e.kind):
			"structure":
				col = Color("ff5a4e")
			"enemy":
				col = Color("ff8a7a")
			"ally_tower", "ally_unit", "building", "escortee":
				col = Color("5ee08a")
			"defend", "vip":
				col = GOLD
			"zone":
				var r := Rect2i(c * PX, sz * PX)
				var zc := Color(1, 1, 1, 1)
				for i in r.size.x:
					img.set_pixel(r.position.x + i, r.position.y, zc)
					img.set_pixel(r.position.x + i, mini(r.end.y - 1, img.get_height() - 1), zc)
				for j in r.size.y:
					img.set_pixel(r.position.x, r.position.y + j, zc)
					img.set_pixel(mini(r.end.x - 1, img.get_width() - 1), r.position.y + j, zc)
		if col != null:
			var pad := 1 if sz == Vector2i.ONE else 0
			img.fill_rect(Rect2i(c * PX + Vector2i(pad, pad), sz * PX - Vector2i(pad * 2, pad * 2)), col)
	return _fit(img)


static func _fit(img: Image) -> Image:
	var k := minf(float(MAX_SIZE.x) / img.get_width(), float(MAX_SIZE.y) / img.get_height())
	if k < 1.0:
		img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
	return img


static func encode(img: Image) -> String:
	return Marshalls.raw_to_base64(img.save_png_to_buffer())


## Image choisie sur le disque, réduite. "" si illisible.
static func from_file(path: String) -> String:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return ""
	img.convert(Image.FORMAT_RGB8)
	return encode(_fit(img))


static func texture(b64: String) -> Texture2D:
	if b64 == "":
		return null
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) != OK:
		return null
	return ImageTexture.create_from_image(img)
