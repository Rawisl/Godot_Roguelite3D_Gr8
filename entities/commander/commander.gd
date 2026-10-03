extends CharacterBody3D

@export var stats: CharacterStats

## Debug sphere placed at the aim hit point. Leave empty when merging.
@export var debug_aim_marker: Node3D

## Prints the horizontal speed every 0.5s. Turn off when merging.
@export var debug_print_speed: bool = false

## Current aim direction on the XZ plane.
var aim_dir: Vector3 = Vector3.FORWARD

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _debug_last_pos: Vector3
var _debug_timer: float = 0.0

@onready var _aim_pivot: Node3D = $AimPivot

func _ready() -> void:
	_debug_last_pos = global_position

func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
		
	_update_movement(camera, delta)
	move_and_slide()
	
	# Aim after moving to use the current frame's position.
	_update_aim(camera)
	
	if debug_print_speed:
		_debug_report_speed(delta)

func _update_movement(camera: Camera3D, delta: float) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	# Calculate movement direction on the XZ plane relative to the camera.
	var cam_basis := camera.global_transform.basis
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()
	
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var dir := right * input.x + forward * (-input.y)
	velocity.x = dir.x * stats.move_speed
	velocity.z = dir.z * stats.move_speed

	if not is_on_floor():
		velocity.y -= _gravity * delta

func _update_aim(camera: Camera3D) -> void:
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position()
	
	if not viewport.get_visible_rect().has_point(mouse):
		return

	# Raycast from the mouse to a horizontal plane at the feet.
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_dir := camera.project_ray_normal(mouse)
	var hit: Variant = Plane(Vector3.UP, global_position.y).intersects_ray(ray_origin, ray_dir)
	
	if hit == null:
		return 

	var hit_point: Vector3 = hit
	if debug_aim_marker:
		debug_aim_marker.global_position = hit_point

	var to_target := hit_point - global_position
	to_target.y = 0.0
	
	# Ignore if the cursor is exactly at the character's feet.
	if to_target.length_squared() < 0.0001:
		return 

	aim_dir = to_target.normalized()
	_aim_pivot.rotation.y = atan2(-aim_dir.x, -aim_dir.z)

func _debug_report_speed(delta: float) -> void:
	var moved := Vector2(global_position.x - _debug_last_pos.x, global_position.z - _debug_last_pos.z)
	_debug_last_pos = global_position
	_debug_timer += delta
	var flat_velocity := Vector2(velocity.x, velocity.z)
	
	if _debug_timer < 0.5 or flat_velocity.is_zero_approx():
		return
		
	_debug_timer = 0.0
	print("velocity: %.3f m/s | moved: %.3f m/s | expected: %.3f m/s" % [
		flat_velocity.length(), moved.length() / delta, stats.move_speed])
