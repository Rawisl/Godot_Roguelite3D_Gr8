extends Node3D
## Sniper and Assassin models next to the Grunt, Archer and Brute they come from, under the game
## camera angle, playing their idle clip. Headless: checks and quits. F6: stays open to look at.
## Checks: both load with an AnimationPlayer and the clips they need, the Sniper has its bow,
## quiver and glowing eyes, and the Assassin's opacity comes from its unit data (stealth_opacity),
## 1 for a unit that is not stealthy, preview_opacity with no unit.

const D := "res://contents/assets/characters/enemy and boss/"
const ROW := [["Grunt", "grunt_model.tscn"], ["Archer", "archer_model.tscn"], ["Sniper", "sniper_model.tscn"],
	["Brute", "brute_model.tscn"], ["Assassin", "assassin_model.tscn"], ["Rider", "rider/rider_model.tscn"]]

var _pass := 0
var _fail := 0


func _ready() -> void:
	var sniper: Node3D = (load(D + "sniper_model.tscn") as PackedScene).instantiate()
	add_child(sniper)
	var player := sniper.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("the Sniper has idle, walk and ranged clips", player != null and _has_clip(player, "idle") and _has_clip(player, "walk") and player.has_animation_library(&"ranged"))
	_check("the Sniper holds a bow and wears a quiver", sniper.find_child("Bow", true, false) != null and sniper.find_child("Quiver", true, false) != null)
	var eyes := sniper.find_child("Skeleton_Minion_Eyes", true, false) as MeshInstance3D
	_check("the Sniper's eyes glow", eyes != null and eyes.material_override is StandardMaterial3D and (eyes.material_override as StandardMaterial3D).emission_enabled)
	sniper.free()

	var assassin: Node3D = (load(D + "assassin_model.tscn") as PackedScene).instantiate()
	add_child(assassin)
	var aplayer := assassin.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("the Assassin has idle, walk and melee clips", aplayer != null and _has_clip(aplayer, "idle") and _has_clip(aplayer, "walk") and aplayer.has_animation_library(&"melee"))
	_check("the Assassin holds two daggers", assassin.find_child("DaggerRight", true, false) != null and assassin.find_child("DaggerLeft", true, false) != null)
	_check("no unit above: preview opacity", is_equal_approx(assassin.call(&"get_opacity"), assassin.get(&"preview_opacity")))
	var meshes := assassin.find_children("*", "MeshInstance3D", true, false)
	var body := meshes.filter(func(m: MeshInstance3D) -> bool: return not String(m.name).ends_with("Eyes"))
	var shared: Material = (body[0] as MeshInstance3D).material_override
	_check("every Assassin body mesh uses the one see-through material", body.all(func(m: MeshInstance3D) -> bool: return m.material_override == shared))
	var a_eyes := assassin.find_child("Skeleton_Warrior_Eyes", true, false) as MeshInstance3D
	var eye_mat := a_eyes.material_override as ShaderMaterial if a_eyes != null else null
	_check("the Assassin's eyes glow and fade with the body", eye_mat != null and float(eye_mat.get_shader_parameter(&"glow_energy")) > 0.0
		and is_equal_approx(float(eye_mat.get_shader_parameter(&"opacity")), assassin.call(&"get_opacity")))
	assassin.free()

	# Opacity from the unit's data, never from the model.
	for case in [[true, 0.5, 0.5], [true, 0.3, 0.3], [false, 0.5, 1.0]]:
		var unit := Node3D.new()
		unit.set_script(load("res://tests/fake_stealth_unit.gd"))
		var data := EnemyData.new()
		data.is_stealth = case[0]
		data.stealth_opacity = case[1]
		unit.set(&"data", data)
		var model: Node3D = (load(D + "assassin_model.tscn") as PackedScene).instantiate()
		unit.add_child(model)
		add_child(unit)
		_check("is_stealth %s, stealth_opacity %.1f: drawn at %.1f" % case, is_equal_approx(model.call(&"get_opacity"), case[2]))
		unit.free()

	# Rider: seated on the saddle, only sitting and melee clips, the mount bobs while it moves.
	var rider: Node3D = (load(D + "rider/rider_model.tscn") as PackedScene).instantiate()
	add_child(rider)
	await get_tree().process_frame
	await get_tree().process_frame
	var rplayer := rider.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("the Rider's player has only the sitting, melee and its own death clips",
		rplayer != null and Array(rplayer.get_animation_library_list()).all(func(l: StringName) -> bool: return l in [&"simulation", &"melee", &""])
		and not rplayer.has_animation(&"general/Idle_B"))
	_check("the Rider sits", rplayer.current_animation == "simulation/Sit_Chair_Idle")
	_check("the Rider holds a sword", rider.find_child("Sword", true, false) != null)
	var rskel := rider.find_child("Skeleton3D", true, false) as Skeleton3D
	var hip := (rskel.global_transform * rskel.get_bone_global_pose(rskel.find_bone("hips"))).origin
	print("[rider] hips at %s" % hip)
	_check("the Rider's hips sit on the saddle (%.2f m up, z %.2f)" % [hip.y, hip.z], absf(hip.y - 0.92 * 1.544) < 0.15 and absf(hip.z + 0.25 * 1.544) < 0.15)
	var horse_player := rider.get_node("Mount/Horse").find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("the horse has its own rig with Walk, Run and Fall", horse_player != null and Array(horse_player.get_animation_list()) == ["Fall", "Run", "Walk"])
	_check("the unit finds the rider's player, not the horse's", rider.find_child("AnimationPlayer", true, false) == rplayer)
	_check("standing still the horse does not walk", not horse_player.is_playing())
	# Drive the model at a set speed with a fixed step, the same however fast the test runs.
	var drive := func(speed: float, seconds: float) -> void:
		var step := 0.05
		for i in int(seconds / step):
			rider.position.z += speed * step
			rider.call(&"_process", step)
	drive.call(2.0, 0.8)
	_check("moving slowly plays the Walk", horse_player.is_playing() and horse_player.current_animation == "Walk" and rider.call(&"get_gait") == &"Walk")
	drive.call(5.5, 0.8)
	_check("moving fast switches to the Run", horse_player.current_animation == "Run" and rider.call(&"get_gait") == &"Run")
	drive.call(3.3, 0.8)
	_check("just under the threshold it keeps running (no flicker)", rider.call(&"get_gait") == &"Run")
	drive.call(2.0, 0.8)
	_check("slowing well down goes back to the Walk", rider.call(&"get_gait") == &"Walk")
	drive.call(0.0, 0.8)
	_check("stopping stops the horse and it stands still", not horse_player.is_playing() and rider.call(&"get_gait") == &"")
	# Death: the rider slumps on the saddle and the horse kneels forward.
	var death := rplayer.get_animation(&"Death_B") if rplayer.has_animation(&"Death_B") else null
	var bad_tracks := 0
	if death != null:
		for i in death.get_track_count():
			var bone := String(death.track_get_path(i)).get_slice(":", 1)
			if (death.track_get_type(i) == Animation.TYPE_POSITION_3D and bone in ["hips", "root"]) or bone.begins_with("upperleg") or bone.begins_with("lowerleg"):
				bad_tracks += 1
	_check("the rider has a seated Death_B (no hip movement, no leg tracks)", death != null and bad_tracks == 0)
	var seat := (rskel.global_transform * rskel.get_bone_global_pose(rskel.find_bone("hips"))).origin
	var seat_y := seat.y
	rplayer.play(&"Death_B")
	for i in 30:
		rider.call(&"_process", 0.05)
		rplayer.advance(0.05)
		horse_player.advance(0.05)
	_check("the rider's death makes the horse kneel (Fall)", rider.call(&"is_dead") and horse_player.assigned_animation == "Fall")
	var dead_hip := (rskel.global_transform * rskel.get_bone_global_pose(rskel.find_bone("hips"))).origin
	print("[rider] seated hips %.2f, after the fall %.2f" % [seat_y, dead_hip.y])
	_check("the rider stays on the kneeling horse (hips lower but well off the ground)", dead_hip.y < seat_y - 0.05 and dead_hip.y > 0.6)
	# Against the same death with no slide: the slide only moves the rider back along the saddle.
	var still: Node3D = (load(D + "rider/rider_model.tscn") as PackedScene).instantiate()
	still.set(&"death_slide_back", 0.0)
	add_child(still)
	await get_tree().process_frame
	var still_player := still.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var still_horse := still.get_node("Mount/Horse").find_child("AnimationPlayer", true, false) as AnimationPlayer
	var still_skel := still.find_child("Skeleton3D", true, false) as Skeleton3D
	still_player.play(&"Death_B")
	for i in 30:
		still.call(&"_process", 0.05)
		still_player.advance(0.05)
		still_horse.advance(0.05)
	var still_hip := (still_skel.global_transform * still_skel.get_bone_global_pose(still_skel.find_bone("hips"))).origin
	var mine := dead_hip - rider.global_position
	var theirs := still_hip - still.global_position
	var slid := Vector2(theirs.z - mine.z, theirs.y - mine.y).length()
	_check("the dying rider slides back on the saddle (%.2f m further than without the slide)" % slid, mine.z < theirs.z and slid > 0.15 and slid < 0.35)
	still.free()
	# Let the death play to the end: just before the rider slumps, horse and rider tip to the right.
	for i in 24:
		rider.call(&"_process", 0.05)
		rplayer.advance(0.05)
		horse_player.advance(0.05)
	var tip := float(rider.call(&"get_tip_degrees"))
	var end_hip := (rskel.global_transform * rskel.get_bone_global_pose(rskel.find_bone("hips"))).origin - rider.global_position
	print("[rider] tipped %.0f deg, rider hips at %s" % [tip, end_hip])
	var rider_up := (rider.get_node("Mount/Rider") as Node3D).global_basis.y.normalized()
	_check("the horse tips over to its right (-X)", tip > 70.0)
	_check("the rider comes off upright: it does not turn with the horse", rider_up.dot(Vector3.UP) > 0.97)
	_check("the rider lands on the ground beside the horse, to its right", end_hip.x < -0.9 and end_hip.y < 0.6 and end_hip.y > -0.1)
	# The fallen horse's back, near the rider (same z band), must stop short of the rider's hips.
	var horse_reach := INF
	var hm := rider.find_child("RiderHorseFlat", true, false) as MeshInstance3D
	var hverts: PackedVector3Array = hm.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in hverts:
		var w := hm.global_transform * v - rider.global_position
		if absf(w.z - end_hip.z) < 0.5:
			horse_reach = minf(horse_reach, w.x)
	_check("the rider lands clear of the fallen horse (horse reaches %.2f, hips at %.2f)" % [horse_reach, end_hip.x], end_hip.x < horse_reach - 0.4)
	var horse_mesh := rider.find_child("RiderHorseFlat", true, false) as MeshInstance3D
	var low := INF
	if horse_mesh != null:
		var verts: PackedVector3Array = horse_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in verts:
			low = minf(low, (horse_mesh.global_transform * v).y)
	_check("the fallen horse does not sink into the ground (lowest %.2f m)" % low, low > -0.35)
	_check("the rider does not sit back up after dying", rplayer.current_animation == "Death_B" or not rplayer.is_playing())
	rider.free()

	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _fail > 0 else 0)
	else:
		_show_row()


