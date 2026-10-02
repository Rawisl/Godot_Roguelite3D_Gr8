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

func take_damage(amount: int) -> void:
	health.take_damage(amount)
