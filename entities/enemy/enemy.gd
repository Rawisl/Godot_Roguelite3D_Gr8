class_name Enemy
extends CharacterBody3D

@export var data: EnemyData

@onready var health: HealthComponent = %Health
@onready var nav: NavigationAgent3D = %NavAgent

func _ready() -> void:
	if data == null:
		#Chạy game làm sao output ko có cái dòng báo warning này là file .tres được nhận thành công trong scene
		push_warning("Enemy thiếu EnemyData")
		return
	health.max_hp = data.max_hp
	health.hp = data.max_hp
	nav.radius = data.avoid_radius
