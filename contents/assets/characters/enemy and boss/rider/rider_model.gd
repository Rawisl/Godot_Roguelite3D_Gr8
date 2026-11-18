extends Node3D
## Rider: a skeleton sitting on the horse.
## - The rider's AnimationPlayer only keeps the sitting and melee clips, so the unit code can
##   never stand it up to walk; its EnemyData sets anim_walk to the sitting clip. After an attack
##   it sits back down.
## - The horse has its own rig and one clip, Walk: it plays while the model moves, faster when
##   the model moves faster, and stops with the legs straight when the model stands still.
## - The rider rides the horse's body bone, so it rises and falls with the horse's steps.
## The rider's player comes first in the tree, so a unit looking for "AnimationPlayer" finds it.

@export var sit_clip: StringName = &"simulation/Sit_Chair_Idle"
## Clip libraries the rider keeps; the walking and standing ones it inherits from the Brute are
## dropped, so nothing can make it stand up on the horse.
@export var kept_libraries: Array[StringName] = [&"simulation", &"melee"]
@export var walk_clip: StringName = &"Walk"
## Speed (m/s) at which the Walk clip plays at its own pace.
@export var walk_speed := 2.5
## Speed (m/s) under which the horse counts as standing.
@export var still_speed := 0.2

var _last := Vector3.ZERO
var _walking := false
var _rider_rest_y := 0.0
var _body_rest_y := 0.0
var _body_bone := -1

@onready var _rider: Node3D = $Mount/Rider
@onready var _player: AnimationPlayer = _rider.find_child("AnimationPlayer", true, false) as AnimationPlayer
@onready var _horse_player: AnimationPlayer = $Mount/Horse.find_child("AnimationPlayer", true, false) as AnimationPlayer
@onready var _horse_skeleton: Skeleton3D = $Mount/Horse.find_child("Skeleton3D", true, false) as Skeleton3D


func _ready() -> void:
	_last = global_position
	_rider_rest_y = _rider.position.y
	if _player != null:
		for lib in _player.get_animation_library_list():
			if not lib in kept_libraries:
				_player.remove_animation_library(lib)
		if _player.has_animation(sit_clip):
			_player.get_animation(sit_clip).loop_mode = Animation.LOOP_LINEAR
			_player.play(sit_clip)
			_player.animation_finished.connect(_back_to_sitting)
	if _horse_player != null and _horse_player.has_animation(walk_clip):
		_horse_player.get_animation(walk_clip).loop_mode = Animation.LOOP_LINEAR
	if _horse_skeleton != null:
		_body_bone = _horse_skeleton.find_bone("body")
		if _body_bone >= 0:
			_body_rest_y = _horse_skeleton.get_bone_rest(_body_bone).origin.y


## After an attack clip the rider sits back down.
func _back_to_sitting(_clip: StringName) -> void:
	if _player.has_animation(sit_clip):
		_player.play(sit_clip, 0.2)


func is_walking() -> bool:
	return _walking


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var moved := Vector2(global_position.x - _last.x, global_position.z - _last.z).length()
	_last = global_position
	var speed := moved / delta
	var walk := speed > still_speed
	if _horse_player != null and _horse_player.has_animation(walk_clip):
		if walk:
			if not _walking:
				_horse_player.play(walk_clip)
			_horse_player.speed_scale = clampf(speed / walk_speed, 0.4, 2.5)
		elif _walking:
			_horse_player.stop()
			if _horse_skeleton != null:
				_horse_skeleton.reset_bone_poses()
	_walking = walk
	# The rider follows the rise and fall of the horse's body bone.
	if _horse_skeleton != null and _body_bone >= 0:
		var lift := _horse_skeleton.get_bone_pose_position(_body_bone).y - _body_rest_y
		_rider.position.y = _rider_rest_y + lift * _horse_skeleton.global_basis.get_scale().y / maxf(global_basis.get_scale().y, 0.001)
