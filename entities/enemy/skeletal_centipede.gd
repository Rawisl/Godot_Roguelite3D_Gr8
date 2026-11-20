class_name SkeletalCentipede
extends BossEnemy
# TODO(Ender-Via): when bosses rotate by appearance, let WaveManager and the Hazard Trial pick this scene and its BossData instead of the fixed Bulwark.

## Skeletal Centipede: a long, low boss that slashes with its scythes, spits a poison stream that
## leaves a pool, and rolls over the commander from a distance. It shares the boss rules (armor
## phases, Enrage, stuck ladder, hitbox helpers) with BossEnemy and runs its own moves.
## A move runs on its own clock (clip seconds, sped up by phase 2 and Enrage), advanced in game time
## from _update_state, so hit times never depend on where the animation happens to be. Between
## moves the boss waits out a recovery in the ATTACK state, then asks CentipedeBrain what to do.
## Every size, distance and speed in the data is read through the data's body() so one model_scale
## value resizes the whole boss.

const POOL_SCENE: PackedScene = preload("res://entities/enemy/poison_pool.tscn")
const ROLL_EXTRA_LIBRARY: AnimationLibrary = preload("res://contents/assets/characters/enemy and boss/skeletal_centipede/skeletal_centipede_roll_extra.res")

## Clips of the model's own animation player.
const CLIP_WALK: StringName = &"walk"
const CLIP_SLASH_1: StringName = &"light_attack_1"
const CLIP_SLASH_2: StringName = &"light_attack_2"
const CLIP_SLASH_3: StringName = &"light_attack_3"
const CLIP_COMBO: StringName = &"light_attack_combo"
const CLIP_SPIT: StringName = &"poison_spit"
const CLIP_ROLL_LOOP: StringName = &"roll_loop"
const CLIP_ROLL_END: StringName = &"roll_end"
## Clips of the extra library added at _ready (the roar and the roll's wind-up).
const CLIP_ROAR: StringName = &"roll_extra/roar"
const CLIP_ROLL_START: StringName = &"roll_extra/roll_start"
## Clips built at _ready: a resting pose and the turns without their rotation of the root bone.
const LIBRARY_RUNTIME: StringName = &"runtime"
const CLIP_IDLE: StringName = &"runtime/idle"
const CLIP_TURN_LEFT: StringName = &"runtime/turn_left_90"
const CLIP_TURN_RIGHT: StringName = &"runtime/turn_right_90"
const CLIP_TURN_180: StringName = &"runtime/turn_180"
## The model's own turn clips; their root rotation is sampled to turn the boss in step with the feet.
const SOURCE_TURN_CLIPS: Array[StringName] = [&"turn_left_90", &"turn_right_90", &"turn_180"]
## The clip whose first frame is the resting pose.
const SOURCE_REST_CLIP: StringName = &"roll_start"

const RIG_ROOT_TRACK: NodePath = ^"SkeletalCentipede_Rig/Skeleton3D:Root"
const BLEND_RIBS_CLOSE: StringName = &"ribs_close"

const MOVE_SLASH: StringName = &"slash"
const MOVE_COMBO: StringName = &"combo"
const MOVE_SPIT: StringName = &"spit"
const MOVE_ROLL: StringName = &"roll"
const MOVE_TURN: StringName = &"turn"

const VFX_SLASH_1: StringName = &"la1_vfx"
const VFX_SLASH_2: StringName = &"la2_vfx"
const VFX_SLASH_3: StringName = &"la3_vfx"
const VFX_COMBO: StringName = &"combo_vfx"

## How often a boss that is turning to face its target checks again whether it can act.
const TURN_RECHECK_TIME: float = 0.1
## Seconds of clip per sample of a turn clip's yaw table.
const YAW_SAMPLE_STEP: float = 1.0 / 60.0
## Speed at which the roll's lean follows its target, per second.
const LEAN_FOLLOW_RATE: float = 8.0
## Share of the roll's top speed below which the roll does not hit anything yet.
const ROLL_HIT_SPEED_SHARE: float = 0.5
## Seconds of the roll's start clip during which the boss stays put before it gathers speed.
const ROLL_START_STILL_TIME: float = 0.2
## The speed-up and recovery share used when the data is missing; keeps stripped test scenes alive.
const FALLBACK_CLIP_LENGTH: float = 1.0

signal move_started(move: StringName, clip: StringName, duration: float)
## One hit window of a move closed; targets holds every node it damaged (empty on a whiff).
signal move_hit(move: StringName, window: int, targets: Array)
signal move_finished(move: StringName)

enum RollPhase { NONE, ROAR, START, LOOP, END }

## One span of a move in which its hitbox can hurt, and who it hurt already.
class HitWindow extends RefCounted:
	var start: float = 0.0
	var end: float = 0.0
	var damage: int = 0
	var knockback: float = 0.0
	var reach: float = 0.0
	var arc_deg: float = 0.0
	var swept: bool = false
	var closed: bool = false
	var hit: Array[Node3D] = []

## Game seconds left before the move may be picked again; counted from the start of the move.
var combo_cooldown_left: float = 0.0
var spit_cooldown_left: float = 0.0
var roll_cooldown_left: float = 0.0
## Last move the boss started.
var last_chosen_move: StringName = &""

var _move: StringName = &""
var _move_time: float = 0.0
var _move_duration: float = 0.0
var _move_clip_speed: float = 1.0
var _pending_move: StringName = &""
var _recovery_left: float = 0.0
var _windows: Array[HitWindow] = []
var _structure_move: bool = false

var _turn_start_yaw: float = 0.0
var _turn_yaw_delta: float = 0.0
var _turn_table: PackedFloat32Array = PackedFloat32Array()
## Yaw of each source turn clip over time, sampled from its root bone: name -> PackedFloat32Array.
var _turn_tables: Dictionary = {}

