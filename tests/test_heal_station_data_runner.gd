extends Node

## Automated test runner verifying:
## - heal_station.tres loads as a ground-only, non-attacking TowerData with one level
## - the level has cost 80 and 300 HP
## - GameConfig exposes the heal station limits

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED HEAL STATION DATA RUNNER TEST         ")
	print("=======================================================")

	test_tower_data()
	test_game_config()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

func test_tower_data() -> void:
	print("\n--- heal_station.tres ---")
	var data := load("res://data/towers/heal_station.tres") as TowerData
	assert_true(data != null, "loads as TowerData")
	if data == null:
		return
	assert_true(data.id == &"heal_station", "id is heal_station")
	assert_true(data.display_name == "tower.heal_station", "display_name key")
	assert_true(data.levels.size() == 1, "has exactly 1 level")
	assert_true(data.allowed_zones.size() == 1 and data.allowed_zones[0] == Enums.SlotZone.GROUND,
			"allowed only on GROUND")
	assert_true(not data.targets_ground, "does not target ground")
	assert_true(not data.targets_air, "does not target air")
	assert_true(data.projectile_scene == null, "has no projectile scene")
	if data.levels.size() == 1:
		assert_true(data.levels[0].max_hp == 300, "level 1 max_hp is 300")
		assert_true(data.levels[0].build_cost == 80, "level 1 build_cost is 80")

func test_game_config() -> void:
	print("\n--- GameConfig ---")
	assert_true(GameConfig.heal_tower_max_count == 2, "heal_tower_max_count is 2")
	assert_true(GameConfig.heal_tower_limit_lv == 6, "heal_tower_limit_lv is 6")
	assert_true(is_equal_approx(GameConfig.heal_tower_dmg_norm_exp, 0.5), "heal_tower_dmg_norm_exp is 0.5")

func assert_true(condition: bool, message: String) -> void:
	if condition:
		passes += 1
		print("PASS: ", message)
	else:
		fails += 1
		print("FAIL: ", message)
