class_name ScenarioDefs
extends RefCounted
## Catalogues du moteur de scénario : déclencheurs (QUAND), conditions (SI), actions (ALORS),
## types d'objectifs et objectifs prédéfinis. Partagés par le jeu et l'éditeur.
##
## Paramètre : [clé, type, libellé, défaut, (options pour "choice")]
## Types : obj (n'importe quel objet), obj_enemy, obj_player, zone, objs, zones, int, float, text,
##   bool, choice, team, who, cmp, var, value, objective, objectives, trigger, timer, sound,
##   unit_type, enemy_type, build_type, behavior, res

const WHO := [["player", "Unités du joueur"], ["enemy", "Ennemis"], ["vip", "Le VIP"], ["obj", "Un objet précis"]]
const TEAM := [["player", "Joueur"], ["enemy", "Ennemis"]]
const CMP := [[">=", "≥"], [">", ">"], ["==", "="], ["!=", "≠"], ["<", "<"], ["<=", "≤"]]
const RES := [["metal", "Métal"], ["essence", "Essence"]]
const OBJ_STATES := [["done", "Activé / terminé"], ["open", "Ouvert"], ["freed", "Libérés"], ["taken", "Ramassé"], ["active", "Bouclier actif"]]
const OBJECTIVE_STATES := [["done", "Réussi"], ["failed", "Échoué"], ["active", "En cours"], ["hidden", "Caché"]]
const VAR_TYPES := [["int", "Entier"], ["float", "Décimal"], ["bool", "Booléen"], ["text", "Texte"], ["ref", "Référence à un objet"]]
const ENEMY_BEHAVIORS := [["march", "Marche sur la base"], ["guard", "Garde son poste"], ["static", "Immobile"], ["aggressive", "Attaque à vue"],
		["attack_target", "Attaque une cible"], ["attack_zone", "Attaque une zone"], ["defend", "Défend une structure"], ["follow", "Suit une unité"],
		["patrol", "Patrouille"], ["wait", "Attend un événement"]]

