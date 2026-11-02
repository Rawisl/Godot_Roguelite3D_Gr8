class_name RewardService
extends Node
## Holds the run's skill state and builds REWARD_PICK offers from the reward pool.
## The REWARD_PICK screen calls offer_next() for each pending pick and skip() to give one up.
# TODO(week 9): apply a picked card to the run state and notify the skill slots
# TODO(week 10): take the run seed and the pick state from RunState (RunState)

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
	EventBus.reward_picked.connect(_on_reward_picked)

func get_catalog() -> Array[SkillData]:
	if pool == null:
		var empty: Array[SkillData] = []
		return empty
	return pool.skills

func has_offer() -> bool:
	return RewardOfferGenerator.has_offer(state, get_catalog())

## Same state and seed give the same cards, so calling again before a pick returns the same offer.
func offer_next() -> Array[Dictionary]:
	var rng := RewardOfferGenerator.make_rng(_run_seed(), state.picks_used)
	_offer = RewardOfferGenerator.generate(state, get_catalog(), rng, pool.cards_per_pick if pool else 0)
	_offer_open = not _offer.is_empty()
	EventBus.reward_offered.emit(_offer, REROLLS_LEFT)
	return _offer

func get_current_offer() -> Array[Dictionary]:
	return _offer

## Gives up the open offer. False when no offer is open, so a double press emits nothing.
func skip() -> bool:
	if not _offer_open:
		return false
	EventBus.reward_picked.emit(&"", SKIP_KIND, 0)
	return true

func _on_reward_picked(_card_id: StringName, _slot_kind: StringName, _new_level: int) -> void:
	state.picks_used += 1
	_offer_open = false
	_offer = []

func _on_tower_built(_slot_id: StringName, type: StringName) -> void:
	if heal_station_data != null and type == heal_station_data.id:
		state.set_flag(HEAL_STATION_FLAG)

func _on_run_started() -> void:
	state.reset()
	_offer = []
	_offer_open = false

## Reads run_seed from the wave manager; 0 when there is none.
func _run_seed() -> int:
	var node := get_tree().get_first_node_in_group(&"wave_manager")
	if node == null:
		return 0
	var value: Variant = node.get(&"run_seed")
	return int(value) if value != null else 0
