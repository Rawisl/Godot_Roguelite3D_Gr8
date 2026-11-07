extends Node

## Automated test runner verifying the corridor camera_bounds and camera sizes:
## - focus is clamped inside the hand-placed rectangle
## - Frontline sees 12-14 m each side of the commander along the corridor
## - Overview keeps the full corridor width in frame anywhere inside the bounds
## - Frontline keeps the commander in frame next to either wall
## - Overview at the bounds' ends shows the Fortress and the far end of the spawn zone
## - Overview is larger than Frontline

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var cam: Camera3D

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED CAMERA BOUNDS TEST                    ")
	print("=======================================================")
	get_window().size = Vector2i(1920, 1080)

	var level: Node3D = LEVEL_SCENE.instantiate()
	add_child(level)
	var bounds: CameraBounds = level.get_node("CameraBounds")
	cam = level.get_node("CameraRig/Camera3D")
	cam.top_level = true
	await get_tree().process_frame

	var r := bounds.get_rect()
	var clamped := bounds.clamp_focus(Vector3(100, 0, -100))
	assert_true(is_equal_approx(clamped.x, r.end.x) and is_equal_approx(clamped.z, r.position.y), "focus is clamped to the rectangle")
	assert_true(bounds.camera_size_overview > bounds.camera_size_frontline, "overview is larger than Frontline")

	_aim(bounds, Vector3.ZERO, bounds.camera_size_frontline)
	var left := _visible_reach(Vector3.LEFT)
	var right := _visible_reach(Vector3.RIGHT)
	assert_true(left >= 12.0 and left <= 14.0 and right >= 12.0 and right <= 14.0,
		"Frontline sees %.1f m left, %.1f m right (12-14 m)" % [left, right])

	# Corridor 23.5 m wide: floor edge at 11.75 m, wall (3 m tall at the back) at 12.25 m.
	var width_ok := true
	for x in [r.position.x, 0.0, r.end.x]:
		for z in [r.position.y, 0.0, r.end.y]:
			_aim(bounds, Vector3(x, 0, z), bounds.camera_size_overview)
			for p in [Vector3(x, 0, -11.75), Vector3(x, 0, 11.75), Vector3(x, 3, -12.25), Vector3(x, 0, 12.25)]:
				width_ok = width_ok and cam.is_position_in_frustum(p)
	assert_true(width_ok, "overview keeps the corridor width in frame")

	# Frontline follows the commander across the corridor: at either wall they stay well inside the frame.
	var inner := Rect2(Vector2(1920, 1080) * 0.075, Vector2(1920, 1080) * 0.85)
	var walls_ok := true
	for z in [-11.25, 11.25]:
		var feet := Vector3(0, 0, z)
		cam.global_position = bounds.camera_position_for(feet, true)
		cam.size = bounds.camera_size_frontline
		for p in [feet, feet + Vector3(0, 2, 0)]:
			walls_ok = walls_ok and inner.has_point(cam.unproject_position(p))
	assert_true(walls_ok, "Frontline keeps the commander in frame next to either wall")

	_aim(bounds, Vector3(-100, 0, 0), bounds.camera_size_overview)
	var fortress: Node3D = level.get_node("NavigationRegion3D/Geometry/Fortress")
	assert_true(cam.is_position_in_frustum(fortress.global_position + Vector3(-1.5, 0, 0)), "overview at the left bound shows the Fortress")

	_aim(bounds, Vector3(100, 0, 0), bounds.camera_size_overview)
	var spawn: Area3D = level.get_node("SpawnZone")
	assert_true(cam.is_position_in_frustum(spawn.global_position + Vector3(5.5, -2, 0)), "overview at the right bound shows the spawn end")

	level.queue_free()
	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

func _aim(bounds: CameraBounds, focus: Vector3, size: float) -> void:
	cam.global_position = bounds.camera_position_for(focus)
	cam.size = size
	_focus = bounds.clamp_focus(focus)

var _focus := Vector3.ZERO

## Distance from the focus along dir before the ground point leaves the frame.
func _visible_reach(dir: Vector3) -> float:
	var d := 0.0
	while d < 60.0 and cam.is_position_in_frustum(_focus + dir * (d + 0.1)):
		d += 0.1
	return d

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)
