class_name ModeSwitch
extends Node
## Switching between Frontline and Commander mode: the Recall channel, the short Arriving
## hold after it, and Deploy. The commander is untouchable from the first frame of Arriving
## on, because Commander mode starts there. Child of the commander.

enum Phase { NONE, RECALLING, ARRIVING, DEPLOYING }

const DENIED_COOLDOWN := &"COOLDOWN"
const DENIED_BOSS_INTRO := &"BOSS_INTRO"

const LAYER_WORLD := 1
const LAYER_STRUCTURE := 4
## Radius of the sphere used to test whether a landing spot is free of walls and structures.
const LANDING_PROBE_RADIUS := 0.4
## Largest distance a candidate may be pulled onto the navmesh and still count as on it.
const NAV_SNAP_TOLERANCE := 0.5
const FALLBACK_RETURN_ZONE_RADIUS := 5.0

var phase: Phase = Phase.NONE
var cooldown_left: float = 0.0

var _commander: CharacterBody3D
var _timer: float = 0.0


func _ready() -> void:
	_commander = get_parent() as CharacterBody3D
	_commander.health.damaged.connect(func(_amount: int, _info: DamageInfo) -> void: interrupt_recall())
	_commander.health.died.connect(reset)


func _physics_process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)
	if phase == Phase.NONE:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	match phase:
		Phase.RECALLING:
			_finish_recall()
		Phase.ARRIVING:
			phase = Phase.NONE
		Phase.DEPLOYING:
			phase = Phase.NONE
			_commander.is_deploying = false
			_commander._refresh_aura()


func is_recalling() -> bool:
	return phase == Phase.RECALLING


func is_arriving() -> bool:
	return phase == Phase.ARRIVING


func is_busy() -> bool:
	return phase != Phase.NONE


## Starts the switch the commander is allowed to make from its current mode.
func request() -> void:
	if is_busy() or _commander.is_dead or _commander.is_stunned:
		return
	if _commander.is_attacking or _commander.is_dodging or _commander.is_using_skill:
		return
	var state: StringName = _commander.get_wave_state()
	if state == &"BOSS_INTRO":
		EventBus.mode_switch_denied.emit(DENIED_BOSS_INTRO, 0.0)
		return
	var free_switch := state == &"PREP"
	if not free_switch and cooldown_left > 0.0:
		EventBus.mode_switch_denied.emit(DENIED_COOLDOWN, cooldown_left)
		return
	if _commander.is_commander_mode:
		_deploy(free_switch)
	else:
		_begin_recall(free_switch)


## Cancels a Recall in progress. No cooldown is spent.
func interrupt_recall() -> void:
	if phase != Phase.RECALLING:
		return
	phase = Phase.NONE
	_timer = 0.0
	_commander._refresh_aura()
	EventBus.recall_cancelled.emit()


## Clears any switch in progress (death, test resets).
func reset() -> void:
	var was_recalling := phase == Phase.RECALLING
	phase = Phase.NONE
	_timer = 0.0
	_commander.is_deploying = false
	if was_recalling:
		EventBus.recall_cancelled.emit()


func _begin_recall(free_switch: bool) -> void:
	if free_switch:
		_finish_recall()
		return
	phase = Phase.RECALLING
	_timer = _channel_time()
	_commander.velocity = Vector3.ZERO
	_commander._refresh_aura()
	EventBus.recall_started.emit(_timer)


func _finish_recall() -> void:
	var free_switch: bool = _commander.get_wave_state() == &"PREP"
	phase = Phase.ARRIVING
	_timer = _commander.get_stat(&"retreat_fade_time", 0.5)
	var post := _marker(&"CommandPost")
	if post != null:
		_commander.global_position = post.global_position
		_commander.face_toward(-post.global_basis.z)
	_commander.velocity = Vector3.ZERO
	EventBus.mode_changed.emit(&"COMMANDER")
	_release_enemy_aggro()
	EventBus.recall_completed.emit()
	if not free_switch:
		cooldown_left = _commander.get_stat(&"mode_switch_cooldown", 5.0)


func _deploy(free_switch: bool) -> void:
	phase = Phase.DEPLOYING
	_timer = _commander.get_stat(&"deploy_invuln_time", 0.6)
	var landing := find_deploy_position()
	_commander.global_position = landing
	_commander.velocity = Vector3.ZERO
	_commander.is_deploying = true
	EventBus.mode_changed.emit(&"FRONTLINE")
	_shockwave(landing)
	if not free_switch:
		cooldown_left = _commander.get_stat(&"mode_switch_cooldown", 5.0)


