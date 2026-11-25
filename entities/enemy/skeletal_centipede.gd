class_name SkeletalCentipede
extends BossEnemy

## Skeletal Centipede: a long, low boss that slashes with its scythes, spits a poison stream that
## leaves a pool, and rolls over the commander from a distance. It shares the boss rules (armor
## phases, Enrage, stuck ladder, hitbox helpers) with BossEnemy and runs its own moves.
## A move runs on its own clock (clip seconds, sped up by phase 2 and Enrage), advanced in game time
## from _update_state, so hit times never depend on where the animation happens to be. Between
## moves the boss waits out a recovery in the ATTACK state, then asks CentipedeBrain what to do.
## Every size, distance and speed in the data is read through the data's body() so one model_scale
## value resizes the whole boss; only the roll speed caps are in metres per second of the lane.
## Spit and Combo open with the roar, as a lead-in of the move itself. The Charge Roll is the roll
## frame (roar, start, loop, end) that homes in on the commander for a time instead of a distance.
## The Dash is a leap that follows its clip (wind-up first): sideways, which then buffs the next
## moves, or straight ahead, which has a cooldown of its own and no buff. The body flies the way it
## faced at take-off while the face turns toward the commander.
## The Combo stops its clip three times to take a longer step (the walk plays, the body turns toward
## the commander), and is cancelled into a pull-back to rest when the commander is far and no hit
## window is open.
## The commander's sword measures to the nearest point of the hurt box (see get_hit_point), which
## reaches ahead of the torso, so a swing from the front lands.
## A boss chasing the commander that a tower or Barricade holds back for blocked_retarget_time turns
## on that structure and stays at it until it breaks, blocked_lock_time runs out, or the commander
## comes into reach. No move carries the body onto a structure: a step that lifts it is undone.

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
## Clips that repeat. Set here rather than in the model's import settings, which Godot would
## otherwise rewrite with every default option of each clip.
const LOOPED_CLIPS: Array[StringName] = [CLIP_WALK, CLIP_ROLL_LOOP]
## The dash's wind-up clips (the model's own) and its leap clips (built at _ready without the root bone's sideways travel).
const CLIP_DASH_CHARGE_LEFT: StringName = &"dash_charging_left"
const CLIP_DASH_CHARGE_RIGHT: StringName = &"dash_charging_right"
const CLIP_DASH_CHARGE_FRONT: StringName = &"dash_charging_front"
const CLIP_DASH_LEFT: StringName = &"runtime/dash_left"
const CLIP_DASH_RIGHT: StringName = &"runtime/dash_right"
const CLIP_DASH_FRONT: StringName = &"runtime/dash_front"
## The model's own leap clips; their root travel is sampled to move the boss in step with the pose.
const SOURCE_DASH_CLIPS: Array[StringName] = [&"dash_left", &"dash_right", &"dash_front"]
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
## Track types that pose a bone; the extra clips' bone tracks of these types are held at rest.
const BONE_TRACK_TYPES: Array[Animation.TrackType] = [
	Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]
const BLEND_RIBS_CLOSE: StringName = &"ribs_close"

const MOVE_SLASH: StringName = &"slash"
const MOVE_COMBO: StringName = &"combo"
## Not a move the AI picks: the combo turns into it when the commander is out of reach.
const MOVE_COMBO_CANCEL: StringName = &"combo_cancel"
const MOVE_SPIT: StringName = &"spit"
const MOVE_ROLL: StringName = &"roll"
const MOVE_CHARGE_ROLL: StringName = &"charge_roll"
const MOVE_DASH: StringName = &"dash"
const MOVE_TURN: StringName = &"turn"

const VFX_SLASH_1: StringName = &"la1_vfx"
const VFX_SLASH_2: StringName = &"la2_vfx"
const VFX_SLASH_3: StringName = &"la3_vfx"
const VFX_COMBO: StringName = &"combo_vfx"

## Blend time (clip seconds) between the combo clip and the walk of its steps.
const COMBO_STEP_BLEND: float = 0.15
## How often a boss that is turning to face its target checks again whether it can act.
const TURN_RECHECK_TIME: float = 0.1
## Yaw change per step (radians) below which the boss counts as not turning.
const TURN_STEP_EPSILON: float = 0.0005
## A collision whose normal is steeper than this is a wall (the dash stops), a flatter one is floor.
const DASH_WALL_NORMAL_Y: float = 0.7
## A sideways step that lifts the body more than this (metres) pushed it up onto something and is undone.
const BODY_RISE_TOLERANCE: float = 0.05
## After a dash or roll the body higher than this above the navmesh (metres) is put back on it.
const LANDING_HEIGHT_TOLERANCE: float = 0.5
## The overlap test of the body's box is lifted by this (metres) so the floor under it does not count.
const OVERLAP_FLOOR_CLEARANCE: float = 0.1
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
## How close the nav agent walks to a structure's attack point; the boss stops earlier, as soon as
## its swing reaches (see _structure_in_strike_reach).
const STRUCTURE_NAV_ARRIVE: float = 0.5

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
## Counts down from the start of any heavy third swing; until 0 a commander dead ahead gets the side swing.
var la3_cooldown_left: float = 0.0
var spit_cooldown_left: float = 0.0
## Shared by the roll and the charge roll: starting either puts both on cooldown.
var roll_cooldown_left: float = 0.0
## Shared by the left and the right dash; the forward dash counts its own.
var dash_cooldown_left: float = 0.0
var dash_front_cooldown_left: float = 0.0
## Game seconds left of the buff a dash gives the next moves.
var dash_buff_left: float = 0.0
## Last move the boss started.
var last_chosen_move: StringName = &""

## Seconds in a row a structure held the boss back while it chased the commander.
var _chase_blocked_time: float = 0.0
## The structure the boss turned on after being held back, and the seconds it stays on it.
var _locked_structure: Node3D = null
var _structure_lock_left: float = 0.0

var _move: StringName = &""
var _move_time: float = 0.0
var _move_duration: float = 0.0
var _move_clip_speed: float = 1.0
var _pending_move: StringName = &""
var _recovery_left: float = 0.0
var _turning_in_place: bool = false
var _windows: Array[HitWindow] = []
var _structure_move: bool = false
## Clip seconds of the roar still to run before the move's own clip starts (Spit and Combo).
var _roar_left: float = 0.0
var _roar_main_clip: StringName = &""
## Index of the combo step being taken (-1 while the combo clip runs), the clip seconds it has
## left, and how many steps were taken already.
var _combo_step_index: int = -1
var _combo_step_left: float = 0.0
var _combo_steps_done: int = 0

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
## True while the running roll is the Charge Roll (it bends harder and runs for a time).
var _roll_charge: bool = false
## Game seconds the loop has run (the Charge Roll ends on this).
var _roll_loop_time: float = 0.0
## Seconds the Charge Roll still goes straight on after it hit the commander; -1 until it did.
var _roll_after_hit_left: float = -1.0

## The running dash: CentipedeBrain.DASH_LEFT, DASH_RIGHT or DASH_FRONT.
var _dash_action: StringName = &""
## The boss's facing when the dash began; the clip's sideways travel is turned by it.
var _dash_basis: Basis = Basis.IDENTITY
## Travel the body has covered so far, in world space.
var _dash_offset: Vector3 = Vector3.ZERO
## Clip seconds of the wind-up, during which the boss stands still.
var _dash_charge_length: float = 0.0
var _dash_leaping: bool = false
## True once a wall or the navmesh's edge held the dash; the clip then plays out on the spot.
var _dash_stopped: bool = false
## Leap clip seconds at which the root stops travelling; the move ends a short landing after it.
var _dash_travel_end_time: float = 0.0

