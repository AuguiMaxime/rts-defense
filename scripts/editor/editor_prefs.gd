class_name EditorPrefs
extends RefCounted
## Préférences de l'éditeur, gardées d'une session à l'autre (user://editor/prefs.json) :
## favoris et objets récents du catalogue, raccourcis clavier, dernier état de l'éditeur.

const PATH := "user://editor/prefs.json"

static var _data: Dictionary = {}
static var _loaded := false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_data = raw if raw is Dictionary else {}
	return _data


static func get_v(key: String, default: Variant = null) -> Variant:
	return data().get(key, default)


static func set_v(key: String, v: Variant) -> void:
	data()[key] = v
	save()


static func save() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data(), "\t"))
