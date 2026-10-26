extends Control
## Edge arrows for targets outside the camera frame: the boss, and the Fortress while under attack.

const FORTRESS_ALERT_TIME := 3.0
const SAFE_MARGIN := 0.03

var _fortress_alert_until := -1.0

@onready var _boss_arrow: Control = %BossArrow
@onready var _boss_pointer: Node2D = %BossPointer
@onready var _fortress_arrow: Control = %FortressArrow
@onready var _fortress_pointer: Node2D = %FortressPointer
@onready var _boss_label: Label = %BossLabel
@onready var _fortress_label: Label = %FortressLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_label.text = tr(&"hud.offscreen.boss")
	_fortress_label.text = tr(&"hud.fortress")
	_boss_arrow.visible = false
	_fortress_arrow.visible = false
	EventBus.fortress_damaged.connect(_on_fortress_damaged)

func _on_fortress_damaged(_amount: int, _type: StringName, _source: StringName) -> void:
	_fortress_alert_until = TimeManager.pausable_real_time + FORTRESS_ALERT_TIME

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	_place(_boss_arrow, _boss_pointer, cam, _boss())
	var attacked := TimeManager.pausable_real_time < _fortress_alert_until
	var on_side := _place(_fortress_arrow, _fortress_pointer, cam, _fortress() if attacked else null)
	_separate(on_side)

func _separate(on_side: bool) -> void:
	if not (_boss_arrow.visible and _fortress_arrow.visible):
		return
	if _boss_arrow.position.distance_to(_fortress_arrow.position) >= _fortress_arrow.size.x:
		return
	var step := Vector2(0.0, _fortress_arrow.size.y) if on_side else Vector2(_fortress_arrow.size.x, 0.0)
	var moved := _boss_arrow.position + step
	var limit := size - _fortress_arrow.size
	if moved.x > limit.x or moved.y > limit.y:
		moved = _boss_arrow.position - step
	_fortress_arrow.position = moved

func _place(arrow: Control, pointer: Node2D, cam: Camera3D, target: Node3D) -> bool:
	if cam == null or target == null:
		arrow.visible = false
		return false
	var margin := size * SAFE_MARGIN
	var frame := Rect2(margin, size - margin * 2.0)
	var point := cam.unproject_position(target.global_position)
	if frame.has_point(point):
		arrow.visible = false
		return false
	var half := arrow.size * 0.5
	var inner := frame.grow_individual(-half.x, -half.y, -half.x, -half.y)
	var center := inner.get_center()
	var dir := point - center
	if dir.is_zero_approx():
		arrow.visible = false
		return false
	# Scale the direction until it touches the nearest edge of the inner frame.
	var t := INF
	if not is_zero_approx(dir.x):
		t = minf(t, inner.size.x * 0.5 / absf(dir.x))
	if not is_zero_approx(dir.y):
		t = minf(t, inner.size.y * 0.5 / absf(dir.y))
	arrow.position = center + dir * t - half
	pointer.rotation = dir.angle()
	arrow.visible = true
	return absf(dir.x) * inner.size.y >= absf(dir.y) * inner.size.x

func _boss() -> Node3D:
	var boss := get_tree().get_first_node_in_group(&"boss") as Node3D
	if boss == null or (&"is_dead" in boss and boss.is_dead):
		return null
	return boss

func _fortress() -> Node3D:
	var f := get_tree().get_first_node_in_group(&"fortress") as Fortress
	return f if f != null and not f.is_destroyed() else null
