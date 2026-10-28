class_name TurretTowerModel
extends Node3D
## Rigged tower model (cannon, ballista) that turns toward the tower's target.
## - Shows Level1, Level2 or Level3 to match Tower.level (the LVL_1, LVL_2 and LVL_4 meshes).
## - Turns yaw_bone around the vertical axis and tilts pitch_bone up or down, so the barrel or
##   the bolt points where the shot goes.
## - Puts a muzzle marker at the tip of the barrel or bolt and hands it to the Tower, so
##   projectiles leave from the right place at every level and angle.
## Reads Tower.target only; the Tower's own aim node is not used (aim_node_name stays empty).

enum PitchMode {
	## Barrel or bolt points straight at the target (ballista).
	DIRECT,
	## Barrel rises with distance, like a lobbed shell (cannon).
	LOB,
}

@export var yaw_bone: StringName = &"Cannon_1"
@export var pitch_bone: StringName = &"Cannon_2"
## Skin vertices of this bone mark the tip of the barrel or bolt.
@export var tip_bone: StringName = &"Cannon_2"
## Direction the barrel or bolt faces in the model at rest.
@export var rest_forward := Vector3(0, 0, 1)
@export var pitch_mode: PitchMode = PitchMode.LOB
## Degrees per second.
@export var turn_speed := 300.0
@export var pitch_speed := 120.0
@export_range(-89, 0) var min_pitch := -30.0
@export_range(0, 89) var max_pitch := 25.0
## LOB: barrel angle at point-blank and at max range.
@export var lob_near_pitch := 5.0
@export var lob_far_pitch := 25.0
## Height above the target's origin to aim at.
@export var aim_height := 1.0

class Rig:
	var skeleton: Skeleton3D
	var yaw: int
	var pitch: int
	var yaw_rest: Quaternion
	var pitch_rest: Quaternion
	## Pitch axis in the pitch bone's parent space.
	var pitch_axis: Vector3
	var muzzle: Marker3D

static var _tip_cache: Dictionary = {}  # "mesh_rid:bone" -> tip in skeleton space

var _tower: Tower
var _levels: Array[Node3D] = []
var _rigs: Array[Rig] = []
var _shown := -1
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	for i in 3:
		var lv := get_node_or_null("Level%d" % (i + 1)) as Node3D
		if lv == null:
			continue
		_levels.append(lv)
		_rigs.append(_build_rig(lv))
	var n := get_parent()
	while n != null and not n is Tower:
		n = n.get_parent()
	_tower = n as Tower
	# TowerModel hands the Tower its static Muzzle in its own _ready, after this one.
	_show_level.call_deferred()


func _build_rig(lv: Node3D) -> Rig:
	var r := Rig.new()
	r.skeleton = lv.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var sk := r.skeleton
	r.yaw = sk.find_bone(yaw_bone)
	r.pitch = sk.find_bone(pitch_bone)
	if r.yaw < 0 or r.pitch < 0:
		push_warning("TurretTowerModel: %s has no bone %s or %s" % [lv.name, yaw_bone, pitch_bone])
		return r
	r.yaw_rest = sk.get_bone_rest(r.yaw).basis.get_rotation_quaternion()
	r.pitch_rest = sk.get_bone_rest(r.pitch).basis.get_rotation_quaternion()
	# Tilting raises the forward axis around up x forward, written in the pitch bone's parent frame.
	var right := Vector3.UP.cross(rest_forward.normalized())
	var parent_rest := sk.get_bone_global_rest(sk.get_bone_parent(r.pitch)) if sk.get_bone_parent(r.pitch) >= 0 else Transform3D()
	r.pitch_axis = (parent_rest.basis.inverse() * right).normalized()
	var slot := BoneAttachment3D.new()
	slot.bone_name = pitch_bone
	sk.add_child(slot)
	r.muzzle = Marker3D.new()
	r.muzzle.name = "Muzzle"
	slot.add_child(r.muzzle)
	var tip := _find_tip(sk)
	r.muzzle.transform = Transform3D(Basis(), sk.get_bone_global_rest(r.pitch).affine_inverse() * tip)
	return r


