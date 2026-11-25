class_name MissionLibrary
extends RefCounted
## « Mes missions » : liste, duplication, renommage, suppression, import et export.
##
## Export : un fichier « pack » (.rtspack, JSON) qui contient une ou plusieurs missions et les
## images de décor qu'elles utilisent. On peut aussi importer un simple fichier de mission (.json).

const PACK_FORMAT := "rts-defense-pack"
const PACK_EXT := "rtspack"
const DECO_DIR_EDITOR := "res://assets/deco/"
const DECO_DIR_USER := "user://deco/"


## Dossier où ranger les décors importés.
static func deco_dir() -> String:
	return DECO_DIR_EDITOR if OS.has_feature("editor") else DECO_DIR_USER


## Chemin d'une image de décor ("" si introuvable).
static func deco_path(sprite: String) -> String:
	for dir in [DECO_DIR_EDITOR, DECO_DIR_USER]:
		var p: String = dir + sprite + ".png"
		if ResourceLoader.exists(p) or FileAccess.file_exists(p):
			return p
	return ""


## Résumé d'une mission enregistrée, pour la liste.
static func info(path: String) -> Dictionary:
	var md := MapData.load_from(path)
	var p: Dictionary = md.mission.get("params", {})
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if path.ends_with(".json") else null
	return {"path": path, "name": md.NAME, "type": str(md.mission.get("type", "waves")), "stars": int(p.get("stars", 2)),
			"players": str(p.get("players", "solo")), "preview": str(p.get("preview", "")),
			"version": int(raw.get("version", 1)) if raw is Dictionary else EditorDoc.VERSION,
			"modified": FileAccess.get_modified_time(path), "map": md}


static func list() -> Array:
	var out: Array = []
	for p in MapData.list_custom():
		out.append(info(p))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.modified) > int(b.modified))
	return out


## Chemin libre pour un nom de mission (ajoute -2, -3… si besoin).
static func free_path(name: String, except := "") -> String:
	var base := MapData.custom_dir() + MapData.slug(name)
	var p := base + ".json"
	var n := 2
	while FileAccess.file_exists(p) and p != except:
		p = "%s-%d.json" % [base, n]
		n += 1
	return p


static func free_name(name: String) -> String:
	var names := MapData.list_custom().map(func(p: String) -> String: return MapData.load_from(p).NAME)
	if not names.has(name):
		return name
	var n := 2
	while names.has("%s (%d)" % [name, n]):
		n += 1
	return "%s (%d)" % [name, n]


static func duplicate_mission(path: String) -> String:
	var md := MapData.load_from(path)
	md.NAME = free_name(md.NAME + " (copie)")
	var p := free_path(md.NAME)
	return p if md.save_to(p) == OK else ""


## Renomme la mission et son fichier. Renvoie le nouveau chemin ("" si échec).
static func rename(path: String, new_name: String) -> String:
	var md := MapData.load_from(path)
	md.NAME = new_name
	var p := free_path(new_name, path)
	if md.save_to(p) != OK:
		return ""
	if p != path:
		DirAccess.remove_absolute(path)
	return p


static func delete(path: String) -> bool:
	var g := ProjectSettings.globalize_path(path)
	if OS.move_to_trash(g) == OK:
		return true
	return DirAccess.remove_absolute(path) == OK


# --- Export ---------------------------------------------------------------------------------

## Images de décor utilisées par une mission.
static func decos_of(md: MapData) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in md.entities:
		if str(e.get("kind", "")) == "deco":
			var sp := str(e.get("sprite", ""))
			if sp != "" and not out.has(sp):
				out.append(sp)
	return out


