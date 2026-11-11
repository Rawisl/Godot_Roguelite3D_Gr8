class_name WeaponPanel
extends PanelContainer
## The run's weapons: the owned ones with range and effect numbers, the others locked as boss
## drops. Picking a row equips it at once, only in PREP (paused PREP too); in any other state the
## panel is read only. RunState checks the state again when it equips.

signal closed

const PREP := &"PREP"
const BUTTON_LOCK_TIME := 0.15

## Every weapon a run can own, in the order of the rows.
@export var weapons: Array[WeaponData] = []
## Base sword range; the panel shows it times the weapon's range_mult.
@export var stats: CharacterStats

var _owned: Array[StringName] = [RunState.BASE_WEAPON]
var _equipped: StringName = RunState.BASE_WEAPON
var _locked := false

@onready var _title: Label = %Title
@onready var _close: Button = %CloseButton
@onready var _hint: Label = %Hint
@onready var _rows: GridContainer = %Rows

func _ready() -> void:
	_title.text = tr(&"panel.weapon.title")
	_close.text = tr(&"panel.close")
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(closed.emit)
	_hint.text = tr(&"hud.weapon.prep_only")
	var rows := _rows.get_children()
	for i in rows.size():
		(rows[i] as WeaponRow).pressed.connect(_on_row_pressed.bind(i))
	_fit_rows()
	EventBus.run_started.connect(_on_run_started)
	EventBus.weapon_equipped.connect(_on_equipped)
	EventBus.weapon_gained.connect(_on_gained)
	EventBus.state_changed.connect(_on_state_changed)

func open() -> void:
	_sync_from_run()
	refresh()

func refresh() -> void:
	var can_change := _is_prep()
	_hint.visible = not can_change
	var rows := _rows.get_children()
	for i in rows.size():
		var row := rows[i] as WeaponRow
		row.visible = i < weapons.size()
		if not row.visible:
			continue
		var data := weapons[i]
		row.show_weapon(data, _owned.has(data.id), data.id == _equipped, can_change,
			_range_text(data), _effect_text(data))

## Every row takes the width of the longest header any weapon can show (name, tag, range), once,
## so a long name never pushes the sword or the text and the panel never resizes on a pick.
func _fit_rows() -> void:
	var tags := [tr(&"panel.weapon.equipped"), tr(&"panel.weapon.locked_tag")]
	var rows := _rows.get_children()
	var widest := 0.0
	for i in mini(rows.size(), weapons.size()):
		var data := weapons[i]
		for tag in tags:
			widest = maxf(widest, (rows[i] as WeaponRow).measure_width(tr(data.name_key), tag, _range_text(data)))
	for row in rows:
		var control := row as Control
		control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, widest)

func _range_text(data: WeaponData) -> String:
	var base_range := stats.sword_range if stats != null else 0.0
	return UiFormat.tr_fmt(&"panel.weapon.range", {"range": format_number(base_range * data.range_mult)})

## The numbers come from the weapon's params: each key as it is, and key_x100 as a whole percent.
func _effect_text(data: WeaponData) -> String:
	var values := {}
	for key in data.params:
		var value: float = data.params[key]
		values[str(key)] = format_number(value)
		values[str(key) + "_x100"] = roundi(value * 100.0)
	return UiFormat.tr_fmt(StringName("weapon.%s.desc" % data.id), values)

## Whole numbers without ".0" (3 s, not 3.0 s), others with up to two decimals.
static func format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value, 2)

## Paused PREP still counts as PREP, as for building.
func _is_prep() -> bool:
	return GameState.wave_state == PREP or GameState.wave_state == &""

func _run_state() -> RunState:
	return get_tree().get_first_node_in_group(&"run_state") as RunState

## RunState holds the list; the panel reads it again each time it opens.
func _sync_from_run() -> void:
	var rs := _run_state()
	if rs == null:
		return
	_owned = rs.owned_weapons.duplicate()
	_equipped = rs.equipped_weapon

func _on_row_pressed(index: int) -> void:
	var data := weapons[index]
	if _try_lock() and _is_prep() and _owned.has(data.id) and data.id != _equipped:
		var rs := _run_state()
		if rs != null:
			rs.equip_weapon(data.id)
	refresh()

func _on_run_started() -> void:
	_owned = [RunState.BASE_WEAPON]
	_equipped = RunState.BASE_WEAPON
	if visible:
		refresh()

func _on_equipped(weapon_id: StringName) -> void:
	_equipped = weapon_id
	if not _owned.has(weapon_id):
		_owned.append(weapon_id)
	if visible:
		refresh()

func _on_gained(weapon_id: StringName) -> void:
	if not _owned.has(weapon_id):
		_owned.append(weapon_id)
	if visible:
		refresh()

func _on_state_changed(_new_state: StringName) -> void:
	if visible:
		refresh()

func _try_lock() -> bool:
	if _locked:
		return false
	_locked = true
	_unlock_later()
	return true

func _unlock_later() -> void:
	await TimeManager.wait_real(BUTTON_LOCK_TIME)
	_locked = false