## Game seconds the boss has been alive (counted in _process), which the turn times are read against.
var _ai_clock: float = 0.0
## When each turn clip began, in _ai_clock seconds; the ones older than turn_roll_window drop out.
var _turn_times: PackedFloat32Array = PackedFloat32Array()

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
		_fx.set_spit_speed_scale(cdata.fx_spit_speed_scale)


func _setup_anim_player() -> void:
	super._setup_anim_player()
	if anim_player == null or cdata == null:
		return
	for clip_name in LOOPED_CLIPS:
		if anim_player.has_animation(clip_name):
			anim_player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR
	if not anim_player.has_animation_library(&"roll_extra"):
		anim_player.add_animation_library(&"roll_extra", ROLL_EXTRA_LIBRARY)
	_hold_extra_bones_at_rest()
	if not anim_player.has_animation_library(LIBRARY_RUNTIME):
		_build_runtime_library()


## The roar and roll_start clips key bones (Shoulder.R) that none of the model's own clips key.
## Without a track the bone keeps the last pose it got, so a roar cut short left the arm raised
## through every move after it. Each model clip missing such a bone track gets one that holds the
## bone's rest value. Runs before the runtime library is built, so the idle and turn copies carry
## the track too. The clips are shared between bosses; a clip that already has the track is left
## alone, so a second boss adds nothing.
func _hold_extra_bones_at_rest() -> void:
	var root := anim_player.get_node_or_null(anim_player.root_node)
	if root == null or not anim_player.has_animation_library(&""):
		return
	var model_library := anim_player.get_animation_library(&"")
	var extra_library := anim_player.get_animation_library(&"roll_extra")
	for extra_name in extra_library.get_animation_list():
		var extra := extra_library.get_animation(extra_name)
		for i in extra.get_track_count():
			var type := extra.track_get_type(i)
			if type not in BONE_TRACK_TYPES:
				continue
			_hold_bone_track_at_rest(root, model_library, extra.track_get_path(i), type)


## Adds a rest-value track for one bone track (path, type) to every model clip that lacks it.
func _hold_bone_track_at_rest(root: Node, model_library: AnimationLibrary, path: NodePath, type: Animation.TrackType) -> void:
	var skeleton := root.get_node_or_null(NodePath(path.get_concatenated_names())) as Skeleton3D
	if skeleton == null:
		return
	var bone := skeleton.find_bone(path.get_concatenated_subnames())
	if bone < 0:
		return
	var rest := skeleton.get_bone_rest(bone)
	for clip_name in model_library.get_animation_list():
		var clip := model_library.get_animation(clip_name)
		if clip.find_track(path, type) >= 0:
			continue
		var track := clip.add_track(type)
		clip.track_set_path(track, path)
		match type:
			Animation.TYPE_ROTATION_3D:
				clip.rotation_track_insert_key(track, 0.0, rest.basis.get_rotation_quaternion())
			Animation.TYPE_POSITION_3D:
				clip.position_track_insert_key(track, 0.0, rest.origin)
			Animation.TYPE_SCALE_3D:
				clip.scale_track_insert_key(track, 0.0, rest.basis.get_scale())


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
	for clip_name in SOURCE_DASH_CLIPS:
		if anim_player.has_animation(clip_name):
			library.add_animation(clip_name, _make_in_place_clip(anim_player.get_animation(clip_name)))
	anim_player.add_animation_library(LIBRARY_RUNTIME, library)


## A copy of source whose root bone keeps its height but not its sideways travel: the boss node
## carries that travel instead (see _tick_dash), so the pose and the body never part.
func _make_in_place_clip(source: Animation) -> Animation:
	var copy := source.duplicate() as Animation
	var root_track := copy.find_track(RIG_ROOT_TRACK, Animation.TYPE_POSITION_3D)
	if root_track < 0:
		return copy
	for key in copy.track_get_key_count(root_track):
		var value := copy.track_get_key_value(root_track, key) as Vector3
		copy.track_set_key_value(root_track, key, Vector3(0.0, value.y, 0.0))
	return copy


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
	_size_box(_body_shape, cdata.body_box_size, cdata.body_box_center)
	_size_box(_hurt_shape(), cdata.hurt_box_size, cdata.hurt_box_center)
	nav.radius = maxf(cdata.agent_radius, cdata.body(cdata.body_box_size.z * 0.5))
	nav.target_desired_distance = get_attack_range()


func _hurt_shape() -> CollisionShape3D:
	return get_node_or_null(^"HurtBox/CollisionShape3D") as CollisionShape3D


## The scene's shape is shared by every instance, so each boss sizes its own copy.
func _size_box(shape_node: CollisionShape3D, size: Vector3, center: Vector3) -> void:
	if shape_node == null or not shape_node.shape is BoxShape3D:
		return
	var box := (shape_node.shape as BoxShape3D).duplicate() as BoxShape3D
	box.size = cdata.body_v3(size)
	shape_node.shape = box
	shape_node.position = cdata.body_v3(center)


## The point of the hurt box nearest to from; the commander's sword measures to it instead of to
## the boss's centre, which lies further off than the sword reaches.
func get_hit_point(from: Vector3) -> Vector3:
	var shape_node := _hurt_shape()
	if shape_node == null or not shape_node.shape is BoxShape3D:
		return global_position
	var half := (shape_node.shape as BoxShape3D).size * 0.5
	var local := shape_node.global_transform.affine_inverse() * from
	var inside := Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z))
	return shape_node.global_transform * inside


## Reach of the walk-up: the boss starts acting on a target this close.
func get_attack_range() -> float:
	return cdata.body(cdata.attack_range) if cdata != null else 1.5


func _melee_reach() -> float:
	return get_attack_range() + (cdata.body(cdata.melee_reach_margin) if cdata != null else 0.0)


func _release_melee_slot() -> void:
	super._release_melee_slot()
	if cdata != null and nav != null:
		nav.target_desired_distance = get_attack_range()


## The boss minds the commander within its own reach: both ranges are in body units.
func _engage_range() -> float:
	return cdata.body(cdata.engage_range) if cdata != null else super._engage_range()


func _engage_leash() -> float:
	return cdata.body(cdata.engage_leash) if cdata != null else super._engage_leash()


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
		"show_core": cdata.fx_show_core,
	}


func _process(delta: float) -> void:
	if is_dead:
		_tick_death(delta)
		return
	_ai_clock += delta
	combo_cooldown_left = maxf(0.0, combo_cooldown_left - delta)
	la3_cooldown_left = maxf(0.0, la3_cooldown_left - delta)
	spit_cooldown_left = maxf(0.0, spit_cooldown_left - delta)
	roll_cooldown_left = maxf(0.0, roll_cooldown_left - delta)
	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
	dash_front_cooldown_left = maxf(0.0, dash_front_cooldown_left - delta)
	dash_buff_left = maxf(0.0, dash_buff_left - delta)
	if push_commit_left > 0.0:
		push_commit_left = maxf(0.0, push_commit_left - delta)
	_structure_lock_left = maxf(0.0, _structure_lock_left - delta)
	_update_t_away(delta)


func _physics_process(delta: float) -> void:
	var before := global_position
	super._physics_process(delta)
	_track_chase_block(before, delta)


