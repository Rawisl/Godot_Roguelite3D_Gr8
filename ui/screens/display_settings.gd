class_name DisplaySettings
extends RefCounted
## Applies the window settings of the Graphics tab. GameState calls apply() for every
## settings_changed, so a value loaded from settings.cfg at start works the same as a change.
##   window_mode: WINDOWED or FULLSCREEN
##   resolution: Vector2i, the window size while windowed
##   vsync: bool
##   max_fps: 0 for no limit

const WINDOWED := 0
const FULLSCREEN := 1
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const FPS_LIMITS: Array[int] = [60, 120, 0]
const DEFAULTS := {
	&"window_mode": WINDOWED,
	&"resolution": Vector2i(1280, 720),
	&"vsync": true,
	&"max_fps": 0,
}

static func apply(key: StringName, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	# settings.cfg is a text file a player can edit: an unknown value is left alone.
	if not is_valid(key, value):
		push_warning("DisplaySettings: %s = %s is not a valid value, ignored" % [key, value])
		return
	if key == &"max_fps":
		Engine.max_fps = maxi(int(value), 0)
		return
	# No window to change when running headless (tests, CI).
	if DisplayServer.get_name() == "headless":
		return
	match key:
		&"window_mode":
			var fullscreen := int(value) == FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
			if not fullscreen:
				_apply_size(GameState.get_setting(&"resolution", DEFAULTS[&"resolution"]))
		&"resolution":
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				_apply_size(value)
		&"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)

## Current value of a window setting: the one set last and valid, or the default.
static func current(key: StringName) -> Variant:
	var value: Variant = GameState.get_setting(key, DEFAULTS.get(key))
	return value if is_valid(key, value) else DEFAULTS.get(key)

static func is_valid(key: StringName, value: Variant) -> bool:
	match key:
		&"window_mode":
			return (value is int) and (value == WINDOWED or value == FULLSCREEN)
		&"resolution":
			return value is Vector2i and RESOLUTIONS.has(value)
		&"vsync":
			return value is bool
		&"max_fps":
			return (value is int) and FPS_LIMITS.has(value)
	return true

static func _apply_size(size: Variant) -> void:
	if not size is Vector2i:
		return
	DisplayServer.window_set_size(size)
	# Keep the window on the screen it is on, centred.
	var screen := DisplayServer.window_get_current_screen()
	var origin := DisplayServer.screen_get_position(screen)
	var free_space := DisplayServer.screen_get_size(screen) - (size as Vector2i)
	DisplayServer.window_set_position(origin + free_space / 2)
