extends Node3D

## Test for the heal station visuals (HealFxManager) with the real station model:
## - the heal_range ring shows when a Frontline commander is inside the range, hides outside it
## - show_ranges shows it from anywhere; Commander mode alone does not
## - HOLD shows the progress ring at the commander's feet with the hold progress
## - HEALING draws the beam from the station's BeamOrigin to the commander; DEPLETED removes it
## - the pool and the energy orb follow the HP left in the store; the beam starts at the orb
## - a freed station leaves no ring behind
## Headless it runs the checks and quits. F6 in the editor runs them, then loops a commander
## walking in and out of range and going through hold and heal.

const MODEL := preload("res://contents/assets/towers/heal_station_model.tscn")
const FAKE_STATION := preload("res://tests/fake_heal_station.gd")

@export var quit_when_done := DisplayServer.get_name() == "headless"

var passes: int = 0
var fails: int = 0
var _fx: HealFxManager
var _commander: Node3D
var _station: Node3D


func _ready() -> void:
	print("\n[heal fx] start")
	_make_world()
	_fx = HealFxManager.new()
	add_child(_fx)
	_station = _make_station(&"slot_a", Vector3.ZERO)
	_commander = _make_commander(Vector3(2, 0, 0))

	await test_ring_in_range()
	await test_show_ranges_and_commander_mode()
	await test_hold_ring()
	await test_beam()
	await test_pool_follows_store()
	await test_freed_station()

	print("[heal fx] done: %d passed, %d failed" % [passes, fails])
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)
		return
	_run_demo()


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)


#region Tests
func test_ring_in_range() -> void:
	_commander.position = Vector3(2, 0, 0)
	await _settle()
	var ring := _fx.get_ring(_station)
	assert_true(ring != null and ring.visible, "a Frontline commander 2 m away shows the ring")
	assert_true(ring != null and is_equal_approx(ring.get_instance_shader_parameter(&"radius"), 3.0), "the ring uses heal_range (3 m)")
	assert_true(ring != null and ring.global_position.distance_to(_station.global_position) < 0.1, "the ring sits on the station")
	_commander.position = Vector3(5, 0, 0)
	await _settle()
	assert_true(not ring.visible, "5 m away the ring fades out")


func test_show_ranges_and_commander_mode() -> void:
	Input.action_press(&"show_ranges")
	await _settle()
	assert_true(_fx.get_ring(_station).visible, "show_ranges shows the ring from outside the range")
	Input.action_release(&"show_ranges")
	_commander.position = Vector3(2, 0, 0)
	_commander.set(&"is_commander_mode", true)
	await _settle()
	assert_true(not _fx.get_ring(_station).visible, "in Commander mode, being inside the range is not enough")
	_commander.set(&"is_commander_mode", false)


func test_hold_ring() -> void:
	EventBus.heal_state_changed.emit(&"HOLD", &"slot_a", 0.5)
	await _settle()
	var ring := _fx.get_node("HealHoldRing") as MeshInstance3D
	assert_true(ring.visible, "HOLD shows the progress ring")
	assert_true(is_equal_approx(ring.get_instance_shader_parameter(&"progress"), 0.5), "the ring shows the hold progress")
	assert_true(Vector2(ring.global_position.x - _commander.global_position.x, ring.global_position.z - _commander.global_position.z).length() < 0.01,
		"the progress ring is at the commander's feet")
	EventBus.heal_state_changed.emit(&"CANCELLED", &"slot_a", 0.0)
	await _settle()
	assert_true(not ring.visible, "a cancel removes the progress ring")


func test_beam() -> void:
	EventBus.heal_state_changed.emit(&"HEALING", &"slot_a", 1.0)
	await _settle()
	var beam := _fx.get_node("HealBeam") as MeshInstance3D
	assert_true(beam.visible, "HEALING shows the beam")
	var origin := (_station.find_child("BeamOrigin", true, false) as Node3D).global_position
	var target := _commander.global_position + Vector3.UP * _fx.beam_target_height
	var length := beam.global_transform.basis.y.length()
	assert_true(absf(length - origin.distance_to(target)) < 0.05, "the beam spans BeamOrigin to the commander")
	assert_true(beam.global_position.distance_to((origin + target) * 0.5) < 0.05, "the beam is centred between them")
	EventBus.heal_state_changed.emit(&"DEPLETED", &"slot_a", 0.0)
	await _settle()
	assert_true(not beam.visible, "DEPLETED removes the beam")


