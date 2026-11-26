class_name BossEnemy
extends Enemy
## Shared base of every boss. Holds what the bosses have in common: the armored, transition and
## exposed phases with their resist table, Enrage, the Hazard Trial flag, the utility AI's
## bookkeeping (RNG, push-on and away timers, scores), target picking between the commander and
## structures, turning between moves, the stuck ladder, and the hitbox measuring helpers (sector
## and box tests against the nearest point of a target's collider).
## A concrete boss extends this and overrides the hooks at the bottom: it owns its moves, its
## animation and its brain.

## The scripted waves, read to tell which appearance of its boss a wave is.
const WAVE_SCRIPT_PATH := "res://data/waves/wave_script.tres"

var current_phase: Enums.BossPhase = Enums.BossPhase.ARMORED
var current_armor_hp: int = 1200
var max_armor_hp: int = 1200
var current_core_hp: int = 900
var max_core_hp: int = 900
var phase_broken: bool = false
var is_enraged: bool = false

## Breaks ties between close scores; seeded from the run so a replay makes the same choices.
var _ai_rng: RandomNumberGenerator = null
## Last action the utility AI picked and the scores behind it, for the debug scenes.
var last_decision: StringName = &""
var last_scores: Dictionary = {}
## Seconds the commander has stayed where the boss cannot hit it; pushes the boss on to structures.
var t_away: float = 0.0
## Game seconds left in which the boss ignores the commander after pushing on.
var push_commit_left: float = 0.0
var _pushing: bool = false
## True after the boss left the commander to push on, until it picks a commander move again.
var _left_commander: bool = false
## Seconds the commander has stood in reach without a break.
var _in_reach_time: float = 0.0
var _think_timer: float = 0.0
## Set on the boss copy spawned inside the Hazard Trial room: an easier moveset, no structures to
## push on to, and a faster turn.
var in_hazard_trial: bool = false

var _transition_timer: float = 0.0
var _cached_boss_melee_point: Node3D = null
## How close to boss_melee_point the boss stops before attacking the Fortress.
const BOSS_POINT_ARRIVE_DISTANCE := 0.2
## Within this distance of boss_melee_point the boss walks straight onto it, without avoidance.
const BOSS_POINT_DIRECT_APPROACH := 2.0

var _stuck_timer: float = 0.0
var _last_stuck_progress: float = -INF
var _normal_progress_timer: float = 0.0
var _current_stuck_tier: int = 0


func _ready() -> void:
	super._ready()
	add_to_group(&"boss")
	_init_boss_stats()
	EventBus.boss_enraged.connect(enter_enrage)
	_use_large_navmesh.call_deferred()


## Paths on the navmesh baked for the large agent (BossData.nav_layers), which keeps a wide enough
## way to the gate and to boss_melee_point. A map without that navmesh (a test arena) keeps the
## regular one so the boss can still walk.
func _use_large_navmesh() -> void:
	var boss_data := data as BossData
	if boss_data == null or boss_data.nav_layers == 0 or not is_inside_tree():
		return
	# Regions join the map on its next sync.
	await get_tree().physics_frame
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var map := nav.get_navigation_map()
	for region in NavigationServer3D.map_get_regions(map):
		if NavigationServer3D.region_get_navigation_layers(region) & boss_data.nav_layers:
			nav.navigation_layers = boss_data.nav_layers
			return
	push_warning("BossEnemy: no navmesh on layers %d, the boss walks on the regular one." % boss_data.nav_layers)


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
	if _locks_movement():
		velocity.x = 0.0
		velocity.z = 0.0
	super._physics_process(delta)
	if _locks_movement():
		velocity.x = 0.0
		velocity.z = 0.0
	_update_stuck_detection(delta)


