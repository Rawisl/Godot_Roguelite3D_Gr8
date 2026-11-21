extends Node3D

## CentipedeFx on the real centipede model: the slash clips resolve every track, the bone
## attachments follow the skeleton, the roll and spit switches work, particle physics follow the
## model scale, and BossFxManager reads a boss's own anchors while the Bulwark keeps its own.

const MODEL_SCENE: PackedScene = preload("res://contents/assets/characters/enemy and boss/skeletal_centipede/skeletal_centipede_model.tscn")
const FX_SCENE: PackedScene = preload("res://art/vfx/centipede_fx.tscn")
const LIBRARY: AnimationLibrary = preload("res://art/vfx/centipede_fx_library.tres")
const BULWARK_MODEL: PackedScene = preload("res://contents/assets/characters/enemy and boss/boss_bulwark_model.tscn")
const SLASH_CLIPS: Array[StringName] = [&"la1_vfx", &"la2_vfx", &"la3_vfx", &"combo_vfx"]

var passes: int = 0
var fails: int = 0


## Boss stand-in that supplies its own anchors, like the real centipede does.
class FakeCentipede extends Node3D:
	func get_fx_anchors() -> Dictionary:
		return {
			"core_bone": &"Torso_Upper", "core_offset": Vector3(0.0, 0.1, 0.3),
			"core_fallback": Vector3(0.0, 0.6, 0.7),
			"vent_bones": [&"Shoulder.L", &"Shoulder.R"], "vent_offset": Vector3(0.0, 0.15, -0.1),
			"vent_fallback": Vector3(0.0, 1.0, 0.3),
		}


## Boss stand-in whose anchors ask for no core sphere.
class FakeCorelessBoss extends FakeCentipede:
	func get_fx_anchors() -> Dictionary:
		var anchors := super()
		anchors["show_core"] = false
		return anchors


func _ready() -> void:
	print("\n=======================================================")
	print("              CENTIPEDE FX VERIFICATION                ")
	print("=======================================================")

	await test_library_tracks_resolve()
	await test_la1_trail_progresses()
	await test_head_follows_bone()
	await test_spit_switch()
	await test_roll_switches()
	await test_stop_all_clears()
	await test_hold_resume_slash()
	await test_particles_follow_scale()
	await test_spit_speed_scale()
	await test_pool_mesh_disc()
	await test_fx_manager_reads_anchors()
	await test_fx_manager_keeps_bulwark()
	await test_fx_manager_hides_core()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		push_error("  [FAIL] %s" % test_name)


## A model with the effects bound, wrapped in a node scaled like the boss's Model node.
func _make_rig(model_scale: float = 1.0) -> Dictionary:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * model_scale
	add_child(holder)
	var model := MODEL_SCENE.instantiate()
	holder.add_child(model)
	var fx := FX_SCENE.instantiate() as CentipedeFx
	holder.add_child(fx)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh := skeleton.get_node("SkeletalCentipede_Mesh") as MeshInstance3D
	fx.bind(skeleton, mesh)
	return {"holder": holder, "model": model, "fx": fx, "skeleton": skeleton, "mesh": mesh}


func _free_rig(rig: Dictionary) -> void:
	(rig.holder as Node).free()


func _uniform(node: Node, uniform: StringName) -> float:
	return (node as GeometryInstance3D).get_instance_shader_parameter(uniform) as float


