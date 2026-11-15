extends Node

var passes: int = 0
var fails: int = 0
var _boss_resources: Dictionary[StringName, BossData] = {}
var _boss_catalog_loaded: bool = false


func _ready() -> void:
	var waves := load("res://data/waves/wave_script.tres") as WaveScript
	var rewards := load("res://data/waves/wave_rewards.tres") as WaveRewardTable
	assert_true(waves != null, "Generated WaveScript loads")
	assert_true(rewards != null, "Generated WaveRewardTable loads")
	test_generated_resources()
	test_validation_rejects_invalid_data()
	test_wave_getters_use_entry_arrays()
	if waves != null:
		test_waves(waves)
		test_scale_continuity(waves)
	if rewards != null:
		test_rewards(rewards)
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	get_tree().quit(0 if fails == 0 else 1)


func test_waves(waves: WaveScript) -> void:
	assert_true(waves.spawn_duration.size() == GameConfig.victory_wave, "Every scripted wave has duration")
	assert_true(not waves.wave_of_entry.is_empty(), "Workbook contains wave entries")
	assert_true(waves.enemy_ids.size() == waves.wave_of_entry.size()
		and waves.counts.size() == waves.wave_of_entry.size()
		and waves.escorts.size() == waves.wave_of_entry.size(), "Entry arrays have equal lengths")
	assert_true(waves.hp_mult.size() == GameConfig.victory_wave
		and waves.dmg_mult.size() == GameConfig.victory_wave
		and waves.speed_mult.size() == GameConfig.victory_wave, "Every wave has all multipliers")
	assert_true(numbers_are_valid(waves.hp_mult) and numbers_are_valid(waves.dmg_mult)
		and numbers_are_valid(waves.speed_mult) and numbers_are_valid(waves.spawn_duration),
		"Every wave coefficient is finite and nonnegative")
	var checked_enemies: Dictionary = {}
	for enemy_id in waves.enemy_ids:
		if not checked_enemies.has(enemy_id):
			assert_true(enemy_resource_exists(enemy_id), "Enemy or boss resource exists for %s" % enemy_id)
			checked_enemies[enemy_id] = true
	for entry_wave in waves.wave_of_entry:
		assert_true(entry_wave >= 1 and entry_wave <= GameConfig.victory_wave, "Entry wave is within script range")
	for escort in waves.escorts:
		assert_true(escort == 0 or escort == 1, "Escort flag is boolean")
	for wave in range(1, GameConfig.victory_wave + 1):
		var entries := waves.get_wave(wave)
		var types: Dictionary = {}
		var bosses := 0
		var escorts := 0
		for entry in entries:
			types[entry.enemy_type] = true
			assert_true(entry.count >= 1, "Wave %d has positive count" % wave)
			if boss_resource_for_id(entry.enemy_type) != null:
				bosses += entry.count
			elif entry.is_escort:
				escorts += entry.count
		assert_true(not entries.is_empty() and types.size() <= GameConfig.wave_max_enemy_types, "Wave %d respects enemy type limit" % wave)
		assert_true(waves.get_spawn_duration(wave) >= GameConfig.lbd_min_seconds_per_wave, "Wave %d meets minimum duration" % wave)
		if wave % GameConfig.boss_wave_interval == 0:
			assert_true(bosses == 1 and escorts >= 1, "Wave %d has one boss and escorts" % wave)
	for wave in [-1, 0, GameConfig.victory_wave + 1]:
		assert_true(waves.get_wave(wave).is_empty(), "Wave %d entries fall back to empty" % wave)
		assert_true(waves.get_spawn_duration(wave) == GameConfig.lbd_min_seconds_per_wave
			and waves.get_hp_mult(wave) == 1.0
			and waves.get_dmg_mult(wave) == 1.0
			and waves.get_speed_mult(wave) == 1.0, "Wave %d coefficients fall back" % wave)
	var empty := WaveScript.new()
	assert_true(empty.get_wave(1).is_empty() and empty.get_spawn_duration(1) == GameConfig.lbd_min_seconds_per_wave
		and empty.get_hp_mult(1) == 1.0, "Empty WaveScript falls back")


