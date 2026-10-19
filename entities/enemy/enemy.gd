class_name Enemy
extends CharacterBody3D
 
## Base enemy controller with state machine, navigation, spawn grace, and combat behaviors.
## Supports melee and ranged archetypes, prioritized targeting rules, and crowd optimizations.
 
signal state_changed(new_state: Enums.EnemyState, old_state: Enums.EnemyState)
 
const PATH_UPDATE_INTERVAL: float = 0.3
const KNOCKBACK_IMPULSE_SCALE: float = 10.0  # Scales knockback force into instantaneous velocity
## slot holder blocked by the units already at the target swings.
const STALL_ATTACK_TIME: float = 0.5
 
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
var taunted_by_player: bool = false
var taunt_timer: float = 0.0
var stagger_timer: float = 0.0
var knockback_immunity_timer: float = 0.0
var knockback_immune: bool:
	get:
		return data.knockback_immune if data != null else false
 
var life_timer: float = 0.0
var straggler_marked: bool = false
var is_frenzied: bool = false
var wait_timer: float = 0.0
var _retarget_timer: float = 0.0
var _path_timer: float = 0.0
var _full_targets_until: Dictionary = {}
## Avoidance: safe velocity the NavAgent returned for the last desired velocity.
var _safe_velocity: Vector3 = Vector3.ZERO
var _has_safe_velocity: bool = false
var _stall_time: float = 0.0
## Side of the current sidestep while blocked: +1 left, -1 right, 0 none chosen yet.
var _sidestep_sign: float = 0.0
## Stall time at which the sidestep tries the other side.
var _sidestep_flip_at: float = 1.0
 
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
 
var anim_player: AnimationPlayer = null
var _base_anim_speed: float = 1.0
 
# Shared node cache per physics frame to avoid get_nodes_in_group garbage collection overhead
static var _cached_barricades: Array[Node] = []
static var _cached_towers: Array[Node] = []
static var _cached_enemies: Array[Node] = []
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
 
	_setup_anim_player()
 
	health.max_hp = data.base_hp
	health.hp = data.base_hp
	health.died.connect(_on_died)
 
	nav.radius = data.avoid_radius
	nav.path_desired_distance = 1.0
	nav.target_desired_distance = data.attack_range if data else 1.0
	# Steer around Barricades, rubble (NavigationObstacle3D) and other units; the navmesh is not re-baked (SLOT-03).
	nav.avoidance_enabled = true
	nav.velocity_computed.connect(_on_velocity_computed)
 
	_init_spawn_zone_bounds()
	_play_locomotion_anim()
	_setup_navigation.call_deferred()
 
func _setup_anim_player() -> void:
	anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_update_anim_speed()
 
func _update_anim_speed() -> void:
	if anim_player != null and is_instance_valid(anim_player):
		anim_player.speed_scale = _base_anim_speed
 
func play_anim(clip_name: StringName, base_speed: float = 1.0) -> void:
	if anim_player == null or not is_instance_valid(anim_player):
		return
	if not anim_player.has_animation(clip_name):
		return
	_base_anim_speed = base_speed
	_update_anim_speed()
	anim_player.play(clip_name)
 
func _play_locomotion_anim() -> void:
	var clip: StringName = data.anim_walk if (data != null and not data.anim_walk.is_empty()) else &"move/Running_A"
	play_anim(clip, 1.0)
 
func _play_attack_anim() -> void:
	var clip: StringName = data.anim_attack if (data != null and not data.anim_attack.is_empty()) else &"melee/Melee_1H_Attack_Slice_Diagonal"
	play_anim(clip, 1.0)
 
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
			_play_locomotion_anim()
		Enums.EnemyState.ADVANCE:
			_retarget_timer = 0.0
			_play_locomotion_anim()
		Enums.EnemyState.CHASE:
			_retarget_timer = 0.0
			_play_locomotion_anim()
		Enums.EnemyState.ATTACK:
			attack_windup_timer = 0.0
			attack_recovery_timer = 0.0
			is_attacking_active = false
			velocity = Vector3.ZERO
			_play_attack_anim()
		Enums.EnemyState.STAGGER:
			play_anim(&"general/Hit_B", 1.0)
		Enums.EnemyState.WAIT:
			wait_timer = 0.0
			velocity = Vector3.ZERO
			play_anim(&"general/Idle_B", 1.0)
		Enums.EnemyState.FRENZY:
			if not is_frenzied:
				is_frenzied = true
				EventBus.frenzy_started.emit(self)
			speed_multiplier = GameConfig.frenzy_speed_mult
			_play_locomotion_anim()
			_find_default_target()
		Enums.EnemyState.DEAD:
			set_physics_process(false)
			velocity = Vector3.ZERO
			_play_death_anim()
 
