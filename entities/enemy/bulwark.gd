class_name Bulwark
extends Enemy

const WALK_ANIM_BASE_SPEED: float = 1.42

var stomp_damage: int:
	get:
		var boss_data := data as BossData
		return boss_data.stomp_damage if boss_data != null else 45

var effective_stomp_damage: int:
	get:
		if wave_dmg_mult <= 0.0 and not is_enraged:
			return stomp_damage
		var dmg: float = float(stomp_damage)
		if wave_dmg_mult > 0.0:
			dmg *= wave_dmg_mult
		if is_enraged:
			dmg *= GameConfig.enrage_damage_mult
		return maxi(1, int(round(dmg)))

var stomp_radius: float:
	get:
		var boss_data := data as BossData
		return boss_data.stomp_radius if boss_data != null else 3.0

var stomp_knockback: float:
	get:
		var boss_data := data as BossData
		return boss_data.stomp_knockback if boss_data != null else 3.0

var stomp_stun_duration: float:
	get:
		var boss_data := data as BossData
		return boss_data.stomp_stun_duration if boss_data != null else 0.0

var current_phase: Enums.BossPhase = Enums.BossPhase.ARMORED
var current_armor_hp: int = 1200
var max_armor_hp: int = 1200
var current_core_hp: int = 900
var max_core_hp: int = 900
var phase_broken: bool = false
var is_enraged: bool = false

var _transition_timer: float = 0.0
var _cached_boss_melee_point: Node3D = null

var _stuck_timer: float = 0.0
var _last_stuck_progress: float = -INF
var _normal_progress_timer: float = 0.0
var _current_stuck_tier: int = 0


func _ready() -> void:
	super._ready()
	add_to_group(&"boss")
	_init_boss_stats()
	EventBus.boss_enraged.connect(enter_enrage)


func _exit_tree() -> void:
	if EventBus.boss_enraged.is_connected(enter_enrage):
		EventBus.boss_enraged.disconnect(enter_enrage)


## Faster movement, quicker stomps and harder hits for the rest of the fight. Idempotent.
func enter_enrage() -> void:
	if is_enraged or is_dead:
		return
	is_enraged = true
	speed_multiplier *= GameConfig.enrage_speed_mult


func _init_boss_stats() -> void:
	var boss_data := data as BossData
	if boss_data != null:
		max_armor_hp = boss_data.get_scaled_armor_hp(wave_hp_mult)
		current_armor_hp = max_armor_hp
		max_core_hp = boss_data.get_scaled_core_hp(wave_hp_mult)
		current_core_hp = max_core_hp
		if health != null:
			health.max_hp = max_armor_hp + max_core_hp
			health.hp = health.max_hp
		EventBus.boss_hp_changed.emit(current_armor_hp, current_core_hp, _get_phase_name())
		EventBus.boss_phase_changed.emit(_get_phase_name())


func apply_wave_scale(hp_mult: float, dmg_mult: float, p_speed_mult: float, wave_num: int = 1, p_scale_config: ScaleConfig = null) -> void:
	super.apply_wave_scale(hp_mult, dmg_mult, p_speed_mult, wave_num, p_scale_config)
	_init_boss_stats()


func _physics_process(delta: float) -> void:
	if current_phase == Enums.BossPhase.TRANSITION:
		velocity = Vector3.ZERO
		_tick_status(delta)
		_transition_timer -= delta
		if _transition_timer <= 0.0:
			_on_transition_finished()
		return
	super._physics_process(delta)
	_update_stuck_detection(delta)


func get_resist(dmg_type: Enums.DamageType) -> float:
	var boss_data := data as BossData
	if boss_data == null:
		return 1.0
	return boss_data.get_resist(dmg_type, current_phase)


