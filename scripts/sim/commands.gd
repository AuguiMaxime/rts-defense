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


## Applique un ordre. Renvoie "" si tout va bien, sinon la raison du refus.
static func apply(world: GameWorld, cmd: Dictionary) -> String:
	var ws: Array = []
	for id in cmd.get("w", []):
		var w := world.worker_by_id(int(id))
		if w != null:
			ws.append(w)
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
