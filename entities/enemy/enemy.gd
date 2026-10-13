class_name Enemy
extends CharacterBody3D

## Base enemy controller with state machine, navigation, spawn grace, and combat behaviors.
## Supports melee and ranged archetypes, prioritized targeting rules (ETG-01), and crowd optimizations.

signal state_changed(new_state: Enums.EnemyState, old_state: Enums.EnemyState)

const PATH_UPDATE_INTERVAL: float = 0.3
const KNOCKBACK_IMPULSE_SCALE: float = 10.0  # Scales knockback force into instantaneous velocity

@export var data: EnemyData

var current_target: Node3D = null
var current_target_position: Vector3 = Vector3.ZERO
var has_target_position: bool = false
var nav_progress: float = 0.0
var speed_multiplier: float = 1.0
var is_dead: bool = false

var current_state: Enums.EnemyState = Enums.EnemyState.SPAWN
var _previous_state: Enums.EnemyState = Enums.EnemyState.ADVANCE

var spawn_grace: bool = true
var is_in_spawn_zone: bool = true
var spawn_grace_timer: float = 0.0
var _spawn_zone_min_x: float = 8.0

var attack_windup_timer: float = 0.0
var attack_recovery_timer: float = 0.0
var is_attacking_active: bool = false

var provoked_by_player: bool = false
var provoked_timer: float = 0.0
var stagger_timer: float = 0.0
var knockback_immunity_timer: float = 0.0

var life_timer: float = 0.0
var straggler_marked: bool = false
var is_frenzied: bool = false
var wait_timer: float = 0.0
var _retarget_timer: float = 0.0
var _path_timer: float = 0.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Shared node cache per physics frame to avoid get_nodes_in_group garbage collection overhead
static var _cached_barricades: Array[Node] = []
static var _cached_towers: Array[Node] = []
static var _last_cache_frame: int = -1

@onready var health: HealthComponent = %Health
@onready var nav: NavigationAgent3D = %NavAgent

func _ready() -> void:
	add_to_group(&"enemy")

	# Phase-offset timers to prevent frame spikes across groups
	_path_timer = randf_range(0.0, PATH_UPDATE_INTERVAL)
	_retarget_timer = randf_range(0.0, GameConfig.retarget_interval)

	if data == null:
		push_warning("Enemy missing EnemyData resource")
		return

	health.max_hp = data.base_hp
	health.hp = data.base_hp
	health.died.connect(_on_died)

	nav.radius = data.avoid_radius
	nav.path_desired_distance = 0.5
	nav.target_desired_distance = data.attack_range if data else 1.0

	_init_spawn_zone_bounds()
	_setup_navigation.call_deferred()

func _init_spawn_zone_bounds() -> void:
	var sz := get_tree().get_first_node_in_group(&"spawn_zone") as Area3D
	if sz == null:
		var root := get_tree().current_scene
		if root != null:
			sz = root.find_child("SpawnZone", true, false) as Area3D
	if sz != null:
		var col := sz.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null and col.shape is BoxShape3D:
			var box := col.shape as BoxShape3D
			_spawn_zone_min_x = sz.global_position.x - (box.size.x * 0.5)
		else:
			_spawn_zone_min_x = sz.global_position.x - 6.0

func _setup_navigation() -> void:
	await get_tree().physics_frame
	if not has_target_position and current_target == null:
		_find_default_target()

func can_be_targeted() -> bool:
	if is_dead or spawn_grace or is_in_spawn_zone:
		return false
	return true

func change_state(new_state: Enums.EnemyState) -> void:
	if current_state == new_state:
		return
	var old_state := current_state
	current_state = new_state
	state_changed.emit(new_state, old_state)

	match new_state:
		Enums.EnemyState.SPAWN:
			spawn_grace = true
			is_in_spawn_zone = true
			spawn_grace_timer = 0.0
		Enums.EnemyState.ADVANCE:
			_retarget_timer = 0.0
		Enums.EnemyState.CHASE:
			_retarget_timer = 0.0
		Enums.EnemyState.ATTACK:
			attack_windup_timer = 0.0
			attack_recovery_timer = 0.0
			is_attacking_active = false
			velocity = Vector3.ZERO
		Enums.EnemyState.STAGGER:
			pass
		Enums.EnemyState.WAIT:
			wait_timer = 0.0
			velocity = Vector3.ZERO
		Enums.EnemyState.FRENZY:
			if not is_frenzied:
				is_frenzied = true
				EventBus.frenzy_started.emit(self)
			speed_multiplier = GameConfig.frenzy_speed_mult
			_find_default_target()
		Enums.EnemyState.DEAD:
			set_physics_process(false)
			velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0

	_update_timers(delta)
	_update_state(delta)
	move_and_slide()

