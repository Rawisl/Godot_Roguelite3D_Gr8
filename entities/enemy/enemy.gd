class_name Enemy
extends CharacterBody3D

## Base class for enemies (SRS 3.7.1, 3.7.4, v1.4).
## Managed by TV2 (Enemy & Wave).

@export var data: EnemyData

var current_target: Node3D = null
var current_target_position: Vector3 = Vector3.ZERO
var has_target_position: bool = false

## Quãng đường nav đã đi được hoặc còn lại (SRS 3.6.5, TWR-15)
var nav_progress: float = 0.0
var speed_multiplier: float = 1.0
var is_dead: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _path_timer: float = 0.0
const PATH_UPDATE_INTERVAL: float = 0.3  # SRS 3.7.4

@onready var health: HealthComponent = %Health
@onready var nav: NavigationAgent3D = %NavAgent

func _ready() -> void:
	add_to_group("enemy")
	
	if data == null:
		push_warning("Enemy thiếu EnemyData!")
		return
		
	health.max_hp = data.base_hp
	health.hp = data.base_hp
	health.died.connect(_on_died)
	
	nav.radius = data.avoid_radius
	nav.path_desired_distance = 0.5
	nav.target_desired_distance = 1.0
	
	# Đợi navigation map đồng bộ ở frame đầu
	_setup_navigation.call_deferred()

func _setup_navigation() -> void:
	await get_tree().physics_frame
	if not has_target_position and current_target == null:
		_find_default_target()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Trọng lực
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
		
	_update_target_tracking(delta)
	_update_navigation_movement(delta)
	move_and_slide()

func _update_target_tracking(delta: float) -> void:
	_path_timer += delta
	if _path_timer >= PATH_UPDATE_INTERVAL:
		_path_timer = 0.0
		if current_target != null and is_instance_valid(current_target):
			nav.target_position = current_target.global_position
		elif has_target_position:
			nav.target_position = current_target_position
		else:
			_find_default_target()

func _update_navigation_movement(_delta: float) -> void:
	if nav.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0.0, 1.0)
		velocity.z = move_toward(velocity.z, 0.0, 1.0)
		return
		
	var next_path_pos := nav.get_next_path_position()
	var move_dir := (next_path_pos - global_position)
	move_dir.y = 0.0
	
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		var move_speed: float = (data.move_speed if data else 3.5) * speed_multiplier
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		
		# Xoay mặt về hướng di chuyển mượt mà
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 0.2)
		
		# Cập nhật nav_progress (khoảng cách còn lại tới đích)
		nav_progress = nav.distance_to_target()
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _find_default_target() -> void:
	# Mặc định quái tìm mục tiêu là Fortress (SRS 3.7.3, ETG-06)
	var fortress := get_tree().get_first_node_in_group("fortress") as Node3D
	if fortress != null:
		set_target(fortress)
	else:
		# Nếu chưa có Fortress, đi về cực trái (x âm, hướng về thành)
		set_target_position(Vector3(-15.0, global_position.y, 0.0))


## ===================================================================
## FUNCTIONS (Thêm ở cuối file theo quy ước nhóm)
## ===================================================================

## Thiết lập mục tiêu là một Node cụ thể (Fortress, Tower, Commander, Barricade)
func set_target(target_node: Node3D) -> void:
	current_target = target_node
	has_target_position = false
	if current_target != null:
		nav.target_position = current_target.global_position

## Thiết lập tọa độ vị trí mục tiêu
func set_target_position(target_pos: Vector3) -> void:
	current_target = null
	current_target_position = target_pos
	has_target_position = true
	nav.target_position = target_pos

## Nhận sát thương
func take_damage(amount: int, _damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> void:
	if is_dead:
		return
	health.take_damage(amount)

## Xử lý khi chết
func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)
	
	# Phát signal ra EventBus (SRS RWD-01, 3.7.7)
	if data != null:
		EventBus.enemy_died.emit(data.id, global_position, data.gold_reward, data.prestige_reward, false)
	
	queue_free()
