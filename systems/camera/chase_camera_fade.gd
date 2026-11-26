class_name ChaseCameraFade
extends RefCounted
## Fades the followed commander out with the dither of the tower occlusion fade while the chase
## camera is pulled close to it by a wall, so the model does not fill the screen. The fade
## follows the distance from the camera to the pivot: fully visible at fade_start_distance or
## farther, fade_min_alpha at fade_end_distance, gone at hide_distance or nearer, linear between,
## and it moves toward that on real time. Meshes that use the dither material fade through it;
## every other mesh or particle node under the target (a weapon with an imported material) fades
## through its transparency where the renderer supports it, is hidden once the model is down to
## min_alpha (the Compatibility renderer ignores transparency), and gets its own transparency and
## visibility back at full opacity. The meshes are collected
## again, once, on the next update after a child is added or removed on the target or on its
## weapon mount (a weapon swapping its model), never by scanning every frame.

const DITHER_SHADER := preload("res://art/shaders/toon_dither.gdshader")
## Group of the node a weapon model is attached to.
const WEAPON_MOUNT_GROUP := &"weapon_mount"

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
## Nodes without the dither material, with the transparency they had before the fade.
var _plain: Dictionary = {}
## The same nodes with the visibility they had before the fade.
var _plain_visible: Dictionary = {}
var _dirty: bool = false
## Nodes whose children coming and going mean the model changed.
var _watched: Array[Node] = []


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
	if _target != null and not is_instance_valid(_target):
		_forget_freed_target()
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
	_plain.clear()
	_plain_visible.clear()


## The target was freed, so there is nothing left to put back.
func _forget_freed_target() -> void:
	_unwatch()
	_target = null
	_meshes.clear()
	_plain.clear()
	_plain_visible.clear()
	_alpha = 1.0
	_applied = 1.0
	_dirty = false


func get_alpha() -> float:
	return _alpha


## Listens for children coming and going on the target and on its weapon mounts, to notice a
## model change without looking at every node of the game.
func _watch_target() -> void:
	if _target == null or not _target.is_inside_tree():
		return
	_watch(_target)
	for mount in _target.get_tree().get_nodes_in_group(WEAPON_MOUNT_GROUP):
		if _target.is_ancestor_of(mount):
			_watch(mount)


func _watch(node: Node) -> void:
	node.child_entered_tree.connect(_on_model_changed)
	node.child_exiting_tree.connect(_on_model_changed)
	_watched.append(node)


func _unwatch() -> void:
	for node in _watched:
		if not is_instance_valid(node):
			continue
		if node.child_entered_tree.is_connected(_on_model_changed):
			node.child_entered_tree.disconnect(_on_model_changed)
		if node.child_exiting_tree.is_connected(_on_model_changed):
			node.child_exiting_tree.disconnect(_on_model_changed)
	_watched.clear()


func _on_model_changed(_node: Node) -> void:
	if not is_instance_valid(_target):
		return
	_dirty = true


## Finds the meshes under the target and gives them the current opacity. A node seen before keeps
## the transparency it was first found with, so a collect in the middle of a fade does not take
## the faded value for its own.
func _collect() -> void:
	_dirty = false
	_meshes.clear()
	var previous := _plain
	var previous_visible := _plain_visible
	_plain = {}
	_plain_visible = {}
	if is_instance_valid(_target):
		for node in _target.find_children("*", "GeometryInstance3D", true, false):
			var geo := node as GeometryInstance3D
			if _has_dither(geo):
				_meshes.append(geo)
			elif previous.has(geo):
				_plain[geo] = previous[geo]
				_plain_visible[geo] = previous_visible.get(geo, true)
			else:
				_plain[geo] = geo.transparency
				_plain_visible[geo] = geo.visible
	for geo in previous:
		if not _plain.has(geo) and is_instance_valid(geo):
			geo.transparency = previous[geo]
			geo.visible = previous_visible.get(geo, true)
	_applied = NAN
	_apply()


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
	return shader_material != null and shader_material.shader == DITHER_SHADER


func _apply() -> void:
	if is_equal_approx(_alpha, _applied):
		return
	_applied = _alpha
	for geo in _meshes:
		if is_instance_valid(geo):
			geo.set_instance_shader_parameter(&"dither_alpha", _alpha)
	var plain_shown := _alpha > min_alpha
	for geo in _plain:
		if not is_instance_valid(geo):
			continue
		geo.transparency = lerpf(_plain[geo], 1.0, 1.0 - _alpha)
		geo.visible = _plain_visible.get(geo, true) and plain_shown