static func pack(paths: Array) -> Dictionary:
	var missions: Array = []
	var decos := {}
	for p: String in paths:
		var md := MapData.load_from(p)
		missions.append(md.to_dict())
		for sp in decos_of(md):
			var dp := deco_path(sp)
			if dp != "" and not decos.has(sp):
				var bytes := FileAccess.get_file_as_bytes(dp)
				if bytes.is_empty() and ResourceLoader.exists(dp):
					var tex: Texture2D = load(dp)
					bytes = tex.get_image().save_png_to_buffer() if tex != null else PackedByteArray()
				if not bytes.is_empty():
					decos[sp] = Marshalls.raw_to_base64(bytes)
	return {"format": PACK_FORMAT, "version": EditorDoc.VERSION, "created": Time.get_datetime_string_from_system(false, true),
			"missions": missions, "decos": decos}


static func export_pack(paths: Array, dest: String) -> Error:
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(pack(paths)))
	return OK


# --- Import ---------------------------------------------------------------------------------

## Importe un pack (.rtspack) ou une mission (.json). Les missions de même nom sont gardées
## (la nouvelle reçoit « (2) »). Renvoie un rapport :
## {ok, missions: [noms], paths: [chemins], decos: n, missing: [décors introuvables], warnings: [...], error}
static func import_file(src: String) -> Dictionary:
	var rep := {"ok": false, "missions": [], "paths": [], "decos": 0, "missing": [], "warnings": [], "error": ""}
	var j := JSON.new()
	var raw: Variant = j.data if j.parse(FileAccess.get_file_as_string(src)) == OK else null
	if not raw is Dictionary:
		rep.error = "Fichier illisible (ce n'est pas une mission RTS Defense)."
		return rep
	var list: Array = []
	var decos: Dictionary = {}
	if str(raw.get("format", "")) == PACK_FORMAT:
		list = raw.get("missions", [])
		decos = raw.get("decos", {})
		if int(raw.get("version", 1)) > EditorDoc.VERSION:
			rep.warnings.append("Pack créé avec une version plus récente de l'éditeur (v%d, ici v%d) : certains réglages peuvent être ignorés." % [int(raw.version), EditorDoc.VERSION])
	elif raw.has("layout"):
		list = [raw]
	else:
		rep.error = "Format inconnu : ni un pack ni une mission."
		return rep
	# Décors fournis par le pack
	for sp: String in decos:
		if deco_path(sp) != "":
			continue
		var bytes := Marshalls.base64_to_raw(str(decos[sp]))
		var img := Image.new()
		if img.load_png_from_buffer(bytes) != OK:
			rep.warnings.append("Image de décor illisible : %s" % sp)
			continue
		DirAccess.make_dir_recursive_absolute(deco_dir())
		if img.save_png(deco_dir() + sp + ".png") == OK:
			rep.decos += 1
	# Missions
	for m: Dictionary in list:
		if not m.has("layout"):
			rep.warnings.append("Une mission sans carte a été ignorée.")
			continue
		var v := int(m.get("version", 1))
		if v > EditorDoc.VERSION:
			rep.warnings.append("« %s » vient d'une version plus récente (v%d)." % [m.get("name", "?"), v])
		var tmp := "user://editor/import_tmp.json"
		DirAccess.make_dir_recursive_absolute(tmp.get_base_dir())
		var f := FileAccess.open(tmp, FileAccess.WRITE)
		f.store_string(JSON.stringify(m))
		f.close()
		var md := MapData.load_from(tmp)
		DirAccess.remove_absolute(tmp)
		# Conversion des anciennes versions : passe par le document de l'éditeur.
		md = EditorDoc.from_map(md).to_map()
		md.NAME = free_name(str(m.get("name", "Mission importée")))
		var p := free_path(md.NAME)
		if md.save_to(p) != OK:
			rep.warnings.append("Impossible d'enregistrer « %s »." % md.NAME)
			continue
		rep.missions.append(md.NAME)
		rep.paths.append(p)
		for sp in decos_of(md):
			if deco_path(sp) == "" and not rep.missing.has(sp):
				rep.missing.append(sp)
	rep.ok = not rep.missions.is_empty()
	if not rep.ok and rep.error == "":
		rep.error = "Aucune mission à importer."
	return rep
