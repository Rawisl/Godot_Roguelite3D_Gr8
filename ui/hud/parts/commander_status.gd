extends VBoxContainer

@onready var _title: Label = %Title
@onready var _bar: ProgressBar = %Bar
@onready var _value: Label = %Value

func _ready() -> void:
	_title.text = tr(&"hud.commander")
	EventBus.commander_hp_changed.connect(_on_hp_changed)

func _on_hp_changed(hp: int, max_hp: int) -> void:
	_bar.max_value = max_hp
	_bar.value = hp
	_value.text = UiFormat.tr_fmt(&"hud.ratio", {"value": hp, "max": max_hp})
