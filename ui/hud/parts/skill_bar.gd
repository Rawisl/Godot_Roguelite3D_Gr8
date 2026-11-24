extends HBoxContainer

const COMMANDER := &"COMMANDER"

## Same pool as RewardService, to find each skill's icon and name.
@export var pool: RewardPool

@export var passive := false

func _ready() -> void:
	var cells := get_children()
	for i in cells.size():
		var cell := cells[i] as SkillCell
		cell.visible = i < (GameConfig.skill_slots_passive if passive else GameConfig.skill_slots_active)
		if not passive:
			cell.set_key(_key_text(i))
	_reset()
	EventBus.run_started.connect(_reset)
	EventBus.skill_slots_changed.connect(_on_slots_changed)
	if not passive:
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
	for cell: SkillCell in get_children():
		cell.set_skill(null, 0)
		cell.clear_cooldown()
	_set_locked(false)

func _on_slots_changed(active_ids: Array, passive_ids: Array, levels: Dictionary) -> void:
	var ids := passive_ids if passive else active_ids
	var cells := get_children()
	for i in cells.size():
		var id: StringName = ids[i] if i < ids.size() else &""
		var cell := cells[i] as SkillCell
		var data := _find_skill(id)
		if data == null or data != cell.skill:
			cell.clear_cooldown()
		cell.set_skill(data, levels.get(id, 0))

func _on_cooldown_changed(skill_id: StringName, remaining: float, total: float) -> void:
	var index := SkillRunner.SLOT_IDS.find(skill_id)
	if index == -1 or index >= get_child_count():
		return
	(get_child(index) as SkillCell).start_cooldown(remaining, total)

## Active skills only work in Frontline; passives keep showing as they are.
func _on_mode_changed(mode: StringName) -> void:
	_set_locked(mode == COMMANDER)

func _set_locked(value: bool) -> void:
	for cell in get_children():
		(cell as SkillCell).set_locked(value)

func _find_skill(id: StringName) -> SkillData:
	if pool == null or id == &"":
		return null
	for data in pool.skills:
		if data.id == id:
			return data
	return null