func _has_clip(player: AnimationPlayer, word: String) -> bool:
	for name in player.get_animation_list():
		if word in String(name).to_lower():
			return true
	return false


func _show_row() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 8.0
	add_child(cam)
	cam.look_at_from_position(Vector3(7.255, 21.213, 19.934) * 0.5, Vector3(0, 0.9, 0))
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#3A4A5A")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 10)
	ground.mesh = plane
	ground.material_override = load("res://art/materials/env_grass.tres")
	add_child(ground)
	var layer := CanvasLayer.new()
	add_child(layer)
	for i in ROW.size():
		var model: Node3D = (load(D + ROW[i][1]) as PackedScene).instantiate()
		model.position = Vector3((i - 2.5) * 1.8, 0, 0)
		add_child(model)
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for name in (player.get_animation_list() if player != null else PackedStringArray()):
			if "idle" in String(name).to_lower():
				player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
				player.play(name)
				break
		if ROW[i][0] == "Rider":
			# Walks forward slowly, gallops back, and stands still at each end.
			var start := model.position
			var tw := create_tween().set_loops()
			tw.tween_property(model, "position", start + Vector3(0, 0, 3.0), 1.5)
			tw.tween_interval(1.0)
			tw.tween_property(model, "position", start, 0.55)
			tw.tween_interval(1.0)
		var label := Label.new()
		label.text = ROW[i][0]
		label.add_theme_color_override(&"font_outline_color", Color.BLACK)
		label.add_theme_constant_override(&"outline_size", 6)
		layer.add_child(label)
		label.position = cam.unproject_position(model.position + Vector3(0, 2.2, 0)) - Vector2(30, 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
