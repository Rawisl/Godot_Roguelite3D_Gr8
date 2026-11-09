class_name RewardPickScreen
extends Control
## REWARD_PICK: up to three cards, the current skill slots and Skip. Talks to RewardService through
## EventBus only. Offers are asked one at a time: the next one only after reward_picked, so it is
## built from the updated run state. Esc is left to ScreenManager (closes the Skip dialog first)
## and GameState (opens Pause on top of this screen).

const DIALOG_SCENE := preload("res://ui/screens/confirm_dialog.tscn")

## Same pool as RewardService, used only to show the skills already in the slots.
@export var pool: RewardPool

var _busy := false
var _skip_dialog: Control

@onready var _title: Label = %Title
@onready var _hint: Label = %Hint
@onready var _pending: Label = %Pending
@onready var _cards: HBoxContainer = %Cards
@onready var _empty: Label = %Empty
@onready var _active_title: Label = %ActiveTitle
@onready var _passive_title: Label = %PassiveTitle
@onready var _active_slots: HBoxContainer = %ActiveSlots
@onready var _passive_slots: HBoxContainer = %PassiveSlots
@onready var _skip: Button = %SkipButton

func _ready() -> void:
	visible = false
	_title.text = tr(&"reward.title")
	_hint.text = tr(&"reward.hint")
	_empty.text = tr(&"reward.empty")
	_active_title.text = tr(&"reward.slots.active")
	_passive_title.text = tr(&"reward.slots.passive")
	_skip.text = tr(&"reward.skip")
	_pending.visible = false
	_skip.pressed.connect(_on_skip_pressed)
	for card: RewardCard in _cards.get_children():
		card.chosen.connect(_on_card_chosen)
	_show_slots([], [])
	EventBus.run_started.connect(func() -> void: _show_slots([], []))
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.reward_offered.connect(_on_reward_offered)
	EventBus.reward_picked.connect(_on_reward_picked)
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.skill_slots_changed.connect(_show_slots)

func _on_state_changed(new_state: StringName) -> void:
	if new_state != &"REWARD_PICK":
		_close()
		return
	visible = true
	_request_offer()

func _request_offer() -> void:
	_busy = true
	_set_enabled(false)
	EventBus.reward_offer_requested.emit()

func _on_reward_offered(cards: Array, _rerolls_left: int) -> void:
	if not visible:
		return
	_busy = false
	_set_enabled(true)
	_empty.visible = cards.is_empty()
	_skip.disabled = cards.is_empty()
	var nodes := _cards.get_children()
	if cards.size() > nodes.size():
		push_warning("RewardPickScreen: %d cards offered, only %d shown" % [cards.size(), nodes.size()])
	for i in nodes.size():
		var node := nodes[i] as RewardCard
		if i < cards.size():
			node.show_card(cards[i])
		else:
			node.visible = false

func _on_card_chosen(card: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	_set_enabled(false)
	EventBus.reward_pick_requested.emit(card.get("id", &""), card.get("kind", &""), card.get("next_level", 0))

func _on_skip_pressed() -> void:
	if _busy or _skip_dialog != null:
		return
	var dialog := DIALOG_SCENE.instantiate()
	dialog.setup(&"reward.skip.title", &"reward.skip.body")
	dialog.set_buttons(&"reward.skip")
	dialog.confirmed.connect(_on_skip_confirmed)
	dialog.tree_exited.connect(func() -> void: _skip_dialog = null)
	if ScreenManager.open_dialog(dialog):
		_skip_dialog = dialog

func _on_skip_confirmed() -> void:
	if _busy or not visible:
		return
	_busy = true
	_set_enabled(false)
	EventBus.reward_skip_requested.emit()

## The wave manager may leave REWARD_PICK inside the same emit, so the next offer waits a frame.
func _on_reward_picked(_card_id: StringName, _slot_kind: StringName, _new_level: int) -> void:
	if visible:
		_request_next.call_deferred()

func _request_next() -> void:
	if visible:
		_request_offer()

func _on_xp_changed(_xp: float, _level: int, _to_next: float, pending_picks: int) -> void:
	_pending.visible = pending_picks > 0
	_pending.text = UiFormat.tr_fmt(&"reward.pending", {"value": pending_picks})

func _close() -> void:
	visible = false
	_busy = false
	if is_instance_valid(_skip_dialog):
		_skip_dialog.cancel()

func _set_enabled(value: bool) -> void:
	for card: RewardCard in _cards.get_children():
		card.disabled = not value
	_skip.disabled = not value

func _show_slots(active: Array, passive: Array, levels: Dictionary = {}) -> void:
	_fill_slots(_active_slots, active, levels, GameConfig.skill_slots_active)
	_fill_slots(_passive_slots, passive, levels, GameConfig.skill_slots_passive)

## Slots past the configured count stay hidden.
func _fill_slots(row: HBoxContainer, ids: Array, levels: Dictionary, count: int) -> void:
	var slots := row.get_children()
	for i in slots.size():
		var slot := slots[i] as RewardSlot
		slot.visible = i < count
		var id: StringName = ids[i] if i < ids.size() else &""
		slot.set_skill(_find_skill(id), levels.get(id, 0))

func _find_skill(id: StringName) -> SkillData:
	if pool == null or id == &"":
		return null
	for data in pool.skills:
		if data.id == id:
			return data
	return null
