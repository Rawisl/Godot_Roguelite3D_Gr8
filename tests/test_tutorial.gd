extends Control
## First run tutorial with a fake BuildService and a scratch save. Press F6: the checks run first
## and print a summary, then click the window once and use the keys:
## 1: step 1, build the Arrow (Start wave grey). 2: step 2, build the Cannon. 3: step 3, start the
## wave (button ready). 4: step 4, fight. 5: the reminder after waiting. 6: Skip from step 2.
## 7: a run after the tutorial is done (no hint, button ready).
## Nothing here touches the real save.

const TEST_SAVE := "user://test_tutorial_save.json"

## Records what the tutorial asks to build and answers like BuildService.build().
class TutorialFakeBuilds:
	extends Node
	var calls: Array[Array] = []

	func build(slot_id: StringName, type: StringName, _level: int = 1) -> bool:
		calls.append([slot_id, type])
		EventBus.tower_built.emit(slot_id, type)
		return true

var _passed := 0
var _failed := 0
var _steps_done: Array[StringName] = []
var _completed := 0
var _fake := TutorialFakeBuilds.new()

@onready var _hint: TutorialHint = $TutorialHint
@onready var _service: TutorialService = _hint._service
@onready var _button: StartWaveButton = $StartWaveButton

func _ready() -> void:
	_fake.add_to_group(&"build_service")
	add_child(_fake)
	EventBus.tutorial_step_completed.connect(func(step: StringName) -> void: _steps_done.append(step))
	EventBus.tutorial_completed.connect(func() -> void: _completed += 1)
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	SaveManager.set_repository(LocalSaveRepository.new(TEST_SAVE))
	SaveManager.load_save()
	await get_tree().process_frame
	await _run_checks()
	print("test_tutorial: %d passed, %d failed" % [_passed, _failed])
	_new_run(false)

