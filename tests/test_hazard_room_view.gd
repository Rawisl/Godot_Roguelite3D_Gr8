extends Node
## Visual check of the Hazard Trial room on the real corridor level: the real CameraRig cutting to
## the room's fixed frame and back to PREP, the painted backdrop, the room light and the
## rocks drifting clockwise around the island.
## Signals are sent by hand, so it works before the Hazard Trial wave state exists. Not shipped.
## Keys: E enter / leave the room (hazard_trial_entered / exited), P pause, 1 / 2 / 3 game speed,
## Up / Down rock speed. In the room the move keys and C must not move the camera.

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")

var _level: Node3D
var _room: HazardRoom
var _rocks: FloatingRocks
var _rig: CameraRig
var _label: Label
var _inside := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	_rig = _level.get_node("CameraRig") as CameraRig
	(_rig.get_node("Camera3D") as Camera3D).current = true
	_room = _level.get_node("HazardRoom") as HazardRoom
	_rocks = _room.get_node("FloatingRocks") as FloatingRocks

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_color_override(&"font_color", Color.WHITE)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)

	EventBus.state_changed.emit(&"PREP")
	set_inside(true)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_E:
			set_inside(not _inside)
		KEY_P:
			get_tree().paused = not get_tree().paused
		KEY_1:
			Engine.time_scale = 1.0
		KEY_2:
			Engine.time_scale = 2.0
		KEY_3:
			Engine.time_scale = 3.0
		KEY_UP:
			_rocks.orbit_speed_deg += 1.0
		KEY_DOWN:
			_rocks.orbit_speed_deg = maxf(_rocks.orbit_speed_deg - 1.0, 0.0)


func _process(_delta: float) -> void:
	_label.text = "Hazard room view\nE in the room: %s   camera frame: %s   P pause: %s   1/2/3 speed: x%d\nUp/Down rock speed: %.0f deg/s (clockwise)" % [
		"yes" if _inside else "no", _rig.get_frame(), "on" if get_tree().paused else "off",
		int(Engine.time_scale), _rocks.orbit_speed_deg]


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


## Enters or leaves the room the way the wave side will: the signal, then PREP on the way out.
func set_inside(on: bool) -> void:
	_inside = on
	if on:
		EventBus.hazard_trial_entered.emit(1, [])
	else:
		EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
		EventBus.state_changed.emit(&"PREP")
