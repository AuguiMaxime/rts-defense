extends Node2D
## Écran de jeu : relie la simulation (GameWorld) à l'affichage, aux contrôles et au HUD.

const TILE := MapView.TILE

var world: GameWorld
var level: Dictionary
var map_script: Variant
var selected: Array[Worker] = [] # ouvriers sélectionnés
var sel_units: Array[Unit] = [] # unités de combat sélectionnées
var focused_site: BuildSite = null # bâtiment sélectionné
var sel_base := false # base sélectionnée
var build_kind := "" # "" = pas en mode construction ; "orbital" = ciblage du pouvoir
var speed := 1
var paused := false
var survival := false
var new_record := false
var tutorial: Tutorial = null
var coop := false
var _snapshot_timer := 0.0
var _ended := false
var _granted_waves := 0
var _granted_kills := 0
var _granted_stats := {}
var _last_wave := 0

@onready var map_view: MapView = $MapView
@onready var units_view: UnitsView = $UnitsView
@onready var camera: CameraController = $Camera
@onready var hud: GameHud = GameHud.new()


func _ready() -> void:
	level = Content.level(Ui.current_level)
	map_script = load(level.map)
	survival = Ui.survival
	coop = Net.online
	world = GameWorld.new(MapLoader.from_layout(map_script.LAYOUT), _build_config())
	if coop:
		if Net.is_host:
			world.record_net_events = true
			Net.command_received.connect(_on_remote_command)
		else:
			world.workers.clear() # le client reçoit tout de l'hôte
			Net.snapshot_received.connect(func(snap: Dictionary) -> void: NetSync.apply(world, snap))
			Net.command_refused.connect(func(reason: String) -> void: hud.flash(reason, Ui.RED))
		Net.partner_left.connect(func() -> void: Ui.toast("Ton partenaire s'est déconnecté — tu continues seul", Ui.RED))
		Net.disconnected.connect(func() -> void:
			Ui.toast("Connexion à l'hôte perdue", Ui.RED)
			Ui.goto("menu"))
	if survival:
		world.waves.infinite = true
	map_view.setup(world.grid, map_script.GROUND)
	units_view.world = world
	units_view.skin_tint = Content.skin(Save.data.skin).tint

	camera.set_bounds(Rect2(Vector2.ZERO, Vector2(world.grid.width, world.grid.height) * TILE).grow(TILE))
	camera.center_on(world.base_center() * TILE)
	camera.is_over_ui = func(p: Vector2) -> bool: return hud.is_over_ui(p)
	camera.tapped.connect(_on_tapped)
	camera.selection_updated.connect(func(a: Vector2, b: Vector2) -> void: units_view.selection_rect = Rect2(a, b - a).abs())
	camera.selection_ended.connect(_on_selection_ended)
	camera.selection_cancelled.connect(func() -> void: units_view.selection_rect = Rect2())

	$HUD.add_child(hud)
	hud.setup(self)
	units_view.shake.connect(camera.add_shake)
	units_view.base_hit.connect(hud.flash_damage)
	if level.id == 1 and not survival and not coop and not Save.data.get("tutorial_done", false):
		tutorial = Tutorial.new()
		tutorial.theme = Ui.theme
		$HUD.add_child(tutorial)
		tutorial.setup(self)


## Bonus de technos et augments appliqués à la partie.
func _build_config() -> Dictionary:
	var cfg := {
		"waves": level.waves,
		"difficulty": 1.0 if Ui.survival else level.difficulty,
		"wave_interval": level.get("interval", Balance.WAVE_INTERVAL),
		"start_metal": Balance.START_METAL + int(Content.tech("reserves").value) * Save.tech_level("reserves"),
		"start_workers": Balance.START_WORKERS,
		"base_hp": roundi(Balance.BASE_HP * (1.0 + Content.tech("hull").value * Save.tech_level("hull"))),
		"damage_mult": 1.0 + Content.tech("ammo").value * Save.tech_level("ammo"),
		"worker_speed_mult": 1.0 + Content.tech("logistics").value * Save.tech_level("logistics"),
		"carry_bonus": Save.tech_level("logistics"),
		"orbital": Save.tech_level("orbital") > 0,
		"laser": Save.owns("tower_laser"),
	}
	var used: Array[String] = []
	if Net.is_client():
		return cfg # en coop, c'est la partie de l'hôte (ses technos et augments) qui compte
	if Save.augment_count("starter_kit") > 0:
		cfg.start_metal += 150
		used.append("starter_kit")
	if Save.augment_count("extra_workers") > 0:
		cfg.start_workers += 2
		used.append("extra_workers")
	if Save.augment_count("shield") > 0:
		cfg.base_hp += 300
		used.append("shield")
	for id in used:
		Save.change_augment(id, -1)
	if not used.is_empty():
		Ui.toast.call_deferred("%d augment(s) activé(s)" % used.size(), Ui.GREEN)
	return cfg


