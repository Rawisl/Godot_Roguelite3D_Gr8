extends HBoxContainer

const DELTA_FADE_TIME := 1.0

var _delta_tween: Tween

@onready var _title: Label = %Title
@onready var _value: Label = %Value
@onready var _delta: Label = %Delta

func _ready() -> void:
	_title.text = tr(&"hud.gold")
	_delta.modulate.a = 0.0
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.gold_delta.connect(_on_gold_delta)

func _on_gold_changed(gold: int) -> void:
	_value.text = str(gold)

func _on_gold_delta(delta: int) -> void:
	if delta == 0:
		return
	var key := &"hud.gold_gain" if delta > 0 else &"hud.gold_loss"
	_delta.text = UiFormat.tr_fmt(key, {"gold": absi(delta)})
	_delta.modulate.a = 1.0
	if _delta_tween:
		_delta_tween.kill()
	# HUD animations run on real time so x2/x3 does not speed them up.
	_delta_tween = create_tween().set_ignore_time_scale()
	_delta_tween.tween_property(_delta, "modulate:a", 0.0, DELTA_FADE_TIME).set_delay(0.5)
