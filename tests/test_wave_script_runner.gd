extends Node

const WAVE_TYPES: Array = [
	"grunt", "grunt", "grunt", "grunt archer", "archer bulwark",
	"grunt archer brute", "grunt archer brute", "archer brute suicide_squad",
	"archer brute suicide_squad", "skeletal_centipede suicide_squad sniper",
	"assassin grunt", "assassin grunt suicide_squad", "assassin grunt suicide_squad archer",
	"assassin suicide_squad knight archer", "bulwark assassin suicide_squad knight sniper",
	"rider knight archer", "rider knight assassin", "rider brute sniper",
	"captain suicide_squad brute sniper assassin", "skeletal_centipede captain brute sniper rider",
	"grunt archer assassin", "brute sniper", "suicide_squad captain knight", "assassin undead",
	"bulwark sniper captain knight assassin", "rider assassin grunt archer",
	"captain suicide_squad brute sniper", "knight undead captain sniper grunt",
	"undead knight", "skeletal_centipede undead knight",
]
const ENEMY_IDS: Array[StringName] = [
	&"grunt", &"archer", &"brute", &"sniper", &"rider",
	&"assassin", &"suicide_squad", &"captain", &"knight", &"undead",
]
const NEW_TRAITS: Dictionary = {
	&"assassin": &"stealth", &"suicide_squad": &"explode",
	&"captain": &"explode", &"knight": &"undying", &"undead": &"revive",
}

var passes := 0
var fails := 0
var waves: WaveScript
var scale: ScaleConfig
var bosses: Dictionary = {}
var enemies: Dictionary = {}


func _ready() -> void:
	waves = load("res://data/waves/wave_script.tres") as WaveScript
	scale = load("res://data/config/scale_config.tres") as ScaleConfig
	if waves == null or scale == null:
		assert_true(false, "WaveScript and ScaleConfig load")
	else:
		for file in DirAccess.get_files_at("res://data/bosses"):
			if file.ends_with(".tres"):
				var resource := load("res://data/bosses".path_join(file)) as BossData
				if resource != null:
					bosses[resource.id] = resource
		for identifier in ENEMY_IDS:
			enemies[identifier] = load("res://data/enemies/%s.tres" % identifier) as EnemyData
		test_wave_types_match_list()
		test_boss_waves()
		test_every_enemy_row_has_data()
		test_new_enemy_traits()
		test_budget_within_10pct()
		test_wave_count_under_max_alive()
		test_coefficients_follow_scale_config()
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	get_tree().quit(0 if fails == 0 else 1)


func assert_true(condition: bool, label: String) -> void:
	if condition:
		passes += 1
		print("[PASS] ", label)
	else:
		fails += 1
		print("[FAIL] ", label)


func test_wave_types_match_list() -> void:
	for wave in range(1, 31):
		var actual: Array[String] = []
		for entry in waves.get_wave(wave):
			actual.append(str(entry.enemy_type))
		actual.sort()
		var expected: Array[String] = []
		for name in str(WAVE_TYPES[wave - 1]).split(" ", false):
			expected.append(name)
		expected.sort()
		assert_true(actual == expected, "Wave %d has its agreed types" % wave)


func test_boss_waves() -> void:
	for wave in range(1, 31):
		var expected_boss := &""
		for name in str(WAVE_TYPES[wave - 1]).split(" ", false):
			if bosses.has(StringName(name)):
				expected_boss = StringName(name)
		var actual_boss := &""
		var boss_count := 0
		var escort_count := 0
		var escort_flags_valid := true
		for entry in waves.get_wave(wave):
			if bosses.has(entry.enemy_type):
				actual_boss = entry.enemy_type
				boss_count += entry.count
				escort_flags_valid = escort_flags_valid and not entry.is_escort
			else:
				if entry.is_escort:
					escort_count += entry.count
				escort_flags_valid = escort_flags_valid and (entry.is_escort == (expected_boss != &""))
		if expected_boss == &"":
			assert_true(boss_count == 0 and escort_count == 0 and escort_flags_valid,
				"Wave %d has no boss or escorts" % wave)
			continue
		assert_true(actual_boss == expected_boss and boss_count == 1
			and escort_count >= 1 and escort_flags_valid,
			"Wave %d has its boss and valid escorts" % wave)


func test_every_enemy_row_has_data() -> void:
	for identifier in ENEMY_IDS:
		var data: EnemyData = enemies.get(identifier)
		assert_true(data != null and data.id == identifier and data.base_hp > 0
			and data.spawn_cost > 0 and data.gold_reward > 0
			and data.prestige_reward > 0 and data.xp_value > 0,
			"%s has positive stats and rewards" % identifier)


func test_new_enemy_traits() -> void:
	for identifier in NEW_TRAITS:
		var data: EnemyData = enemies.get(identifier)
		assert_true(data != null and NEW_TRAITS[identifier] in data.traits
			and data.display_name_key == "enemy.%s" % identifier
			and tr(data.display_name_key) != data.display_name_key,
			"%s has its trait and translated name" % identifier)


func test_budget_within_10pct() -> void:
	for wave in range(1, 31):
		var cost := 0
		var has_boss := false
		for entry in waves.get_wave(wave):
			if bosses.has(entry.enemy_type):
				has_boss = true
				continue
			var data: EnemyData = enemies.get(entry.enemy_type)
			if data != null:
				cost += entry.count * data.spawn_cost
		var target := float(scale.get_budget(wave)) * (0.5 if has_boss else 1.0)
		var tolerance := maxf(0.1 * target, 1.0 if has_boss else 0.0)
		assert_true(absf(float(cost) - target) <= tolerance,
			"Wave %d is within its budget" % wave)


func test_wave_count_under_max_alive() -> void:
	for wave in range(1, 31):
		var count := 0
		for entry in waves.get_wave(wave):
			if not bosses.has(entry.enemy_type):
				count += entry.count
		assert_true(count <= GameConfig.max_alive, "Wave %d stays under the living cap" % wave)


func test_coefficients_follow_scale_config() -> void:
	for wave in range(1, 31):
		assert_true(is_equal_approx(waves.get_spawn_duration(wave), scale.get_spawn_duration(wave))
			and is_equal_approx(waves.get_hp_mult(wave), scale.get_hp_mult(wave))
			and is_equal_approx(waves.get_dmg_mult(wave), scale.get_dmg_mult(wave))
			and is_equal_approx(waves.get_speed_mult(wave), scale.get_speed_mult(wave)),
			"Wave %d follows the scale configuration" % wave)
