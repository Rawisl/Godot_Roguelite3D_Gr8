extends CanvasLayer
## Cheat panel of the test run scene, shown and hidden with PageUp. Finds every system by group
## when a button is pressed, so it never keeps a stale node.

## Gold added by one press.
@export var gold_amount: int = 10000
## Seconds between two passes that make new towers invulnerable too and put back the instant
## kill bonus when the commander's stats are reset (for example by the hazard room).
@export var invincible_refresh_interval: float = 0.5
## Damage of commander sword hits and skills is multiplied by this while instant kill is on.
@export var instant_kill_mult: float = 1000.0
## Bosses the summon list offers next to the plain enemies, by BossData id.
@export var summon_boss_ids: Array[StringName] = [&"skeletal_centipede"]

const ENEMY_DIR := "res://entities/enemy/"
const BASE_ENEMY_SCENE := "enemy.tscn"
## Stat block source of the instant kill bonus, so switching it off removes only this bonus.
const INSTANT_KILL_SOURCE := &"cheat_instant_kill"
const INSTANT_KILL_STATS: Array[StringName] = [&"sword_damage", &"skill_damage"]
## Added on top of the missing XP when float rounding leaves the commander just short of the level.
const XP_TOP_UP := 0.001

@onready var title_label: Label = %Title
@onready var invincible_check: CheckButton = %InvincibleCheck
@onready var heal_button: Button = %HealButton
@onready var gold_button: Button = %GoldButton
@onready var level_button: Button = %LevelButton
@onready var instant_kill_check: CheckButton = %InstantKillCheck
@onready var summon_option: OptionButton = %SummonOption
@onready var summon_button: Button = %SummonButton
@onready var skill_option: OptionButton = %SkillOption
@onready var slot_option: OptionButton = %SlotOption
@onready var skill_button: Button = %SkillButton
@onready var jump_label: Label = %JumpLabel
@onready var jump_spin: SpinBox = %JumpSpin
@onready var jump_button: Button = %JumpButton
@onready var hint_label: Label = %Hint

var _invincible := false
var _instant_kill := false
var _summon_scenes: Array[PackedScene] = []
## Ids in the skill list that are stat cards, which take no slot.
var _stat_ids: Array[StringName] = []
## False while the skill list was built without the reward pool.
var _list_has_pool := false
var _refresh_timer: Timer


func _ready() -> void:
	title_label.text = tr(&"debug.cheat.title")
	invincible_check.text = tr(&"debug.cheat.invincible")
	heal_button.text = tr(&"debug.cheat.heal_full")
	gold_button.text = tr(&"debug.cheat.add_gold").format({"value": gold_amount})
	level_button.text = tr(&"debug.cheat.add_level")
	instant_kill_check.text = tr(&"debug.cheat.instant_kill")
	summon_button.text = tr(&"debug.cheat.summon")
	skill_button.text = tr(&"debug.cheat.add_skill")
	jump_label.text = tr(&"debug.cheat.jump_label")
	jump_button.text = tr(&"debug.cheat.jump_wave")
	_disable_focus()

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = invincible_refresh_interval
	_refresh_timer.one_shot = false
	_refresh_timer.timeout.connect(_on_refresh_timeout)
	add_child(_refresh_timer)

	invincible_check.toggled.connect(set_invincible)
	heal_button.pressed.connect(heal_all)
	gold_button.pressed.connect(add_gold)
	level_button.pressed.connect(add_level)
	instant_kill_check.toggled.connect(set_instant_kill)
	summon_button.pressed.connect(_on_summon_pressed)
	skill_button.pressed.connect(_on_skill_pressed)
	jump_button.pressed.connect(_on_jump_pressed)

	_build_summon_list()
	_build_skill_list()
	_build_slot_list()
	skill_option.item_selected.connect(_on_skill_selected)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.run_ended.connect(_on_run_ended)
	refresh()


func _exit_tree() -> void:
	if EventBus.state_changed.is_connected(_on_state_changed):
		EventBus.state_changed.disconnect(_on_state_changed)
	if EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.disconnect(_on_run_ended)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != KEY_PAGEUP:
		return
	toggle_panel()
	get_viewport().set_input_as_handled()