# --- Held back by a structure ------------------------------------------------------------------

## While chasing the commander, adds up the time a tower or Barricade holds the boss back (it
## touches one and barely moves) and turns on that structure once it passed blocked_retarget_time.
## The shared stuck ladder skips a commander chase, so this is the boss's own way out.
func _track_chase_block(before: Vector3, delta: float) -> void:
	if is_dead or in_hazard_trial or current_phase == Enums.BossPhase.TRANSITION:
		_chase_blocked_time = 0.0
		return
	if current_state != Enums.EnemyState.CHASE or not _is_commander(current_target) or _locked_structure != null:
		_chase_blocked_time = 0.0
		return
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if moved >= _walk_speed() * delta * cdata.blocked_speed_share:
		_chase_blocked_time = 0.0
		return
	var blocker := _touched_blocker()
	# A frame without contact neither adds nor clears, so a boss that slides off and on still counts.
	if blocker == null:
		return
	_chase_blocked_time += delta
	if _chase_blocked_time >= cdata.blocked_retarget_time:
		_lock_onto_structure(blocker)


func _walk_speed() -> float:
	return data.move_speed * speed_multiplier * get_slow_factor()


## The first structure the last slide ran into that the boss may attack to clear its way.
func _touched_blocker() -> Node3D:
	for index in get_slide_collision_count():
		var collider := get_slide_collision(index).get_collider() as Node3D
		if collider != null and _is_blocking_structure(collider):
			return collider
	return null


## A tower or Barricade on the ground (not the Fortress, not a wall tower) that can still be hit.
func _is_blocking_structure(node: Node3D) -> bool:
	if not node.is_in_group(&"tower") and not node.is_in_group(&"barricade"):
		return false
	if node.is_in_group(&"fortress") or _is_wall_tower(node):
		return false
	return _is_target_valid(node)


func _lock_onto_structure(structure: Node3D) -> void:
	_locked_structure = structure
	_structure_lock_left = cdata.blocked_lock_time
	_chase_blocked_time = 0.0
	set_target(structure)


func _release_structure_lock() -> void:
	_locked_structure = null
	_structure_lock_left = 0.0


## True while the boss stays on the structure it turned on. Lets go when the structure is gone or
## broken, the time is up, or the commander stands in reach.
func _structure_lock_holds() -> bool:
	if _locked_structure == null:
		return false
	if not is_instance_valid(_locked_structure) or not _is_target_valid(_locked_structure):
		_release_structure_lock()
		return false
	if _structure_lock_left <= 0.0:
		_release_structure_lock()
		return false
	var cmd := _get_valid_commander()
	if cmd != null and _commander_in_slash_reach(cmd):
		_release_structure_lock()
		return false
	return true


## True when the commander stands in front, inside the slash. The spit pool does not count: a
## commander behind the structure is often in it, and the lock would never hold.
func _commander_in_slash_reach(cmd: Node3D) -> bool:
	return is_in_front(cmd) and _in_slash_hitbox(cmd, cdata.body(cdata.slash_range), cdata.slash_arc_deg)


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
		_sync_nav_arrive()
		_think_timer -= delta
		if _think_timer <= 0.0:
			_think_timer = cdata.ai_think_interval
			if _act_while_moving():
				return
		if current_state == Enums.EnemyState.CHASE and _target_in_attack_range():
			change_state(Enums.EnemyState.ATTACK)
			return
	super._update_state(delta)


## Walks a structure's way up to its attack point, and stops short of it only when the swing
## reaches; a commander is walked up to the (scaled) attack range.
func _sync_nav_arrive() -> void:
	if nav == null:
		return
	var on_structure := current_target != null and is_instance_valid(current_target) and not _is_commander(current_target)
	nav.target_desired_distance = STRUCTURE_NAV_ARRIVE if on_structure else get_attack_range()


## Enemy's own CHASE check reads the raw attack range; the boss's is scaled with its model.
## A structure counts as in range when the swing reaches it, the same measure the swing hits by.
func _target_in_attack_range() -> bool:
	if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
		return false
	if not _is_commander(current_target):
		return _structure_in_strike_reach(current_target)
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
	var yaw_before := rotation.y
	_turn_toward_target(delta)
	_animate_turn_in_place(angle_difference(yaw_before, rotation.y), delta)
	_recovery_left -= delta
	if _recovery_left > 0.0:
		return
	_end_turn_in_place()
	_act_in_attack(choose_attack())


## Plays the walk clip in place while the boss turns without a move, at a speed matching the
## turning arc; back to idle once it stops turning.
func _animate_turn_in_place(yaw_step: float, delta: float) -> void:
	if anim_player == null or cdata == null or delta <= 0.0 or not anim_player.has_animation(CLIP_WALK):
		return
	if absf(yaw_step) < TURN_STEP_EPSILON:
		if _turning_in_place:
			_turning_in_place = false
			_play_idle(0.2)
		return
	var arc_speed := absf(yaw_step) / delta * cdata.body(cdata.turn_step_radius)
	anim_player.speed_scale = clampf(arc_speed / cdata.body(cdata.walk_anim_base_speed), 0.0, cdata.walk_anim_max_scale)
	if not _turning_in_place or anim_player.current_animation != CLIP_WALK:
		anim_player.play(CLIP_WALK, 0.15)
	_turning_in_place = true


## Hands the animation player back to the next move: no stale walk speed.
func _end_turn_in_place() -> void:
	if not _turning_in_place:
		return
	_turning_in_place = false
	if anim_player != null:
		anim_player.speed_scale = 1.0


## Called by change_state when the boss enters the ATTACK state.
func _play_attack_anim() -> void:
	var action := _pending_move
	_pending_move = &""
	if action == &"":
		action = choose_attack()
	_act_in_attack(action)


## Starts what the AI picked, from the ATTACK state.
func _act_in_attack(action: StringName) -> void:
	if _structure_lock_holds():
		_attack_structure()
		return
	match action:
		CentipedeBrain.SLASH, CentipedeBrain.COMBO, CentipedeBrain.SPIT, CentipedeBrain.ROLL, \
				CentipedeBrain.CHARGE_ROLL, CentipedeBrain.DASH_LEFT, CentipedeBrain.DASH_RIGHT, CentipedeBrain.DASH_FRONT:
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
			_turn_times.clear()
			_begin_roll()
		MOVE_CHARGE_ROLL:
			roll_cooldown_left = cdata.roll_cooldown
			_begin_charge_roll()
		CentipedeBrain.DASH_LEFT, CentipedeBrain.DASH_RIGHT, CentipedeBrain.DASH_FRONT:
			_begin_dash(move)


## Structures only get the heavy swing, once the boss faces them and the swing reaches them.
func _attack_structure() -> void:
	if current_target == null or not is_instance_valid(current_target):
		_wait_and_turn()
		return
	if not _structure_in_strike_reach(current_target):
		change_state(Enums.EnemyState.CHASE)
		return
	var off_deg := absf(rad_to_deg(_yaw_to_point(_structure_aim_point(current_target))))
	if off_deg > cdata.structure_face_tolerance_deg:
		_face_target()
		return
	last_chosen_move = MOVE_SLASH
	_begin_slash(CLIP_SLASH_3)


## True when the swing reaches the structure: the gap to the nearest point of its collider is
## inside a share of the slash's reach, so the walk-up never has to stop beyond it.
func _structure_in_strike_reach(target: Node3D) -> bool:
	return _flat_gap(target, global_position) <= cdata.body(cdata.slash_range) * cdata.structure_reach_share


