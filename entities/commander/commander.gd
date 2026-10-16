extends CharacterBody3D

@export var stats: CharacterStats
@export var debug_aim_marker: Node3D
@export var debug_print_speed: bool = false
@export var _anim_player: AnimationPlayer

# Combat & hit constants
const COLLISION_LAYER_ENEMY: int = 3
const TARGET_COLLIDER_PADDING: float = 0.4
const COMBO_HIT3_ARC_DEG: float = 240.0
const STRIKE_RATIO_MELEE: float = 0.38
const STRIKE_RATIO_SPIN: float = 0.45
const ROTATION_LERP_SPEED: float = 16.0

# Animation clips
const ANIM_IDLE: StringName = &"general/Idle_A"
const ANIM_RUN: StringName = &"move/Running_A"
const ANIM_HIT: StringName = &"general/Hit_A"
const ANIM_DEATH: StringName = &"general/Death_A"
const ANIM_DODGE_FWD: StringName = &"advance/Dodge_Forward"
const ANIM_DODGE_BACK: StringName = &"advance/Dodge_Backward"
const ANIM_SKILL: StringName = &"simulation/Cheering"

const COMBO_ANIM_CLIPS: Array[StringName] = [
	&"melee/Melee_1H_Attack_Chop",
	&"melee/Melee_1H_Attack_Slice_Diagonal",
	&"melee/Melee_2H_Attack_Spinning"
]
const COMBO_ANIM_SPEEDS: Array[float] = [1.6, 1.6, 1.4]

const KNOCKBACK_DURATION: float = 0.25
const POST_ACTION_DURATION: float = 0.1

var aim_dir: Vector3 = Vector3.FORWARD
var is_commander_mode: bool = false
var is_deploying: bool = false
var is_dead: bool = false

var _knockback_velocity: Vector3 = Vector3.ZERO
var _knockback_decay: float = 0.0
# True if knockback was applied to velocity during this physics frame
var _was_pushed: bool = false
var _hit_reaction_timer: float = 0.0
var _post_action_timer: float = 0.0
var _post_action_facing_dir: Vector3 = Vector3.ZERO

# Stun state
var is_stunned: bool = false
var _stun_timer: float = 0.0
var _stun_immunity_timer: float = 0.0

# Skill state
var is_using_skill: bool = false
var _skill_timer: float = 0.0
var _battle_cry_cd_timer: float = 0.0
var _battle_cry_active_timer: float = 0.0

# Dodge state
var is_dodging: bool = false
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _is_backstep_dodge: bool = false

# Combat & Combo state
var is_attacking: bool = false
var current_combo_hit: int = 1
var _attack_timer: float = 0.0
var _strike_timer: float = 0.0
var _has_struck: bool = false
var _combo_reset_timer: float = 0.0
var _attack_strike_dir: Vector3 = Vector3.FORWARD

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _debug_last_pos: Vector3
var _debug_timer: float = 0.0
var _cmd_input: CommanderInput
var _spawn_position: Vector3
var _wave_state: StringName = &""
var _is_low_hp: bool = false

@onready var _aim_pivot: Node3D = %AimPivot
@onready var _sword_area: Area3D = %SwordArea
@onready var health: HealthComponent = %Health


func _ready() -> void:
	add_to_group(&"commander")
	_spawn_position = global_position
	_debug_last_pos = global_position
	_setup_health()
	_setup_animation_player()
	_setup_sword_area()
	_setup_input()
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.state_changed.connect(_on_wave_state_changed)


func _setup_health() -> void:
	if stats != null:
		health.max_hp = stats.commander_max_hp
		health.hp = stats.commander_max_hp

	health.hp_changed.connect(_on_hp_changed)
	health.died.connect(_on_died)
	EventBus.commander_hp_changed.emit.call_deferred(health.hp, health.max_hp)


func _setup_animation_player() -> void:
	if _anim_player == null:
		var aps := find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty():
			_anim_player = aps[0] as AnimationPlayer


func _setup_input() -> void:
	_cmd_input = CommanderInput.new()
	_cmd_input.name = "CommanderInput"
	if stats != null:
		_cmd_input.buffer_time = stats.input_buffer_time
	add_child(_cmd_input)


