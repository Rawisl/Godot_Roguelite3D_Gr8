extends Node3D
## Rider: a skeleton sitting on the horse.
## - The rider's AnimationPlayer only keeps the sitting and melee clips, so the unit code can
##   never stand it up to walk; its EnemyData sets anim_walk to the sitting clip. After an attack
##   it sits back down.
## - The horse has its own rig and two clips: Walk (a diagonal walk) while the model moves slowly
##   and Run (a four-beat gallop) above run_threshold, each scaled to the speed, with a short blend
##   between them. Standing still it stops with the legs straight. The speed is smoothed and the
##   switch has some room between going up and coming down, so it does not flicker between gaits.
## - The rider rides the horse's body bone (lift and pitch), so it moves with the horse's steps.
## - Death: the unit plays the rider's Death_B. It is a copy of the skeleton's Death_B without
##   the hip and root movement and without the leg tracks, so the rider slumps but stays seated.
##   When it starts, the horse plays Fall (it kneels forward) and stops walking. Just before the
##   rider slumps (death_tip_start into the clip) the horse tips over to its right, pivoting on
##   its right side at the ground. The rider comes off: it does not turn with the horse but drops,
##   upright as its own clip has it, to the ground beside the fallen horse.
## The rider's player comes first in the tree, so a unit looking for "AnimationPlayer" finds it.

@export var sit_clip: StringName = &"simulation/Sit_Chair_Idle"
## Clip libraries the rider keeps; the walking and standing ones it inherits from the Brute are
## dropped, so nothing can make it stand up on the horse.
@export var kept_libraries: Array[StringName] = [&"simulation", &"melee", &""]
## Death clip copied from the skeleton's general library before that library is dropped; the
## unit code looks it up as "Death_B".
@export var death_clip: StringName = &"Death_B"
@export var general_library: AnimationLibrary = preload("res://contents/assets/characters/additional animations/Animations/gltf/Rig_Medium/Rig_Medium_General.glb")
@export var fall_clip: StringName = &"Fall"
## On death the rider slides this far back on the saddle (towards the tail), over death_slide_time.
@export var death_slide_back := 0.25
@export var death_slide_time := 0.6
## Seconds into the death clip when the horse starts to tip over: Death_B slumps from about 1.4 s.
@export var death_tip_start := 1.3
## Seconds the tip takes; it speeds up like a fall.
@export var death_tip_time := 0.5
@export_range(0.0, 90.0) var death_tip_angle := 82.0
## Distance from the horse's centre line to its right side at the ground, the tip's pivot.
@export var death_tip_pivot := 0.45
## Where the rider lands, from the horse's centre line: this far to the horse's right, with its
## hips this high off the ground. The fallen horse's back reaches about 1.85 m to that side by
## the saddle, so 2.5 m keeps the rider clear of it.
@export var death_land_side := 2.5
@export var death_land_hips := 0.25
@export var walk_clip: StringName = &"Walk"
@export var run_clip: StringName = &"Run"
## Speed (m/s) at which the Walk clip plays at its own pace.
@export var walk_speed := 2.5
## Speed (m/s) at which the Run clip plays at its own pace.
@export var run_speed := 5.5
## Speed (m/s) above which the horse gallops; it walks again under run_threshold - run_hysteresis.
@export var run_threshold := 3.6
@export var run_hysteresis := 0.6
## Seconds to blend from one gait to the other.
@export var gait_blend := 0.15
## Speed (m/s) under which the horse counts as standing.
@export var still_speed := 0.2

var _last := Vector3.ZERO
var _walking := false
var _gait: StringName = &""
var _dead := false
var _death_time := 0.0
var _rider_rest := Transform3D.IDENTITY
var _mount_rest := Transform3D.IDENTITY
## Height of the rider's hips above its own origin, in the mount's frame (set once at start).
var _hips_height := 0.45
var _speed := 0.0
var _body_bone := -1

@onready var _rider: Node3D = %Rider
@onready var _player: AnimationPlayer = _rider.find_child("AnimationPlayer", true, false) as AnimationPlayer
@onready var _horse_player: AnimationPlayer = %Horse.find_child("AnimationPlayer", true, false) as AnimationPlayer
@onready var _horse_skeleton: Skeleton3D = %Horse.find_child("Skeleton3D", true, false) as Skeleton3D


func _ready() -> void:
	_last = global_position
	_rider_rest = _rider.transform
	_mount_rest = (_rider.get_parent() as Node3D).transform
	var rider_skel := _rider.find_child("Skeleton3D", true, false) as Skeleton3D
	if rider_skel != null and rider_skel.find_bone("hips") >= 0:
		var to_mount := _rider.transform.affine_inverse() * (_rider.get_parent() as Node3D).global_transform.affine_inverse() * rider_skel.global_transform
		_hips_height = (_rider.transform.basis * (to_mount * rider_skel.get_bone_global_rest(rider_skel.find_bone("hips"))).origin).y
	if _player != null:
		_add_seated_death()
		for lib in _player.get_animation_library_list():
			if not lib in kept_libraries:
				_player.remove_animation_library(lib)
		if _player.has_animation(sit_clip):
			_player.get_animation(sit_clip).loop_mode = Animation.LOOP_LINEAR
			_player.play(sit_clip)
			_player.animation_finished.connect(_back_to_sitting)
		_player.animation_started.connect(_on_rider_clip_started)
	if _horse_player != null:
		for clip in [walk_clip, run_clip]:
			if _horse_player.has_animation(clip):
				_horse_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if _horse_skeleton != null:
		_body_bone = _horse_skeleton.find_bone("body")