func _channel_time() -> float:
	if _in_return_zone():
		return _commander.get_stat(&"recall_time_in_zone", 0.6)
	return _commander.get_stat(&"recall_time_outside", 3.0)


func _in_return_zone() -> bool:
	var zone := _marker(&"ReturnZone")
	if zone == null:
		return false
	var radius := FALLBACK_RETURN_ZONE_RADIUS
	var shape_node := zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CylinderShape3D:
		radius = (shape_node.shape as CylinderShape3D).radius * zone.global_transform.basis.get_scale().x
	var offset := _commander.global_position - zone.global_position
	return Vector2(offset.x, offset.z).length() <= radius


## Where Deploy lands: the deploy point itself when free, else the first free spot around it.
func find_deploy_position() -> Vector3:
	var default_point := _default_deploy_point()
	var enemies := PackedVector3Array()
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if enemy is Node3D and not ("is_dead" in enemy and enemy.is_dead):
			enemies.append((enemy as Node3D).global_position)
	var found: Variant = DeployPointFinder.find(
			default_point, _toward_fortress(default_point), enemies,
			_commander.get_stat(&"deploy_clear_radius", 0.8),
			_commander.get_stat(&"deploy_point_search_radius", 4.0),
			_resolve_candidate)
	return default_point if found == null else found


func _default_deploy_point() -> Vector3:
	var marker := _marker(&"DeployPoint")
	return marker.global_position if marker != null else _commander._spawn_position


func _toward_fortress(origin: Vector3) -> Vector3:
	var fortress := get_tree().get_first_node_in_group(&"fortress") as Node3D
	if fortress != null:
		return fortress.global_position
	return origin + Vector3.RIGHT


## Snaps a raw candidate onto the navmesh and rejects it inside the spawn zone or a collider.
func _resolve_candidate(candidate: Vector3) -> Variant:
	var point := candidate
	var map := _commander.get_world_3d().navigation_map
	if not NavigationServer3D.map_get_regions(map).is_empty():
		var on_nav := NavigationServer3D.map_get_closest_point(map, candidate)
		if Vector2(on_nav.x - candidate.x, on_nav.z - candidate.z).length() > NAV_SNAP_TOLERANCE:
			return null
		point = on_nav
	for zone in get_tree().get_nodes_in_group(&"spawn_zone"):
		if _inside_box_area(zone as Area3D, point):
			return null
	if _touches_solid(point):
		return null
	return point


func _inside_box_area(area: Area3D, point: Vector3) -> bool:
	if area == null:
		return false
	var shape_node := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or not (shape_node.shape is BoxShape3D):
		return false
	var local := shape_node.to_local(point)
	var half := (shape_node.shape as BoxShape3D).size * 0.5
	return absf(local.x) <= half.x and absf(local.z) <= half.z


func _touches_solid(point: Vector3) -> bool:
	var probe := SphereShape3D.new()
	probe.radius = LANDING_PROBE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (LANDING_PROBE_RADIUS + 0.5))
	query.collision_mask = (1 << (LAYER_WORLD - 1)) | (1 << (LAYER_STRUCTURE - 1))
	var excluded: Array[RID] = [_commander.get_rid()]
	query.exclude = excluded
	return not _commander.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _shockwave(center: Vector3) -> void:
	var radius: float = _commander.get_stat(&"deploy_shockwave_radius", 3.0)
	var distance: float = _commander.get_stat(&"deploy_shockwave_distance", 2.0)
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if not enemy.has_method("apply_displacement"):
			continue
		var offset: Vector3 = (enemy as Node3D).global_position - center
		offset.y = 0.0
		if offset.length() > radius:
			continue
		# An enemy standing exactly on the landing point is pushed toward the spawn side.
		var direction := offset if offset.length_squared() > 0.0001 else Vector3.RIGHT
		enemy.apply_displacement(direction, distance)


func _release_enemy_aggro() -> void:
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		if enemy.has_method("release_commander_aggro"):
			enemy.release_commander_aggro()


func _marker(marker_name: StringName) -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child(marker_name, true, false) as Node3D