## The point of a structure the boss faces and swings at: the nearest point of its collider.
func _structure_aim_point(target: Node3D) -> Vector3:
	return _closest_point_on_target(target, global_position)


## Where the boss looks to face a target: the commander itself, a structure's nearest point.
func _aim_point(target: Node3D) -> Vector3:
	return target.global_position if _is_commander(target) else _structure_aim_point(target)


## Between moves the boss turns toward the point it swings at, not the centre of a big structure.
func _turn_toward_target(delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target) or _is_commander(current_target):
		super._turn_toward_target(delta)
		return
	var look_dir := _structure_aim_point(current_target) - global_position
	look_dir.y = 0.0
	if look_dir.length_squared() > 0.001:
		rotation.y = _turn_limited(rotation.y, atan2(look_dir.x, look_dir.z), delta)


## Turns toward the target: a turn clip for a wide angle, the slow turn between checks otherwise.
func _face_target() -> void:
	if current_target == null or not is_instance_valid(current_target):
		_wait_and_turn()
		return
	var delta_yaw := _yaw_to_point(_aim_point(current_target))
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
	return _yaw_to_point(target.global_position)


## Signed yaw between the boss's facing and a point.
func _yaw_to_point(point: Vector3) -> float:
	var look := point - global_position
	look.y = 0.0
	if look.length_squared() < 0.001:
		return 0.0
	return angle_difference(rotation.y, atan2(look.x, look.z))


## Between moves in CHASE, ADVANCE or WAIT: acts on the AI's pick. True when it changed state.
func _act_while_moving() -> bool:
	if _structure_lock_holds():
		return false
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
	if _structure_lock_holds():
		set_target(_locked_structure)
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


## True when the commander stands in front, inside the slash or where the spit's pool would be.
func _commander_in_reach(cmd: Node3D) -> bool:
	if cdata == null or not is_in_front(cmd):
		return false
	if _in_slash_hitbox(cmd, cdata.body(cdata.slash_range), cdata.slash_arc_deg):
		return true
	return _in_spit_pool(cmd)


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
	s.charge_roll_unlocked = appearance >= cdata.charge_roll_unlock_appearance
	s.dash_unlocked = appearance >= cdata.dash_unlock_appearance
	s.combo_ready = combo_cooldown_left <= 0.0
	s.spit_ready = spit_cooldown_left <= 0.0
	s.roll_ready = roll_cooldown_left <= 0.0
	s.charge_roll_ready = roll_cooldown_left <= 0.0
	s.dash_ready = dash_cooldown_left <= 0.0
	s.dash_front_ready = dash_front_cooldown_left <= 0.0
	s.dash_buff = dash_buff_left > 0.0
	s.recent_turns = recent_turn_count()
	var cmd := _get_valid_commander()
	if cmd == null or is_dead or spawn_grace:
		return s
	s.engaged = _is_engaged(cmd)
	s.in_front = is_in_front(cmd)
	s.in_slash = _in_slash_hitbox(cmd, cdata.body(cdata.slash_range), cdata.slash_arc_deg)
	s.distance = _flat_gap(cmd, global_position)
	s.off_angle_deg = absf(rad_to_deg(_yaw_to(cmd)))
	s.commander_lateral = sin(_yaw_to(cmd))
	s.in_spit_reach = _in_spit_pool(cmd)
	_set_dash_shares(s)
	s.chase_fortress_share = _chase_fortress_share(cmd)
	return s


## Turn clips begun within the last turn_roll_window game seconds.
func recent_turn_count() -> int:
	var count := 0
	for time in _turn_times:
		if time > _ai_clock - cdata.turn_roll_window:
			count += 1
	return count


## Fills in what each dash is worth. Only worked out when that dash could be picked.
func _set_dash_shares(s: CentipedeBrain.Situation) -> void:
	if not (s.engaged and s.dash_unlocked):
		return
	if s.dash_ready and s.distance <= cdata.body(cdata.dash_trigger_reach):
		s.dash_left_share = _dash_side_share(CentipedeBrain.DASH_LEFT)
		s.dash_right_share = _dash_side_share(CentipedeBrain.DASH_RIGHT)
	var in_front_band := s.distance >= cdata.body(cdata.dash_front_min_distance) \
			and s.distance <= cdata.body(cdata.dash_front_max_distance)
	if s.dash_front_ready and s.in_front and not s.in_slash and in_front_band:
		s.dash_front_share = _dash_front_share()


## Flat unit vector of a side dash: the boss's left (its local +X) or its right.
func _dash_direction(action: StringName) -> Vector3:
	var local_x := global_transform.basis.x
	local_x.y = 0.0
	return local_x.normalized() * (1.0 if action == CentipedeBrain.DASH_LEFT else -1.0)


## The wind-up clip of a dash (the model's own).
func _dash_charge_clip(action: StringName) -> StringName:
	match action:
		CentipedeBrain.DASH_LEFT:
			return CLIP_DASH_CHARGE_LEFT
		CentipedeBrain.DASH_RIGHT:
			return CLIP_DASH_CHARGE_RIGHT
	return CLIP_DASH_CHARGE_FRONT


## The leap clip of a dash (built at _ready, without the root bone's travel).
func _dash_leap_clip(action: StringName) -> StringName:
	match action:
		CentipedeBrain.DASH_LEFT:
			return CLIP_DASH_LEFT
		CentipedeBrain.DASH_RIGHT:
			return CLIP_DASH_RIGHT
	return CLIP_DASH_FRONT


## The model's own leap clip, whose root travel moves the body.
func _dash_source_clip(action: StringName) -> StringName:
	match action:
		CentipedeBrain.DASH_LEFT:
			return SOURCE_DASH_CLIPS[0]
		CentipedeBrain.DASH_RIGHT:
			return SOURCE_DASH_CLIPS[1]
	return SOURCE_DASH_CLIPS[2]


## True when the model has both the wind-up and the leap clip of that dash.
func _has_dash_clips(action: StringName) -> bool:
	if anim_player == null:
		return false
	return anim_player.has_animation(_dash_charge_clip(action)) and anim_player.has_animation(_dash_leap_clip(action))


## The leap clip's own root travel on the floor plane at clip_time, in the boss's local space and
## at model scale 1; zero without the clip.
func _dash_root_local(action: StringName, clip_time: float) -> Vector3:
	if anim_player == null:
		return Vector3.ZERO
	var source_name := _dash_source_clip(action)
	if not anim_player.has_animation(source_name):
		return Vector3.ZERO
	var clip := anim_player.get_animation(source_name)
	var track := clip.find_track(RIG_ROOT_TRACK, Animation.TYPE_POSITION_3D)
	if track < 0:
		return Vector3.ZERO
	var position := clip.position_track_interpolate(track, clampf(clip_time, 0.0, clip.length))
	return Vector3(position.x, 0.0, position.z)


## How far the body has moved clip_time seconds into the leap, in the world for a boss facing basis.
func dash_offset(action: StringName, clip_time: float, basis: Basis) -> Vector3:
	var offset := basis * cdata.body_v3(_dash_root_local(action, clip_time)) * cdata.dash_travel_scale
	offset.y = 0.0
	return offset


