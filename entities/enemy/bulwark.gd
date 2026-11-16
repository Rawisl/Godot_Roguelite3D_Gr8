class_name Bulwark
extends Enemy

const WALK_ANIM_BASE_SPEED: float = 1.42

var stomp_damage: int:
	get:
		var boss_data := data as BossData
		return boss_data.stomp_damage if boss_data != null else 45

var effective_stomp_damage: int:
	get:
		return _scale_attack_damage(stomp_damage)

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

signal attack_step_started(attack_id: int, step_name: StringName, clip: StringName, duration: float)
signal attack_sequence_finished(attack_id: int)
## A hitbox of an attack step resolved; targets holds every node it damaged (empty on a whiff).
signal attack_hit(attack_id: int, step_name: StringName, targets: Array)

const COMBO_SLAM_ID: int = 6
const TRIPLE_STOMP_ID: int = 7
const NORMAL_ATTACK_ID: int = 11

## Turning more than this between moves, the boss walks slowly while it turns.
const TURN_WALK_MIN_DEG: float = 15.0
## Walking speed while turning between moves, as a share of its move speed.
const TURN_WALK_SPEED_MULT: float = 0.35
## How often a boss that is turning to face the commander checks again whether it can attack.
const TURN_RECHECK_TIME: float = 0.1
## Moves the commander AI can pick (choose_attack).
const MOVE_STOMP: StringName = &"stomp"
const MOVE_NORMAL: StringName = &"normal"
const MOVE_COMBO: StringName = &"combo"
const MOVE_TRIPLE: StringName = &"triple"
## Used only when the model has no slam clip (tests without the animation library).
const SLAM_CLIP_FALLBACK_LENGTH: float = 2.83
const CLIP_SLASH_1H: StringName = &"melee/Melee_1H_Slash"
const CLIP_STAB_1H: StringName = &"melee/Melee_1H_Stab"
const CLIP_SLAM_2H: StringName = &"melee/Melee_2H_Slam"
const CLIP_IDLE: StringName = &"general/Idle_A"
## Clip second of the slam where the mace is back in the guard pose: the single stomp blends to
## Idle from here, so the next stomp always starts the clip from its wind-up.
const STOMP_CLIP_RECOVERED: float = 2.37
const STOMP_RECOVER_BLEND: float = 0.15
## Clip second of the slam where the mace hits the ground.
const STOMP_CLIP_IMPACT: float = 0.97

enum ComboStep { NONE = -1, SLASH = 0, STAB = 1, SLAM = 2 }

var is_in_attack_sequence: bool = false
var current_attack_id: int = 0
var _attack_token: int = 0

## Slash-based sequences (normal attack = slash only, combo = slash -> stab -> slam), ticked on
## game time in _process.
var combo_step: ComboStep = ComboStep.NONE
var _combo_last_step: ComboStep = ComboStep.SLAM
var _combo_attack_id: int = COMBO_SLAM_ID
var _combo_step_time: float = 0.0
var _combo_hit_done: bool = false
var _combo_from_ai: bool = false

## Where the stomp being wound up will land, fixed when its telegraph appears so the ring and
## the hit always match. Vector3.INF when no stomp is pending.
var _locked_stomp_center: Vector3 = Vector3.INF
## Walking slowly while turning between moves (see _update_turn_walk).
var _turn_walking: bool = false
## Facing at the start of an ATTACK-state update; NAN outside of it.
var _yaw_during_attack_update: float = NAN
## True from a single stomp's impact until its clip reaches STOMP_CLIP_RECOVERED.
var _stomp_recovering: bool = false
var _model_height: float = -1.0

## Triple stomp chain, ticked on game time in _process. -1 when not running.
var _triple_index: int = -1
var _triple_time: float = 0.0
var _triple_hit_done: bool = false
var _triple_from_ai: bool = false
var triple_stomp_cooldown_left: float = 0.0
## Game seconds until the boss may stomp a commander that keeps out of its slash reach.
var commander_stomp_cooldown_left: float = 0.0

## Rolls the combo chance; seeded from the run so a replay makes the same choices.
var _ai_rng: RandomNumberGenerator = null
var last_chosen_move: StringName = &""
## Set on the boss copy spawned inside the Hazard Trial room; it then uses an easier moveset.
# TODO(Ender-Via): set in_hazard_trial = true on the boss the Hazard Trial spawns into the room.
var in_hazard_trial: bool = false

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
	get_model_height()  # measure in the spawn pose, before any swing lifts the arms
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
	if is_in_attack_state():
		velocity.x = 0.0
		velocity.z = 0.0
	super._physics_process(delta)
	if is_in_attack_state():
		velocity.x = 0.0
		velocity.z = 0.0
	_update_stuck_detection(delta)


# The combo runs here rather than in _physics_process so it also plays when a showcase scene
# turns physics off. Delta is game time: scaled by the speed buttons and frozen by Pause.
func _process(delta: float) -> void:
	if triple_stomp_cooldown_left > 0.0:
		triple_stomp_cooldown_left = maxf(0.0, triple_stomp_cooldown_left - delta)
	if commander_stomp_cooldown_left > 0.0:
		commander_stomp_cooldown_left = maxf(0.0, commander_stomp_cooldown_left - delta)
	if combo_step != ComboStep.NONE:
		_tick_combo(delta)
	if _triple_index >= 0:
		_tick_triple_stomp(delta)
	if _stomp_recovering:
		_tick_stomp_recovery()


