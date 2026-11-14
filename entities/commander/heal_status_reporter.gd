class_name HealStatusReporter
extends Node
## Reports gameplay conditions separately so pause never makes the HUD stale.

const UPDATE_INTERVAL := 0.1

var _channel: HealChannel
var _commander: Node
var _last_update := -INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_channel = get_parent() as HealChannel
	if _channel == null:
		push_error("HealStatusReporter must be a child of HealChannel")
		set_process(false)
		return
	_commander = _channel.get_parent()
	if _commander == null or not _commander.is_in_group(&"commander"):
		push_error("HealStatusReporter requires the channel's commander parent")
		_commander = null
		set_process(false)


func _process(_delta: float) -> void:
	var now := TimeManager.real_time
	if now >= _last_update and now - _last_update < UPDATE_INTERVAL:
		return
	_last_update = now
	var alive := 0
	var total := 0
	var service := get_tree().get_first_node_in_group(&"build_service") as BuildService
	if service != null:
		var status := service.get_heal_station_status()
		alive = status["alive"]
		total = status["total"]
	var reason := _channel.get_block_reason()
	if _commander.is_dead:
		reason = &"DEAD"
	elif reason == &"NO_STATION_IN_RANGE" and alive == 0:
		reason = &"DEPLETED"
	var duration: float = _commander.get_stat(&"heal_hold_time", 1.0)
	var remaining := maxf(0.0, duration - _channel.hold_time) if _channel.phase != HealChannel.HEALING else 0.0
	var progress := clampf(_channel.hold_time / maxf(duration, 0.000001), 0.0, 1.0)
	EventBus.heal_status_updated.emit(_channel.phase, reason, progress, remaining,
		_channel.get_heal_rate(), alive, total)


func _exit_tree() -> void:
	if _channel != null and _commander != null:
		EventBus.heal_status_updated.emit(HealChannel.IDLE, &"", 0.0, 0.0, 0.0, 0, 0)