func _update_timers(delta: float) -> void:
	life_timer += delta

	if life_timer >= GameConfig.straggler_marker_time and not straggler_marked:
		straggler_marked = true
		EventBus.straggler_marker_shown.emit(self)

	if life_timer >= GameConfig.frenzy_time and not is_frenzied and current_state != Enums.EnemyState.DEAD:
		is_frenzied = true
		change_state(Enums.EnemyState.FRENZY)

	if knockback_immunity_timer > 0.0:
		knockback_immunity_timer = maxf(0.0, knockback_immunity_timer - delta)

	if provoked_timer > 0.0:
		provoked_timer -= delta
		if provoked_timer <= 0.0:
			provoked_by_player = false
		elif provoked_by_player:
			var cmd := _get_valid_commander()
			if cmd == null or global_position.distance_to(cmd.global_position) > GameConfig.leash_distance:
				provoked_by_player = false
				provoked_timer = 0.0
				_find_best_target()

func _update_state(delta: float) -> void:
	match current_state:
		Enums.EnemyState.SPAWN:
			spawn_grace_timer += delta
			var exited_zone: bool = (global_position.x < _spawn_zone_min_x)
			var expired: bool = (spawn_grace_timer >= GameConfig.spawn_grace_max_time)
			if exited_zone or expired:
				spawn_grace = false
				is_in_spawn_zone = false
				change_state(Enums.EnemyState.ADVANCE)
				return

			_move_towards_direction(Vector3(-1.0, 0.0, 0.0))

		Enums.EnemyState.ADVANCE:
			_retarget_timer += delta
			if _retarget_timer >= GameConfig.retarget_interval:
				_retarget_timer = 0.0
				_find_best_target()

			if current_target != null and is_instance_valid(current_target) and _is_target_valid(current_target):
				change_state(Enums.EnemyState.CHASE)
				return

			_update_navigation_movement(delta)

		Enums.EnemyState.CHASE:
			_retarget_timer += delta
			if _retarget_timer >= GameConfig.retarget_interval:
				_retarget_timer = 0.0
				_find_best_target()

			if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
				change_state(Enums.EnemyState.ADVANCE)
				return

			var diff := current_target.global_position - global_position
			diff.y = 0.0
			var dist_to_target: float = diff.length()
			var attack_rng: float = data.attack_range if data else 1.5
			if dist_to_target <= attack_rng:
				change_state(Enums.EnemyState.ATTACK)
				return

			_update_target_tracking(delta)
			_update_navigation_movement(delta)

		Enums.EnemyState.ATTACK:
			velocity.x = 0.0
			velocity.z = 0.0

			if current_target != null and is_instance_valid(current_target):
				var look_dir := (current_target.global_position - global_position)
				look_dir.y = 0.0
				if look_dir.length_squared() > 0.001:
					var target_yaw := atan2(-look_dir.x, -look_dir.z)
					rotation.y = lerp_angle(rotation.y, target_yaw, 0.2)

			if not is_attacking_active:
				attack_windup_timer += delta
				if attack_windup_timer >= GameConfig.enemy_windup_time:
					is_attacking_active = true
					attack_windup_timer = 0.0
					_execute_attack_action()
					var total_interval: float = data.attack_interval if data else 1.0
					attack_recovery_timer = maxf(0.0, total_interval - GameConfig.enemy_windup_time)
			else:
				attack_recovery_timer -= delta
				if attack_recovery_timer <= 0.0:
					is_attacking_active = false
					if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
						if is_frenzied:
							change_state(Enums.EnemyState.FRENZY)
						else:
							change_state(Enums.EnemyState.ADVANCE)
					else:
						var diff_after := current_target.global_position - global_position
						diff_after.y = 0.0
						var dist_after: float = diff_after.length()
						var attack_rng: float = data.attack_range if data else 1.5
						if dist_after <= attack_rng + 0.3:
							attack_windup_timer = 0.0
						else:
							change_state(Enums.EnemyState.CHASE)

		Enums.EnemyState.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			stagger_timer -= delta
			if stagger_timer <= 0.0:
				knockback_immunity_timer = GameConfig.enemy_knockback_immunity_time
				if is_frenzied or _previous_state == Enums.EnemyState.FRENZY:
					change_state(Enums.EnemyState.FRENZY)
				elif _previous_state == Enums.EnemyState.CHASE and current_target != null and is_instance_valid(current_target) and _is_target_valid(current_target):
					change_state(Enums.EnemyState.CHASE)
				else:
					change_state(Enums.EnemyState.ADVANCE)

		Enums.EnemyState.WAIT:
			velocity.x = 0.0
			velocity.z = 0.0
			wait_timer += delta
			if wait_timer >= GameConfig.crowd_wait_retarget_time:
				wait_timer = 0.0
				change_state(Enums.EnemyState.ADVANCE)

		Enums.EnemyState.FRENZY:
			if current_target == null or not is_instance_valid(current_target) or not current_target.is_in_group(&"fortress"):
				_find_default_target()
			if current_target != null and is_instance_valid(current_target):
				var diff_f := current_target.global_position - global_position
				diff_f.y = 0.0
				if diff_f.length() <= (data.attack_range if data else 1.5):
					change_state(Enums.EnemyState.ATTACK)
					return
			_update_target_tracking(delta)
			_update_navigation_movement(delta)

		Enums.EnemyState.DEAD:
			velocity = Vector3.ZERO

