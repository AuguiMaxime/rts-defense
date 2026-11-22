class_name Worker
extends RefCounted
## Un ouvrier : récolte ou construit. Position en cases (le centre d'une case est x + 0.5).

enum State { IDLE, MOVING, HARVESTING, BUILDING, REPAIRING }
enum Job { NONE, HARVEST, BUILD, REPAIR }

var id := 0
var net_target := Vector2.INF # coop : position reçue de l'hôte (interpolation)
var pos := Vector2.ZERO
var facing := Vector2.RIGHT # direction du dernier déplacement
var state := State.IDLE
var job := Job.NONE
var path: Array[Vector2i] = []
var target_deposit := Vector2i(-1, -1)
var deposit_type := -1 # type de minerai récolté (pour en retrouver un autre)
var target_site: BuildSite = null
var carry_type := -1 # GameGrid.Cell.METAL ou ESSENCE
var carry_amount := 0
var timer := 0.0
var hp := Balance.WORKER_HP
var alive := true
var auto_repair := false # répare tout seul le bâtiment abîmé le plus proche
var repair_base := false # la cible de réparation est la base


func cell() -> Vector2i:
	return Vector2i(pos.floor())