# --- QUAND ------------------------------------------------------------------------------------
const EVENTS := {
	"start": {"label": "Début de la mission", "cat": "Mission", "params": []},
	"time": {"label": "Temps écoulé", "cat": "Temps", "params": [["seconds", "float", "Après (s)", 30.0]]},
	"every": {"label": "Toutes les X secondes", "cat": "Temps", "params": [["seconds", "float", "Période (s)", 30.0]]},
	"timer_end": {"label": "Chrono terminé", "cat": "Temps", "params": [["timer", "timer", "Chrono", "chrono"]]},
	"killed": {"label": "Unité ou structure détruite", "cat": "Combat", "params": [["who", "who", "Qui", "enemy"], ["obj", "obj", "Objet", -1]]},
	"created": {"label": "Unité créée", "cat": "Combat", "params": [["team", "team", "Camp", "player"]]},
	"spotted": {"label": "Objet repéré par le joueur", "cat": "Combat", "params": [["obj", "obj", "Objet", -1], ["radius", "float", "Distance (cases)", 6.0]]},
	"enter_zone": {"label": "Unité entrant dans une zone", "cat": "Zones", "params": [["zone", "zone", "Zone", -1], ["who", "who", "Qui", "player"], ["obj", "obj", "Objet", -1]]},
	"leave_zone": {"label": "Unité quittant une zone", "cat": "Zones", "params": [["zone", "zone", "Zone", -1], ["who", "who", "Qui", "player"], ["obj", "obj", "Objet", -1]]},
	"zone_captured": {"label": "Zone contrôlée par le joueur", "cat": "Zones", "params": [["zone", "zone", "Zone", -1]]},
	"zone_lost": {"label": "Zone perdue", "cat": "Zones", "params": [["zone", "zone", "Zone", -1]]},
	"building_destroyed": {"label": "Bâtiment du joueur détruit", "cat": "Bâtiments", "params": [["obj", "obj_player", "Bâtiment (vide = n'importe lequel)", -1]]},
	"building_built": {"label": "Bâtiment construit", "cat": "Bâtiments", "params": [["kind", "choice", "Type", "any", [["any", "N'importe lequel"], ["tower", "Une tourelle"], ["building", "Un bâtiment"]]]]},
	"convoy_arrived": {"label": "Convoi allié arrivé", "cat": "Convois", "params": []},
	"convoy_destroyed": {"label": "Convoi détruit", "cat": "Convois", "params": []},
	"vip_arrived": {"label": "VIP arrivé dans une zone", "cat": "Convois", "params": [["zone", "zone", "Zone", -1]]},
	"vip_killed": {"label": "VIP éliminé", "cat": "Convois", "params": []},
	"wave_started": {"label": "Vague commencée", "cat": "Vagues", "params": [["n", "int", "Numéro (0 = toutes)", 0]]},
	"wave_ended": {"label": "Vague terminée", "cat": "Vagues", "params": [["n", "int", "Numéro (0 = toutes)", 0]]},
	"boss_spawned": {"label": "Boss apparu", "cat": "Vagues", "params": []},
	"boss_killed": {"label": "Boss éliminé", "cat": "Vagues", "params": []},
	"objective_started": {"label": "Objectif commencé", "cat": "Objectifs", "params": [["objective", "objective", "Objectif", ""]]},
	"objective_done": {"label": "Objectif réussi", "cat": "Objectifs", "params": [["objective", "objective", "Objectif", ""]]},
	"objective_failed": {"label": "Objectif échoué", "cat": "Objectifs", "params": [["objective", "objective", "Objectif", ""]]},
	"interaction": {"label": "Interaction effectuée", "cat": "Objets", "params": [["obj", "obj", "Objet interactif (vide = n'importe lequel)", -1]]},
	"base_destroyed": {"label": "Base du joueur détruite", "cat": "Mission", "params": []},
	"var_changed": {"label": "Variable modifiée", "cat": "Variables", "params": [["var", "var", "Variable", ""]]},
}

# --- SI -----------------------------------------------------------------------------------------
const CONDITIONS := {
	"alive": {"label": "Objet en vie", "params": [["obj", "obj", "Objet", -1]]},
	"dead": {"label": "Objet détruit", "params": [["obj", "obj", "Objet", -1]]},
	"in_zone": {"label": "Unités dans une zone", "params": [["zone", "zone", "Zone", -1], ["who", "who", "Qui", "player"], ["obj", "obj", "Objet", -1], ["cmp", "cmp", "Nombre", ">="], ["value", "value", "", 1]]},
	"zone_control": {"label": "Zone contrôlée par le joueur", "params": [["zone", "zone", "Zone", -1]]},
	"objective": {"label": "État d'un objectif", "params": [["objective", "objective", "Objectif", ""], ["state", "choice", "État", "done", OBJECTIVE_STATES]]},
	"time": {"label": "Temps de jeu", "params": [["cmp", "cmp", "Comparaison", ">="], ["value", "value", "Secondes", 60]]},
	"var": {"label": "Variable", "params": [["var", "var", "Variable", ""], ["cmp", "cmp", "Comparaison", "=="], ["value", "value", "Valeur", 0]]},
	"count": {"label": "Nombre d'unités", "params": [["team", "team", "Camp", "enemy"], ["zone", "zone", "Zone (vide = toute la carte)", -1], ["cmp", "cmp", "Comparaison", "<="], ["value", "value", "Nombre", 0]]},
	"team_eliminated": {"label": "Camp éliminé", "params": [["team", "team", "Camp", "enemy"]]},
	"obj_state": {"label": "État d'un objet interactif", "params": [["obj", "obj", "Objet", -1], ["state", "choice", "État", "done", OBJ_STATES]]},
	"resources": {"label": "Ressources du joueur", "params": [["res", "res", "Ressource", "metal"], ["cmp", "cmp", "Comparaison", ">="], ["value", "value", "Quantité", 500]]},
	"wave": {"label": "Numéro de vague", "params": [["cmp", "cmp", "Comparaison", ">="], ["value", "value", "Vague", 3]]},
	"players": {"label": "Nombre de joueurs", "params": [["cmp", "cmp", "Comparaison", "=="], ["value", "value", "Joueurs", 2]]},
	"random": {"label": "Hasard", "params": [["percent", "float", "Chance (%)", 50.0]]},
}