func _process(delta: float) -> void:
	if Net.is_client():
		NetSync.interpolate(world, delta)
	elif not paused or coop:
		for i in speed:
			world.tick(delta)
		if coop:
			_snapshot_timer -= delta
			if _snapshot_timer <= 0.0:
				_snapshot_timer = 0.1
				Net.send_snapshot(NetSync.snapshot(world))
	if focused_site != null and not focused_site.alive:
		_clear_selection()
	if selected.any(func(w: Worker) -> bool: return not w.alive) or sel_units.any(func(u: Unit) -> bool: return not u.alive):
		_set_selection(selected.filter(func(w: Worker) -> bool: return w.alive), sel_units.filter(func(u: Unit) -> bool: return u.alive))
	_update_rally_display()
	if world.waves.wave != _last_wave:
		_last_wave = world.waves.wave
		Sfx.play("wave", -2.0, 1.0)
		Sfx.vibrate(60)
		if WaveManager.is_boss_wave(_last_wave):
			hud.flash("ALERTE : BOSS EN APPROCHE", Ui.RED)
			Sfx.vibrate(150)
		else:
			hud.flash("VAGUE %d EN APPROCHE" % _last_wave, Ui.RED)
	if world.state != GameWorld.State.PLAYING and not _ended:
		_ended = true
		hud.show_end(world.state == GameWorld.State.WON)


# --- Sélection ------------------------------------------------------------------------
# Modèle façon StarCraft : on sélectionne soit la base, soit un bâtiment, soit des ouvriers/unités.
# La grille d'actions en bas à droite dépend de la sélection.

func selection_kind() -> String:
	if sel_base:
		return "base"
	if focused_site != null:
		return "site"
	if not selected.is_empty() or not sel_units.is_empty():
		return "mobile"
	return "none"


## Clé qui change quand le contenu de la sélection change (pour reconstruire la console).
func selection_key() -> String:
	match selection_kind():
		"base":
			return "base"
		"site":
			return "site%d-%s-%d" % [focused_site.id, focused_site.built, focused_site.level]
		"mobile":
			return "mob" + ",".join(selected.map(func(w: Worker) -> String: return "w%d" % w.id)) \
					+ ",".join(sel_units.map(func(u: Unit) -> String: return "u%d" % u.id))
	return "none"


## Identifiant du producteur sélectionné (base ou caserne/usine terminée), sinon 0.
func selected_producer_id() -> int:
	if sel_base:
		return GameWorld.BASE_ID
	if focused_site != null and focused_site.built and focused_site.is_producer():
		return focused_site.id
	return 0


func select_base() -> void:
	_clear_selection()
	sel_base = true
	units_view.sel_base = true


func focus_site(s: BuildSite) -> void:
	_clear_selection()
	focused_site = s
	units_view.focused_site = s


func _set_selection(ws: Array, us: Array = []) -> void:
	_clear_selection()
	selected.assign(ws)
	sel_units.assign(us)
	units_view.selected = selected
	units_view.sel_units = sel_units


func _clear_selection() -> void:
	selected.clear()
	sel_units.clear()
	focused_site = null
	sel_base = false
	units_view.focused_site = null
	units_view.sel_base = false
	units_view.selected = selected
	units_view.sel_units = sel_units
	map_view.set_selected(Vector2i(-1, -1))
	if build_kind != "" and build_kind != "orbital":
		set_build_kind("")


func deselect() -> void:
	_clear_selection()


# --- Contrôles --------------------------------------------------------------------