## Leap clip seconds at which the root has reached its last floor position; the rest of the clip is
## the landing. The whole clip when it has no root travel track.
func _dash_travel_end(action: StringName) -> float:
	var leap_length := _clip_length(_dash_leap_clip(action))
	if anim_player == null:
		return leap_length
	var source_name := _dash_source_clip(action)
	if not anim_player.has_animation(source_name):
		return leap_length
	var clip := anim_player.get_animation(source_name)
	var track := clip.find_track(RIG_ROOT_TRACK, Animation.TYPE_POSITION_3D)
	if track < 0:
		return leap_length
	var count := clip.track_get_key_count(track)
	var last := clip.track_get_key_value(track, count - 1) as Vector3
	var end_time := clip.track_get_key_time(track, count - 1)
	for index in range(count - 2, -1, -1):
		var key := clip.track_get_key_value(track, index) as Vector3
		if absf(key.x - last.x) > 1e-4 or absf(key.z - last.z) > 1e-4:
			break
		end_time = clip.track_get_key_time(track, index)
	return minf(end_time, leap_length)


## Where the leap ends when nothing holds it.
func dash_travel(action: StringName) -> Vector3:
	return dash_offset(action, _clip_length(_dash_leap_clip(action)), global_transform.basis.orthonormalized())


## True when the leap has its clips and neither something solid nor the navmesh's edge is in its way.
func _dash_is_clear(action: StringName) -> bool:
	if not _has_dash_clips(action):
		return false
	var motion := dash_travel(action)
	return not test_move(global_transform, motion) and not _leaves_navmesh(global_position + motion)


## 0 when the side dash is blocked, would leave the navmesh or has no clips, otherwise how much that
## side is worth: the Fortress side counts fully, the side toward where the boss came from only a share.
func _dash_side_share(action: StringName) -> float:
	if not _dash_is_clear(action):
		return 0.0
	var direction := _dash_direction(action)
	var fortress := _get_valid_fortress()
	if fortress == null or in_hazard_trial:
		return 1.0
	var toward_fortress := _flat_direction_to(fortress.global_position)
	var spawn := get_tree().get_first_node_in_group(&"boss_spawn_point") as Node3D
	var toward_spawn := -toward_fortress if spawn == null else _flat_direction_to(spawn.global_position)
	var lean := UtilityBrain.ramp(direction.dot(toward_fortress - toward_spawn), -cdata.dash_side_dot_band, cdata.dash_side_dot_band)
	return lerpf(cdata.dash_spawn_side_share, 1.0, lean)


## How much a chase is worth by where it leads: toward the Fortress counts fully, straight away from it
## only chase_off_fortress_share. 1 when there is no Fortress to measure against.
func _chase_fortress_share(commander: Node3D) -> float:
	var fortress := _get_valid_fortress()
	if fortress == null or in_hazard_trial:
		return 1.0
	var toward_commander := _flat_direction_to(commander.global_position)
	var toward_fortress := _flat_direction_to(fortress.global_position)
	var lean := UtilityBrain.ramp(toward_commander.dot(toward_fortress), -cdata.chase_fortress_band, cdata.chase_fortress_band)
	return lerpf(cdata.chase_off_fortress_share, 1.0, lean)


## 1 when the forward dash can be done, 0 otherwise; it has no Fortress or spawn side.
func _dash_front_share() -> float:
	return 1.0 if _dash_is_clear(CentipedeBrain.DASH_FRONT) else 0.0


func _flat_direction_to(point: Vector3) -> Vector3:
	var offset := point - global_position
	offset.y = 0.0
	return offset.normalized()


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


## Where the poison lands, on the floor, for the boss's facing right now.
func _pool_center_world() -> Vector3:
	return to_global(cdata.body_v3(cdata.pool_center))


## The commander would stand in the pool: the gap from its body to the pool's centre is within the radius.
func _in_spit_pool(target: Node3D) -> bool:
	var offset := target.global_position - _pool_center_world()
	offset.y = 0.0
	return offset.length() - _target_body_radius(target) <= cdata.pool_radius


# --- Running a move ----------------------------------------------------------------------------

func _begin_move(move: StringName, clip: StringName, duration: float) -> void:
	_reset_move(move, duration)
	_play_clip(clip, 0.1, _move_clip_speed)
	move_started.emit(move, clip, duration / _move_clip_speed)


## A move that opens with the roar: the move's own clock and clip start when the roar is over, so
## its hit times stay where the data puts them. The move is announced as the roar plus the move.
## announced_length is what move_started reports for the move when it runs longer than its clock.
func _begin_roared_move(move: StringName, clip: StringName, duration: float, announced_length: float = -1.0) -> void:
	_reset_move(move, duration)
	var roar := _clip_length(CLIP_ROAR)
	_roar_left = roar
	_roar_main_clip = clip
	_play_clip(CLIP_ROAR, 0.1, _move_clip_speed)
	var announced := duration if announced_length < 0.0 else announced_length
	move_started.emit(move, CLIP_ROAR, (roar + announced) / _move_clip_speed)


func _reset_move(move: StringName, duration: float) -> void:
	_move = move
	_move_time = 0.0
	_move_duration = duration
	_windows.clear()
	_clear_combo_step()
	_roar_left = 0.0
	_move_clip_speed = _combo_speed()
	velocity.x = 0.0
	velocity.z = 0.0


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
	var step := delta * _move_clip_speed
	# The roar always plays out: a lost target or a commander out of reach is acted on once it ends.
	if _roar_left > 0.0:
		step = _tick_roar_lead_in(step)
		if _roar_left > 0.0:
			return
	# A roll or a dash, roar included, runs to its own end (distance, time, a wall) even when its
	# target is gone; only the other moves drop with their target.
	if not _runs_to_its_end() and not _has_valid_target():
		stop_attack_sequence()
		_retarget_now()
		return
	if _move == MOVE_COMBO and _should_cancel_combo():
		_cancel_combo()
		return
	# A combo step stops the move's clock: the hit windows wait while the boss walks.
	if _combo_step_index >= 0:
		_tick_combo_step(step)
		return
	_move_time += step
	match _move:
		MOVE_SLASH:
			_tick_windows()
		MOVE_COMBO:
			_tick_combo()
			_tick_windows()
		MOVE_SPIT:
			_tick_spit()
		MOVE_ROLL, MOVE_CHARGE_ROLL:
			_tick_roll(delta, step)
			return
		MOVE_DASH:
			_tick_dash(step)
		MOVE_TURN:
			_tick_turn()
	if _move_time >= _move_duration:
		_finish_move()


## True for the moves the AI never cuts short: the roll, the charge roll and the dash.
func _runs_to_its_end() -> bool:
	return _move == MOVE_ROLL or _move == MOVE_CHARGE_ROLL or _move == MOVE_DASH


func _has_valid_target() -> bool:
	return current_target != null and is_instance_valid(current_target) and _is_target_valid(current_target)


## Runs the roar that opens Spit and Combo: the boss stands still and its eyes warn. Returns the
## part of step left over once the roar is done, which goes to the move itself.
func _tick_roar_lead_in(step: float) -> float:
	var roar := _clip_length(CLIP_ROAR)
	_roar_left -= step
	_tick_roar_fx(roar - maxf(_roar_left, 0.0))
	if _roar_left > 0.0:
		return 0.0
	var left_over := -_roar_left
	_roar_left = 0.0
	if _fx != null:
		_fx.set_eye_glow(0.0)
		_fx.set_eye_sparks(false)
		if _move == MOVE_COMBO:
			_fx.play_slash(VFX_COMBO, _move_clip_speed)
	_play_clip(_roar_main_clip, 0.1, _move_clip_speed)
	return left_over


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
	if finished == MOVE_DASH:
		_land_on_navmesh()
		if _dash_action != CentipedeBrain.DASH_FRONT:
			dash_buff_left = cdata.dash_buff_time
	move_finished.emit(finished)
	_recovery_left = _recovery_after(finished, was_structure_move, real_duration)


