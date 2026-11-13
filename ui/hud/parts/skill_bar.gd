extends PanelContainer
## Two rows of skill slots: the active skills on keys 1-3 with their cooldowns, then the passives.
## Draws only from EventBus: skill_slots_changed for what sits in each slot, skill_cooldown_changed
## for the active cooldowns, mode_changed for the Commander mode lock.

const COMMANDER := &"COMMANDER"

## Same pool as RewardService, to find each skill's icon and name.
@export var pool: RewardPool

@onready var _active_row: HBoxContainer = %ActiveRow
@onready var _passive_row: HBoxContainer = %PassiveRow

func _ready() -> void:
	var active := _active_row.get_children()
	for i in active.size():
		var cell := active[i] as SkillCell
		cell.visible = i < GameConfig.skill_slots_active
		cell.set_key(_key_text(i))
	var passive := _passive_row.get_children()
	for i in passive.size():
		(passive[i] as SkillCell).visible = i < GameConfig.skill_slots_passive
	_reset()
	EventBus.run_started.connect(_reset)
	EventBus.skill_slots_changed.connect(_on_slots_changed)
	EventBus.skill_cooldown_changed.connect(_on_cooldown_changed)
	EventBus.mode_changed.connect(_on_mode_changed)

## The key comes from the InputMap action, so the label follows the binding.
func _key_text(index: int) -> String:
	if index >= SkillRunner.SLOT_IDS.size():
		return ""
	var action := SkillRunner.SLOT_IDS[index]
	if not InputMap.has_action(action):
		return ""
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return ""

func _reset() -> void:
	for row in [_active_row, _passive_row]:
		for cell in row.get_children():
			(cell as SkillCell).set_skill(null, 0)
			(cell as SkillCell).clear_cooldown()
	_set_locked(false)

func _on_slots_changed(active: Array, passive: Array, levels: Dictionary) -> void:
	_fill(_active_row, active, levels)
	_fill(_passive_row, passive, levels)

func _fill(row: HBoxContainer, ids: Array, levels: Dictionary) -> void:
	var cells := row.get_children()
	for i in cells.size():
		var id: StringName = ids[i] if i < ids.size() else &""
		var cell := cells[i] as SkillCell
		var data := _find_skill(id)
		if data == null or data != cell.skill:
			cell.clear_cooldown()
		cell.set_skill(data, levels.get(id, 0))

func _on_cooldown_changed(skill_id: StringName, remaining: float, total: float) -> void:
	var index := SkillRunner.SLOT_IDS.find(skill_id)
	if index == -1 or index >= _active_row.get_child_count():
		return
	(_active_row.get_child(index) as SkillCell).start_cooldown(remaining, total)

## Active skills only work in Frontline; passives keep showing as they are.
func _on_mode_changed(mode: StringName) -> void:
	_set_locked(mode == COMMANDER)

func _set_locked(value: bool) -> void:
	for cell in _active_row.get_children():
		(cell as SkillCell).set_locked(value)

func _find_skill(id: StringName) -> SkillData:
	if pool == null or id == &"":
		return null
	for data in pool.skills:
		if data.id == id:
			return data
	return null