func _physics_process(delta: float) -> void:
	if is_dead:
		return
 
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
 
	_update_timers(delta)
	_update_state(delta)
	_apply_avoidance(delta)
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
 
	if taunt_timer > 0.0:
		taunt_timer -= delta
		if taunt_timer <= 0.0:
			taunted_by_player = false
			_find_best_target()
		elif taunted_by_player:
			var cmd := _get_valid_commander()
			if cmd == null or global_position.distance_to(cmd.global_position) > GameConfig.leash_distance:
				taunted_by_player = false
				taunt_timer = 0.0
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
				if not _keeps_slot_target():
					_find_best_target()
 
			if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
				_retarget_now()
				return
 
			if not _try_hold_melee_slot(current_target):
				change_state(Enums.EnemyState.WAIT)
				return
 
			var diff := _get_attack_point(current_target) - global_position
			diff.y = 0.0
			var dist_to_target: float = diff.length()
			var attack_rng: float = data.attack_range if data else 1.5
			attack_rng = minf(attack_rng, _slot_arrive_distance(current_target))
			if dist_to_target <= attack_rng:
				change_state(Enums.EnemyState.ATTACK)
				return
			# CRD-01: holding a slot but boxed in by the units already there; hit from here when in reach.
			if (_stall_time >= STALL_ATTACK_TIME and dist_to_target <= _melee_reach()
					and _uses_melee_slot(current_target) and current_target.has_melee_slot(self)):
				change_state(Enums.EnemyState.ATTACK)
				return
			# CRD-02: give the slot up, skip this target for a while and choose another one.
			if _stall_time >= GameConfig.crowd_wait_retarget_time and _uses_melee_slot(current_target):
				var stuck_on := current_target
				_release_melee_slot()
				_skip_full_target(stuck_on)
				_stall_time = 0.0
				_retarget_now()
				return
 
			_update_target_tracking(delta)
			_update_navigation_movement(delta)
 
		Enums.EnemyState.ATTACK:
			velocity.x = 0.0
			velocity.z = 0.0
			# ETG-04: finish the swing before choosing again, unless the target died or became RUINED (ETG-03).
			if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
				_retarget_now()
				return
 
			if current_target != null and is_instance_valid(current_target):
				var look_dir := (_get_attack_point(current_target) - global_position)
				look_dir.y = 0.0
				if look_dir.length_squared() > 0.001:
					var target_yaw := atan2(look_dir.x, look_dir.z)
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
						var diff_after := _get_attack_point(current_target) - global_position
						diff_after.y = 0.0
						var dist_after: float = diff_after.length()
						if dist_after <= _melee_reach():
							attack_windup_timer = 0.0
							_play_attack_anim()
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
			if not is_instance_valid(current_target) or not _is_target_valid(current_target):
				_retarget_now()
				return
			wait_timer += delta
			if wait_timer >= GameConfig.crowd_wait_retarget_time:
				wait_timer = 0.0
				# CRD-02: still full after the wait, skip it for a while and choose again.
				_skip_full_target(current_target)
				_retarget_now()
 
		Enums.EnemyState.FRENZY:
			if current_target == null or not is_instance_valid(current_target) or not current_target.is_in_group(&"fortress"):
				_find_default_target()
			if current_target != null and is_instance_valid(current_target):
				_try_hold_melee_slot(current_target)
				var diff_f := _get_attack_point(current_target) - global_position
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
 
	var diff := _get_attack_point(current_target) - global_position
	diff.y = 0.0
	var dist := diff.length()
	var max_reach := (data.attack_range if data else 1.5) + 0.6
	if dist > max_reach:
		return
 
	if current_target.has_method("take_damage"):
		var dmg := data.base_damage if data else 6
		var dmg_type := data.damage_type if data else Enums.DamageType.SLASH
		var hit_dir := diff.normalized() if diff.length_squared() > 0.001 else Vector3.FORWARD
		var kb_force: float = data.knockback_force if data != null else 0.0
		var info := DamageInfo.new(dmg, dmg_type, self, kb_force, hit_dir)
		current_target.take_damage(info)
 
