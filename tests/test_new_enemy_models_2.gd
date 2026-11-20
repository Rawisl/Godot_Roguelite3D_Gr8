extends Node3D
## Suicide Squad, Captain, Knight and Undead models next to the Archer, Brute and Grunt they come
## from, under the game camera angle. Headless: checks and quits. F6: stays open and cycles each
## effect every 2 s (fuse lit, Knight invulnerable, Undead reviving) so they can be seen.

const D := "res://contents/assets/characters/enemy and boss/"
const ROW := [["Archer", "archer_model.tscn"], ["Suicide Squad", "suicide_squad_model.tscn"], ["Captain", "captain_model.tscn"],
	["Brute", "brute_model.tscn"], ["Knight", "knight_model.tscn"], ["Undead", "undead_model.tscn"]]

var _pass := 0
var _fail := 0
var _effects: Array[Node3D] = []
var _on := false


func _ready() -> void:
	for pair in ROW.slice(1):
		var model: Node3D = (load(D + pair[1]) as PackedScene).instantiate()
		add_child(model)
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_check("%s has an AnimationPlayer with idle and walk clips" % pair[0], player != null and _has(player, "idle") and _has(player, "walk"))
		model.free()

	var squad: Node3D = (load(D + "suicide_squad_model.tscn") as PackedScene).instantiate()
	add_child(squad)
	_check("the Suicide Squad carries a bomb and no weapon", squad.find_child("Bomb", true, false) != null and squad.find_child("Skeleton_Crossbow*", true, false) == null)
	squad.call(&"set_fuse", true)
	var bomb_mesh := squad.find_child("Bomb", true, false).find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_check("lighting the fuse makes the bomb glow", squad.call(&"is_fuse_lit") and bomb_mesh.material_overlay != null)
	_check("the fuse pulse stays under 3 a second", float(squad.get(&"pulse_rate")) <= 3.0)
	squad.call(&"set_fuse", false)
	_check("putting the fuse out clears the glow", bomb_mesh.material_overlay == null)
	squad.free()

	var captain: Node3D = (load(D + "captain_model.tscn") as PackedScene).instantiate()
	add_child(captain)
	var cplayer := captain.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check("the Captain carries a bomb and a sword, with melee clips", captain.find_child("Bomb", true, false) != null and captain.find_child("Sword", true, false) != null and cplayer.has_animation_library(&"melee"))
	var hood := captain.find_child("Skeleton_Rogue_Hood", true, false) as Node3D
	var helmet := captain.find_child("CaptainHelmet", true, false) as Node3D
	_check("the Captain wears the warrior helmet, not the hood", helmet != null and helmet.visible and hood != null and not hood.visible)
	var squad2: Node3D = (load(D + "suicide_squad_model.tscn") as PackedScene).instantiate()
	add_child(squad2)
	var cbody := captain.get_node("Skeleton_Rogue") as Node3D
	var sbody := squad2.get_node("Skeleton_Rogue") as Node3D
	_check("the Captain is bigger than the Suicide Squad", cbody.scale.x > sbody.scale.x * 1.05)
	var cbomb := captain.find_child("Bomb", true, false) as Node3D
	var sbomb := squad2.find_child("Bomb", true, false) as Node3D
	_check("the Captain's bomb is bigger", cbomb.scale.x > sbomb.scale.x)
	var cmat := load(D + "textures/captain_material.tres") as ShaderMaterial
	var smat := load(D + "textures/suicide_squad_material.tres") as ShaderMaterial
	var cc: Color = cmat.get_shader_parameter(&"cloth_color")
	var sc: Color = smat.get_shader_parameter(&"cloth_color")
	_check("the Squad and Captain bones stay untinted", (cmat.get_shader_parameter(&"albedo_color") as Color).is_equal_approx(Color.WHITE)
		and (smat.get_shader_parameter(&"albedo_color") as Color).is_equal_approx(Color.WHITE) and cmat.shader.resource_path.ends_with("toon_cloth_tint.gdshader"))
	_check("the Captain's colour is far from the Squad's red", absf(cc.h - sc.h) > 0.05 and cc.g > sc.g + 0.05)
	squad2.free()
	captain.free()

	var knight: Node3D = (load(D + "knight_model.tscn") as PackedScene).instantiate()
	add_child(knight)
	_check("the Knight holds a sword and the large shield", knight.find_child("Sword", true, false) != null and knight.find_child("Shield", true, false) != null)
	knight.call(&"set_invulnerable", true)
	var icon := knight.find_child("InvulnIcon", true, false) as Sprite3D
	var kmesh := knight.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	_check("invulnerable: the armour glows and the shield icon shows", kmesh.material_overlay != null and icon != null and icon.visible)
	knight.call(&"set_invulnerable", false)
	_check("after it: no glow, no icon", kmesh.material_overlay == null and not icon.visible)
	knight.free()

	var undead: Node3D = (load(D + "undead_model.tscn") as PackedScene).instantiate()
	add_child(undead)
	_check("the Undead holds a scythe", undead.find_child("Scythe", true, false) != null)
	undead.call(&"set_reviving", true)
	_check("reviving: bones swirl and the ring shows", (undead.find_child("ReviveBones", true, false) as CPUParticles3D).emitting and (undead.find_child("ReviveRing", true, false) as Node3D).visible)
	undead.call(&"set_reviving", false)
	_check("after it: no bones, no ring", not (undead.find_child("ReviveBones", true, false) as CPUParticles3D).emitting and not (undead.find_child("ReviveRing", true, false) as Node3D).visible)
	undead.free()

	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _fail > 0 else 0)
	else:
		_show_row()


func _has(player: AnimationPlayer, word: String) -> bool:
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
		if model.has_method(&"set_fuse") or model.has_method(&"set_invulnerable") or model.has_method(&"set_reviving"):
			_effects.append(model)
		var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for name in player.get_animation_list():
			if "idle" in String(name).to_lower():
				player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
				player.play(name)
				break
		var label := Label.new()
		label.text = ROW[i][0]
		label.add_theme_color_override(&"font_outline_color", Color.BLACK)
		label.add_theme_constant_override(&"outline_size", 6)
		layer.add_child(label)
		label.position = cam.unproject_position(model.position + Vector3(0, 2.2, 0)) - Vector2(30, 0)
	var timer := Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.timeout.connect(_toggle_effects)
	add_child(timer)


## Every 2 s: lit fuse, invulnerable Knight and reviving Undead on, then off.
func _toggle_effects() -> void:
	_on = not _on
	for model in _effects:
		for method in [&"set_fuse", &"set_invulnerable", &"set_reviving"]:
			if model.has_method(method):
				model.call(method, _on)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
