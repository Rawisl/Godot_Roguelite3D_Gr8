class_name Bulwark
extends BossEnemy
# TODO(Ender-Via): move the structure pick into BulwarkBrain as a scored action so _find_best_target only reads the result and no longer changes push state or uses the AI roll.

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
## How often a boss that is turning to face its target checks again whether it can attack.
const TURN_RECHECK_TIME: float = 0.1
## Facing a structure this closely, the boss stomps even if the ring would miss, so it never turns forever.
const STRUCTURE_FACE_TOLERANCE_DEG: float = 10.0
## Actions the utility AI can pick (see BulwarkBrain).
const MOVE_STOMP: StringName = &"stomp"
const MOVE_NORMAL: StringName = &"normal"
const MOVE_COMBO: StringName = &"combo"
const MOVE_TRIPLE: StringName = &"triple"
const MOVE_CHASE: StringName = &"chase"
const MOVE_FACE: StringName = &"face"
const MOVE_PUSH: StringName = &"push"
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

## Last move the boss started (a stomp on a structure counts as MOVE_STOMP).
var last_chosen_move: StringName = &""


func _ready() -> void:
	super._ready()
	get_model_height()  # measure in the spawn pose, before any swing lifts the arms


# The combo runs here rather than in _physics_process so it also plays when a showcase scene
# turns physics off. Delta is game time: scaled by the speed buttons and frozen by Pause.
func _process(delta: float) -> void:
	if triple_stomp_cooldown_left > 0.0:
		triple_stomp_cooldown_left = maxf(0.0, triple_stomp_cooldown_left - delta)
	if commander_stomp_cooldown_left > 0.0:
		commander_stomp_cooldown_left = maxf(0.0, commander_stomp_cooldown_left - delta)
	if push_commit_left > 0.0:
		push_commit_left = maxf(0.0, push_commit_left - delta)
	_update_t_away(delta)
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
	if current_state in [Enums.EnemyState.ADVANCE, Enums.EnemyState.CHASE, Enums.EnemyState.WAIT] \
			and current_phase != Enums.BossPhase.TRANSITION:
		_think_timer -= delta
		var boss_data := data as BossData
		if boss_data != null and _think_timer <= 0.0:
			_think_timer = boss_data.ai_think_interval
			if _act_while_moving():
				return
	super._update_state(delta)


## The pause between two moves of the ATTACK state: the last move is over and no sequence runs.
## A single stomp counts as over only once the mace is back up, not at its impact: the boss stays
## bent over the mace until then and must not turn.
func _is_recovering_between_moves() -> bool:
	return (current_state == Enums.EnemyState.ATTACK and is_attacking_active and not _stomp_recovering
			and not is_in_attack_sequence and combo_step == ComboStep.NONE and _triple_index < 0)


## While turning a wide angle between moves the boss walks slowly along its facing instead of
## spinning on the spot. Only once the last move's clip is over (Idle), so no swing is cut short.
func _update_turn_walk() -> void:
	var walk := false
	# Only around the commander: at a structure (and the Fortress's melee point) it turns on the spot.
	if _is_commander(current_target) and anim_player != null:
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


func _get_attack_windup() -> float:
	var boss_data := data as BossData
	return boss_data.stomp_windup if boss_data != null else 1.0


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
	var action := choose_attack()
	match action:
		MOVE_PUSH:
			if _is_commander(current_target):
				_push_on()
				return
			_attack_structure()
			return
		&"":
			# Nothing scores (no commander to fight, nothing to push on to): a commander target is
			# only waited on; anything else gets the stomp as usual.
			if _is_commander(current_target):
				_wait_and_turn()
			else:
				_attack_structure()
			return
		MOVE_FACE:
			_retarget_commander()
			_wait_and_turn()
			return
		MOVE_CHASE:
			_retarget_commander()
			change_state(Enums.EnemyState.CHASE)
			return
	_retarget_commander()
	_start_move(action)


## Plays one of the commander moves the AI picked.
func _start_move(move: StringName) -> void:
	_turn_walking = false
	last_chosen_move = move
	match move:
		MOVE_TRIPLE:
			play_triple_stomp(true)
		MOVE_COMBO:
			_begin_slash_sequence(COMBO_SLAM_ID, ComboStep.SLAM, true)
		MOVE_NORMAL:
			_begin_slash_sequence(NORMAL_ATTACK_ID, ComboStep.SLASH, true)
		_:
			if _is_commander(current_target):
				var boss_data := data as BossData
				commander_stomp_cooldown_left = boss_data.commander_stomp_cooldown if boss_data != null else 0.0
			attack_step_started.emit(1, &"STOMP_WINDUP", CLIP_SLAM_2H, _get_attack_windup())
			_play_stomp_anim()


## Structures only get the stomp. The boss first turns until the ring would reach the target, so
## a structure beside it is not stomped from the side.
func _attack_structure() -> void:
	if current_target != null and is_instance_valid(current_target) and not _stomp_reaches(current_target):
		_wait_and_turn()
		return
	# At boss_melee_point the wide wall is in reach from almost any facing: turn to the Fortress first.
	if (current_target != null and is_instance_valid(current_target) and current_target.is_in_group(&"fortress")
			and not _faces(current_target)):
		_wait_and_turn()
		return
	_start_move(MOVE_STOMP)


