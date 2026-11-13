class_name WeaponRow
extends Button
## One weapon in the weapon panel: name, range and effect with its numbers, the tag of the one in
## use, or a locked line for a weapon the run does not own yet.

@onready var _placeholder: Control = %Placeholder
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %NameLabel
@onready var _tag: Label = %TagLabel
@onready var _range: Label = %RangeLabel
@onready var _effect: Label = %EffectLabel
@onready var _row: Control = $Row

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE

## Width the row needs to show these texts on its header line, side margins included. Leaves the
## texts in place; show_weapon() sets the real ones.
func measure_width(name_text: String, tag_text: String, range_text: String) -> float:
	_name.text = name_text
	_tag.text = tag_text
	_range.text = range_text
	_range.visible = true
	return _row.get_combined_minimum_size().x + _row.offset_left - _row.offset_right

## can_change is false outside PREP: every row is then read only.
func show_weapon(data: WeaponData, owned: bool, equipped: bool, can_change: bool,
		range_text: String, effect_text: String) -> void:
	_name.text = tr(data.name_key)
	var icon: Variant = data.get(&"icon")
	_icon.texture = icon as Texture2D
	_icon.visible = _icon.texture != null
	# The drawn sword keeps the spot until the weapon has its own icon.
	_placeholder.visible = not _icon.visible
	set_pressed_no_signal(owned and equipped)
	_range.visible = owned
	if not owned:
		disabled = true
		_tag.text = tr(&"panel.weapon.locked_tag")
		_effect.text = tr(&"panel.weapon.locked")
		tooltip_text = tr(&"panel.weapon.locked")
		return
	disabled = not can_change
	_tag.text = tr(&"panel.weapon.equipped") if equipped else ""
	_range.text = range_text
	_effect.text = effect_text
	if not can_change:
		tooltip_text = tr(&"hud.weapon.prep_only")
	elif equipped:
		tooltip_text = tr(&"panel.weapon.equipped")
	else:
		tooltip_text = tr(&"panel.weapon.pick_tip")
