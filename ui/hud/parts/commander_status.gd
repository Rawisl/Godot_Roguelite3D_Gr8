extends VBoxContainer

@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar
@onready var _value: Label = %Value
@onready var _shield: HBoxContainer = %Shield
@onready var _shield_label: Label = %ShieldLabel

func _ready() -> void:
	_title.text = tr(&"hud.commander")
	_shield_label.text = tr(&"hud.invulnerable")
	_shield.visible = false
	EventBus.commander_hp_changed.connect(_on_hp_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.run_started.connect(_on_run_started)

func _on_hp_changed(hp: int, max_hp: int) -> void:
	_bar.max_value = max_hp
	_bar.value = hp
	_value.text = UiFormat.tr_fmt(&"hud.ratio", {"value": hp, "max": max_hp})

func _on_mode_changed(mode: StringName) -> void:
	_shield.visible = mode == &"COMMANDER"

func _on_run_started() -> void:
	_shield.visible = false
