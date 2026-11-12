class_name NavRebaker
extends Node
## Rebakes the level navigation meshes when a ground slot changes state, so units walk around
## ground towers and rubble instead of wedging into the gaps between them. Bakes run on a
## background thread; changes inside one frame are merged into a single bake.

## Emitted when every region has finished baking and no change is waiting.
signal rebaked

## Group the level navigation meshes read as their bake source.
const SOURCE_GROUP := &"nav_source"

## Frames to wait after a change before baking: the change itself can land before or after this
## node's own _process in the frame, and a freed tower leaves the tree only when that frame ends.
const SETTLE_FRAMES := 2

## Bake calls made so far (one per region per bake), for tests to count.
var bake_count := 0

var _regions: Array[NavigationRegion3D] = []
var _dirty := false
## Frames still to wait before the pending change is baked.
var _settle_left := 0
## Regions whose bake has started and whose bake_finished has not arrived yet.
var _baking: Dictionary = {}
## Regions that got a change while they were still baking; they bake once more when done.
var _again: Dictionary = {}


func _ready() -> void:
	set_process(false)
	EventBus.slot_state_changed.connect(_on_slot_state_changed)
	# The level is fully built by the next idle frame.
	_find_regions.call_deferred()


func is_idle() -> bool:
	return not _dirty and _baking.is_empty() and _again.is_empty()


func _find_regions() -> void:
	var level := get_parent().owner
	if level == null:
		return
	for node in level.find_children("*", "NavigationRegion3D", true, false):
		_register_region(node as NavigationRegion3D)


func _register_region(region: NavigationRegion3D) -> void:
	var mesh := region.navigation_mesh
	if mesh == null:
		push_warning("NavRebaker: %s has no navigation mesh" % region.name)
		return
	if mesh.geometry_source_geometry_mode == NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN:
		push_warning("NavRebaker: %s does not bake from group %s" % [region.name, SOURCE_GROUP])
		return
	if mesh.geometry_source_group_name != SOURCE_GROUP:
		push_warning("NavRebaker: %s bakes from group %s, not %s" % [region.name, mesh.geometry_source_group_name, SOURCE_GROUP])
		return
	_regions.append(region)
	region.bake_finished.connect(_on_bake_finished.bind(region))
	region.tree_exiting.connect(_on_region_exiting.bind(region))


func _on_slot_state_changed(slot_id: StringName, _state: StringName) -> void:
	var manager := get_parent() as SlotManager
	if manager == null:
		return
	var slot := manager.get_slot(slot_id)
	if slot == null or not slot.is_ground():
		return
	_dirty = true
	_settle_left = SETTLE_FRAMES
	set_process(true)


## Bakes once the change has settled: a sold tower is freed and the rubble collider state applied.
func _process(_delta: float) -> void:
	_settle_left -= 1
	if _settle_left > 0:
		return
	set_process(false)
	_dirty = false
	for region in _regions:
		if not is_instance_valid(region) or not region.is_inside_tree():
			continue
		if _baking.has(region):
			_again[region] = true
			continue
		_bake(region)


func _bake(region: NavigationRegion3D) -> void:
	bake_count += 1
	_baking[region] = true
	region.bake_navigation_mesh(true)


## A region that leaves the tree mid-bake never reports bake_finished; stop waiting for it.
func _on_region_exiting(region: NavigationRegion3D) -> void:
	_regions.erase(region)
	_baking.erase(region)
	_again.erase(region)
	if is_idle():
		rebaked.emit()


func _on_bake_finished(region: NavigationRegion3D) -> void:
	_baking.erase(region)
	if _again.erase(region):
		_bake(region)
		return
	if is_idle():
		rebaked.emit()
