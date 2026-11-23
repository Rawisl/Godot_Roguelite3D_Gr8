extends Node3D
## Headless regression checks for tower tier scenes, signals and model replacement.

const SCENES := [
	preload("res://entities/tower/arrow.tscn"),
	preload("res://entities/tower/cannon.tscn"),
	preload("res://entities/tower/barricade.tscn"),
	preload("res://entities/tower/heal_station.tscn"),
]
const POOL := preload("res://entities/projectile/projectile_pool.tscn")
const GRUNT := preload("res://entities/enemy/grunt.tscn")
const CANNON_MODEL := preload("res://contents/assets/towers/cannon_tower_model.tscn")
const SLOT := preload("res://systems/build/slot.tscn")
const RUBBLE_MODEL := preload("res://contents/assets/towers/rubble_model.tscn")

var passes := 0
var fails := 0

func _ready() -> void:
	add_child(POOL.instantiate())
	_make_world()
	test_data_has_three_scenes()
	test_get_model_scene_fallback()
	test_arrow_12_to_13_tier2()
	test_arrow_24_to_25_tier3()
	test_other_towers_follow_tier()
	test_tier_signal_once()
	test_rebuild_level14_shows_tier2()
	test_freed_muzzle_falls_back()
	await test_ruined_shows_shared_rubble()
	await test_no_tier_polling()
	await test_swap_keeps_valid_muzzle()
	print("[tower tiers] %d passed, %d failed" % [passes, fails])
	get_tree().quit(0 if fails == 0 else 1)

func assert_true(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("[PASS] ", label)
	else:
		fails += 1
		printerr("[FAIL] ", label)

func _make_world() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	ground.add_child(shape)
	ground.position.y = -1.0
	add_child(ground)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 15, 15)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true

func _tower(scene: PackedScene) -> Tower:
	var t := scene.instantiate() as Tower
	add_child(t)
	return t

func _tier_model(t: Tower) -> Node3D:
	return t._find_tier_model(t.get_node("Model"))

func _shown_tier(t: Tower) -> int:
	var model := _tier_model(t)
	if model == null:
		return -1
	var found := -1
	for i in range(1, 4):
		var prefix := "HealStationL" if t is HealStation else "Level"
		var n := model.find_child("%s%d" % [prefix, i], true, false) as Node3D
		if n != null and n.visible:
			if found != -1:
				return -1
			found = i
	return found

func test_data_has_three_scenes() -> void:
	for scene in SCENES:
		var t := _tower(scene)
		var model := _tier_model(t)
		var valid := t.data.model_tier_scenes.size() == 3
		for tier in range(1, 4):
			var chosen := t.data.get_model_scene(tier)
			valid = valid and chosen != null and chosen.resource_path == model.scene_file_path
		assert_true(valid, "%s has three valid model scenes" % t.data.id)
		t.free()

func test_get_model_scene_fallback() -> void:
	var data := TowerData.new()
	var scene: PackedScene = SCENES[0]
	data.model_tier_scenes = [scene, null]
	assert_true(data.get_model_scene(3) == scene, "missing tiers fall back to tier 1")
	assert_true(data.get_model_scene(0) == null, "tier zero has no scene")

func test_arrow_12_to_13_tier2() -> void:
	var t := _tower(SCENES[0])
	t.apply_level(GameConfig.tower_tier2_level - 1)
	assert_true(t.model_tier == 1 and _shown_tier(t) == 1, "Arrow before tier 2 shows Level1")
	t.apply_level(GameConfig.tower_tier2_level)
	var m := _tier_model(t) as TurretTowerModel
	assert_true(t.model_tier == 2 and _shown_tier(t) == 2, "Arrow 12 to 13 shows Level2")
	assert_true(is_instance_valid(t._muzzle_node) and t._muzzle_node == m.muzzle(), "Arrow tier 2 muzzle follows rig")
	t.free()

func test_arrow_24_to_25_tier3() -> void:
	var t := _tower(SCENES[0])
	t.apply_level(GameConfig.tower_tier3_level - 1)
	t.apply_level(GameConfig.tower_tier3_level)
	var m := _tier_model(t) as TurretTowerModel
	assert_true(t.model_tier == 3 and _shown_tier(t) == 3, "Arrow 24 to 25 shows Level3")
	assert_true(is_instance_valid(t._muzzle_node) and t._muzzle_node == m.muzzle(), "Arrow tier 3 muzzle follows rig")
	t.free()

