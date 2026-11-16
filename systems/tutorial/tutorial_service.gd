class_name TutorialService
extends Node
## First run tutorial, once per account: build the Arrow, then the Cannon, then start the wave,
## then hit an enemy. It never changes the wave script or any stat, and only the Start wave button
## waits for it (until both towers stand). tutorial_done is saved as soon as both towers are
## built, before the wave starts, so leaving earlier runs the tutorial again next time. Skip is
## always there and builds the missing towers on their default slots, like the next runs get them.
## It sits with the other run systems in main.tscn; the HUD hint only shows what it says.
# TODO(kiezroth): add BuildService.build_starter(slot_id, type) for the free starter tower (level 1, invested_gold 0, is_starter, sell lock) and make a click on a starter slot use it while the tutorial runs. Until it exists the player pays the normal price, and Skip only hides the hints for this run without saving tutorial_done, so a run never starts without its towers.
# TODO(kiezroth): while is_active() and the step is build_arrow or build_cannon, light only that step's starter slot and lock the others; then count a build only on its starter slot (now any Arrow or Cannon counts, so a build on another cell never leaves the step stuck).

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
## Tower type -> the step that asks for it.
const BUILD_STEPS := {ARROW: BUILD_ARROW, CANNON: BUILD_CANNON}

var step: StringName = OFF
## Tower type -> its default slot, read from GameConfig when the tutorial starts.
var _starters: Dictionary[StringName, StringName] = {}
## Tower types already built in this tutorial.
var _built: Dictionary[StringName, bool] = {}
var _step_since := 0.0

func _ready() -> void:
	add_to_group(&"tutorial")
	EventBus.run_started.connect(begin_if_needed)
	EventBus.tower_built.connect(_on_tower_built)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.enemy_spawned.connect(_on_enemy_spawned)
	set_process(false)

func _process(_delta: float) -> void:
	if step not in [BUILD_ARROW, BUILD_CANNON]:
		return
	if TimeManager.pausable_real_time - _step_since >= GameConfig.tutorial_remind_seconds:
		_step_since = TimeManager.pausable_real_time
		reminded.emit(step)

## Starts the tutorial for a profile that has not finished it, on a run from the first wave. A run
## started after it was done (on this machine or synced from the account) gets the starter towers.
func begin_if_needed() -> void:
	if bool(SaveManager.get_section(SaveManager.FLAGS).get("tutorial_done", false)) or _start_wave() > 1:
		_set_step(OFF)
		return
	_starters = {ARROW: GameConfig.starter_arrow_slot, CANNON: GameConfig.starter_cannon_slot}
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

## Builds what is missing on the default slots, saves tutorial_done and hides every hint. Without
## a free starter build the towers cannot be paid for, so the flag is not saved and the tutorial
## comes back next run.
func skip() -> void:
	if not is_active():
		return
	if _can_build_starters():
		for type: StringName in _starters:
			if not _built.get(type, false):
				_build_service().call(&"build_starter", _starters[type], type)
		_finish_building()
	_set_step(OFF)

func _can_build_starters() -> bool:
	var service := _build_service()
	return service != null and service.has_method(&"build_starter")

func _build_service() -> Node:
	return get_tree().get_first_node_in_group(&"build_service")

func _start_wave() -> int:
	var run_state := get_tree().get_first_node_in_group(&"run_state")
	return int(run_state.get(&"start_wave")) if run_state != null else 1

func _on_tower_built(_slot_id: StringName, type: StringName) -> void:
	if not is_wave_locked() or not _starters.has(type) or _built.get(type, false):
		return
	_built[type] = true
	EventBus.tutorial_step_completed.emit(BUILD_STEPS[type])
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

func _on_enemy_spawned(node: Node) -> void:
	var enemy := node as Enemy
	if enemy != null and enemy.health != null:
		enemy.health.damaged.connect(_on_enemy_damaged)

## Any commander hit counts, not only a kill.
func _on_enemy_damaged(_amount: int, info: DamageInfo) -> void:
	if step == FIGHT and info != null and info.hit_by_commander:
		EventBus.tutorial_step_completed.emit(FIGHT)
		_set_step(OFF)

func _set_step(new_step: StringName) -> void:
	step = new_step
	_step_since = TimeManager.pausable_real_time
	set_process(is_wave_locked())
	step_changed.emit(step)
