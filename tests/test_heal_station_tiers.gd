extends Node3D
## Heal station tiers: the model shows HealStationL1, L2 or L3 for the station's level, with the
## brown tier 1 and the mixed tier 2, and the energy orb sits over each tier's pool at its height
## and size. Headless: checks and quits. F6: also shows the three tiers side by side.

const MODEL := preload("res://contents/assets/towers/heal_station_model.tscn")
const TIER1_BROWN := preload("res://contents/assets/towers/texture/heal_station_stone_light_tier1.tres")

var _pass := 0
var _fail := 0


func _ready() -> void:
	var model: HealStationModel = MODEL.instantiate()
	add_child(model)
	var orb := model.get_node("%EnergyOrb") as EnergyOrb
	_check("without a tower it shows the preview tier", model.get_tier() == model.preview_tier and _visible_tier(model) == model.preview_tier)

	# A stand-in tower walks through the levels.
	var tower := Tower.new()
	model._tower = tower
	var expect := {1: 1, GameConfig.tower_tier2_level - 1: 1, GameConfig.tower_tier2_level: 2,
		GameConfig.tower_tier3_level - 1: 2, GameConfig.tower_tier3_level: 3, 36: 3}
	for level in expect:
		tower.level = level
		model._process(0.0)
		var tier: int = expect[level]
		_check("level %d shows tier %d" % [level, tier], _visible_tier(model) == tier)
		_check("level %d: orb at %.2f m, scale %.2f" % [level, model.orb_heights[tier - 1], model.orb_scales[tier - 1]],
			is_equal_approx(orb.position.y, model.orb_heights[tier - 1]) and is_equal_approx(orb.scale.x, model.orb_scales[tier - 1]))
	tower.free()
	model._tower = null

	# Each tier's orb floats over its own pool, and lower tiers have a lower, smaller orb.
	var l1 := model.find_child("HealStationL1", true, false) as MeshInstance3D
	_check("tier 1 uses the brown stone", l1.mesh.surface_get_material(0) == TIER1_BROWN)
	for i in 3:
		var mesh := model.find_child("HealStationL%d" % (i + 1), true, false) as MeshInstance3D
		var top := (mesh.get_aabb().end.y) * mesh.scale.y
		_check("tier %d orb (%.2f m) is above its pool" % [i + 1, model.orb_heights[i]], model.orb_heights[i] - orb.radius * model.orb_scales[i] > _pool_height(mesh) and top > 0.0)
	_check("orbs rise and grow with the tier", model.orb_heights[0] < model.orb_heights[1] and model.orb_heights[1] < model.orb_heights[2]
		and model.orb_scales[0] < model.orb_scales[1] and model.orb_scales[1] <= model.orb_scales[2])
	model.free()

	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _fail > 0 else 0)
	else:
		_show_side_by_side()


func _visible_tier(model: Node) -> int:
	for i in 3:
		var level := model.find_child("HealStationL%d" % (i + 1), true, false) as Node3D
		if level != null and level.visible:
			return i + 1
	return 0


## Height of the water surface: the top of the heal_water surfaces.
func _pool_height(mesh: MeshInstance3D) -> float:
	var top := 0.0
	for s in mesh.mesh.get_surface_count():
		if mesh.mesh.surface_get_material(s) == preload("res://art/materials/heal_water.tres"):
			var arrays := mesh.mesh.surface_get_arrays(s)
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				top = maxf(top, v.y * mesh.scale.y)
	return top


func _show_side_by_side() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.0
	add_child(cam)
	cam.global_basis = Basis.from_euler(Vector3(deg_to_rad(-45), deg_to_rad(20), 0))
	cam.global_position = Vector3(0, 0.6, 0) + cam.global_basis.z * 30.0
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 12)
	ground.mesh = plane
	ground.material_override = preload("res://art/materials/env_grass.tres")
	add_child(ground)
	for i in 3:
		var model: HealStationModel = MODEL.instantiate()
		model.preview_tier = i + 1
		model.position = Vector3((i - 1) * 2.4, 0, 0)
		add_child(model)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
