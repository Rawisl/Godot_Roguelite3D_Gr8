extends Node3D
## Slot rings in PREP: they show on free slots only and hide in COMBAT, and once the ground
## building limit is reached the empty ground cells show the locked ring (dim, dashed) until a
## place frees up again. Wall slots never lock. Headless: checks and quits.

const SLOT := preload("res://systems/build/slot.tscn")

var _pass := 0
var _fail := 0


func _ready() -> void:
	var root := Node3D.new()
	add_child(root)
	var wall := _slot(root, &"W1", Enums.SlotZone.WALL)
	var ground: Array[Slot] = []
	for i in GameConfig.max_ground_buildings + 2:
		ground.append(_slot(root, StringName("G_%d_0" % i), Enums.SlotZone.GROUND))
	var manager := SlotManager.new()
	manager.slot_root = root
	add_child(manager)

	EventBus.state_changed.emit(&"PREP")
	_check("PREP shows the ring on every free slot", wall.marker.visible and ground.all(func(s: Slot) -> bool: return s.marker.visible))
	_check("no cell is locked while the ground has room", not ground.any(func(s: Slot) -> bool: return s.is_locked()))

	# Fill the ground up to the limit, one short first.
	for i in GameConfig.max_ground_buildings - 1:
		ground[i].set_state(Enums.SlotState.OCCUPIED)
	_check("one place left: still unlocked", not ground.any(func(s: Slot) -> bool: return s.is_locked()))
	ground[GameConfig.max_ground_buildings - 1].set_state(Enums.SlotState.RUINED)
	var empty := ground.slice(GameConfig.max_ground_buildings)
	_check("limit reached (rubble counts): the empty cells lock", empty.all(func(s: Slot) -> bool: return s.is_locked()))
	_check("the used cells are not marked locked", not ground.slice(0, GameConfig.max_ground_buildings).any(func(s: Slot) -> bool: return s.is_locked()))
	_check("a locked cell still shows its ring in PREP", empty.all(func(s: Slot) -> bool: return s.marker.visible))
	_check("wall slots never lock", not wall.is_locked())

	# Clearing the rubble frees a place.
	ground[GameConfig.max_ground_buildings - 1].set_state(Enums.SlotState.EMPTY)
	_check("a place freed: the cells unlock", not ground.any(func(s: Slot) -> bool: return s.is_locked()))

	EventBus.state_changed.emit(&"COMBAT")
	_check("COMBAT hides every ring", not wall.marker.visible and not ground.any(func(s: Slot) -> bool: return s.marker.visible))
	EventBus.state_changed.emit(&"PREP")
	_check("built cells show no ring", not ground[0].marker.visible)

	var mat := ground[0].marker.get_active_material(0) as ShaderMaterial
	var uniforms := mat.shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name) if mat != null else []
	_check("the ring shader has the locked colour and dashes", uniforms.has("locked_color") and uniforms.has("locked_dashes"))

	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _slot(root: Node, id: StringName, zone: Enums.SlotZone) -> Slot:
	var slot: Slot = SLOT.instantiate()
	slot.name = id
	slot.slot_id = id
	slot.zone = zone
	root.add_child(slot)
	return slot


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