## Pause after a move: the opening to hit back. A structure is hit on the attack interval.
func _recovery_after(finished: StringName, on_structure: bool, real_duration: float) -> float:
	var speed := _combo_speed()
	match finished:
		MOVE_TURN:
			return 0.0
		MOVE_DASH:
			return cdata.dash_recovery / speed
		MOVE_SLASH:
			if on_structure:
				return maxf(cdata.attack_recovery / speed, _get_attack_interval() - real_duration)
			return cdata.attack_recovery / speed
	if finished == MOVE_COMBO_CANCEL:
		return cdata.combo_cancel_recovery / speed
	return cdata.heavy_attack_recovery / speed


func _clear_move_state() -> void:
	_move = &""
	_move_time = 0.0
	_windows.clear()
	_structure_move = false
	_roll_phase = RollPhase.NONE
	_roll_hit.clear()
	_roll_charge = false
	_roar_left = 0.0
	_spit_emitting = false
	_clear_combo_step()


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
	if _roar_left > 0.0:
		return true
	# The dash moves the body itself (move_and_collide), so its velocity stays locked like any move.
	return is_in_attack_state() and _move != MOVE_ROLL and _move != MOVE_CHARGE_ROLL \
			and _move != MOVE_COMBO


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

## LA3 when it is off cooldown and the target is dead ahead, otherwise LA1 for the right half and
## LA2 for the left.
func _pick_slash_clip(target: Node3D) -> StringName:
	var heavy_ready := la3_cooldown_left <= 0.0
	if target == null or not is_instance_valid(target):
		return CLIP_SLASH_3 if heavy_ready else CLIP_SLASH_1
	if heavy_ready and absf(rad_to_deg(_yaw_to(target))) <= cdata.slash_center_deg:
		return CLIP_SLASH_3
	var local := to_local(target.global_position)
	return CLIP_SLASH_1 if local.x < 0.0 else CLIP_SLASH_2


func _begin_slash(clip: StringName) -> void:
	_structure_move = not _is_commander(current_target)
	_begin_move(MOVE_SLASH, clip, _clip_length(clip))
	var heavy := clip == CLIP_SLASH_3
	if heavy:
		la3_cooldown_left = cdata.la3_cooldown
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
	_begin_roared_move(MOVE_COMBO, CLIP_COMBO, _clip_length(CLIP_COMBO), _combo_planned_length())
	var spans := cdata.combo_hit_windows
	for i in spans.size():
		var finisher := i == spans.size() - 1
		var damage := cdata.combo_finisher_damage if finisher else cdata.combo_hit_damage
		var knockback := cdata.combo_finisher_knockback if finisher else 0.0
		var arc := cdata.combo_finisher_arc_deg if finisher else cdata.combo_arc_deg
		_windows.append(_new_window(spans[i], damage, knockback, cdata.body(cdata.combo_range), arc))
	# The slash trails start with the combo's own clip, once the roar is over (see _tick_roar_lead_in).


## Clip seconds the combo takes with its steps: the clip, minus the spans it skips, plus the steps.
func _combo_planned_length() -> float:
	var length := _clip_length(CLIP_COMBO)
	for span in cdata.combo_move_windows:
		length += cdata.combo_step_time - (span.y - span.x)
	return length


## Stops the combo clip at the start of the next step span and begins the step.
func _tick_combo() -> void:
	var spans := cdata.combo_move_windows
	if _combo_steps_done >= spans.size() or _move_time < spans[_combo_steps_done].x:
		return
	_move_time = spans[_combo_steps_done].x
	_begin_combo_step(_combo_steps_done)


func _begin_combo_step(index: int) -> void:
	_combo_step_index = index
	_combo_step_left = cdata.combo_step_time
	if anim_player != null and anim_player.has_animation(CLIP_WALK):
		var ground_speed := cdata.body(cdata.combo_move_speed) * _move_clip_speed
		anim_player.speed_scale = clampf(ground_speed / cdata.body(cdata.walk_anim_base_speed), 0.0, cdata.walk_anim_max_scale)
		anim_player.play(CLIP_WALK, COMBO_STEP_BLEND)
	if _fx != null:
		_fx.detach_slash()


## One tick of a step (step in clip seconds): turns toward the target, then walks the way the body
## now faces. The step ends when its time is up, or when the target is near, or the floor or a wall
## stops the walk, and the body already faces the target.
func _tick_combo_step(step: float) -> void:
	step = minf(step, _combo_step_left)
	_combo_step_left -= step
	var stopped := _step_forward(step)
	if stopped or _combo_step_left <= 0.0:
		_end_combo_step()


## One step of the combo's walk: always turns toward the target first (limited by the step turn
## rate), then walks unless the target is near. True when the walk is over: the target is near or
## something blocks the way, and the body faces the target within the step face tolerance. Until
## then the body keeps turning in place.
func _step_forward(step: float) -> bool:
	var max_turn := deg_to_rad(cdata.combo_step_turn_rate_deg) * step
	rotation.y += clampf(_yaw_to_point(_aim_point(current_target)), -max_turn, max_turn)
	var faced := absf(_yaw_to_point(_aim_point(current_target))) <= deg_to_rad(cdata.combo_step_face_tolerance_deg)
	var stop_gap := cdata.body(cdata.combo_step_stop_gap)
	if _flat_gap(current_target, global_position) <= stop_gap:
		return faced
	var motion := _combo_forward() * cdata.body(cdata.combo_move_speed) * step
	if _leaves_navmesh(global_position + motion):
		return faced
	if _move_body(motion):
		return faced
	return faced and _flat_gap(current_target, global_position) <= stop_gap


## Back to the combo clip, where the skipped span ends, and the trails with it.
func _end_combo_step() -> void:
	var resume_time := cdata.combo_move_windows[_combo_step_index].y
	_combo_step_index = -1
	_combo_step_left = 0.0
	_combo_steps_done += 1
	_move_time = resume_time
	if anim_player != null and anim_player.has_animation(CLIP_COMBO):
		anim_player.speed_scale = _move_clip_speed
		anim_player.play(CLIP_COMBO, COMBO_STEP_BLEND)
		anim_player.seek(resume_time, true)
	if _fx != null:
		_fx.resume_slash(resume_time, _move_clip_speed)


func _clear_combo_step() -> void:
	_combo_step_index = -1
	_combo_step_left = 0.0
	_combo_steps_done = 0


## The commander is out of reach and no hit window is open (the swing in progress always lands).
func _should_cancel_combo() -> bool:
	for window in _windows:
		if not window.closed and _move_time >= window.start and _move_time <= window.end:
			return false
	return _flat_gap(current_target, global_position) > cdata.body(cdata.combo_cancel_distance)


## Drops the combo for a short pull-back to rest. Hit windows that did not run never report, and
## the combo's cooldown keeps counting from when it began.
func _cancel_combo() -> void:
	_windows.clear()
	if _fx != null:
		_fx.stop_all()
	_set_ribs_close(0.0)
	_set_lean(0.0)
	_reset_move(MOVE_COMBO_CANCEL, cdata.combo_cancel_time)
	var length := cdata.combo_cancel_time / _move_clip_speed
	_play_idle(length)
	move_started.emit(MOVE_COMBO_CANCEL, CLIP_IDLE, length)