## Ends the single stomp's clip once the mace is back up. Without this the clip runs on past the
## next stomp's start, and play() on a clip that is still playing does not restart it.
func _tick_stomp_recovery() -> void:
	if anim_player == null or anim_player.current_animation != CLIP_SLAM_2H:
		_stomp_recovering = false
		return
	if anim_player.current_animation_position >= STOMP_CLIP_RECOVERED:
		_stomp_recovering = false
		anim_player.speed_scale = 1.0
		if anim_player.has_animation(CLIP_IDLE):
			anim_player.play(CLIP_IDLE, STOMP_RECOVER_BLEND)


## Returns true when the boss is executing an attack or attack sequence (locked from moving or turning).
func is_in_attack_state() -> bool:
	return current_state == Enums.EnemyState.ATTACK or is_in_attack_sequence or combo_step != ComboStep.NONE or _triple_index >= 0


func _update_state(delta: float) -> void:
	if is_in_attack_state():
		# Committed to attack / attack sequence: stand still and lock rotation completely.
		velocity.x = 0.0
		velocity.z = 0.0
		if combo_step != ComboStep.NONE or _triple_index >= 0:
			if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
				stop_attack_sequence()
				_retarget_now()
			return
		var yaw_before := rotation.y
		# Enemy's ATTACK state eases toward the target before it starts the next move; the move
		# must be chosen and aimed with the real (locked) facing, see _play_attack_anim.
		_yaw_during_attack_update = yaw_before
		super._update_state(delta)
		_yaw_during_attack_update = NAN
		# Facing is locked from the wind-up to the hit. In the pause after a hit the boss turns
		# toward its target at ai_turn_rate_deg, so it never freezes with the commander behind it.
		rotation.y = yaw_before
		velocity.x = 0.0
		velocity.z = 0.0
		if _is_recovering_between_moves():
			_turn_toward_target(delta)
			_update_turn_walk()
		else:
			_turn_walking = false
		return

	_turn_walking = false
	# Chasing a commander that keeps just out of reach: stomp it once it stands in the ring.
	if current_state == Enums.EnemyState.CHASE and _can_stomp_commander_from_range():
		change_state(Enums.EnemyState.ATTACK)
		return
	super._update_state(delta)


## The pause between two moves of the ATTACK state: the last hit has landed and no sequence runs.
func _is_recovering_between_moves() -> bool:
	return (current_state == Enums.EnemyState.ATTACK and is_attacking_active
			and not is_in_attack_sequence and combo_step == ComboStep.NONE and _triple_index < 0)