func test_library_tracks_resolve() -> void:
	var rig := _make_rig()
	var fx := rig.fx as CentipedeFx
	var player := fx.get_node("VfxPlayer") as AnimationPlayer
	var missing := 0
	var preview_only := 0
	for clip in SLASH_CLIPS:
		var anim := player.get_animation(clip)
		for i in anim.get_track_count():
			var path := anim.track_get_path(i)
			if fx.get_node_or_null(NodePath(path.get_concatenated_names())) == null:
				missing += 1
				push_error("unresolved track %s in %s" % [path, clip])
			var text := str(path)
			if text.begins_with("Boss") or text.begins_with("Camera3D") or anim.track_get_type(i) == Animation.TYPE_ANIMATION:
				preview_only += 1
	assert_true(LIBRARY.has_animation(&"la1_vfx") and LIBRARY.has_animation(&"combo_vfx") and player.has_animation(&"la3_vfx"), "tc1 the player carries the four slash clips")
	assert_true(missing == 0, "tc1 every track of every slash clip resolves a node (%d missing)" % missing)
	assert_true(preview_only == 0, "tc1 no preview-only tracks are left in the library")
	_free_rig(rig)
	await get_tree().process_frame


func test_la1_trail_progresses() -> void:
	var rig := _make_rig()
	var fx := rig.fx as CentipedeFx
	var player := fx.get_node("VfxPlayer") as AnimationPlayer
	fx.play_slash(&"la1_vfx", 1.0)
	player.advance(0.7)
	var progress := _uniform(fx.get_node("SlashLA1/VFX_SlashLA1"), &"progress")
	assert_true(progress > 0.0 and progress < 1.0, "tc2 la1 trail is mid-sweep at 0.7 s (progress %.2f)" % progress)
	assert_true(is_zero_approx(_uniform(fx.get_node("SlashLA2/VFX_SlashLA2"), &"progress")), "tc2 the other trails stay idle")
	_free_rig(rig)
	await get_tree().process_frame


func test_head_follows_bone() -> void:
	var rig := _make_rig()
	await get_tree().process_frame
	await get_tree().process_frame
	var fx := rig.fx as CentipedeFx
	var head := fx.get_node("Head") as BoneAttachment3D
	assert_true(head.use_external_skeleton and not head.external_skeleton.is_empty(), "tc3 the head attachment is bound to the external skeleton")
	var d := head.global_position.distance_to(Vector3(0.0, 0.83, 0.61))
	assert_true(d < 0.05, "tc3 the head attachment sits on the Head bone at rest (off by %.3f)" % d)
	var scythe := fx.get_node("ScytheR") as BoneAttachment3D
	assert_true(scythe.global_position.x < -0.3, "tc3 ScytheR sits on the right (negative x) scythe")
	assert_true((rig.mesh as MeshInstance3D).material_overlay != null, "tc3 bind puts the glow overlay on the body mesh")
	_free_rig(rig)
	await get_tree().process_frame


func test_spit_switch() -> void:
	var rig := _make_rig()
	var fx := rig.fx as CentipedeFx
	await get_tree().process_frame
	var parts: Array[CPUParticles3D] = []
	for nm in ["Core", "Drops", "Smoke"]:
		parts.append(fx.get_node("Head/SpitEmitter/" + nm) as CPUParticles3D)
	fx.set_spit_emitting(true)
	assert_true(parts.all(func(p: CPUParticles3D) -> bool: return p.emitting), "tc4 set_spit_emitting(true) turns on all three spit particles")
	var origin := fx.get_spit_origin()
	assert_true(origin.distance_to((fx.get_node("Head/SpitEmitter") as Node3D).global_position) < 0.001 and origin.z > 0.4, "tc4 the spit origin is the mouth, in front of the body")
	fx.set_spit_emitting(false)
	assert_true(parts.all(func(p: CPUParticles3D) -> bool: return not p.emitting), "tc4 set_spit_emitting(false) turns them off")
	_free_rig(rig)
	await get_tree().process_frame


