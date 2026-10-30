extends Node3D
## Tower destroyed effect: the tower shrinks, swells and pops into smoke and debris, the rubble drops in. Not shipped.
## F6: checks once and prints OK/FAIL, then keeps destroying and rebuilding the three towers
## every 2.5 s so the effect can be watched. Headless runs quit after the checks.

const SLOT := preload("res://systems/build/slot.tscn")
const GRASS := preload("res://art/materials/env_grass.tres")
const TOWERS := [
	[preload("res://entities/tower/arrow.tscn"), null],
	[preload("res://entities/tower/cannon.tscn"), preload("res://contents/assets/towers/cannon_tower_model.tscn")],
	[preload("res://entities/tower/barricade.tscn"), preload("res://contents/assets/towers/barricade_tower_model.tscn")],
]

var _pass := 0
var _fail := 0
var _slots: Array[Slot] = []
var _fx: DestroyFxManager


func _ready() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	floor_mesh.mesh = plane
	floor_mesh.material_override = GRASS
	add_child(floor_mesh)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 30, 0)
	light.shadow_enabled = true
	add_child(light)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.0
	cam.rotation_degrees = Vector3(-45, 20, 0)
	add_child(cam)
	cam.global_position = Vector3(0, 1.0, 0) + cam.global_basis.z * 30.0
	_fx = DestroyFxManager.new()
	add_child(_fx)
	for i in TOWERS.size():
		var slot := SLOT.instantiate() as Slot
		slot.name = "D%d" % i
		slot.slot_id = StringName("D%d" % i)
		slot.position = Vector3(-4.0 + i * 4.0, 0, 0)
		add_child(slot)
		_slots.append(slot)
	_build_all()
	# The first frames after loading are long; start once the clocks run at a steady pace.
	await _wait(0.3)
	await _run_checks()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _fail > 0 else 0)
		return
	while is_inside_tree():
		_build_all()
		await _wait(1.0)
		for slot in _slots:
			slot.ruin()
		await _wait(1.5)


func _run_checks() -> void:
	var slot := _slots[1]  # the Cannon: its turret script must not run on the freed tower
	var visual := _fx._rubble_visual(slot)
	_check("the rubble has a visual node to animate", visual != null)
	if visual == null:
		return
	var rest_y := visual.position.y
	var rest_scale := visual.scale
	var model := slot.tower.get_node(^"Model") as Node3D
	var model_pos := model.global_position
	slot.ruin()
	_check("the slot is RUINED at once", slot.state == Enums.SlotState.RUINED)
	var stand_in := get_node_or_null(^"DestroyingTower") as Node3D
	# Fails if Slot.ruin() stops freeing the tower before tower_destroyed (see _dying_tower).
	_check("the tower model moves to a stand-in", stand_in != null and model.get_parent() == stand_in)
	_check("the rubble is hidden while the tower swells", not visual.visible)
	await _wait(0.06)
	_check("the tower shrinks first", is_instance_valid(stand_in) and stand_in.scale.y < 0.95)
	await _wait(0.19)
	_check("the tower lifts", is_instance_valid(model) and model.global_position.y > model_pos.y + 0.1)
	_check("the tower swells", is_instance_valid(stand_in) and stand_in.scale.x > 1.05)
	_check("no burst before the pop", _bursts().is_empty())
	await _wait(0.25)
	_check("the stand-in is gone after the pop", not is_instance_valid(stand_in))
	var bursts := _bursts()
	_check("a burst is spawned at the pop", bursts.size() == 1)
	if bursts.size() == 1:
		var burst := bursts[0]
		_check("smoke and debris are emitting", (burst.get_node(^"Smoke") as CPUParticles3D).emitting and (burst.get_node(^"Debris") as CPUParticles3D).emitting)
	_check("the rubble shows again and drops in", visual.visible and visual.position.y > rest_y + 0.05)
	await _wait(0.5)
	_check("the rubble lands at its rest height", is_equal_approx(visual.position.y, rest_y))
	_check("the rubble ends at its rest scale", visual.scale.is_equal_approx(rest_scale))
	await _wait(1.5)
	_check("the burst frees itself", _bursts().is_empty())
	# Destroyed again while the first effect is still running: still ends at the rest pose.
	_build_one(1)
	slot.ruin()
	await _wait(0.2)
	_build_one(1)
	slot.ruin()
	await _wait(1.0)
	_check("a second destruction during the first still ends at rest", visual.visible and is_equal_approx(visual.position.y, rest_y) and visual.scale.is_equal_approx(rest_scale))
	# x3 speed: the effect keeps its real-time length.
	_build_one(1)
	TimeManager.set_time_scale(3)
	slot.ruin()
	await _wait(0.2)
	_check("at x3 the tower is still swelling after 0.2 s real time", get_node_or_null(^"DestroyingTower") != null)
	await _wait(0.3)
	var live := _bursts()
	TimeManager.set_time_scale(1)
	await _frames(1)
	_check("a burst follows a speed change while it plays", not live.is_empty() 			and is_equal_approx((live[0].get_node(^"Smoke") as CPUParticles3D).speed_scale, 1.0))
	await _wait(1.8)
	# Paused: the swell holds and pops after the game resumes.
	_build_one(1)
	slot.ruin()
	TimeManager.request_pause(TimeManager.REASON_USER)
	await _wait(0.5)
	_check("while paused the tower does not pop", get_node_or_null(^"DestroyingTower") != null)
	TimeManager.release_pause(TimeManager.REASON_USER)
	await _wait(0.5)
	_check("after the pause the tower pops", get_node_or_null(^"DestroyingTower") == null and not _bursts().is_empty())
	await _wait(1.6)


func _bursts() -> Array[Node]:
	return find_children("DestroyBurst*", "", false, false)


func _build_all() -> void:
	for i in _slots.size():
		_build_one(i)


func _build_one(i: int) -> void:
	var slot := _slots[i]
	if slot.state != Enums.SlotState.EMPTY:
		slot.set_state(Enums.SlotState.EMPTY)
	var tower := (TOWERS[i][0] as PackedScene).instantiate() as Tower
	if TOWERS[i][1] != null:
		tower.get_node(^"Model").add_child((TOWERS[i][1] as PackedScene).instantiate())
	slot.place_tower(tower)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Real seconds, so x3 does not shorten the wait.
func _wait(seconds: float) -> void:
	var end := TimeManager.real_time + seconds
	while TimeManager.real_time < end:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[test] OK   ", label)
	else:
		_fail += 1
		print("[test] FAIL ", label)
