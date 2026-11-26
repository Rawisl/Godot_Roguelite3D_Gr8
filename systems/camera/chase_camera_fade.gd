class_name ChaseCameraFade
extends RefCounted
## Fades the followed commander out with the dither of the tower occlusion fade while the chase
## camera is pulled close to it by a wall, so the model does not fill the screen. The fade
## follows the distance from the camera to the pivot: fully visible at fade_start_distance or
## farther, fade_min_alpha at fade_end_distance, gone at hide_distance or nearer, linear between,
## and it moves toward that on real time. Only meshes that use a dither material are touched. The meshes are collected
## again, once, on the next update after anything is added or removed under the target (a weapon
## swapping its model), never by scanning every frame.

## Camera-to-pivot distance from which the model starts to fade, in metres.
var start_distance: float = 2.0
## Distance at which the model is down to min_alpha, in metres.
var end_distance: float = 1.0
## Distance at which the model is gone, in metres.
var hide_distance: float = 0.6
## Opacity of the fully faded model, from 0 to 1.
var min_alpha: float = 0.3
## Real seconds from fully visible to hidden.
var fade_time: float = 0.15
## Set by the caller while the camera cannot frame the commander: the commander is hidden then,
## whatever the distance, with the same smoothing, and follows the distance again afterwards.
var unframed: bool = false

var _alpha: float = 1.0
var _applied: float = 1.0
var _target: Node3D
var _meshes: Array[GeometryInstance3D] = []
var _dirty: bool = false
var _watched_tree: SceneTree


func configure(settings: Dictionary) -> void:
	start_distance = settings.get("fade_start_distance", 2.0)
	end_distance = settings.get("fade_end_distance", 1.0)
	hide_distance = settings.get("fade_hide_distance", 0.6)
	min_alpha = settings.get("fade_min_alpha", 0.3)
	fade_time = settings.get("fade_time", 0.15)


## Opacity the model should have with the camera this far from the pivot.
func alpha_for(gap: float) -> float:
	if gap >= start_distance:
		return 1.0
	if start_distance <= end_distance:
		return min_alpha
	if gap > end_distance:
		return lerpf(min_alpha, 1.0, (gap - end_distance) / (start_distance - end_distance))
	if gap <= hide_distance or end_distance <= hide_distance:
		return 0.0
	return lerpf(0.0, min_alpha, (gap - hide_distance) / (end_distance - hide_distance))


## Moves the opacity of the target's dither meshes toward what the distance asks for. A different
## target is put back to full opacity first; the unframed flag the caller set for this tick stays.
func update(target: Node3D, gap: float, real_delta: float, reduced_motion: bool) -> void:
	if target != _target:
		_release_target()
		_target = target
		_watch_target()
		_collect()
	elif _dirty:
		_collect()
	var wanted := 0.0 if unframed else alpha_for(gap)
	if reduced_motion or fade_time <= 0.0:
		_alpha = wanted
	else:
		_alpha = move_toward(_alpha, wanted, real_delta / fade_time)
	_apply()


## Back to full opacity at once, forgets the target and the unframed flag.
func restore() -> void:
	_release_target()
	unframed = false


## Puts the current target's meshes back to full opacity and lets go of it.
func _release_target() -> void:
	_alpha = 1.0
	_apply()
	_unwatch()
	_target = null
	_meshes.clear()


func get_alpha() -> float:
	return _alpha


## Listens for nodes entering or leaving the tree, to notice changes under the target.
func _watch_target() -> void:
	if _target == null or not _target.is_inside_tree():
		return
	_watched_tree = _target.get_tree()
	_watched_tree.node_added.connect(_on_tree_changed)
	_watched_tree.node_removed.connect(_on_tree_changed)


func _unwatch() -> void:
	if _watched_tree == null:
		return
	if is_instance_valid(_watched_tree):
		_watched_tree.node_added.disconnect(_on_tree_changed)
		_watched_tree.node_removed.disconnect(_on_tree_changed)
	_watched_tree = null


func _on_tree_changed(node: Node) -> void:
	if _target != null and _target.is_ancestor_of(node):
		_dirty = true


## Finds the dither meshes under the target and gives them the current opacity.
func _collect() -> void:
	_dirty = false
	_meshes.clear()
	if _target == null:
		return
	for node in _target.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if _has_dither(geo):
			_meshes.append(geo)
			geo.set_instance_shader_parameter(&"dither_alpha", _alpha)
	_applied = _alpha


func _has_dither(geo: GeometryInstance3D) -> bool:
	if _is_dither_material(geo.material_override):
		return true
	var mesh_instance := geo as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		return false
	for surface in mesh_instance.mesh.get_surface_count():
		if _is_dither_material(mesh_instance.get_active_material(surface)):
			return true
	return false


func _is_dither_material(material: Material) -> bool:
	var shader_material := material as ShaderMaterial
	if shader_material == null or shader_material.shader == null:
		return false
	# Instance uniforms are not in the shader's uniform list, so the source is searched.
	return shader_material.shader.code.contains("instance uniform float dither_alpha")


func _apply() -> void:
	if is_equal_approx(_alpha, _applied):
		return
	_applied = _alpha
	for geo in _meshes:
		if is_instance_valid(geo):
			geo.set_instance_shader_parameter(&"dither_alpha", _alpha)
