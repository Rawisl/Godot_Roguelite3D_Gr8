class_name SkillCell
extends Control
## One skill slot on the HUD: key, icon and level dots, plus a cooldown ring with the seconds
## left for active skills. An empty slot has a dashed frame. Locked shows grey with a lock tag
## and the reason in the tooltip, so nothing relies on colour alone.

## Filled dot for a level reached, hollow dot for one still to come.
@export var dot_full: StyleBox
@export var dot_empty: StyleBox
## Active slots run cooldowns; passive slots never show the ring.
@export var show_cooldown := true
@export var empty_color := Color(0.1098, 0.1216, 0.149, 0.6)
@export var dash_color := Color(0.6627, 0.6549, 0.6235)
@export var dash_length := 8.0
@export var dash_width := 2.0
@export var locked_modulate := Color(1, 1, 1, 0.45)
## Icon tint while the skill is on cooldown, so the ring and the seconds stand out on it.
@export var cooldown_icon_modulate := Color(0.35, 0.35, 0.35)

var skill: SkillData
var level := 0
var locked := false
var _cd_end := 0.0
var _cd_total := 0.0

@onready var _frame: Panel = %Frame
@onready var _body: Control = %Body
@onready var _icon: TextureRect = %Icon
@onready var _sweep: CooldownSweep = %Sweep
@onready var _cooldown: Label = %CooldownLabel
@onready var _key_cap: Control = %KeyCap
@onready var _key: Label = %KeyLabel
@onready var _dots: HBoxContainer = %Dots
@onready var _lock_tag: Control = %LockTag
@onready var _lock_label: Label = %LockLabel

func _ready() -> void:
	_lock_label.text = tr(&"hud.skill.locked")
	_show()

## Empty text hides the key cap (passive slots have no key).
func set_key(text: String) -> void:
	_key_cap.visible = text != ""
	_key.text = text

func set_skill(data: SkillData, new_level: int) -> void:
	skill = data
	level = new_level
	_show()

func set_locked(value: bool) -> void:
	locked = value
	_show()

## Game time, so the seconds hold on Pause and follow x2 and x3.
func start_cooldown(remaining: float, total: float) -> void:
	_cd_end = TimeManager.game_time + remaining
	_cd_total = maxf(total, remaining)

func clear_cooldown() -> void:
	_cd_end = 0.0
	_cd_total = 0.0

func cooldown_left() -> float:
	return maxf(_cd_end - TimeManager.game_time, 0.0)

func _process(_delta: float) -> void:
	var left := cooldown_left() if skill != null and show_cooldown else 0.0
	_sweep.ratio = left / _cd_total if _cd_total > 0.0 else 0.0
	_cooldown.visible = left > 0.0
	_cooldown.text = str(ceili(left))
	if _icon.visible:
		_icon.modulate = cooldown_icon_modulate if left > 0.0 else Color.WHITE

func _show() -> void:
	var filled := skill != null
	_frame.visible = filled
	_icon.visible = filled
	_icon.texture = skill.icon if filled else null
	_sweep.visible = filled and show_cooldown
	var max_level := skill.get_max_level() if filled else 0
	for i in _dots.get_child_count():
		var dot := _dots.get_child(i) as Panel
		dot.visible = i < max_level
		dot.add_theme_stylebox_override(&"panel", dot_full if i < level else dot_empty)
	_lock_tag.visible = locked
	_body.modulate = locked_modulate if locked else Color.WHITE
	tooltip_text = _tooltip()
	queue_redraw()

func _tooltip() -> String:
	if skill == null:
		return tr(&"hud.skill.empty")
	var lines := PackedStringArray([UiFormat.tr_fmt(&"hud.skill.tip",
		{"name": tr(skill.name_key), "level": level, "max": skill.get_max_level()})])
	if locked:
		lines.append(tr(&"hud.skill.locked_tip"))
	if skill.description_key != &"":
		lines.append(tr(skill.description_key))
	return "\n".join(lines)

## An empty slot draws its own dim fill and a dashed frame; a filled one uses the Frame panel.
func _draw() -> void:
	if skill != null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), empty_color)
	var inset := dash_width * 0.5
	var a := Vector2(inset, inset)
	var b := Vector2(size.x - inset, inset)
	var c := Vector2(size.x - inset, size.y - inset)
	var d := Vector2(inset, size.y - inset)
	for edge in [[a, b], [b, c], [c, d], [d, a]]:
		draw_dashed_line(edge[0], edge[1], dash_color, dash_width, dash_length)
