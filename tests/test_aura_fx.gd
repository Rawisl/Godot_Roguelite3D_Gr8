extends Node3D

## Automated test for the Frontline aura visuals (branch week7/aura-vfx):
## - the ring fades in around a Frontline commander, follows it, and uses frontline_aura_radius
## - an Arrow 11 m away shows the icon above its model, at 13 m the icon goes away
## - a Barricade inside the radius never shows the icon
## - Commander mode fades the ring out and clears every icon
## - a freed tower leaves no icon behind
## Run with F6. Set quit_when_done off to look at the ring in the editor.

const ARROW_SCENE: PackedScene = preload("res://entities/tower/arrow.tscn")
const BARRICADE_SCENE: PackedScene = preload("res://entities/tower/barricade.tscn")
const COMMANDER_SCENE: PackedScene = preload("res://entities/commander/commander.tscn")
const POOL_SCENE: PackedScene = preload("res://entities/projectile/projectile_pool.tscn")

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var _fx: AuraFxManager


func _ready() -> void:
	print("\n[aura fx] start")
	add_child(POOL_SCENE.instantiate())
	_make_floor()
	_make_camera()
	_fx = AuraFxManager.new()
	add_child(_fx)

	await test_ring()
	await test_icons()
	await test_commander_mode()
	await test_freed_tower()

	print("[aura fx] done: %d passed, %d failed" % [passes, fails])
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


#region Helpers
func _make_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.5, 0)
	add_child(body)


## Commander._physics_process returns early without a camera.
func _make_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 30, 20)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true


func _commander(pos: Vector3):
	var c = COMMANDER_SCENE.instantiate()
	c.position = pos
	add_child(c)
	EventBus.state_changed.emit(&"COMBAT")
	return c


func _tower(scene: PackedScene, pos: Vector3) -> Tower:
	var t := scene.instantiate() as Tower
	t.position = pos
	add_child(t)
	return t


## One tower scan, one icon poll and one fade, in game time.
func _settle() -> void:
	var wait := GameConfig.scan_interval + _fx.icon_poll + _fx.fade_time + 0.05
	await get_tree().create_timer(wait, false, true).timeout


func _icon_of(t: Tower) -> Sprite3D:
	return _fx._icons.get(t)


func _clear(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.free()
#endregion


func test_ring() -> void:
	print("\n[GROUP 1] Ring around the commander")
	assert_true(_fx.ring_fade() == 0.0 and not _fx._ring.visible, "no commander: ring hidden")
	var c = _commander(Vector3(3, 0, 4))
	await _settle()
	assert_true(is_equal_approx(_fx.ring_fade(), 1.0) and _fx._ring.visible, "Frontline commander: ring fully shown")
	var p: Vector3 = _fx._ring.global_position
	assert_true(is_equal_approx(p.x, c.global_position.x) and is_equal_approx(p.z, c.global_position.z),
		"ring is centred on the commander")
	var r: float = _fx._ring.get_instance_shader_parameter(&"radius")
	assert_true(is_equal_approx(r, GameConfig.frontline_aura_radius), "ring radius is frontline_aura_radius (%s)" % r)
	var plane := _fx._ring.mesh as PlaneMesh
	assert_true(plane != null and plane.size.x >= 2.0 * r, "plane is wide enough for the whole ring")
	c.global_position = Vector3(-6, 0, 2)
	await get_tree().process_frame
	await get_tree().process_frame
	p = _fx._ring.global_position
	assert_true(is_equal_approx(p.x, -6.0) and is_equal_approx(p.z, 2.0), "ring follows the commander")
	_clear([c])
	await _settle()
	assert_true(_fx.ring_fade() == 0.0 and not _fx._ring.visible, "commander gone: ring faded out")


func test_icons() -> void:
	print("\n[GROUP 2] Icon above towers that get the aura")
	var arrow := _tower(ARROW_SCENE, Vector3.ZERO)
	var barricade := _tower(BARRICADE_SCENE, Vector3(0, 0, 4))
	var c = _commander(Vector3(11, 0, 0))
	await _settle()
	assert_true(arrow.aura_active and _fx.has_icon(arrow), "Arrow at 11 m: icon shown")
	var icon := _icon_of(arrow)
	assert_true(icon != null and icon.visible and is_equal_approx(icon.modulate.a, 1.0), "icon faded in")
	var top := _fx._tower_height(arrow)
	assert_true(icon != null and icon.global_position.y > arrow.global_position.y + top,
		"icon sits above the tower model (icon y %.2f, model top %.2f)" % [icon.global_position.y if icon else 0.0, top])
	assert_true(not _fx.has_icon(barricade), "Barricade inside the radius: no icon")
	c.global_position = Vector3(13, 0, 0)
	await _settle()
	assert_true(not arrow.aura_active and not _fx.has_icon(arrow), "Arrow at 13 m: icon gone")
	assert_true(icon != null and not icon.visible, "icon faded out")
	_clear([arrow, barricade, c])


func test_commander_mode() -> void:
	print("\n[GROUP 3] Commander mode turns everything off")
	var arrow := _tower(ARROW_SCENE, Vector3.ZERO)
	var c = _commander(Vector3(5, 0, 0))
	await _settle()
	assert_true(_fx.has_icon(arrow) and is_equal_approx(_fx.ring_fade(), 1.0), "Frontline: ring and icon on")
	EventBus.mode_changed.emit(&"COMMANDER")
	await _settle()
	assert_true(_fx.ring_fade() == 0.0, "Commander mode: ring faded out")
	assert_true(not _fx.has_icon(arrow), "Commander mode: icon gone")
	EventBus.mode_changed.emit(&"FRONTLINE")
	await _settle()
	assert_true(is_equal_approx(_fx.ring_fade(), 1.0) and _fx.has_icon(arrow), "back to Frontline: both come back")
	_clear([arrow, c])


func test_freed_tower() -> void:
	print("\n[GROUP 4] Sold or destroyed tower")
	var arrow := _tower(ARROW_SCENE, Vector3.ZERO)
	var c = _commander(Vector3(4, 0, 0))
	await _settle()
	var icon := _icon_of(arrow)
	assert_true(icon != null, "icon made")
	arrow.free()
	await _settle()
	assert_true(not is_instance_valid(icon) or icon.is_queued_for_deletion(), "freed tower: its icon is removed")
	_clear([c])
