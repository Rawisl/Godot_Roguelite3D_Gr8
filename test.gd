extends Node3D

## Test environment generator for Commander Combat & Movement mechanics.


func _ready() -> void:
	_spawn_test_wall()
	_spawn_dummy_enemies()


## Spawns a physical wall on Layer 1 (World) to test Dodge blocking (CMB-06).
func _spawn_test_wall() -> void:
	var wall := StaticBody3D.new()
	wall.name = "TestWall"
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector3(0.0, 1.0, 5.0)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(8.0, 2.0, 1.0)
	shape.shape = box_shape
	wall.add_child(shape)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_shape.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.4, 0.8) # Blue wall
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	wall.add_child(mesh_inst)

	add_child(wall)


## Spawns 4 dummy targets on Layer 3 (Enemy) to verify cleave limit and damage types.
func _spawn_dummy_enemies() -> void:
	# 4 targets spaced closely to test max_targets = 3 (CMB-09)
	var x_offsets: Array[float] = [-1.5, -0.5, 0.5, 1.5]

	for i in range(x_offsets.size()):
		var dummy := CharacterBody3D.new()
		dummy.name = "DummyEnemy_%d" % (i + 1)
		dummy.add_to_group("enemy")
		dummy.collision_layer = 4 # Layer 3: enemy (1 << 2 = 4)
		dummy.collision_mask = 1
		dummy.position = Vector3(x_offsets[i], 0.9, -2.0)

		# Custom health tracking for test verification
		dummy.set_meta("hp", 40)
		dummy.set_meta("max_hp", 40)

		var shape := CollisionShape3D.new()
		var cap_shape := CapsuleShape3D.new()
		cap_shape.radius = 0.35
		cap_shape.height = 1.8
		shape.shape = cap_shape
		dummy.add_child(shape)

		var mesh_inst := MeshInstance3D.new()
		var cap_mesh := CapsuleMesh.new()
		cap_mesh.radius = 0.35
		cap_mesh.height = 1.8
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.2, 0.2) # Red enemy
		cap_mesh.material = mat
		mesh_inst.mesh = cap_mesh
		dummy.add_child(mesh_inst)

		# Attach damage handling method dynamically
		dummy.set_script(preload("res://tests/dummy_target.gd") if ResourceLoader.exists("res://tests/dummy_target.gd") else null)

		# Fallback if no separate script: provide take_damage via dynamic callable
		add_child(dummy)