## A copy of the skeleton's death clip that keeps the rider on the saddle: no hip or root
## movement and no leg tracks, so the legs keep the sitting pose while the body slumps.
func _add_seated_death() -> void:
	if general_library == null or not general_library.has_animation(death_clip):
		return
	var death := general_library.get_animation(death_clip).duplicate(true) as Animation
	for i in range(death.get_track_count() - 1, -1, -1):
		var bone := String(death.track_get_path(i)).get_slice(":", 1)
		var moves := death.track_get_type(i) == Animation.TYPE_POSITION_3D and bone in ["hips", "root"]
		var leg := bone.begins_with("upperleg") or bone.begins_with("lowerleg") or bone.begins_with("foot") or bone.begins_with("toes")
		if moves or leg:
			death.remove_track(i)
	death.loop_mode = Animation.LOOP_NONE
	var lib: AnimationLibrary
	if _player.has_animation_library(&""):
		lib = _player.get_animation_library(&"")
	else:
		lib = AnimationLibrary.new()
		_player.add_animation_library(&"", lib)
	lib.add_animation(death_clip, death)


func _on_rider_clip_started(clip: StringName) -> void:
	if clip != death_clip or _dead:
		return
	_dead = true
	if _horse_player != null and _horse_player.has_animation(fall_clip):
		_horse_player.speed_scale = 1.0
		_horse_player.play(fall_clip, 0.1)


func is_dead() -> bool:
	return _dead


## Tips horse and rider over to the horse's right (-X, as it faces +Z), around its right side on
## the ground, starting just before the rider slumps.
func _tip_over() -> void:
	var p := clampf((_death_time - death_tip_start) / maxf(death_tip_time, 0.001), 0.0, 1.0)
	var angle := deg_to_rad(death_tip_angle) * p * p
	var pivot := Vector3(-death_tip_pivot, 0.0, 0.0)
	var mount := _rider.get_parent() as Node3D
	mount.transform = (Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)
		* Transform3D(Basis.IDENTITY, -pivot) * _mount_rest)


## Once the horse tips, the rider comes off: it keeps its own upright turn (the mount's tip is
## undone for it) and falls from the saddle to the ground beside the horse, speeding up.
func _drop_rider() -> void:
	var p := clampf((_death_time - death_tip_start) / maxf(death_tip_time, 0.001), 0.0, 1.0)
	if p <= 0.0:
		return
	var mount := _rider.get_parent() as Node3D
	# Where the rider sits now, seen from the mount's untipped frame.
	var seat := _mount_rest.affine_inverse() * mount.transform * _rider.transform
	var hips_above_origin := _hips_height
	var land := Transform3D(_rider_rest.basis, Vector3(-death_land_side, death_land_hips - hips_above_origin, seat.origin.z))
	var placed := seat.interpolate_with(land, p * p)
	_rider.transform = mount.transform.affine_inverse() * _mount_rest * placed


## The angle the mount has tipped over so far, in degrees.
func get_tip_degrees() -> float:
	var mount := _rider.get_parent() as Node3D
	return rad_to_deg(mount.transform.basis.get_euler().z)


## After an attack clip the rider sits back down; never after its death.
func _back_to_sitting(_clip: StringName) -> void:
	if _dead:
		return
	if _player.has_animation(sit_clip):
		_player.play(sit_clip, 0.2)


func is_walking() -> bool:
	return _walking


## The clip the horse plays now: the walk or run clip, or empty while it stands.
func get_gait() -> StringName:
	return _gait


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var moved := Vector2(global_position.x - _last.x, global_position.z - _last.z).length()
	_last = global_position
	if _dead:
		_death_time += delta
		_follow_body()
		_tip_over()
		_drop_rider()
		return
	# Smoothed over about a tenth of a second, so one uneven frame does not change the gait.
	_speed = lerpf(_speed, moved / delta, clampf(delta * 10.0, 0.0, 1.0))
	var walk := _speed > still_speed
	if _horse_player != null and _horse_player.has_animation(walk_clip):
		if walk:
			var running := _gait == run_clip
			var run := _horse_player.has_animation(run_clip) and (_speed > run_threshold or (running and _speed > run_threshold - run_hysteresis))
			var gait := run_clip if run else walk_clip
			if gait != _gait:
				_horse_player.play(gait, gait_blend if _walking else 0.0)
				_gait = gait
			var pace := run_speed if run else walk_speed
			_horse_player.speed_scale = clampf(_speed / pace, 0.4, 2.5)
		elif _walking:
			_horse_player.stop()
			_gait = &""
			if _horse_skeleton != null:
				_horse_skeleton.reset_bone_poses()
	_walking = walk
	_follow_body()


## The rider follows the horse's body bone: its lift on every step and its pitch when it kneels.
func _follow_body() -> void:
	if _horse_skeleton == null or _body_bone < 0:
		return
	var delta := _horse_skeleton.get_bone_global_pose(_body_bone) * _horse_skeleton.get_bone_global_rest(_body_bone).affine_inverse()
	var mount := _rider.get_parent() as Node3D
	var skel_in_mount := mount.global_transform.affine_inverse() * _horse_skeleton.global_transform
	var seat := _rider_rest
	if _dead:
		# The horse faces +Z, so back on the saddle is -Z.
		var slide := death_slide_back * smoothstep(0.0, 1.0, _death_time / maxf(death_slide_time, 0.001))
		seat = seat.translated(Vector3(0.0, 0.0, -slide))
	_rider.transform = skel_in_mount * delta * skel_in_mount.affine_inverse() * seat
