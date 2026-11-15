extends PanelContainer
## Mithril next to gold. Glows for a moment when Mithril is gained. In PREP, while the Fortress
## is missing HP and there is Mithril to spend, a "Repair" button shows next to the number; it
## opens the Fortress panel like a click on the Fortress, and the repair itself stays in the panel.

## Glow after a gain, in real seconds.
@export var glow_time := 0.3

var _mithril := 0
var _hp := 0
var _max_hp := 0
var _in_prep := false
var _glow_tween: Tween

@onready var _title: Label = %Title
@onready var _value: Label = %Value
@onready var _hint: Button = %Hint
@onready var _glow: Panel = %Glow

func _ready() -> void:
	_title.text = tr(&"hud.mithril")
	_hint.text = tr(&"hud.mithril.hint")
	_hint.tooltip_text = tr(&"hud.mithril.hint_tip")
	_hint.pressed.connect(_on_hint_pressed)
	_glow.modulate.a = 0.0
	EventBus.mithril_changed.connect(_on_mithril_changed)
	EventBus.fortress_hp_changed.connect(_on_fortress_hp_changed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.run_started.connect(_on_run_started)
	_in_prep = GameState.wave_state == &"PREP"
	_refresh()

func _on_mithril_changed(new_mithril: int, delta: int) -> void:
	_mithril = new_mithril
	if delta > 0:
		_flash_glow()
	_refresh()

func _on_fortress_hp_changed(new_hp: int, max_hp: int, _delta: int) -> void:
	_hp = new_hp
	_max_hp = max_hp
	_refresh()

func _on_state_changed(new_state: StringName) -> void:
	_in_prep = new_state == &"PREP"
	_refresh()

## Mithril never carries over to a new run.
func _on_run_started() -> void:
	_mithril = 0
	_refresh()

func _refresh() -> void:
	_value.text = str(_mithril)
	var show_hint := _in_prep and _mithril > 0 and _hp < _max_hp
	_hint.visible = show_hint
	tooltip_text = tr(&"hud.mithril.hint_tip" if show_hint else &"hud.mithril.tip")

## Same path as clicking the Fortress in the world, so the panel opens with its own checks.
func _on_hint_pressed() -> void:
	var selection := get_tree().get_first_node_in_group(&"selection_controller") as SelectionController
	if selection != null:
		selection.select_fortress()

## HUD animations run on real time so x2/x3 does not speed them up.
func _flash_glow() -> void:
	if _glow_tween != null:
		_glow_tween.kill()
	_glow.modulate.a = 1.0
	_glow_tween = create_tween().set_ignore_time_scale()
	_glow_tween.tween_property(_glow, "modulate:a", 0.0, glow_time)