func test_roll_switches() -> void:
	var rig := _make_rig()
	var fx := rig.fx as CentipedeFx
	fx.set_eye_glow(0.7)
	assert_true(is_equal_approx(_uniform(fx.get_node("Head/EyeL"), &"glow"), 0.7) and is_equal_approx(_uniform(fx.get_node("Head/EyeR"), &"glow"), 0.7), "tc5 eye glow reaches both eyes")
	fx.set_eye_sparks(true)
	assert_true((fx.get_node("Head/EyeL/Sparks") as CPUParticles3D).emitting and (fx.get_node("Head/EyeR/Sparks") as CPUParticles3D).emitting, "tc5 eye sparks switch on")
	fx.set_speed_lines(0.5)
	assert_true(is_equal_approx(_uniform(fx.get_node("RollSpeedLines"), &"intensity"), 0.5), "tc5 speed line intensity is set")
	fx.set_body_glow(0.4)
	assert_true(is_equal_approx(_uniform(rig.mesh, &"glow"), 0.4), "tc5 body glow is set on the body mesh")
	_free_rig(rig)
	await get_tree().process_frame


func test_stop_all_clears() -> void:
	var rig := _make_rig()
	var fx := rig.fx as CentipedeFx
	fx.play_slash(&"la3_vfx", 1.0)
	(fx.get_node("VfxPlayer") as AnimationPlayer).advance(0.7)
	fx.set_eye_glow(1.0)
	fx.set_eye_sparks(true)
	fx.set_speed_lines(1.0)
	fx.set_body_glow(1.0)
	fx.set_spit_emitting(true)
	fx.stop_all()
	var player := fx.get_node("VfxPlayer") as AnimationPlayer
	assert_true(not player.is_playing() and is_zero_approx(_uniform(fx.get_node("SlashLA3/VFX_SlashLA3_L"), &"opacity")), "tc6 stop_all stops the trail clip and hides the trail")
	var quiet := not (fx.get_node("Head/EyeL/Sparks") as CPUParticles3D).emitting \
			and not (fx.get_node("Head/SpitEmitter/Core") as CPUParticles3D).emitting \
			and not (fx.get_node("ScytheR/StarParticles") as CPUParticles3D).emitting
	assert_true(quiet, "tc6 stop_all silences sparks, spit and stars")
	assert_true(is_zero_approx(_uniform(rig.mesh, &"glow")) and is_zero_approx(_uniform(fx.get_node("Head/EyeL"), &"glow")), "tc6 stop_all clears the glows")
	_free_rig(rig)
	await get_tree().process_frame


func test_hold_resume_slash() -> void:
	var rig := _make_rig()
	var fx := rig.fx as CentipedeFx
	var player := fx.get_node("VfxPlayer") as AnimationPlayer
	fx.play_slash(&"combo_vfx", 1.0)
	player.advance(0.3)
	var held_at := player.current_animation_position
	fx.hold_slash()
	assert_true(not player.is_playing() and player.assigned_animation == &"combo_vfx" and is_equal_approx(player.current_animation_position, held_at),
			"tc7 hold_slash freezes the trail clip where it is")
	fx.resume_slash(1.2, 2.0)
	assert_true(player.is_playing() and absf(player.current_animation_position - 1.2) < 0.01 and is_equal_approx(player.get_playing_speed(), 2.0),
			"tc7 resume_slash carries the clip on from the given time at the given speed")
	_free_rig(rig)
	await get_tree().process_frame


