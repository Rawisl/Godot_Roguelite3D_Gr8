extends Node3D

## Test environment generator for Commander Combat & Movement mechanics.

const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")


func _ready() -> void:
	_spawn_test_wall()
	_spawn_dummy_enemies()


## Spawns a physical wall on Layer 1 (World) to test Dodge blocking.
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


## Spawns 4 Grunts as test dummies to verify cleave limit, knockback, and damage types.
func _spawn_dummy_enemies() -> void:
	# 4 Grunt đặt san sát nhau trước mặt Commander để test cleave cap = 3
	var x_offsets: Array[float] = [-1.5, -0.5, 0.5, 1.5]

	for i in range(x_offsets.size()):
		var dummy: Enemy = GRUNT_SCENE.instantiate() as Enemy
		dummy.name = "DummyGrunt_%d" % (i + 1)
		dummy.position = Vector3(x_offsets[i], 0.0, -2.0)
		# Phải add_child trước để các biến @onready (như dummy.health) được khởi tạo
		add_child(dummy)
		dummy.speed_multiplier = 0.0
		
		dummy.health.max_hp = 99999
		dummy.health.hp = 99999

		dummy.health.damaged.connect(func(amount: int, info: DamageInfo):
			var type_str := "SLASH"
			if info != null:
				match info.damage_type:
					Enums.DamageType.PIERCE: type_str = "PIERCE"
					Enums.DamageType.BLAST: type_str = "BLAST"
					Enums.DamageType.SLASH: type_str = "SLASH"
					Enums.DamageType.TRUE: type_str = "TRUE"

			print("[HIT] %s trúng đòn! Sát thương: %d | Loại: %s | Knockback: %.1f m | HP: %d/%d | Vị trí: (%.2f, %.2f)" % [
				dummy.name,
				amount,
				type_str,
				info.knockback_force if info != null else 0.0,
				dummy.health.hp,
				dummy.health.max_hp,
				dummy.global_position.x,
				dummy.global_position.z
			])
		)