func _setup_sword_area() -> void:
	if _sword_area == null:
		return
	var col_shape := _sword_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape != null and col_shape.shape is CylinderShape3D:
		var cylinder := col_shape.shape as CylinderShape3D
		var required_radius: float = (stats.sword_range if stats else 2.2) + TARGET_COLLIDER_PADDING
		cylinder.radius = maxf(cylinder.radius, required_radius)


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	if is_dead or (health != null and health.hp <= 0):
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		return

	# Checked before the stun branch so a stunned commander knocked into the void is recovered at once.
	if global_position.y < (stats.fall_y_threshold if stats else -5.0):
		_recover_from_fall()

	_update_cooldowns_and_timers(delta)

	if is_commander_mode:
		_cmd_input.discard()
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if is_stunned:
		_cmd_input.discard()
		velocity.x = 0.0
		velocity.z = 0.0
		if not _knockback_velocity.is_zero_approx():
			velocity.x += _knockback_velocity.x
			velocity.z += _knockback_velocity.z
			_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, _knockback_decay * delta)
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		if _anim_player != null and not _anim_player.is_playing() and _anim_player.has_animation(ANIM_IDLE):
			_anim_player.play(ANIM_IDLE, 0.2)
		return

	_execute_command(_cmd_input.next_command(_command_busy_left), camera)

	if is_dodging:
		_update_dodge_movement(delta)
	elif is_using_skill:
		_update_skill_movement(delta)
	else:
		_update_movement(camera, delta)

	_was_pushed = false
	if not _knockback_velocity.is_zero_approx():
		_was_pushed = true
		velocity.x += _knockback_velocity.x
		velocity.z += _knockback_velocity.z
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, _knockback_decay * delta)

	move_and_slide()

	if is_dodging and _dodge_timer <= 0.0:
		_end_dodge()

	_update_aim(camera)
	_update_model_facing(delta)

	if debug_print_speed:
		_debug_report_speed(delta)


func _update_cooldowns_and_timers(delta: float) -> void:
	if _hit_reaction_timer > 0.0:
		_hit_reaction_timer = maxf(0.0, _hit_reaction_timer - delta)

	if _post_action_timer > 0.0:
		_post_action_timer = maxf(0.0, _post_action_timer - delta)

	if _stun_immunity_timer > 0.0:
		_stun_immunity_timer = maxf(0.0, _stun_immunity_timer - delta)

	if is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			is_stunned = false
			_stun_timer = 0.0
			_stun_immunity_timer = stats.stun_immunity_duration if stats != null else 3.0

	if _dodge_cooldown_timer > 0.0:
		var prev_cd := _dodge_cooldown_timer
		_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
		var total_cd := stats.dodge_cooldown if stats else 1.5
		if _dodge_cooldown_timer == 0.0 or ceili(prev_cd) != ceili(_dodge_cooldown_timer):
			EventBus.skill_cooldown_changed.emit(&"dodge", _dodge_cooldown_timer, total_cd)

	if _battle_cry_cd_timer > 0.0:
		var prev_cd := _battle_cry_cd_timer
		_battle_cry_cd_timer = maxf(0.0, _battle_cry_cd_timer - delta)
		var total_cd := stats.skill_cooldown if stats else 12.0
		if _battle_cry_cd_timer == 0.0 or ceili(prev_cd) != ceili(_battle_cry_cd_timer):
			EventBus.skill_cooldown_changed.emit(&"battle_cry", _battle_cry_cd_timer, total_cd)

	if _battle_cry_active_timer > 0.0:
		_battle_cry_active_timer = maxf(0.0, _battle_cry_active_timer - delta)

	if is_using_skill:
		_skill_timer -= delta
		if _skill_timer <= 0.0:
			_end_skill()

	if is_attacking and not _has_struck:
		_strike_timer -= delta
		if _strike_timer <= 0.0:
			_has_struck = true
			_execute_sword_strike(current_combo_hit)

	if is_attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_end_attack()

	if not is_attacking and _combo_reset_timer > 0.0:
		_combo_reset_timer -= delta
		if _combo_reset_timer <= 0.0:
			current_combo_hit = 1


## Game seconds until the commander can start the command. Dodge can cancel the recovery
## of an attack, other commands wait for it.
func _command_busy_left(command: StringName) -> float:
	var left := 0.0
	if is_dodging:
		left = maxf(left, _dodge_timer)
	if is_using_skill:
		left = maxf(left, _skill_timer)
	if is_attacking and command != &"dodge":
		left = maxf(left, _attack_timer)
	return left


func _execute_command(command: StringName, camera: Camera3D) -> void:
	match command:
		&"dodge":
			_try_dodge(camera)
		&"battle_cry":
			_try_battle_cry()
		&"attack":
			_try_attack()


