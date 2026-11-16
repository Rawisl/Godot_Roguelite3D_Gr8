class_name WavePreview
extends HBoxContainer
## What the next wave brings, shown in PREP: up to five enemy types (the boss first), how many of
## each and their traits with icon and name. Before a boss wave that drops a weapon it also says
## a weapon not owned yet will drop. Hidden outside PREP and until a preview arrives. The button on
## its left folds the whole panel away to the right (>) and leaves only the button (<) to bring it
## back, like the skill slots; a new run shows it again.
# TODO(Ender-Via): send wave_preview_ready(wave_index, {enemy_id: count}, is_boss) at the start of each PREP; nothing shows before it does.
# TODO(kiezroth): the composition sent with wave_preview_ready should come from the WaveScript of that wave.

## Every weapon in the game, to know when none is left to drop.
@export var weapons: Array[WeaponData] = []

var _in_prep := false
var _has_preview := false
var _owned := 1
var expanded := true

@onready var _title: Label = %Title
@onready var _rows: VBoxContainer = %Rows
@onready var _weapon_note: Label = %WeaponNote
@onready var _panel: PanelContainer = %Panel
@onready var _toggle: Button = %Toggle
@onready var _arrow: ArrowGlyph = %ToggleArrow

func _ready() -> void:
	visible = false
	EventBus.wave_preview_ready.connect(show_preview)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.wave_started.connect(func(_index: int) -> void: _has_preview = false)
	EventBus.run_started.connect(_on_run_started)
	EventBus.weapon_gained.connect(func(_id: StringName) -> void: _owned += 1)
	_in_prep = GameState.wave_state == &"PREP"
	_toggle.text = ""
	_toggle.pressed.connect(func() -> void: set_expanded(not expanded))
	_apply_expanded()

## Folds the panel away (false) or brings it back.
func set_expanded(value: bool) -> void:
	expanded = value
	_apply_expanded()

func _apply_expanded() -> void:
	_panel.visible = expanded
	# Shrink to the button when folded; inside a container this only asks for the new size.
	reset_size()
	# > pushes the panel away to the right, < brings it back; the words are in the tooltip.
	_arrow.pointing_left = not expanded
	_toggle.tooltip_text = tr(&"hud.preview.hide" if expanded else &"hud.preview.show")

## Kept apart from the signal so the test scene can draw any wave.
func show_preview(wave_index: int, composition: Dictionary, is_boss: bool) -> void:
	_title.text = UiFormat.tr_fmt(&"hud.preview.boss_title" if is_boss else &"hud.preview.title", {"wave": wave_index})
	var ids := _ordered(composition)
	var rows := _rows.get_children()
	for i in rows.size():
		var row := rows[i] as WavePreviewRow
		if i < ids.size():
			var boss := _is_boss_type(ids[i])
			row.show_enemy(ids[i], 0 if boss else _count(composition, ids[i]))
		else:
			row.visible = false
	var left := weapons.size() - _owned
	_weapon_note.visible = is_boss and wave_index in GameConfig.weapon_drop_waves and left > 0
	_weapon_note.text = UiFormat.tr_fmt(&"hud.preview.weapon_drop", {"left": left})
	_has_preview = true
	_refresh()

## The boss first, then the most numerous; at most as many as there are rows.
func _ordered(composition: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in composition:
		ids.append(StringName(id))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		if _is_boss_type(a) != _is_boss_type(b):
			return _is_boss_type(a)
		return _count(composition, a) > _count(composition, b))
	return ids.slice(0, _rows.get_child_count())

## Keys may come as String or StringName.
func _count(composition: Dictionary, enemy_id: StringName) -> int:
	return int(composition.get(enemy_id, composition.get(String(enemy_id), 0)))

## Bosses keep their data apart from the regular enemies.
func _is_boss_type(enemy_id: StringName) -> bool:
	return ResourceLoader.exists("res://data/bosses/%s.tres" % enemy_id)

func _on_state_changed(new_state: StringName) -> void:
	_in_prep = new_state == &"PREP"
	_refresh()

func _on_run_started() -> void:
	_owned = 1
	_has_preview = false
	set_expanded(true)
	_refresh()

func _refresh() -> void:
	visible = _in_prep and _has_preview
