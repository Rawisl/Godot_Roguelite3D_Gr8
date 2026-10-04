extends Node

## Unit test kiểm tra ScaleConfig khớp bảng SRS 3.7.6
## Chạy scene này bằng F6 trong Godot để tự kiểm tra.

@export var scale_config: ScaleConfig

@onready var label: Label = $CanvasLayer/Panel/Label

func _ready() -> void:
	if scale_config == null:
		scale_config = load("res://data/config/scale_config.tres") as ScaleConfig
	
	run_tests()

func run_tests() -> void:
	var output_text: String = "=== UNIT TEST: SCALECONFIG (SRS 3.7.6) ===\n\n"
	print("\n=== UNIT TEST: SCALECONFIG (SRS 3.7.6) ===")
	
	var table_data := [
		# wave, expected_budget, expected_duration, expected_hp_mult, expected_dmg_mult, expected_speed_mult
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
	
	# Test SCL-01: Thay đổi chỉ số Resource không sửa code
	output_text += "\n--- TEST SCL-01: RESOURCE DRIVEN TUNING ---\n"
	print("\n--- TEST SCL-01: RESOURCE DRIVEN TUNING ---")
	var custom_cfg: ScaleConfig = scale_config.duplicate() as ScaleConfig
	custom_cfg.budget_base = 20.0
	custom_cfg.budget_linear = 5.0
	custom_cfg.budget_quadratic = 0.0
	# Với custom_cfg: wave 1 = 20, wave 2 = 20 + 5(1) = 25
	var scl01_ok: bool = (custom_cfg.get_budget(1) == 20 and custom_cfg.get_budget(2) == 25)
	if scl01_ok:
		var line := "[PASS] SCL-01: Thay đổi tham số trong Resource thay đổi kết quả tính toán động, không cần sửa code."
		print(line)
		output_text += line + "\n"
	else:
		all_passed = false
		var line := "[FAIL] SCL-01: Thay đổi tham số trong Resource không có tác dụng!"
		print(line)
		output_text += line + "\n"
	
	# Test SCL-02: Soft cap wave 40
	output_text += "\n--- TEST SCL-02: SOFT CAP AFTER WAVE 40 ---\n"
	print("\n--- TEST SCL-02: SOFT CAP AFTER WAVE 40 ---")
	var budget_39: int = scale_config.get_budget(39)
	var budget_40: int = scale_config.get_budget(40)
	var budget_41: int = scale_config.get_budget(41)
	var diff_pre_cap: int = budget_40 - budget_39
	var diff_post_cap: int = budget_41 - budget_40
	var scl02_ok: bool = (diff_post_cap < diff_pre_cap)
	if scl02_ok:
		var line := "[PASS] SCL-02: Tốc độ tăng budget sau wave 40 đã giảm một nửa (W39->W40: +%d, W40->W41: +%d)." % [diff_pre_cap, diff_post_cap]
		print(line)
		output_text += line + "\n"
	else:
		all_passed = false
		var line := "[FAIL] SCL-02: Tốc độ tăng budget sau wave 40 không giảm!"
		print(line)
		output_text += line + "\n"
		
	if all_passed:
		output_text += "\n===> KẾT QUẢ: TẤT CẢ TEST ĐỀU ĐẠT CHUẨN SRS 3.7.6 & SCL-01! <==="
		print("\n===> KẾT QUẢ: TẤT CẢ TEST ĐỀU ĐẠT CHUẨN SRS 3.7.6 & SCL-01! <===\n")
	else:
		output_text += "\n===> KẾT QUẢ: CÓ TEST BỊ LỖI! <==="
		push_error("Test ScaleConfig thất bại!")
	
	if label:
		label.text = output_text