var _spit_pool_spawned: bool = false
var _spit_emitting: bool = false
var _spit_next_tick: float = 0.0

var _roll_phase: RollPhase = RollPhase.NONE
var _roll_phase_time: float = 0.0
var _roll_speed: float = 0.0
var _roll_end_speed: float = 0.0
var _roll_distance: float = 0.0
var _roll_blocked_time: float = 0.0
var _roll_hit: Array[Node3D] = []

var _dying: bool = false
var _death_left: float = 0.0

var _model: Node3D
var _skeleton: Skeleton3D
var _body_mesh: MeshInstance3D
var _fx: CentipedeFx

var cdata: CentipedeBossData:
	get:
		return data as CentipedeBossData


func _ready() -> void:
	super._ready()
	if cdata == null:
		return
	_model = get_node_or_null(^"Model") as Node3D
	if _model != null:
		_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
		_body_mesh = _model.find_child("SkeletalCentipede_Mesh", true, false) as MeshInstance3D
		_fx = _model.get_node_or_null(^"CentipedeFx") as CentipedeFx
	_apply_model_scale()
	if _fx != null and _skeleton != null:
		_fx.bind(_skeleton, _body_mesh)
		_fx.apply_scale(cdata.model_scale)
	if cdata.roll_min_distance < cdata.body(cdata.spit_max_reach) - 1.0:
		push_warning("SkeletalCentipede: roll_min_distance is inside the spit's reach, the roll will crowd out the spit")


func _setup_anim_player() -> void:
	super._setup_anim_player()
	if anim_player == null or cdata == null:
		return
	if not anim_player.has_animation_library(&"roll_extra"):
		anim_player.add_animation_library(&"roll_extra", ROLL_EXTRA_LIBRARY)
	if not anim_player.has_animation_library(LIBRARY_RUNTIME):
		_build_runtime_library()


## One resting-pose clip, and the three turns with the root bone's rotation taken out (the boss
## node turns instead; its yaw follows the removed rotation, see _tick_turn).
func _build_runtime_library() -> void:
	var library := AnimationLibrary.new()
	if anim_player.has_animation(SOURCE_REST_CLIP):
		library.add_animation(&"idle", _make_rest_clip(anim_player.get_animation(SOURCE_REST_CLIP)))
	for clip_name in SOURCE_TURN_CLIPS:
		if not anim_player.has_animation(clip_name):
			continue
		var source := anim_player.get_animation(clip_name)
		_turn_tables[clip_name] = _sample_root_yaw(source)
		var copy := source.duplicate() as Animation
		var root_track := copy.find_track(RIG_ROOT_TRACK, Animation.TYPE_ROTATION_3D)
		if root_track >= 0:
			copy.remove_track(root_track)
		library.add_animation(clip_name, copy)
	anim_player.add_animation_library(LIBRARY_RUNTIME, library)


## Every pose track of source at its first frame, held for a second and looped.
func _make_rest_clip(source: Animation) -> Animation:
	var rest := Animation.new()
	rest.length = 1.0
	rest.loop_mode = Animation.LOOP_LINEAR
	for i in source.get_track_count():
		var type := source.track_get_type(i)
		var track := -1
		match type:
			Animation.TYPE_ROTATION_3D:
				track = rest.add_track(type)
				var value := source.rotation_track_interpolate(i, 0.0)
				rest.rotation_track_insert_key(track, 0.0, value)
				rest.rotation_track_insert_key(track, 1.0, value)
			Animation.TYPE_POSITION_3D:
				track = rest.add_track(type)
				var value := source.position_track_interpolate(i, 0.0)
				rest.position_track_insert_key(track, 0.0, value)
				rest.position_track_insert_key(track, 1.0, value)
			Animation.TYPE_SCALE_3D:
				track = rest.add_track(type)
				var value := source.scale_track_interpolate(i, 0.0)
				rest.scale_track_insert_key(track, 0.0, value)
				rest.scale_track_insert_key(track, 1.0, value)
			Animation.TYPE_BLEND_SHAPE:
				track = rest.add_track(type)
				var value := source.blend_shape_track_interpolate(i, 0.0)
				rest.blend_shape_track_insert_key(track, 0.0, value)
				rest.blend_shape_track_insert_key(track, 1.0, value)
			Animation.TYPE_VALUE:
				track = rest.add_track(type)
				var value: Variant = source.value_track_interpolate(i, 0.0)
				rest.track_insert_key(track, 0.0, value)
				rest.track_insert_key(track, 1.0, value)
		if track >= 0:
			rest.track_set_path(track, source.track_get_path(i))
	return rest


## Yaw of the root bone over the clip, one sample per YAW_SAMPLE_STEP, unwrapped so a half turn
## keeps its direction.
func _sample_root_yaw(clip: Animation) -> PackedFloat32Array:
	var table := PackedFloat32Array()
	var track := clip.find_track(RIG_ROOT_TRACK, Animation.TYPE_ROTATION_3D)
	if track < 0:
		table.append(0.0)
		return table
	var yaw := 0.0
	var samples := int(ceil(clip.length / YAW_SAMPLE_STEP)) + 1
	for i in samples:
		var time := minf(float(i) * YAW_SAMPLE_STEP, clip.length)
		var forward := clip.rotation_track_interpolate(track, time) * Vector3.BACK
		yaw += angle_difference(yaw, atan2(forward.x, forward.z))
		table.append(yaw)
	return table