func _turn_toward_target(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		return
	var look_dir := _get_attack_point(current_target) - global_position
	look_dir.y = 0.0
	if look_dir.length_squared() > 0.001:
		rotation.y = _turn_limited(rotation.y, atan2(look_dir.x, look_dir.z), delta)


## While turning a wide angle between moves the boss walks slowly along its facing instead of
## spinning on the spot. Only once the last move's clip is over (Idle), so no swing is cut short.
func _update_turn_walk() -> void:
	var walk := false
	if current_target != null and is_instance_valid(current_target) and anim_player != null:
		var look_dir := _get_attack_point(current_target) - global_position
		look_dir.y = 0.0
		var anim_free := anim_player.current_animation == CLIP_IDLE or anim_player.current_animation == _walk_clip() 				or not anim_player.is_playing()
		walk = anim_free and look_dir.length_squared() > 0.001 				and absf(rad_to_deg(angle_difference(rotation.y, atan2(look_dir.x, look_dir.z)))) > TURN_WALK_MIN_DEG
	if not walk:
		if _turn_walking:
			_turn_walking = false
			if anim_player != null and anim_player.has_animation(CLIP_IDLE):
				anim_player.speed_scale = 1.0
				anim_player.play(CLIP_IDLE, 0.25)
		return
	var base_speed: float = data.move_speed if data != null else 1.6
	var speed := base_speed * speed_multiplier * get_slow_factor() * TURN_WALK_SPEED_MULT
	var fwd := _combo_forward()
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if not _turn_walking:
		_turn_walking = true
		var clip := _walk_clip()
		if anim_player.has_animation(clip):
			anim_player.play(clip, 0.25)
	anim_player.speed_scale = speed / WALK_ANIM_BASE_SPEED


func _walk_clip() -> StringName:
	return data.anim_walk if (data != null and not data.anim_walk.is_empty()) else &"move/Walking_A"


func _turn_limited(from_yaw: float, to_yaw: float, delta: float) -> float:
	var boss_data := data as BossData
	if boss_data == null:
		return to_yaw
	var max_step := deg_to_rad(boss_data.ai_turn_rate_deg) * delta
	return from_yaw + clampf(angle_difference(from_yaw, to_yaw), -max_step, max_step)


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
	EventBus.boss_defeated.emit()
	super._on_died()


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


## Called by the ATTACK state at the start of every swing: this is where the boss picks its move.
func _play_attack_anim() -> void:
	if not is_nan(_yaw_during_attack_update):
		rotation.y = _yaw_during_attack_update
	if _must_turn_before_attacking():
		# Keep pausing (and turning, see _update_state) a moment longer, then check again.
		is_attacking_active = true
		attack_windup_timer = 0.0
		attack_recovery_timer = TURN_RECHECK_TIME
		return
	_turn_walking = false
	last_chosen_move = choose_attack()
	match last_chosen_move:
		MOVE_TRIPLE:
			play_triple_stomp(true)
		MOVE_COMBO:
			_begin_slash_sequence(COMBO_SLAM_ID, ComboStep.SLAM, true)
		MOVE_NORMAL:
			_begin_slash_sequence(NORMAL_ATTACK_ID, ComboStep.SLASH, true)
		_:
			if current_target != null and is_instance_valid(current_target) and current_target.is_in_group(&"commander"):
				var boss_data := data as BossData
				commander_stomp_cooldown_left = boss_data.commander_stomp_cooldown if boss_data != null else 0.0
			attack_step_started.emit(1, &"STOMP_WINDUP", CLIP_SLAM_2H, _get_attack_windup())
			_play_stomp_anim()


## The commander is at the flank or behind and the only move left would swing at empty air
## (the normal attack while the triple stomp cools down, or the stomp before the triple stomp
## unlocks: its ring lands in front). The boss turns to face it first.
func _must_turn_before_attacking() -> bool:
	var boss_data := data as BossData
	if boss_data == null or current_target == null or not is_instance_valid(current_target):
		return false
	if not current_target.is_in_group(&"commander") or is_in_front(current_target):
		return false
	return choose_attack() != MOVE_TRIPLE


## The commander is in front, out of the slash's reach but inside the ring the stomp would
## land on right now, and the stomp against the commander is off cooldown.
func _can_stomp_commander_from_range() -> bool:
	var boss_data := data as BossData
	if boss_data == null or commander_stomp_cooldown_left > 0.0 or is_dead or spawn_grace:
		return false
	if current_target == null or not is_instance_valid(current_target) or not current_target.is_in_group(&"commander"):
		return false
	if not _is_target_valid(current_target) or not is_in_front(current_target):
		return false
	if _in_slash_hitbox(current_target, boss_data.combo_slash_range, boss_data.combo_slash_arc_deg):
		return false
	return _get_distance_to_target(current_target, get_stomp_center()) <= stomp_radius


## Picks the next move against the current target.
## - Not the commander (tower, Barricade, Fortress): the stomp.
## - Commander at the flank or behind: triple stomp; while it cools down, the normal attack (the
##   boss turns to face it first, see _must_turn_before_attacking).
## - Commander in front, out of slash reach but inside the stomp ring: the stomp (commander_stomp_cooldown).
## - Commander in front: the normal attack, or below combo_hp_threshold a combo_chance roll for the combo.
func choose_attack() -> StringName:
	var boss_data := data as BossData
	if boss_data == null or current_target == null or not is_instance_valid(current_target):
		return MOVE_STOMP
	if not current_target.is_in_group(&"commander"):
		return MOVE_STOMP
	var appearance := get_moveset_appearance()
	if not is_in_front(current_target):
		if appearance < boss_data.triple_stomp_unlock_appearance:
			return MOVE_STOMP
		return MOVE_TRIPLE if triple_stomp_cooldown_left <= 0.0 else MOVE_NORMAL
	if _can_stomp_commander_from_range():
		return MOVE_STOMP
	if appearance < boss_data.combo_unlock_appearance:
		return MOVE_NORMAL
	if get_hp_fraction() < boss_data.combo_hp_threshold and _ai_roll() < boss_data.combo_chance:
		return MOVE_COMBO
	return MOVE_NORMAL


## Which appearance of the boss this is: 1 on its first boss wave, 2 on the next, and so on.
func get_appearance() -> int:
	return maxi(1, spawn_wave / maxi(1, GameConfig.boss_wave_interval))


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


## Back to the ATTACK state after an AI sequence, as if a swing just landed: wait out the
## recovery, then it checks range again and picks the next move.
func _hand_back_to_attack_state(speed: float, heavy: bool) -> void:
	if current_state != Enums.EnemyState.ATTACK:
		return
	var boss_data := data as BossData
	var recovery := boss_data.heavy_attack_recovery if heavy else boss_data.attack_recovery
	is_attacking_active = true
	attack_windup_timer = 0.0
	attack_recovery_timer = recovery / maxf(0.05, speed)


func _play_stomp_anim() -> void:
	_locked_stomp_center = get_stomp_center()
	_stomp_recovering = false
	EventBus.telegraph_started.emit(&"stomp", _locked_stomp_center, stomp_radius, _get_attack_windup())
	if anim_player != null and anim_player.has_animation(CLIP_SLAM_2H):
		anim_player.speed_scale = 1.0
		anim_player.play(CLIP_SLAM_2H, 0.05, 1.0)
		# play() keeps going when the clip is already playing; rewind so every stomp has its wind-up.
		anim_player.seek(0.0, true)


func _execute_attack_action() -> void:
	var center := _locked_stomp_center
	_locked_stomp_center = Vector3.INF
	attack_hit.emit(1, &"STOMP_SLAM", execute_stomp(-1.0, -1.0, 1.0, center))
	if anim_player == null or anim_player.current_animation != CLIP_SLAM_2H:
		return
	_stomp_recovering = true
	# Phase 2 and Enrage shorten the interval: speed the mace's return up so it is back in guard,
	# and blended to Idle, before the next stomp starts.
	var recovery_time: float = _get_attack_interval() - _get_attack_windup() - STOMP_RECOVER_BLEND
	var recovery_speed: float = (STOMP_CLIP_RECOVERED - STOMP_CLIP_IMPACT) / maxf(0.1, recovery_time)
	anim_player.speed_scale = maxf(1.0, recovery_speed)


## Creates a timer on game time that pauses when the game is paused and scales with game speed.
func _game_timer(duration: float) -> SceneTreeTimer:
	return get_tree().create_timer(duration, false, false, false)


## Executes Attack 1 (Stomp): windup telegraph, slam impact, and recovery.
func play_attack_1() -> void:
	if is_dead or anim_player == null:
		return
	stop_attack_sequence()  # also ends any running tick-driven sequence
	var token := _attack_token
	is_in_attack_sequence = true
	current_attack_id = 1

	attack_step_started.emit(1, &"STOMP_WINDUP", &"melee/Melee_2H_Slam", _get_attack_windup())
	_play_stomp_anim()

	await _game_timer(_get_attack_windup()).timeout
	if token != _attack_token or is_dead:
		return

	attack_step_started.emit(1, &"STOMP_SLAM", &"melee/Melee_2H_Slam", 2.83 - _get_attack_windup())
	_execute_attack_action()

	var remaining: float = maxf(0.1, 2.83 - _get_attack_windup())
	if anim_player != null and anim_player.speed_scale > 0.0:
		remaining /= anim_player.speed_scale
	await _game_timer(remaining).timeout
	if token != _attack_token or is_dead:
		return

	is_in_attack_sequence = false
	current_attack_id = 0
	attack_sequence_finished.emit(1)
	if anim_player != null and anim_player.has_animation(&"general/Idle_A"):
		anim_player.play(&"general/Idle_A", 0.2)


## Executes Attack 2: Triple strike combo preceded by a brief blocking posture.
## 1. Guard posture: Melee_Block (0.45s)
## 2. Strike 1: Melee_1H_Slash (1.57s)
## 3. Strike 2: Melee_1H_Stab (1.40s)
## 4. Strike 3: Melee_2H_Attack (1.33s)
func play_attack_2() -> void:
	if is_dead or anim_player == null:
		return
	stop_attack_sequence()  # also ends any running tick-driven sequence
	var token := _attack_token
	is_in_attack_sequence = true
	current_attack_id = 2

	# Step 1: Pre-attack blocking posture
	attack_step_started.emit(2, &"BLOCK_POSE", &"melee/Melee_Block", 0.45)
	anim_player.speed_scale = 1.0
	anim_player.play(&"melee/Melee_Block", 0.15)
	await _game_timer(0.45).timeout
	if token != _attack_token or is_dead:
		return

	# Step 2: Strike 1 - 1H Slash
	attack_step_started.emit(2, &"SLASH", &"melee/Melee_1H_Slash", 1.57)
	anim_player.play(&"melee/Melee_1H_Slash", 0.1)
	await _game_timer(1.57).timeout
	if token != _attack_token or is_dead:
		return

	# Step 3: Strike 2 - 1H Stab
	attack_step_started.emit(2, &"STAB", &"melee/Melee_1H_Stab", 1.40)
	anim_player.play(&"melee/Melee_1H_Stab", 0.1)
	await _game_timer(1.40).timeout
	if token != _attack_token or is_dead:
		return

	# Step 4: Strike 3 - 2H Attack
	attack_step_started.emit(2, &"2H_ATTACK", &"melee/Melee_2H_Attack", 1.33)
	anim_player.play(&"melee/Melee_2H_Attack", 0.12)
	await _game_timer(1.33).timeout
	if token != _attack_token or is_dead:
		return

	is_in_attack_sequence = false
	current_attack_id = 0
	attack_sequence_finished.emit(2)
	if anim_player != null and anim_player.has_animation(&"general/Idle_A"):
		anim_player.play(&"general/Idle_A", 0.2)


## Executes Attack 3: Two-handed slash combo (Two consecutive heavy 2H swings).
## 1. Strike 1: Melee_2H_Attack (1.33s)
## 2. Strike 2: Melee_2H_Attack (1.33s)
func play_attack_3() -> void:
	if is_dead or anim_player == null:
		return
	stop_attack_sequence()  # also ends any running tick-driven sequence
	var token := _attack_token
	is_in_attack_sequence = true
	current_attack_id = 3

	# Step 1: 2H Slash 1
	attack_step_started.emit(3, &"2H_SLASH_1", &"melee/Melee_2H_Attack", 1.33)
	anim_player.speed_scale = 1.0
	anim_player.play(&"melee/Melee_2H_Attack", 0.1)
	await _game_timer(1.33).timeout
	if token != _attack_token or is_dead:
		return

	# Step 2: 2H Slash 2
	attack_step_started.emit(3, &"2H_SLASH_2", &"melee/Melee_2H_Attack", 1.33)
	anim_player.play(&"melee/Melee_2H_Attack", 0.1)
	await _game_timer(1.33).timeout
	if token != _attack_token or is_dead:
		return

	is_in_attack_sequence = false
	current_attack_id = 0
	attack_sequence_finished.emit(3)
	if anim_player != null and anim_player.has_animation(&"general/Idle_A"):
		anim_player.play(&"general/Idle_A", 0.2)


## Executes Attack 4: Dual-wield slash sequence (Dual slash followed by dual slash combo).
## 1. Strike 1: Melee_Dualwield_Slash (1.03s)
## 2. Strike 2: Melee_Dualwield_SlashCombo (1.60s)
func play_attack_4() -> void:
	if is_dead or anim_player == null:
		return
	stop_attack_sequence()  # also ends any running tick-driven sequence
	var token := _attack_token
	is_in_attack_sequence = true
	current_attack_id = 4

	# Step 1: Dualwield cross slash
	attack_step_started.emit(4, &"DUAL_SLASH", &"melee/Melee_Dualwield_Slash", 1.03)
	anim_player.speed_scale = 1.0
	anim_player.play(&"melee/Melee_Dualwield_Slash", 0.1)
	await _game_timer(1.03).timeout
	if token != _attack_token or is_dead:
		return

	# Step 2: Dualwield slash combo
	attack_step_started.emit(4, &"DUAL_COMBO", &"melee/Melee_Dualwield_SlashCombo", 1.60)
	anim_player.play(&"melee/Melee_Dualwield_SlashCombo", 0.1)
	await _game_timer(1.60).timeout
	if token != _attack_token or is_dead:
		return

	is_in_attack_sequence = false
	current_attack_id = 0
	attack_sequence_finished.emit(4)
	if anim_player != null and anim_player.has_animation(&"general/Idle_A"):
		anim_player.play(&"general/Idle_A", 0.2)


## Executes Attack 5: 1H Slash followed by reverse combo strike.
## 1. Strike 1: Melee_1H_Slash (1.57s)
## 2. Strike 2: Melee_Dualwield_SlashCombo (1.60s)
func play_attack_5() -> void:
	if is_dead or anim_player == null:
		return
	stop_attack_sequence()  # also ends any running tick-driven sequence
	var token := _attack_token
	is_in_attack_sequence = true
	current_attack_id = 5

	# Step 1: 1H Forward Slash
	attack_step_started.emit(5, &"SLASH_1H", &"melee/Melee_1H_Slash", 1.57)
	anim_player.speed_scale = 1.0
	anim_player.play(&"melee/Melee_1H_Slash", 0.1)
	await _game_timer(1.57).timeout
	if token != _attack_token or is_dead:
		return

	# Step 2: Reverse / Off-hand Combo Strike
	attack_step_started.emit(5, &"REVERSE_COMBO", &"melee/Melee_Dualwield_SlashCombo", 1.60)
	anim_player.play(&"melee/Melee_Dualwield_SlashCombo", 0.1)
	await _game_timer(1.60).timeout
	if token != _attack_token or is_dead:
		return

	is_in_attack_sequence = false
	current_attack_id = 0
	attack_sequence_finished.emit(5)
	if anim_player != null and anim_player.has_animation(&"general/Idle_A"):
		anim_player.play(&"general/Idle_A", 0.2)


## Plays the slash -> stab -> slam combo on demand (showcase scenes). In a fight choose_attack()
## decides when it is used.
func play_attack_combo_slam() -> void:
	_begin_slash_sequence(COMBO_SLAM_ID, ComboStep.SLAM, false)


## Plays the one-handed normal attack on demand, with its hitbox.
func play_normal_attack() -> void:
	_begin_slash_sequence(NORMAL_ATTACK_ID, ComboStep.SLASH, false)


## Runs the slash steps from SLASH up to last_step under attack_id.
func _begin_slash_sequence(attack_id: int, last_step: ComboStep, from_ai: bool) -> void:
	if is_dead or not (data is BossData):
		return
	stop_attack_sequence()
	is_in_attack_sequence = true
	current_attack_id = attack_id
	_combo_attack_id = attack_id
	_combo_last_step = last_step
	_combo_from_ai = from_ai
	_enter_combo_step(ComboStep.SLASH)


## Phase 2 and Enrage speed the whole combo up by the same ratio they speed up the stomp.
func _combo_speed() -> float:
	var boss_data := data as BossData
	if boss_data == null:
		return 1.0
	return maxf(1.0, boss_data.attack_interval / maxf(0.1, _get_attack_interval()))


func _combo_step_duration(step: ComboStep) -> float:
	var boss_data := data as BossData
	match step:
		ComboStep.SLASH:
			return boss_data.combo_slash_duration
		ComboStep.STAB:
			return boss_data.combo_stab_duration
		ComboStep.SLAM:
			return boss_data.combo_slam_duration
	return 0.0


func _combo_step_hit_time(step: ComboStep) -> float:
	var boss_data := data as BossData
	match step:
		ComboStep.SLASH:
			return boss_data.combo_slash_hit_time
		ComboStep.STAB:
			return boss_data.combo_stab_hit_time
		ComboStep.SLAM:
			return boss_data.combo_slam_windup
	return 0.0


func _enter_combo_step(step: ComboStep) -> void:
	var boss_data := data as BossData
	combo_step = step
	_combo_step_time = 0.0
	_combo_hit_done = false
	var speed := _combo_speed()
	var clip: StringName = CLIP_SLASH_1H
	var step_name: StringName = &"SLASH_1H"
	match step:
		ComboStep.STAB:
			clip = CLIP_STAB_1H
			step_name = &"STAB_1H"
		ComboStep.SLAM:
			clip = CLIP_SLAM_2H
			step_name = &"2H_GROUND_SLAM"
			_locked_stomp_center = get_stomp_center()
			EventBus.telegraph_started.emit(&"stomp", _locked_stomp_center,
					stomp_radius * boss_data.combo_slam_radius_mult, boss_data.combo_slam_windup / speed)
	attack_step_started.emit(_combo_attack_id, step_name, clip, _combo_step_duration(step) / speed)
	if anim_player != null and anim_player.has_animation(clip):
		anim_player.speed_scale = speed
		anim_player.play(clip, 0.1)


func _tick_combo(delta: float) -> void:
	if is_dead:
		stop_attack_sequence()
		return
	# An AI combo belongs to the ATTACK state; anything that pulls the boss out of it ends the combo.
	if _combo_from_ai and current_state != Enums.EnemyState.ATTACK:
		stop_attack_sequence()
		return

	# Step time advances faster in phase 2 and Enrage, so the data timings stay in clip seconds.
	_combo_step_time += delta * _combo_speed()
	if not _combo_hit_done:
		# Lock rotation in attack state: do not track combo target while swinging.
		if _combo_step_time >= _combo_step_hit_time(combo_step):
			_combo_hit_done = true
			_strike_combo_step(combo_step)
			if combo_step == ComboStep.NONE:
				return  # the hit ended the combo (the boss died or broke its armor)

	if _combo_step_time >= _combo_step_duration(combo_step):
		if combo_step == _combo_last_step:
			_finish_combo()
		else:
			_enter_combo_step((combo_step + 1) as ComboStep)


## Turns toward target; disabled while attacking as facing and movement are locked during attacks.
func _track_combo_target(_delta: float) -> void:
	# Locked during attack state: do not turn toward target while attacking.
	return


func _strike_combo_step(step: ComboStep) -> void:
	var boss_data := data as BossData
	var hits: Array[Node3D] = []
	var step_name: StringName = &""
	match step:
		ComboStep.SLASH:
			step_name = &"SLASH_1H"
			for tgt in _collect_combo_targets():
				if _in_slash_hitbox(tgt, boss_data.combo_slash_range, boss_data.combo_slash_arc_deg):
					var slash_damage := boss_data.normal_attack_damage if _combo_attack_id == NORMAL_ATTACK_ID else boss_data.combo_slash_damage
					if _apply_combo_hit(tgt, slash_damage, 0.0):
						hits.append(tgt)
		ComboStep.STAB:
			step_name = &"STAB_1H"
			for tgt in _collect_combo_targets():
				if _in_stab_hitbox(tgt, boss_data.combo_stab_range, boss_data.combo_stab_width):
					if _apply_combo_hit(tgt, boss_data.combo_stab_damage, boss_data.combo_stab_knockback):
						hits.append(tgt)
		ComboStep.SLAM:
			step_name = &"2H_GROUND_SLAM"
			hits = execute_stomp(stomp_radius * boss_data.combo_slam_radius_mult, boss_data.combo_slam_screen_shake,
					boss_data.combo_slam_damage_mult, _locked_stomp_center)
			_locked_stomp_center = Vector3.INF
	attack_hit.emit(_combo_attack_id, step_name, hits)


func _finish_combo() -> void:
	var from_ai := _combo_from_ai
	var attack_id := _combo_attack_id
	combo_step = ComboStep.NONE
	_combo_from_ai = false
	is_in_attack_sequence = false
	current_attack_id = 0
	attack_sequence_finished.emit(attack_id)
	if anim_player != null and anim_player.has_animation(CLIP_IDLE):
		anim_player.speed_scale = 1.0
		anim_player.play(CLIP_IDLE, 0.2)
	if from_ai:
		_hand_back_to_attack_state(_combo_speed(), attack_id != NORMAL_ATTACK_ID)


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


func _apply_combo_hit(target: Node3D, base_damage: int, knockback: float) -> bool:
	if not is_instance_valid(target):
		return false
	var is_cmd := target.is_in_group(&"commander")
	if is_cmd and bool(target.get("is_dodging")):
		return false
	var kb := 0.0
	if is_cmd and not bool(target.get("is_deploying")):
		kb = knockback
	var diff := target.global_position - global_position
	diff.y = 0.0
	var hit_dir := diff.normalized() if diff.length_squared() > 0.001 else _combo_forward()
	target.take_damage(DamageInfo.new(_scale_attack_damage(base_damage), Enums.DamageType.SLASH, self, kb, hit_dir))
	return true


## Commander capsules have no closest-point helper; count their radius as reach instead.
func _target_body_radius(target: Node3D) -> float:
	var col := _find_collision_shape(target)
	if col != null and col.shape is CapsuleShape3D:
		return (col.shape as CapsuleShape3D).radius
	return 0.0


## Ground point the mace hits: stomp_forward_offset_heights boss heights straight ahead.
func get_stomp_center() -> Vector3:
	var center := global_position + _combo_forward() * get_stomp_forward_offset()
	center.y = global_position.y
	return center


func get_stomp_forward_offset() -> float:
	var boss_data := data as BossData
	if boss_data == null:
		return 0.0
	return boss_data.stomp_forward_offset_heights * get_model_height()


## Height of the boss model (feet to top of the head), measured once from its meshes.
func get_model_height() -> float:
	if _model_height > 0.0:
		return _model_height
	var top := -INF
	var bottom := INF
	var model := get_node_or_null(^"Model")
	if model != null and is_inside_tree():
		var to_local := global_transform.affine_inverse()
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			# Skip the weapon: it follows the hand, so its height depends on the current pose.
			if mesh.mesh == null or mesh.get_parent() is BoneAttachment3D:
				continue
			var box: AABB = to_local * mesh.global_transform * mesh.get_aabb()
			top = maxf(top, box.end.y)
			bottom = minf(bottom, box.position.y)
	var boss_data := data as BossData
	if top > bottom:
		_model_height = top - minf(bottom, 0.0)
	else:
		_model_height = boss_data.fallback_model_height if boss_data != null else 3.17
	return _model_height


func _scale_attack_damage(base_damage: int) -> int:
	if wave_dmg_mult <= 0.0 and not is_enraged:
		return base_damage
	var dmg: float = float(base_damage)
	if wave_dmg_mult > 0.0:
		dmg *= wave_dmg_mult
	if is_enraged:
		dmg *= GameConfig.enrage_damage_mult
	return maxi(1, int(round(dmg)))


## Three stomps back to back with a growing radius. Each stomp restarts the slam clip and cuts
## it at triple_stomp_clip_cut, so the next stomp always plays its own wind-up and impact.
func play_triple_stomp(from_ai: bool = false) -> void:
	var boss_data := data as BossData
	if is_dead or boss_data == null:
		return
	stop_attack_sequence()
	is_in_attack_sequence = true
	current_attack_id = TRIPLE_STOMP_ID
	_triple_from_ai = from_ai
	if from_ai:
		triple_stomp_cooldown_left = boss_data.triple_stomp_cooldown
	_enter_triple_stomp(0)


func get_triple_stomp_count() -> int:
	var boss_data := data as BossData
	return boss_data.triple_stomp_radius_mults.size() if boss_data != null else 0


func get_triple_stomp_radius(index: int) -> float:
	var boss_data := data as BossData
	if boss_data == null or index < 0 or index >= boss_data.triple_stomp_radius_mults.size():
		return stomp_radius
	return stomp_radius * boss_data.triple_stomp_radius_mults[index]


## Clip seconds one stomp of the chain lasts before the next one starts.
func get_triple_stomp_step_length() -> float:
	var boss_data := data as BossData
	return _slam_clip_length() * boss_data.triple_stomp_clip_cut


func _slam_clip_length() -> float:
	if anim_player != null and anim_player.has_animation(CLIP_SLAM_2H):
		return anim_player.get_animation(CLIP_SLAM_2H).length
	return SLAM_CLIP_FALLBACK_LENGTH


func _triple_stomp_speed() -> float:
	var boss_data := data as BossData
	return maxf(0.05, boss_data.triple_stomp_anim_speed) * _combo_speed()


func _enter_triple_stomp(index: int) -> void:
	var boss_data := data as BossData
	_triple_index = index
	_triple_time = 0.0
	_triple_hit_done = false
	var speed := _triple_stomp_speed()
	var step_name := StringName("TRIPLE_STOMP_%d" % (index + 1))
	attack_step_started.emit(TRIPLE_STOMP_ID, step_name, CLIP_SLAM_2H, get_triple_stomp_step_length() / speed)
	_locked_stomp_center = get_stomp_center()
	EventBus.telegraph_started.emit(&"stomp", _locked_stomp_center, get_triple_stomp_radius(index),
			boss_data.triple_stomp_hit_time / speed)
	if anim_player != null and anim_player.has_animation(CLIP_SLAM_2H):
		anim_player.speed_scale = speed
		anim_player.play(CLIP_SLAM_2H, 0.08)
		# play() keeps going when the clip is already playing; rewind so every stomp has its wind-up.
		anim_player.seek(0.0, true)


func _tick_triple_stomp(delta: float) -> void:
	if is_dead or (_triple_from_ai and current_state != Enums.EnemyState.ATTACK):
		stop_attack_sequence()
		return
	var boss_data := data as BossData
	_triple_time += delta * _triple_stomp_speed()
	if not _triple_hit_done and _triple_time >= boss_data.triple_stomp_hit_time:
		_triple_hit_done = true
		var shakes := boss_data.triple_stomp_screen_shakes
		var shake: float = shakes[_triple_index] if _triple_index < shakes.size() else -1.0
		var step_name := StringName("TRIPLE_STOMP_%d" % (_triple_index + 1))
		var mults := boss_data.triple_stomp_damage_mults
		var dmg_mult: float = mults[_triple_index] if _triple_index < mults.size() else 1.0
		var center := _locked_stomp_center
		_locked_stomp_center = Vector3.INF
		attack_hit.emit(TRIPLE_STOMP_ID, step_name, execute_stomp(get_triple_stomp_radius(_triple_index), shake, dmg_mult, center))
		if _triple_index < 0:
			return
	# In attack state: facing is locked, do not turn toward target between stomps.
	if _triple_time >= get_triple_stomp_step_length():
		if _triple_index + 1 < get_triple_stomp_count():
			_enter_triple_stomp(_triple_index + 1)
		else:
			var from_ai := _triple_from_ai
			_triple_index = -1
			_triple_from_ai = false
			is_in_attack_sequence = false
			current_attack_id = 0
			attack_sequence_finished.emit(TRIPLE_STOMP_ID)
			if anim_player != null and anim_player.has_animation(CLIP_IDLE):
				anim_player.speed_scale = 1.0
				anim_player.play(CLIP_IDLE, 0.2)
			if from_ai:
				_hand_back_to_attack_state(_triple_stomp_speed(), true)


## Hitbox of one attack step, for debug drawing: {shape, reach, arc_deg, width, radius}.
## shape is &"sector", &"box" or &"circle"; empty when the step has no hitbox.
func get_step_hitbox(attack_id: int, step_name: StringName) -> Dictionary:
	var boss_data := data as BossData
	if boss_data == null:
		return {}
	if attack_id == NORMAL_ATTACK_ID and step_name == &"SLASH_1H":
		return {"shape": &"sector", "reach": boss_data.combo_slash_range, "arc_deg": boss_data.combo_slash_arc_deg}
	if attack_id == COMBO_SLAM_ID:
		match step_name:
			&"SLASH_1H":
				return {"shape": &"sector", "reach": boss_data.combo_slash_range, "arc_deg": boss_data.combo_slash_arc_deg}
			&"STAB_1H":
				return {"shape": &"box", "reach": boss_data.combo_stab_range, "width": boss_data.combo_stab_width}
			&"2H_GROUND_SLAM":
				return {"shape": &"circle", "radius": stomp_radius * boss_data.combo_slam_radius_mult, "forward_offset": get_stomp_forward_offset()}
	elif attack_id == TRIPLE_STOMP_ID:
		var index := String(step_name).trim_prefix("TRIPLE_STOMP_").to_int() - 1
		return {"shape": &"circle", "radius": get_triple_stomp_radius(index), "forward_offset": get_stomp_forward_offset()}
	elif attack_id == 1 and step_name == &"STOMP_WINDUP":
		return {"shape": &"circle", "radius": stomp_radius, "forward_offset": get_stomp_forward_offset()}
	return {}


## Executes a single attack animation cleanly.
func play_single_attack(clip: StringName, step_name: StringName = &"SINGLE_ATTACK", duration: float = -1.0, attack_id: int = 10) -> void:
	if is_dead or anim_player == null:
		return
	if not anim_player.has_animation(clip):
		push_warning("Bulwark: animation clip not found: %s" % clip)
		return

	stop_attack_sequence()  # also ends any running tick-driven sequence
	var token := _attack_token
	is_in_attack_sequence = true
	current_attack_id = attack_id

	var anim_dur := duration
	if anim_dur <= 0.0:
		var anim := anim_player.get_animation(clip)
		anim_dur = anim.length if anim != null else 1.0

	attack_step_started.emit(attack_id, step_name, clip, anim_dur)
	anim_player.speed_scale = 1.0
	anim_player.play(clip, 0.1)
	await _game_timer(anim_dur).timeout
	if token != _attack_token or is_dead:
		return

	is_in_attack_sequence = false
	current_attack_id = 0
	attack_sequence_finished.emit(attack_id)
	if anim_player != null and anim_player.has_animation(&"general/Idle_A"):
		anim_player.play(&"general/Idle_A", 0.2)


func play_slash_1h() -> void:
	play_single_attack(&"melee/Melee_1H_Slash", &"SLASH_1H", 1.57, 11)


func play_stab_1h() -> void:
	play_single_attack(&"melee/Melee_1H_Stab", &"STAB_1H", 1.40, 12)


func play_attack_2h() -> void:
	play_single_attack(&"melee/Melee_2H_Attack", &"ATTACK_2H", 1.33, 13)


func play_dualwield_slash() -> void:
	play_single_attack(&"melee/Melee_Dualwield_Slash", &"DUALWIELD_SLASH", 1.03, 14)


func play_offhand_slash() -> void:
	play_single_attack(&"melee/Melee_Dualwield_SlashCombo", &"OFFHAND_REVERSE", 1.60, 15)


## Stops any active attack sequence and transitions to Idle.
func stop_attack_sequence() -> void:
	_attack_token += 1
	combo_step = ComboStep.NONE
	_combo_from_ai = false
	_triple_index = -1
	_triple_from_ai = false
	_locked_stomp_center = Vector3.INF
	_stomp_recovering = false
	_turn_walking = false
	is_in_attack_sequence = false
	current_attack_id = 0
	if anim_player != null and is_instance_valid(anim_player):
		if anim_player.has_animation(&"general/Idle_A"):
			anim_player.play(&"general/Idle_A", 0.2)
		else:
			anim_player.stop()


## Returns every node the stomp damaged.
## center: where the mace lands; Vector3.INF means "in front of the boss right now".
func execute_stomp(custom_radius: float = -1.0, custom_shake: float = -1.0, damage_mult: float = 1.0,
		center: Vector3 = Vector3.INF) -> Array[Node3D]:
	var hits: Array[Node3D] = []
	if is_dead:
		return hits

	var tree := get_tree()
	if tree == null:
		return hits

	var boss_data := data as BossData
	var shake: float = custom_shake if custom_shake > 0.0 else (boss_data.stomp_screen_shake if boss_data != null else 0.6)
	EventBus.screen_shake_requested.emit(shake, &"stomp")

	var radius: float = custom_radius if custom_radius > 0.0 else stomp_radius
	var stomp_pos := center if center.is_finite() else get_stomp_center()
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

		var diff := tgt.global_position - stomp_pos
		diff.y = 0.0
		var hit_dir := diff.normalized() if diff.length_squared() > 0.001 else _combo_forward()

		var is_cmd := tgt.is_in_group(&"commander")
		var is_dodge: bool = bool(tgt.get("is_dodging")) if is_cmd else false
		if is_cmd and is_dodge:
			continue

		var is_deploy: bool = bool(tgt.get("is_deploying")) if is_cmd else false
		var kb: float = 0.0
		if is_cmd and not is_deploy:
			kb = stomp_knockback

		var dmg := effective_stomp_damage if is_equal_approx(damage_mult, 1.0) else maxi(1, int(round(effective_stomp_damage * damage_mult)))
		var info := DamageInfo.new(dmg, Enums.DamageType.BLAST, self, kb, hit_dir)
		tgt.take_damage(info)
		hits.append(tgt)

		if is_cmd and not is_dodge and tgt.has_method("apply_stun") and stomp_stun_duration > 0.0:
			tgt.apply_stun(stomp_stun_duration)
	return hits


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
	var diff := _closest_point_on_target(target, from_pos) - from_pos
	diff.y = 0.0
	return diff.length()


func _find_collision_shape(target: Node3D) -> CollisionShape3D:
	var col_shape := target.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape == null:
		for child in target.get_children():
			if child is CollisionShape3D:
				return child
	return col_shape


## Nearest point of the target's box, cylinder or sphere collider to from_pos; the node origin
## for any other shape.
func _closest_point_on_target(target: Node3D, from_pos: Vector3) -> Vector3:
	var col_shape := _find_collision_shape(target)
	if col_shape != null and col_shape.shape != null:
		if col_shape.shape is BoxShape3D:
			var half_extents := (col_shape.shape as BoxShape3D).size * 0.5
			var local_pos := col_shape.global_transform.affine_inverse() * from_pos
			var clamped_local := Vector3(
				clampf(local_pos.x, -half_extents.x, half_extents.x),
				clampf(local_pos.y, -half_extents.y, half_extents.y),
				clampf(local_pos.z, -half_extents.z, half_extents.z)
			)
			return col_shape.global_transform * clamped_local
		elif col_shape.shape is CylinderShape3D:
			var cyl := col_shape.shape as CylinderShape3D
			var local_pos := col_shape.global_transform.affine_inverse() * from_pos
			var clamped_xz := Vector2(local_pos.x, local_pos.z).limit_length(cyl.radius)
			var clamped_y := clampf(local_pos.y, -cyl.height * 0.5, cyl.height * 0.5)
			return col_shape.global_transform * Vector3(clamped_xz.x, clamped_y, clamped_xz.y)
		elif col_shape.shape is SphereShape3D:
			var sph := col_shape.shape as SphereShape3D
			var to_from := from_pos - col_shape.global_position
			to_from.y = 0.0
			if to_from.length() <= sph.radius:
				return from_pos
			return col_shape.global_position + to_from.normalized() * sph.radius
	return target.global_position


func can_be_recycled() -> bool:
	return false


func can_be_culled() -> bool:
	return false


func _update_stuck_detection(delta: float) -> void:
	if is_dead or spawn_grace or current_phase == Enums.BossPhase.TRANSITION or is_in_attack_state():
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
		if _get_distance_to_target(obstacle, get_stomp_center()) <= stomp_radius:
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
