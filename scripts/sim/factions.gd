class_name Factions
extends RefCounted
## Factions et relations.
##
## Chaque faction appartient à un camp :
## - camp « joueur » : les unités et bâtiments du joueur, ses alliés pilotés par l'ordinateur, les civils ;
## - camp « ennemi » : les aliens, leurs structures, les créatures neutres.
## Deux factions du même camp sont toujours alliées. Entre deux camps, la relation se règle par paire :
## ennemi (on se bat), neutre (on s'ignore) ou « hostile si attaqué » (neutre jusqu'à la première attaque
## du camp joueur). Un déclencheur peut changer une relation pendant la partie.

const BUILTIN := [
	{"id": "p1", "name": "Joueur 1", "camp": "player", "color": "38d8ff"},
	{"id": "p2", "name": "Joueur 2", "camp": "player", "color": "ffc24a"},
	{"id": "ally", "name": "Alliés IA", "camp": "player", "color": "5ee08a"},
	{"id": "civil", "name": "Civils", "camp": "player", "color": "d8dde6"},
	{"id": "enemy", "name": "Ennemis", "camp": "enemy", "color": "ff5a4e"},
	{"id": "neutral", "name": "Neutres", "camp": "enemy", "color": "b9a27a"},
]
const RELATIONS := [["enemy", "Ennemi"], ["neutral", "Neutre"], ["provoked", "Hostile si attaqué"]]
const CAMPS := [["player", "Camp du joueur"], ["enemy", "Camp ennemi"]]

var list: Array = [] # factions (intégrées puis personnalisées)
var rel := {} # "a|b" (camp joueur | camp ennemi) -> relation
var _camp := {}
var pending: Array = [] # changements de relation à signaler au scénario : [a, b, relation]
var provocable := false # au moins une relation « hostile si attaqué » (évite du travail à chaque tir)
var _cache := {}


func _init(data: Dictionary = {}) -> void:
	list = all(data)
	for f: Dictionary in list:
		_camp[str(f.id)] = str(f.camp)
	rel = data.get("rel", {}).duplicate()
	_refresh()


func _refresh() -> void:
	_cache.clear()
	provocable = false
	for p: Dictionary in list:
		for e: Dictionary in list:
			if p.camp == "player" and e.camp == "enemy" and relation(str(p.id), str(e.id)) == "provoked":
				provocable = true


## Toutes les factions d'une mission : intégrées puis personnalisées.
static func all(data: Dictionary) -> Array:
	var out: Array = BUILTIN.duplicate(true)
	for f: Dictionary in data.get("list", []):
		out.append(f)
	return out


## Relation par défaut entre une faction du camp joueur et une du camp ennemi.
static func default_rel(_p: String, e: String) -> String:
	return "neutral" if e == "neutral" else "enemy"


static func key(p: String, e: String) -> String:
	return p + "|" + e


func camp(f: String) -> String:
	return str(_camp.get(f, "enemy" if f == "" else "player"))


func color_of(f: String) -> Color:
	for x: Dictionary in list:
		if str(x.id) == f:
			return Color.from_string(str(x.get("color", "ffffff")), Color.WHITE)
	return Color.WHITE


func name_of(f: String) -> String:
	for x: Dictionary in list:
		if str(x.id) == f:
			return str(x.name)
	return f


## Relation entre deux factions : "ally" (même camp), "enemy", "neutral" ou "provoked".
func relation(a: String, b: String) -> String:
	var ca := camp(a)
	if ca == camp(b):
		return "ally"
	var p := a if ca == "player" else b
	var e := b if ca == "player" else a
	return str(rel.get(key(p, e), default_rel(p, e)))


func hostile(a: String, b: String) -> bool:
	var k := a + "|" + b
	var v: Variant = _cache.get(k)
	if v == null:
		v = relation(a, b) == "enemy"
		_cache[k] = v
	return v


func set_relation(a: String, b: String, v: String) -> void:
	if camp(a) == camp(b):
		return
	var p := a if camp(a) == "player" else b
	var e := b if camp(a) == "player" else a
	if relation(p, e) != v:
		rel[key(p, e)] = v
		pending.append([p, e, v])
		_refresh()


## Une unité d'une faction du camp ennemi est attaquée par une faction du camp joueur.
func provoke(victim: String, by := "p1") -> void:
	if camp(victim) == "enemy" and relation(by, victim) == "provoked":
		set_relation(by, victim, "enemy")


func ids(camp_filter := "") -> Array:
	var out := []
	for f: Dictionary in list:
		if camp_filter == "" or f.camp == camp_filter:
			out.append([str(f.id), str(f.name)])
	return out