func _turn_toward_target(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	# The target itself, not its attack point: at a structure that point is where the boss stands.
	var look_dir := current_target.global_position - global_position
	look_dir.y = 0.0
	if look_dir.length_squared() > 0.001:
		rotation.y = _turn_limited(rotation.y, atan2(look_dir.x, look_dir.z), delta)


## Phase 2 and Enrage turn the boss faster by the same ratio they shorten its attack interval.
func _turn_limited(from_yaw: float, to_yaw: float, delta: float) -> float:
	var boss_data := data as BossData
	if boss_data == null:
		return to_yaw
	return from_yaw + clampf(angle_difference(from_yaw, to_yaw), -get_turn_rate_rad() * delta, get_turn_rate_rad() * delta)


## Top turning speed between moves, in radians per second.
func get_turn_rate_rad() -> float:
	var boss_data := data as BossData
	if boss_data == null:
		return INF
	var rate := boss_data.ai_turn_rate_deg * _combo_speed()
	if in_hazard_trial:
		rate *= boss_data.hazard_turn_rate_mult
	return deg_to_rad(rate)


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

	var actual_damage := 0
	match current_phase:
		Enums.BossPhase.ARMORED:
			if effective_damage >= current_armor_hp:
				actual_damage = current_armor_hp
				current_armor_hp = 0
				if health != null:
					health.hp = current_core_hp
					health.hp_changed.emit(health.hp, health.max_hp)
					health.damaged.emit(actual_damage, info)
				EventBus.boss_hp_changed.emit(current_armor_hp, current_core_hp, _get_phase_name())
				_start_armor_break_transition()
			else:
				actual_damage = effective_damage
				current_armor_hp -= actual_damage
				if health != null:
					health.hp = current_core_hp + current_armor_hp
					health.hp_changed.emit(health.hp, health.max_hp)
					health.damaged.emit(actual_damage, info)
				EventBus.boss_hp_changed.emit(current_armor_hp, current_core_hp, _get_phase_name())

		Enums.BossPhase.TRANSITION, Enums.BossPhase.EXPOSED:
			actual_damage = mini(current_core_hp, effective_damage)
			current_core_hp = maxi(0, current_core_hp - actual_damage)
			if health != null:
				health.hp = current_core_hp
				health.hp_changed.emit(health.hp, health.max_hp)
				health.damaged.emit(actual_damage, info)
				if current_core_hp == 0:
					health.died.emit()
			EventBus.boss_hp_changed.emit(current_armor_hp, current_core_hp, _get_phase_name())
	_notify_weapon_hit(info, actual_damage)
	return actual_damage


func _start_armor_break_transition() -> void:
	if phase_broken:
		return
	phase_broken = true
	current_phase = Enums.BossPhase.TRANSITION

	stop_attack_sequence()
	attack_windup_timer = 0.0
	attack_recovery_timer = 0.0
	is_attacking_active = false
	if anim_player != null and is_instance_valid(anim_player):
		anim_player.stop()
	if current_state == Enums.EnemyState.ATTACK:
		current_state = Enums.EnemyState.ADVANCE

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
	_play_locomotion_anim()
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
	stop_attack_sequence()
	EventBus.boss_hp_changed.emit(0, 0, _get_phase_name())
	# Announce the boss death first: when the boss is the last unit, enemy_died ends the wave and the summary must already see it.
	# The room boss is not the wave's boss: no prestige, repair charge, weapon or boss count.
	if not in_hazard_trial:
		EventBus.boss_defeated.emit()
	super._on_died()


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


## Leave the commander and push on to the next structure, ignoring it for push_commit_time.
func _push_on() -> void:
	var boss_data := data as BossData
	_pushing = true
	_left_commander = true
	push_commit_left = boss_data.push_commit_time if boss_data != null else 0.0
	provoked_by_player = false
	provoked_timer = 0.0
	var structure := _find_structure_target()
	if structure != null:
		set_target(structure)
		change_state(Enums.EnemyState.CHASE)
	else:
		_find_default_target()
		change_state(Enums.EnemyState.ADVANCE)


func _retarget_commander() -> void:
	var cmd := _get_valid_commander()
	if cmd != null and current_target != cmd:
		set_target(cmd)


## Next structure by target_rules, skipping the commander rule.
func _find_structure_target() -> Node3D:
	if data == null:
		return _get_valid_fortress()
	for rule in data.target_rules:
		var found: Node3D = null
		match rule:
			&"BARRICADE":
				found = _find_closest_valid_barricade()
			&"TOWER":
				found = _find_closest_valid_tower_any()
			&"TOWER_GROUND":
				found = _find_closest_valid_tower(false)
			&"FORTRESS":
				found = _get_valid_fortress()
		if found != null:
			return found
	return _get_valid_fortress()


func _is_commander(target: Node3D) -> bool:
	return target != null and is_instance_valid(target) and target.is_in_group(&"commander")


## The boss minds the commander when it is close, or hit the boss recently and is within the
## leash. Inside the Hazard Trial room the commander is the only target, so always.
func _is_engaged(cmd: Node3D) -> bool:
	if cmd == null:
		return false
	if in_hazard_trial:
		return true
	var offset := cmd.global_position - global_position
	offset.y = 0.0
	var dist := offset.length()
	if dist <= _engage_range():
		return true
	# Bosses ignore Battle Cry, so a taunt only comes from scripted fights (the AI test arena).
	if taunted_by_player and dist <= GameConfig.leash_distance:
		return true
	return provoked_by_player and dist <= _engage_leash()


## Distance within which the boss minds the commander on its own; a boss may size it to its body.
func _engage_range() -> float:
	return data.aggro_range if data != null else 4.0


## Distance within which the boss keeps minding a commander that hit it recently.
func _engage_leash() -> float:
	var boss_data := data as BossData
	return boss_data.commander_leash if boss_data != null else 0.0


## Counts while the commander keeps out of reach. It starts only once the boss minds the commander
## (or has already left it to push on), and resets as soon as the commander stands in reach.
## Only standing in reach for reach_reset_time resets it: circling past the front cone just
## pauses the count. Landing a hit on the commander also resets it (see _on_commander_hit).
func _update_t_away(delta: float) -> void:
	var cmd := _get_valid_commander()
	if cmd == null or (not _left_commander and not _is_engaged(cmd)):
		t_away = 0.0
		_in_reach_time = 0.0
		return
	if _commander_in_reach(cmd):
		_in_reach_time += delta
		var boss_data := data as BossData
		if boss_data == null or _in_reach_time >= boss_data.reach_reset_time:
			t_away = 0.0
	else:
		_in_reach_time = 0.0
		t_away += delta


## A hit that lands on the commander means the fight is on: the commander is not out of reach.
func _on_commander_hit() -> void:
	t_away = 0.0


## Which appearance of this boss this is: 1 on its first boss wave, 2 on its next, and so on.
## Bosses alternate in the scripted waves, so each boss counts only its own waves; without a
## wave script (or when it never names this boss) every boss wave counts as one appearance.
func get_appearance() -> int:
	var interval := maxi(1, GameConfig.boss_wave_interval)
	var boss_data := data as BossData
	var script := load(WAVE_SCRIPT_PATH) as WaveScript
	if boss_data != null and script != null:
		var scripted := script.get_boss_appearance(boss_data.id, spawn_wave, interval)
		if scripted > 0:
			return scripted
	return maxi(1, spawn_wave / interval)


## The appearance whose moves the boss fights with; the Hazard Trial copy steps back.
func get_moveset_appearance() -> int:
	var boss_data := data as BossData
	var appearance := get_appearance()
	if in_hazard_trial and boss_data != null:
		appearance -= boss_data.hazard_appearance_offset
	return maxi(1, appearance)


## True when the target sits inside the front cone (ai_front_arc_deg) of the boss's facing.
func is_in_front(target: Node3D) -> bool:
	var boss_data := data as BossData
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		return true
	return rad_to_deg(_combo_forward().angle_to(offset)) <= boss_data.ai_front_arc_deg * 0.5


## Armor and core together, 1.0 at full health.
func get_hp_fraction() -> float:
	var total_max := max_armor_hp + max_core_hp
	if total_max <= 0:
		return 0.0
	return float(current_armor_hp + current_core_hp) / float(total_max)


func _ai_roll() -> float:
	if _ai_rng == null:
		_ai_rng = RandomNumberGenerator.new()
		var run_seed := 0
		var run_state := get_tree().get_first_node_in_group(&"run_state") if is_inside_tree() else null
		if run_state != null and "run_seed" in run_state:
			run_seed = int(run_state.run_seed)
		_ai_rng.seed = hash([run_seed, "boss_ai", spawn_wave])
	return _ai_rng.randf()


func set_ai_seed(seed_value: int) -> void:
	_ai_rng = RandomNumberGenerator.new()
	_ai_rng.seed = seed_value


## Creates a timer on game time that pauses when the game is paused and scales with game speed.
func _game_timer(duration: float) -> SceneTreeTimer:
	return get_tree().create_timer(duration, false, false, false)


## Phase 2 and Enrage speed the whole combo up by the same ratio they speed up the stomp.
func _combo_speed() -> float:
	var boss_data := data as BossData
	if boss_data == null:
		return 1.0
	return maxf(1.0, boss_data.attack_interval / maxf(0.1, _get_attack_interval()))


## Everything a sword swing can hurt: the commander in Frontline and structures on the ground.
## Wall towers are out of reach, as for every ground melee attacker.
func _collect_combo_targets() -> Array[Node3D]:
	var out: Array[Node3D] = []
	var tree := get_tree()
	if tree == null:
		return out
	var candidates: Array[Node] = []
	var cmd := tree.get_first_node_in_group(&"commander")
	if cmd != null:
		candidates.append(cmd)
	for grp: StringName in [&"tower", &"barricade", &"fortress"]:
		candidates.append_array(tree.get_nodes_in_group(grp))
	for node in candidates:
		var n3d := node as Node3D
		if n3d == null or out.has(n3d) or not n3d.has_method(&"take_damage"):
			continue
		if _is_target_valid(n3d):
			out.append(n3d)
	return out


func _combo_forward() -> Vector3:
	var fwd := global_transform.basis.z
	fwd.y = 0.0
	return fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.LEFT


## Sector in front of the boss, measured to the nearest point of the target's body.
func _in_slash_hitbox(target: Node3D, reach: float, arc_deg: float) -> bool:
	var offset := _closest_point_on_target(target, global_position) - global_position
	offset.y = 0.0
	var dist := offset.length() - _target_body_radius(target)
	if dist > reach:
		return false
	if offset.length() < 0.3:
		return true
	return rad_to_deg(_combo_forward().angle_to(offset)) <= arc_deg * 0.5


## Narrow box straight ahead of the boss.
func _in_stab_hitbox(target: Node3D, reach: float, width: float) -> bool:
	var offset := _closest_point_on_target(target, global_position) - global_position
	offset.y = 0.0
	var fwd := _combo_forward()
	var right := Vector3.UP.cross(fwd)
	var pad := _target_body_radius(target)
	var along := offset.dot(fwd)
	var lateral := absf(offset.dot(right))
	return along >= -pad and along <= reach + pad and lateral <= width * 0.5 + pad


## Commander capsules have no closest-point helper; count their radius as reach instead.
func _target_body_radius(target: Node3D) -> float:
	var col := _find_collision_shape(target)
	if col != null and col.shape is CapsuleShape3D:
		return (col.shape as CapsuleShape3D).radius
	return 0.0


func _scale_attack_damage(base_damage: int) -> int:
	if wave_dmg_mult <= 0.0 and not is_enraged:
		return base_damage
	var dmg: float = float(base_damage)
	if wave_dmg_mult > 0.0:
		dmg *= wave_dmg_mult
	if is_enraged:
		dmg *= GameConfig.enrage_damage_mult
	return maxi(1, int(round(dmg)))


## On its way to the Fortress the boss walks right onto boss_melee_point before it attacks, so
## its Stomp lands on the wall; other targets keep attack_range.
func _arrive_distance(t: Node3D) -> float:
	var arrive: float = super._arrive_distance(t)
	if t != null and is_instance_valid(t) and t.is_in_group(&"fortress") and _get_boss_melee_point() != null:
		arrive = BOSS_POINT_ARRIVE_DISTANCE
	return arrive


## The navigation agent stops where the boss attacks, so it walks onto boss_melee_point.
func _set_nav_arrive_distance(arrive: float) -> void:
	nav.target_desired_distance = arrive


## The last metres onto boss_melee_point are walked straight: avoidance would keep the large
## agent off a point that sits by design right at the edge of its navmesh.
func _steers_without_avoidance() -> bool:
	if current_target == null or not is_instance_valid(current_target) or not current_target.is_in_group(&"fortress"):
		return false
	var point := _get_boss_melee_point()
	if point == null:
		return false
	var gap := point.global_position - global_position
	gap.y = 0.0
	return gap.length() <= BOSS_POINT_DIRECT_APPROACH


func _get_boss_melee_point() -> Node3D:
	if _cached_boss_melee_point == null or not is_instance_valid(_cached_boss_melee_point):
		_cached_boss_melee_point = get_tree().get_first_node_in_group(&"boss_melee_point") as Node3D
		if _cached_boss_melee_point == null:
			var root := get_tree().current_scene
			if root != null:
				_cached_boss_melee_point = root.find_child("BossMeleePoint", true, false) as Node3D
	return _cached_boss_melee_point if is_instance_valid(_cached_boss_melee_point) else null


func _get_attack_point(t: Node3D) -> Vector3:
	if t != null and is_instance_valid(t) and t.is_in_group(&"fortress"):
		var point := _get_boss_melee_point()
		return point.global_position if point != null else t.global_position
	return super._get_attack_point(t)


func can_be_recycled() -> bool:
	return false


func can_be_culled() -> bool:
	return false


func _update_stuck_detection(delta: float) -> void:
	# Progress is measured along the lane, so chasing the commander off the lane is not being stuck.
	if is_dead or spawn_grace or current_phase == Enums.BossPhase.TRANSITION or is_in_attack_state() \
			or _is_commander(current_target):
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
			EventBus.stuck_event_logged.emit(3, _boss_id(), global_position, wave_idx)
			_resolve_stuck_tier_3()
			_stuck_timer = 0.0
			_current_stuck_tier = 0
			_last_stuck_progress = nav_progress
	elif _stuck_timer >= GameConfig.boss_stuck_time + GameConfig.boss_stuck_step_time:
		if _current_stuck_tier < 2:
			_current_stuck_tier = 2
			EventBus.stuck_event_logged.emit(2, _boss_id(), global_position, wave_idx)
			_resolve_stuck_tier_2()
	elif _stuck_timer >= GameConfig.boss_stuck_time:
		if _current_stuck_tier < 1:
			_current_stuck_tier = 1
			EventBus.stuck_event_logged.emit(1, _boss_id(), global_position, wave_idx)
			_resolve_stuck_tier_1()


func _resolve_stuck_tier_1() -> void:
	if current_target != null and is_instance_valid(current_target):
		nav.target_position = _get_attack_point(current_target)


func _resolve_stuck_tier_2() -> void:
	var obstacle := _find_blocking_structure()
	if obstacle != null:
		current_target = obstacle
		nav.target_position = obstacle.global_position
		_break_blocking_structure(obstacle)


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
		global_position = _closest_point_on_own_layers(map, target_hop_pos)
	else:
		global_position = target_hop_pos
	if current_target != null and is_instance_valid(current_target):
		nav.target_position = _get_attack_point(current_target)


## Closest navmesh point to pos on the regions of the boss's navigation_layers only, so a hop never
## lands on the regular navmesh, too narrow for the large agent (BOSS-03). With no such region (a
## map without the large navmesh) the closest point of the whole map.
func _closest_point_on_own_layers(map: RID, pos: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_dist := INF
	for region in NavigationServer3D.map_get_regions(map):
		if not NavigationServer3D.region_get_enabled(region):
			continue
		if not (NavigationServer3D.region_get_navigation_layers(region) & nav.navigation_layers):
			continue
		var pt := NavigationServer3D.region_get_closest_point(region, pos)
		var d := pt.distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best = pt
	if best_dist == INF:
		return NavigationServer3D.map_get_closest_point(map, pos)
	return best


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


## Ends any running attack or attack sequence and returns the boss to its idle pose.
func stop_attack_sequence() -> void:
	pass


## True while the boss is committed to a move (locked from moving and turning).
func is_in_attack_state() -> bool:
	return current_state == Enums.EnemyState.ATTACK


## True when the boss must not walk: the physics step then zeroes its horizontal velocity.
## A boss whose move is itself movement (a charge, an advance) returns false while it moves.
func _locks_movement() -> bool:
	return is_in_attack_state()


## True when the commander stands where the boss's moves can hit it; keeps t_away at zero.
@warning_ignore("unused_parameter")
func _commander_in_reach(cmd: Node3D) -> bool:
	return false


## Called by the stuck ladder when a structure blocks the way and is now the target.
@warning_ignore("unused_parameter")
func _break_blocking_structure(obstacle: Node3D) -> void:
	pass


## Enemy type reported by the stuck ladder.
func _boss_id() -> StringName:
	return data.id if data != null else &""
