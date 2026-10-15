extends Node3D
## Hiệu ứng dựng tower: cứ 1.5 s xây lại Arrow, Cannon, Barricade trên 3 slot. Nhấn F6 trên scene này.
## Cannon và Barricade chưa gắn model trong entities/tower/, scene test gắn tạm model để xem hiệu ứng.

const SLOT := preload("res://systems/build/slot.tscn")
const GRASS := preload("res://art/materials/env_grass.tres")
const TOWERS := [
	[preload("res://entities/tower/arrow.tscn"), null, &"arrow"],
	[preload("res://entities/tower/cannon.tscn"), preload("res://contents/assets/towers/cannon_tower_model.tscn"), &"cannon"],
	[preload("res://entities/tower/barricade.tscn"), preload("res://contents/assets/towers/barricade_tower_model.tscn"), &"barricade"],
]

var _slots: Array[Slot] = []
var _timer := 0.0

func _ready() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	floor_mesh.material_override = GRASS
	add_child(floor_mesh)
	for i in TOWERS.size():
		var slot := SLOT.instantiate() as Slot
		slot.name = "T%d" % i
		slot.position = Vector3(-4.0 + i * 4.0, 0, 0)
		add_child(slot)
		_slots.append(slot)
	_build_all()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 1.5:
		_timer = 0.0
		_build_all()

func _build_all() -> void:
	for i in _slots.size():
		var slot := _slots[i]
		if slot.state != Enums.SlotState.EMPTY:
			slot.clear_tower()
		var tower := (TOWERS[i][0] as PackedScene).instantiate() as Tower
		if TOWERS[i][1] != null:
			tower.get_node(^"Model").add_child((TOWERS[i][1] as PackedScene).instantiate())
		slot.place_tower(tower)
		EventBus.tower_built.emit(slot.slot_id, TOWERS[i][2])
