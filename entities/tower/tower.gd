class_name Tower
extends StaticBody3D

signal destroyed(tower: Tower)

@export var data: TowerData
var level: int = 1

@onready var health: HealthComponent = %Health
@onready var range_shape: CollisionShape3D = %RangeArea.get_node("CollisionShape3D")
@onready var scan_timer: Timer = %ScanTimer

func _ready() -> void:
	if data == null:
		push_warning("Tower thiếu TowerData")
		return
	apply_level(level)
	health.died.connect(func(): destroyed.emit(self))

func apply_level(new_level: int) -> void:
	level = new_level
	var lv: TowerLevelData = data.levels[level - 1]
	health.max_hp = lv.max_hp
	health.hp = lv.max_hp
	(range_shape.shape as SphereShape3D).radius = lv.attack_range
	scan_timer.wait_time = lv.attack_interval
