extends Node

## Visual check of the arrow hit: an arrow from the left hits a dummy every second, on grass,
## seen from the game camera angle. Runs forever; close the window to stop.

const HIT := preload("res://art/vfx/arrow_hit.tscn")

## Seconds per loop.
@export var interval := 1.0

func _ready() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 5.0
	cam.position = Vector3(2.4, 7.1, 6.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.8, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = preload("res://art/materials/env_grass.tres")
	add_child(ground)
	var dummy := MeshInstance3D.new()
	# A thin post, so both the front ring and the back sparks stay in view.
	var post := CylinderMesh.new()
	post.top_radius = 0.08
	post.bottom_radius = 0.08
	post.height = 1.6
	dummy.mesh = post
	dummy.position = Vector3(0, 0.8, 0)
	add_child(dummy)

	var hit: ArrowHit = HIT.instantiate()
	add_child(hit)
	# Arrow comes from the front left, dropping slightly, so the ring faces the camera.
	var dir := Vector3(0.8, -0.2, -0.6).normalized()
	while is_inside_tree():
		hit.play(Vector3(0, 1.1, 0), dir)
		await get_tree().create_timer(interval).timeout
