extends Node
## Visual check of the boss phase and Enrage effects on the real corridor level, with the
## Bulwark model standing in front of the gate and the Frontline camera on it. Signals are sent
## by hand, so it works before a real boss wave. Not shipped.
## Keys: B armor break (TRANSITION, then EXPOSED after the transition time), E Enrage,
## R new boss (resets), F Reduced flashing on / off, P pause, 1 / 2 / 3 game speed.

const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const BULWARK_MODEL: PackedScene = preload("res://contents/assets/characters/enemy and boss/boss_bulwark_model.tscn")
const BOSS_AT := Vector3(-6, 0, 0)

var _level: Node3D
var _mgr: BossFxManager
var _boss: Node3D
var _label: Label
var _phase := &"ARMORED"
var _exposed_at := -1.0
var _reduce_flash := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level = LEVEL_SCENE.instantiate()
	add_child(_level)
	_mgr = _level.get_node("BossFxManager") as BossFxManager
	var cam := (_level.get_node("CameraRig") as CameraRig).find_child("*", true, false) as Camera3D
	cam.current = true
	# The Frontline camera follows the commander, so a stand-in on the boss frames it up close.
	var commander := Node3D.new()
	commander.add_to_group(&"commander")
	_level.add_child(commander)
	commander.global_position = BOSS_AT

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override(&"font_size", 20)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	layer.add_child(_label)

	await get_tree().process_frame
	_new_boss()


func _new_boss() -> void:
	if _boss != null:
		_boss.queue_free()
		_boss.remove_from_group(&"boss")
	_boss = Node3D.new()
	_boss.name = "FakeBulwark"
	_boss.add_to_group(&"boss")
	var model := BULWARK_MODEL.instantiate() as Node3D
	_boss.add_child(model)
	_level.add_child(_boss)
	_boss.global_position = BOSS_AT
	# Face the camera side of the corridor a little, so the chest core is in view.
	_boss.rotation.y = deg_to_rad(35)
	for ap: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
		ap.play(&"general/Idle_A")
	_phase = &"ARMORED"
	_exposed_at = -1.0
	EventBus.boss_spawned.emit()
	EventBus.boss_phase_changed.emit(_phase)


func _process(_delta: float) -> void:
	if _exposed_at >= 0.0 and TimeManager.game_time >= _exposed_at:
		_exposed_at = -1.0
		_phase = &"EXPOSED"
		EventBus.boss_phase_changed.emit(_phase)
	_label.text = "\n".join(PackedStringArray([
		"Phase: %s   Enraged: %s" % [_phase, "yes" if _mgr.is_enraged() else "no"],
		"Core: %s   glow %.2f" % ["lit" if _mgr.is_core_lit() else "dark", _mgr.get_core_energy()],
		"Speed: x%d   %s   Reduced flashing: %s" % [TimeManager.get_time_scale(),
			"PAUSED" if TimeManager.is_paused else "running", "on" if _reduce_flash else "off"],
		"",
		"B armor break   E Enrage   R new boss   F reduced flashing   P pause   1/2/3 speed",
	]))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_B:
			if _phase == &"ARMORED":
				_phase = &"TRANSITION"
				EventBus.boss_phase_changed.emit(_phase)
				_exposed_at = TimeManager.game_time + GameConfig.boss_transition_time
		KEY_E:
			EventBus.boss_enraged.emit()
		KEY_R:
			_new_boss()
		KEY_F:
			_reduce_flash = not _reduce_flash
			EventBus.settings_changed.emit(&"reduce_flash", _reduce_flash)
		KEY_P:
			if TimeManager.is_paused:
				TimeManager.release_pause(TimeManager.REASON_USER)
			else:
				TimeManager.request_pause(TimeManager.REASON_USER)
		KEY_1, KEY_2, KEY_3:
			TimeManager.set_time_scale((event as InputEventKey).physical_keycode - KEY_0)
		_:
			return
	get_viewport().set_input_as_handled()
