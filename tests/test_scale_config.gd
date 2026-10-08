extends Node

## Unit test verifying ScaleConfig formulas against SRS 3.7.6 table and SCL-01/SCL-02 rules.

@export var scale_config: ScaleConfig

@onready var label: Label = %Label

func _ready() -> void:
	if scale_config == null:
		scale_config = load("res://data/config/scale_config.tres") as ScaleConfig
	run_tests()

func run_tests() -> void:
	var output_text: String = "=== UNIT TEST: SCALECONFIG (SRS 3.7.6) ===\n\n"
	print("\n=== UNIT TEST: SCALECONFIG (SRS 3.7.6) ===")
	
	var table_data := [
		{"wave": 1, "budget": 8, "duration": 15.0, "hp": 1.00, "dmg": 1.00, "speed": 1.000},
		{"wave": 5, "budget": 18, "duration": 17.0, "hp": 1.46, "dmg": 1.27, "speed": 1.020},
		{"wave": 10, "budget": 32, "duration": 19.5, "hp": 2.22, "dmg": 1.70, "speed": 1.045},
		{"wave": 15, "budget": 49, "duration": 22.0, "hp": 3.18, "dmg": 2.23, "speed": 1.070},
		{"wave": 20, "budget": 68, "duration": 24.5, "hp": 4.34, "dmg": 2.86, "speed": 1.095},
		{"wave": 30, "budget": 114, "duration": 29.5, "hp": 7.26, "dmg": 4.42, "speed": 1.145},
	]
	
	var all_passed: bool = true
	
	for row in table_data:
		var w: int = row["wave"]
		var calc_budget: int = scale_config.get_budget(w)
		var calc_duration: float = scale_config.get_spawn_duration(w)
		var calc_hp: float = snappedf(scale_config.get_hp_mult(w), 0.01)
		var calc_dmg: float = snappedf(scale_config.get_dmg_mult(w), 0.01)
		var calc_speed: float = snappedf(scale_config.get_speed_mult(w), 0.001)
		
		var budget_ok: bool = (calc_budget == int(row["budget"]))
		var duration_ok: bool = is_equal_approx(calc_duration, float(row["duration"]))
		var hp_ok: bool = is_equal_approx(calc_hp, float(row["hp"]))
		var dmg_ok: bool = is_equal_approx(calc_dmg, float(row["dmg"]))
		var speed_ok: bool = is_equal_approx(calc_speed, float(row["speed"]))
		
		var row_passed: bool = budget_ok and duration_ok and hp_ok and dmg_ok and speed_ok
		if not row_passed:
			all_passed = false
			
		var status_str := "[PASS]" if row_passed else "[FAIL]"
		var line := "%s Wave %2d: Budget=%d (exp %d) | Duration=%.1fs (exp %.1fs) | HP=%.2f (exp %.2f) | DMG=%.2f (exp %.2f) | Speed=%.3f (exp %.3f)" % [
			status_str, w, calc_budget, int(row["budget"]), calc_duration, float(row["duration"]), calc_hp, float(row["hp"]), calc_dmg, float(row["dmg"]), calc_speed, float(row["speed"])
		]
		print(line)
		output_text += line + "\n"
	
	# SCL-01 test: runtime resource parameter modification
	var custom_cfg: ScaleConfig = scale_config.duplicate() as ScaleConfig
	custom_cfg.budget_base = 20.0
	custom_cfg.budget_linear = 5.0
	custom_cfg.budget_quadratic = 0.0
	var scl01_ok: bool = (custom_cfg.get_budget(1) == 20 and custom_cfg.get_budget(2) == 25)
	if scl01_ok:
		var line := "[PASS] SCL-01: Runtime resource tuning alters calculation without code changes"
		print(line)
		output_text += "\n" + line + "\n"
	else:
		all_passed = false
		var line := "[FAIL] SCL-01: Resource parameter change had no effect"
		print(line)
		output_text += "\n" + line + "\n"
	
	# SCL-02 test: budget growth rate halved after wave 40
	var diff_pre_cap: int = scale_config.get_budget(40) - scale_config.get_budget(39)
	var diff_post_cap: int = scale_config.get_budget(41) - scale_config.get_budget(40)
	var scl02_ok: bool = (diff_post_cap < diff_pre_cap)
	if scl02_ok:
		var line := "[PASS] SCL-02: Soft cap active after wave 40 (+%d vs +%d)" % [diff_pre_cap, diff_post_cap]
		print(line)
		output_text += line + "\n"
	else:
		all_passed = false
		var line := "[FAIL] SCL-02: Soft cap failed after wave 40"
		print(line)
		output_text += line + "\n"
		
	if all_passed:
		output_text += "\nResult: ALL TESTS PASSED (SRS 3.7.6, SCL-01, SCL-02)"
		print("\nResult: ALL TESTS PASSED (SRS 3.7.6, SCL-01, SCL-02)\n")
	else:
		output_text += "\nResult: SOME TESTS FAILED"
		push_error("ScaleConfig unit test failed")
	
	if label:
		label.text = output_text
