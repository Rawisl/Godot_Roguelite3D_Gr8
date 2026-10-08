extends CharacterBody3D

@export var stats: CharacterStats

@export var debug_aim_marker: Node3D
@export var debug_print_speed: bool = false

var aim_dir: Vector3 = Vector3.FORWARD
var is_commander_mode: bool = false

# Dodge state
var is_dodging: bool = false
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO

# Combat & Combo state
var is_attacking: bool = false
var current_combo_hit: int = 1
var _attack_timer: float = 0.0
var _strike_timer: float = 0.0
var _has_struck: bool = false
var _combo_reset_timer: float = 0.0
var _has_buffered_attack: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _debug_last_pos: Vector3
var _debug_timer: float = 0.0

const COLLISION_LAYER_ENEMY: int = 3
const WIND_UP_RATIO: float = 0.25 

@onready var _aim_pivot: Node3D = %AimPivot
@onready var _sword_area: Area3D = %SwordArea
@onready var _anim_player: AnimationPlayer = %AnimationPlayer
@onready var _facing_mesh: Node3D = %PlaceholderFacing
@onready var health: HealthComponent = %Health


func _ready() -> void:
	add_to_group(&"commander")
	_debug_last_pos = global_position
	_setup_health()


func _setup_health() -> void:
	if stats != null:
		health.max_hp = stats.commander_max_hp
		health.hp = stats.commander_max_hp

	health.hp_changed.connect(_on_hp_changed)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	_update_cooldowns_and_timers(delta)

	if is_commander_mode:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if is_dodging:
		_update_dodge_movement(delta)
	else:
		_check_dodge_input(camera)
		_check_attack_input()
		_update_movement(camera, delta)

	move_and_slide()
	_update_aim(camera)

	if debug_print_speed:
		_debug_report_speed(delta)


func _update_cooldowns_and_timers(delta: float) -> void:
	# Dodge cooldown
	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
		var total_cd := stats.dodge_cooldown if stats else 1.5
		EventBus.skill_cooldown_changed.emit(&"dodge", _dodge_cooldown_timer, total_cd)

	# Active strike timer
	if is_attacking and not _has_struck:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			_has_struck = true
			_execute_sword_strike(current_combo_hit)

	# Attack action total timer
	if is_attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_end_attack()

	# Combo expiration timer
	if not is_attacking and _combo_reset_timer > 0.0:
		_combo_reset_timer -= delta
		if _combo_reset_timer <= 0.0:
			current_combo_hit = 1


func _check_dodge_input(camera: Camera3D) -> void:
	if is_commander_mode or is_dodging or _dodge_cooldown_timer > 0.0:
		return

	if Input.is_action_just_pressed(&"dodge"):
		if is_attacking:
			_interrupt_attack()
		_start_dodge(camera)


func _start_dodge(camera: Camera3D) -> void:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")

	if not input.is_zero_approx():
		var cam_basis := camera.global_transform.basis
		var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
		_dodge_dir = (right * input.x + forward * (-input.y)).normalized()
	else:
		_dodge_dir = -aim_dir

	is_dodging = true
	_dodge_timer = stats.dodge_iframe if stats else 0.3
	_dodge_cooldown_timer = stats.dodge_cooldown if stats else 1.5

	set_collision_mask_value(COLLISION_LAYER_ENEMY, false)

	var total_cd := stats.dodge_cooldown if stats else 1.5
	EventBus.skill_cooldown_changed.emit(&"dodge", _dodge_cooldown_timer, total_cd)


func _update_dodge_movement(delta: float) -> void:
	var dodge_dist := stats.dodge_distance if stats else 4.0
	var dodge_duration := stats.dodge_iframe if stats else 0.3
	var dodge_speed := dodge_dist / maxf(0.01, dodge_duration)

	velocity.x = _dodge_dir.x * dodge_speed
	velocity.z = _dodge_dir.z * dodge_speed

	if not is_on_floor():
		velocity.y -= _gravity * delta

	_dodge_timer -= delta
	if _dodge_timer <= 0.0:
		_end_dodge()


func _end_dodge() -> void:
	is_dodging = false
	_dodge_timer = 0.0
	set_collision_mask_value(COLLISION_LAYER_ENEMY, true)


func _update_movement(camera: Camera3D, delta: float) -> void:
	if is_attacking:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * delta
		return

	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var speed := stats.move_speed if stats else 6.0

	var cam_basis := camera.global_transform.basis
	var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
	var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()

	var dir := right * input.x + forward * (-input.y)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if not is_on_floor():
		velocity.y -= _gravity * delta


func _update_aim(camera: Camera3D) -> void:
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position()

	if not viewport.get_visible_rect().has_point(mouse):
		return

	var ray_origin := camera.project_ray_origin(mouse)
	var ray_dir := camera.project_ray_normal(mouse)
	var hit: Variant = Plane(Vector3.UP, global_position.y).intersects_ray(ray_origin, ray_dir)

	if hit == null:
		return

	var hit_point: Vector3 = hit
	if debug_aim_marker:
		debug_aim_marker.global_position = hit_point

	var to_target := hit_point - global_position
	to_target.y = 0.0

	if to_target.length_squared() < 0.0001:
		return

	aim_dir = to_target.normalized()
	_aim_pivot.rotation.y = atan2(-aim_dir.x, -aim_dir.z)


func _check_attack_input() -> void:
	if is_commander_mode or is_dodging:
		return

	if Input.is_action_just_pressed(&"attack"):
		if not is_attacking:
			_start_attack(current_combo_hit)
		else:
			# Cho phép buffer trong combo window mà không lo timeout sớm
			var window := stats.combo_window if stats else 0.35
			if _attack_timer <= window:
				_has_buffered_attack = true