func test_rewards(rewards: WaveRewardTable) -> void:
	assert_true(rewards.gold_mult.size() == GameConfig.victory_wave
		and rewards.xp_mult.size() == GameConfig.victory_wave
		and rewards.mithril_reward.size() == GameConfig.victory_wave, "Reward arrays cover every wave")
	assert_true(numbers_are_valid(rewards.gold_mult) and numbers_are_valid(rewards.xp_mult)
		and numbers_are_valid(rewards.mithril_reward), "Every reward is finite and nonnegative")
	var covered := mini(GameConfig.victory_wave, mini(rewards.gold_mult.size(),
		mini(rewards.xp_mult.size(), rewards.mithril_reward.size())))
	for wave in range(1, covered + 1):
		assert_true(is_equal_approx(rewards.get_gold_mult(wave), snappedf(rewards.gold_mult[wave - 1], WaveRewardTable.SNAP_STEP))
			and is_equal_approx(rewards.get_xp_mult(wave), snappedf(rewards.xp_mult[wave - 1], WaveRewardTable.SNAP_STEP))
			and rewards.get_mithril_reward(wave) == rewards.mithril_reward[wave - 1],
			"Wave %d reward getters use their table entries" % wave)
	var endless_wave := GameConfig.victory_wave + 1
	var final_mithril_index := mini(GameConfig.victory_wave, rewards.mithril_reward.size()) - 1
	var final_mithril := rewards.mithril_reward[final_mithril_index] if final_mithril_index >= 0 else 0
	assert_true(is_equal_approx(rewards.get_gold_mult(endless_wave),
		1.0 + GameConfig.gold_reward_growth_per_wave * (endless_wave - 1))
		and rewards.get_xp_mult(endless_wave) == 1.0
		and rewards.get_mithril_reward(endless_wave) == final_mithril,
		"Endless rewards use configured formula and the last available Mithril value")


func test_scale_continuity(waves: WaveScript) -> void:
	var scale := load("res://data/config/scale_config.tres") as ScaleConfig
	assert_true(scale != null, "Endless ScaleConfig loads")
	if scale == null:
		return
	var last_wave := GameConfig.victory_wave
	assert_true(is_equal_approx(waves.get_hp_mult(last_wave), scale.get_hp_mult(last_wave))
		and is_equal_approx(waves.get_dmg_mult(last_wave), scale.get_dmg_mult(last_wave))
		and is_equal_approx(waves.get_speed_mult(last_wave), scale.get_speed_mult(last_wave)),
		"Scripted coefficients meet the endless formula at the boundary")
	# TODO(endervia): verify WaveManager selects WaveScript through victory_wave and ScaleConfig afterwards once scripted spawning is integrated.


func assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passes += 1
		print("[PASS] %s" % test_name)
	else:
		fails += 1
		printerr("[FAIL] %s" % test_name)


func numbers_are_valid(value: Variant) -> bool:
	if value is int or value is float:
		return is_finite(float(value)) and value >= 0
	if value is Dictionary:
		for key in value:
			if not numbers_are_valid(value[key]):
				return false
	elif value is Array or value is PackedFloat32Array or value is PackedFloat64Array \
		or value is PackedInt32Array or value is PackedInt64Array or value is PackedByteArray:
		for item in value:
			if not numbers_are_valid(item):
				return false
	return true


func resource_numbers_are_valid(resource: Resource) -> bool:
	for property in resource.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
			# World coordinates may be negative; this threshold is not a generated balance stat.
			if resource is CharacterStats and property.name == &"fall_y_threshold":
				continue
			if not numbers_are_valid(resource.get(property.name)):
				return false
	return true


func tower_levels_are_valid(tower: TowerData) -> bool:
	if tower.levels.size() != GameConfig.tower_max_level:
		return false
	for level in tower.levels:
		if level == null or not resource_numbers_are_valid(level):
			return false
	return true


func enemy_resource_exists(enemy_id: StringName) -> bool:
	var boss := boss_resource_for_id(enemy_id)
	if boss != null:
		return resource_numbers_are_valid(boss)
	var path := "res://data/enemies/%s.tres" % enemy_id
	if not ResourceLoader.exists(path):
		return false
	var enemy := load(path) as EnemyData
	return enemy != null and enemy.id == enemy_id and resource_numbers_are_valid(enemy)


func boss_resource_for_id(enemy_id: StringName) -> BossData:
	if not _boss_catalog_loaded:
		_boss_catalog_loaded = true
		for file in DirAccess.get_files_at("res://data/bosses"):
			if not file.ends_with(".tres"):
				continue
			var resource := load("res://data/bosses".path_join(file)) as BossData
			var valid := resource != null and resource.id != &"" and not _boss_resources.has(resource.id)
			assert_true(valid, "%s declares a unique boss ID" % file)
			if valid:
				_boss_resources[resource.id] = resource
		assert_true(not _boss_resources.is_empty(), "Boss catalog contains BossData")
	return _boss_resources.get(enemy_id)