# --- ALORS --------------------------------------------------------------------------------------
const ACTIONS := {
	"spawn": {"label": "Créer des unités", "cat": "Unités", "params": [["team", "team", "Camp", "enemy"], ["enemy_type", "enemy_type", "Type ennemi", "normal"],
			["unit_type", "unit_type", "Type allié", "soldier"], ["count", "int", "Nombre", 3], ["zone", "zone", "Dans la zone", -1], ["behavior", "behavior", "Comportement", "march"]]},
	"activate": {"label": "Faire apparaître / réveiller", "cat": "Unités", "params": [["obj", "obj", "Objet", -1]]},
	"remove": {"label": "Retirer un objet", "cat": "Unités", "params": [["obj", "obj", "Objet", -1]]},
	"move": {"label": "Envoyer vers une zone", "cat": "Unités", "params": [["obj", "obj", "Objet", -1], ["zone", "zone", "Zone", -1]]},
	"heal": {"label": "Soigner / réparer", "cat": "Unités", "params": [["obj", "obj", "Objet", -1]]},
	"immobilize": {"label": "Immobiliser", "cat": "Unités", "params": [["obj", "obj", "Objet", -1], ["on", "bool", "Immobile", true]]},
	"build": {"label": "Créer un bâtiment allié", "cat": "Bâtiments", "params": [["build_type", "build_type", "Bâtiment", "gun"], ["zone", "zone", "Au centre de la zone", -1]]},
	"destroy": {"label": "Détruire un objet", "cat": "Bâtiments", "params": [["obj", "obj", "Objet", -1]]},
	"behavior": {"label": "Changer le comportement", "cat": "Comportements", "params": [["obj", "obj_enemy", "Ennemi", -1], ["behavior", "behavior", "Comportement", "aggressive"], ["target", "obj", "Cible / zone", -1]]},
	"wave_launch": {"label": "Lancer la vague suivante", "cat": "Vagues", "params": []},
	"wave_pause": {"label": "Suspendre les vagues", "cat": "Vagues", "params": []},
	"wave_resume": {"label": "Reprendre les vagues", "cat": "Vagues", "params": []},
	"wave_interval": {"label": "Changer l'intervalle des vagues", "cat": "Vagues", "params": [["seconds", "float", "Secondes", 20.0]]},
	"give": {"label": "Donner des ressources", "cat": "Ressources", "params": [["res", "res", "Ressource", "metal"], ["amount", "int", "Quantité (négatif = retirer)", 200]]},
	"obj_reveal": {"label": "Révéler un objectif", "cat": "Objectifs", "params": [["objective", "objective", "Objectif", ""]]},
	"obj_hide": {"label": "Masquer un objectif", "cat": "Objectifs", "params": [["objective", "objective", "Objectif", ""]]},
	"obj_complete": {"label": "Réussir un objectif", "cat": "Objectifs", "params": [["objective", "objective", "Objectif", ""]]},
	"obj_fail": {"label": "Faire échouer un objectif", "cat": "Objectifs", "params": [["objective", "objective", "Objectif", ""]]},
	"door_open": {"label": "Ouvrir une porte", "cat": "Carte", "params": [["obj", "obj", "Porte", -1]]},
	"door_close": {"label": "Fermer une porte", "cat": "Carte", "params": [["obj", "obj", "Porte", -1]]},
	"message": {"label": "Message", "cat": "Interface", "params": [["speaker", "text", "Qui parle", "QG"], ["text", "text", "Texte", ""], ["seconds", "float", "Durée (s)", 6.0]]},
	"alert": {"label": "Alerte (bandeau)", "cat": "Interface", "params": [["text", "text", "Texte", ""]]},
	"notify": {"label": "Notification courte", "cat": "Interface", "params": [["text", "text", "Texte", ""]]},
	"marker": {"label": "Marqueur sur la carte", "cat": "Interface", "params": [["obj", "obj", "Objet ou zone", -1], ["text", "text", "Libellé", ""], ["seconds", "float", "Durée (s, 0 = jusqu'à retrait)", 10.0]]},
	"marker_clear": {"label": "Retirer les marqueurs", "cat": "Interface", "params": []},
	"sound": {"label": "Jouer un son", "cat": "Audio", "params": [["sound", "sound", "Son", "wave"]]},
	"timer_start": {"label": "Démarrer un chrono", "cat": "Temps", "params": [["timer", "timer", "Nom", "chrono"], ["seconds", "float", "Durée (s)", 60.0], ["label", "text", "Libellé affiché", "Renforts dans"], ["show", "bool", "Afficher", true]]},
	"timer_stop": {"label": "Arrêter un chrono", "cat": "Temps", "params": [["timer", "timer", "Nom", "chrono"]]},
	"timer_add": {"label": "Ajouter du temps à un chrono", "cat": "Temps", "params": [["timer", "timer", "Nom", "chrono"], ["seconds", "float", "Secondes (négatif = retirer)", 10.0]]},
	"var_set": {"label": "Fixer une variable", "cat": "Variables", "params": [["var", "var", "Variable", ""], ["value", "value", "Valeur", 0]]},
	"var_add": {"label": "Ajouter à une variable", "cat": "Variables", "params": [["var", "var", "Variable", ""], ["value", "value", "Valeur (négatif = retirer)", 1]]},
	"var_reset": {"label": "Réinitialiser une variable", "cat": "Variables", "params": [["var", "var", "Variable", ""]]},
	"wait": {"label": "Attendre", "cat": "Flux", "params": [["seconds", "float", "Secondes", 3.0]]},
	"trigger_enable": {"label": "Activer / désactiver un déclencheur", "cat": "Flux", "params": [["trigger", "trigger", "Déclencheur", ""], ["on", "bool", "Actif", true]]},
	"trigger_run": {"label": "Exécuter un déclencheur", "cat": "Flux", "params": [["trigger", "trigger", "Déclencheur", ""]]},
	"victory": {"label": "Victoire", "cat": "Mission", "params": [["text", "text", "Message", ""]]},
	"defeat": {"label": "Défaite", "cat": "Mission", "params": [["text", "text", "Message", ""]]},
}