func _try_dodge(camera: Camera3D) -> void:
	if is_commander_mode or is_dodging or _dodge_cooldown_timer > 0.0:
		return
	if is_attacking:
		_interrupt_attack()
	_start_dodge(camera)


func _start_dodge(camera: Camera3D) -> void:
	var input := _cmd_input.get_move_vector()
	var dodge_clip := ANIM_DODGE_FWD

	if not input.is_zero_approx():
		var cam_basis := camera.global_transform.basis
		var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()
		_dodge_dir = (right * input.x + forward * (-input.y)).normalized()
		_is_backstep_dodge = false
		dodge_clip = ANIM_DODGE_FWD
	else:
		_dodge_dir = -aim_dir
		_is_backstep_dodge = true
		dodge_clip = ANIM_DODGE_BACK

	is_dodging = true
	_knockback_velocity = Vector3.ZERO
	_knockback_decay = 0.0
	_hit_reaction_timer = 0.0
	_post_action_timer = 0.0
	_post_action_facing_dir = Vector3.ZERO
	_dodge_timer = stats.dodge_iframe if stats else 0.3
	_dodge_cooldown_timer = stats.dodge_cooldown if stats else 1.5

	set_collision_mask_value(COLLISION_LAYER_ENEMY, false)

	var total_cd := stats.dodge_cooldown if stats else 1.5
	EventBus.skill_cooldown_changed.emit(&"dodge", _dodge_cooldown_timer, total_cd)

	if _anim_player != null and _anim_player.has_animation(dodge_clip):
		var dodge_duration := stats.dodge_iframe if stats else 0.3
		var anim_len := _anim_player.get_animation(dodge_clip).length
		var speed := anim_len / maxf(0.01, dodge_duration)
		_anim_player.play(dodge_clip, 0.05, speed)


func _update_dodge_movement(delta: float) -> void:
	var dodge_dist := stats.dodge_distance if stats else 4.0
	var dodge_duration := stats.dodge_iframe if stats else 0.3
	var dodge_speed := dodge_dist / maxf(0.01, dodge_duration)

	velocity.x = _dodge_dir.x * dodge_speed
	velocity.z = _dodge_dir.z * dodge_speed

	if not is_on_floor():
		velocity.y -= _gravity * delta

	_dodge_timer -= delta


func _end_dodge() -> void:
	_post_action_facing_dir = aim_dir if _is_backstep_dodge else _dodge_dir
	_post_action_timer = POST_ACTION_DURATION
	is_dodging = false
	_is_backstep_dodge = false
	_dodge_timer = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	set_collision_mask_value(COLLISION_LAYER_ENEMY, true)


func _try_battle_cry() -> void:
	if is_commander_mode or is_dodging or is_using_skill or is_attacking or _battle_cry_cd_timer > 0.0:
		return
	if health != null and health.hp <= 0:
		return
	_start_battle_cry()


func _start_battle_cry() -> void:
	is_using_skill = true
	var anim_time: float = stats.skill_animation_time if stats else 0.5
	_skill_timer = anim_time

	var total_cd: float = stats.skill_cooldown if stats else 12.0
	_battle_cry_cd_timer = total_cd
	_battle_cry_active_timer = stats.battle_cry_duration if stats else 4.0

	velocity.x = 0.0
	velocity.z = 0.0

	EventBus.skill_cooldown_changed.emit(&"battle_cry", _battle_cry_cd_timer, total_cd)

	if _anim_player != null and _anim_player.has_animation(ANIM_SKILL):
		var anim_len := _anim_player.get_animation(ANIM_SKILL).length
		var speed := anim_len / maxf(0.01, anim_time)
		_anim_player.play(ANIM_SKILL, 0.05, speed)

	_taunt_enemies_in_range()