func take_damage(damage_input: Variant, p_damage_type: Enums.DamageType = Enums.DamageType.SLASH) -> int:
	if is_dead or spawn_grace:
		return 0

	var info: DamageInfo = null
	if damage_input is DamageInfo:
		info = damage_input
	elif damage_input is int:
		info = DamageInfo.new(damage_input, p_damage_type)

	if info == null:
		return 0

	if info.source != null and is_instance_valid(info.source) and info.source.is_in_group(&"commander"):
		provoked_by_player = true
		provoked_timer = GameConfig.aggro_duration

	var effective_damage: int = DamageCalc.resolve(info, self)
	if effective_damage <= 0:
		if info.immune and info.is_from_commander():
			EventBus.damage_immune.emit(self, info)
		return 0

	if effective_damage >= 1 and health != null and not health.hit_by_commander:
		if info != null and (info.hit_by_commander or info.is_from_commander()):
			health.hit_by_commander = true

	match current_phase:
		Enums.BossPhase.ARMORED:
			if effective_damage >= current_armor_hp:
				var absorbed := current_armor_hp
				current_armor_hp = 0
				if health != null:
					health.hp = current_core_hp
					health.hp_changed.emit(health.hp, health.max_hp)
					health.damaged.emit(absorbed, info)
				EventBus.boss_hp_changed.emit(current_armor_hp, current_core_hp, _get_phase_name())
				_start_armor_break_transition()
			else:
				current_armor_hp -= effective_damage
				if health != null:
					health.hp = current_core_hp + current_armor_hp
					health.hp_changed.emit(health.hp, health.max_hp)
					health.damaged.emit(effective_damage, info)
				EventBus.boss_hp_changed.emit(current_armor_hp, current_core_hp, _get_phase_name())

		Enums.BossPhase.TRANSITION, Enums.BossPhase.EXPOSED:
			current_core_hp = maxi(0, current_core_hp - effective_damage)
			if health != null:
				health.hp = current_core_hp
				health.hp_changed.emit(health.hp, health.max_hp)
				health.damaged.emit(effective_damage, info)
				if current_core_hp == 0:
					health.died.emit()
			EventBus.boss_hp_changed.emit(current_armor_hp, current_core_hp, _get_phase_name())
	return effective_damage


func _start_armor_break_transition() -> void:
	if phase_broken:
		return
	phase_broken = true
	current_phase = Enums.BossPhase.TRANSITION

	var boss_data := data as BossData
	_transition_timer = boss_data.transition_duration if boss_data != null else 2.5
	EventBus.boss_phase_changed.emit(&"TRANSITION")
	EventBus.boss_hp_changed.emit(current_armor_hp, current_core_hp, &"TRANSITION")


func _on_transition_finished() -> void:
	if is_dead:
		return
	current_phase = Enums.BossPhase.EXPOSED
	var boss_data := data as BossData
	if boss_data != null:
		speed_multiplier = wave_speed_mult * boss_data.phase2_speed_mult
		if is_enraged:
			speed_multiplier *= GameConfig.enrage_speed_mult
	EventBus.boss_phase_changed.emit(&"EXPOSED")
	EventBus.boss_hp_changed.emit(current_armor_hp, current_core_hp, &"EXPOSED")


func _get_phase_name() -> StringName:
	match current_phase:
		Enums.BossPhase.ARMORED:
			return &"ARMORED"
		Enums.BossPhase.TRANSITION:
			return &"TRANSITION"
		Enums.BossPhase.EXPOSED:
			return &"EXPOSED"
	return &"ARMORED"


func _on_died() -> void:
	if is_dead:
		return
	EventBus.boss_hp_changed.emit(0, 0, _get_phase_name())
	super._on_died()
	EventBus.boss_defeated.emit()


func _get_attack_windup() -> float:
	var boss_data := data as BossData
	return boss_data.stomp_windup if boss_data != null else 1.0


func _get_attack_interval() -> float:
	var boss_data := data as BossData
	if boss_data == null:
		return 2.5
	var interval: float = boss_data.attack_interval
	if current_phase == Enums.BossPhase.EXPOSED:
		interval /= maxf(0.1, boss_data.phase2_attack_rate_mult)
	if is_enraged:
		interval /= maxf(0.1, GameConfig.enrage_attack_rate_mult)
	return interval


func _play_locomotion_anim() -> void:
	if anim_player == null:
		return
	var walk_clip: StringName = data.anim_walk if (data != null and not data.anim_walk.is_empty()) else &"move/Walking_A"
	if anim_player.has_animation(walk_clip):
		var base_speed: float = data.move_speed if data != null else 1.6
		var target_speed: float = base_speed * speed_multiplier * get_slow_factor()
		anim_player.speed_scale = target_speed / WALK_ANIM_BASE_SPEED
		anim_player.play(walk_clip)


func _play_attack_anim() -> void:
	EventBus.telegraph_started.emit(&"stomp", global_position, stomp_radius, _get_attack_windup())
	if anim_player != null and anim_player.has_animation(&"melee/Melee_2H_Slam"):
		anim_player.speed_scale = 1.0
		anim_player.play(&"melee/Melee_2H_Slam", 0.05, 1.0)


func _execute_attack_action() -> void:
	execute_stomp()
	if anim_player == null or not anim_player.is_playing():
		return
	# Enrage shortens the interval in phase 1 too, so the recovery clip must speed up there as well.
	if current_phase != Enums.BossPhase.EXPOSED and not is_enraged:
		return
	var recovery_time: float = _get_attack_interval() - _get_attack_windup() - 0.15
	var recovery_speed: float = (2.37 - 0.97) / maxf(0.1, recovery_time)
	anim_player.speed_scale = recovery_speed