func _on_tapped(world_px: Vector2) -> void:
	if paused:
		return
	var p := world_px / TILE
	var c := Vector2i(p.floor())

	if build_kind == "orbital":
		if issue({"t": "orbital", "p": p}) == "":
			set_build_kind("")
		return
	if build_kind != "":
		_try_place(c)
		return

	# 1. Toucher un de mes ouvriers ou une de mes unités : on le sélectionne.
	var u := world.unit_at(p)
	if u != null:
		_set_selection([], [u])
		return
	var w := world.worker_at(p)
	if w != null:
		_set_selection([w])
		return

	var site := world.site_at(c)
	var on_base := world.is_base_cell(c)
	var kind := selection_kind()

	# 2. Producteur sélectionné : toucher la carte place le point de ralliement.
	var pid := selected_producer_id()
	if pid != 0 and not (on_base and pid == GameWorld.BASE_ID) and not (site != null and site == focused_site):
		if site == null and not on_base and world.grid.is_inside(c):
			issue({"t": "rally", "p": pid, "c": c})
			Sfx.play("click", -4.0)
			hud.flash("Point de ralliement placé", Ui.GREEN)
			return

	# 3. Ouvriers / unités sélectionnés : donner un ordre.
	if kind == "mobile":
		_order_selection(p, c, site, on_base)
		return

	# 4. Sinon : sélectionner la base ou le bâtiment touché.
	if on_base:
		select_base()
	elif site != null:
		focus_site(site)
	else:
		_clear_selection()
		if world.grid.is_inside(c):
			hud.show_info(GameGrid.CELL_NAMES[world.grid.get_cell(c)])


func _order_selection(p: Vector2, c: Vector2i, site: BuildSite, on_base: bool) -> void:
	var wids := Commands.ids(selected)
	var uids := sel_units.map(func(x: Unit) -> int: return x.id)
	var enemy := world.enemy_at(p)
	if enemy != null and not uids.is_empty():
		issue({"t": "unit_attack", "u": uids, "e": enemy.id})
		if not wids.is_empty():
			issue({"t": "move", "w": wids, "c": c})
		hud.flash("Attaque !", Ui.RED)
		return
	if not uids.is_empty():
		issue({"t": "unit_move", "u": uids, "c": c})
	if wids.is_empty():
		return
	if site != null:
		if not site.built:
			issue({"t": "build", "w": wids, "s": site.id})
		elif site.hp < site.max_hp:
			issue({"t": "repair", "w": wids, "s": site.id})
			hud.flash("Réparation en cours", Ui.GREEN)
		return
	if on_base:
		if world.base_hp < world.max_base_hp:
			issue({"t": "repair_base", "w": wids})
			hud.flash("Réparation de la base", Ui.GREEN)
		return
	match world.grid.get_cell(c):
		GameGrid.Cell.METAL, GameGrid.Cell.ESSENCE:
			issue({"t": "harvest", "w": wids, "c": c})
		_:
			issue({"t": "move", "w": wids, "c": c})


func _try_place(c: Vector2i) -> void:
	var reason := world.can_place(build_kind, c)
	if reason != "":
		hud.flash(reason, Ui.RED)
		return
	issue({"t": "place", "k": build_kind, "c": c, "w": Commands.ids(selected)})
	set_build_kind("")


func _on_selection_ended(a: Vector2, b: Vector2) -> void:
	units_view.selection_rect = Rect2()
	var r := Rect2(a / TILE, (b - a) / TILE).abs()
	var us := world.units_in_rect(r)
	# Comme dans StarCraft : s'il y a des unités de combat dans le cadre, on ne prend qu'elles.
	if not us.is_empty():
		_set_selection([], us)
	else:
		_set_selection(world.workers_in_rect(r))


func set_build_kind(kind: String) -> void:
	build_kind = kind
	units_view.show_ranges = kind in Content.TOWERS
	if kind == "orbital":
		hud.flash("Touche la zone à frapper", Ui.CYAN)
	elif kind != "":
		var size := int(Content.building(kind).get("size", 1))
		hud.flash("Touche %s pour construire : %s" % ["l'emplacement (2x2, coin haut-gauche)" if size > 1 else "une case libre", Content.building(kind).name], Ui.CYAN)


# --- Grille d'actions ----------------------------------------------------------------

static func _cost_text(metal: int, essence: int) -> String:
	var parts: Array[String] = []
	if metal > 0:
		parts.append("%dM" % metal)
	if essence > 0:
		parts.append("%dE" % essence)
	return " ".join(parts)


func _affordable(metal: int, essence: int) -> bool:
	return world.metal >= metal and world.essence >= essence


