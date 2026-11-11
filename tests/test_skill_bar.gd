extends Node
## Skill bar, XP bar, Aura icon, weapon slot and weapon panel with fake EventBus signals and a real
## RunState. Press F6 on this scene: the checks below run first and print a summary, then the keys
## replay each step by hand.
## 1: fill the skill slots. 2: start the skill cooldowns. 3: switch Frontline / Commander.
## 4: commander kill XP. 5: tower-only kill XP. A: Aura on / off. W: gain the next weapon.
## O: click the weapon slot. S: switch PREP / COMBAT. C: Chain Lightning cooldown.
## H: hide / show the skill slots. R: new run.

const SKILL_IDS: Array[StringName] = [&"whirlwind", &"sword_wave", &"firebomb"]
const WEAPON_IDS: Array[StringName] = [&"frost", &"chain_lightning", &"burn", &"rampage", &"swift"]

var _passed := 0
var _failed := 0
var _commander_mode := false
var _aura := false
var _prep := true
var _xp := 0.0
var _level := 0
var _pending := 0
var _next_weapon := 0

@onready var _run_state: RunState = $"../RunState"

func _ready() -> void:
	# Keys must work while the game is paused, as the HUD does.
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await _run_checks()
	_new_run()

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_fill_slots()
		KEY_2:
			EventBus.skill_cooldown_changed.emit(&"skill_1", 6.0, 6.0)
			EventBus.skill_cooldown_changed.emit(&"skill_2", 3.0, 8.0)
		KEY_3:
			_commander_mode = not _commander_mode
			EventBus.mode_changed.emit(&"COMMANDER" if _commander_mode else &"FRONTLINE")
		KEY_4:
			_gain_xp(2.0, true)
		KEY_5:
			_gain_xp(1.0, false)
		KEY_A:
			_aura = not _aura
			EventBus.aura_changed.emit(_aura)
		KEY_W:
			_gain_next_weapon()
		KEY_O:
			_slot().pressed.emit()
		KEY_S:
			_prep = not _prep
			EventBus.state_changed.emit(&"PREP" if _prep else &"COMBAT")
		KEY_C:
			EventBus.skill_cooldown_changed.emit(&"chain_lightning", 5.0, 5.0)
		KEY_H:
			(get_tree().root.find_child("SkillToggle", true, false) as Button).pressed.emit()
		KEY_R:
			_new_run()

func _new_run() -> void:
	_commander_mode = false
	_aura = false
	_prep = true
	_xp = 0.0
	_level = 0
	_pending = 0
	_next_weapon = 0
	_run_state.owned_weapons = [RunState.BASE_WEAPON]
	_run_state.equipped_weapon = RunState.BASE_WEAPON
	EventBus.run_started.emit()
	EventBus.state_changed.emit(&"PREP")
	EventBus.mode_changed.emit(&"FRONTLINE")
	EventBus.xp_changed.emit(0.0, 0, _to_next(0), 0)

func _fill_slots() -> void:
	EventBus.skill_slots_changed.emit([&"whirlwind", &"sword_wave", &""], [&"sharpness", &"", &""],
		{&"whirlwind": 1, &"sword_wave": 2, &"sharpness": 1})

## A small stand-in for XpTracker: xp_gained first, level ups, then xp_changed.
func _gain_xp(amount: float, from_commander: bool) -> void:
	EventBus.xp_gained.emit(amount, from_commander)
	_xp += amount
	while _xp >= _to_next(_level):
		_xp -= _to_next(_level)
		_level += 1
		_pending += 1
		EventBus.level_up.emit(_level, _pending)
	EventBus.xp_changed.emit(_xp, _level, _to_next(_level), _pending)

func _to_next(level: int) -> float:
	return 5.0 + 4.0 * level

## Same path as a boss drop once RunState sends weapon_gained.
func _gain_next_weapon() -> void:
	if _next_weapon >= WEAPON_IDS.size():
		return
	var id := WEAPON_IDS[_next_weapon]
	_next_weapon += 1
	_run_state.grant_weapon(id)
	EventBus.weapon_gained.emit(id)

func _cells(row: String) -> Array:
	return get_tree().root.find_child(row, true, false).get_children()

func _slot() -> WeaponSlot:
	return get_tree().root.find_child("WeaponSlot", true, false) as WeaponSlot

func _panel() -> WeaponPanel:
	return get_tree().root.find_child("WeaponPanel", true, false) as WeaponPanel