func toggle_panel() -> void:
	visible = not visible
	if visible:
		refresh()


## Makes the Fortress, the commander and every tower take no damage until switched off.
func set_invincible(on: bool) -> void:
	_invincible = on
	invincible_check.set_pressed_no_signal(on)
	_apply_invincible()
	_update_refresh_timer()


## Multiplies the commander's sword and skill damage so a single hit kills, until switched off.
func set_instant_kill(on: bool) -> void:
	_instant_kill = on
	instant_kill_check.set_pressed_no_signal(on)
	_apply_instant_kill()
	_update_refresh_timer()


## Refills Fortress, commander and tower HP. Returns how many of them gained HP.
func heal_all() -> int:
	var healed := 0
	for target in _invincible_targets():
		var health := target.get(&"health") as HealthComponent
		if health == null:
			continue
		var before := health.hp
		if target.is_in_group(&"tower"):
			target.restore_full_hp()
		else:
			health.heal(health.max_hp)
		if health.hp > before:
			healed += 1
	return healed


func add_gold() -> void:
	var gold_manager := _gold_manager()
	if gold_manager == null:
		return
	_add_gold_without_earned_count(gold_manager, gold_amount)


## Raises the commander by one level through the real XP path. Returns true when a level was gained.
func add_level() -> bool:
	var tracker := get_tree().get_first_node_in_group(&"xp_tracker") as XpTracker
	if tracker == null:
		return false
	var level_before := tracker.commander_level
	var need := float(tracker.stats.get_xp_to_level(level_before + 1)) - tracker.xp
	tracker.add_xp(maxf(need, XP_TOP_UP))
	if tracker.commander_level == level_before:
		tracker.add_xp(XP_TOP_UP)
	return tracker.commander_level > level_before


## Adds one scaled enemy to the running wave without touching the spawn queue.
func summon(scene: PackedScene) -> Node:
	var wm := _wave_manager()
	if scene == null or wm == null:
		return null
	var run_state := _run_state()
	if run_state != null and run_state.is_run_ended():
		return null
	if wm.wave_state != Enums.WaveState.COMBAT and wm.wave_state != Enums.WaveState.BOSS_COMBAT:
		return null
	var enemy := scene.instantiate() as Enemy
	if enemy == null:
		return null
	enemy.position = wm.random_spawn_zone_point()
	enemy.spawn_grace = true
	enemy.is_in_spawn_zone = true
	var wave := wm.current_wave
	wm.apply_wave_scale_to(enemy, wave)
	var boss_data := enemy.data as BossData
	# The boss id first, so the boss bar names this boss instead of the first one it knows.
	if boss_data != null:
		EventBus.boss_intro_started.emit(boss_data.id)
	if wm.enemy_container != null and is_instance_valid(wm.enemy_container):
		wm.enemy_container.add_child(enemy)
	else:
		wm.add_child(enemy)
	wm.enemies_alive += 1
	wm.total_wave_enemies += 1
	EventBus.enemy_spawned.emit(enemy)
	EventBus.enemy_count_changed.emit(wm.enemies_alive, wm.spawn_queue.size(), wm.total_wave_enemies)
	# Lets the boss bar and the boss effects attach to it, as for a boss the wave spawns.
	if boss_data != null:
		EventBus.boss_spawned.emit()
	return enemy


## Restarts PREP at the given wave. Only allowed during PREP of a run that is still going.
func jump_to_wave(wave: int) -> bool:
	var wm := _wave_manager()
	var run_state := _run_state()
	if wm == null or run_state == null:
		return false
	if run_state.is_run_ended() or wave < 1:
		return false
	if wm.wave_state != Enums.WaveState.PREP:
		return false
	wm.current_wave = wave
	run_state.waves_cleared = wave - 1
	wm.start_prep()
	return true


