class_name TutorialService
extends Node
## First run tutorial, once per account: build the Arrow, then the Cannon, then start the wave,
## then hit an enemy. It never changes the wave script or any stat, and only the Start wave button
## waits for it (until both towers stand). tutorial_done is saved as soon as both towers are
## built, before the wave starts, so leaving earlier runs the tutorial again next time. Skip is
## always there and builds the missing towers on their default slots, like the next runs get them.
# TODO(kiezroth): add BuildService.build_starter(slot_id, type) for the free starter tower (level 1, invested_gold 0, is_starter, sell lock) and make a click on a starter slot use it while the tutorial runs; until then the player pays the normal price and Skip falls back to build().
# TODO(kiezroth): while is_active() and the step is build_arrow or build_cannon, light only that step's starter slot and lock the others.

signal step_changed(step: StringName)
## The step waited too long without progress, so the hint is shown again.
signal reminded(step: StringName)

const BUILD_ARROW := &"build_arrow"
const BUILD_CANNON := &"build_cannon"
const START_WAVE := &"start_wave"
const FIGHT := &"fight"
const OFF := &""
## The steps the player is told about, in order; the hint shows "step n of this many".
const STEPS: Array[StringName] = [BUILD_ARROW, BUILD_CANNON, START_WAVE, FIGHT]
const ARROW := &"arrow"
const CANNON := &"cannon"

var step: StringName = OFF
## Starter slot -> tower type, read from GameConfig when the tutorial starts.
var _starters: Dictionary[StringName, StringName] = {}
var _built: Dictionary[StringName, bool] = {}
var _step_since := 0.0

func _ready() -> void:
	add_to_group(&"tutorial")
	EventBus.run_started.connect(begin_if_needed)
	EventBus.tower_built.connect(_on_tower_built)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.enemy_died.connect(_on_enemy_died)
	set_process(false)

func _process(_delta: float) -> void:
	if step not in [BUILD_ARROW, BUILD_CANNON]:
		return
	if TimeManager.pausable_real_time - _step_since >= GameConfig.tutorial_remind_seconds:
		_step_since = TimeManager.pausable_real_time
		reminded.emit(step)

## Starts the tutorial for a profile that has not finished it. A run started after it was done
## (on this machine or synced from the account) gets the starter towers instead.
func begin_if_needed() -> void:
	if bool(SaveManager.get_section(SaveManager.FLAGS).get("tutorial_done", false)):
		_set_step(OFF)
		return
	_starters = {GameConfig.starter_arrow_slot: ARROW, GameConfig.starter_cannon_slot: CANNON}
	_built.clear()
	_set_step(BUILD_ARROW)

func is_active() -> bool:
	return step != OFF

## The Start wave button stays grey until both towers stand.
func is_wave_locked() -> bool:
	return step == BUILD_ARROW or step == BUILD_CANNON

## The index of the current step from 1, for "step n of m".
func step_number() -> int:
	return STEPS.find(step) + 1

## Builds what is missing on the default slots, saves tutorial_done and hides every hint.
# TODO(kiezroth): with build_starter() missing and no starting gold, Skip builds nothing yet still saves tutorial_done, so that run starts without towers; build_starter() fixes it.
func skip() -> void:
	if not is_active():
		return
	for slot_id: StringName in _starters:
		if not _built.get(slot_id, false):
			_build_starter(slot_id, _starters[slot_id])
	_finish_building()
	_set_step(OFF)

func _build_starter(slot_id: StringName, type: StringName) -> void:
	var service := get_tree().get_first_node_in_group(&"build_service")
	if service == null:
		return
	if service.has_method(&"build_starter"):
		service.call(&"build_starter", slot_id, type)
	else:
		service.call(&"build", slot_id, type)

func _on_tower_built(slot_id: StringName, type: StringName) -> void:
	if not is_wave_locked() or _starters.get(slot_id, &"") != type:
		return
	_built[slot_id] = true
	EventBus.tutorial_step_completed.emit(step)
	if _built.size() < _starters.size():
		_set_step(BUILD_CANNON if type == ARROW else BUILD_ARROW)
		return
	_finish_building()
	_set_step(START_WAVE)

## Saved right away, before the wave starts, so a run left after this point does not repeat it.
func _finish_building() -> void:
	SaveManager.mark_tutorial_done()

func _on_state_changed(new_state: StringName) -> void:
	if step == START_WAVE and new_state == &"COMBAT":
		EventBus.tutorial_step_completed.emit(START_WAVE)
		_set_step(FIGHT)
	elif step == FIGHT and new_state not in [&"COMBAT", &"BOSS_COMBAT"]:
		# The first wave ended without a hit: the hint is not carried into the next PREP.
		_set_step(OFF)

func _on_enemy_died(_type: StringName, _position: Vector3, _gold: float, _prestige: int, is_cull: bool, hit_by_commander: bool) -> void:
	if step == FIGHT and hit_by_commander and not is_cull:
		EventBus.tutorial_step_completed.emit(FIGHT)
		_set_step(OFF)

func _set_step(new_step: StringName) -> void:
	step = new_step
	_step_since = TimeManager.pausable_real_time
	set_process(is_wave_locked())
	step_changed.emit(step)