func _apply_model_scale() -> void:
	var s := cdata.model_scale
	if _model != null:
		_model.scale = Vector3.ONE * s
	_size_box(_body_shape)
	_size_box(get_node_or_null(^"HurtBox/CollisionShape3D") as CollisionShape3D)
	nav.radius = maxf(cdata.agent_radius, cdata.body(cdata.body_box_size.z * 0.5))
	nav.target_desired_distance = get_attack_range()


## The scene's shape is shared by every instance, so each boss sizes its own copy.
func _size_box(shape_node: CollisionShape3D) -> void:
	if shape_node == null or not shape_node.shape is BoxShape3D:
		return
	var box := (shape_node.shape as BoxShape3D).duplicate() as BoxShape3D
	box.size = cdata.body_v3(cdata.body_box_size)
	shape_node.shape = box
	shape_node.position = cdata.body_v3(cdata.body_box_center)


## Reach of the walk-up: the boss starts acting on a target this close.
func get_attack_range() -> float:
	return cdata.body(cdata.attack_range) if cdata != null else 1.5


func _melee_reach() -> float:
	return get_attack_range() + (cdata.body(cdata.melee_reach_margin) if cdata != null else 0.0)


func _release_melee_slot() -> void:
	super._release_melee_slot()
	if cdata != null and nav != null:
		nav.target_desired_distance = get_attack_range()


## Where the boss's electric core and vents sit; BossFxManager reads it. Fallbacks are in the
## boss's space, so they follow the model scale.
func get_fx_anchors() -> Dictionary:
	return {
		"core_bone": cdata.fx_core_bone,
		"core_offset": cdata.fx_core_offset,
		"core_fallback": cdata.body_v3(cdata.fx_core_fallback),
		"vent_bones": cdata.fx_vent_bones,
		"vent_offset": cdata.fx_vent_offset,
		"vent_fallback": cdata.body_v3(cdata.fx_vent_fallback),
	}


func _process(delta: float) -> void:
	if is_dead:
		_tick_death(delta)
		return
	combo_cooldown_left = maxf(0.0, combo_cooldown_left - delta)
	spit_cooldown_left = maxf(0.0, spit_cooldown_left - delta)
	roll_cooldown_left = maxf(0.0, roll_cooldown_left - delta)
	if push_commit_left > 0.0:
		push_commit_left = maxf(0.0, push_commit_left - delta)
	_update_t_away(delta)


# --- Walking and deciding ----------------------------------------------------------------------

func _update_state(delta: float) -> void:
	if is_dead:
		return
	if _move != &"":
		_tick_move(delta)
		return
	if current_state == Enums.EnemyState.ATTACK:
		_tick_attack_state(delta)
		return
	if current_state in [Enums.EnemyState.ADVANCE, Enums.EnemyState.CHASE, Enums.EnemyState.WAIT] \
			and current_phase != Enums.BossPhase.TRANSITION:
		_think_timer -= delta
		if _think_timer <= 0.0:
			_think_timer = cdata.ai_think_interval
			if _act_while_moving():
				return
		if current_state == Enums.EnemyState.CHASE and _target_in_attack_range():
			change_state(Enums.EnemyState.ATTACK)
			return
	super._update_state(delta)


## Enemy's own CHASE check reads the raw attack range; the boss's is scaled with its model.
func _target_in_attack_range() -> bool:
	if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
		return false
	var diff := _get_attack_point(current_target) - global_position
	diff.y = 0.0
	return diff.length() <= get_attack_range()