## Spit particles at model scale 1 and 2: the cloud is twice as big in the world, and the
## authored gravity is kept instead of compounded by repeated calls.
func test_particles_follow_scale() -> void:
	var rigs: Array[Dictionary] = []
	var cores: Array[CPUParticles3D] = []
	var scales: Array[float] = [1.0, 2.0]
	for i in 2:
		var rig := _make_rig(scales[i])
		(rig.holder as Node3D).position = Vector3(20.0 * i, 0.0, 0.0)
		var fx := rig.fx as CentipedeFx
		fx.apply_scale(scales[i])
		fx.apply_scale(scales[i])
		var core := fx.get_node("Head/SpitEmitter/Core") as CPUParticles3D
		core.use_fixed_seed = true
		core.seed = 7
		core.emitting = true
		rigs.append(rig)
		cores.append(core)
	await get_tree().create_timer(0.5).timeout
	var extent: Array[float] = []
	for i in 2:
		var size := cores[i].capture_aabb().size
		# Along the spit axis (local z); the sideways box carries a fixed margin from the quad size.
		extent.append(size.z * scales[i])
	var ratio := extent[1] / maxf(extent[0], 0.0001)
	if extent[0] > 0.0:
		assert_true(absf(ratio - 2.0) < 0.3, "tc7 the spit cloud is twice as big in the world at scale 2 (ratio %.2f, %.2f m)" % [ratio, extent[0]])
	else:
		# The headless renderer reports an empty particle box, so only the physics values are checked here.
		print("  [SKIP] tc7 cloud size needs a renderer (headless gives an empty box)")
	var authored: Vector3 = cores[1].get_meta(&"authored_gravity")
	assert_true(cores[1].gravity.is_equal_approx(authored * 2.0), "tc7 gravity is twice the authored value at scale 2")
	assert_true(authored.is_equal_approx(cores[0].gravity), "tc7 calling apply_scale twice does not compound")
	(rigs[1].fx as CentipedeFx).apply_scale(1.0)
	assert_true(cores[1].gravity.is_equal_approx(authored), "tc7 apply_scale(1) restores the authored gravity")
	for rig in rigs:
		_free_rig(rig)
	await get_tree().process_frame


func test_spit_speed_scale() -> void:
	var rig := _make_rig()
	var fx := rig.fx as CentipedeFx
	var parts: Array[CPUParticles3D] = []
	for nm in ["Core", "Drops", "Smoke"]:
		parts.append(fx.get_node("Head/SpitEmitter/" + nm) as CPUParticles3D)
	var authored: Array[Vector2] = []
	for p in parts:
		authored.append(Vector2(p.initial_velocity_min, p.initial_velocity_max))
	fx.set_spit_speed_scale(0.6)
	fx.set_spit_speed_scale(0.6)
	var scaled := true
	for i in parts.size():
		scaled = scaled and is_equal_approx(parts[i].initial_velocity_min, authored[i].x * 0.6) \
				and is_equal_approx(parts[i].initial_velocity_max, authored[i].y * 0.6)
	assert_true(scaled, "tc11 set_spit_speed_scale(0.6) gives min and max speed of all three spit particles 0.6 of the authored value, also when called twice")
	fx.apply_scale(3.0)
	var kept := true
	for i in parts.size():
		kept = kept and is_equal_approx(parts[i].initial_velocity_min, authored[i].x * 0.6) \
				and is_equal_approx(parts[i].initial_velocity_max, authored[i].y * 0.6)
	assert_true(kept, "tc11 apply_scale afterwards leaves the speeds alone")
	fx.set_spit_speed_scale(1.0)
	assert_true(is_equal_approx(parts[0].initial_velocity_max, authored[0].y), "tc11 scale 1 restores the authored speed")
	_free_rig(rig)
	await get_tree().process_frame


func test_pool_mesh_disc() -> void:
	var pool := PoisonPoolMesh.new()
	pool.disc = true
	pool.length = 3.0
	var mesh := pool.build_mesh()
	var arrays := mesh.surface_get_arrays(0)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var inside := true
	var rim := false
	var centre := false
	var flat_v := true
	for i in verts.size():
		var r := Vector2(verts[i].x, verts[i].z).length()
		inside = inside and r <= 3.0 + 1e-4
		rim = rim or absf(r - 3.0) < 1e-4
		centre = centre or r < 1e-4
		flat_v = flat_v and is_equal_approx(uvs[i].y, 0.5)
		flat_v = flat_v and absf(uvs[i].x - (0.5 + 0.5 * r / 3.0)) < 1e-4
	assert_true(inside and rim and centre, "tc12 the disc mesh stays within radius length, reaches it and has a centre vertex")
	assert_true(flat_v, "tc12 disc UV.y is 0.5 and UV.x grows with the radius")
	pool.free()
	await get_tree().process_frame


