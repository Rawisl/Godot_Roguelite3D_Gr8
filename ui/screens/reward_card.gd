class_name RewardCard
extends Button
## One REWARD_PICK card, drawn from the card dictionary that RewardOfferGenerator builds.
## The look comes from the theme: the card itself is the RewardCard variation, and the frame and
## the kind band take the variation of the card's kind, so the kind shows by colour and by its
## label. The card grows a little on hover, dips on press and keeps a glow once picked. The
## screen pauses the game, so these run on real time; Reduced motion turns them into instant changes.

signal chosen(card: Dictionary)

const KIND_KEYS := {
	&"ACTIVE": &"reward.kind.active",
	&"PASSIVE": &"reward.kind.passive",
	&"STAT": &"reward.kind.stat",
}
## Frame, band and band label variations per kind. The darker bands take the light label.
const KIND_STYLES := {
	&"ACTIVE": [&"RewardFrameActive", &"RewardKindActive", &"RewardKindLabel"],
	&"PASSIVE": [&"RewardFramePassive", &"RewardKindPassive", &"RewardKindLabelLight"],
	&"STAT": [&"RewardFrameStat", &"RewardKindStat", &"RewardKindLabelLight"],
}
const STATE_STYLES: Array[StringName] = [&"normal", &"hover", &"pressed", &"disabled"]

@export var hover_scale: float = 1.04
@export var press_scale: float = 0.98
@export var picked_scale: float = 1.06
## Seconds for each scale change, real time.
@export var anim_time: float = 0.12
## Frame and band strength while the card is greyed out.
@export var disabled_tint: Color = Color(1, 1, 1, 0.45)

var _card: Dictionary = {}
var _picked := false
var _reduced_motion := false
var _tween: Tween

@onready var _kind: Label = %Kind
@onready var _band: PanelContainer = %KindBand
@onready var _frame: Panel = %Frame
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _level: Label = %Level
@onready var _desc: Label = %Desc

func _ready() -> void:
	_reduced_motion = GameState.get_setting(&"reduced_motion", false) == true
	EventBus.settings_changed.connect(_on_settings_changed)
	pressed.connect(_on_pressed)
	mouse_entered.connect(func() -> void:
		if not disabled:
			_scale_to(hover_scale))
	mouse_exited.connect(func() -> void: _scale_to(_rest_scale()))
	button_down.connect(func() -> void: _scale_to(press_scale))
	button_up.connect(func() -> void: _scale_to(hover_scale if is_hovered() else _rest_scale()))
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5

func show_card(card: Dictionary) -> void:
	_card = card
	_set_picked(false)
	_scale_to(1.0, true)
	var kind: StringName = card.get("kind", &"ACTIVE")
	var styles: Array = KIND_STYLES.get(kind, KIND_STYLES[&"ACTIVE"])
	_frame.theme_type_variation = styles[0]
	_band.theme_type_variation = styles[1]
	_kind.theme_type_variation = styles[2]
	var data := card.get("data") as SkillData
	_kind.text = tr(KIND_KEYS.get(kind, &""))
	_icon.texture = data.icon if data != null else null
	_name.text = tr(data.name_key) if data != null else String(card.get("id", ""))
	if card.get("is_new", false):
		_level.text = tr(&"reward.level.new")
	else:
		_level.text = UiFormat.tr_fmt(&"reward.level.up",
			{"from": card.get("level", 0), "to": card.get("next_level", 1)})
	_desc.text = tr(data.description_key) if data != null else ""
	var max_level := data.get_max_level() if data != null else 0
	tooltip_text = UiFormat.tr_fmt(&"reward.card.tip", {"desc": _desc.text, "max": max_level})
	visible = true

func is_picked() -> bool:
	return _picked

func _notification(what: int) -> void:
	# A Button redraws when it is enabled or disabled; the frame and band follow.
	if what == NOTIFICATION_DRAW and is_node_ready():
		var dim := disabled and not _picked
		_frame.modulate = disabled_tint if dim else Color.WHITE
		_band.modulate = disabled_tint if dim else Color.WHITE
		if dim and not is_equal_approx(scale.x, 1.0):
			_scale_to(1.0, true)

func _on_pressed() -> void:
	_set_picked(true)
	_scale_to(picked_scale)
	chosen.emit(_card)

## The picked card keeps its glow while the screen greys the others out.
func _set_picked(value: bool) -> void:
	_picked = value
	for state in STATE_STYLES:
		if value:
			add_theme_stylebox_override(state, get_theme_stylebox(&"picked"))
		else:
			remove_theme_stylebox_override(state)
	queue_redraw()

func _rest_scale() -> float:
	return picked_scale if _picked else 1.0

func _scale_to(target: float, instant := false) -> void:
	if _tween != null:
		_tween.kill()
	# A grown card draws over its neighbours.
	z_index = 1 if target > 1.0 else 0
	if instant or _reduced_motion or not is_inside_tree():
		scale = Vector2.ONE * target
		return
	_tween = create_tween()
	# The game is paused on this screen and the speed may be x3: UI time only.
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ignore_time_scale(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, ^"scale", Vector2.ONE * target, anim_time)

func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduced_motion":
		_reduced_motion = value == true
