class_name EnemyBarLayer
extends Control
## Enemy HP bars: shown after a hit or on hover, hidden SHOW_TIME later.
## A fixed pool; when more enemies qualify, the hovered one comes first, then the ones
## closest to the commander. The boss uses BossBar instead.

const MAX_BARS := 40
const SHOW_TIME := 3.0
const BAR_SIZE := Vector2(56, 8)
const HEAD_OFFSET := Vector3(0, 2.2, 0)
const PICK_INTERVAL := 0.1

var hovered: Node = null

var _bars: Array[ProgressBar] = []
var _shown_until: Dictionary = {}  # Enemy -> pausable real time when its bar hides
var _assigned: Array[Enemy] = []
var _next_pick := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in MAX_BARS:
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"EnemyBar"
		bar.show_percentage = false
		bar.custom_minimum_size = BAR_SIZE
		bar.size = BAR_SIZE
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		add_child(bar)
		_bars.append(bar)
	EventBus.enemy_spawned.connect(_on_enemy_spawned)

func _on_enemy_spawned(node: Node) -> void:
	var enemy := node as Enemy
	if enemy == null or enemy.is_in_group(&"boss"):
		return
	enemy.health.damaged.connect(_on_damaged.bind(enemy))
	enemy.tree_exiting.connect(_forget.bind(enemy))

## Pausable real time: not sped up at x2/x3 and frozen while paused.
func _on_damaged(_amount: int, _info: DamageInfo, enemy: Enemy) -> void:
	_shown_until[enemy] = TimeManager.pausable_real_time + SHOW_TIME

func _forget(enemy: Enemy) -> void:
	_shown_until.erase(enemy)

func _process(_delta: float) -> void:
	if TimeManager.real_time >= _next_pick:
		_next_pick = TimeManager.real_time + PICK_INTERVAL
		_pick()
	_place()

func _pick() -> void:
	var now := TimeManager.pausable_real_time
	var candidates: Array[Enemy] = []
	for e in _shown_until.keys():
		if not is_instance_valid(e) or e.is_dead or now > _shown_until[e]:
			_shown_until.erase(e)
			continue
		candidates.append(e)
	var hovered_enemy: Enemy = null
	if is_instance_valid(hovered):
		hovered_enemy = hovered as Enemy
	if hovered_enemy != null and (hovered_enemy.is_dead or hovered_enemy.is_in_group(&"boss")):
		hovered_enemy = null
	if hovered_enemy != null and hovered_enemy not in candidates:
		candidates.append(hovered_enemy)
	var anchor := _commander_position()
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		if a == hovered_enemy or b == hovered_enemy:
			return a == hovered_enemy
		return a.global_position.distance_squared_to(anchor) < b.global_position.distance_squared_to(anchor))
	_assigned.assign(candidates.slice(0, MAX_BARS))

func _place() -> void:
	var cam := get_viewport().get_camera_3d()
	for i in _bars.size():
		var bar := _bars[i]
		if cam == null or i >= _assigned.size() or not is_instance_valid(_assigned[i]) or _assigned[i].is_dead:
			bar.visible = false
			continue
		var e := _assigned[i]
		var world := e.global_position + HEAD_OFFSET
		if cam.is_position_behind(world):
			bar.visible = false
			continue
		bar.max_value = e.health.max_hp
		bar.value = e.health.hp
		bar.position = cam.unproject_position(world) - BAR_SIZE * 0.5
		bar.visible = true

func _commander_position() -> Vector3:
	var c := get_tree().get_first_node_in_group(&"commander") as Node3D
	return c.global_position if c != null else Vector3.ZERO