# --- Objectifs ----------------------------------------------------------------------------------
## Types que le moteur sait suivre. Chaque objectif prédéfini en est un réglage.
const OBJECTIVE_TYPES := {
	"destroy": {"label": "Détruire", "params": [["what", "choice", "Quoi", "targets", [["targets", "Les objets choisis"], ["all_enemies", "Tous les ennemis"], ["structures", "Toutes les structures ennemies"], ["bases", "Toutes les bases ennemies"], ["boss", "Le boss"]]],
			["targets", "objs", "Objets", []], ["count", "int", "Nombre requis (0 = tous)", 0]]},
	"protect": {"label": "Défendre", "params": [["targets", "objs", "À protéger (vide = la base et les bâtiments à défendre)", []], ["time", "float", "Pendant (s, 0 = jusqu'à la fin)", 0.0]]},
	"survive_time": {"label": "Survivre une durée", "params": [["time", "float", "Durée (s, 0 = réglage de l'onglet Mission)", 300.0]]},
	"survive_waves": {"label": "Survivre à des vagues", "params": [["waves", "int", "Vagues (0 = toutes)", 0]]},
	"hold": {"label": "Tenir une position", "params": [["zone", "zone", "Zone", -1], ["time", "float", "Pendant (s)", 60.0]]},
	"prevent": {"label": "Empêcher d'atteindre une zone", "params": [["zone", "zone", "Zone", -1], ["max", "int", "Ennemis tolérés", 0], ["time", "float", "Pendant (s, 0 = jusqu'à la fin)", 0.0]]},
	"reach": {"label": "Atteindre une zone", "params": [["zone", "zone", "Zone", -1], ["who", "who", "Qui", "player"], ["obj", "obj", "Objet", -1], ["count", "int", "Unités requises", 1], ["extract", "bool", "Retirer les unités arrivées (extraction)", false]]},
	"escort": {"label": "Escorter jusqu'à une zone", "params": [["obj", "obj", "Unité escortée (vide = le VIP)", -1], ["zone", "zone", "Destination (vide = zone d'arrivée)", -1]]},
	"convoys": {"label": "Convois alliés arrivés", "params": [["count", "int", "Convois requis (0 = réglage de l'onglet Mission)", 1]]},
	"convoys_destroyed": {"label": "Convois ennemis détruits", "params": [["count", "int", "Convois requis (0 = réglage de l'onglet Mission)", 1]]},
	"route": {"label": "Suivre un itinéraire", "params": [["zones", "zones", "Zones dans l'ordre", []], ["who", "who", "Qui", "player"], ["obj", "obj", "Objet", -1]]},
	"capture": {"label": "Capturer des zones", "params": [["zones", "zones", "Zones (vide = zones de prise)", []], ["need", "int", "Zones requises (0 = toutes)", 0], ["time", "float", "Temps de capture (s, 0 = durée de chaque zone)", 10.0], ["obj", "obj", "Avec cette unité (vide = n'importe laquelle)", -1]]},
	"control": {"label": "Contrôler des secteurs ensemble", "params": [["zones", "zones", "Zones", []], ["time", "float", "Pendant (s)", 30.0]]},
	"interact": {"label": "Interagir avec des objets", "params": [["targets", "objs", "Objets (terminal, prisonniers, objet…)", []], ["count", "int", "Nombre requis (0 = tous)", 0]]},
	"collect": {"label": "Récupérer des objets", "params": [["count", "int", "Objets requis", 1]]},
	"condition": {"label": "Condition personnalisée", "params": [["cond", "cond", "Condition", {}]]},
	"compound": {"label": "Combinaison d'objectifs", "params": [["children", "objectives", "Objectifs", []], ["mode", "choice", "Règle", "all", [["all", "Tous (ET)"], ["any", "Un seul suffit (OU)"], ["atleast", "Au moins X"], ["none", "Aucun (NON)"]]], ["n", "int", "X", 1]]},
}