func _execute_attack_action() -> void:
	_execute_melee_strike()

func _execute_melee_strike() -> void:
	if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
		return

	var diff := current_target.global_position - global_position
	diff.y = 0.0
	var dist := diff.length()
	var max_reach := (data.attack_range if data else 1.5) + 0.6
	if dist > max_reach:
		return

	if current_target.has_method("take_damage"):
		var dmg := data.base_damage if data else 6
		var dmg_type := data.damage_type if data else Enums.DamageType.SLASH
		var hit_dir := diff.normalized() if diff.length_squared() > 0.001 else Vector3.FORWARD
		var info := DamageInfo.new(dmg, dmg_type, self, 0.0, hit_dir)
		current_target.take_damage(info)

func _move_towards_direction(dir: Vector3) -> void:
	var move_dir := dir
	move_dir.y = 0.0
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		var move_speed: float = (data.move_speed if data else 3.5) * speed_multiplier
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 0.2)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

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

		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 0.2)
		nav_progress = nav.distance_to_target()
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _update_node_cache() -> void:
	var cur_frame := Engine.get_physics_frames()
	if _last_cache_frame != cur_frame or cur_frame <= 1:
		_last_cache_frame = cur_frame
		_cached_barricades = get_tree().get_nodes_in_group(&"barricade")
		_cached_towers = get_tree().get_nodes_in_group(&"tower")

func _is_target_ahead(target_pos: Vector3, tolerance: float = 0.5) -> bool:
	var advance_dir := Vector3(-1.0, 0.0, 0.0)
	var to_target := (target_pos - global_position)
	to_target.y = 0.0
	return to_target.dot(advance_dir) >= -tolerance

func _is_target_valid(t: Node3D) -> bool:
	if t == null or not is_instance_valid(t):
		return false

	if t.is_in_group(&"commander"):
		if "is_commander_mode" in t and t.is_commander_mode:
			return false
		if "health" in t and t.health != null and t.health.hp <= 0:
			return false
		return true

	if t.is_in_group(&"fortress"):
		if "health" in t and t.health != null and t.health.hp <= 0:
			return false
		return true

	if t.is_in_group(&"barricade"):
		if "health" in t and t.health != null and t.health.hp <= 0:
			return false
		return true

	if t.is_in_group(&"tower"):
		var is_wall: bool = false
		if t.has_meta("is_wall"):
			is_wall = bool(t.get_meta("is_wall"))
		elif "slot" in t and t.slot != null and "zone" in t.slot:
			is_wall = (t.slot.zone == Enums.SlotZone.WALL)
		elif t.get_parent() != null and "zone" in t.get_parent():
			is_wall = (t.get_parent().zone == Enums.SlotZone.WALL)
		elif t.get_parent() != null and t.get_parent().get_parent() != null and "zone" in t.get_parent().get_parent():
			is_wall = (t.get_parent().get_parent().zone == Enums.SlotZone.WALL)
		elif t.global_position.y >= 3.0:
			is_wall = true

		# Melee ground units cannot target wall towers (ETG-01)
		var can_target_wall := (data != null and (data.is_ranged or data.is_flying))
		if is_wall and not can_target_wall:
			return false
		if "health" in t and t.health != null and t.health.hp <= 0:
			return false
		return true

	return false

