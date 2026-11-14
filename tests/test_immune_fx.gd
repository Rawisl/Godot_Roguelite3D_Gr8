extends Node3D

## Automated test for the tower immune icon (ImmuneFxManager):
## - tower_immunity_changed(true) fades the icon in above the tower model, (false) fades it out
## - another tower's slot does not get an icon
## - with the Frontline aura icon on the same tower, the immune icon sits above it
## - a tower already blocked before the manager starts gets its icon
## - a freed tower leaves no icon behind
## Run with F6.

const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var _fx: ImmuneFxManager


func _ready() -> void:
	print("\n[immune fx] start")
	add_child(POOL_SCENE.instantiate())
	var cam := Camera3D.new()
	cam.position = Vector3(0, 30, 20)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	_fx = ImmuneFxManager.new()
	add_child(_fx)
	await get_tree().process_frame

	await test_show_and_hide()
	await test_other_slot()
	await test_above_aura_icon()
	await test_blocked_before_start()
	await test_freed_tower()

	print("[immune fx] done: %d passed, %d failed" % [passes, fails])
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


func _tower(slot_id: StringName, pos: Vector3) -> Tower:
	var t := ARROW_SCENE.instantiate() as Tower
	t.slot_id = slot_id
	add_child(t)
	t.global_position = pos
	return t


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _top(tower: Tower) -> float:
	var top := -INF
	for mesh in tower.find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		if m.is_visible_in_tree() and m.mesh != null:
			top = maxf(top, (m.global_transform * m.get_aabb()).end.y)
	return top


func test_show_and_hide() -> void:
	print("[GROUP 1] Shown while blocked")
	var t := _tower(&"W1", Vector3(0, 0, 0))
	await _frames(2)
	assert_true(not _fx.has_icon(t), "no icon before the tower is blocked")
	EventBus.tower_immunity_changed.emit(&"W1", true)
	await _frames(30)
	var icon := _fx.get_icon(t)
	assert_true(_fx.has_icon(t) and icon.visible and is_equal_approx(icon.modulate.a, 1.0), "the icon fades in fully")
	assert_true(icon.global_position.y > _top(t), "the icon sits above the tower model (%.2f > %.2f)" % [icon.global_position.y, _top(t)])
	assert_true(icon.no_depth_test and icon.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "the icon faces the camera and is never hidden by the model")
	EventBus.tower_immunity_changed.emit(&"W1", false)
	await _frames(30)
	assert_true(not _fx.has_icon(t) and not icon.visible, "the icon fades out when the tower can shoot again")
	t.free()
	await _frames(2)


func test_other_slot() -> void:
	print("[GROUP 2] Only the tower of that slot")
	var a := _tower(&"W1", Vector3(-4, 0, 0))
	var b := _tower(&"W2", Vector3(4, 0, 0))
	await _frames(2)
	EventBus.tower_immunity_changed.emit(&"W2", true)
	await _frames(20)
	assert_true(_fx.has_icon(b) and not _fx.has_icon(a), "only W2 shows the icon")
	EventBus.tower_immunity_changed.emit(&"W9", true)
	await _frames(2)
	assert_true(not _fx.has_icon(a), "an unknown slot changes nothing")
	a.free(); b.free()
	await _frames(2)


func test_above_aura_icon() -> void:
	print("[GROUP 3] Above the aura icon")
	var t := _tower(&"W1", Vector3(0, 0, 0))
	await _frames(2)
	EventBus.tower_immunity_changed.emit(&"W1", true)
	await _frames(20)
	var plain := _fx.get_icon(t).global_position.y
	t.aura_active = true
	await _frames(2)
	var stacked := _fx.get_icon(t).global_position.y
	assert_true(stacked - plain > _fx.icon_size, "with the aura icon on, the immune icon moves up above it (+%.2f m)" % (stacked - plain))
	t.free()
	await _frames(2)


func test_blocked_before_start() -> void:
	print("[GROUP 4] Tower blocked before the manager starts")
	var t := _tower(&"W3", Vector3(0, 0, 4))
	t.is_immune_blocked = true
	var late := ImmuneFxManager.new()
	add_child(late)
	await _frames(20)
	assert_true(late.has_icon(t), "a tower already blocked gets its icon")
	late.free(); t.free()
	await _frames(2)


func test_freed_tower() -> void:
	print("[GROUP 5] Freed tower")
	var t := _tower(&"W1", Vector3(0, 0, 0))
	await _frames(2)
	EventBus.tower_immunity_changed.emit(&"W1", true)
	await _frames(10)
	var icon := _fx.get_icon(t)
	t.free()
	await _frames(3)
	assert_true(not is_instance_valid(icon), "the icon of a freed tower is removed")