func test_other_towers_follow_tier() -> void:
	for scene in [SCENES[1], SCENES[2], SCENES[3]]:
		var t := _tower(scene)
		for lv in [GameConfig.tower_tier2_level, GameConfig.tower_tier3_level]:
			t.apply_level(lv)
			var expected := TowerData.model_tier(lv)
			assert_true(t.model_tier == expected and _shown_tier(t) == expected,
				"%s level %d shows tier %d" % [t.data.id, lv, expected])
		t.free()

func test_tier_signal_once() -> void:
	var t := SCENES[0].instantiate() as Tower
	var received: Array[int] = []
	t.model_tier_changed.connect(func(tier: int): received.append(tier))
	add_child(t)
	t.apply_level(GameConfig.tower_tier2_level - 1)
	t.apply_level(GameConfig.tower_tier2_level)
	t.apply_level(GameConfig.tower_tier2_level + 1)
	t.apply_level(GameConfig.tower_tier2_level + 1)
	assert_true(received == [1, 2], "initial tier and boundary emit once; same tier is silent")
	t.free()

func test_rebuild_level14_shows_tier2() -> void:
	var lv := GameConfig.tower_tier2_level + 1
	for scene in [SCENES[2], SCENES[3]]:
		var t := _tower(scene)
		t.apply_level(lv)
		assert_true(t.model_tier == TowerData.model_tier(lv) and _shown_tier(t) == 2,
			"%s rebuilt at level %d shows tier 2" % [t.data.id, lv])
		t.free()

func test_freed_muzzle_falls_back() -> void:
	var t := _tower(SCENES[0])
	var marker := Marker3D.new()
	t.add_child(marker)
	t.set_visuals(null, marker)
	marker.free()
	assert_true(t._shot_origin().is_equal_approx(t.muzzle.global_position), "freed muzzle falls back to base marker")
	t.free()

func test_ruined_shows_shared_rubble() -> void:
	var slot := SLOT.instantiate() as Slot
	add_child(slot)
	var tower := SCENES[0].instantiate() as Tower
	slot.place_tower(tower)
	tower.apply_level(GameConfig.tower_tier2_level + 1)
	slot.ruin()
	await get_tree().process_frame
	var rubble := slot.rubble.get_node("RubbleModel") as Node3D
	assert_true(slot.state == Enums.SlotState.RUINED and slot.rubble.visible
		and rubble.scene_file_path == RUBBLE_MODEL.resource_path,
		"ruined slot shows the shared rubble model")
	slot.free()

func test_swap_keeps_valid_muzzle() -> void:
	var t := SCENES[0].instantiate() as Tower
	var data := t.data.duplicate() as TowerData
	data.model_tier_scenes = [data.get_model_scene(1), CANNON_MODEL, CANNON_MODEL]
	t.data = data
	add_child(t)
	var old := _tier_model(t)
	var old_transform := old.transform
	var old_index := old.get_index()
	t.apply_level(GameConfig.tower_tier2_level)
	var current := _tier_model(t)
	assert_true(not is_instance_valid(old), "old model is freed immediately")
	assert_true(current != null and current.scene_file_path == CANNON_MODEL.resource_path
		and current.get_index() == old_index and current.transform.is_equal_approx(old_transform),
		"replacement preserves model position and order")
	assert_true(is_instance_valid(t._muzzle_node) and current.is_ancestor_of(t._muzzle_node),
		"replacement installs a valid muzzle")
	var enemy := GRUNT.instantiate() as Enemy
	enemy.position = Vector3(0, 0, 5)
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.spawn_grace = false
	enemy.is_in_spawn_zone = false
	var fired: Array[Vector3] = []
	t.shot_released.connect(func(pos: Vector3, _target: Node3D): fired.append(pos))
	await get_tree().create_timer(2.5).timeout
	assert_true(not fired.is_empty(), "replacement tower still releases shots")
	if not fired.is_empty():
		assert_true(fired[0].distance_to(t._muzzle_node.global_position) < 0.05,
			"shot originates at the replacement muzzle")
	# Let the scene tree release active projectiles with their target on quit.

func test_no_tier_polling() -> void:
	for scene in [SCENES[0], SCENES[3]]:
		var t := _tower(scene)
		t.level = GameConfig.tower_tier2_level
		await get_tree().process_frame
		assert_true(t.model_tier == 1 and _shown_tier(t) == 1, "%s does not poll its level" % t.data.id)
		t.free()
