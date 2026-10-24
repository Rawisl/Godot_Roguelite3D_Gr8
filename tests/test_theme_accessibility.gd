extends Node

## Automated test runner verifying:
## - main_theme.tres has the variations TV4 uses (Keycap, KeycapLabel, SpeedToggle, ErrorLabel,
##   FormCaption, HudLabel, HudHint) and a LineEdit style
## - the Accessibility tab broadcasts screen_shake, reduced_motion and reduce_flash

const THEME: Theme = preload("res://ui/theme/main_theme.tres")
const TAB := preload("res://ui/screens/tab_accessibility.tscn")

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var _got: Dictionary = {}

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED THEME AND ACCESSIBILITY TEST          ")
	print("=======================================================")

	var variations := {
		&"Keycap": &"PanelContainer", &"KeycapLabel": &"Label", &"SpeedToggle": &"Button",
		&"ErrorLabel": &"Label", &"FormCaption": &"Label", &"HudLabel": &"Label", &"HudHint": &"Label",
	}
	for v in variations:
		assert_true(THEME.get_type_variation_base(v) == variations[v], "%s is a %s variation" % [v, variations[v]])
	assert_true(THEME.has_stylebox(&"panel", &"Keycap"), "Keycap has a panel style")
	assert_true(THEME.has_stylebox(&"pressed", &"SpeedToggle"), "SpeedToggle has a lit pressed style")
	assert_true(THEME.has_color(&"font_color", &"ErrorLabel"), "ErrorLabel has its own colour")
	assert_true(THEME.has_stylebox(&"normal", &"LineEdit") and THEME.has_stylebox(&"focus", &"LineEdit"), "LineEdit has normal and focus styles")

	EventBus.settings_changed.connect(func(key: StringName, value: Variant) -> void: _got[key] = value)
	var tab: Control = TAB.instantiate()
	add_child(tab)
	await get_tree().process_frame
	var shake: OptionButton = tab.get_node("%Shake")
	assert_true(shake.item_count == 3, "shake has Normal / 50% / Off")
	shake.item_selected.emit(2)
	assert_true(_got.get(&"screen_shake") == 0.0 and _got.get(&"reduced_motion") == true, "shake Off sends screen_shake 0 and reduced_motion on")
	shake.item_selected.emit(1)
	assert_true(_got.get(&"screen_shake") == 0.5 and _got.get(&"reduced_motion") == false, "shake 50% sends 0.5 and reduced_motion off")
	var flash: CheckButton = tab.get_node("%ReduceFlash")
	flash.button_pressed = true
	assert_true(_got.get(&"reduce_flash") == true, "reduce flash sends reduce_flash on")

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)