func test_pool_follows_store() -> void:
	_station.hp = 75.0
	await _settle()
	var pool := _station.find_child("heal_station_v3", true, false) as MeshInstance3D
	assert_true(pool != null and is_equal_approx(pool.get_instance_shader_parameter(&"store"), 0.25), "a quarter store sets the pool to 0.25")
	var orb := _station.find_child("EnergyOrb", true, false) as EnergyOrb
	assert_true(orb != null and is_equal_approx(orb.get_store(), 0.25), "the energy orb follows the store")
	var light := orb.get_node("Light") as OmniLight3D
	assert_true(is_equal_approx(light.light_energy, orb.light_energy * 0.25), "the orb's light dims with the store")
	_station.hp = 0.0
	await _settle()
	assert_true(orb.get_store() == 0.0 and light.light_energy == 0.0 and not (orb.get_node("Sparks") as CPUParticles3D).emitting,
		"an empty store turns the orb off: grey, no light, no sparks")
	_station.hp = _station.max_hp


func test_freed_station() -> void:
	var extra := _make_station(&"slot_b", Vector3(-4, 0, 0))
	Input.action_press(&"show_ranges")
	await _settle()
	var ring := _fx.get_ring(extra)
	assert_true(ring != null and ring.visible, "a second station gets its own ring")
	extra.queue_free()
	await _settle()
	assert_true(not is_instance_valid(ring) and _fx.get_ring_count() == 1, "a freed station leaves no ring behind")
	Input.action_release(&"show_ranges")
#endregion


#region Helpers
func _make_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.62, 0.36)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3(0.242, 0, 0.97), Vector3(0.749, 0.636, -0.187), Vector3(-0.617, 0.772, 0.154)), Vector3(0, 10, 0))
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = preload("res://art/materials/env_grass.tres")
	add_child(ground)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.0
	cam.transform = Transform3D(Basis(Vector3(0.707107, 0, -0.707107), Vector3(-0.408248, 0.816497, -0.408248), Vector3(0.57735, 0.57735, 0.57735)), Vector3(12, 13, 12))
	add_child(cam)
	cam.current = true


func _make_station(slot_id: StringName, pos: Vector3) -> Node3D:
	var station := Node3D.new()
	station.set_script(FAKE_STATION)
	station.set(&"slot_id", slot_id)
	station.position = pos
	station.add_child(MODEL.instantiate())
	add_child(station)
	return station


## Stand-in commander: the group and the one flag the manager reads.
func _make_commander(pos: Vector3) -> Node3D:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar is_commander_mode := false\n"
	script.reload()
	var commander := Node3D.new()
	commander.set_script(script)
	commander.position = pos
	commander.add_to_group(&"commander")
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	body.mesh = capsule
	body.position.y = 0.9
	commander.add_child(body)
	add_child(commander)
	return commander


## Longer than a fade, in real time, so it holds however fast the frames run.
func _settle() -> void:
	await get_tree().create_timer(_fx.fade_time * 2.0 + 0.05).timeout
	await get_tree().process_frame
#endregion


#region Demo
## The commander walks a circle that crosses the edge of the range, then stands next to the
## station, holds E for a second and heals for three.
func _run_demo() -> void:
	var t := 0.0
	while is_inside_tree():
		_station.hp = _station.max_hp
		for i in 180:
			t += get_process_delta_time()
			_commander.position = Vector3(cos(t * 0.8) * 3.6, 0, sin(t * 0.8) * 3.6)
			await get_tree().process_frame
		_commander.position = Vector3(1.8, 0, 1.0)
		for i in 10:
			EventBus.heal_state_changed.emit(&"HOLD", _station.slot_id, (i + 1) / 10.0)
			await get_tree().create_timer(0.1).timeout
		EventBus.heal_state_changed.emit(&"HEALING", _station.slot_id, 1.0)
		for i in 30:
			_station.hp = maxf(0.0, _station.hp - 6.0)
			await get_tree().create_timer(0.1).timeout
		EventBus.heal_state_changed.emit(&"IDLE", _station.slot_id, 0.0)
		await get_tree().create_timer(0.8).timeout
#endregion
