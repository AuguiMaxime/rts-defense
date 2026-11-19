extends Node2D
## Écran de jeu : relie la simulation (GameWorld) à l'affichage, aux contrôles et au HUD.

const TILE := MapView.TILE

var world: GameWorld
var level: Dictionary
var map_script: Variant
var selected: Array[Worker] = []
var focused_site: BuildSite = null
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
	if focused_site != null and not world.sites.has(focused_site):
		focus_site(null)
	if selected.any(func(w: Worker) -> bool: return not world.workers.has(w)):
		_set_selection(selected.filter(func(w: Worker) -> bool: return world.workers.has(w)))
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

	var w := world.worker_at(p)
	if w != null:
		_set_selection([w])
		return

	var site := world.site_at(c)
	if selected.is_empty():
		if site != null:
			focus_site(site)
			return
		focus_site(null)
		map_view.set_selected(c)
		if world.grid.is_inside(c):
			hud.show_info(GameGrid.CELL_NAMES[world.grid.get_cell(c)])
		return

	if site != null:
		if not site.built:
			issue({"t": "build", "w": Commands.ids(selected), "s": site.id})
		elif site.hp < site.max_hp:
			issue({"t": "repair", "w": Commands.ids(selected), "s": site.id})
			hud.flash("Réparation en cours", Ui.GREEN)
		return
	match world.grid.get_cell(c):
		GameGrid.Cell.METAL, GameGrid.Cell.ESSENCE:
			issue({"t": "harvest", "w": Commands.ids(selected), "c": c})
		_:
			issue({"t": "move", "w": Commands.ids(selected), "c": c})


func focus_site(s: BuildSite) -> void:
	focused_site = s
	units_view.focused_site = s
	if s != null:
		_set_selection([])
		map_view.set_selected(Vector2i(-1, -1))


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
	focus_site(null)


func _try_place(c: Vector2i) -> void:
	var reason := world.can_place(build_kind, c)
	if reason != "":
		hud.flash(reason, Ui.RED)
		return
	issue({"t": "place", "k": build_kind, "c": c, "w": Commands.ids(selected)})
	set_build_kind("")


func _on_selection_ended(a: Vector2, b: Vector2) -> void:
	units_view.selection_rect = Rect2()
	_set_selection(world.workers_in_rect(Rect2(a / TILE, (b - a) / TILE).abs()))


func _set_selection(ws: Array) -> void:
	selected.assign(ws)
	if not ws.is_empty() and focused_site != null:
		focused_site = null
		units_view.focused_site = null
	units_view.selected = selected
	map_view.set_selected(Vector2i(-1, -1))


func set_build_kind(kind: String) -> void:
	build_kind = kind
	units_view.show_ranges = kind in Content.TOWERS
	if kind != "":
		focus_site(null)
	hud.refresh_build_buttons()
	if kind == "orbital":
		hud.flash("Touche la zone à frapper", Ui.CYAN)
	elif kind != "":
		hud.flash("Touche une case libre pour construire : %s" % Content.building(kind).name, Ui.CYAN)


func deselect() -> void:
	_set_selection([])


func train_worker() -> void:
	var reason := world.can_train_worker()
	if reason != "":
		hud.flash(reason, Ui.RED)
	else:
		issue({"t": "train"})


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