func card_actions() -> Array:
	var out: Array = []
	match selection_kind():
		"base":
			for t in Content.BASE_PRODUCES:
				out.append(_unit_action(GameWorld.BASE_ID, t))
			if world.orbital_unlocked():
				var ready := world.orbital_ready()
				out.append({"id": "orbital", "icon": "orbital", "label": "ORBITALE",
						"cost": "PRÊTE" if ready else "%d s" % ceili(world.orbital_cooldown),
						"cost_color": Ui.GREEN if ready else Ui.MUTED, "enabled": ready, "active": build_kind == "orbital",
						"call": func() -> void:
							if world.orbital_ready():
								set_build_kind("" if build_kind == "orbital" else "orbital")
							else:
								hud.flash("Frappe orbitale en recharge", Ui.RED)})
		"site":
			var s := focused_site
			if not s.built:
				out.append({"id": "cancel_site", "icon": "#✕", "label": "ANNULER", "cost": "+%dM" % s.sell_value().metal,
						"call": sell_focused})
			else:
				if s.is_producer():
					for t in Content.PRODUCTION[s.kind].produces:
						out.append(_unit_action(s.id, t))
				if s.is_tower() and s.level < BuildSite.MAX_LEVEL:
					var uc := s.upgrade_cost()
					out.append({"id": "upgrade", "icon": "#▲", "label": "AMÉLIORER", "cost": _cost_text(uc.metal, uc.essence),
							"enabled": world.can_upgrade(s) == "", "call": upgrade_focused})
				if s.hp < s.max_hp:
					out.append({"id": "repair", "icon": Sprites.SITE, "label": "RÉPARER", "call": repair_focused})
				out.append({"id": "sell", "icon": "#$", "label": "VENDRE", "cost": "+%dM" % s.sell_value().metal,
						"cost_color": Ui.GOLD, "call": sell_focused})
		"mobile":
			if not selected.is_empty():
				for kind in Content.BUILD_ORDER:
					if kind == "laser" and not world.laser_unlocked:
						continue
					var b := Content.building(kind)
					var icon: Variant = Sprites.TOWER_LOOK[kind].turret if Content.is_tower(kind) else \
							("pop" if kind == "house" else (Sprites.SOLDIER_GREEN if kind == "barracks" else Sprites.TANK_GREEN))
					var k: String = kind
					out.append({"id": kind, "icon": icon, "tint": Sprites.TOWER_LOOK[kind].tint if Content.is_tower(kind) else Color(1, 1, 1),
							"label": str(b.name).to_upper(), "cost": _cost_text(b.metal, b.essence),
							"enabled": _affordable(b.metal, b.essence), "active": build_kind == kind,
							"call": func() -> void: set_build_kind("" if build_kind == k else k)})
				var all_auto := selected.all(func(x: Worker) -> bool: return x.auto_repair)
				out.append({"id": "auto_repair", "icon": Sprites.SITE, "label": "AUTO-RÉPAR.",
						"cost": "ACTIVE" if all_auto else "INACTIVE", "cost_color": Ui.GREEN if all_auto else Ui.MUTED,
						"active": all_auto,
						"call": func() -> void:
							issue({"t": "auto_repair", "w": Commands.ids(selected), "on": not all_auto})
							hud.flash("Réparation automatique %s" % ("désactivée" if all_auto else "activée"), Ui.GREEN)})
			if out.size() < Console.CARD_COLS * Console.CARD_ROWS:
				out.append({"id": "stop", "icon": "#■", "label": "STOP",
						"call": func() -> void:
							issue({"t": "stop", "u": sel_units.map(func(x: Unit) -> int: return x.id), "w": Commands.ids(selected)})})
	return out.slice(0, Console.CARD_COLS * Console.CARD_ROWS)


func _unit_action(producer_id: int, t: String) -> Dictionary:
	var d: Dictionary = Content.UNITS[t]
	return {"id": t, "icon": Console.unit_icon(t), "tint": Sprites.UNIT_LOOK[t].tint if Sprites.UNIT_LOOK.has(t) else Color(1, 1, 1),
			"label": str(d.name).to_upper(), "cost": _cost_text(d.metal, d.essence),
			"enabled": world.can_queue(producer_id, t) == "",
			"call": func() -> void: queue_unit(producer_id, t)}


func queue_unit(producer_id: int, t: String) -> void:
	var reason := world.can_queue(producer_id, t)
	if reason != "":
		hud.flash(reason, Ui.RED)
		return
	issue({"t": "queue", "p": producer_id, "u": t})


func cancel_queue(producer_id: int, index: int) -> void:
	var p := world.producer_by_id(producer_id)
	if p != null and index < p.queue.size():
		issue({"t": "cancel", "p": producer_id, "i": index})


