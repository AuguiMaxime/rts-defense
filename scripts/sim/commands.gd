class_name Commands
extends RefCounted
## Ordres du joueur sous forme de messages, exécutés sur la simulation.
## En solo ils s'appliquent directement ; en coop ils partent chez l'hôte, qui les applique.
##
## Formats (clé "t" = type) :
##   move / harvest      {"w": [ids ouvriers], "c": Vector2i}
##   build / repair      {"w": [ids], "s": id chantier}
##   repair_auto         {"s": id}                       ouvriers les plus proches
##   place               {"k": type, "c": Vector2i, "w": [ids] (vide = le plus proche)}
##   upgrade / sell      {"s": id}
##   train / next_wave   {}
##   orbital             {"p": Vector2}
##   queue               {"p": id producteur (-1 = base), "u": type d'unité}
##   cancel              {"p": id producteur, "i": rang dans la file}
##   rally               {"p": id producteur, "c": Vector2i}
##   unit_move           {"u": [ids unités], "c": Vector2i}
##   unit_attack         {"u": [ids], "e": id ennemi}
##   stop                {"u": [ids], "w": [ids]}
##   auto_repair         {"w": [ids], "on": bool}
##   repair_base         {"w": [ids]}
##   ability             {"u": [ids], "a": id du pouvoir}


## Applique un ordre. Renvoie "" si tout va bien, sinon la raison du refus.
static func apply(world: GameWorld, cmd: Dictionary) -> String:
	var ws: Array = []
	for id in cmd.get("w", []):
		var w := world.worker_by_id(int(id))
		if w != null:
			ws.append(w)
	var us: Array = []
	for id in cmd.get("u", []) if cmd.get("u") is Array else []:
		var u := world.unit_by_id(int(id))
		if u != null:
			us.append(u)
	var site: BuildSite = world.site_by_id(int(cmd.get("s", -1))) if cmd.has("s") else null
	match cmd.get("t", ""):
		"move":
			world.command_move(ws, cmd.c)
		"harvest":
			world.command_harvest(ws, cmd.c)
		"build":
			if site == null:
				return "Chantier introuvable"
			world.command_build(ws, site)
		"repair":
			if site == null:
				return "Bâtiment introuvable"
			world.command_repair(ws, site)
		"repair_auto":
			if site == null:
				return "Bâtiment introuvable"
			var n := 0
			for i in 2:
				var w := world.nearest_available_worker(site.cell)
				if w == null:
					break
				world.command_repair([w], site)
				n += 1
			if n == 0:
				return "Aucun ouvrier disponible"
		"place":
			var reason := world.can_place(cmd.k, cmd.c)
			if reason != "":
				return reason
			var s := world.place(cmd.k, cmd.c)
			if ws.is_empty():
				var nearest := world.nearest_available_worker(cmd.c)
				if nearest != null:
					ws.append(nearest)
			world.command_build(ws, s)
		"upgrade":
			if site == null:
				return "Bâtiment introuvable"
			var reason := world.can_upgrade(site)
			if reason != "":
				return reason
			world.upgrade(site)
		"sell":
			if site == null:
				return "Bâtiment introuvable"
			world.sell(site)
		"train":
			var reason := world.can_train_worker()
			if reason != "":
				return reason
			world.train_worker()
		"queue":
			var reason := world.can_queue(int(cmd.p), cmd.u)
			if reason != "":
				return reason
			world.queue_unit(int(cmd.p), cmd.u)
		"research":
			var reason := world.can_research(int(cmd.p), str(cmd.r))
			if reason != "":
				return reason
			world.queue_research(int(cmd.p), str(cmd.r))
		"hold":
			world.command_hold(us)
		"cancel":
			world.cancel_queue(int(cmd.p), int(cmd.i))
		"rally":
			world.set_rally(int(cmd.p), cmd.c)
		"unit_move":
			world.command_units_move(us, cmd.c)
		"ability":
			world.use_ability(us, str(cmd.a))
		"unit_attack":
			var e := world.enemy_by_id(int(cmd.e))
			if e == null:
				return "Cible introuvable"
			world.command_units_attack(us, e)
		"stop":
			world.command_stop(us, ws)
		"auto_repair":
			world.set_auto_repair(ws, bool(cmd.on))
		"repair_base":
			world.command_repair_base(ws)
		"next_wave":
			world.waves.start_next()
		"orbital":
			if not world.cast_orbital(cmd.p):
				return "Frappe orbitale en recharge"
		_:
			return "Ordre inconnu"
	return ""


static func ids(workers: Array) -> Array:
	return workers.map(func(w: Worker) -> int: return w.id)
