extends Node

## Automated test runner verifying SkillData, RunSkillState, the progression
## signals on EventBus and the sample skill locale keys.

const WHIRLWIND: SkillData = preload("res://data/skills/whirlwind.tres")
const SHARPNESS: SkillData = preload("res://data/skills/sharpness.tres")
const VITALITY: SkillData = preload("res://data/skills/stat_vitality.tres")
const HEAL_STATION: SkillData = preload("res://data/skills/heal_station_skill.tres")

## Off when driven from the editor or godot-mcp, so results can still be read.
@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var failed_names: PackedStringArray = []

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED SKILL DATA RUNNER TEST                ")
	print("=======================================================")

	test_resources_load()
	test_max_level()
	test_get_value()
	test_new_state()
	test_take_same_skill()
	test_slots_full()
	test_owned_without_slot()
	test_stat_does_not_slot()
	test_dict_roundtrip()
	test_event_bus_signals()
	test_locale_keys()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	if quit_when_done:
		get_tree().quit(0 if fails == 0 else 1)

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		failed_names.append(test_name)
		printerr("  [FAIL] %s" % test_name)

func _make_skill(id: StringName, kind: SkillData.Kind) -> SkillData:
	var d := SkillData.new()
	d.id = id
	d.kind = kind
	return d

func test_resources_load() -> void:
	for d: SkillData in [WHIRLWIND, SHARPNESS, VITALITY, HEAL_STATION]:
		assert_true(d is SkillData, "%s loads as SkillData" % d.id)
		assert_true(d.validate().is_empty(), "%s validate() is empty: %s" % [d.id, d.validate()])

func test_max_level() -> void:
	assert_true(WHIRLWIND.get_max_level() == GameConfig.skill_max_level, "skill max level from GameConfig")
	assert_true(VITALITY.get_max_level() == GameConfig.stat_max_stacks, "stat max level from GameConfig")
	var d := _make_skill(&"override", SkillData.Kind.ACTIVE)
	d.max_level_override = GameConfig.skill_max_level + 2
	assert_true(d.get_max_level() == GameConfig.skill_max_level + 2, "max_level_override wins")

func test_get_value() -> void:
	# Expected numbers come from the sample table, not from GameConfig.
	assert_true(is_equal_approx(WHIRLWIND.get_value(&"damage", 1), 15.0), "whirlwind damage lv1 = 15")
	assert_true(is_equal_approx(WHIRLWIND.get_value(&"damage", 2), 20.0), "whirlwind damage lv2 = 20")
	assert_true(is_equal_approx(WHIRLWIND.get_value(&"damage", 3), 25.0), "whirlwind damage lv3 = 25")
	assert_true(WHIRLWIND.get_value(&"damage", 0) == 0.0, "level 0 gives 0.0 (skill not owned)")
	assert_true(WHIRLWIND.get_value(&"damage", -1) == 0.0, "negative level gives 0.0")
	assert_true(is_equal_approx(WHIRLWIND.get_value(&"damage", 4), 25.0), "level 4 clamps to last")
	assert_true(WHIRLWIND.get_value(&"missing", 1) == 0.0, "missing key returns 0.0")
	var d := _make_skill(&"bad", SkillData.Kind.PASSIVE)
	d.values = {&"x": PackedFloat32Array([1.0])}
	assert_true(d.validate().size() == 1, "validate flags wrong value count")

func test_new_state() -> void:
	var s := RunSkillState.new()
	var all_empty := true
	for id in s.active:
		all_empty = all_empty and id == &""
	assert_true(s.active.size() == GameConfig.skill_slots_active, "active sized from GameConfig")
	assert_true(s.passive.size() == GameConfig.skill_slots_passive, "passive sized from GameConfig")
	assert_true(all_empty, "all active slots empty")

func test_take_same_skill() -> void:
	var s := RunSkillState.new()
	var r := s.take(WHIRLWIND)
	assert_true(r == {"slot_kind": &"ACTIVE", "slot_index": 0, "new_level": 1}, "first take -> ACTIVE slot 0 lv1: %s" % r)
	r = s.take(WHIRLWIND)
	assert_true(r.get("new_level") == 2 and r.get("slot_index") == 0, "second take levels up, same slot")
	r = s.take(WHIRLWIND)
	assert_true(r.get("new_level") == 3, "third take -> lv3")
	assert_true(s.take(WHIRLWIND).is_empty(), "fourth take refused")
	assert_true(s.is_maxed(WHIRLWIND), "whirlwind maxed")