# --- Spit --------------------------------------------------------------------------------------

func _begin_spit() -> void:
	_spit_pool_spawned = false
	_spit_next_tick = cdata.spit_stream_start + cdata.spit_stream_tick
	_begin_roared_move(MOVE_SPIT, CLIP_SPIT, _clip_length(CLIP_SPIT) + cdata.spit_stream_duration)
	# The warning starts with the roar, so it runs for the roar and then the time to the pool.
	EventBus.telegraph_started.emit(&"poison", _pool_center_world(), cdata.pool_radius,
			(_clip_length(CLIP_ROAR) + cdata.pool_spawn_time) / _move_clip_speed)


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


## The stream reaches the far edge of the pool.
func _spit_stream_reach(apex: Vector3) -> float:
	var to_pool := _pool_center_world() - apex
	to_pool.y = 0.0
	return to_pool.length() + cdata.pool_radius


func _in_spit_cone(target: Node3D, apex: Vector3) -> bool:
	var offset := _closest_point_on_target(target, apex) - apex
	offset.y = 0.0
	if offset.length() - _target_body_radius(target) > _spit_stream_reach(apex):
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
	pool.global_position = _pool_center_world()
	pool.rotation.y = rotation.y


# --- Roll --------------------------------------------------------------------------------------

func _begin_roll() -> void:
	_roll_charge = false
	_start_roll_frame(MOVE_ROLL)


## The roll that homes in: same frame as the roll, with its own speed, turn rate, damage and end.
func _begin_charge_roll() -> void:
	_roll_charge = true
	_start_roll_frame(MOVE_CHARGE_ROLL)


func _start_roll_frame(move: StringName) -> void:
	_roll_phase = RollPhase.ROAR
	_roll_phase_time = 0.0
	_roll_loop_time = 0.0
	_roll_after_hit_left = -1.0
	_roll_speed = 0.0
	_roll_distance = 0.0
	_roll_blocked_time = 0.0
	_roll_hit.clear()
	_begin_move(move, CLIP_ROAR, _clip_length(CLIP_ROAR))


## Fastest ground speed of the running roll, in metres per second of the lane.
func _roll_cap() -> float:
	return cdata.charge_roll_speed_cap if _roll_charge else cdata.roll_speed_cap


func _roll_turn_rate_rad() -> float:
	return deg_to_rad(cdata.charge_roll_turn_rate_deg if _roll_charge else cdata.roll_turn_rate_deg)


func _roll_damage() -> int:
	return cdata.charge_roll_damage if _roll_charge else cdata.roll_damage


func _enter_roll_phase(phase: RollPhase) -> void:
	_roll_phase = phase
	_roll_phase_time = 0.0
	match phase:
		RollPhase.START:
			_play_clip(CLIP_ROLL_START, 0.1, _move_clip_speed)
			if _fx != null:
				_fx.set_eye_glow(0.0)
				_fx.set_eye_sparks(false)
		RollPhase.LOOP:
			_play_clip(CLIP_ROLL_LOOP, 0.1, 1.0)
		RollPhase.END:
			_roll_end_speed = _roll_speed
			_play_clip(CLIP_ROLL_END, 0.1, _move_clip_speed)


## Top ground speed of the roll right now: the clip's own speed, held down to the lane's cap (a
## big boss would otherwise cross the lane in a blink). The clip plays slower by the difference.
func _roll_full_speed() -> float:
	return _roll_top_speed() * get_slow_factor()


## The roll's top speed before a slow is applied; the speed lines are measured against it.
func _roll_top_speed() -> float:
	return minf(cdata.body(cdata.roll_speed), _roll_cap()) * speed_multiplier


func _tick_roll(delta: float, step: float) -> void:
	_roll_phase_time += step
	if (_roll_phase == RollPhase.START or _roll_phase == RollPhase.LOOP) and _after_hit_run_over(delta):
		_enter_roll_phase(RollPhase.END)
	match _roll_phase:
		RollPhase.ROAR:
			_tick_roar_fx(_roll_phase_time)
			if _roll_phase_time >= _clip_length(CLIP_ROAR):
				_enter_roll_phase(RollPhase.START)
		RollPhase.START:
			_roll_speed = _roll_start_speed()
			_roll_travel(delta, true)
			if _roll_phase_time >= _clip_length(CLIP_ROLL_START):
				_enter_roll_phase(RollPhase.LOOP)
		RollPhase.LOOP:
			_roll_loop_time += delta
			_roll_speed = _roll_full_speed()
			_roll_travel(delta, true)
			_set_roll_clip_speed()
			if _roll_loop_over():
				_enter_roll_phase(RollPhase.END)
		RollPhase.END:
			var slide := maxf(0.001, cdata.roll_end_slide_time)
			_roll_speed = _roll_end_speed * (1.0 - clampf(_roll_phase_time / slide, 0.0, 1.0))
			_roll_travel(delta, false)
			_tick_end_glow()
			if _roll_phase_time >= _clip_length(CLIP_ROLL_END):
				_finish_roll()
	if _fx != null and _roll_phase != RollPhase.ROAR:
		var share := _roll_speed / maxf(0.001, _roll_top_speed())
		_fx.set_speed_lines(clampf(share, 0.0, 1.0))


## The eyes light up and spark during the roar (time_in_roar seconds in): the warning before a move.
func _tick_roar_fx(time_in_roar: float) -> void:
	if _fx == null:
		return
	_fx.set_eye_glow(clampf(time_in_roar / maxf(0.001, _fx.eye_glow_rise_time), 0.0, 1.0))
	_fx.set_eye_sparks(time_in_roar >= _fx.eye_sparks_delay)


## Stands still for the first moments of the start clip, then eases up to full speed.
func _roll_start_speed() -> float:
	var length := _clip_length(CLIP_ROLL_START)
	var progress := (_roll_phase_time - ROLL_START_STILL_TIME) / maxf(0.001, length - ROLL_START_STILL_TIME)
	return _roll_full_speed() * smoothstep(0.0, 1.0, progress)


## The clip's playback follows the ground speed, so the body does not slip.
func _set_roll_clip_speed() -> void:
	if anim_player != null:
		anim_player.speed_scale = _roll_speed / maxf(0.001, cdata.body(cdata.roll_speed))


## The Charge Roll runs for a time, then ends; the roll runs for a distance.
func _roll_loop_over() -> bool:
	if _roll_charge:
		return _roll_loop_time >= cdata.charge_roll_loop_time
	return _roll_covers_max_distance()


## The roll ends when the distance it still slides is all that is left of the maximum.
func _roll_covers_max_distance() -> bool:
	var slide := _roll_speed * cdata.roll_end_slide_time * 0.5
	return _roll_distance + slide >= cdata.body(cdata.roll_max_distance)


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
	_move_body(motion)
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


## Bends the roll toward the commander at the roll's turn rate and leans the body into the turn.
## A Charge Roll that has landed its hit goes straight on.
func _steer_roll(delta: float) -> void:
	var target := current_target
	if not _has_valid_target() or _roll_after_hit_left >= 0.0:
		_set_lean_toward(0.0, delta)
		return
	var max_step := _roll_turn_rate_rad() * delta
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
			if _strike_target(target, _roll_damage(), cdata.roll_knockback, Enums.DamageType.BLAST, _roll_throw_direction(target)):
				_roll_hit.append(target)
				_start_after_hit_run()
			continue
		_roll_hit.append(target)
		_strike_target(target, _roll_damage(), 0.0, Enums.DamageType.BLAST)
		if _roll_phase != RollPhase.END:
			_enter_roll_phase(RollPhase.END)