## The ATTACK state without a move: wait out the recovery, turning toward the target, then decide.
func _tick_attack_state(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
		_retarget_now()
		return
	_turn_toward_target(delta)
	_recovery_left -= delta
	if _recovery_left > 0.0:
		return
	_act_in_attack(choose_attack())


## Called by change_state when the boss enters the ATTACK state.
func _play_attack_anim() -> void:
	var action := _pending_move
	_pending_move = &""
	if action == &"":
		action = choose_attack()
	_act_in_attack(action)


## Starts what the AI picked, from the ATTACK state.
func _act_in_attack(action: StringName) -> void:
	match action:
		CentipedeBrain.SLASH, CentipedeBrain.COMBO, CentipedeBrain.SPIT, CentipedeBrain.ROLL:
			_retarget_commander()
			_start_move(action)
		CentipedeBrain.PUSH:
			if _is_commander(current_target):
				_push_on()
			else:
				_attack_structure()
		CentipedeBrain.FACE:
			_retarget_commander()
			_face_target()
		CentipedeBrain.CHASE:
			_retarget_commander()
			change_state(Enums.EnemyState.CHASE)
		_:
			# Nothing scores: a commander is only waited on, anything else gets the swing.
			if _is_commander(current_target):
				_wait_and_turn()
			else:
				_attack_structure()


func _start_move(move: StringName) -> void:
	last_chosen_move = move
	match move:
		MOVE_SLASH:
			_begin_slash(_pick_slash_clip(current_target))
		MOVE_COMBO:
			combo_cooldown_left = cdata.combo_cooldown
			_begin_combo()
		MOVE_SPIT:
			spit_cooldown_left = cdata.spit_cooldown
			_begin_spit()
		MOVE_ROLL:
			roll_cooldown_left = cdata.roll_cooldown
			_begin_roll()


## Structures only get the heavy swing, and only once the boss faces them.
func _attack_structure() -> void:
	if current_target == null or not is_instance_valid(current_target):
		_wait_and_turn()
		return
	var off_deg := absf(rad_to_deg(_yaw_to(current_target)))
	if off_deg > cdata.structure_face_tolerance_deg:
		_face_target()
		return
	last_chosen_move = MOVE_SLASH
	_begin_slash(CLIP_SLASH_3)


## Turns toward the target: a turn clip for a wide angle, the slow turn between checks otherwise.
func _face_target() -> void:
	if current_target == null or not is_instance_valid(current_target):
		_wait_and_turn()
		return
	var delta_yaw := _yaw_to(current_target)
	if absf(rad_to_deg(delta_yaw)) >= cdata.turn_clip_min_deg:
		last_chosen_move = MOVE_TURN
		_begin_turn(delta_yaw)
	else:
		_wait_and_turn()


## Holds the ATTACK state without a move; the recovery turns the boss, then it decides again.
func _wait_and_turn() -> void:
	_recovery_left = TURN_RECHECK_TIME


## Signed yaw between the boss's facing and the target (positive turns toward +X).
func _yaw_to(target: Node3D) -> float:
	var look := target.global_position - global_position
	look.y = 0.0
	if look.length_squared() < 0.001:
		return 0.0
	return angle_difference(rotation.y, atan2(look.x, look.z))


## Between moves in CHASE, ADVANCE or WAIT: acts on the AI's pick. True when it changed state.
func _act_while_moving() -> bool:
	var action := choose_attack()
	if action == &"":
		return false
	if action == CentipedeBrain.PUSH:
		if _is_commander(current_target):
			_push_on()
			return true
		return false
	var cmd := _get_valid_commander()
	if cmd == null:
		return false
	if action == CentipedeBrain.CHASE or action == CentipedeBrain.FACE:
		if current_target == cmd:
			return false
		set_target(cmd)
		if current_state != Enums.EnemyState.CHASE:
			change_state(Enums.EnemyState.CHASE)
		return true
	_pending_move = action
	change_state(Enums.EnemyState.ATTACK)
	return true


## Every target pick goes through the AI: the commander while it fights it, otherwise the next
## structure by target_rules (without the PLAYER rule) or the Fortress.
func _find_best_target() -> void:
	if current_state == Enums.EnemyState.FRENZY:
		super._find_best_target()
		return
	var action := choose_attack()
	if CentipedeBrain.is_commander_action(action):
		var cmd := _get_valid_commander()
		if cmd != null:
			set_target(cmd)
			return
	var structure := _find_structure_target()
	if structure != null:
		set_target(structure)
	else:
		_find_default_target()


## True when the commander stands in front, inside the slash or the spit's band.
func _commander_in_reach(cmd: Node3D) -> bool:
	if cdata == null or not is_in_front(cmd):
		return false
	if _in_slash_hitbox(cmd, cdata.body(cdata.slash_range), cdata.slash_arc_deg):
		return true
	return _in_spit_band(cmd)


## What the boss knows about the fight right now, for CentipedeBrain.
func build_situation() -> CentipedeBrain.Situation:
	var s := CentipedeBrain.Situation.new()
	s.hp_fraction = get_hp_fraction()
	s.t_away = t_away
	s.pushing = _pushing
	s.push_committed = push_commit_left > 0.0
	s.has_objective = not in_hazard_trial and _find_structure_target() != null
	var appearance := get_moveset_appearance()
	s.combo_unlocked = appearance >= cdata.combo_unlock_appearance
	s.spit_unlocked = appearance >= cdata.spit_unlock_appearance
	s.roll_unlocked = appearance >= cdata.roll_unlock_appearance
	s.combo_ready = combo_cooldown_left <= 0.0
	s.spit_ready = spit_cooldown_left <= 0.0
	s.roll_ready = roll_cooldown_left <= 0.0
	var cmd := _get_valid_commander()
	if cmd == null or is_dead or spawn_grace:
		return s
	s.engaged = _is_engaged(cmd)
	s.in_front = is_in_front(cmd)
	s.in_slash = _in_slash_hitbox(cmd, cdata.body(cdata.slash_range), cdata.slash_arc_deg)
	s.distance = _flat_gap(cmd, global_position)
	s.in_spit_reach = _in_spit_band(cmd)
	return s


## The utility AI's pick right now. Also remembers the scores for debugging.
func choose_attack() -> StringName:
	if cdata == null:
		return &""
	last_scores = CentipedeBrain.score_all(build_situation(), cdata)
	last_decision = CentipedeBrain.pick(last_scores, cdata, _ai_roll)
	if last_decision != &"":
		_pushing = last_decision == CentipedeBrain.PUSH
		if not _pushing:
			_left_commander = false
	return last_decision


## Distance from from_pos to the nearest point of the target's body, on the floor plane.
func _flat_gap(target: Node3D, from_pos: Vector3) -> float:
	return maxf(0.0, _get_distance_to_target(target, from_pos) - _target_body_radius(target))


## The commander stands in the spit's distance band and inside the pool's opening angle.
func _in_spit_band(target: Node3D) -> bool:
	var gap := _flat_gap(target, global_position)
	if gap < cdata.body(cdata.spit_min_reach) or gap > cdata.body(cdata.spit_max_reach):
		return false
	var offset := _closest_point_on_target(target, global_position) - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.01:
		return true
	return rad_to_deg(_combo_forward().angle_to(offset)) <= cdata.pool_half_angle_deg


# --- Running a move ----------------------------------------------------------------------------

func _begin_move(move: StringName, clip: StringName, duration: float) -> void:
	_move = move
	_move_time = 0.0
	_move_duration = duration
	_windows.clear()
	_move_clip_speed = _combo_speed()
	_play_clip(clip, 0.1, _move_clip_speed)
	move_started.emit(move, clip, duration / _move_clip_speed)


## Plays clip from its start; the animation player does not restart a clip that is playing.
func _play_clip(clip: StringName, blend: float, speed: float) -> void:
	if anim_player == null or not anim_player.has_animation(clip):
		return
	anim_player.speed_scale = speed
	anim_player.play(clip, blend)
	anim_player.seek(0.0, true)


func _play_idle(blend: float) -> void:
	if anim_player == null or not anim_player.has_animation(CLIP_IDLE):
		return
	anim_player.speed_scale = 1.0
	anim_player.play(CLIP_IDLE, blend)


func _clip_length(clip: StringName) -> float:
	if anim_player != null and anim_player.has_animation(clip):
		return anim_player.get_animation(clip).length
	return FALLBACK_CLIP_LENGTH


func _tick_move(delta: float) -> void:
	if is_dead:
		return
	if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
		stop_attack_sequence()
		_retarget_now()
		return
	var step := delta * _move_clip_speed
	var previous_time := _move_time
	_move_time += step
	match _move:
		MOVE_SLASH:
			_tick_windows()
		MOVE_COMBO:
			_tick_combo(previous_time)
			_tick_windows()
		MOVE_SPIT:
			_tick_spit()
		MOVE_ROLL:
			_tick_roll(delta, step)
			return
		MOVE_TURN:
			_tick_turn()
	if _move_time >= _move_duration:
		_finish_move()


func _finish_move() -> void:
	var finished := _move
	var was_structure_move := _structure_move
	var real_duration := _move_duration / _move_clip_speed
	for index in _windows.size():
		_close_window(index)
	_clear_move_state()
	_play_idle(0.2)
	if _fx != null:
		_fx.stop_all()
	_set_ribs_close(0.0)
	_set_lean(0.0)
	move_finished.emit(finished)
	_recovery_left = _recovery_after(finished, was_structure_move, real_duration)


## Pause after a move: the opening to hit back. A structure is hit on the attack interval.
func _recovery_after(finished: StringName, on_structure: bool, real_duration: float) -> float:
	var speed := _combo_speed()
	match finished:
		MOVE_TURN:
			return 0.0
		MOVE_SLASH:
			if on_structure:
				return maxf(cdata.attack_recovery / speed, _get_attack_interval() - real_duration)
			return cdata.attack_recovery / speed
	return cdata.heavy_attack_recovery / speed


func _clear_move_state() -> void:
	_move = &""
	_move_time = 0.0
	_windows.clear()
	_structure_move = false
	_roll_phase = RollPhase.NONE
	_roll_hit.clear()
	_spit_emitting = false


## Ends any running move and returns the boss to its resting pose.
func stop_attack_sequence() -> void:
	_pending_move = &""
	_recovery_left = 0.0
	_clear_move_state()
	velocity.x = 0.0
	velocity.z = 0.0
	if _fx != null:
		_fx.stop_all()
	_set_ribs_close(0.0)
	_set_lean(0.0)
	if not _dying:
		_play_idle(0.2)


## The armor break freezes the animation player; show the resting pose instead of a stopped swing.
func _start_armor_break_transition() -> void:
	super._start_armor_break_transition()
	_play_idle(0.1)


func _play_locomotion_anim() -> void:
	if anim_player == null or cdata == null or not anim_player.has_animation(CLIP_WALK):
		return
	var ground_speed := cdata.move_speed * speed_multiplier * get_slow_factor()
	anim_player.speed_scale = clampf(ground_speed / cdata.body(cdata.walk_anim_base_speed), 0.0, cdata.walk_anim_max_scale)
	anim_player.play(CLIP_WALK)


func _locks_movement() -> bool:
	return is_in_attack_state() and _move != MOVE_ROLL and _move != MOVE_COMBO


func _set_ribs_close(value: float) -> void:
	if _body_mesh != null and _body_mesh.get_blend_shape_count() > 0:
		_body_mesh.set_blend_shape_value(0, value)


func _set_lean(angle: float) -> void:
	if _model != null:
		_model.rotation.z = angle


## One strike on a target: nothing for a dodging commander, no knockback while it deploys.
## Returns true when the hit landed.
func _strike_target(target: Node3D, base_damage: int, knockback: float, damage_type: Enums.DamageType,
		direction: Vector3 = Vector3.ZERO) -> bool:
	if not is_instance_valid(target):
		return false
	var is_cmd := target.is_in_group(&"commander")
	if is_cmd and bool(target.get(&"is_dodging")):
		return false
	var kb := 0.0
	if is_cmd and not bool(target.get(&"is_deploying")):
		kb = knockback
	var hit_dir := direction if direction.length_squared() > 0.001 else _direction_to(target)
	target.take_damage(DamageInfo.new(_scale_attack_damage(base_damage), damage_type, self, kb, hit_dir))
	if is_cmd:
		_on_commander_hit()
	return true


## A damage-over-time tick (poison): no knockback, and a dodging commander is skipped.
func _strike_dot(target: Node3D, base_damage: int) -> bool:
	if not is_instance_valid(target):
		return false
	if target.is_in_group(&"commander") and bool(target.get(&"is_dodging")):
		return false
	var amount := float(_scale_attack_damage(base_damage))
	target.take_damage(DamageInfo.outgoing(amount, 1.0, Enums.DamageType.MAGIC, self, 0.0, _direction_to(target), true))
	if target.is_in_group(&"commander"):
		_on_commander_hit()
	return true


func _direction_to(target: Node3D) -> Vector3:
	var diff := target.global_position - global_position
	diff.y = 0.0
	return diff.normalized() if diff.length_squared() > 0.001 else _combo_forward()


# --- Hit windows (slash and combo) -------------------------------------------------------------

func _new_window(span: Vector2, damage: int, knockback: float, reach: float, arc_deg: float) -> HitWindow:
	var window := HitWindow.new()
	window.start = span.x
	window.end = span.y
	window.damage = damage
	window.knockback = knockback
	window.reach = reach
	window.arc_deg = arc_deg
	return window


func _tick_windows() -> void:
	for index in _windows.size():
		var window := _windows[index]
		if window.closed or _move_time < window.start:
			continue
		if _move_time <= window.end or not window.swept:
			_sweep_window(window)
		if _move_time > window.end:
			_close_window(index)


## Hurts every target inside the window's sector that this window has not hurt yet.
func _sweep_window(window: HitWindow) -> void:
	window.swept = true
	for target in _collect_combo_targets():
		if window.hit.has(target) or not _in_slash_hitbox(target, window.reach, window.arc_deg):
			continue
		if _strike_target(target, window.damage, window.knockback, Enums.DamageType.SLASH):
			window.hit.append(target)


func _close_window(index: int) -> void:
	var window := _windows[index]
	if window.closed:
		return
	window.closed = true
	move_hit.emit(_move, index, window.hit.duplicate())


# --- Slash -------------------------------------------------------------------------------------

## LA3 when the target is dead ahead, otherwise LA1 for the right half and LA2 for the left.
func _pick_slash_clip(target: Node3D) -> StringName:
	if target == null or not is_instance_valid(target):
		return CLIP_SLASH_3
	if absf(rad_to_deg(_yaw_to(target))) <= cdata.slash_center_deg:
		return CLIP_SLASH_3
	var local := to_local(target.global_position)
	return CLIP_SLASH_1 if local.x < 0.0 else CLIP_SLASH_2


func _begin_slash(clip: StringName) -> void:
	_structure_move = not _is_commander(current_target)
	_begin_move(MOVE_SLASH, clip, _clip_length(clip))
	var heavy := clip == CLIP_SLASH_3
	var damage := cdata.la3_damage if heavy else cdata.la_damage
	var knockback := cdata.la3_knockback if heavy else 0.0
	var arc := cdata.la3_arc_deg if heavy else cdata.slash_arc_deg
	_windows.append(_new_window(cdata.slash_hit_window, damage, knockback, cdata.body(cdata.slash_range), arc))
	if _fx != null:
		_fx.play_slash(_slash_vfx(clip), _move_clip_speed)


func _slash_vfx(clip: StringName) -> StringName:
	match clip:
		CLIP_SLASH_1:
			return VFX_SLASH_1
		CLIP_SLASH_2:
			return VFX_SLASH_2
	return VFX_SLASH_3


# --- Combo -------------------------------------------------------------------------------------

func _begin_combo() -> void:
	_begin_move(MOVE_COMBO, CLIP_COMBO, _clip_length(CLIP_COMBO))
	var spans := cdata.combo_hit_windows
	for i in spans.size():
		var finisher := i == spans.size() - 1
		var damage := cdata.combo_finisher_damage if finisher else cdata.combo_hit_damage
		var knockback := cdata.combo_finisher_knockback if finisher else 0.0
		var arc := cdata.combo_finisher_arc_deg if finisher else cdata.combo_arc_deg
		_windows.append(_new_window(spans[i], damage, knockback, cdata.body(cdata.combo_range), arc))
	if _fx != null:
		_fx.play_slash(VFX_COMBO, _move_clip_speed)


## The boss steps forward during the move's advance windows, without leaving the floor's colliders.
func _tick_combo(previous_time: float) -> void:
	var moving_time := 0.0
	for span in cdata.combo_move_windows:
		moving_time += maxf(0.0, minf(_move_time, span.y) - maxf(previous_time, span.x))
	if moving_time <= 0.0:
		return
	move_and_collide(_combo_forward() * cdata.body(cdata.combo_move_speed) * moving_time)


# --- Spit --------------------------------------------------------------------------------------

func _begin_spit() -> void:
	_spit_pool_spawned = false
	_spit_next_tick = cdata.spit_stream_start + cdata.spit_stream_tick
	_begin_move(MOVE_SPIT, CLIP_SPIT, _clip_length(CLIP_SPIT) + cdata.spit_stream_duration)
	var pool_center := global_position + _combo_forward() * cdata.body(cdata.pool_offset.z + cdata.pool_length * cdata.spit_telegraph_along)
	EventBus.telegraph_started.emit(&"poison", pool_center, cdata.body(cdata.spit_telegraph_radius),
			cdata.pool_spawn_time / _move_clip_speed)


func _tick_spit() -> void:
	var stream_end := cdata.spit_stream_start + cdata.spit_stream_duration
	var streaming := _move_time >= cdata.spit_stream_start and _move_time < stream_end
	if streaming != _spit_emitting:
		_spit_emitting = streaming
		if _fx != null:
			_fx.set_spit_emitting(streaming)
	while _spit_next_tick <= _move_time and _spit_next_tick <= stream_end + 0.0001:
		_spit_next_tick += cdata.spit_stream_tick
		_hurt_in_stream()
	if not _spit_pool_spawned and _move_time >= cdata.pool_spawn_time:
		_spit_pool_spawned = true
		_spawn_pool()
	# The clip stops while the stream runs and goes on when it ends.
	var holding := _move_time >= cdata.spit_freeze_time and _move_time < cdata.spit_freeze_time + cdata.spit_stream_duration
	if anim_player != null:
		anim_player.speed_scale = 0.0 if holding else _move_clip_speed


## Where the stream leaves the boss, on the floor.
func get_spit_apex() -> Vector3:
	var apex := global_position + _combo_forward() * cdata.body(cdata.spit_apex_fallback)
	if _fx != null and _fx.is_inside_tree():
		apex = _fx.get_spit_origin()
	apex.y = global_position.y
	return apex


func _hurt_in_stream() -> void:
	var apex := get_spit_apex()
	for target in _collect_combo_targets():
		if _in_spit_cone(target, apex):
			_strike_dot(target, cdata.spit_stream_tick_damage)


func _in_spit_cone(target: Node3D, apex: Vector3) -> bool:
	var offset := _closest_point_on_target(target, apex) - apex
	offset.y = 0.0
	if offset.length() - _target_body_radius(target) > cdata.body(cdata.spit_stream_reach):
		return false
	if offset.length() < cdata.body(cdata.spit_cone_tip_radius):
		return true
	return rad_to_deg(_combo_forward().angle_to(offset)) <= cdata.spit_stream_half_angle_deg


func _spawn_pool() -> void:
	var pool := POOL_SCENE.instantiate() as PoisonPool
	pool.setup(self, _scale_attack_damage(cdata.pool_tick_damage), cdata)
	var world := get_tree().current_scene
	if world == null:
		world = get_parent()
	world.add_child(pool)
	pool.global_position = to_global(cdata.body_v3(cdata.pool_offset))
	pool.rotation.y = rotation.y


# --- Roll --------------------------------------------------------------------------------------

func _begin_roll() -> void:
	_roll_phase = RollPhase.ROAR
	_roll_phase_time = 0.0
	_roll_speed = 0.0
	_roll_distance = 0.0
	_roll_blocked_time = 0.0
	_roll_hit.clear()
	_begin_move(MOVE_ROLL, CLIP_ROAR, _clip_length(CLIP_ROAR))


func _enter_roll_phase(phase: RollPhase) -> void:
	_roll_phase = phase
	_roll_phase_time = 0.0
	match phase:
		RollPhase.START:
			_play_clip(CLIP_ROLL_START, 0.1, _move_clip_speed)
			if _fx != null:
				_fx.set_eye_sparks(false)
		RollPhase.LOOP:
			_play_clip(CLIP_ROLL_LOOP, 0.1, 1.0)
		RollPhase.END:
			_roll_end_speed = _roll_speed
			_play_clip(CLIP_ROLL_END, 0.1, _move_clip_speed)


## Top ground speed of the roll right now.
func _roll_full_speed() -> float:
	return cdata.body(cdata.roll_speed) * speed_multiplier * get_slow_factor()


func _tick_roll(delta: float, step: float) -> void:
	_roll_phase_time += step
	match _roll_phase:
		RollPhase.ROAR:
			_tick_roar()
			if _roll_phase_time >= _clip_length(CLIP_ROAR):
				_enter_roll_phase(RollPhase.START)
		RollPhase.START:
			_roll_speed = _roll_start_speed()
			_roll_travel(delta, true)
			if _roll_phase_time >= _clip_length(CLIP_ROLL_START):
				_enter_roll_phase(RollPhase.LOOP)
		RollPhase.LOOP:
			_roll_speed = _roll_full_speed()
			_roll_travel(delta, true)
			_set_roll_clip_speed()
			if _roll_covers_max_distance():
				_enter_roll_phase(RollPhase.END)
		RollPhase.END:
			var slide := maxf(0.001, cdata.roll_end_slide_time)
			_roll_speed = _roll_end_speed * (1.0 - clampf(_roll_phase_time / slide, 0.0, 1.0))
			_roll_travel(delta, false)
			_tick_end_glow()
			if _roll_phase_time >= _clip_length(CLIP_ROLL_END):
				_finish_roll()
	if _fx != null and _roll_phase != RollPhase.ROAR:
		var share := _roll_speed / maxf(0.001, cdata.body(cdata.roll_speed))
		_fx.set_speed_lines(clampf(share, 0.0, 1.0))


## The eyes light up and spark during the roar: the warning before the roll.
func _tick_roar() -> void:
	if _fx == null:
		return
	_fx.set_eye_glow(clampf(_roll_phase_time / maxf(0.001, _fx.eye_glow_rise_time), 0.0, 1.0))
	_fx.set_eye_sparks(_roll_phase_time >= _fx.eye_sparks_delay)


## Stands still for the first moments of the start clip, then eases up to full speed.
func _roll_start_speed() -> float:
	var length := _clip_length(CLIP_ROLL_START)
	var progress := (_roll_phase_time - ROLL_START_STILL_TIME) / maxf(0.001, length - ROLL_START_STILL_TIME)
	return _roll_full_speed() * smoothstep(0.0, 1.0, progress)


## The clip's playback follows the ground speed, so the body does not slip.
func _set_roll_clip_speed() -> void:
	if anim_player != null:
		anim_player.speed_scale = _roll_speed / maxf(0.001, cdata.body(cdata.roll_speed))


## The roll ends when the distance it still slides is all that is left of the maximum.
func _roll_covers_max_distance() -> bool:
	var slide := _roll_speed * cdata.roll_end_slide_time * 0.5
	return _roll_distance + slide >= cdata.roll_max_distance


func _roll_travel(delta: float, steer: bool) -> void:
	if steer:
		_steer_roll(delta)
	else:
		_set_lean_toward(0.0, delta)
	var wanted := _roll_speed * delta
	if wanted <= 0.0:
		return
	var motion := _combo_forward() * wanted
	if _roll_phase != RollPhase.END and _leaves_navmesh(global_position + motion):
		_enter_roll_phase(RollPhase.END)
		return
	var before := global_position
	move_and_collide(motion)
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_roll_distance += moved
	_track_roll_block(moved, wanted, delta)
	_roll_hits()


## True when the boss's next spot is off the navmesh (only checked where there is one).
func _leaves_navmesh(next_position: Vector3) -> bool:
	if not _has_navmesh():
		return false
	var closest := NavigationServer3D.map_get_closest_point(nav.get_navigation_map(), next_position)
	return Vector2(closest.x - next_position.x, closest.z - next_position.z).length() > NAVMESH_SNAP_DISTANCE


## Ends the roll when something holds the boss back for roll_blocked_time.
func _track_roll_block(moved: float, wanted: float, delta: float) -> void:
	if _roll_phase == RollPhase.END:
		return
	if moved >= wanted * cdata.roll_blocked_ratio:
		_roll_blocked_time = 0.0
		return
	_roll_blocked_time += delta
	if _roll_blocked_time >= cdata.roll_blocked_time:
		_enter_roll_phase(RollPhase.END)


## Bends the roll toward the commander at roll_turn_rate_deg and leans the body into the turn.
func _steer_roll(delta: float) -> void:
	var target := current_target
	if target == null or not is_instance_valid(target):
		_set_lean_toward(0.0, delta)
		return
	var max_step := deg_to_rad(cdata.roll_turn_rate_deg) * delta
	var step := clampf(_yaw_to(target), -max_step, max_step)
	rotation.y += step
	var share := step / maxf(0.0001, max_step)
	_set_lean_toward(-share * deg_to_rad(cdata.roll_lean_max_deg), delta)


func _set_lean_toward(angle: float, delta: float) -> void:
	if _model != null:
		_model.rotation.z = lerpf(_model.rotation.z, angle, 1.0 - exp(-LEAN_FOLLOW_RATE * delta))


## The roll's hit circle: the commander is hurt and thrown aside, a structure is hurt and stops the roll.
func _roll_hits() -> void:
	if _roll_speed < _roll_full_speed() * ROLL_HIT_SPEED_SHARE:
		return
	var center := to_global(cdata.body_v3(cdata.roll_ring_center))
	var radius := cdata.body(cdata.roll_hit_radius)
	for target in _collect_combo_targets():
		if _roll_hit.has(target):
			continue
		if _get_distance_to_target(target, center) - _target_body_radius(target) > radius:
			continue
		if target.is_in_group(&"commander"):
			if _strike_target(target, cdata.roll_damage, cdata.roll_knockback, Enums.DamageType.BLAST, _roll_throw_direction(target)):
				_roll_hit.append(target)
			continue
		_roll_hit.append(target)
		_strike_target(target, cdata.roll_damage, 0.0, Enums.DamageType.BLAST)
		if _roll_phase != RollPhase.END:
			_enter_roll_phase(RollPhase.END)


## Sideways, out of the roll's path.
func _roll_throw_direction(target: Node3D) -> Vector3:
	var forward := _combo_forward()
	var offset := target.global_position - global_position
	offset.y = 0.0
	var lateral := offset - forward * offset.dot(forward)
	if lateral.length_squared() < 0.0001:
		return Vector3.UP.cross(forward).normalized()
	return lateral.normalized()


## The body glows as the roll ends: rises, holds, falls.
func _tick_end_glow() -> void:
	if _fx == null:
		return
	var rise := maxf(0.001, _fx.body_glow_rise)
	var glow := 0.0
	if _roll_phase_time < rise:
		glow = _roll_phase_time / rise
	elif _roll_phase_time < rise + _fx.body_glow_hold:
		glow = 1.0
	else:
		glow = 1.0 - (_roll_phase_time - rise - _fx.body_glow_hold) / maxf(0.001, _fx.body_glow_fall)
	_fx.set_body_glow(clampf(glow, 0.0, 1.0))


func _finish_roll() -> void:
	_snap_to_navmesh()
	_finish_move()


# --- Turn --------------------------------------------------------------------------------------

## Plays the turn clip that fits delta_yaw; the boss turns by exactly that, in step with the clip's feet.
func _begin_turn(delta_yaw: float) -> void:
	var clip := CLIP_TURN_180
	if absf(rad_to_deg(delta_yaw)) <= cdata.turn_half_clip_deg:
		clip = CLIP_TURN_LEFT if delta_yaw > 0.0 else CLIP_TURN_RIGHT
	var source_name := StringName(String(clip).trim_prefix("runtime/"))
	_turn_table = _turn_tables.get(source_name, PackedFloat32Array())
	_turn_start_yaw = rotation.y
	_turn_yaw_delta = delta_yaw
	_begin_move(MOVE_TURN, clip, _clip_length(clip))


func _tick_turn() -> void:
	var fraction := 1.0
	if _turn_table.size() > 1 and _turn_table[_turn_table.size() - 1] != 0.0:
		var index := clampf(_move_time / YAW_SAMPLE_STEP, 0.0, float(_turn_table.size() - 1))
		var low := int(index)
		var high := mini(low + 1, _turn_table.size() - 1)
		var sampled := lerpf(_turn_table[low], _turn_table[high], index - float(low))
		fraction = sampled / _turn_table[_turn_table.size() - 1]
	elif _move_duration > 0.0:
		fraction = clampf(_move_time / _move_duration, 0.0, 1.0)
	rotation.y = _turn_start_yaw + _turn_yaw_delta * fraction


# --- Death -------------------------------------------------------------------------------------

func _play_death_anim() -> void:
	_dying = true
	_death_left = cdata.death_duration if cdata != null else 2.0
	if _fx != null:
		_fx.stop_all()
	_set_ribs_close(0.0)
	_play_idle(0.1)


## The model sinks into the floor and tips over, then the boss is removed.
func _tick_death(delta: float) -> void:
	if not _dying or cdata == null:
		return
	_death_left -= delta
	var progress := 1.0 - clampf(_death_left / maxf(0.001, cdata.death_duration), 0.0, 1.0)
	var eased := ease(progress, 2.0)
	if _model != null:
		_model.position.y = -cdata.body(cdata.death_sink_depth) * eased
		_model.rotation.z = deg_to_rad(cdata.death_tilt_deg) * eased
	if _death_left <= 0.0:
		queue_free()
