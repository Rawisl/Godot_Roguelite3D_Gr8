extends Node
## Visual check of the Hazard Trial room on the real corridor level: the fixed room camera, the
## painted backdrop, the room light and the rocks drifting clockwise around the island.
## Signals are sent by hand, so it works before the Hazard Trial wave state exists. Not shipped.
## Keys: E room light on / off (hazard_trial_entered / exited), P pause, 1 / 2 / 3 game speed,
## Up / Down rock speed, C corridor view / room view.

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
## Camera position from its focus, as CameraBounds.camera_offset.
const CAMERA_OFFSET := Vector3(7.255, 21.213, 19.934)

var _level: Node3D
var _room: HazardRoom
var _rocks: FloatingRocks
var _cam: Camera3D
var _label: Label
var _inside := false
var _room_view := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	# The rig would pull the camera back to the corridor; this test places it by hand.
	var rig := _level.get_node("CameraRig")
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	_cam = rig.get_node("Camera3D") as Camera3D
	_cam.current = true
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

	_set_light(true)
	_place_camera()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_E:
			_set_light(not _inside)
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
		KEY_C:
			_room_view = not _room_view
			_place_camera()


func _process(_delta: float) -> void:
	_label.text = "Hazard room view\nE room light: %s   P pause: %s   1/2/3 speed: x%d\nUp/Down rock speed: %.0f deg/s (clockwise)   C view: %s" % [
		"on" if _inside else "off", "on" if get_tree().paused else "off", int(Engine.time_scale),
		_rocks.orbit_speed_deg, "room" if _room_view else "corridor"]


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false


func _place_camera() -> void:
	var focus := _room.get_camera_focus() if _room_view else Vector3.ZERO
	_cam.global_position = focus + CAMERA_OFFSET
	_cam.size = _room.camera_size if _room_view else 23.5


func _set_light(on: bool) -> void:
	_inside = on
	if on:
		EventBus.hazard_trial_entered.emit(1, [])
	else:
		EventBus.hazard_trial_exited.emit(&"LEFT", 0, 0, 0.0, 0)
