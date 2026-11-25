class_name EditorShortcuts
extends RefCounted
## Raccourcis clavier de l'éditeur, modifiables (Fichier → Raccourcis clavier, F1).
## Les touches choisies sont gardées dans les préférences.

## [action, libellé, touche par défaut]
const ACTIONS := [
	["undo", "Annuler", "Ctrl+Z"], ["redo", "Rétablir", "Ctrl+Y"],
	["copy", "Copier", "Ctrl+C"], ["cut", "Couper", "Ctrl+X"], ["paste", "Coller", "Ctrl+V"],
	["duplicate", "Dupliquer", "Ctrl+D"], ["select_all", "Tout sélectionner", "Ctrl+A"], ["delete", "Supprimer la sélection", "Delete"],
	["save", "Enregistrer", "Ctrl+S"], ["missions", "Mes missions", "Ctrl+O"], ["test", "Tester", "F5"], ["validate", "Valider", "F6"],
	["help", "Raccourcis clavier", "F1"], ["fit", "Cadrer la carte", "Ctrl+0"],
	["tab_map", "Onglet Carte", "1"], ["tab_objects", "Onglet Objets", "2"], ["tab_objectives", "Onglet Objectifs", "3"],
	["tab_events", "Onglet Événements", "4"], ["tab_waves", "Onglet Vagues", "5"], ["tab_mission", "Onglet Mission", "6"],
	["tool_select", "Outil sélection", "V"], ["tool_paint", "Pinceau", "B"], ["tool_fill", "Remplissage", "F"],
	["tool_pipette", "Pipette", "I"], ["tool_place", "Poser un objet", "P"], ["tool_erase", "Gomme", "E"],
	["grid", "Grille", "G"], ["rotate", "Pivoter", "R"], ["mirror", "Miroir gauche-droite", "M"], ["mirror_v", "Miroir haut-bas", "Shift+M"],
	["brush_minus", "Pinceau plus petit", "BracketLeft"], ["brush_plus", "Pinceau plus grand", "BracketRight"],
	["paths", "Voir les passages", "H"],
]


## Touche actuelle de chaque action.
static func keys() -> Dictionary:
	var custom: Dictionary = EditorPrefs.get_v("keys", {})
	var out := {}
	for a in ACTIONS:
		out[a[0]] = str(custom.get(a[0], a[2]))
	return out


static func label_of(id: String) -> String:
	for a in ACTIONS:
		if a[0] == id:
			return a[1]
	return id


## Texte d'une touche avec ses modificateurs (« Ctrl+Shift+Z »).
static func event_string(k: InputEventKey) -> String:
	var parts: Array[String] = []
	if k.ctrl_pressed or k.meta_pressed:
		parts.append("Ctrl")
	if k.shift_pressed:
		parts.append("Shift")
	if k.alt_pressed:
		parts.append("Alt")
	parts.append(OS.get_keycode_string(k.keycode))
	return "+".join(parts)


## Texte lisible pour l'affichage (« Suppr », « [ »…).
static func pretty(s: String) -> String:
	return s.replace("Delete", "Suppr").replace("BracketLeft", "[").replace("BracketRight", "]").replace("Shift", "Maj")


static func action_for(k: InputEventKey) -> String:
	var s := event_string(k)
	var map := keys()
	for id in map:
		if map[id] == s:
			return id
	return ""


## Change la touche d'une action. Si une autre action l'utilisait, elle perd sa touche
## (renvoie son identifiant, ou "").
static func bind(id: String, s: String) -> String:
	var custom: Dictionary = EditorPrefs.get_v("keys", {}).duplicate()
	var map := keys()
	var stolen := ""
	for other in map:
		if other != id and map[other] == s:
			custom[other] = ""
			stolen = other
	custom[id] = s
	EditorPrefs.set_v("keys", custom)
	return stolen


static func reset() -> void:
	EditorPrefs.set_v("keys", {})