func upgrade_focused() -> void:
	var s := focused_site
	if s == null:
		return
	var reason := world.can_upgrade(s)
	if reason != "":
		hud.flash(reason, Ui.RED)
	else:
		issue({"t": "upgrade", "s": s.id})
		hud.flash("%s niveau %d" % [s.stats().name, s.level + (1 if Net.is_client() else 0)], Ui.GREEN)


func repair_focused() -> void:
	var s := focused_site
	if s == null:
		return
	var reason := issue({"t": "repair_auto", "s": s.id})
	hud.flash("Ouvriers envoyés en réparation" if reason == "" else reason, Ui.GREEN if reason == "" else Ui.RED)


func sell_focused() -> void:
	if focused_site == null:
		return
	var refund := focused_site.sell_value()
	issue({"t": "sell", "s": focused_site.id})
	hud.flash("Vendu : +%d métal" % refund.metal, Ui.GOLD)
	_clear_selection()


func train_worker() -> void:
	queue_unit(GameWorld.BASE_ID, "worker")


func _update_rally_display() -> void:
	var pid := selected_producer_id()
	var p := world.producer_by_id(pid) if pid != 0 else null
	if p != null and p.has_rally():
		units_view.rally_from = world.base_center() if pid == GameWorld.BASE_ID else focused_site.center()
		units_view.rally_to = Vector2(p.rally) + Vector2(0.5, 0.5)
	else:
		units_view.rally_from = Vector2.INF
		units_view.rally_to = Vector2.INF


## Envoie un ordre : appliqué tout de suite en solo et chez l'hôte, envoyé à l'hôte côté client.
func issue(cmd: Dictionary) -> String:
	if Net.is_client():
		Net.send_command(cmd)
		return ""
	var reason := Commands.apply(world, cmd)
	if reason != "":
		hud.flash(reason, Ui.RED)
	return reason


func _on_remote_command(cmd: Dictionary) -> void:
	var reason := Commands.apply(world, cmd)
	if reason != "":
		Net.send_refused(reason)


func toggle_speed() -> void:
	if Net.is_client():
		hud.flash("En coop, seul l'hôte règle la vitesse", Ui.RED)
		return
	speed = 2 if speed == 1 else 1


func set_paused(on: bool) -> void:
	paused = on


func _notification(what: int) -> void:
	# Mise en pause automatique quand l'appli passe en arrière-plan sur mobile.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not _ended and is_node_ready():
		hud.open_pause()


# --- Fin de partie -------------------------------------------------------------------

## Étoiles : 3 si la base a gardé 70 % de ses PV, 2 au-dessus de 35 %, sinon 1.
func stars() -> int:
	if world.state != GameWorld.State.WON:
		return 0
	var ratio := float(world.base_hp) / world.max_base_hp
	return 3 if ratio >= 0.7 else (2 if ratio >= 0.35 else 1)


## Crédits gagnés, enregistre la progression. À n'appeler qu'une fois par fin.
func grant_rewards() -> int:
	var won := world.state == GameWorld.State.WON
	var waves_done := world.waves.wave if won else maxi(0, world.waves.wave - 1)
	var prev_waves := _granted_waves
	var credits_kills_delta := world.kills - _granted_kills
	var credits := (waves_done - _granted_waves) * 12 + (world.kills - _granted_kills)
	if won and _granted_waves == 0:
		credits += 80 + stars() * 25
	credits = maxi(0, credits)
	_granted_waves = maxi(_granted_waves, waves_done)
	_granted_kills = world.kills
	Save.add("credits", credits)
	var st := {}
	for k in world.stats:
		st[k] = int(world.stats[k]) - int(_granted_stats.get(k, 0))
	_granted_stats = world.stats.duplicate()
	st.kills = credits_kills_delta
	st.waves = waves_done - prev_waves
	st.wins = 1 if won and prev_waves == 0 else 0
	Save.add_mission_progress(st)
	if coop:
		pass # en coop : crédits seulement, pas d'étoiles ni de record
	elif survival:
		new_record = Save.record_survival(level.id, world.waves.wave)
	elif won:
		Save.record_level(level.id, stars(), world.waves.wave)
	return credits


func restart() -> void:
	if coop:
		Ui.goto("multi")
		return
	Ui.play_level(level.id, survival)


func next_level_id() -> int:
	for l in Content.LEVELS:
		if l.id == level.id + 1:
			return l.id
	return -1


func continue_infinite() -> void:
	_ended = false
	world.continue_infinite()
