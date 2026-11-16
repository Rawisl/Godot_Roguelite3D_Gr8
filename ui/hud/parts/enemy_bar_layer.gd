class_name EnemyBarLayer
extends Control
## Enemy HP bars: shown after a hit or on hover, hidden SHOW_TIME later. Hovering an enemy for
## GameConfig.hover_info_delay also shows its name and traits above its bar.
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
var _hover_since := 0.0
var _hover_shown_for: Node = null

@onready var _hover_info: PanelContainer = %HoverInfo
@onready var _hover_name: Label = %HoverName
@onready var _hover_badges: HBoxContainer = %HoverBadges

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
	# The bars are added after it, so keep the hover box drawn on top of them.
	move_child(_hover_info, -1)
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
	_place_hover_info()

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

## Name and traits of the hovered enemy, above its bar. Not for the boss, which has BossBar.
func _place_hover_info() -> void:
	var enemy := hovered as Enemy if is_instance_valid(hovered) else null
	if enemy == null or enemy.is_dead or enemy.is_in_group(&"boss"):
		_hover_shown_for = null
		_hover_info.visible = false
		return
	if enemy != _hover_shown_for:
		_hover_shown_for = enemy
		_hover_since = TimeManager.real_time
		_fill_hover_info(enemy)
	var cam := get_viewport().get_camera_3d()
	var world := enemy.global_position + HEAD_OFFSET
	if cam == null or cam.is_position_behind(world) or TimeManager.real_time - _hover_since < GameConfig.hover_info_delay:
		_hover_info.visible = false
		return
	_hover_info.reset_size()
	var above := cam.unproject_position(world) - Vector2(_hover_info.size.x * 0.5, BAR_SIZE.y + _hover_info.size.y + 4.0)
	_hover_info.position = above
	_hover_info.visible = true

func _fill_hover_info(enemy: Enemy) -> void:
	var id := enemy.data.id if enemy.data != null else &""
	_hover_name.text = EnemyTraits.display_name(id)
	var traits := EnemyTraits.of(id)
	var badges := _hover_badges.get_children()
	for i in badges.size():
		if i < traits.size():
			(badges[i] as TraitBadge).show_trait(traits[i])
		else:
			(badges[i] as Control).visible = false
	_hover_badges.visible = not traits.is_empty()

func _commander_position() -> Vector3:
	var c := get_tree().get_first_node_in_group(&"commander") as Node3D
	return c.global_position if c != null else Vector3.ZERO