func _attached_bone(holder: Node) -> String:
	return ((holder.get_parent()) as BoneAttachment3D).bone_name


func test_fx_manager_reads_anchors() -> void:
	var boss := FakeCentipede.new()
	boss.add_to_group(&"boss")
	boss.add_child(MODEL_SCENE.instantiate())
	add_child(boss)
	var mgr := BossFxManager.new()
	add_child(mgr)
	EventBus.boss_spawned.emit()
	var rig := mgr.get_rig()
	assert_true(not rig.is_empty(), "tc8 the manager builds a rig on a boss with its own anchors")
	assert_true(_attached_bone((rig.core as Node3D).get_parent()) == "Torso_Upper", "tc8 the core rides the bone the boss named")
	var vent_bones: Array[String] = []
	for vent: CPUParticles3D in rig.vents:
		vent_bones.append(_attached_bone(vent.get_parent()))
	assert_true(vent_bones == ["Shoulder.L", "Shoulder.R"], "tc8 the vents ride the shoulder bones the boss named (%s)" % [vent_bones])
	mgr.free()
	boss.free()
	await get_tree().process_frame


func test_fx_manager_keeps_bulwark() -> void:
	var boss := Node3D.new()
	boss.add_to_group(&"boss")
	boss.add_child(BULWARK_MODEL.instantiate())
	add_child(boss)
	var mgr := BossFxManager.new()
	add_child(mgr)
	EventBus.boss_spawned.emit()
	var rig := mgr.get_rig()
	assert_true(_attached_bone((rig.core as Node3D).get_parent()) == "chest", "tc9 a boss without anchors still gets the core on the chest")
	var vent_bones: Array[String] = []
	for vent: CPUParticles3D in rig.vents:
		vent_bones.append(_attached_bone(vent.get_parent()))
	assert_true(vent_bones == ["upperarm.l", "upperarm.r"], "tc9 and the vents on the upper arms (%s)" % [vent_bones])
	EventBus.boss_phase_changed.emit(&"EXPOSED")
	assert_true(mgr.is_core_lit() and mgr.get_core_light() > 0.0, "tc9 the Bulwark core and its light still light up when exposed")
	mgr.free()
	boss.free()
	await get_tree().process_frame


func test_fx_manager_hides_core() -> void:
	var boss := FakeCorelessBoss.new()
	boss.add_to_group(&"boss")
	boss.add_child(MODEL_SCENE.instantiate())
	add_child(boss)
	var mgr := BossFxManager.new()
	add_child(mgr)
	var alerts: Array[StringName] = []
	var on_alert := func(_tier: int, key: StringName, _args: Dictionary) -> void: alerts.append(key)
	EventBus.alert_requested.connect(on_alert)
	EventBus.boss_spawned.emit()
	var rig := mgr.get_rig()
	EventBus.boss_phase_changed.emit(&"TRANSITION")
	assert_true(not mgr.is_core_lit(), "tc10 a boss with show_core false gets no visible core on the armour break")
	assert_true(mgr.get_core_light() == 0.0, "tc10 and no core light")
	assert_true((rig.plates as CPUParticles3D).emitting and (rig.break_steam as CPUParticles3D).emitting, "tc10 the plates and break steam still burst")
	assert_true(alerts.has(&"alert.boss_core_exposed"), "tc10 the exposed alert still fires")
	EventBus.boss_enraged.emit()
	var vents_on: bool = not rig.vents.is_empty()
	for vent: CPUParticles3D in rig.vents:
		vents_on = vents_on and vent.emitting
	assert_true(vents_on, "tc10 the vents still start on enrage")
	assert_true(not mgr.is_core_lit(), "tc10 and the core stays dark once enraged")
	EventBus.alert_requested.disconnect(on_alert)
	mgr.free()
	boss.free()
	await get_tree().process_frame
