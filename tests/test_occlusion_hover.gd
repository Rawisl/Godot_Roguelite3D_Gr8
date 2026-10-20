extends Node3D
## Hover và vật che: 4 tower Cannon, mỗi 2 s đổi tower được hover. Nhấn F6 trên scene này.
## - Tower đang hover không bao giờ tự mờ.
## - Tower đứng phía trước nó (gần camera hơn) mờ.
## - Tower ở xa không mờ.
## - Tower đứng cạnh trong bán kính 2.5 m, phía gần camera, cũng có thể mờ (đúng bán kính của SRS).
## Độ mờ của từng tower in ra Output và hiện góc trái màn hình.

const GRASS := preload("res://art/materials/env_grass.tres")
const CANNON := preload("res://contents/assets/towers/cannon_tower_model.tscn")
const POSITIONS := {
	"Center": Vector3(0, 0, 0),
	"Front": Vector3(0, 0, 3.5),
	"Side": Vector3(3, 0, 0),
	"Far": Vector3(-8, 0, -6),
}
const SWITCH_TIME := 2.0

var _towers := {}
var _order: Array[String] = []
var _index := -1
var _timer := SWITCH_TIME

@onready var _manager: OcclusionManager = $OcclusionManager
@onready var _label: Label = %InfoLabel

func _ready() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	floor_mesh.material_override = GRASS
	add_child(floor_mesh)
	for key in POSITIONS:
		var tower := CANNON.instantiate() as Node3D
		tower.name = key
		tower.position = POSITIONS[key]
		add_child(tower)
		_towers[key] = tower
		_order.append(key)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= SWITCH_TIME:
		_timer = 0.0
		_index = (_index + 1) % _order.size()
		_manager.set_hover_target(_towers[_order[_index]])
	if _timer > 0.5 and _timer - delta <= 0.5:
		_report()

func _report() -> void:
	var parts: Array[String] = []
	for key in _order:
		parts.append("%s %.1f" % [key, _alpha(_towers[key])])
	var line := "Hover %s -> %s" % [_order[_index], ", ".join(parts)]
	print("[OcclusionHover] ", line)
	_label.text = line + "\n(1.0 = đặc, 0.3 = mờ)"

func _alpha(tower: Node3D) -> float:
	for mesh in tower.find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree():
			var a = mesh.get_instance_shader_parameter(&"dither_alpha")
			return 1.0 if a == null else float(a)
	return 1.0