func execute_stomp() -> void:
	if is_dead:
		return

	var tree := get_tree()
	if tree == null:
		return

	var boss_data := data as BossData
	var shake: float = boss_data.stomp_screen_shake if boss_data != null else 0.6
	EventBus.screen_shake_requested.emit(shake, &"stomp")

	var radius := stomp_radius
	var stomp_pos := global_position
	var targets: Array[Node3D] = []

	var commander := tree.get_first_node_in_group(&"commander") as Node3D
	if commander != null and is_instance_valid(commander):
		if _get_distance_to_target(commander, stomp_pos) <= radius:
			targets.append(commander)

	var structure_groups: Array[StringName] = [&"tower", &"fortress", &"barricade"]
	for grp in structure_groups:
		var nodes := tree.get_nodes_in_group(grp)
		for node in nodes:
			var node3d := node as Node3D
			if node3d != null and is_instance_valid(node3d) and not targets.has(node3d):
				if _get_distance_to_target(node3d, stomp_pos) <= radius:
					targets.append(node3d)

	for tgt in targets:
		if not is_instance_valid(tgt) or not tgt.has_method("take_damage"):
			continue

		var diff := tgt.global_position - global_position
		diff.y = 0.0
		var hit_dir := diff.normalized() if diff.length_squared() > 0.001 else Vector3.FORWARD

		var is_cmd := tgt.is_in_group(&"commander")
		var is_dodge: bool = bool(tgt.get("is_dodging")) if is_cmd else false
		if is_cmd and is_dodge:
			continue

		var is_deploy: bool = bool(tgt.get("is_deploying")) if is_cmd else false
		var kb: float = 0.0
		if is_cmd and not is_deploy:
			kb = stomp_knockback

		var info := DamageInfo.new(effective_stomp_damage, Enums.DamageType.BLAST, self, kb, hit_dir)
		tgt.take_damage(info)

		if is_cmd and not is_dodge and tgt.has_method("apply_stun") and stomp_stun_duration > 0.0:
			tgt.apply_stun(stomp_stun_duration)


func _get_attack_point(t: Node3D) -> Vector3:
	if t != null and is_instance_valid(t) and t.is_in_group(&"fortress"):
		if _cached_boss_melee_point == null or not is_instance_valid(_cached_boss_melee_point):
			_cached_boss_melee_point = get_tree().get_first_node_in_group(&"boss_melee_point") as Node3D
			if _cached_boss_melee_point == null:
				var root := get_tree().current_scene
				if root != null:
					_cached_boss_melee_point = root.find_child("BossMeleePoint", true, false) as Node3D
		if _cached_boss_melee_point != null and is_instance_valid(_cached_boss_melee_point):
			return _cached_boss_melee_point.global_position
		return t.global_position
	return super._get_attack_point(t)


func _get_distance_to_target(target: Node3D, from_pos: Vector3) -> float:
	var col_shape := target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape == null:
		for child in target.get_children():
			if child is CollisionShape3D:
				col_shape = child
				break

	if col_shape != null and col_shape.shape != null:
		if col_shape.shape is BoxShape3D:
			var box := col_shape.shape as BoxShape3D
			var half_extents := box.size * 0.5
			var local_pos := col_shape.global_transform.affine_inverse() * from_pos
			var clamped_local := Vector3(
				clampf(local_pos.x, -half_extents.x, half_extents.x),
				clampf(local_pos.y, -half_extents.y, half_extents.y),
				clampf(local_pos.z, -half_extents.z, half_extents.z)
			)
			var closest_world := col_shape.global_transform * clamped_local
			var diff := closest_world - from_pos
			diff.y = 0.0
			return diff.length()
		elif col_shape.shape is CylinderShape3D:
			var cyl := col_shape.shape as CylinderShape3D
			var local_pos := col_shape.global_transform.affine_inverse() * from_pos
			var local_xz := Vector2(local_pos.x, local_pos.z)
			var clamped_xz := local_xz.limit_length(cyl.radius)
			var clamped_y := clampf(local_pos.y, -cyl.height * 0.5, cyl.height * 0.5)
			var closest_world := col_shape.global_transform * Vector3(clamped_xz.x, clamped_y, clamped_xz.y)
			var diff := closest_world - from_pos
			diff.y = 0.0
			return diff.length()
		elif col_shape.shape is SphereShape3D:
			var sph := col_shape.shape as SphereShape3D
			var diff := col_shape.global_position - from_pos
			diff.y = 0.0
			return maxf(0.0, diff.length() - sph.radius)

	var diff := target.global_position - from_pos
	diff.y = 0.0
	return diff.length()