func _update_skill_movement(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= _gravity * delta


func _end_skill() -> void:
	is_using_skill = false
	_skill_timer = 0.0


func _interrupt_skill() -> void:
	if is_using_skill:
		is_using_skill = false
		_skill_timer = 0.0


func _taunt_enemies_in_range() -> void:
	var radius: float = stats.battle_cry_radius if stats else 6.0
	var radius_sq: float = radius * radius
	var duration: float = stats.battle_cry_duration if stats else 4.0
	var enemies := get_tree().get_nodes_in_group(&"enemy")

	for enemy in enemies:
		var enemy_node := enemy as Node3D
		if enemy_node == null or not is_instance_valid(enemy_node) or enemy_node.is_queued_for_deletion():
			continue

		var diff := enemy_node.global_position - global_position
		diff.y = 0.0
		if diff.length_squared() <= radius_sq:
			if enemy_node.has_method("apply_commander_taunt"):
				enemy_node.apply_commander_taunt(self, duration)


func _update_movement(camera: Camera3D, delta: float) -> void:
	if is_attacking:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * delta
		return

	if not _knockback_velocity.is_zero_approx():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var input := _cmd_input.get_move_vector()
		var speed := stats.move_speed if stats else 6.0

		var cam_basis := camera.global_transform.basis
		var right := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		var forward := Vector3(-cam_basis.z.x, 0.0, -cam_basis.z.z).normalized()

		var dir := right * input.x + forward * (-input.y)
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if _anim_player != null and not is_attacking and not is_dodging and health.hp > 0:
		var is_playing_melee := _anim_player.is_playing() and _anim_player.current_animation.begins_with("melee/")
		var is_playing_hit := _anim_player.is_playing() and _anim_player.current_animation == ANIM_HIT
		var is_hit_locked := _hit_reaction_timer > 0.0 or not _knockback_velocity.is_zero_approx()

		if not is_playing_melee:
			if is_playing_hit and is_hit_locked:
				pass
			else:
				var horizontal_vel := Vector2(velocity.x, velocity.z)
				if horizontal_vel.length() > 0.1:
					if _anim_player.current_animation != ANIM_RUN:
						_anim_player.play(ANIM_RUN, 0.15)
				elif not is_playing_hit:
					if _anim_player.current_animation != ANIM_IDLE:
						_anim_player.play(ANIM_IDLE, 0.15)


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

	if to_target.length_squared() >= 0.0001:
		aim_dir = to_target.normalized()


func _update_model_facing(delta: float) -> void:
	var target_dir := Vector3.ZERO
	var snap_instantly := false

	if is_attacking:
		target_dir = _attack_strike_dir
		snap_instantly = true
	elif is_dodging:
		target_dir = aim_dir if _is_backstep_dodge else _dodge_dir
		snap_instantly = true
	elif is_using_skill:
		target_dir = aim_dir
		snap_instantly = false
	elif _was_pushed:
		target_dir = -_knockback_velocity.normalized()
		snap_instantly = false
	elif _post_action_timer > 0.0 and not _post_action_facing_dir.is_zero_approx():
		var horizontal_vel := Vector2(velocity.x, velocity.z)
		if horizontal_vel.length() > 0.1:
			var move_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
			var t := 1.0 - clampf(_post_action_timer / POST_ACTION_DURATION, 0.0, 1.0)
			if _post_action_facing_dir.dot(move_dir) < -0.999:
				target_dir = move_dir
			else:
				target_dir = _post_action_facing_dir.slerp(move_dir, t).normalized()
		else:
			target_dir = _post_action_facing_dir
		snap_instantly = false
	else:
		var horizontal_vel := Vector2(velocity.x, velocity.z)
		if horizontal_vel.length() > 0.1:
			target_dir = Vector3(velocity.x, 0.0, velocity.z).normalized()

	if not target_dir.is_zero_approx():
		var target_yaw := atan2(target_dir.x, target_dir.z)
		if snap_instantly:
			_aim_pivot.rotation.y = target_yaw
		else:
			var weight := 1.0 - exp(-ROTATION_LERP_SPEED * delta)
			_aim_pivot.rotation.y = lerp_angle(_aim_pivot.rotation.y, target_yaw, weight)


func _try_attack() -> void:
	if is_commander_mode or is_dodging or is_attacking or is_using_skill:
		return
	_start_attack(current_combo_hit)


func _start_attack(hit_index: int) -> void:
	is_attacking = true
	current_combo_hit = hit_index
	_has_struck = false
	_post_action_timer = 0.0
	_post_action_facing_dir = Vector3.ZERO

	var interval := stats.attack_interval if stats else 0.45
	_attack_timer = interval

	var hit_ratio := STRIKE_RATIO_SPIN if hit_index == 3 else STRIKE_RATIO_MELEE
	_strike_timer = interval * hit_ratio
	_combo_reset_timer = 0.0

	_attack_strike_dir = aim_dir
	_aim_pivot.rotation.y = atan2(_attack_strike_dir.x, _attack_strike_dir.z)

	_play_attack_animation(current_combo_hit)


func _end_attack() -> void:
	is_attacking = false
	_attack_timer = 0.0
	_has_struck = false

	_post_action_facing_dir = _attack_strike_dir
	_post_action_timer = POST_ACTION_DURATION
	if current_combo_hit >= 3:
		current_combo_hit = 1
		_combo_reset_timer = 0.0
	else:
		current_combo_hit += 1
		_combo_reset_timer = stats.combo_window if stats else 0.35


func _interrupt_attack() -> void:
	var struck := _has_struck
	is_attacking = false
	_attack_timer = 0.0
	_has_struck = false
	_post_action_timer = 0.0
	_post_action_facing_dir = Vector3.ZERO

	if struck:
		if current_combo_hit >= 3:
			current_combo_hit = 1
			_combo_reset_timer = 0.0
		else:
			current_combo_hit += 1
			_combo_reset_timer = stats.combo_window if stats else 0.35
	else:
		current_combo_hit = 1
		_combo_reset_timer = 0.0


func _play_attack_animation(combo_step: int) -> void:
	if _anim_player == null:
		return

	var idx := clampi(combo_step - 1, 0, 2)
	var anim_clip: StringName = COMBO_ANIM_CLIPS[idx]
	var anim_speed: float = COMBO_ANIM_SPEEDS[idx]

	if _anim_player.has_animation(anim_clip):
		_anim_player.play(anim_clip, 0.05, anim_speed)


func _execute_sword_strike(combo_step: int) -> void:
	if _sword_area == null or stats == null:
		return

	var max_range: float = stats.sword_range + TARGET_COLLIDER_PADDING
	var arc_deg: float = COMBO_HIT3_ARC_DEG if combo_step == 3 else stats.sword_arc_deg
	var half_arc_rad: float = deg_to_rad(arc_deg * 0.5)

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
			angle = _attack_strike_dir.angle_to(to_target.normalized())

		if angle > half_arc_rad:
			continue

		var entity_id: int = body.get("entity_id") if "entity_id" in body else body.get_instance_id()
		candidates.append({
			"body": body,
			"distance": dist,
			"angle": angle,
			"id": entity_id,
			"dir": to_target.normalized() if not to_target.is_zero_approx() else _attack_strike_dir
		})

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
		if target_node == null or not is_instance_valid(target_node) or target_node.is_queued_for_deletion():
			continue
		var hit_dir: Vector3 = target_data.dir

		var info := DamageInfo.new(
			damage_amount,
			stats.sword_damage_type,
			self,
			knockback,
			hit_dir
		)

		if "provoked_by_player" in target_node:
			target_node.set("provoked_by_player", true)

		if target_node.has_method("take_damage"):
			target_node.take_damage(info)


func take_damage(damage_input: Variant) -> void:
	if is_dead or is_commander_mode or _wave_state == &"PREP" or _wave_state == &"SUMMARY":
		return

	var info: DamageInfo = null
	if damage_input is DamageInfo:
		info = damage_input
	elif damage_input is int:
		info = DamageInfo.new(damage_input, Enums.DamageType.SLASH)
	else:
		return

	if (is_dodging or is_deploying) and info.damage_type != Enums.DamageType.TRUE:
		return

	var final_amount: int = info.amount
	if info.damage_type != Enums.DamageType.TRUE and stats != null and info.amount > 0:
		var effective_armor: float = clampf(stats.armor_pct, 0.0, 0.75)
		var skill_mult: float = stats.battle_cry_damage_mult if _battle_cry_active_timer > 0.0 else 1.0
		final_amount = maxi(1, ceili(float(info.amount) * (1.0 - effective_armor) * skill_mult))

	var processed_info := DamageInfo.new(
		final_amount,
		info.damage_type,
		info.source,
		info.knockback_force,
		info.hit_direction
	)
	health.take_damage(processed_info)

	var can_knockback: bool = not is_dodging and not is_deploying and not is_commander_mode
	if can_knockback and info.knockback_force > 0.0 and health.hp > 0:
		var kb_dir := info.hit_direction
		kb_dir.y = 0.0
		if kb_dir.length_squared() > 0.001:
			kb_dir = kb_dir.normalized()
		elif info.source is Node3D:
			var from_source: Vector3 = global_position - (info.source as Node3D).global_position
			from_source.y = 0.0
			if from_source.length_squared() > 0.001:
				kb_dir = from_source.normalized()
			else:
				kb_dir = -Vector3(sin(_aim_pivot.rotation.y), 0.0, cos(_aim_pivot.rotation.y))
		else:
			kb_dir = -Vector3(sin(_aim_pivot.rotation.y), 0.0, cos(_aim_pivot.rotation.y))
		var kb_duration: float = KNOCKBACK_DURATION
		var kb_speed: float = (info.knockback_force * 2.0) / kb_duration
		_knockback_velocity = kb_dir * kb_speed
		_knockback_decay = kb_speed / kb_duration

	if not is_attacking and not is_dodging and not is_using_skill and health.hp > 0:
		_hit_reaction_timer = KNOCKBACK_DURATION
		if _anim_player != null and _anim_player.has_animation(ANIM_HIT):
			_anim_player.play(ANIM_HIT, 0.05)


func apply_stun(duration: float = -1.0) -> bool:
	if is_commander_mode or is_dodging or is_deploying:
		return false
	if health != null and health.hp <= 0:
		return false
	if _stun_immunity_timer > 0.0:
		return false

	var max_dur: float = stats.max_stun_duration if stats != null else 1.5
	var target_dur := max_dur if duration < 0.0 else duration
	var clamped_dur := clampf(target_dur, 0.0, max_dur)
	if clamped_dur <= 0.0:
		return false

	if is_attacking:
		_interrupt_attack()
	if is_using_skill:
		_interrupt_skill()

	is_stunned = true
	_stun_timer = maxf(_stun_timer, clamped_dur)
	_hit_reaction_timer = 0.0
	_post_action_timer = 0.0
	_post_action_facing_dir = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0

	if _anim_player != null and _anim_player.has_animation(ANIM_HIT):
		_anim_player.play(ANIM_HIT, 0.05)

	return true


func can_retreat() -> bool:
	return not is_commander_mode and not is_stunned and health != null and health.hp > 0


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	EventBus.commander_hp_changed.emit(current_hp, max_hp)
	_update_low_hp(current_hp, max_hp)


func _update_low_hp(current_hp: int, max_hp: int) -> void:
	var threshold: float = stats.commander_low_hp_warning_pct if stats else 0.25
	var is_low := current_hp > 0 and float(current_hp) < float(max_hp) * threshold
	if is_low != _is_low_hp:
		_is_low_hp = is_low
		EventBus.commander_low_hp_changed.emit(is_low)


func _on_wave_state_changed(new_state: StringName) -> void:
	_wave_state = new_state
	if new_state == &"PREP" and not is_dead:
		var heal_pct: float = stats.prep_heal_pct if stats else 0.6
		health.heal(floori(float(health.max_hp) * heal_pct))


## Falling out of the map costs a fraction of max HP as TRUE damage but never kills.
func _recover_from_fall() -> void:
	if is_dodging:
		_end_dodge()
	if is_attacking:
		_interrupt_attack()
	velocity = Vector3.ZERO
	_knockback_velocity = Vector3.ZERO
	global_position = _find_deploy_position()

	var hp_before := health.hp
	var fall_pct: float = stats.fall_damage_pct if stats else 0.15
	var amount := mini(ceili(float(health.max_hp) * fall_pct), health.hp - 1)
	if amount > 0:
		take_damage(DamageInfo.new(amount, Enums.DamageType.TRUE))
	print("Commander fell off the map: moved to deploy point, lost %d HP" % (hp_before - health.hp))


func _find_deploy_position() -> Vector3:
	var scene := get_tree().current_scene
	var marker := scene.find_child("DeployPoint", true, false) as Node3D if scene != null else null
	return marker.global_position if marker != null else _spawn_position


func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	_cmd_input.discard()
	_knockback_velocity = Vector3.ZERO
	_knockback_decay = 0.0
	_hit_reaction_timer = 0.0
	_post_action_timer = 0.0
	_post_action_facing_dir = Vector3.ZERO
	is_stunned = false
	_stun_timer = 0.0
	_stun_immunity_timer = 0.0
	if is_dodging:
		_end_dodge()
	if is_attacking:
		_interrupt_attack()
	_interrupt_skill()
	EventBus.commander_died.emit()
	if _anim_player != null and _anim_player.has_animation(ANIM_DEATH):
		_anim_player.play(ANIM_DEATH)


func _on_mode_changed(mode: StringName) -> void:
	is_commander_mode = (mode == &"COMMANDER")
	if is_commander_mode:
		_knockback_velocity = Vector3.ZERO
		_knockback_decay = 0.0
		_hit_reaction_timer = 0.0
		_post_action_timer = 0.0
		_post_action_facing_dir = Vector3.ZERO
		is_stunned = false
		_stun_timer = 0.0
		if is_dodging:
			_end_dodge()
		if is_attacking:
			_interrupt_attack()
		_interrupt_skill()
		_battle_cry_active_timer = 0.0


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