## Farthest point of tip_bone's mesh along rest_forward, in skeleton space.
func _find_tip(sk: Skeleton3D) -> Vector3:
	var mi := sk.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var key := "%s:%s" % [mi.mesh.get_rid(), tip_bone]
	if _tip_cache.has(key):
		return _tip_cache[key]
	var bone := sk.find_bone(tip_bone)
	var bind := -1
	for k in mi.skin.get_bind_count():
		if mi.skin.get_bind_bone(k) == bone or mi.skin.get_bind_name(k) == tip_bone:
			bind = k
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	var per := int(bones.size() / verts.size())
	var fwd := rest_forward.normalized()
	var best := -INF
	var height := 0.0
	var count := 0
	for v in verts.size():
		for j in per:
			if bones[v * per + j] == bind and weights[v * per + j] > 0.5:
				best = maxf(best, verts[v].dot(fwd))
				height += verts[v].y
				count += 1
				break
	var pivot := sk.get_bone_global_rest(bone).origin
	var tip := pivot
	if count > 0:
		tip = pivot + fwd * (best - pivot.dot(fwd))
		tip.y = height / count
	_tip_cache[key] = tip
	return tip


func _process(delta: float) -> void:
	if _tower == null:
		return
	if _tower.level - 1 != _shown:
		_show_level()
	if _shown < 0 or _shown >= _rigs.size():
		return
	var r := _rigs[_shown]
	if r.yaw < 0:
		return
	var target := _tower.target
	if target != null and is_instance_valid(target):
		var want := _aim_angles(r, target.global_position + Vector3.UP * aim_height)
		_yaw = rotate_toward(_yaw, want.x, deg_to_rad(turn_speed) * delta)
		_pitch = move_toward(_pitch, want.y, deg_to_rad(pitch_speed) * delta)
	_pose(r)


## x: yaw from rest_forward around up, y: pitch above the horizon, both in radians.
func _aim_angles(r: Rig, point: Vector3) -> Vector2:
	var sk := r.skeleton
	var local := sk.global_transform.affine_inverse() * point
	var pivot := sk.get_bone_global_rest(r.pitch).origin
	var d := local - pivot
	var flat := Vector3(d.x, 0.0, d.z)
	var fwd := Vector3(rest_forward.x, 0.0, rest_forward.z).normalized()
	var yaw := fwd.signed_angle_to(flat, Vector3.UP) if flat.length_squared() > 0.0001 else _yaw
	var pitch := 0.0
	if pitch_mode == PitchMode.DIRECT:
		pitch = atan2(d.y, flat.length())
	else:
		var reach := 1.0
		if _tower.data != null:
			var lv: TowerLevelData = _tower.data.levels[_tower.level - 1]
			# The skeleton is in model units; compare in world metres.
			reach = clampf((point - _tower.global_position).length() / maxf(lv.attack_range, 0.1), 0.0, 1.0)
		pitch = deg_to_rad(lerpf(lob_near_pitch, lob_far_pitch, reach))
	return Vector2(yaw, clampf(pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch)))


func _pose(r: Rig) -> void:
	var sk := r.skeleton
	sk.set_bone_pose_rotation(r.yaw, Quaternion(Vector3.UP, _yaw) * r.yaw_rest)
	# Rotating around up x forward by +a lowers the barrel, so raise it with -pitch.
	sk.set_bone_pose_rotation(r.pitch, Quaternion(r.pitch_axis, -_pitch) * r.pitch_rest)


func _show_level() -> void:
	if _tower == null:
		return
	_shown = clampi(_tower.level - 1, 0, _levels.size() - 1)
	for i in _levels.size():
		_levels[i].visible = i == _shown
	var r := _rigs[_shown]
	if r.muzzle != null:
		_tower.set_visuals(null, r.muzzle)
		_pose(r)


## Muzzle marker of the level being shown. For tests.
func muzzle() -> Marker3D:
	return _rigs[_shown].muzzle if _shown >= 0 else null


## World direction the barrel or bolt points. For tests.
func barrel_direction() -> Vector3:
	var r := _rigs[_shown]
	var sk := r.skeleton
	var pose := sk.get_bone_global_pose(r.pitch)
	var rest := sk.get_bone_global_rest(r.pitch)
	var fwd := (pose.basis * rest.basis.inverse()) * rest_forward
	return (sk.global_transform.basis * fwd).normalized()
