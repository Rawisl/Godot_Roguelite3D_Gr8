class_name DummyHealStation
extends StaticBody3D

## Dummy Heal Station representing TOWER_GROUND with 3 melee attack slots (HLT-10, EN-01).
## Used for testing AI targeting and melee slot crowd throttling without requiring full build grid.

var health: HealthComponent = null

## Slot owners: attacker holding the slot (null when free). Max capacity is GameConfig.max_attackers_per_tower (3).
var _owners: Array = []
var _local_offsets: Array[Vector3] = []
var _stand_off: float = 1.2


func _init() -> void:
	add_to_group(&"tower")
	add_to_group(&"tower_ground")
	add_to_group(&"heal_station")


func _ready() -> void:
	if not is_in_group(&"tower"):
		add_to_group(&"tower")
	if not is_in_group(&"tower_ground"):
		add_to_group(&"tower_ground")
	if not is_in_group(&"heal_station"):
		add_to_group(&"heal_station")

	_setup_health()
	_setup_melee_slots()


func _setup_health() -> void:
	if health == null:
		health = HealthComponent.new()
		health.name = "Health"
		health.max_hp = 300  # HLT-07: heal tower base HP
		health.hp = 300
		add_child(health)
		health.died.connect(_on_died)


func _setup_melee_slots() -> void:
	var slot_count: int = GameConfig.max_attackers_per_tower if GameConfig != null else 3
	_owners.resize(slot_count)
	_owners.fill(null)

	_local_offsets.clear()
	# Distribute 3 slots around the station (+X towards spawn, +Z left, -Z right)
	for i in range(slot_count):
		var angle: float = (TAU / float(slot_count)) * float(i)
		_local_offsets.append(Vector3(cos(angle) * _stand_off, 0.0, sin(angle) * _stand_off))


func _clean_invalid_owners() -> void:
	for i in range(_owners.size()):
		if _owners[i] != null and not is_instance_valid(_owners[i]):
			_owners[i] = null


func claim_melee_slot(attacker: Node3D) -> bool:
	_clean_invalid_owners()
	if attacker == null or not is_instance_valid(attacker):
		return false
	if health != null and health.hp <= 0:
		return false
	if has_melee_slot(attacker):
		return true

	var best_idx: int = -1
	var best_dist: float = INF
	for i in range(_owners.size()):
		if _owners[i] == null:
			var slot_pos := global_position + _local_offsets[i]
			var d := attacker.global_position.distance_squared_to(slot_pos)
			if d < best_dist:
				best_dist = d
				best_idx = i

	if best_idx == -1:
		return false

	_owners[best_idx] = attacker
	if not attacker.tree_exiting.is_connected(release_melee_slot.bind(attacker)):
		attacker.tree_exiting.connect(release_melee_slot.bind(attacker), CONNECT_ONE_SHOT)

	return true


func release_melee_slot(attacker: Node3D) -> void:
	_clean_invalid_owners()
	for i in range(_owners.size()):
		if _owners[i] == attacker:
			_owners[i] = null


func has_melee_slot(attacker: Node3D) -> bool:
	_clean_invalid_owners()
	return _owners.has(attacker)


func get_melee_slot_position(attacker: Node3D) -> Vector3:
	var idx := _owners.find(attacker)
	if idx != -1 and idx < _local_offsets.size():
		return global_position + _local_offsets[idx]
	return global_position


func get_free_melee_slots() -> int:
	_clean_invalid_owners()
	var free_count := 0
	for o in _owners:
		if o == null:
			free_count += 1
	return free_count


func release_all_slots() -> void:
	_owners.fill(null)


func take_damage(damage_input: Variant, p_damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> int:
	if health == null:
		return 0
	return health.take_damage(damage_input, p_damage_type)


func _on_died() -> void:
	release_all_slots()