## Bibliothèque du cahier des charges (§4.1 à 4.4) : chaque entrée pré-remplit un type.
const PRESETS := [
	["Militaire", "Détruire une unité", "destroy", {"what": "targets", "count": 1}],
	["Militaire", "Détruire plusieurs unités", "destroy", {"what": "targets", "count": 0}],
	["Militaire", "Détruire une structure", "destroy", {"what": "targets", "count": 1}],
	["Militaire", "Détruire toutes les bases ennemies", "destroy", {"what": "bases"}],
	["Militaire", "Éliminer toutes les unités ennemies", "destroy", {"what": "all_enemies"}],
	["Militaire", "Défendre la base", "protect", {}],
	["Militaire", "Défendre un bâtiment", "protect", {}],
	["Militaire", "Défendre une position", "hold", {"time": 120.0}],
	["Militaire", "Survivre pendant une durée", "survive_time", {"time": 300.0}],
	["Militaire", "Survivre à un nombre de vagues", "survive_waves", {"waves": 5}],
	["Militaire", "Empêcher un ennemi d'atteindre une zone", "prevent", {}],
	["Militaire", "Éliminer un boss", "destroy", {"what": "boss"}],
	["Déplacement", "Atteindre une zone", "reach", {}],
	["Déplacement", "Amener une unité à destination", "reach", {"who": "obj"}],
	["Déplacement", "Escorter un VIP", "escort", {}],
	["Déplacement", "Escorter un convoi", "convoys", {"count": 1}],
	["Déplacement", "Protéger plusieurs convois", "convoys", {"count": 3}],
	["Déplacement", "Faire arriver plusieurs unités", "reach", {"count": 5}],
	["Déplacement", "Suivre un itinéraire", "route", {}],
	["Déplacement", "Atteindre plusieurs points de passage", "route", {}],
	["Déplacement", "Extraire une unité", "reach", {"who": "obj", "extract": true}],
	["Déplacement", "Faire traverser la carte", "reach", {"count": 3, "extract": true}],
	["Capture", "Capturer une zone", "capture", {"need": 1}],
	["Capture", "Capturer plusieurs zones", "capture", {"need": 0}],
	["Capture", "Capturer X zones parmi Y", "capture", {"need": 2}],
	["Capture", "Maintenir une zone pendant une durée", "hold", {"time": 60.0}],
	["Capture", "Capturer une zone avec une unité précise", "capture", {"need": 1}],
	["Capture", "Contrôler plusieurs secteurs simultanément", "control", {}],
	["Capture", "Défendre une zone capturée", "hold", {"time": 90.0}],
	["Interaction", "Activer un terminal", "interact", {"count": 1}],
	["Interaction", "Détruire un générateur", "destroy", {"what": "targets", "count": 1}],
	["Interaction", "Désactiver un bouclier", "destroy", {"what": "targets", "count": 1}],
	["Interaction", "Ouvrir une porte", "interact", {"count": 1}],
	["Interaction", "Débloquer un passage", "interact", {"count": 1}],
	["Interaction", "Récupérer un objet", "collect", {"count": 1}],
	["Interaction", "Libérer des prisonniers", "interact", {"count": 1}],
	["Interaction", "Activer plusieurs mécanismes", "interact", {"count": 0}],
	["Interaction", "Interagir avec un personnage", "reach", {"who": "player"}],
	["Avancé", "Condition personnalisée", "condition", {}],
	["Avancé", "Combinaison d'objectifs (ET, OU, X sur Y, NON)", "compound", {}],
]


