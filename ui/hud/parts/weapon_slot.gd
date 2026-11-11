class_name WeaponSlot
extends Button
## The equipped weapon next to the skill slots: its name, its effect and how many of the run's
## weapons are owned. A click in PREP (paused PREP too) asks for the weapon panel; in any other
## state the slot is read only and says so in its tooltip. A weapon with a cooldown (Chain
## Lightning) shows the ring with the seconds left.

signal open_requested

const PREP := &"PREP"
const HIDDEN_STATE := &"REWARD_PICK"

## Every weapon a run can own, base sword first. Its size is the total in "n/6".
@export var weapons: Array[WeaponData] = []

var _owned: Array[StringName] = []
var _equipped: StringName = RunState.BASE_WEAPON
var _state: StringName = PREP
var _cd_end := 0.0
var _cd_total := 0.0

@onready var _placeholder: Control = %Placeholder
@onready var _icon: TextureRect = %Icon
@onready var _sweep: CooldownSweep = %Sweep
@onready var _cooldown: Label = %CooldownLabel
@onready var _name: Label = %NameLabel
@onready var _effect: Label = %EffectLabel
@onready var _count: Label = %CountLabel
@onready var _row: Control = $Row

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)
	if GameState.wave_state != &"":
		_state = GameState.wave_state
	_fit_width()
	_reset()
	EventBus.run_started.connect(_reset)
	EventBus.weapon_equipped.connect(_on_equipped)
	EventBus.weapon_gained.connect(_on_gained)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.skill_cooldown_changed.connect(_on_cooldown_changed)

func _reset() -> void:
	_owned = [RunState.BASE_WEAPON]
	_equipped = RunState.BASE_WEAPON
	_cd_end = 0.0
	_cd_total = 0.0
	_show()

## The slot takes the width of the longest weapon text, once, so a long name never pushes the
## sword or the text and the slot keeps its size when the weapon changes.
func _fit_width() -> void:
	var widest := 0.0
	for data in weapons:
		if data == null:
			continue
		_name.text = tr(data.name_key)
		_effect.text = tr(StringName("weapon.effect." + str(data.effect_id)))
		_count.text = UiFormat.tr_fmt(&"hud.weapon.count", {"value": weapons.size(), "max": weapons.size()})
		widest = maxf(widest, _row.get_combined_minimum_size().x)
	custom_minimum_size.x = maxf(custom_minimum_size.x, widest + _row.offset_left - _row.offset_right)

func _process(_delta: float) -> void:
	var left := maxf(_cd_end - TimeManager.game_time, 0.0)
	_sweep.ratio = left / _cd_total if _cd_total > 0.0 else 0.0
	_sweep.visible = left > 0.0
	_cooldown.visible = left > 0.0
	_cooldown.text = str(ceili(left))

func _show() -> void:
	visible = _state != HIDDEN_STATE
	var data := _find(_equipped)
	_name.text = tr(data.name_key) if data != null else ""
	_effect.text = tr(StringName("weapon.effect." + str(data.effect_id))) if data != null else ""
	_count.text = UiFormat.tr_fmt(&"hud.weapon.count", {"value": _owned.size(), "max": weapons.size()})
	# TODO(Rawisl): give WeaponData an icon field; the slot shows it as soon as the field exists.
	# TODO(kimvux): draw one icon per weapon (hilt lower left, tip upper right, like the placeholder) for that field.
	var icon: Variant = data.get(&"icon") if data != null else null
	_icon.texture = icon as Texture2D
	_icon.visible = _icon.texture != null
	# The drawn sword keeps the spot until the weapon has its own icon.
	_placeholder.visible = not _icon.visible
	disabled = _state != PREP
	tooltip_text = tr(&"hud.weapon.change_tip") if _state == PREP else tr(&"hud.weapon.prep_only")

func _on_pressed() -> void:
	if _state == PREP:
		open_requested.emit()

func _on_equipped(weapon_id: StringName) -> void:
	_equipped = weapon_id
	if not _owned.has(weapon_id):
		_owned.append(weapon_id)
	_cd_end = 0.0
	_show()

# TODO(Ender-Via): emit EventBus.weapon_gained(id) in RunState.grant_weapon when a weapon is added, so the count updates.
func _on_gained(weapon_id: StringName) -> void:
	if not _owned.has(weapon_id):
		_owned.append(weapon_id)
	_show()

func _on_state_changed(new_state: StringName) -> void:
	_state = new_state
	_show()

# TODO(Rawisl): emit skill_cooldown_changed(&"chain_lightning", chain_cd, chain_cooldown) when a chain starts, so the ring shows.
func _on_cooldown_changed(skill_id: StringName, remaining: float, total: float) -> void:
	if skill_id != _equipped:
		return
	_cd_end = TimeManager.game_time + remaining
	_cd_total = maxf(total, remaining)

func _find(id: StringName) -> WeaponData:
	for data in weapons:
		if data != null and data.id == id:
			return data
	return null