func _get_valid_commander() -> Node3D:
	var cmd := get_tree().get_first_node_in_group(&"commander") as Node3D
	if cmd != null and _is_target_valid(cmd):
		return cmd
	return null

func _get_valid_fortress() -> Node3D:
	var fortress := get_tree().get_first_node_in_group(&"fortress") as Node3D
	if fortress != null and _is_target_valid(fortress):
		return fortress
	return null

func _find_closest_valid_barricade() -> Node3D:
	_update_node_cache()
	var closest: Node3D = null
	var min_dist: float = INF
	for b in _cached_barricades:
		var b_node := b as Node3D
		if b_node != null and is_instance_valid(b_node) and _is_target_valid(b_node):
			if not _is_target_ahead(b_node.global_position):
				continue
			var d := global_position.distance_to(b_node.global_position)
			if d < min_dist:
				min_dist = d
				closest = b_node
	return closest

func _find_closest_valid_tower(wall_only: bool) -> Node3D:
	_update_node_cache()
	var closest: Node3D = null
	var min_dist: float = INF
	for tw in _cached_towers:
		var tw_node := tw as Node3D
		if tw_node != null and is_instance_valid(tw_node) and _is_target_valid(tw_node):
			var is_wall: bool = false
			if "slot" in tw_node and tw_node.slot != null and "zone" in tw_node.slot:
				is_wall = (tw_node.slot.zone == Enums.SlotZone.WALL)
			if wall_only != is_wall:
				continue
			if not _is_target_ahead(tw_node.global_position):
				continue
			var d := global_position.distance_to(tw_node.global_position)
			if d < min_dist:
				min_dist = d
				closest = tw_node
	return closest

func _find_best_target() -> void:
	if current_state == Enums.EnemyState.FRENZY:
		_find_default_target()
		return

	# Provocation overrides regular targeting rules (AGG-01, AGG-02, AGG-06)
	if provoked_by_player:
		var cmd := _get_valid_commander()
		if cmd != null:
			var dist_to_cmd := global_position.distance_to(cmd.global_position)
			if dist_to_cmd <= GameConfig.leash_distance:
				var is_melee := (data != null and not data.is_ranged and not data.is_flying)
				if is_melee and current_target != cmd and _get_active_melee_attackers_count(cmd) >= GameConfig.max_aggro_melee:
					set_target(cmd)
					change_state(Enums.EnemyState.WAIT)
					return
				set_target(cmd)
				return
			else:
				provoked_by_player = false
				provoked_timer = 0.0

	if data == null or data.target_rules.is_empty():
		_find_default_target()
		return

	# Evaluate targets in prioritized order from data.target_rules (ETG-01)
	for rule in data.target_rules:
		match rule:
			&"PLAYER":
				var cmd := _get_valid_commander()
				if cmd != null:
					var dist_to_cmd := global_position.distance_to(cmd.global_position)
					if dist_to_cmd <= data.aggro_range:
						set_target(cmd)
						return

			&"BARRICADE":
				var closest_barricade := _find_closest_valid_barricade()
				if closest_barricade != null:
					set_target(closest_barricade)
					return

			&"TOWER_GROUND":
				var closest_tower := _find_closest_valid_tower(false)
				if closest_tower != null:
					set_target(closest_tower)
					return

			&"TOWER_WALL":
				if data.is_ranged or data.is_flying:
					var closest_wall_tower := _find_closest_valid_tower(true)
					if closest_wall_tower != null:
						set_target(closest_wall_tower)
						return

			&"FORTRESS":
				var fortress := _get_valid_fortress()
				if fortress != null:
					set_target(fortress)
					return

	_find_default_target()

func _find_default_target() -> void:
	var fortress := _get_valid_fortress()
	if fortress != null:
		set_target(fortress)
	else:
		set_target_position(_get_fortress_fallback_position())