func _move_towards_direction(dir: Vector3) -> void:
	var move_dir := dir
	move_dir.y = 0.0
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		var move_speed: float = (data.move_speed if data else 3.5) * speed_multiplier
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		var target_yaw := atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 0.2)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
 
func _update_target_tracking(delta: float) -> void:
	_path_timer += delta
	if _path_timer >= PATH_UPDATE_INTERVAL:
		_path_timer = 0.0
		if current_target != null and is_instance_valid(current_target):
			nav.target_position = _get_attack_point(current_target)
		elif has_target_position:
			nav.target_position = current_target_position
		else:
			_find_default_target()
 
func _update_navigation_movement(_delta: float) -> void:
	var target_dest := Vector3.ZERO
	if current_target != null and is_instance_valid(current_target):
		target_dest = _get_attack_point(current_target)
	elif has_target_position:
		target_dest = current_target_position
 
	var direct_diff := target_dest - global_position
	direct_diff.y = 0.0
	var dist_to_dest := direct_diff.length()
 
	# Stop if navigation agent finished and enemy reached the target distance
	if nav.is_navigation_finished() and dist_to_dest <= nav.target_desired_distance:
		velocity.x = move_toward(velocity.x, 0.0, 1.0)
		velocity.z = move_toward(velocity.z, 0.0, 1.0)
		return
 
	var next_path_pos := nav.get_next_path_position()
	var move_dir := (next_path_pos - global_position)
	move_dir.y = 0.0
 
	# Fallback to direct steering if navigation mesh is unavailable or path vector is empty
	if move_dir.length_squared() <= 0.001 and dist_to_dest > 0.1:
		move_dir = direct_diff
 
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		var move_speed: float = (data.move_speed if data else 3.5) * speed_multiplier
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
 
		var target_yaw := atan2(move_dir.x, move_dir.z)
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
		_cached_enemies = get_tree().get_nodes_in_group(&"enemy")
 
func _is_target_ahead(target_pos: Vector3, tolerance: float = 0.5) -> bool:
	var advance_dir := Vector3(-1.0, 0.0, 0.0)
	var to_target := (target_pos - global_position)
	to_target.y = 0.0
	return to_target.dot(advance_dir) >= -tolerance
 
func _is_target_valid(t: Node3D) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if _is_skipped_full_target(t):
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
 
	if t.is_in_group(&"barricade") or _is_barricade(t):
		if "health" in t and t.health != null and t.health.hp <= 0:
			return false
		return true
 
	if t.is_in_group(&"tower"):
		var is_wall: bool = false
		if t.is_in_group(&"tower_wall"):
			is_wall = true
		elif t.has_meta("is_wall"):
			is_wall = bool(t.get_meta("is_wall"))
		elif "slot" in t and t.slot != null and "zone" in t.slot:
			is_wall = (t.slot.zone == Enums.SlotZone.WALL)
		elif t.get_parent() != null and "zone" in t.get_parent():
			is_wall = (t.get_parent().zone == Enums.SlotZone.WALL)
		elif t.get_parent() != null and t.get_parent().get_parent() != null and "zone" in t.get_parent().get_parent():
			is_wall = (t.get_parent().get_parent().zone == Enums.SlotZone.WALL)
		elif t.global_position.y >= 2.5:
			is_wall = true
 
		# Melee ground units cannot target wall towers (ETG-01)
		var can_target_wall := (data != null and (data.is_ranged or data.is_flying))
		if is_wall and not can_target_wall:
			return false
		if "health" in t and t.health != null and t.health.hp <= 0:
			return false
		return true
 
	return false
 