static func defaults(params: Array) -> Dictionary:
	var d := {}
	for p in params:
		var v: Variant = p[3]
		d[p[0]] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	return d


static func new_objective(preset: Array, id: String) -> Dictionary:
	var t: String = preset[2]
	var o := {"id": id, "name": preset[1], "desc": "", "kind": "main", "start": "visible", "after": [], "type": t,
			"deadline": 0.0, "fail_dead": [], "reward": {"metal": 0, "essence": 0}}
	o.merge(defaults(OBJECTIVE_TYPES[t].params))
	for k in preset[3]:
		o[k] = preset[3][k]
	return o


static func new_trigger(id: String) -> Dictionary:
	return {"id": id, "name": "Nouveau déclencheur", "enabled": true, "once": true, "priority": 0, "delay": 0.0,
			"event": {"type": "start"}, "cond": {"op": "and", "items": []}, "actions": [], "else": []}


static func new_item(defs: Dictionary, type: String) -> Dictionary:
	var it := {"type": type}
	it.merge(defaults(defs[type].params))
	return it


static func compare(a: Variant, cmp: String, b: Variant) -> bool:
	if (a is int or a is float or a is bool) and (b is int or b is float or b is bool):
		var x := float(a)
		var y := float(b)
		if cmp == ">":
			return x > y
		if cmp == ">=":
			return x >= y
		if cmp == "<":
			return x < y
		if cmp == "<=":
			return x <= y
		if cmp == "!=":
			return not is_equal_approx(x, y)
		return is_equal_approx(x, y)
	if cmp == "!=":
		return str(a) != str(b)
	return str(a) == str(b)
