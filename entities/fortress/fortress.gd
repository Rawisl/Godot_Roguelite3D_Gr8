class_name Fortress
extends StaticBody3D

@export var stats: FortressStats

@onready var health: HealthComponent = %Health
var _destroyed: bool = false

func _ready() -> void:
	health.max_hp = stats.max_hp
	health.hp = stats.max_hp
	health.hp_changed.connect(func(hp, mx): EventBus.fortress_hp_changed.emit(hp, mx))
	health.died.connect(_on_died)
	EventBus.fortress_hp_changed.emit(health.hp, health.max_hp)

func _on_died() -> void:
	if _destroyed:
		return
	_destroyed = true
	EventBus.fortress_destroyed.emit()

func take_damage(damage_input: Variant, p_damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> void:
	if _destroyed:
		return
	var info: DamageInfo = null
	if damage_input is DamageInfo:
		info = damage_input
	elif damage_input is int:
		info = DamageInfo.new(damage_input, p_damage_type)

	if info == null:
		return

	var taken := health.take_damage(info)
	var type_name := &"SLASH"
	match info.damage_type:
		Enums.DamageType.PIERCE: type_name = &"PIERCE"
		Enums.DamageType.BLAST: type_name = &"BLAST"
		Enums.DamageType.SLASH: type_name = &"SLASH"
		Enums.DamageType.MAGIC: type_name = &"MAGIC"
		Enums.DamageType.TRAP: type_name = &"TRAP"
		Enums.DamageType.TRUE: type_name = &"TRUE"

	var src_name := StringName(info.source.name if info.source != null else "")
	EventBus.fortress_damaged.emit(taken, type_name, src_name)