## Asks the reward service to give a card as if it were picked, without using a pick: it goes into
## slot_index of its group (0..2, replacing what sits there) and levels up by one. Stat cards ignore
## the slot. Returns false when the run has ended, otherwise true once the request is sent.
func add_skill(skill_id: StringName, slot_index: int) -> bool:
	var run_state := _run_state()
	if run_state != null and run_state.is_run_ended():
		return false
	EventBus.skill_grant_requested.emit(skill_id, slot_index)
	return true


## Every control the player can click. Used to keep focus off them.
func get_clickable_controls() -> Array[Control]:
	return [invincible_check, heal_button, gold_button, level_button, instant_kill_check,
		summon_option, summon_button, skill_option, slot_option, skill_button, jump_spin, jump_spin.get_line_edit(), jump_button]


func get_summon_scenes() -> Array[PackedScene]:
	return _summon_scenes.duplicate()


## Enables each control for the current wave phase and updates the hint line.
func refresh() -> void:
	# The reward service may enter the tree after the panel, so the list is built again once it is there.
	if not _list_has_pool and get_tree().get_first_node_in_group(&"reward_service") != null:
		_build_skill_list()
	var wm := _wave_manager()
	var run_state := _run_state()
	var ended := run_state != null and run_state.is_run_ended()
	var state: Enums.WaveState = wm.wave_state if wm != null else Enums.WaveState.PREP
	var combat := state == Enums.WaveState.COMBAT or state == Enums.WaveState.BOSS_COMBAT
	var prep := state == Enums.WaveState.PREP
	invincible_check.disabled = ended
	heal_button.disabled = ended
	gold_button.disabled = ended
	level_button.disabled = ended
	instant_kill_check.disabled = ended
	summon_button.disabled = ended or not combat or _summon_scenes.is_empty()
	summon_option.disabled = summon_button.disabled
	skill_button.disabled = ended or skill_option.item_count == 0
	skill_option.disabled = skill_button.disabled
	slot_option.disabled = skill_button.disabled or _selected_is_stat()
	jump_button.disabled = ended or not prep
	jump_spin.editable = not ended and prep
	hint_label.text = tr(_hint_key(ended, prep, combat))


func _hint_key(ended: bool, prep: bool, combat: bool) -> StringName:
	if ended:
		return &"debug.cheat.hint_ended"
	if prep:
		return &"debug.cheat.hint_prep"
	if combat:
		return &"debug.cheat.hint_combat"
	return &"debug.cheat.hint_other"


func _on_state_changed(_new_state: StringName) -> void:
	refresh()


func _on_run_ended(_end_type: StringName, _summary: Dictionary) -> void:
	refresh()


func _on_summon_pressed() -> void:
	var index := summon_option.selected
	if index < 0 or index >= _summon_scenes.size():
		return
	summon(_summon_scenes[index])


func _on_skill_pressed() -> void:
	var index := skill_option.selected
	if index < 0 or index >= skill_option.item_count:
		return
	add_skill(skill_option.get_item_metadata(index), maxi(slot_option.selected, 0))


func _on_skill_selected(_index: int) -> void:
	refresh()


func _selected_is_stat() -> bool:
	var index := skill_option.selected
	if index < 0 or index >= skill_option.item_count:
		return false
	return _stat_ids.has(skill_option.get_item_metadata(index))


func _on_jump_pressed() -> void:
	jump_to_wave(int(jump_spin.value))


## During a run GameState drops focus as soon as a control takes it, which cancels a press
## that has not been released yet. Like the HUD buttons, the panel never takes focus.
func _disable_focus() -> void:
	for control in get_clickable_controls():
		control.focus_mode = Control.FOCUS_NONE


func _update_refresh_timer() -> void:
	if _invincible or _instant_kill:
		_refresh_timer.start()
		return
	_refresh_timer.stop()


func _on_refresh_timeout() -> void:
	_apply_invincible()
	_apply_instant_kill()


