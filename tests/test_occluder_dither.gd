extends Node3D
## Chỉ huy giả đi qua lại sau tower Cannon và tiến lại gần một quân địch
## đứng sau cột đá. Nhấn F6 trên scene này.
## - Chỉ huy sau tower: tower mờ dither, bóng vẫn đặc.
## - Chỉ huy cách quân địch dưới 3 m: cột đá mờ. Trên 3 m: cột đặc lại.
## - Tường phía sau chỉ huy không bao giờ mờ.

const STONE := preload("res://art/materials/struct_stone.tres")
const TOON_DITHER := preload("res://art/shaders/toon_dither.gdshader")
const GRASS := preload("res://art/materials/env_grass.tres")
const CANNON := preload("res://contents/assets/towers/cannon_tower_model.tscn")

var commander: Node3D
var enemy: Node3D
var pillar: MeshInstance3D
var _t := 0.0

func _ready() -> void:
	_add_box(Vector3(30, 0.2, 30), Vector3(0, -0.1, 0), GRASS, false)
	pillar = _add_box(Vector3(1, 4, 1), Vector3(-6, 2, 3), STONE, true)
	_add_box(Vector3(6, 3, 1), Vector3(6, 1.5, -6), STONE, true) # nằm sau, không được mờ
	var tower := CANNON.instantiate() as Node3D
	add_child(tower)
	tower.position = Vector3(5, 0, 3)
	commander = _add_capsule(Color(0.85, 0.85, 0.85))
	commander.add_to_group(&"commander")
	# Đứng sát mép cột: cột 2.5 m (occlusion_radius) đã đủ rộng để quân bị coi là bị che,
	# còn chỉ huy đi bên phải thì đường nhìn của chỉ huy không chạm cột.
	enemy = _add_capsule(Color(0.8, 0.25, 0.2))
	enemy.add_to_group(&"enemy")
	enemy.position = Vector3(-4.6, 0.9, 1.0)

func _process(delta: float) -> void:
	_t += delta
	# x chạy từ -2.2 (cách quân 2.4 m) tới 9.0.
	commander.position = Vector3(3.4 + 5.6 * sin(_t * 0.6), 0.9, 1.0)

func _add_box(size: Vector3, pos: Vector3, mat: Material, occluder: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	if occluder:
		# Vật che dùng bản toon có dither, giống tower_material.
		var dither_mat := (mat as ShaderMaterial).duplicate() as ShaderMaterial
		dither_mat.shader = TOON_DITHER
		mesh.material_override = dither_mat
		mesh.add_to_group(&"occluder")
	add_child(mesh)
	return mesh

func _add_capsule(color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	add_child(mesh)
	return mesh