func can_be_recycled() -> bool:
	return false


func can_be_culled() -> bool:
	return false


func _update_stuck_detection(delta: float) -> void:
	if is_dead or spawn_grace or current_phase == Enums.BossPhase.TRANSITION:
		_stuck_timer = 0.0
		_last_stuck_progress = -INF
		return

	if current_state != Enums.EnemyState.ADVANCE and current_state != Enums.EnemyState.CHASE:
		return

	if current_target == null or not is_instance_valid(current_target):
		return

	if _last_stuck_progress == -INF:
		_last_stuck_progress = nav_progress

	var progress_delta: float = nav_progress - _last_stuck_progress
	if progress_delta >= GameConfig.stuck_progress_min:
		_normal_progress_timer += delta
		_last_stuck_progress = nav_progress
		if _normal_progress_timer >= GameConfig.stuck_reset_time:
			_stuck_timer = 0.0
			_current_stuck_tier = 0
	else:
		_normal_progress_timer = 0.0
		_stuck_timer += delta

	_evaluate_stuck_ladder()


func _evaluate_stuck_ladder() -> void:
	var wave_idx: int = _get_wave_index()
	if _stuck_timer >= GameConfig.boss_stuck_time + GameConfig.boss_stuck_step_time * 2.0:
		if _current_stuck_tier < 3:
			_current_stuck_tier = 3
			EventBus.stuck_event_logged.emit(3, &"bulwark", global_position, wave_idx)
			_resolve_stuck_tier_3()
			_stuck_timer = 0.0
			_current_stuck_tier = 0
			_last_stuck_progress = nav_progress
	elif _stuck_timer >= GameConfig.boss_stuck_time + GameConfig.boss_stuck_step_time:
		if _current_stuck_tier < 2:
			_current_stuck_tier = 2
			EventBus.stuck_event_logged.emit(2, &"bulwark", global_position, wave_idx)
			_resolve_stuck_tier_2()
	elif _stuck_timer >= GameConfig.boss_stuck_time:
		if _current_stuck_tier < 1:
			_current_stuck_tier = 1
			EventBus.stuck_event_logged.emit(1, &"bulwark", global_position, wave_idx)
			_resolve_stuck_tier_1()


func _resolve_stuck_tier_1() -> void:
	if current_target != null and is_instance_valid(current_target):
		nav.target_position = _get_attack_point(current_target)


func _resolve_stuck_tier_2() -> void:
	var obstacle := _find_blocking_structure()
	if obstacle != null:
		current_target = obstacle
		nav.target_position = obstacle.global_position
		if _get_distance_to_target(obstacle, global_position) <= stomp_radius:
			execute_stomp()


func _resolve_stuck_tier_3() -> void:
	var hop_dist: float = GameConfig.boss_hop_radius
	var forward_dir := Vector3.LEFT
	if current_target != null and is_instance_valid(current_target):
		var diff := current_target.global_position - global_position
		diff.y = 0.0
		if diff.length_squared() > 0.01:
			forward_dir = diff.normalized()
	var target_hop_pos := global_position + forward_dir * hop_dist
	var tree := get_tree()
	if tree != null:
		var fortress := tree.get_first_node_in_group(&"fortress") as Node3D
		if fortress != null:
			if forward_dir.x < 0.0 and target_hop_pos.x < fortress.global_position.x:
				target_hop_pos.x = fortress.global_position.x + 1.0
	var map := nav.get_navigation_map()
	if map.is_valid():
		var nav_pt := NavigationServer3D.map_get_closest_point(map, target_hop_pos)
		global_position = nav_pt
	else:
		global_position = target_hop_pos
	if current_target != null and is_instance_valid(current_target):
		nav.target_position = _get_attack_point(current_target)


func _find_blocking_structure() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node3D = null
	var min_dist: float = INF
	var candidates: Array[Node] = []
	candidates.append_array(tree.get_nodes_in_group(&"barricade"))
	candidates.append_array(tree.get_nodes_in_group(&"tower"))
	for cand in candidates:
		var n3d := cand as Node3D
		if n3d == null or not is_instance_valid(n3d):
			continue
		if n3d.is_in_group(&"fortress"):
			continue
		if "slot" in n3d and n3d.slot != null and "zone" in n3d.slot:
			if n3d.slot.zone == Enums.SlotZone.WALL:
				continue
		var diff := n3d.global_position - global_position
		var d := diff.length()
		if d < min_dist:
			min_dist = d
			best = n3d
	return best


func _get_wave_index() -> int:
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var wm := tree.current_scene.find_child("WaveManager", true, false)
		if wm != null and "current_wave" in wm:
			return int(wm.current_wave)
	return spawn_wave if spawn_wave > 0 else 1