func test_slots_full() -> void:
	var s := RunSkillState.new()
	var extras: Array[SkillData] = []
	for i in GameConfig.skill_slots_active:
		var d := _make_skill(StringName("a%d" % i), SkillData.Kind.ACTIVE)
		extras.append(d)
		s.take(d)
	var overflow := _make_skill(&"overflow", SkillData.Kind.ACTIVE)
	assert_true(s.take(overflow).is_empty(), "take refused when slots full")
	assert_true(not s.can_take(overflow), "can_take false when slots full")
	assert_true(s.can_take(extras[0]), "owned skill still can_take below max")
	assert_true(s.free_slot_index(SkillData.Kind.ACTIVE) == -1, "no free active slot")
	assert_true(s.free_slot_index(SkillData.Kind.PASSIVE) == 0, "passive slot still free")
	# Slots do not compact: a hole stays where it is and is filled first.
	s.active[1] = &""
	assert_true(s.free_slot_index(SkillData.Kind.ACTIVE) == 1, "lowest empty index reused")
	assert_true(s.free_slot_index(SkillData.Kind.STAT) == -1, "STAT has no slot")

func test_owned_without_slot() -> void:
	# Restored state where a slotted skill has a level but no slot, with every active slot taken.
	var full: Array[StringName] = []
	for i in GameConfig.skill_slots_active:
		full.append(StringName("a%d" % i))
	var s := RunSkillState.new()
	s.from_dict({"active": full, "passive": [], "levels": {&"orphan": 1, VITALITY.id: 1}})
	var orphan := _make_skill(&"orphan", SkillData.Kind.ACTIVE)
	assert_true(not s.can_take(orphan), "owned skill without a slot needs a free slot")
	assert_true(s.take(orphan).is_empty(), "take refused for owned skill without a slot")
	assert_true(s.active == full, "slots unchanged after the refusal")
	assert_true(s.get_level(&"orphan") == 1, "level unchanged after the refusal")
	assert_true(s.can_take(VITALITY), "STAT still can_take with full slots")
	s.active[1] = &""
	var r := s.take(orphan)
	assert_true(r.get("slot_index") == 1 and r.get("new_level") == 2, "owned skill takes the lowest free slot and levels up: %s" % r)

func test_stat_does_not_slot() -> void:
	var s := RunSkillState.new()
	var active_before := s.active.duplicate()
	var passive_before := s.passive.duplicate()
	var r := s.take(VITALITY)
	assert_true(r.get("slot_kind") == &"STAT" and r.get("slot_index") == -1, "STAT result has no slot")
	for i in GameConfig.stat_max_stacks - 1:
		s.take(VITALITY)
	assert_true(s.get_level(VITALITY.id) == GameConfig.stat_max_stacks, "stat stacks to max")
	assert_true(s.take(VITALITY).is_empty(), "stat stops at max")
	assert_true(s.get_level(VITALITY.id) == GameConfig.stat_max_stacks, "stat level unchanged after refusal")
	assert_true(s.active == active_before and s.passive == passive_before, "STAT leaves slots untouched")

func test_dict_roundtrip() -> void:
	var s := RunSkillState.new()
	s.take(WHIRLWIND)
	s.take(WHIRLWIND)
	s.take(SHARPNESS)
	s.take(VITALITY)
	var copy := RunSkillState.new()
	copy.from_dict(s.to_dict())
	assert_true(copy.active == s.active, "roundtrip active")
	assert_true(copy.passive == s.passive, "roundtrip passive")
	assert_true(copy.levels == s.levels, "roundtrip levels")

func test_event_bus_signals() -> void:
	var expected := {
		&"xp_changed": 4, &"level_up": 2, &"reward_offered": 2,
		&"reward_picked": 3, &"skill_slots_changed": 2, &"aura_changed": 1,
	}
	for sig: StringName in expected:
		assert_true(EventBus.has_signal(sig), "EventBus has %s" % sig)
		var args := -1
		for info in EventBus.get_signal_list():
			if info["name"] == sig:
				args = info["args"].size()
		assert_true(args == expected[sig], "%s has %d args" % [sig, expected[sig]])

func test_locale_keys() -> void:
	TranslationServer.set_locale("vi")
	for d: SkillData in [WHIRLWIND, SHARPNESS, VITALITY, HEAL_STATION]:
		assert_true(tr(d.name_key) != String(d.name_key), "%s name translated" % d.id)
		assert_true(tr(d.description_key) != String(d.description_key), "%s description translated" % d.id)
