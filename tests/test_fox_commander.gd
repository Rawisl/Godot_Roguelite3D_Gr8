extends Node3D
## Fox commander model: swaps it into commander.tscn at runtime (the way TV1 will wire it),
## checks it, then lets you drive it. commander.tscn itself still uses the knight. Not shipped.
## F6: WASD moves, attack runs the 3-hit combo, dodge rolls, the camera follows.
## Headless, it prints the checks and quits.

const COMMANDER := preload("res://entities/commander/commander.tscn")
const FOX := preload("res://contents/assets/characters/fox_commander/fox_commander_model.tscn")
const KNIGHT := preload("res://contents/assets/characters/commander/commander_model.tscn")

## Every clip commander.gd plays (ANIM_* and COMBO_ANIM_CLIPS).
const CLIPS := [&"general/Idle_A", &"move/Running_A", &"general/Hit_A", &"general/Death_A",
	&"advance/Dodge_Forward", &"advance/Dodge_Backward", &"simulation/Cheering",
	&"melee/Melee_1H_Attack_Chop", &"melee/Melee_1H_Attack_Slice_Diagonal", &"melee/Melee_2H_Attack_Spinning"]

var _pass := 0
var _fail := 0
var _commander: Node3D
var _cam: Camera3D


func _ready() -> void:
	_make_world()
	_commander = COMMANDER.instantiate()
	_swap_in_fox(_commander)
	add_child(_commander)
	var knight: Node3D = KNIGHT.instantiate()
	knight.position = Vector3(2.5, 0, 0)
	add_child(knight)
	EventBus.state_changed.emit(&"COMBAT")
	await get_tree().physics_frame
	await get_tree().physics_frame
	if DisplayServer.get_name() == "headless":
		await _run_checks(knight)
		get_tree().quit(1 if _fail > 0 else 0)


func _run_checks(knight: Node3D) -> void:
	var ap: AnimationPlayer = _commander._anim_player
	_check("commander uses FoxAnimationPlayer", ap != null and ap.name == &"FoxAnimationPlayer")
	for clip in CLIPS:
		_check("has %s" % clip, ap != null and ap.has_animation(clip))
	_check("idle and run loop", ap.get_animation(&"general/Idle_A").loop_mode != Animation.LOOP_NONE
		and ap.get_animation(&"move/Running_A").loop_mode != Animation.LOOP_NONE)
	_check("commander starts in idle", ap.current_animation == &"general/Idle_A")

	var fb := _bounds(_commander.get_node("AimPivot/Model/CommanderModel"), "FoxSword")
	var kb := _bounds(knight, "sword")
	print("[fox] body size %s / knight %s" % [fb.size.snapped(Vector3.ONE * 0.01), kb.size.snapped(Vector3.ONE * 0.01)])
	_check("fox is about as tall as the knight", absf(fb.size.y - kb.size.y) < 0.15)
	_check("fox stands on the ground", absf(fb.position.y) < 0.05)

	var sword := _commander.find_child("FoxSword", true, false) as MeshInstance3D
	_check("sword uses the knight's sword material", sword != null and sword.material_override != null)
	# Facing: the sword sticks out in front at rest, like the knight's, so +Z is the front.
	var model := FOX.instantiate() as Node3D
	add_child(model)
	(model.get_node("%FoxAnimationPlayer") as AnimationPlayer).stop()
	(model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D).reset_bone_poses()
	await get_tree().process_frame
	var s := model.find_child("FoxSword", true, false) as MeshInstance3D
	var tip := (s.global_transform * s.get_aabb()).end.z
	_check("fox faces +Z like the knight (sword tip z %.2f)" % tip, tip > 1.0)
	model.free()

	# First combo hit through commander.gd.
	var hand_slot := sword.get_parent() as Node3D
	var before := hand_slot.global_position
	_commander._try_attack()
	await get_tree().create_timer(0.3).timeout
	_check("attack plays the first combo clip", String(ap.current_animation) == "melee/Melee_1H_Attack_Chop")
	_check("sword moves with the swing (%.2f m)" % hand_slot.global_position.distance_to(before),
		hand_slot.global_position.distance_to(before) > 0.1)
	print("[fox] done: %d passed, %d failed" % [_pass, _fail])


## Replaces the knight under AimPivot/Model with the fox and points _anim_player at its player.
func _swap_in_fox(commander: Node3D) -> void:
	var slot := commander.get_node("AimPivot/Model")
	var knight := slot.get_node("CommanderModel")
	var index := knight.get_index()
	slot.remove_child(knight)
	knight.free()
	var fox := FOX.instantiate()
	fox.name = "CommanderModel"
	slot.add_child(fox)
	slot.move_child(fox, index)
	commander._anim_player = fox.get_node("%FoxAnimationPlayer")


func _process(_delta: float) -> void:
	if _commander != null and _cam != null:
		_cam.global_position = _commander.global_position + Vector3(0, 9, 8)
		_cam.look_at(_commander.global_position + Vector3.UP)


func _bounds(root: Node, skip: String) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if String(n.name).contains(skip):
			continue
		var m := n as MeshInstance3D
		var b := m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _make_world() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.5, 0)
	add_child(body)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 9, 8)
	add_child(_cam)
	_cam.look_at(Vector3.UP)
	_cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[fox] OK   ", label)
	else:
		_fail += 1
		print("[fox] FAIL ", label)