func _start_attack(hit_index: int) -> void:
	is_attacking = true
	current_combo_hit = hit_index
	_has_buffered_attack = false
	_has_struck = false
	
	var interval := stats.attack_interval if stats else 0.45
	_attack_timer = interval
	_strike_timer = interval * WIND_UP_RATIO
	_combo_reset_timer = 0.0

	_play_attack_animation(current_combo_hit)


func _end_attack() -> void:
	is_attacking = false
	_attack_timer = 0.0
	_has_struck = false

	if _has_buffered_attack:
		_has_buffered_attack = false
		var next_hit := (current_combo_hit % 3) + 1
		_start_attack(next_hit)
	else:
		if current_combo_hit >= 3:
			current_combo_hit = 1
			_combo_reset_timer = 0.0
		else:
			_combo_reset_timer = stats.combo_reset_time if stats else 0.6


func _interrupt_attack() -> void:
	is_attacking = false
	_attack_timer = 0.0
	_has_struck = false
	_has_buffered_attack = false
	_combo_reset_timer = stats.combo_reset_time if stats else 0.6


func _play_attack_animation(combo_step: int) -> void:
	var anim_name := "attack_%d" % combo_step
	if _anim_player != null and _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)
	else:
		_procedural_attack_feedback(combo_step)


func _procedural_attack_feedback(combo_step: int) -> void:
	if _facing_mesh == null:
		return

	var tween := create_tween()
	var base_pos := Vector3(0.0, 1.3, -0.55)

	match combo_step:
		1:
			tween.tween_property(_facing_mesh, "position", base_pos + Vector3(-0.15, 0.0, -0.35), 0.08)
			tween.tween_property(_facing_mesh, "position", base_pos, 0.12)
		2:
			tween.tween_property(_facing_mesh, "position", base_pos + Vector3(0.15, 0.0, -0.35), 0.08)
			tween.tween_property(_facing_mesh, "position", base_pos, 0.12)
		3:
			tween.tween_property(_facing_mesh, "position", base_pos + Vector3(0.0, 0.0, -0.55), 0.10)
			tween.parallel().tween_property(_facing_mesh, "scale", Vector3(1.3, 1.3, 1.3), 0.10)
			tween.tween_property(_facing_mesh, "position", base_pos, 0.15)
			tween.parallel().tween_property(_facing_mesh, "scale", Vector3.ONE, 0.15)


func _execute_sword_strike(combo_step: int) -> void:
	if _sword_area == null or stats == null:
		return

	var max_range: float = stats.sword_range
	var half_arc_rad: float = deg_to_rad(stats.sword_arc_deg * 0.5)
	var max_targets: int = stats.sword_max_targets

	var damage_amount: int = stats.sword_damage
	var knockback: float = 0.0

	if combo_step == 3:
		damage_amount = roundi(float(stats.sword_damage) * stats.combo_hit3_mult)
		knockback = stats.combo_hit3_knockback

	var candidates: Array[Dictionary] = []
	var bodies := _sword_area.get_overlapping_bodies()

	for body in bodies:
		if body == self or not body.has_method("take_damage"):
			continue

		var to_target := body.global_position - global_position
		to_target.y = 0.0
		var dist := to_target.length()

		if dist > max_range:
			continue

		var angle: float = 0.0
		if not to_target.is_zero_approx():
			angle = aim_dir.angle_to(to_target.normalized())

		if angle > half_arc_rad:
			continue

		var entity_id: int = body.get("entity_id") if "entity_id" in body else body.get_instance_id()
		candidates.append({
			"body": body,
			"distance": dist,
			"angle": angle,
			"id": entity_id,
			"dir": to_target.normalized() if not to_target.is_zero_approx() else aim_dir
		})

	# Sort tie-break
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a.distance, b.distance):
			return a.distance < b.distance
		if not is_equal_approx(a.angle, b.angle):
			return a.angle < b.angle
		return a.id < b.id
	)

	var target_count := mini(candidates.size(), max_targets)
	for i in range(target_count):
		var target_data: Dictionary = candidates[i]
		var target_node: Node = target_data.body
		var hit_dir: Vector3 = target_data.dir

		var info := DamageInfo.new(
			damage_amount,
			stats.sword_damage_type,
			self,
			knockback,
			hit_dir
		)

		if target_node.has_method("take_damage"):
			target_node.take_damage(info)


func take_damage(damage_input: Variant) -> void:
	if is_commander_mode:
		return

	var info: DamageInfo = null
	if damage_input is DamageInfo:
		info = damage_input
	elif damage_input is int:
		info = DamageInfo.new(damage_input, Enums.DamageType.SLASH)
	else:
		return

	if is_dodging and info.damage_type != Enums.DamageType.TRUE:
		return

	var final_amount: int = info.amount
	if info.damage_type != Enums.DamageType.TRUE and stats != null:
		var effective_armor: float = clampf(stats.armor_pct, 0.0, 0.75)
		final_amount = maxi(1, ceili(float(info.amount) * (1.0 - effective_armor)))

	info.amount = final_amount
	health.take_damage(info)


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	EventBus.commander_hp_changed.emit(current_hp, max_hp)


func _on_died() -> void:
	EventBus.commander_died.emit()


func _debug_report_speed(delta: float) -> void:
	var moved := Vector2(global_position.x - _debug_last_pos.x, global_position.z - _debug_last_pos.z)
	_debug_last_pos = global_position
	_debug_timer += delta
	var flat_velocity := Vector2(velocity.x, velocity.z)

	if _debug_timer < 0.5 or flat_velocity.is_zero_approx():
		return

	_debug_timer = 0.0
	print("velocity: %.3f m/s | moved: %.3f m/s | expected: %.3f m/s" % [
		flat_velocity.length(), moved.length() / delta, stats.move_speed if stats else 6.0])
