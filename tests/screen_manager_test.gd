extends Control
## Manual test for ScreenManager. Not shipped.
## F: fade-change scene   D: open a dummy dialog   T: toggle x3 time scale
## P: toggle pause        Esc / BackButton: should both call go_back()

const TARGET_SCENE := "res://tests/screen_manager_test.tscn"

static var _fade_start_ms: int = 0
var _back_count: int = 0

@onready var _back_button: Button = %BackButton

func _ready() -> void:
	# Keep receiving keys while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_back_button.text = "Back"
	_back_button.pressed.connect(go_back)
	if not ScreenManager.screen_changed.is_connected(_on_screen_changed):
		ScreenManager.screen_changed.connect(_on_screen_changed)
	print("[test] ready. time_scale=%s paused=%s" % [Engine.time_scale, get_tree().paused])
	if ScreenManager.is_fading():
		_wait_fade_end()


## Called by both Esc (via ScreenManager) and BackButton
func go_back() -> void:
	_back_count += 1
	print("[test] go_back called, count=%d, has_dialog=%s, fading=%s" % [_back_count, ScreenManager.has_dialog(), ScreenManager.is_fading()])

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F:
			_fade_start_ms = Time.get_ticks_msec()
			print("[test] change_scene start")
			ScreenManager.change_scene(TARGET_SCENE)
		KEY_D:
			var dialog := ColorRect.new()
			dialog.color = Color(0.2, 0.2, 0.6, 0.8)
			dialog.custom_minimum_size = Vector2(400, 200)
			dialog.set_anchors_preset(Control.PRESET_CENTER)
			ScreenManager.open_dialog(dialog)
			print("[test] dialog opened, has_dialog=%s, fading=%s" % [ScreenManager.has_dialog(), ScreenManager.is_fading()])
		KEY_T:
			Engine.time_scale = 3.0 if Engine.time_scale == 1.0 else 1.0
			print("[test] time_scale=%s" % Engine.time_scale)
		KEY_P:
			get_tree().paused = not get_tree().paused
			print("[test] paused=%s" % get_tree().paused)

func _on_screen_changed(scene_path: String) -> void:
	print("[test] swapped after %d ms -> %s" % [Time.get_ticks_msec() - _fade_start_ms, scene_path])

func _wait_fade_end() -> void:
	while ScreenManager.is_fading():
		if not is_inside_tree():
			return
		await get_tree().process_frame
	print("[test] fade done after %d ms (expect ~500)" % (Time.get_ticks_msec() - _fade_start_ms))