## Hold the ATTACK state without a move; the pause turns the boss (see _update_state), then the
## ATTACK state calls _play_attack_anim again.
func _wait_and_turn() -> void:
	is_attacking_active = true
	attack_windup_timer = 0.0
	attack_recovery_timer = TURN_RECHECK_TIME


## True when a stomp started now lands on the target, or the boss already faces it closely enough.
func _stomp_reaches(target: Node3D) -> bool:
	if _get_distance_to_target(target, get_stomp_center()) <= stomp_radius:
		return true
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return true
	return rad_to_deg(absf(angle_difference(rotation.y, atan2(to_target.x, to_target.z)))) <= STRUCTURE_FACE_TOLERANCE_DEG


## True when the boss faces the target's centre within STRUCTURE_FACE_TOLERANCE_DEG.
func _faces(target: Node3D) -> bool:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return true
	return rad_to_deg(absf(angle_difference(rotation.y, atan2(to_target.x, to_target.z)))) <= STRUCTURE_FACE_TOLERANCE_DEG


## Between moves in CHASE, ADVANCE or WAIT: acts on the AI's pick. True when it changed state.
func _act_while_moving() -> bool:
	var action := choose_attack()
	if action == &"":
		return false
	if action == MOVE_PUSH:
		if _is_commander(current_target):
			_push_on()
			return true
		return false
	var cmd := _get_valid_commander()
	if cmd == null:
		return false
	if action == MOVE_STOMP and current_state == Enums.EnemyState.CHASE and current_target == cmd:
		# A commander kiting just out of slash reach stands in the ring: stop and stomp.
		change_state(Enums.EnemyState.ATTACK)
		return true
	if current_target != cmd:
		set_target(cmd)
		if current_state != Enums.EnemyState.CHASE:
			change_state(Enums.EnemyState.CHASE)
		return true
	return false


## Every target pick goes through the AI: the commander while it fights it, otherwise the next
## structure by target_rules (without the PLAYER rule) or the Fortress.
func _find_best_target() -> void:
	if current_state == Enums.EnemyState.FRENZY:
		super._find_best_target()
		return
	var action := choose_attack()
	if BulwarkBrain.is_commander_action(action):
		var cmd := _get_valid_commander()
		if cmd != null:
			set_target(cmd)
			return
	var structure := _find_structure_target()
	if structure != null:
		set_target(structure)
	else:
		_find_default_target()


## A structure blocking the way is stomped as soon as the ring reaches it.
func _break_blocking_structure(obstacle: Node3D) -> void:
	if _get_distance_to_target(obstacle, get_stomp_center()) <= stomp_radius:
		execute_stomp()


## The commander stands in front, inside the slash or inside the ring a stomp would land on.
func _commander_in_reach(cmd: Node3D) -> bool:
	var boss_data := data as BossData
	if boss_data == null or not is_in_front(cmd):
		return false
	if _in_slash_hitbox(cmd, boss_data.combo_slash_range, boss_data.combo_slash_arc_deg):
		return true
	return _get_distance_to_target(cmd, get_stomp_center()) <= stomp_radius


## What the boss knows about the fight right now, for BulwarkBrain.
func build_situation() -> BulwarkBrain.Situation:
	var s := BulwarkBrain.Situation.new()
	var boss_data := data as BossData
	s.hp_fraction = get_hp_fraction()
	s.t_away = t_away
	s.pushing = _pushing
	s.push_committed = push_commit_left > 0.0
	s.has_objective = not in_hazard_trial and _find_structure_target() != null
	var appearance := get_moveset_appearance()
	s.combo_unlocked = boss_data != null and appearance >= boss_data.combo_unlock_appearance
	s.triple_unlocked = boss_data != null and appearance >= boss_data.triple_stomp_unlock_appearance
	s.triple_ready = triple_stomp_cooldown_left <= 0.0
	s.commander_stomp_ready = commander_stomp_cooldown_left <= 0.0
	var cmd := _get_valid_commander()
	if cmd == null or boss_data == null or is_dead or spawn_grace:
		return s
	s.engaged = _is_engaged(cmd)
	s.in_front = is_in_front(cmd)
	s.in_slash = _in_slash_hitbox(cmd, boss_data.combo_slash_range, boss_data.combo_slash_arc_deg)
	var center := get_stomp_center()
	s.in_ring = _get_distance_to_target(cmd, center) <= stomp_radius
	s.in_triple_reach = _get_distance_to_target(cmd, center) <= get_triple_stomp_radius(get_triple_stomp_count() - 1)
	return s


## The utility AI's pick right now (see BulwarkBrain). Also remembers the scores for debugging.
func choose_attack() -> StringName:
	var boss_data := data as BossData
	if boss_data == null:
		return MOVE_STOMP
	last_scores = BulwarkBrain.score_all(build_situation(), boss_data)
	last_decision = BulwarkBrain.pick(last_scores, boss_data, _ai_roll)
	if last_decision != &"":
		_pushing = last_decision == MOVE_PUSH
		if not _pushing:
			_left_commander = false
	return last_decision


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
	if is_cmd:
		_on_commander_hit()
	return true


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
		if is_cmd:
			_on_commander_hit()

		if is_cmd and not is_dodge and tgt.has_method("apply_stun") and stomp_stun_duration > 0.0:
			tgt.apply_stun(stomp_stun_duration)
	return hits