func _run_checks() -> void:
	_new_run()
	var active := _cells("ActiveRow")
	var passive := _cells("PassiveRow")
	_check(active.size() == 3 and passive.size() == 3, "three active and three passive slots")
	var first := active[0] as SkillCell
	_check(first.skill == null and not (first.get_node("%Frame") as Control).visible, "new run: slots are empty (dashed frame)")
	_check((first.get_node("%KeyLabel") as Label).text == "1", "first active slot shows key 1 from the InputMap")
	_check(not (passive[0].get_node("%KeyCap") as Control).visible, "passive slots have no key")

	_fill_slots()
	_check(first.skill != null and first.skill.id == &"whirlwind" and first.level == 1, "slot 1 holds Whirlwind level 1")
	_check((active[1] as SkillCell).level == 2 and (active[2] as SkillCell).skill == null, "slot 2 level 2, slot 3 still empty")
	_check((passive[0] as SkillCell).skill != null and (passive[0] as SkillCell).skill.id == &"sharpness", "passive slot 1 holds Sharpness")
	var dots := first.get_node("%Dots")
	_check(dots.get_child(0).get_theme_stylebox(&"panel") == first.dot_full
		and dots.get_child(1).get_theme_stylebox(&"panel") == first.dot_empty, "level dots: one full, then hollow")

	EventBus.skill_cooldown_changed.emit(&"skill_1", 6.0, 6.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(first.cooldown_left() > 5.0 and (first.get_node("%CooldownLabel") as Label).text == "6", "cooldown ring and seconds on slot 1")
	_check((active[1] as SkillCell).cooldown_left() == 0.0, "slot 2 has no cooldown")

	EventBus.mode_changed.emit(&"COMMANDER")
	_check(first.locked and (first.get_node("%LockTag") as Control).visible, "Commander mode: active slots locked with a tag")
	_check(not (passive[0] as SkillCell).locked, "Commander mode: passives not locked")
	_check(first.tooltip_text.contains(tr(&"hud.skill.locked_tip")), "locked tooltip gives the reason")
	EventBus.mode_changed.emit(&"FRONTLINE")
	_check(not first.locked, "Frontline: unlocked again")

	var xp_bar := get_tree().root.find_child("XpBar", true, false)
	var fill := xp_bar.get_node("%XpFill") as XpFill
	_gain_xp(2.0, true)
	_gain_xp(1.0, false)
	_check(is_equal_approx(fill.commander_ratio, 0.4) and is_equal_approx(fill.tower_ratio, 0.2), "XP split: 2 commander, 1 tower out of 5")
	_check((xp_bar.get_node("%PercentLabel") as Label).text == "60%", "XP percent 60%")
	_check(not (xp_bar.get_node("%PendingLabel") as Control).visible, "no picks waiting yet")
	_gain_xp(3.0, true)
	_check((xp_bar.get_node("%LevelLabel") as Label).text == UiFormat.tr_fmt(&"hud.xp.level", {"level": 1}), "level up shows level 1")
	_check((xp_bar.get_node("%PendingLabel") as Control).visible, "level up shows the pick waiting")
	_check(is_equal_approx((fill.commander_ratio + fill.tower_ratio) * _to_next(1), 1.0), "carried XP keeps adding up to the new level's XP")
	EventBus.xp_changed.emit(4.0, 1, 9.0, 1)
	_check(is_equal_approx((fill.commander_ratio + fill.tower_ratio) * 9.0, 4.0), "XP without xp_gained still fills the bar")

	var aura := get_tree().root.find_child("AuraIcon", true, false) as Control
	EventBus.aura_changed.emit(true)
	_check(aura.visible and aura.tooltip_text != "", "Aura icon shows with its tooltip")
	EventBus.aura_changed.emit(false)
	_check(not aura.visible, "Aura icon hides")

	var toggle := get_tree().root.find_child("SkillToggle", true, false) as Button
	var skill_row := get_tree().root.find_child("SkillRow", true, false) as Control
	var arrow := get_tree().root.find_child("SkillToggleArrow", true, false) as ArrowGlyph
	_check(skill_row.visible and not arrow.pointing_up and toggle.text == "", "skill slots shown at start, arrow points down, no text")
	_check(toggle.tooltip_text.begins_with(tr(&"hud.skill.hide")), "the tooltip says the arrow hides the slots")
	EventBus.skill_cooldown_changed.emit(&"skill_1", 6.0, 6.0)
	toggle.pressed.emit()
	_check(not skill_row.visible and arrow.pointing_up, "Hide: skill slots and weapon slot hidden, arrow points up")
	_check(toggle.tooltip_text.begins_with(tr(&"hud.skill.show")), "the tooltip says the arrow shows them again")
	_check(toggle.visible and get_tree().root.find_child("EmergencyRepair", true, false).visible, "Hide: the button and Emergency repair stay")
	_check(first.cooldown_left() > 5.0, "hidden slots keep the cooldown running")
	toggle.pressed.emit()
	_check(skill_row.visible and first.cooldown_left() > 5.0, "Show: slots back with the seconds left")

	var slot := _slot()
	var count := slot.get_node("%CountLabel") as Label
	_check((slot.get_node("%NameLabel") as Label).text == tr(&"weapon.sword_base.name"), "weapon slot starts with the base sword")
	_check(count.text == UiFormat.tr_fmt(&"hud.weapon.count", {"value": 1, "max": 6}), "weapon count 1/6")
	_check((slot.get_node("%Placeholder") as Control).visible and not (slot.get_node("%Icon") as Control).visible,
		"no weapon icon yet: the drawn sword keeps the spot")
	_gain_next_weapon()
	_check(count.text == UiFormat.tr_fmt(&"hud.weapon.count", {"value": 2, "max": 6}), "weapon gained: 2/6")

	var panel := _panel()
	slot.pressed.emit()
	_check(panel.visible, "PREP: clicking the slot opens the weapon panel")
	var rows := panel.get_node("%Rows").get_children()
	var base_row := rows[0] as WeaponRow
	var frost_row := rows[1] as WeaponRow
	var chain_row := rows[2] as WeaponRow
	_check(base_row.button_pressed and not frost_row.button_pressed, "base sword row marked as in use")
	_check(chain_row.disabled and (chain_row.get_node("%EffectLabel") as Label).text == tr(&"panel.weapon.locked"), "weapon not owned: locked, dropped by a boss")
	_check((frost_row.get_node("%EffectLabel") as Label).text.contains("20%"), "Frost row shows its numbers from the .tres")
	_check((frost_row.get_node("%RangeLabel") as Label).text.contains("2.2"), "Frost row shows the sword range")
	_check((frost_row.get_node("%Placeholder") as Control).visible, "panel rows show the drawn sword next to the name")
	frost_row.pressed.emit()
	_check(_run_state.equipped_weapon == &"frost", "picking Frost equips it in RunState")
	_check((slot.get_node("%NameLabel") as Label).text == tr(&"weapon.frost.name"), "slot follows weapon_equipped")
	_check(frost_row.button_pressed and not base_row.button_pressed, "Frost row now marked as in use")

	var widths := rows.map(func(r: Control) -> float: return r.custom_minimum_size.x)
	_check(widths.all(func(w: float) -> bool: return is_equal_approx(w, widths[0])), "panel rows share one width")
	await get_tree().process_frame
	for row in rows:
		var inner := (row as Control).get_node("Row") as Control
		_check(inner.get_combined_minimum_size().x + 32.0 <= (row as Control).size.x + 0.5,
			"row text fits: " + ((row as Control).get_node("%NameLabel") as Label).text)
	EventBus.weapon_equipped.emit(&"swift")
	await get_tree().process_frame
	var slot_row := slot.get_node("Row") as Control
	_check(slot_row.get_combined_minimum_size().x + 28.0 <= slot.size.x + 0.5, "longest weapon name fits the HUD slot")
	EventBus.weapon_equipped.emit(&"frost")

	EventBus.state_changed.emit(&"COMBAT")
	_check(not panel.visible, "leaving PREP closes the panel")
	_check(slot.disabled and slot.tooltip_text == tr(&"hud.weapon.prep_only"), "COMBAT: slot read only with the reason")
	slot.pressed.emit()
	_check(not panel.visible, "COMBAT: clicking the slot does not open the panel")
	_check(not _run_state.equip_weapon(&"sword_base"), "RunState refuses to equip outside PREP")
	EventBus.state_changed.emit(&"REWARD_PICK")
	_check(not slot.visible, "REWARD_PICK: weapon slot hidden")
	EventBus.state_changed.emit(&"PREP")

	_gain_next_weapon()
	slot.pressed.emit()
	# Past the 0.15 s button lock of the Frost pick.
	await TimeManager.wait_real(0.2)
	chain_row.pressed.emit()
	EventBus.skill_cooldown_changed.emit(&"chain_lightning", 5.0, 5.0)
	# process_frame comes before _process, so wait one more for the ring to redraw.
	await get_tree().process_frame
	await get_tree().process_frame
	var sweep := slot.get_node("%Sweep") as CooldownSweep
	_check(_run_state.equipped_weapon == &"chain_lightning" and sweep.ratio > 0.9, "Chain Lightning: cooldown ring runs")
	slot.pressed.emit()
	toggle.pressed.emit()
	_check(not panel.visible, "hiding the skill slots closes the weapon panel")

	EventBus.run_started.emit()
	_check(skill_row.visible, "new run shows the skill slots again")
	_check(first.skill == null and count.text == UiFormat.tr_fmt(&"hud.weapon.count", {"value": 1, "max": 6}), "new run clears slots and weapons")
	(get_tree().root.find_child("PanelHost", true, false) as PanelHost).close_all()
	print("test_skill_bar: %d passed, %d failed" % [_passed, _failed])

func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
		print("  [PASS] ", label)
	else:
		_failed += 1
		print("  [FAIL] ", label)