func test_generated_resources() -> void:
	var character := load("res://data/config/commander_stats.tres") as CharacterStats
	assert_true(character != null and resource_numbers_are_valid(character), "CharacterStats loads with valid numbers")
	var tower_ids: Dictionary = {}
	for file in DirAccess.get_files_at("res://data/towers"):
		if not file.ends_with(".tres"):
			continue
		var resource := load("res://data/towers".path_join(file))
		assert_true(resource != null, "%s loads" % file)
		if not resource is TowerData:
			continue
		var tower := resource as TowerData
		var tower_id := tower.id
		assert_true(tower_id != &"" and not tower_ids.has(tower_id), "%s declares a unique tower ID" % file)
		tower_ids[tower_id] = true
		assert_true(tower_levels_are_valid(tower) and resource_numbers_are_valid(tower),
			"%s covers all tower levels with valid numbers" % tower_id)
		for index in range(tower.levels.size()):
			var level := tower.levels[index]
			assert_true(level != null and level.resource_path == "res://data/towers/%s_l%d.tres" % [tower_id, index + 1],
				"%s level %d references its generated resource" % [tower_id, index + 1])
	assert_true(tower_ids.size() >= 4, "Tower catalog contains the four required tower types")
	for directory in ["res://data/skills", "res://data/weapons"]:
		var count := 0
		for file in DirAccess.get_files_at(directory):
			if not file.ends_with(".tres"):
				continue
			var resource := load(directory.path_join(file))
			if resource is StatCardTable:
				continue
			count += 1
			var valid := resource != null
			if resource is SkillData:
				valid = resource.id != &"" and not resource.values.is_empty() and resource.validate().is_empty()
			elif resource is WeaponData:
				valid = resource.id != &"" and resource.name_key != &""
			else:
				valid = false
			assert_true(valid and resource_numbers_are_valid(resource), "%s loads with valid schema and numbers" % file)
		assert_true(count > 0, "%s contains generated resources" % directory)
	var enemy_count := 0
	for file in DirAccess.get_files_at("res://data/enemies"):
		if not file.ends_with(".tres"):
			continue
		enemy_count += 1
		var enemy := load("res://data/enemies".path_join(file)) as EnemyData
		var valid := enemy != null and enemy.id == StringName(file.get_basename()) and resource_numbers_are_valid(enemy)
		assert_true(valid, "%s loads with valid EnemyData schema and numbers" % file)
	assert_true(enemy_count > 0, "res://data/enemies contains generated resources")


func test_validation_rejects_invalid_data() -> void:
	for invalid in [-1.0, INF, NAN]:
		assert_true(not numbers_are_valid(PackedFloat32Array([1.0, invalid])), "Invalid coefficient or reward is rejected")
	assert_true(not numbers_are_valid(PackedInt32Array([1, -1])), "Negative integer reward is rejected")
	assert_true(not numbers_are_valid({&"damage": PackedFloat32Array([-1.0])}), "Negative skill values are rejected")
	var tower := TowerData.new()
	for index in range(GameConfig.tower_max_level):
		tower.levels.append(TowerLevelData.new())
	tower.levels.remove_at(tower.levels.size() - 1)
	assert_true(not tower_levels_are_valid(tower), "Missing final tower level is rejected")
	assert_true(not enemy_resource_exists(&"missing_balance_enemy"), "Unknown enemy resource is rejected")
	var boss := BossData.new()
	boss.id = &"balance_test_boss"
	_boss_resources[boss.id] = boss
	assert_true(enemy_resource_exists(boss.id), "BossData resolves without a mirrored enemy file")
	_boss_resources.erase(boss.id)
	var partial := WaveScript.new()
	partial.wave_of_entry = PackedInt32Array([1])
	partial.enemy_ids = [&"grunt"]
	partial.counts = PackedInt32Array([1])
	partial.escorts = PackedByteArray([0])
	assert_true(partial.get_wave(1).size() == 1, "Wave entries remain accessible when duration is missing")
	assert_true(partial.get_spawn_duration(1) == GameConfig.lbd_min_seconds_per_wave, "Missing duration uses configured fallback")
	var rewards := WaveRewardTable.new()
	rewards.gold_mult.resize(GameConfig.victory_wave)
	rewards.xp_mult.resize(GameConfig.victory_wave)
	rewards.mithril_reward.resize(GameConfig.victory_wave)
	rewards.gold_mult.fill(1.37123)
	rewards.xp_mult.fill(2.51234)
	rewards.mithril_reward.fill(7)
	test_rewards(rewards)


func test_wave_getters_use_entry_arrays() -> void:
	var waves := WaveScript.new()
	waves.wave_of_entry = PackedInt32Array([2, 1, 2])
	waves.enemy_ids = [&"first", &"second", &"third"]
	waves.counts = PackedInt32Array([3, 2, 4])
	waves.escorts = PackedByteArray([0, 0, 1])
	assert_true(waves.get_wave(1) == [{"enemy_type": &"second", "count": 2, "is_escort": false}],
		"Entry lookup selects its requested wave")
	assert_true(waves.get_wave(2) == [
		{"enemy_type": &"first", "count": 3, "is_escort": false},
		{"enemy_type": &"third", "count": 4, "is_escort": true},
	], "Entry lookup preserves order and escort flags independently of duration")
	var entries := waves.get_wave(2)
	entries[0]["count"] = 99
	assert_true(waves.counts[0] == 3, "Returned dictionaries cannot mutate stored counts")
