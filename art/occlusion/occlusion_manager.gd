class_name OcclusionManager
extends Node
## Làm mờ dither các vật trong nhóm "occluder" khi chúng che
## chỉ huy, quân địch quanh chỉ huy hoặc vật đang hover.
## Cả vật mờ xuống occluded_alpha (phương án A), không khoét lỗ tròn.
## Khi vật mờ, một bản sao chỉ đổ bóng (SHADOWS_ONLY, không dither) thay nó
## đổ bóng, để bóng không bị lỗ theo lưới dither.

const OCCLUDER_GROUP := &"occluder"
const SHADOW_PROXY_META := &"occlusion_shadow_proxy"

@export var occluded_alpha := 0.3
## Vật cách đường camera tới mục tiêu không quá bán kính này (đo trên mặt đất) thì bị làm mờ.
@export var occlusion_radius := 2.5
@export var fade_time := 0.15
## Quân địch trong bán kính này quanh chỉ huy cũng được xét.
@export var enemy_radius := 3.0
@export var scan_interval := 0.1

## Vật đang hover. Hệ thống chọn mục tiêu gán qua set_hover_target().
var _hover_target: Node3D
var _scan_left := 0.0
## GeometryInstance3D -> alpha hiện tại.
var _alpha := {}
## GeometryInstance3D -> true nếu đang che.
var _occluding := {}
## GeometryInstance3D -> [bản sao đổ bóng, cast_shadow gốc].
var _shadow_proxies := {}

func _ready() -> void:
	# Hiệu ứng hình ảnh chạy theo thời gian thực, cả khi Pause.
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_hover_target(target: Node3D) -> void:
	_hover_target = target

func _process(delta: float) -> void:
	# Bỏ ảnh hưởng của x2/x3 để mờ dần luôn đúng fade_time.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	_scan_left -= real_delta
	if _scan_left <= 0.0:
		_scan_left = scan_interval
		_scan()
	_update_fades(real_delta)

func _scan() -> void:
	_occluding.clear()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var points := _unit_points()
	var hovered := is_instance_valid(_hover_target) and _hover_target.is_inside_tree()
	# Vật đang hover không tự che chính nó: model của nó chỉ xét theo chỉ huy và quân.
	var points_with_hover := points.duplicate()
	if hovered:
		points_with_hover.append(_hover_target.global_position)
	if points_with_hover.is_empty():
		return
	var forward := -camera.global_transform.basis.z
	for occluder in get_tree().get_nodes_in_group(OCCLUDER_GROUP):
		var is_hovered := hovered and (occluder == _hover_target or _hover_target.is_ancestor_of(occluder))
		var targets: Array[Vector3] = points if is_hovered else points_with_hover
		if targets.is_empty():
			continue
		for geo in _geometries(occluder):
			if _is_occluding(geo, camera, forward, targets):
				_occluding[geo] = true

## Chỉ huy và quân địch quanh chỉ huy.
func _unit_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var commander := get_tree().get_first_node_in_group(&"commander") as Node3D
	if commander and commander.is_visible_in_tree():
		points.append(commander.global_position)
		for enemy in get_tree().get_nodes_in_group(&"enemy"):
			var e := enemy as Node3D
			if e and e.global_position.distance_to(commander.global_position) <= enemy_radius:
				points.append(e.global_position)
	return points

func _is_occluding(geo: GeometryInstance3D, camera: Camera3D, forward: Vector3, points: Array[Vector3]) -> bool:
	var box := geo.global_transform * geo.get_aabb()
	# Chỉ nới theo mặt đất (X, Z), không nới chiều cao: tia nhìn đi chéo lên
	# trên nóc vật không bị tính là che.
	var grown := box
	grown.position -= Vector3(occlusion_radius, 0.0, occlusion_radius)
	grown.size += Vector3(occlusion_radius, 0.0, occlusion_radius) * 2.0
	var box_depth := (box.get_center() - camera.global_position).dot(forward)
	for p in points:
		# Vật nằm sau mục tiêu (xa camera hơn) thì không che.
		if box_depth >= (p - camera.global_position).dot(forward):
			continue
		var from := camera.project_ray_origin(camera.unproject_position(p))
		if grown.intersects_segment(from, p):
			return true
	return false

func _geometries(root: Node) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	if root is GeometryInstance3D:
		result.append(root)
	for child in root.find_children("*", "GeometryInstance3D", true, false):
		if not child.has_meta(SHADOW_PROXY_META):
			result.append(child)
	return result

func _update_fades(real_delta: float) -> void:
	var step := (1.0 - occluded_alpha) / maxf(fade_time, 0.001) * real_delta
	for geo in _occluding:
		# Vật có thể bị xóa (bán, phá hủy) giữa hai lần quét.
		if not is_instance_valid(geo):
			continue
		if not _alpha.has(geo):
			_alpha[geo] = 1.0
			_add_shadow_proxy(geo)
	for geo in _alpha.keys():
		if not is_instance_valid(geo):
			_alpha.erase(geo)
			_shadow_proxies.erase(geo)
			continue
		var goal := occluded_alpha if _occluding.has(geo) else 1.0
		var value: float = move_toward(_alpha[geo], goal, step)
		geo.set_instance_shader_parameter(&"dither_alpha", value)
		if value >= 1.0 and goal >= 1.0:
			_alpha.erase(geo)
			_remove_shadow_proxy(geo)
		else:
			_alpha[geo] = value

func _add_shadow_proxy(geo: GeometryInstance3D) -> void:
	var source := geo as MeshInstance3D
	if source == null or source.mesh == null:
		return
	if source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		return
	var proxy := MeshInstance3D.new()
	proxy.set_meta(SHADOW_PROXY_META, true)
	proxy.mesh = source.mesh
	proxy.skin = source.skin
	proxy.layers = source.layers
	proxy.material_override = source.material_override
	for i in source.get_surface_override_material_count():
		proxy.set_surface_override_material(i, source.get_surface_override_material(i))
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_shadow_proxies[geo] = [proxy, source.cast_shadow]
	source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	source.add_child(proxy)
	if not source.skeleton.is_empty():
		# Bản sao nằm dưới source một cấp nên đường dẫn tới Skeleton3D phải lùi thêm một cấp.
		proxy.skeleton = proxy.get_path_to(source.get_node(source.skeleton))

func _remove_shadow_proxy(geo: GeometryInstance3D) -> void:
	if not _shadow_proxies.has(geo):
		return
	var entry: Array = _shadow_proxies[geo]
	_shadow_proxies.erase(geo)
	geo.cast_shadow = entry[1]
	if is_instance_valid(entry[0]):
		entry[0].queue_free()
