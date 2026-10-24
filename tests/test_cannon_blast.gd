extends Node

## Visual check of the cannon blast: a shell lands on a dummy every 1.5 s, on grass,
## seen from the game camera angle. Runs forever; close the window to stop.

const BLAST := preload("res://art/vfx/cannon_blast.tscn")

## Seconds per loop.
@export var interval := 1.5
## Blast radius, as from the Cannon level data.
@export var radius := 2.0

func _ready() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 8.0
	cam.position = Vector3(2.4, 7.1, 6.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.5, 0))
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
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 1.6, 0.8)
	dummy.mesh = box
	dummy.position = Vector3(0, 0.8, 0)
	add_child(dummy)

	var blast: CannonBlast = BLAST.instantiate()
	add_child(blast)
	# Shell comes in from the left (the Fortress side) on a falling arc.
	var dir := Vector3(1, -1, 0).normalized()
	while is_inside_tree():
		blast.play(Vector3(-0.5, 1.1, 0), dir, radius)
		await get_tree().create_timer(interval).timeout
