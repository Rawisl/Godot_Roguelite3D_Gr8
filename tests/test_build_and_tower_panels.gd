extends Control
## Checks the Build, Tower and Heal station panels against a fake BuildService. Press F6: the checks
## run first and print a summary, then click the window once and use the keys:
## 1: Build panel with the normal entries. 2: the path-blocked entry (red ring on hover).
## 3: the ground-full and heal-limit entries. 4: Tower panel at level 13 with the tier 2 gate closed.
## 5: Tower panel at level 13 with the gate open. 6: starter tower that cannot be sold yet.
## 7: Heal station at level 5. 8: Heal station at MAX. 9: hover the first entry (ghost and ring show).
## 0: move off it (both go away).

const ARROW := preload("res://data/towers/arrow.tres")
const HEAL := preload("res://data/towers/heal_station.tres")
const GHOST_POS := Vector3(4, 0, -2)

var _passed := 0
var _failed := 0

@onready var _fake: FakeBuildService = $FakeService
@onready var _build: BuildPanel = $BuildPanel
@onready var _tower: TowerPanel = $TowerPanel
@onready var _heal: HealStationPanel = $HealPanel
@onready var _ring: RangeRing = $World/Ring

func _ready() -> void:
	# Stands in for PanelHost: the build preview draws the ring and the ghost of the tower type.
	_fake.tower_scenes[&"arrow"] = preload("res://entities/tower/arrow.tscn")
	_build.preview_requested.connect(_on_preview)
	_build.preview_cleared.connect(_ring.hide_ring)
	$World/Camera.look_at(GHOST_POS)
	await get_tree().process_frame
	await _run_checks()
	print("test_build_and_tower_panels: %d passed, %d failed" % [_passed, _failed])
	_show_build(_normal_options())

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_show_build(_normal_options())
		KEY_2:
			_show_build([_option(&"BLOCKS_PATH", 0, 0)])
		KEY_3:
			_show_build([_option(&"GROUND_FULL", 0, 0), _option(&"HEAL_LIMIT", 0, 0, HEAL)])
		KEY_4:
			_show_tower(13, true, false)
		KEY_5:
			_show_tower(13, false, false)
		KEY_6:
			_show_tower(3, false, false, 3)
		KEY_7:
			_show_heal(5, false)
		KEY_8:
			_show_heal(36, true)
		KEY_9:
			_buttons(_build)[0].mouse_entered.emit()
		KEY_0:
			_buttons(_build)[0].mouse_exited.emit()

func _on_preview(_slot_id: StringName, type: StringName, radius: float, blocked: bool) -> void:
	_ring.show_at(GHOST_POS, radius, blocked, _fake.tower_scenes.get(type) as PackedScene)

func _run_checks() -> void:
	await _check_build_entries()
	await _check_blocked_preview()
	_check_tower_locked_upgrade()
	_check_tower_tier_and_sell_lock()
	_check_heal_upgrade()

## Build panel: a locked entry is greyed and says why, a free one stays live.
const GHOST_BLOCKED := Color("#FF2D2D", 0.45)
const GHOST_FREE := Color(1, 1, 1, 0.4)

func _check_build_entries() -> void:
	await _show_build(_normal_options())
	var buttons := _buttons(_build)
	_expect(buttons.size() == 2, "build: two entries shown")
	_expect(not buttons[0].disabled and _texts(buttons[0]).size() == 1, "build: free entry is live, no reason line")

	await _show_build([_option(&"GROUND_FULL", 0, 0)])
	var full := _buttons(_build)[0]
	_expect(full.disabled, "build: ground full greys the entry")
	_expect(_texts(full).has(UiFormat.tr_fmt(&"panel.build.ground_full", {"max": GameConfig.max_ground_buildings})),
		"build: ground full reason shows the cap")

	await _show_build([_option(&"HEAL_LIMIT", 0, 0, HEAL)])
	var limit := _buttons(_build)[0]
	_expect(limit.disabled and _texts(limit).has(UiFormat.tr_fmt(&"panel.build.heal_limit", {"max": GameConfig.heal_tower_max_count})),
		"build: heal limit greys the entry with its reason")

	await _show_build([_option(&"", 5, 0)])
	var short := _buttons(_build)[0]
	_expect(short.disabled and _texts(short).has(UiFormat.tr_fmt(&"panel.need_gold", {"gold": 5})),
		"build: missing gold still shows the gold line")

## A blocked-path entry shows its reason and sends the red preview when hovered.
func _check_blocked_preview() -> void:
	await _show_build([_option(&"BLOCKS_PATH", 0, 0)])
	var blocked := _buttons(_build)[0]
	_expect(blocked.disabled and _texts(blocked).has(tr(&"panel.build.blocks_path")), "build: blocked path greys the entry")
	var got: Array = []
	_build.preview_requested.connect(func(_id, _type, _radius, flag): got.append(flag), CONNECT_ONE_SHOT)
	blocked.mouse_entered.emit()
	_expect(got == [true], "build: blocked entry asks for the red preview")
	_expect(blocked.tooltip_text == tr(&"panel.build.blocks_path"), "build: blocked entry tooltip says why")
	_expect(_ring.visible and _ghost_color() == GHOST_BLOCKED, "preview: blocked build shows a red ghost on the ring")
	blocked.mouse_exited.emit()
	_expect(not _ring.visible and _ring._ghost == null, "preview: leaving the entry removes ring and ghost")
	await _show_build(_normal_options())
	_buttons(_build)[0].mouse_entered.emit()
	_expect(_ring.visible and _ghost_color() == GHOST_FREE, "preview: allowed build shows a white ghost")
	_buttons(_build)[0].mouse_exited.emit()