func _is_barricade(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group(&"barricade"):
		return true
	if "data" in node and node.data != null and "id" in node.data:
		if node.data.id == &"barricade":
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
	var min_score: float = INF
	var best_id: int = 0
 
	var candidates: Array[Node] = []
	for b in _cached_barricades:
		if b not in candidates:
			candidates.append(b)
	for tw in _cached_towers:
		if _is_barricade(tw) and tw not in candidates:
			candidates.append(tw)
 
	for b in candidates:
		var b_node := b as Node3D
		if b_node != null and is_instance_valid(b_node) and _is_target_valid(b_node):
			if not _is_target_ahead(b_node.global_position):
				continue
			var d := global_position.distance_to(b_node.global_position)
			var weight: float = 1.0
			if "aggro_weight" in b_node:
				weight = float(b_node.aggro_weight)
			elif "level" in b_node:
				var lv: int = b_node.level
				if lv == 2:
					weight = 1.2
				elif lv >= 3:
					weight = 1.5
			var score: float = d / maxf(0.1, weight)
 
			# Tie-break: score first, then instance id (ETG-07)
			if score < min_score - 0.001:
				min_score = score
				closest = b_node
				best_id = b_node.get_instance_id()
			elif absf(score - min_score) <= 0.001:
				var cur_id := b_node.get_instance_id()
				if cur_id < best_id:
					min_score = score
					closest = b_node
					best_id = cur_id
	return closest
 
func _find_closest_valid_tower(wall_only: bool) -> Node3D:
	_update_node_cache()
	var closest: Node3D = null
	var min_dist: float = INF
	var best_id: int = 0
	for tw in _cached_towers:
		var tw_node := tw as Node3D
		if tw_node != null and is_instance_valid(tw_node) and _is_target_valid(tw_node):
			if _is_barricade(tw_node):
				continue
			var is_wall: bool = false
			if tw_node.is_in_group(&"tower_wall"):
				is_wall = true
			elif tw_node.has_meta("is_wall"):
				is_wall = bool(tw_node.get_meta("is_wall"))
			elif "slot" in tw_node and tw_node.slot != null and "zone" in tw_node.slot:
				is_wall = (tw_node.slot.zone == Enums.SlotZone.WALL)
			elif tw_node.get_parent() != null and "zone" in tw_node.get_parent():
				is_wall = (tw_node.get_parent().zone == Enums.SlotZone.WALL)
			elif tw_node.global_position.y >= 2.5:
				is_wall = true
 
			if wall_only != is_wall:
				continue
			if not _is_target_ahead(tw_node.global_position):
				continue
			var d := global_position.distance_to(tw_node.global_position)
			if d < min_dist - 0.001:
				min_dist = d
				closest = tw_node
				best_id = tw_node.get_instance_id()
			elif absf(d - min_dist) <= 0.001:
				var cur_id := tw_node.get_instance_id()
				if cur_id < best_id:
					min_dist = d
					closest = tw_node
					best_id = cur_id
	return closest
 
func _find_closest_valid_tower_any() -> Node3D:
	_update_node_cache()
	var closest: Node3D = null
	var min_dist: float = INF
	var best_id: int = 0
	for tw in _cached_towers:
		var tw_node := tw as Node3D
		if tw_node != null and is_instance_valid(tw_node) and _is_target_valid(tw_node):
			if _is_barricade(tw_node):
				continue
			if not _is_target_ahead(tw_node.global_position):
				continue
			var d := global_position.distance_to(tw_node.global_position)
			if d < min_dist - 0.001:
				min_dist = d
				closest = tw_node
				best_id = tw_node.get_instance_id()
			elif absf(d - min_dist) <= 0.001:
				var cur_id := tw_node.get_instance_id()
				if cur_id < best_id:
					min_dist = d
					closest = tw_node
					best_id = cur_id
	return closest
 
func _find_best_target() -> void:
	if current_state == Enums.EnemyState.FRENZY:
		_find_default_target()
		return
 
	# Battle Cry taunt overrides regular targeting rules up to leash distance
	if taunted_by_player:
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
				taunted_by_player = false
				taunt_timer = 0.0
				provoked_by_player = false
				provoked_timer = 0.0
 
	# Attack hit provocation overrides regular rules within aggro range
	if provoked_by_player:
		var cmd := _get_valid_commander()
		if cmd != null:
			var dist_to_cmd := global_position.distance_to(cmd.global_position)
			var max_range: float = data.aggro_range if data != null else 10.0
			if dist_to_cmd <= max_range:
				var is_melee := (data != null and not data.is_ranged and not data.is_flying)
				if is_melee and current_target != cmd and _get_active_melee_attackers_count(cmd) >= GameConfig.max_aggro_melee:
					set_target(cmd)
					change_state(Enums.EnemyState.WAIT)
					return
				set_target(cmd)
				return
 
	if data == null or data.target_rules.is_empty():
		_find_default_target()
		return
 
	# Evaluate targets in prioritized order from data.target_rules
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
 
			&"TOWER":
				var closest_tower := _find_closest_valid_tower_any()
				if closest_tower != null:
					set_target(closest_tower)
					return
 
			&"TOWER_GROUND":
				if data.is_ranged or data.is_flying:
					var closest_tower := _find_closest_valid_tower_any()
					if closest_tower != null:
						set_target(closest_tower)
						return
				else:
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
	if target_node != current_target:
		_release_melee_slot()
	current_target = target_node
	has_target_position = false
	if current_target != null:
		nav.target_position = _get_attack_point(current_target)
 
func set_target_position(target_pos: Vector3) -> void:
	_release_melee_slot()
	current_target = null
	current_target_position = target_pos
	has_target_position = true
	nav.target_position = target_pos
 
## Attack point: the Fortress returns the claimed slot position (or the gate center); other targets use their own position.
func _get_attack_point(t: Node3D) -> Vector3:
	if t.has_method(&"get_melee_slot_position"):
		return t.get_melee_slot_position(self)
	return t.global_position
 
## Only ground melee units use attack slots (CRD-06: flying and ranged units do not take slots).
func _uses_melee_slot(t: Node3D) -> bool:
	if t == null or not is_instance_valid(t) or not t.has_method(&"claim_melee_slot"):
		return false
	return data == null or not (data.is_ranged or data.is_flying)
 
## Returns false when the unit must WAIT: within crowd_claim_distance of the Fortress and no slot is free.
## Distance is measured along the corridor (X axis), since slots are spread across the gate width.
func _try_hold_melee_slot(t: Node3D) -> bool:
	if not _uses_melee_slot(t) or t.has_melee_slot(self):
		return true
	var gate: Vector3 = t.get_melee_slot_position(self)
	if absf(global_position.x - gate.x) > GameConfig.crowd_claim_distance:
		return true
	if t.claim_melee_slot(self):
		nav.target_position = t.get_melee_slot_position(self)
		nav.target_desired_distance = minf(nav.target_desired_distance, _slot_arrive_distance(t))
		return true
	return is_frenzied
 
## A unit that already holds a melee slot keeps that target on the periodic scan, even when it
## walks a little past it to reach its slot . The commander hit or taunt it still pulls it away (ETG-03), and a dead or RUINED target ends it.
func _keeps_slot_target() -> bool:
	if provoked_by_player or taunted_by_player:
		return false
	if current_target == null or not is_instance_valid(current_target):
		return false
	return (_is_target_valid(current_target) and _uses_melee_slot(current_target)
		and current_target.has_melee_slot(self))

## Same reach as the strike check in _execute_melee_strike.
func _melee_reach() -> float:
	return (data.attack_range if data else 1.5) + 0.6

## Targets with widely spaced slots (Barricade) ask units to walk onto their slot before swinging,
## so they do not stop attack_range short and block the way to the slots next to them (CRD-01).
func _slot_arrive_distance(t: Node3D) -> float:
	if t == null or not is_instance_valid(t) or not t.has_method(&"get_melee_arrive_distance"):
		return INF
	if not _uses_melee_slot(t) or not t.has_melee_slot(self):
		return INF
	return t.get_melee_arrive_distance()

func _release_melee_slot() -> void:
	nav.target_desired_distance = data.attack_range if data else 1.0
	if current_target != null and is_instance_valid(current_target) and current_target.has_method(&"release_melee_slot"):
		current_target.release_melee_slot(self)
 
func _get_active_melee_attackers_count(cmd: Node3D) -> int:
	var count: int = 0
	_update_node_cache()
	for e in _cached_enemies:
		if e == self or not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var other := e as Enemy
		if other == null or other.is_dead:
			continue
		if other.current_target == cmd:
			var other_is_melee := (other.data != null and not other.data.is_ranged and not other.data.is_flying)
			if other_is_melee and (other.current_state == Enums.EnemyState.CHASE or other.current_state == Enums.EnemyState.ATTACK):
				count += 1
				if count >= GameConfig.max_aggro_melee:
					return count
	return count
 
## ETG-03: target died, became RUINED/skipped. Choose again instead of waiting for the next retarget_interval scan. 
func _retarget_now() -> void:
	if is_frenzied:
		change_state(Enums.EnemyState.FRENZY)
		return
	change_state(Enums.EnemyState.ADVANCE)
	_find_best_target()

## CRD-02: after waiting crowd_wait_retarget_time on a full melee target, ignore it so the unit picks another one. The Fortress is never skipped (ETG-06).
func _skip_full_target(t) -> void:
	if not is_instance_valid(t) or not _uses_melee_slot(t):
		return
	if t.is_in_group(&"fortress") or t.has_melee_slot(self):
		return
	_full_targets_until[t.get_instance_id()] = life_timer + GameConfig.crowd_full_target_ignore_time

func _is_skipped_full_target(t: Node3D) -> bool:
	var id := t.get_instance_id()
	if not _full_targets_until.has(id):
		return false
	if life_timer >= float(_full_targets_until[id]):
		_full_targets_until.erase(id)
		return false
	return true

## Walking states hand their velocity to the NavAgent and move with the safe velocity it
## returns (one physics frame later). Standing, attacking and knockback keep their own velocity.
func _apply_avoidance(delta: float) -> void:
	if not nav.avoidance_enabled:
		return
	var walking := (current_state == Enums.EnemyState.ADVANCE
		or current_state == Enums.EnemyState.CHASE
		or current_state == Enums.EnemyState.FRENZY)
	var desired := Vector3(velocity.x, 0.0, velocity.z) if walking else Vector3.ZERO
	var blocked := (walking and _has_safe_velocity and desired.length() > 0.1
		and _safe_velocity.length() < desired.length() * 0.25)
	_stall_time = _stall_time + delta if blocked else 0.0
	if not blocked:
		_sidestep_sign = 0.0
		_sidestep_flip_at = 1.0
	var feed := desired
	# RVO stops that walks straight at an obstacle or at a standing crowd, and never picks a side. Ask for a sideways move instead
	var to_dest := Vector3(nav.target_position.x - global_position.x, 0.0, nav.target_position.z - global_position.z)
	if blocked and to_dest.length() > 1.5:
		var left := Vector3(-desired.z, 0.0, desired.x).normalized()
		if _sidestep_sign == 0.0:
			_sidestep_sign = _pick_sidestep(left, to_dest)
		elif _stall_time >= _sidestep_flip_at:
			_sidestep_sign = -_sidestep_sign
			_sidestep_flip_at += 1.0
		feed = (desired.normalized() * 0.35 + left * _sidestep_sign).normalized() * desired.length()
	nav.max_speed = maxf(desired.length(), 0.01)
	nav.velocity = feed
	if walking and _has_safe_velocity and desired.length_squared() > 0.001:
		velocity.x = _safe_velocity.x
		velocity.z = _safe_velocity.z

## +1 = step left, -1 = step right. The side the destination lies on; when it is straight ahead,
## the side with open navmesh (not a corridor wall).
func _pick_sidestep(left: Vector3, to_dest: Vector3) -> float:
	var lean := left.dot(to_dest.normalized())
	if absf(lean) > 0.3:
		return signf(lean)
	var map := nav.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return 1.0  # map not synced yet (first frames)
	var l := global_position + left * 1.2
	var r := global_position - left * 1.2
	var off_l := Vector2(NavigationServer3D.map_get_closest_point(map, l).x - l.x, NavigationServer3D.map_get_closest_point(map, l).z - l.z).length()
	var off_r := Vector2(NavigationServer3D.map_get_closest_point(map, r).x - r.x, NavigationServer3D.map_get_closest_point(map, r).z - r.z).length()
	return 1.0 if off_l <= off_r else -1.0

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	_safe_velocity = safe_velocity
	_has_safe_velocity = true
 
func apply_commander_taunt(commander_node: Node3D, duration: float) -> void:
	if is_dead or spawn_grace or is_in_spawn_zone:
		return
	if commander_node == null or not is_instance_valid(commander_node):
		return
 
	# Bosses are immune to taunt
	var is_boss: bool = is_in_group(&"boss") or (data != null and data is BossData) or (get("is_boss") == true)
	if is_boss:
		return
 
	taunted_by_player = true
	taunt_timer = maxf(taunt_timer, duration)
	provoked_by_player = true
	provoked_timer = maxf(provoked_timer, duration)
 
	# Check melee attacker capacity on Commander
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
 
	if info.knockback_force > 0.0:
		var kb_dir := info.hit_direction
		kb_dir.y = 0.0
		var dir_norm := kb_dir.normalized() if kb_dir.length_squared() > 0.001 else Vector3.FORWARD
		apply_knockback(dir_norm * info.knockback_force)
 
	health.take_damage(info)
 
func apply_knockback(force_vector: Vector3) -> void:
	if is_dead or spawn_grace:
		return
	var is_boss: bool = is_in_group(&"boss") or (data != null and data is BossData) or (get("is_boss") == true)
	if is_boss or knockback_immune:
		return
	if knockback_immunity_timer > 0.0:
		return
	var kb_dir := force_vector
	kb_dir.y = 0.0
	var force_mag := force_vector.length()
	if force_mag <= 0.001 or kb_dir.length_squared() <= 0.001:
		return
	velocity += kb_dir.normalized() * (force_mag * KNOCKBACK_IMPULSE_SCALE)
	if current_state == Enums.EnemyState.ATTACK:
		attack_windup_timer = 0.0
		is_attacking_active = false
	_previous_state = current_state if current_state != Enums.EnemyState.STAGGER else _previous_state
	change_state(Enums.EnemyState.STAGGER)
	stagger_timer = GameConfig.enemy_stagger_time
 
func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	_release_melee_slot()
	remove_from_group(&"enemy")
	collision_layer = 0
	collision_mask = 0
 
	var col_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape != null:
		col_shape.set_deferred("disabled", true)
	var hurt_shape := get_node_or_null("HurtBox/CollisionShape3D") as CollisionShape3D
	if hurt_shape != null:
		hurt_shape.set_deferred("disabled", true)
 
	if data != null:
		EventBus.enemy_died.emit(data.id, global_position, data.gold_reward, data.prestige_reward, false)
 
	change_state(Enums.EnemyState.DEAD)
 
func _play_death_anim() -> void:
	var death_anim: StringName = &""
	if anim_player != null:
		if anim_player.has_animation(&"general/Death_A"):
			death_anim = &"general/Death_A"
		elif anim_player.has_animation(&"general/Death_B"):
			death_anim = &"general/Death_B"
		elif anim_player.has_animation(&"Death_A"):
			death_anim = &"Death_A"
		elif anim_player.has_animation(&"Death_B"):
			death_anim = &"Death_B"
 
	if not death_anim.is_empty():
		play_anim(death_anim, 1.0)
		var delay: float = 0.8
		if anim_player != null and anim_player.has_animation(death_anim):
			var anim: Animation = anim_player.get_animation(death_anim)
			if anim != null and anim.length > 0.0:
				delay = anim.length
		var tree := get_tree()
		if tree != null:
			var timer := tree.create_timer(delay)
			timer.timeout.connect(func():
				if is_instance_valid(self):
					queue_free()
			)
		else:
			queue_free()
	else:
		queue_free()
 
