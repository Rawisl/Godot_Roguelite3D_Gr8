class_name HealFxManager
extends Node
## Heal station visuals:
## - a green ring at heal_range around every station while the commander is in Frontline and
##   inside that range, or while show_ranges is held
## - a progress ring at the commander's feet while E is held (heal_state_changed HOLD)
## - a beam from the station's BeamOrigin to the commander while it heals (HEALING)
## - the pool colour of each station follows the HP left in its store
## Stations are found through the "heal_station" group (slot_id, hp, optional max_hp), the
## commander through the "commander" group. Nothing is added to the station or commander scenes.

const HOLD := &"HOLD"
const HEALING := &"HEALING"

@export_group("Range ring")
@export var ring_material: ShaderMaterial = preload("res://art/materials/heal_ring.tres")
@export var ring_lift := 0.04
## Room outside the radius for the glow.
@export var ring_margin := 0.6
## Used when the commander has no heal_range stat.
@export var default_heal_range := 3.0

@export_group("Hold ring")
@export var progress_material: ShaderMaterial = preload("res://art/materials/heal_hold_ring.tres")
@export var progress_lift := 0.05

@export_group("Beam")
@export var beam_material: ShaderMaterial = preload("res://art/materials/heal_beam.tres")
@export var beam_radius := 0.1
## Where the beam lands on the commander, above its feet.
@export var beam_target_height := 0.9
## Used when a station model has no BeamOrigin marker.
@export var beam_origin_height := 0.75

## Seconds to fade any of these in or out. Fades, never blinks.
@export var fade_time := 0.15

var _rings: Dictionary = {}  # station -> {mesh, fade, radius, meshes, store}
var _progress_ring: MeshInstance3D
var _progress_fade := 0.0
var _progress := 0.0
var _beam: MeshInstance3D
var _beam_fade := 0.0
var _state: StringName = &""
var _source_slot: StringName = &""


func _ready() -> void:
	_progress_ring = _flat_mesh("HealHoldRing", 2.0, progress_material)
	_beam = MeshInstance3D.new()
	_beam.name = "HealBeam"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = beam_radius
	cylinder.bottom_radius = beam_radius
	cylinder.height = 1.0
	cylinder.radial_segments = 8
	cylinder.rings = 1
	_beam.mesh = cylinder
	_beam.material_override = beam_material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)
	EventBus.heal_state_changed.connect(_on_heal_state_changed)


## Ring shown for this station right now, faded in or not; null when it has none yet.
func get_ring(station: Node3D) -> MeshInstance3D:
	var entry: Dictionary = _rings.get(station, {})
	return entry.get("mesh")


func get_ring_count() -> int:
	return _rings.size()


func _on_heal_state_changed(state: StringName, source_slot: StringName, hold_progress: float) -> void:
	_state = state
	_source_slot = source_slot
	if state == HOLD:
		_progress = hold_progress


func _process(delta: float) -> void:
	var commander := get_tree().get_first_node_in_group(&"commander") as Node3D
	var step := delta / maxf(fade_time, 0.001)
	_update_rings(commander, step)
	_update_progress(commander, step)
	_update_beam(commander, step)


func _update_rings(commander: Node3D, step: float) -> void:
	for station in _rings.keys():
		if not is_instance_valid(station) or not station.is_inside_tree():
			_rings[station].mesh.queue_free()
			_rings.erase(station)
	var radius := _heal_range(commander)
	var show_all := Input.is_action_pressed(&"show_ranges")
	for node in get_tree().get_nodes_in_group(&"heal_station"):
		var station := node as Node3D
		if station == null:
			continue
		var entry: Dictionary = _rings.get(station, {})
		if entry.is_empty():
			entry = {"mesh": _flat_mesh("HealRangeRing", 2.0 * (radius + ring_margin), ring_material), "fade": 0.0, "radius": -1.0,
				"meshes": station.find_children("*", "MeshInstance3D", true, false), "store": -1.0}
			_rings[station] = entry
		var mesh: MeshInstance3D = entry.mesh
		if not is_equal_approx(entry.radius, radius):
			entry.radius = radius
			(mesh.mesh as PlaneMesh).size = Vector2.ONE * 2.0 * (radius + ring_margin)
			mesh.set_instance_shader_parameter(&"radius", radius)
		var wanted := show_all or (_in_frontline(commander) and _flat_distance(station, commander) <= radius)
		entry.fade = move_toward(entry.fade, 1.0 if wanted else 0.0, step)
		mesh.visible = entry.fade > 0.0
		mesh.global_position = station.global_position + Vector3.UP * ring_lift
		mesh.set_instance_shader_parameter(&"fade", entry.fade)
		_update_pool(station, entry)


