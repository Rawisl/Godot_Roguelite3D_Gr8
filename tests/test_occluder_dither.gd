extends Node3D
## Chỉ huy giả đi qua lại sau tower Cannon và tiến lại gần một quân địch
## đứng sau cột đá. Nhấn F6 trên scene này.
## - Chỉ huy sau tower Cannon: tower mờ dither, bóng vẫn đặc.
## - Barricade ở góc xa che một điểm hover ngay sau nó: cứ 2 s bật hover thì Barricade mờ, tắt thì đặc lại.
## - Chỉ huy cách quân địch dưới 3 m: cột đá mờ. Trên 3 m: cột đặc lại.
## - Tường phía sau chỉ huy không bao giờ mờ.

const STONE := preload("res://art/materials/struct_stone.tres")
const TOON_DITHER := preload("res://art/shaders/toon_dither.gdshader")
const GRASS := preload("res://art/materials/env_grass.tres")
const CANNON := preload("res://contents/assets/towers/cannon_tower_model.tscn")
const HOVER_TOGGLE := 2.0
const BARRICADE := preload("res://contents/assets/towers/barricade_tower_model.tscn")

var commander: Node3D
var enemy: Node3D
var pillar: MeshInstance3D
var barricade: Node3D
var _hover: Node3D
var _hover_on := false
var _hover_timer := 0.0
var _t := 0.0

func _ready() -> void:
	_add_box(Vector3(30, 0.2, 30), Vector3(0, -0.1, 0), GRASS, false)
	pillar = _add_box(Vector3(1, 4, 1), Vector3(-6, 2, 3), STONE, true)
	_add_box(Vector3(6, 3, 1), Vector3(6, 1.5, -6), STONE, true) # nằm sau, không được mờ
	var tower := CANNON.instantiate() as Node3D
	add_child(tower)
	tower.position = Vector3(5, 0, 3)
	# Barricade đứng trước đường chỉ huy đi, phải mờ như Cannon khi che.
	barricade = BARRICADE.instantiate() as Node3D
	add_child(barricade)
	# Đặt ở góc xa, cách Cannon, cột đá và đường chỉ huy hơn 2.5 m để không lẫn với các vật đó.
	barricade.position = Vector3(-12, 0, -3.5)
	# Điểm hover sát mặt đất ngay sau Barricade, bật tắt mỗi HOVER_TOGGLE giây.
	_hover = Node3D.new()
	add_child(_hover)
	_hover.position = Vector3(-12, 0, -5)
	commander = _add_capsule(Color(0.85, 0.85, 0.85))
	commander.add_to_group(&"commander")
	# Đứng sát mép cột: cột 2.5 m (occlusion_radius) đã đủ rộng để quân bị coi là bị che,
	# còn chỉ huy đi bên phải thì đường nhìn của chỉ huy không chạm cột.
	enemy = _add_capsule(Color(0.8, 0.25, 0.2))
	enemy.add_to_group(&"enemy")
	enemy.position = Vector3(-4.6, 0.9, 1.0)

func _process(delta: float) -> void:
	_t += delta
	_hover_timer += delta
	if _hover_timer >= HOVER_TOGGLE:
		_hover_timer = 0.0
		_hover_on = not _hover_on
		($OcclusionManager as OcclusionManager).set_hover_target(_hover if _hover_on else null)
	# x chạy từ -2.2 (cách quân 2.4 m) tới 12, ra khỏi vùng 2.5 m quanh Cannon ở hai đầu.
	commander.position = Vector3(4.9 + 7.1 * sin(_t * 0.5), 0.9, 1.0)

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
