extends Node
## Visual check of the boss intro camera on the real corridor level. It loops
## PREP -> BOSS_INTRO -> BOSS_COMBAT with fake state signals, so it works before the wave
## manager sends BOSS_INTRO. The Bulwark model stands on BossSpawnPoint and a fox stands in
## for the commander. Not shipped.
## Keys: Space restart the loop, S skip the intro (after 1 s, like the game), Tab Frontline /
## Commander, P pause, 1 / 2 / 3 game speed, R reduced motion on / off.

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const BULWARK_MODEL: PackedScene = preload("res://contents/assets/characters/enemy and boss/boss_bulwark_model.tscn")
const FOX_MODEL: PackedScene = preload("res://contents/assets/characters/fox_commander/fox_commander_model.tscn")
const PREP_TIME := 1.5
const COMBAT_TIME := 2.5
const COMMANDER_AT := Vector3(-8, 0, 3)

var _level: Node3D
var _rig: CameraRig
var _camera: Camera3D
var _label: Label
var _state := &""
var _state_start := 0.0
var _commander_mode := false
var _reduced := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	_rig = _level.get_node("CameraRig") as CameraRig
	_camera = _rig.find_child("*", true, false) as Camera3D
	_camera.current = true

	var commander := Node3D.new()
	commander.name = "FakeCommander"
	commander.add_to_group(&"commander")
	_level.add_child(commander)
	commander.global_position = COMMANDER_AT
	_add_model(commander, FOX_MODEL, Vector3.RIGHT)

	var spawn := _level.get_node("Markers/BossSpawnPoint") as Node3D
	var boss := Node3D.new()
	boss.name = "FakeBulwark"
	_level.add_child(boss)
	boss.global_position = spawn.global_position
	_add_model(boss, BULWARK_MODEL, Vector3.LEFT)

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override(&"font_size", 20)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)

	await get_tree().process_frame
	_go(&"PREP")


func _add_model(parent: Node3D, scene: PackedScene, facing: Vector3) -> void:
	var model := scene.instantiate() as Node3D
	parent.add_child(model)
	model.look_at(model.global_position - facing, Vector3.UP)
	for ap: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		for anim in ap.get_animation_list():
			if anim.contains("Idle"):
				ap.play(anim)
				return


func _go(state: StringName) -> void:
	if _state == &"BOSS_INTRO":
		var boss := _rig.get_boss_focus()
		print("[view] intro ended after %.1f s, camera %.2f m from the boss" % [
			TimeManager.game_time - _state_start, Vector2(_rig.position.x - boss.x, _rig.position.z - boss.z).length()])
	_state = state
	_state_start = TimeManager.game_time
	EventBus.state_changed.emit(state)


func _process(_delta: float) -> void:
	var t := TimeManager.game_time - _state_start
	match _state:
		&"PREP":
			if t >= PREP_TIME:
				_go(&"BOSS_INTRO")
		&"BOSS_INTRO":
			if t >= GameConfig.boss_intro_duration:
				_go(&"BOSS_COMBAT")
		&"BOSS_COMBAT":
			if t >= COMBAT_TIME:
				_go(&"PREP")
	_refresh(t)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_SPACE:
			_go(&"PREP")
		KEY_S:
			if _state == &"BOSS_INTRO" and TimeManager.game_time - _state_start >= GameConfig.boss_intro_skip_delay:
				_go(&"BOSS_COMBAT")
		KEY_TAB:
			_commander_mode = not _commander_mode
			EventBus.mode_changed.emit(&"COMMANDER" if _commander_mode else &"FRONTLINE")
		KEY_P:
			if TimeManager.is_paused:
				TimeManager.release_pause(TimeManager.REASON_USER)
			else:
				TimeManager.request_pause(TimeManager.REASON_USER)
		KEY_1, KEY_2, KEY_3:
			TimeManager.set_time_scale((event as InputEventKey).physical_keycode - KEY_0)
		KEY_R:
			_reduced = not _reduced
			EventBus.settings_changed.emit(&"reduced_motion", _reduced)
		_:
			return
	get_viewport().set_input_as_handled()


func _refresh(t: float) -> void:
	var boss := _rig.get_boss_focus()
	var gap := Vector2(_rig.position.x - boss.x, _rig.position.z - boss.z).length()
	var lines: PackedStringArray = [
		"State: %s   %.1f s game time" % [_state, t],
		"Mode: %s   Speed: x%d   %s   Reduced motion: %s" % [
			"Commander" if _commander_mode else "Frontline", TimeManager.get_time_scale(),
			"PAUSED" if TimeManager.is_paused else "running", "on" if _reduced else "off"],
		"Camera focus: (%.1f, %.1f)   size %.1f   %.2f m from the boss" % [
			_rig.position.x, _rig.position.z, _camera.size, gap],
		"Intro pan: %s" % ("yes" if _rig.is_in_boss_intro() else "no"),
		"",
		"Space restart   S skip intro   Tab mode   P pause   1/2/3 speed   R reduced motion",
	]
	_label.text = "\n".join(lines)