## The Charge Roll stops bending after it hit the commander and ends shortly after.
func _start_after_hit_run() -> void:
	if not _roll_charge or _roll_after_hit_left >= 0.0:
		return
	_roll_after_hit_left = cdata.charge_roll_after_hit_time


## Counts the Charge Roll's run after its hit down; true once it is over.
func _after_hit_run_over(delta: float) -> bool:
	if _roll_after_hit_left < 0.0:
		return false
	_roll_after_hit_left = maxf(0.0, _roll_after_hit_left - delta)
	return _roll_after_hit_left <= 0.0


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
	_land_on_navmesh()
	_finish_move()


# --- Dash --------------------------------------------------------------------------------------

## A leap, sideways or straight ahead; action is CentipedeBrain.DASH_LEFT, DASH_RIGHT or DASH_FRONT.
## The wind-up clip plays first with the boss standing still (the warning), then the leap clip
## carries the body. A side dash then weights the next moves up for dash_buff_time (see
## CentipedeBrain); the forward one does not. The sides share one cooldown, the forward dash has its own.
func _begin_dash(action: StringName) -> void:
	last_chosen_move = MOVE_DASH
	if action == CentipedeBrain.DASH_FRONT:
		dash_front_cooldown_left = cdata.dash_front_cooldown
	else:
		dash_cooldown_left = cdata.dash_cooldown
	_dash_action = action
	_dash_basis = global_transform.basis.orthonormalized()
	_dash_offset = Vector3.ZERO
	_dash_leaping = false
	_dash_stopped = false
	var charge := _dash_charge_clip(action)
	_dash_charge_length = _clip_length(charge)
	_dash_travel_end_time = _dash_travel_end(action)
	var leap_length := _clip_length(_dash_leap_clip(action))
	_reset_move(MOVE_DASH, _dash_charge_length + minf(leap_length, _dash_travel_end_time + cdata.dash_land_time))
	_play_clip(charge, 0.1, _move_clip_speed)
	move_started.emit(MOVE_DASH, charge, _move_duration / _move_clip_speed)


## Stands still through the wind-up, then moves the body by the leap clip's own travel, so the
## pose and the body stay together. A wall, a structure (whatever the contact normal) or the
## navmesh's edge stops the body for good; the clip still plays to its end. A step that would lift
## the body is undone (see _move_body). A forward leap also stops short of the commander.
func _tick_dash(step: float) -> void:
	if _move_time < _dash_charge_length:
		return
	var leap_time := _move_time - _dash_charge_length
	if not _dash_leaping:
		_dash_leaping = true
		_play_clip(_dash_leap_clip(_dash_action), 0.0, _move_clip_speed)
		anim_player.seek(leap_time, true)
	if leap_time < _dash_travel_end_time:
		_turn_in_air(step)
	var target := dash_offset(_dash_action, leap_time, _dash_basis)
	var motion := target - _dash_offset
	_dash_offset = target
	if _dash_stopped or motion.length_squared() < 1e-8:
		return
	if _leaves_navmesh(global_position + motion) or _dash_would_overlap_commander(motion):
		_dash_stopped = true
		return
	if _move_body(motion):
		_dash_stopped = true


## Turns the face toward the commander while airborne; the path keeps the take-off basis. A turn
## that would put the body into something else is skipped, since the physics would shove it out upward.
func _turn_in_air(step: float) -> void:
	var cmd := _get_valid_commander()
	if cmd == null:
		return
	var max_turn := deg_to_rad(cdata.dash_air_turn_rate_deg) * step
	var turn := clampf(_yaw_to_point(cmd.global_position), -max_turn, max_turn)
	if _body_overlaps(global_transform.rotated_local(Vector3.UP, turn)):
		return
	rotation.y += turn


## Moves the body by motion for a move that carries it (dash, combo step, roll). True when
## something holds it: a structure, whatever the side it touches, or a wall. A step that lifts the
## body is undone, because the body was pushed up onto a lower obstacle instead of stopped by it.
func _move_body(motion: Vector3) -> bool:
	var before := global_position
	var hit := move_and_collide(motion)
	if global_position.y > before.y + BODY_RISE_TOLERANCE:
		global_position = before
		return true
	if hit == null:
		return false
	if _is_structure_body(hit.get_collider()):
		return true
	return absf(hit.get_normal().y) < DASH_WALL_NORMAL_Y


## A tower, a Barricade or the Fortress: the body never climbs onto any of them.
func _is_structure_body(node: Object) -> bool:
	var structure := node as Node
	if structure == null:
		return false
	return structure.is_in_group(&"tower") or structure.is_in_group(&"barricade") or structure.is_in_group(&"fortress")


## True when the body's box, placed at xform, overlaps anything of the boss's mask (other than the floor under it).
func _body_overlaps(xform: Transform3D) -> bool:
	if _body_shape == null or _body_shape.shape == null or not is_inside_tree():
		return false
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _body_shape.shape
	params.transform = xform * _body_shape.transform
	params.transform.origin.y += OVERLAP_FLOOR_CLEARANCE
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	params.collide_with_areas = false
	return not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## After a dash or roll: when the body ended higher than the navmesh surface, or off it, puts it
## back on the navmesh's nearest point (height included).
func _land_on_navmesh() -> void:
	if not _has_navmesh():
		return
	var closest := NavigationServer3D.map_get_closest_point(nav.get_navigation_map(), global_position)
	var flat_gap := Vector2(closest.x - global_position.x, closest.z - global_position.z).length()
	if flat_gap <= NAVMESH_SNAP_DISTANCE and global_position.y - closest.y <= LANDING_HEIGHT_TOLERANCE:
		return
	global_position = closest
	velocity = Vector3.ZERO


## A forward leap must not carry the boss onto the commander (the boss's mask does not hold it back).
func _dash_would_overlap_commander(motion: Vector3) -> bool:
	if _dash_action != CentipedeBrain.DASH_FRONT:
		return false
	var cmd := _get_valid_commander()
	if cmd == null:
		return false
	return _flat_gap(cmd, global_position + motion) < cdata.body(cdata.body_box_size.z * 0.5)


# --- Turn --------------------------------------------------------------------------------------

## Plays the turn clip that fits delta_yaw; the boss turns by exactly that, in step with the clip's feet.
func _begin_turn(delta_yaw: float) -> void:
	_record_turn()
	var clip := CLIP_TURN_180
	if absf(rad_to_deg(delta_yaw)) <= cdata.turn_half_clip_deg:
		clip = CLIP_TURN_LEFT if delta_yaw > 0.0 else CLIP_TURN_RIGHT
	var source_name := StringName(String(clip).trim_prefix("runtime/"))
	_turn_table = _turn_tables.get(source_name, PackedFloat32Array())
	_turn_start_yaw = rotation.y
	_turn_yaw_delta = delta_yaw
	_begin_move(MOVE_TURN, clip, _clip_length(clip))


## Remembers a turn clip's start, and forgets the ones that left the window.
func _record_turn() -> void:
	var kept := PackedFloat32Array()
	for time in _turn_times:
		if time > _ai_clock - cdata.turn_roll_window:
			kept.append(time)
	kept.append(_ai_clock)
	_turn_times = kept


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
