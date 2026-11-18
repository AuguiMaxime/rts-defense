class_name GameWorld
extends RefCounted
## État complet d'une partie et ses règles. Avancé par tick(delta).
## Aucune dépendance à l'affichage : c'est ce bloc qui tournera sur le serveur en multi.

var grid: GameGrid
var pathfinder: Pathfinder
var metal := Balance.START_METAL
var essence := Balance.START_ESSENCE
var workers: Array[Worker] = []
var sites: Array[BuildSite] = []
var train_queue := 0
var train_timer := 0.0

var _next_id := 1


func _init(g: GameGrid) -> void:
	grid = g
	pathfinder = Pathfinder.new(g)
	for i in Balance.START_WORKERS:
		_spawn_worker()


# --- Avancement du temps -------------------------------------------------

func tick(delta: float) -> void:
	if train_queue > 0:
		train_timer += delta
		if train_timer >= Balance.WORKER_TRAIN_TIME:
			train_timer = 0.0
			train_queue -= 1
			_spawn_worker()
	for w in workers:
		_tick_worker(w, delta)


func _tick_worker(w: Worker, delta: float) -> void:
	match w.state:
		Worker.State.MOVING:
			if _follow_path(w, delta):
				_on_arrived(w)
		Worker.State.HARVESTING:
			w.timer -= delta
			if w.timer <= 0.0:
				w.carry_type = grid.get_cell(w.target_deposit)
				w.carry_amount = Balance.CARRY_CAPACITY
				_move_to_adjacent(w, grid.base_cells)
		Worker.State.BUILDING:
			var s := w.target_site
			if s == null or s.built or not sites.has(s):
				_set_idle(w)
				return
			s.work_done += delta
			if s.work_done >= s.work_needed:
				_finish_site(s)


func _follow_path(w: Worker, delta: float) -> bool:
	var step := Balance.WORKER_SPEED * delta
	while step > 0.0 and not w.path.is_empty():
		var target := Vector2(w.path[0]) + Vector2(0.5, 0.5)
		var d := w.pos.distance_to(target)
		if d > 0.001:
			w.facing = (target - w.pos) / d
		if d <= step:
			w.pos = target
			step -= d
			w.path.remove_at(0)
		else:
			w.pos += (target - w.pos) / d * step
			step = 0.0
	return w.path.is_empty()


func _on_arrived(w: Worker) -> void:
	match w.job:
		Worker.Job.HARVEST:
			if w.carry_amount > 0:
				_deposit(w)
				_move_to_adjacent(w, [w.target_deposit] as Array[Vector2i])
			else:
				w.state = Worker.State.HARVESTING
				w.timer = Balance.HARVEST_TIME
		Worker.Job.BUILD:
			w.state = Worker.State.BUILDING
		_:
			w.state = Worker.State.IDLE


func _deposit(w: Worker) -> void:
	if w.carry_type == GameGrid.Cell.METAL:
		metal += w.carry_amount
	elif w.carry_type == GameGrid.Cell.ESSENCE:
		essence += w.carry_amount
	w.carry_amount = 0
	w.carry_type = -1


# --- Ordres du joueur ---------------------------------------------------------

func train_worker() -> bool:
	if metal < Balance.WORKER_COST_METAL:
		return false
	metal -= Balance.WORKER_COST_METAL
	train_queue += 1
	return true


func command_move(ws: Array, c: Vector2i) -> void:
	for w: Worker in ws:
		w.job = Worker.Job.NONE
		w.target_site = null
		if pathfinder.is_free(c):
			_set_path(w, pathfinder.find_path(w.cell(), c))
		else:
			_move_to_adjacent(w, [c] as Array[Vector2i])


func command_harvest(ws: Array, deposit: Vector2i) -> void:
	for w: Worker in ws:
		w.job = Worker.Job.HARVEST
		w.target_site = null
		w.target_deposit = deposit
		if w.carry_amount > 0:
			_move_to_adjacent(w, grid.base_cells)
		else:
			_move_to_adjacent(w, [deposit] as Array[Vector2i])


