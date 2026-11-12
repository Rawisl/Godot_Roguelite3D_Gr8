extends VBoxContainer
## The skill slots and the weapon slot, with a button that hides them. Hiding only hides the
## display: keys 1-3 still cast and the cooldowns keep running, so showing them again gives the
## right seconds. A new run shows them again.
# TODO(WhoKeng): keep the choice in settings.cfg once the Settings tabs save their values.

## Sent when the slots are shown or hidden, so the weapon panel can close with them.
signal shown_changed(shown: bool)

var shown := true

@onready var _toggle: Button = %SkillToggle
@onready var _arrow: ArrowGlyph = %SkillToggleArrow
@onready var _row: Control = %SkillRow

func _ready() -> void:
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.text = ""
	_toggle.pressed.connect(_on_toggle_pressed)
	EventBus.run_started.connect(set_shown.bind(true))
	_apply()

func set_shown(value: bool) -> void:
	if value == shown:
		return
	shown = value
	_apply()
	shown_changed.emit(shown)

func _on_toggle_pressed() -> void:
	set_shown(not shown)

func _apply() -> void:
	_row.visible = shown
	# Down folds the slots away, up brings them back. The words stay in the tooltip.
	_arrow.pointing_up = not shown
	var action := tr(&"hud.skill.hide") if shown else tr(&"hud.skill.show")
	_toggle.tooltip_text = action + "\n" + tr(&"hud.skill.toggle_tip")
