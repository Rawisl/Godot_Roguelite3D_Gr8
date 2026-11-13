extends VBoxContainer
## Commander XP under the commander HP bar: level, progress in percent and the picks waiting.
## XP from kills the commander took part in is solid, XP from tower-only kills is striped, and the
## tooltip gives both numbers, so the split never relies on colour alone.

## Glow on level up, in real seconds.
@export var glow_time := 0.3

var _level := 0
var _xp := 0.0
var _to_next := 0.0
var _pending := 0
var _commander_xp := 0.0
var _tower_xp := 0.0
var _glow_tween: Tween

@onready var _level_label: Label = %LevelLabel
@onready var _pending_label: Label = %PendingLabel
@onready var _fill: XpFill = %XpFill
@onready var _percent: Label = %PercentLabel
@onready var _glow: Panel = %Glow

func _ready() -> void:
	_glow.modulate.a = 0.0
	_reset()
	EventBus.run_started.connect(_reset)
	EventBus.xp_gained.connect(_on_xp_gained)
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.level_up.connect(_on_level_up)

func _reset() -> void:
	_level = 0
	_xp = 0.0
	_to_next = 0.0
	_pending = 0
	_commander_xp = 0.0
	_tower_xp = 0.0
	_show()

# TODO(Ender-Via): emit EventBus.xp_gained(gained, hit_by_commander) in XpTracker._on_enemy_died right before add_xp, so the bar can split commander and tower XP.
func _on_xp_gained(amount: float, from_commander: bool) -> void:
	if amount <= 0.0:
		return
	if from_commander:
		_commander_xp += amount
	else:
		_tower_xp += amount

func _on_xp_changed(xp: float, level: int, to_next: float, pending_picks: int) -> void:
	_fit_parts(xp)
	_xp = xp
	_level = level
	_to_next = to_next
	_pending = pending_picks
	_show()

## Keeps the two parts adding up to the XP of the current level. A level up carries what is left
## over with the same split; XP that came without xp_gained counts as the commander's.
func _fit_parts(xp: float) -> void:
	var known := _commander_xp + _tower_xp
	if known > xp and known > 0.0:
		var keep := xp / known
		_commander_xp *= keep
		_tower_xp *= keep
	elif known < xp:
		_commander_xp += xp - known

func _show() -> void:
	_level_label.text = UiFormat.tr_fmt(&"hud.xp.level", {"level": _level})
	var share := _xp / _to_next if _to_next > 0.0 else 0.0
	_percent.text = UiFormat.tr_fmt(&"hud.xp.percent", {"value": floori(clampf(share, 0.0, 1.0) * 100.0)})
	_pending_label.visible = _pending > 0
	_pending_label.text = UiFormat.tr_fmt(&"hud.xp.pending", {"count": _pending})
	if _to_next > 0.0:
		_fill.set_parts(_commander_xp / _to_next, _tower_xp / _to_next)
	else:
		_fill.set_parts(0.0, 0.0)
	tooltip_text = UiFormat.tr_fmt(&"hud.xp.tip", {
		"xp": String.num(_xp, 1), "max": String.num(_to_next, 1),
		"commander": String.num(_commander_xp, 1), "tower": String.num(_tower_xp, 1)})

func _on_level_up(new_level: int, _pending_picks: int) -> void:
	_flash_glow()
	EventBus.alert_requested.emit(int(Enums.AlertTier.T3), &"alert.level_up", {"level": new_level})

func _flash_glow() -> void:
	if _glow_tween != null:
		_glow_tween.kill()
	_glow.modulate.a = 1.0
	_glow_tween = create_tween().set_ignore_time_scale()
	_glow_tween.tween_property(_glow, "modulate:a", 0.0, glow_time)
