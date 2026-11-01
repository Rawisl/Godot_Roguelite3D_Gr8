extends Control
## Draws the heal station panel without a BuildService. Press F6 on this scene.
## 1: full store in PREP. 2: half store in PREP. 3: empty store in COMBAT (no Sell).

const DATA: TowerData = preload("res://data/towers/heal_station.tres")

@onready var _panel: HealStationPanel = %HealStationPanel

func _ready() -> void:
	_show(300, 300, 48, true)

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1:
			_show(300, 300, 48, true)
		KEY_2:
			_show(150, 300, 24, true)
		KEY_3:
			_show(0, 300, 0, false)

func _show(hp: int, max_hp: int, sell_value: int, in_prep: bool) -> void:
	_panel.show_info({"data": DATA, "level": 1, "hp": hp, "max_hp": max_hp, "sell_value": sell_value}, in_prep)
