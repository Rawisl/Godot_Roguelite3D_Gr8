class_name RewardService
extends Node
## Holds the run's skill state and builds REWARD_PICK offers from the reward pool.
## The REWARD_PICK screen talks to it through EventBus only: reward_offer_requested asks for the next
## offer, reward_pick_requested and reward_skip_requested answer it. The public functions below are for
## tests and internal use; the UI does not call them.
# TODO(kiezroth): when RunState holds the skill state, read picks_used and the slots from it instead of the local RunSkillState

const HEAL_STATION_FLAG := &"heal_station_built"
## Reroll is not in this version, so every offer carries 0 rerolls.
const REROLLS_LEFT := 0
const SKIP_KIND := &"SKIP"

@export var pool: RewardPool
## Building this tower type turns HEAL_STATION_FLAG on for the rest of the run.
@export var heal_station_data: TowerData = preload("res://data/towers/heal_station.tres")

var state := RunSkillState.new()
var _offer: Array[Dictionary] = []
var _offer_open := false

func _ready() -> void:
	add_to_group(&"reward_service")
	if pool == null:
		push_warning("RewardService has no reward pool")
	EventBus.run_started.connect(_on_run_started)
	EventBus.tower_built.connect(_on_tower_built)
	EventBus.reward_offer_requested.connect(_on_offer_requested)
	EventBus.reward_pick_requested.connect(_on_pick_requested)
	EventBus.reward_skip_requested.connect(_on_skip_requested)

func get_catalog() -> Array[SkillData]:
	if pool == null:
		var empty: Array[SkillData] = []
		return empty
	return pool.skills

func has_offer() -> bool:
	return RewardOfferGenerator.has_offer(state, get_catalog())

## Same state and seed give the same cards, so calling again before a pick returns the same offer.
## Returns [] and emits nothing when no card can be offered.
func offer_next() -> Array[Dictionary]:
	var rng := RewardOfferGenerator.make_rng(_run_seed(), state.picks_used)
	_offer = RewardOfferGenerator.generate(state, get_catalog(), rng, pool.cards_per_pick if pool else 0)
	_offer_open = not _offer.is_empty()
	if _offer_open:
		EventBus.reward_offered.emit(_offer, REROLLS_LEFT)
	return _offer

func get_current_offer() -> Array[Dictionary]:
	return _offer

## Gives up the open offer. False when no offer is open, so a double press emits nothing.
func skip() -> bool:
	if not _offer_open:
		return false
	_close_offer()
	EventBus.reward_picked.emit(&"", SKIP_KIND, 0)
	_emit_slots()
	return true

## Takes one card of the open offer. False when no offer is open, card_id is not in it, or the run state refuses the card.
## The card in the offer decides what happens: it is written to the run state, and reward_picked carries
## the card's kind and the new level from the state. The kind and level parameters are ignored.
func pick(card_id: StringName, _kind: StringName, _level: int) -> bool:
	if not _offer_open:
		return false
	var card := _find_card(card_id)
	if card.is_empty():
		return false
	var data := card.get("data") as SkillData
	if data == null:
		return false
	var result := state.take(data)
	if result.is_empty():
		return false
	_close_offer()
	EventBus.reward_picked.emit(card_id, result["slot_kind"], result["new_level"])
	_emit_slots()
	return true

## Counts the pick before reward_picked goes out, so listeners already see the new picks_used.
func _close_offer() -> void:
	state.picks_used += 1
	_offer_open = false
	_offer = []

func _find_card(card_id: StringName) -> Dictionary:
	for card in _offer:
		if card.get("id") == card_id:
			return card
	return {}

## An open offer is sent again as it is. With nothing left to offer, reward_offered([], 0) tells the
## REWARD_PICK screen the pool is empty, then the request is skipped on the spot so the pick still
## counts and reward_picked reaches the XP tracker; offer_next called directly stays silent in that case.
## Each request is answered once; the screen asks again while picks are pending.
func _on_offer_requested() -> void:
	if _offer_open:
		EventBus.reward_offered.emit(_offer, REROLLS_LEFT)
	elif has_offer():
		offer_next()
	else:
		EventBus.reward_offered.emit([], REROLLS_LEFT)
		_close_offer()
		EventBus.reward_picked.emit(&"", SKIP_KIND, 0)
		_emit_slots()

func _on_pick_requested(card_id: StringName, kind: StringName, level: int) -> void:
	pick(card_id, kind, level)

func _on_skip_requested() -> void:
	skip()

func _on_tower_built(_slot_id: StringName, type: StringName) -> void:
	if heal_station_data != null and type == heal_station_data.id:
		state.set_flag(HEAL_STATION_FLAG)

func _on_run_started() -> void:
	state.reset()
	_offer = []
	_offer_open = false
	_emit_slots()

## Tells the HUD and the REWARD_PICK screen what sits in the slots. levels holds only the ids in a slot.
func _emit_slots() -> void:
	var levels: Dictionary = {}
	for id in state.active + state.passive:
		if id != &"":
			levels[id] = state.get_level(id)
	EventBus.skill_slots_changed.emit(state.active.duplicate(), state.passive.duplicate(), levels)

## Reads run_seed from RunState first, then from the wave manager; 0 when neither is in the tree.
func _run_seed() -> int:
	var run_state := get_tree().get_first_node_in_group(&"run_state")
	if run_state != null:
		return int(run_state.get(&"run_seed"))
	var node := get_tree().get_first_node_in_group(&"wave_manager")
	if node == null:
		return 0
	var value: Variant = node.get(&"run_seed")
	return int(value) if value != null else 0