func _update_progress(commander: Node3D, step: float) -> void:
	var wanted := _state == HOLD and commander != null
	_progress_fade = move_toward(_progress_fade, 1.0 if wanted else 0.0, step)
	_progress_ring.visible = _progress_fade > 0.0 and commander != null
	if not _progress_ring.visible:
		return
	_progress_ring.global_position = commander.global_position + Vector3.UP * progress_lift
	_progress_ring.set_instance_shader_parameter(&"progress", _progress)
	_progress_ring.set_instance_shader_parameter(&"fade", _progress_fade)


func _update_beam(commander: Node3D, step: float) -> void:
	var station := _station_for(_source_slot) if _state == HEALING else null
	var wanted := station != null and commander != null
	_beam_fade = move_toward(_beam_fade, 1.0 if wanted else 0.0, step)
	_beam.visible = _beam_fade > 0.0 and commander != null
	if not _beam.visible:
		return
	if station != null:
		_beam.set_meta(&"station", station)
	var from_station := _beam.get_meta(&"station", null) as Node3D
	if from_station == null or not is_instance_valid(from_station):
		_beam.visible = false
		return
	var start := _beam_origin(from_station)
	var end := commander.global_position + Vector3.UP * beam_target_height
	var axis := start - end
	var length := axis.length()
	if length < 0.01:
		_beam.visible = false
		return
	# The cylinder's +Y runs from its v = 1 end to v = 0, so +Y points at the station.
	var y := axis / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_beam.global_transform = Transform3D(Basis(x, y * length, z), (start + end) * 0.5)
	_beam.set_instance_shader_parameter(&"fade", _beam_fade)


## Pool colour follows the store: full is bright, empty fades to grey water.
## The station's meshes are listed once per ring and only written when the store changes.
func _update_pool(station: Node3D, entry: Dictionary) -> void:
	var max_hp: float = station.get(&"max_hp") if station.get(&"max_hp") != null else 0.0
	var hp = station.get(&"hp")
	if max_hp <= 0.0 or hp == null:
		return
	var store := clampf(float(hp) / max_hp, 0.0, 1.0)
	if is_equal_approx(store, entry.store):
		return
	entry.store = store
	for mesh in entry.meshes:
		if is_instance_valid(mesh):
			(mesh as MeshInstance3D).set_instance_shader_parameter(&"store", store)


func _beam_origin(station: Node3D) -> Vector3:
	var marker := station.find_child("BeamOrigin", true, false) as Node3D
	if marker != null:
		return marker.global_position
	return station.global_position + Vector3.UP * beam_origin_height


func _station_for(slot_id: StringName) -> Node3D:
	for node in get_tree().get_nodes_in_group(&"heal_station"):
		if node.get(&"slot_id") == slot_id:
			return node as Node3D
	return null


func _heal_range(commander: Node3D) -> float:
	if commander != null and commander.has_method(&"get_stat"):
		return commander.get_stat(&"heal_range", default_heal_range)
	return default_heal_range


func _in_frontline(commander: Node3D) -> bool:
	return commander != null and commander.get(&"is_commander_mode") != true


func _flat_distance(a: Node3D, b: Node3D) -> float:
	if b == null:
		return INF
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func _flat_mesh(mesh_name: String, size: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = mesh_name
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * size
	mesh.mesh = plane
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visible = false
	add_child(mesh)
	return mesh