func _get_fortress_fallback_position() -> Vector3:
	var fortress_marker := get_tree().get_first_node_in_group(&"fortress_spawn") as Node3D
	if fortress_marker == null:
		var root := get_tree().current_scene
		if root != null:
			fortress_marker = root.find_child("FortressSpawn", true, false) as Node3D
	if fortress_marker != null:
		return fortress_marker.global_position
	var fortress_node := get_tree().get_first_node_in_group(&"fortress") as Node3D
	if fortress_node != null:
		return fortress_node.global_position
	return Vector3(-17.5, global_position.y, 0.0)

func set_target(target_node: Node3D) -> void:
	current_target = target_node
	has_target_position = false
	if current_target != null:
		nav.target_position = current_target.global_position

func set_target_position(target_pos: Vector3) -> void:
	current_target = null
	current_target_position = target_pos
	has_target_position = true
	nav.target_position = target_pos

func _get_active_melee_attackers_count(cmd: Node3D) -> int:
	var count: int = 0
	var enemies := get_tree().get_nodes_in_group(&"enemy")
	for e in enemies:
		if e == self or not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var other := e as Enemy
		if other == null or other.is_dead:
			continue
		if other.current_target == cmd:
			var other_is_melee := (other.data != null and not other.data.is_ranged and not other.data.is_flying)
			if other_is_melee and (other.current_state == Enums.EnemyState.CHASE or other.current_state == Enums.EnemyState.ATTACK):
				count += 1
	return count

func apply_commander_taunt(commander_node: Node3D, duration: float) -> void:
	if is_dead or spawn_grace or is_in_spawn_zone:
		return
	if commander_node == null or not is_instance_valid(commander_node):
		return

	# Bosses are immune to taunt (AGG-02, AI-06, BOSS-01)
	var is_boss: bool = is_in_group(&"boss") or (data != null and data is BossData) or (get("is_boss") == true)
	if is_boss:
		return

	provoked_by_player = true
	provoked_timer = maxf(provoked_timer, duration)

	# AGG-06: Check melee attacker capacity on Commander
	var is_melee := (data != null and not data.is_ranged and not data.is_flying)
	if is_melee and _get_active_melee_attackers_count(commander_node) >= GameConfig.max_aggro_melee:
		set_target(commander_node)
		change_state(Enums.EnemyState.WAIT)
		return

	set_target(commander_node)

	if current_state == Enums.EnemyState.ADVANCE or current_state == Enums.EnemyState.WAIT or current_state == Enums.EnemyState.SPAWN:
		change_state(Enums.EnemyState.CHASE)
	elif current_state == Enums.EnemyState.CHASE:
		_retarget_timer = 0.0

func take_damage(damage_input: Variant, p_damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> void:
	if is_dead or spawn_grace:
		return

	var info: DamageInfo = null
	if damage_input is DamageInfo:
		info = damage_input
	elif damage_input is int:
		info = DamageInfo.new(damage_input, p_damage_type)

	if info == null:
		return

	if info.source != null and is_instance_valid(info.source) and info.source.is_in_group(&"commander"):
		provoked_by_player = true
		provoked_timer = GameConfig.aggro_duration

	if info.knockback_force > 0.0 and (data == null or not data.knockback_immune):
		if knockback_immunity_timer <= 0.0:
			var kb_dir := info.hit_direction
			kb_dir.y = 0.0
			velocity += kb_dir.normalized() * (info.knockback_force * KNOCKBACK_IMPULSE_SCALE)
			if current_state == Enums.EnemyState.ATTACK:
				attack_windup_timer = 0.0
				is_attacking_active = false
			_previous_state = current_state if current_state != Enums.EnemyState.STAGGER else _previous_state
			change_state(Enums.EnemyState.STAGGER)
			stagger_timer = GameConfig.enemy_stagger_time

	health.take_damage(info)

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	change_state(Enums.EnemyState.DEAD)
	set_physics_process(false)

	var col_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape != null:
		col_shape.set_deferred("disabled", true)
	var hurt_shape := get_node_or_null("HurtBox/CollisionShape3D") as CollisionShape3D
	if hurt_shape != null:
		hurt_shape.set_deferred("disabled", true)

	if data != null:
		EventBus.enemy_died.emit(data.id, global_position, data.gold_reward, data.prestige_reward, false)
	queue_free()