## Tower panel: upgrade to tier 2 is grey until the Commander reaches the gate level.
func _check_tower_locked_upgrade() -> void:
	_show_tower(13, true, false)
	var need := UiFormat.tr_fmt(&"panel.need_commander_level", {"level": GameConfig.tower_gate_tier2})
	_expect(_tower._upgrade.disabled and _tower._upgrade.tooltip_text == need, "tower: locked upgrade is grey with the level")
	_expect(_texts(_tower._upgrade).has(need), "tower: locked upgrade names the Commander level")
	_show_tower(13, false, false)
	_expect(not _tower._upgrade.disabled, "tower: open gate allows the upgrade")

## Tower panel shows the model tier with the level, and a starter tower that cannot be sold yet is grey.
func _check_tower_tier_and_sell_lock() -> void:
	_show_tower(13, false, false)
	_expect(_tower._level.text == UiFormat.tr_fmt(&"panel.tower.level_tier", {"level": 13, "tier": 2}),
		"tower: level 13 shows tier 2")
	_show_tower(3, false, false, 3)
	_expect(_tower._sell.disabled and _tower._sell.visible, "tower: starter tower cannot be sold yet")
	_expect(_texts(_tower._sell).has(UiFormat.tr_fmt(&"panel.tower.sell_locked", {"wave": 3})), "tower: sell lock names the wave")
	_show_tower(3, false, false, 0)
	_expect(not _tower._sell.disabled, "tower: sell opens once the lock is gone")

## Heal station: upgrade is live in PREP, grey at MAX and hidden in combat.
func _check_heal_upgrade() -> void:
	_show_heal(5, false)
	_expect(not _heal._upgrade.disabled and _heal._upgrade.visible, "heal: upgrade live in PREP")
	_expect(_heal._level_row._value.text == UiFormat.tr_fmt(&"panel.heal.level_value",
		{"level": 5, "max": GameConfig.tower_max_level, "tier": 1}), "heal: level row shows level, max and tier")
	_show_heal(36, true)
	_expect(_heal._upgrade.disabled and _texts(_heal._upgrade).has(tr(&"panel.max")), "heal: MAX is grey")
	_show_heal(5, false, false)
	_expect(not _heal._upgrade.visible, "heal: upgrade hidden outside PREP")

## refresh() frees the old entries with queue_free, so the checks wait one frame before reading them.
func _show_build(options: Array[Dictionary]) -> void:
	_fake.build_options = options
	_build.open(&"W1")
	await get_tree().process_frame

func _show_tower(level: int, locked: bool, short: bool, sell_wave := 0) -> void:
	_fake.sell_locked_until = sell_wave
	_fake.tower_info = {
		"data": ARROW, "level": level, "hp": 100, "max_hp": 100, "range": 8.0,
		"priority": Enums.TargetPriority.FIRST, "can_target": true, "is_max": false,
		"sell_value": 20, "upgrade_cost": 50, "upgrade_shortfall": 5 if short else 0,
		"upgrade_required_level": GameConfig.tower_gate_tier2 if locked else 0, "upgrade_locked": locked,
	}
	_tower.open(&"W1")

func _show_heal(level: int, is_max: bool, in_prep := true) -> void:
	var info := {"data": HEAL, "level": level, "hp": 150, "max_hp": 300, "sell_value": 30, "is_max": is_max,
		"upgrade_cost": 40, "upgrade_shortfall": 0, "upgrade_locked": false, "upgrade_required_level": 0}
	_heal.show_info(info, in_prep)

func _normal_options() -> Array[Dictionary]:
	return [_option(&"", 0, 0), _option(&"", 0, 0, HEAL, 1)]

## One fake entry of BuildService.get_build_options(). The fields match the real function.
func _option(reason: StringName, shortfall: int, gold: int, data: TowerData = ARROW, level := 1) -> Dictionary:
	return {"data": data, "level": level, "cost": 50 + gold, "shortfall": shortfall, "rebuild": false, "locked_reason": reason}

func _buttons(panel: Node) -> Array[PanelButton]:
	var found: Array[PanelButton] = []
	for node in panel.find_children("*", "Button", true, false):
		if node is PanelButton:
			found.append(node)
	return found

## Every Label text under a button, so the checks read what the player reads.
func _texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for child in node.find_children("*", "Label", true, false):
		var label := child as Label
		if label.text != "":
			out.append(label.text)
	return out

## Colour of the ghost's mesh, or Color(0, 0, 0, 0) when there is no ghost.
func _ghost_color() -> Color:
	if not is_instance_valid(_ring._ghost):
		return Color(0, 0, 0, 0)
	var mesh := _ring._ghost.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	return (mesh.material_override as StandardMaterial3D).albedo_color

func _expect(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		push_error("test_build_and_tower_panels FAILED: " + what)
