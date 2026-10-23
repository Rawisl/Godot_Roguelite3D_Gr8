class_name DummyHealStation
extends StaticBody3D

## Dummy Heal Station representing a ground tower with melee attack slots.
## Used for testing AI targeting and melee slot crowd throttling without requiring full build grid.

const MELEE_ARRIVE_DISTANCE: float = 0.6

var health: HealthComponent = null
var melee_slots: TowerMeleeSlots = null


func _init() -> void:
	add_to_group(&"tower")
	add_to_group(&"heal_station")


func _ready() -> void:
	if not is_in_group(&"tower"):
		add_to_group(&"tower")
	if not is_in_group(&"heal_station"):
		add_to_group(&"heal_station")

	_setup_collision_and_mesh()
	_setup_health()
	_setup_melee_slots()


func _setup_collision_and_mesh() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.8
	cyl.height = 2.0
	col.shape = cyl
	add_child(col)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "TempMesh"
	var cmesh := CylinderMesh.new()
	cmesh.top_radius = 0.7
	cmesh.bottom_radius = 0.8
	cmesh.height = 2.0
	mesh_inst.mesh = cmesh
	add_child(mesh_inst)


func _setup_health() -> void:
	if health == null:
		health = HealthComponent.new()
		health.name = "Health"
		health.max_hp = 300
		health.hp = 300
		add_child(health)
		health.died.connect(_on_died)


func _setup_melee_slots() -> void:
	melee_slots = TowerMeleeSlots.new()
	melee_slots.name = "MeleeSlots"

	var p0 := Marker3D.new()
	p0.name = "P0"
	p0.position = Vector3(0.75, 0.0, -1.3)
	melee_slots.add_child(p0)

	var p1 := Marker3D.new()
	p1.name = "P1"
	p1.position = Vector3(1.5, 0.0, 0.0)
	melee_slots.add_child(p1)

	var p2 := Marker3D.new()
	p2.name = "P2"
	p2.position = Vector3(0.75, 0.0, 1.3)
	melee_slots.add_child(p2)

	add_child(melee_slots)


func _on_died() -> void:
	if melee_slots != null:
		melee_slots.release_all()


func accepts_melee() -> bool:
	return health != null and health.hp > 0 and not is_in_group(&"tower_wall")


func claim_melee_slot(attacker: Node3D) -> bool:
	if not accepts_melee():
		return false
	return melee_slots.claim(attacker)


func release_melee_slot(attacker: Node3D) -> void:
	if melee_slots != null:
		melee_slots.release(attacker)


func has_melee_slot(attacker: Node3D) -> bool:
	return melee_slots != null and melee_slots.has(attacker)


func get_melee_slot_position(attacker: Node3D) -> Vector3:
	if melee_slots != null:
		return melee_slots.position_for(attacker)
	return global_position


func get_free_melee_slots() -> int:
	if melee_slots != null:
		return melee_slots.free_count()
	return 0


func get_melee_arrive_distance() -> float:
	return MELEE_ARRIVE_DISTANCE


func take_damage(damage_input: Variant, p_damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> int:
	if health != null:
		return health.take_damage(damage_input, p_damage_type)
	return 0