func _exit_tree() -> void:
	SaveManager.set_repository(LocalSaveRepository.new())
	SaveManager.load_save()
	for path in [TEST_SAVE, TEST_SAVE.get_basename() + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_new_run(false)
		KEY_2:
			_new_run(false)
			_build(GameConfig.starter_arrow_slot, &"arrow")
		KEY_3:
			_new_run(false)
			_build(GameConfig.starter_arrow_slot, &"arrow")
			_build(GameConfig.starter_cannon_slot, &"cannon")
		KEY_4:
			_new_run(false)
			_build(GameConfig.starter_arrow_slot, &"arrow")
			_build(GameConfig.starter_cannon_slot, &"cannon")
			EventBus.state_changed.emit(&"COMBAT")
		KEY_5:
			_new_run(false)
			_service.reminded.emit(_service.step)
		KEY_6:
			_new_run(false)
			_build(GameConfig.starter_arrow_slot, &"arrow")
			_hint._skip.pressed.emit()
		KEY_7:
			_new_run(true)

func _run_checks() -> void:
	# A new profile runs the tutorial.
	_new_run(false)
	_expect(_service.step == TutorialService.BUILD_ARROW and _hint.visible, "tutorial: a new profile starts at the Arrow")
	_expect(_hint._step.text == UiFormat.tr_fmt(&"tutorial.step", {"n": 1, "total": 4}) and _hint._action.text == tr(&"tutorial.build_arrow.action")
		and _hint._where.text == tr(&"tutorial.build_arrow.where"), "tutorial: the hint says step 1 of 4, what to do and where")
	_expect(not _hint._action.text.ends_with(".") and not _hint._where.text.ends_with("."), "tutorial: the hint lines end without a full stop")
	_expect(_visible_chips() == 1, "tutorial: the Arrow step shows the camera key")
	_expect(_button._lock_reason() == &"hud.start_wave.tutorial", "tutorial: Start wave is grey until both towers stand")

	_build(&"W1", &"cannon")
	_expect(_service.step == TutorialService.BUILD_ARROW, "tutorial: a tower on another slot does not count")
	_build(GameConfig.starter_arrow_slot, &"arrow")
	_expect(_service.step == TutorialService.BUILD_CANNON and _steps_done == [TutorialService.BUILD_ARROW], "tutorial: the Arrow moves on to the Cannon")
	_expect(not _flag_saved(), "tutorial: one tower is not enough to finish")
	_build(GameConfig.starter_cannon_slot, &"cannon")
	_expect(_service.step == TutorialService.START_WAVE and _flag_saved() and _completed == 1,
		"tutorial: both towers save tutorial_done right away, before the wave")
	_expect(_button._lock_reason() == &"", "tutorial: Start wave is ready once both towers stand")

	EventBus.state_changed.emit(&"COMBAT")
	_expect(_service.step == TutorialService.FIGHT and _hint._action.text == tr(&"tutorial.fight.action"), "tutorial: the wave start shows the fight hint")
	_expect(_visible_chips() == 3 and _dot_color(3) == TutorialHint.DOT_NOW and _dot_color(0) == TutorialHint.DOT_DONE,
		"tutorial: the fight step shows three keys and the last dot is the current one")
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 1.0, 0, false, false)
	_expect(_service.step == TutorialService.FIGHT, "tutorial: a kill by towers alone does not count")
	EventBus.enemy_died.emit(&"grunt", Vector3.ZERO, 1.0, 0, false, true)
	_expect(_service.step == TutorialService.OFF and not _hint.visible, "tutorial: a hit by the commander ends the hints")

	# The next run gets nothing.
	_new_run(true)
	_expect(not _hint.visible and _button._lock_reason() == &"", "tutorial: a run after it is done shows no hint and no lock")

	# Leaving before both towers: the next run starts over.
	_new_run(false)
	_build(GameConfig.starter_arrow_slot, &"arrow")
	_new_run(false)
	_expect(_service.step == TutorialService.BUILD_ARROW and not _flag_saved(), "tutorial: leaving before both towers runs it again")

	# Skip after the Arrow builds the Cannon.
	_build(GameConfig.starter_arrow_slot, &"arrow")
	_fake.calls.clear()
	_hint._skip.pressed.emit()
	_expect(_fake.calls == [[GameConfig.starter_cannon_slot, &"cannon"]], "tutorial: Skip builds only the missing tower on its slot")
	_expect(_flag_saved() and _service.step == TutorialService.OFF and not _hint.visible, "tutorial: Skip saves tutorial_done and hides the hint")

	# The first wave ending without a hit drops the fight hint.
	_new_run(false)
	_build(GameConfig.starter_arrow_slot, &"arrow")
	_build(GameConfig.starter_cannon_slot, &"cannon")
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.state_changed.emit(&"SUMMARY")
	_expect(_service.step == TutorialService.OFF, "tutorial: the fight hint ends with the first wave")

	# A build step that waits too long reminds.
	_new_run(false)
	var seconds := GameConfig.tutorial_remind_seconds
	GameConfig.tutorial_remind_seconds = 0.2
	# Headless frames advance the pausable clock slower than the wall clock, so wait on that clock.
	var start := TimeManager.pausable_real_time
	while TimeManager.pausable_real_time - start < 0.4:
		await get_tree().process_frame
	_expect(_hint._remind.visible and _hint.visible, "tutorial: a long wait shows the hint again with a reminder tag")
	GameConfig.tutorial_remind_seconds = seconds

## A run start with the flag as it would be in the save.
func _new_run(done: bool) -> void:
	SaveManager.get_section(SaveManager.FLAGS)["tutorial_done"] = done
	SaveManager.save_now()
	_button.tutorial_lock = false
	EventBus.state_changed.emit(&"PREP")
	EventBus.run_started.emit()

func _visible_chips() -> int:
	return _hint._keys.get_children().filter(func(c: Node) -> bool: return (c as Control).visible).size()

func _dot_color(index: int) -> Color:
	return (_hint._dots.get_child(index).get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color

func _build(slot_id: StringName, type: StringName) -> void:
	EventBus.tower_built.emit(slot_id, type)

## Reads the flag back from disk, so it checks what was written and not only memory.
func _flag_saved() -> bool:
	var repository := LocalSaveRepository.new(TEST_SAVE)
	var envelope := repository.load_data()
	return bool(envelope.get("data", {}).get("flags", {}).get("tutorial_done", false))

func _expect(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		push_error("test_tutorial FAILED: " + what)