func command_build(ws: Array, site: BuildSite) -> void:
	for w: Worker in ws:
		w.job = Worker.Job.BUILD
		w.target_site = site
		_move_to_adjacent(w, [site.cell] as Array[Vector2i])


## Raison du refus, ou "" si la tourelle peut être posée.
func can_place_tower(c: Vector2i) -> String:
	if not grid.is_inside(c):
		return "Hors de la map"
	if grid.get_cell(c) != GameGrid.Cell.EMPTY or site_at(c) != null:
		return "Case occupée"
	if metal < Balance.TOWER_COST_METAL:
		return "Pas assez de métal (%d)" % Balance.TOWER_COST_METAL
	pathfinder.set_solid(c, true)
	var open := enemies_can_reach_base()
	pathfinder.set_solid(c, false)
	if not open:
		return "Bloquerait le chemin des ennemis"
	return ""


func place_tower(c: Vector2i) -> BuildSite:
	if can_place_tower(c) != "":
		return null
	metal -= Balance.TOWER_COST_METAL
	var s := BuildSite.new()
	s.cell = c
	sites.append(s)
	pathfinder.set_solid(c, true)
	for w in workers:
		if w.state == Worker.State.MOVING and w.path.has(c):
			_set_path(w, pathfinder.find_path(w.cell(), w.path.back()))
	return s


## Règle anti-blocage : chaque point d'apparition doit garder un chemin vers la base.
func enemies_can_reach_base() -> bool:
	for sp in grid.spawn_points:
		if pathfinder.find_path_to_adjacent(sp, grid.base_cells).is_empty():
			return false
	return true


# --- Requêtes pour l'interface -----------------------------------------------

func site_at(c: Vector2i) -> BuildSite:
	for s in sites:
		if s.cell == c:
			return s
	return null


func worker_at(p: Vector2, radius := 0.5) -> Worker:
	var best: Worker = null
	var best_d := radius
	for w in workers:
		var d := w.pos.distance_to(p)
		if d <= best_d:
			best = w
			best_d = d
	return best


func workers_in_rect(r: Rect2) -> Array[Worker]:
	var result: Array[Worker] = []
	for w in workers:
		if r.has_point(w.pos):
			result.append(w)
	return result


## L'ouvrier le plus proche qui n'est pas déjà sur un chantier.
func nearest_available_worker(c: Vector2i) -> Worker:
	var target := Vector2(c) + Vector2(0.5, 0.5)
	var best: Worker = null
	var best_score := INF
	for w in workers:
		if w.job == Worker.Job.BUILD:
			continue
		var score := w.pos.distance_to(target) + (0.0 if w.state == Worker.State.IDLE else 1000.0)
		if score < best_score:
			best = w
			best_score = score
	return best


# --- Interne ----------------------------------------------------------------

func _spawn_worker() -> void:
	var w := Worker.new()
	w.id = _next_id
	_next_id += 1
	var spots := pathfinder.free_cells_around(grid.base_cells)
	var c := spots[(w.id - 1) % spots.size()] if not spots.is_empty() else Vector2i.ZERO
	w.pos = Vector2(c) + Vector2(0.5, 0.5)
	workers.append(w)


func _move_to_adjacent(w: Worker, targets: Array[Vector2i]) -> void:
	_set_path(w, pathfinder.find_path_to_adjacent(w.cell(), targets))


func _set_path(w: Worker, p: Array[Vector2i]) -> void:
	if p.is_empty():
		_set_idle(w)
		return
	w.path = p
	w.state = Worker.State.MOVING


func _set_idle(w: Worker) -> void:
	w.state = Worker.State.IDLE
	w.job = Worker.Job.NONE
	w.target_site = null
	w.path.clear()


func _finish_site(s: BuildSite) -> void:
	s.built = true
	s.hp = s.max_hp
	for w in workers:
		if w.target_site == s:
			_set_idle(w)