## Puts the bonus on the commander's stat block, or removes it. Only writes when the bonus is
## missing, so the stat block does not report a change on every refresh.
func _apply_instant_kill() -> void:
	var commander := get_tree().get_first_node_in_group(&"commander")
	if commander == null:
		return
	var block := commander.get(&"stat_block") as StatBlock
	if block == null:
		return
	if not _instant_kill:
		block.clear_source(INSTANT_KILL_SOURCE)
		return
	if _has_instant_kill_bonus(block):
		return
	for stat_key in INSTANT_KILL_STATS:
		block.set_mul(stat_key, INSTANT_KILL_SOURCE, instant_kill_mult - 1.0)


func _has_instant_kill_bonus(block: StatBlock) -> bool:
	var mul: Dictionary = block.export_state()["mul"]
	for stat_key in INSTANT_KILL_STATS:
		var sources: Dictionary = mul.get(stat_key, {})
		if not sources.has(INSTANT_KILL_SOURCE):
			return false
	return true


## Sets the flag on every target; towers built later are caught by the refresh timer.
func _apply_invincible() -> void:
	for target in _invincible_targets():
		var health := target.get(&"health") as HealthComponent
		if health != null:
			health.invulnerable = _invincible


func _invincible_targets() -> Array[Node]:
	var targets: Array[Node] = []
	var fortress := get_tree().get_first_node_in_group(&"fortress")
	if fortress != null:
		targets.append(fortress)
	var commander := get_tree().get_first_node_in_group(&"commander")
	if commander != null:
		targets.append(commander)
	targets.append_array(get_tree().get_nodes_in_group(&"tower"))
	return targets


## Spawnable enemy scenes, sorted by file name; the base scene and bosses outside
## summon_boss_ids are left out.
func _build_summon_list() -> void:
	var files: Array[String] = []
	for file in ResourceLoader.list_directory(ENEMY_DIR):
		if file.ends_with(".tscn") and file != BASE_ENEMY_SCENE:
			files.append(file)
	files.sort()
	for file in files:
		var scene := load(ENEMY_DIR + file) as PackedScene
		if scene == null:
			continue
		var inst := scene.instantiate()
		var enemy := inst as Enemy
		if enemy == null or enemy.data == null:
			inst.free()
			continue
		if enemy.data is BossData and not summon_boss_ids.has(enemy.data.id):
			inst.free()
			continue
		var label := tr(enemy.data.display_name_key)
		inst.free()
		_summon_scenes.append(scene)
		summon_option.add_item(label)


## Every card of the reward pool (active, passive and stat) plus the runner's skills the pool does not
## hold, labelled by name with the id as item metadata.
func _build_skill_list() -> void:
	var service := get_tree().get_first_node_in_group(&"reward_service") as RewardService
	_list_has_pool = service != null
	var selected_id: Variant = skill_option.get_item_metadata(skill_option.selected) if skill_option.selected >= 0 else null
	skill_option.clear()
	_stat_ids.clear()
	var cards: Array[SkillData] = []
	if service != null:
		cards.append_array(service.get_catalog())
	for data in SkillRunner.SKILLS:
		if not cards.has(data):
			cards.append(data)
	for data in cards:
		if data == null:
			continue
		skill_option.add_item(tr(data.name_key))
		skill_option.set_item_metadata(skill_option.item_count - 1, data.id)
		if not data.is_slotted():
			_stat_ids.append(data.id)
		if data.id == selected_id:
			skill_option.select(skill_option.item_count - 1)


## One entry per slot of a group, written 1-based.
func _build_slot_list() -> void:
	for i in maxi(GameConfig.skill_slots_active, GameConfig.skill_slots_passive):
		slot_option.add_item(tr(&"debug.cheat.slot").format({"index": i + 1}))


## Gold from the cheat is not run income, so it stays out of the earned total.
func _add_gold_without_earned_count(gold_manager: GoldManager, amount: int) -> void:
	var show_delta := true
	var count_as_earned := false
	gold_manager.add(amount, show_delta, count_as_earned)


func _wave_manager() -> WaveManager:
	return get_tree().get_first_node_in_group(&"wave_manager") as WaveManager


func _run_state() -> RunState:
	return get_tree().get_first_node_in_group(&"run_state") as RunState


func _gold_manager() -> GoldManager:
	return get_tree().get_first_node_in_group(&"gold_manager") as GoldManager
