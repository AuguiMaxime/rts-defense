class_name EditorHistory
extends RefCounted
## Annuler / rétablir : chaque action enregistre l'état d'avant (100 actions au plus).
##   begin("Peindre")  … modifications …  commit()
## Une action qui ne change rien n'est pas enregistrée.

const LIMIT := 100

var doc: EditorDoc
var _undo: Array = [] # [{label, state}]
var _redo: Array = []
var _pending: Dictionary = {}
var _pending_label := ""
var _pending_key := ""
## Nombre d'actions depuis le dernier enregistrement (fichier ou sauvegarde auto).
var changes := 0


func _init(d: EditorDoc) -> void:
	doc = d


func is_open() -> bool:
	return not _pending.is_empty()


func begin(label: String) -> void:
	if is_open():
		return
	_pending = doc.snapshot()
	_pending_label = label
	_pending_key = JSON.stringify(_pending)


## Termine l'action ouverte. Renvoie true si quelque chose a changé.
func commit() -> bool:
	if not is_open():
		return false
	var before := _pending
	_pending = {}
	if JSON.stringify(doc.snapshot()) == _pending_key:
		return false
	_undo.append({"label": _pending_label, "state": before})
	if _undo.size() > LIMIT:
		_undo.pop_front()
	_redo.clear()
	changes += 1
	return true


## Annule l'action ouverte sans l'enregistrer (Échap pendant un déplacement…).
func cancel() -> void:
	if is_open():
		doc.restore(_pending)
		_pending = {}


## Raccourci : une action complète.
func record(label: String, change: Callable) -> bool:
	begin(label)
	change.call()
	return commit()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo_label() -> String:
	return _undo.back().label if can_undo() else ""


func redo_label() -> String:
	return _redo.back().label if can_redo() else ""


func undo() -> String:
	if not can_undo():
		return ""
	var a: Dictionary = _undo.pop_back()
	_redo.append({"label": a.label, "state": doc.snapshot()})
	doc.restore(a.state)
	changes += 1
	return a.label


func redo() -> String:
	if not can_redo():
		return ""
	var a: Dictionary = _redo.pop_back()
	_undo.append({"label": a.label, "state": doc.snapshot()})
	doc.restore(a.state)
	changes += 1
	return a.label


func clear() -> void:
	_undo.clear()
	_redo.clear()
	_pending = {}
	changes = 0
