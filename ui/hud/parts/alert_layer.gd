class_name AlertLayer
extends Control
## Shows alert_requested: T1 as the banner in the middle, T2 as toasts at the top centre, T3 as
## small toasts at the bottom right. At most one banner and three toasts at once; the rest wait,
## T1 first, then by tier, then by time. The same alert is not shown again within repeat_gap
## (params "repeat" = true skips that, for countdowns). Lifetimes run in real time, so x2, x3 and
## Pause do not change them. The panels are placed in the scene; nothing is created here.
## Each panel has a tone mark, the main line and an optional second line (params "sub_key", read
## with the same params), so a toast never needs a sentence with punctuation. An alert with
## params "merge" replaces the one of the same group still on screen or waiting, and restarts its
## time, instead of stacking a second toast.

## How long each tier stays, in real seconds.
@export var banner_time := 3.0
@export var t2_time := 2.5
@export var t3_time := 2.0
## Gap before the same alert key may show again, in real seconds.
@export var repeat_gap := 5.0
## Toasts on screen at once, T2 and T3 together.
@export var max_toasts := 3
## Widest the banner and the top toasts may get before their lines wrap, so they stay between the
## left column and the open wave preview on the right (1920 wide layout).
@export var max_centre_width := 440.0

var _queue: Array[Dictionary] = []
var _last_shown: Dictionary = {}  # key -> real time it was last queued
var _order := 0

@onready var _banner: PanelContainer = %Banner
@onready var _top: VBoxContainer = %ToastTop
@onready var _bottom: VBoxContainer = %ToastBottom

func _ready() -> void:
	_hide_all()
	EventBus.alert_requested.connect(_on_alert_requested)
	EventBus.run_started.connect(clear)

## Drops what is shown and what waits, for a new run.
func clear() -> void:
	_queue.clear()
	_last_shown.clear()
	_hide_all()

func _hide_all() -> void:
	_banner.visible = false
	_banner.set_meta(&"until", 0.0)
	for column in [_top, _bottom]:
		for toast in column.get_children():
			(toast as Control).visible = false
			toast.set_meta(&"until", 0.0)

func _on_alert_requested(tier: int, key: StringName, params: Dictionary) -> void:
	if key in [&"alert.commander_low", &"alert.fortress_low"]:
		return
	var now := TimeManager.real_time
	if params.has("merge") and _merge(key, params):
		_last_shown[key] = now
		return
	if not params.get(&"repeat", params.get("repeat", false)):
		if _last_shown.has(key) and now - float(_last_shown[key]) < repeat_gap:
			return
	_last_shown[key] = now
	_order += 1
	_queue.append({"tier": clampi(tier, 1, 3), "key": key, "params": params, "order": _order})
	_pump()

func _process(_delta: float) -> void:
	var now := TimeManager.real_time
	var freed := false
	for panel in _all_panels():
		if panel.visible and now >= float(panel.get_meta(&"until", 0.0)):
			panel.visible = false
			freed = true
	if freed:
		_pump()

## Shows what fits, T1 first, then by tier, then oldest.
func _pump() -> void:
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.tier < b.tier if a.tier != b.tier else a.order < b.order)
	var waiting: Array[Dictionary] = []
	for item in _queue:
		if not _try_show(item):
			waiting.append(item)
	_queue = waiting

func _try_show(item: Dictionary) -> bool:
	var tier: int = item.tier
	var panel: Control
	var life: float
	if tier == 1:
		if _banner.visible:
			return false
		panel = _banner
		life = banner_time
	else:
		if visible_toast_count() >= max_toasts:
			return false
		panel = _free_toast(_top if tier == 2 else _bottom)
		if panel == null:
			return false
		life = t2_time if tier == 2 else t3_time
	_fill(panel, item.key, item.params)
	panel.set_meta(&"merge", item.params.get("merge", &""))
	panel.set_meta(&"until", TimeManager.real_time + life)
	panel.visible = true
	# Newest toast at the end of its column.
	panel.get_parent().move_child(panel, -1)
	return true

## Panel > Row > [mark, Texts > [main line, second line]].
func _fill(panel: Control, key: StringName, params: Dictionary) -> void:
	var texts := panel.get_child(0).get_child(1)
	(texts.get_child(0) as Label).text = UiFormat.tr_fmt(key, params)
	var sub := texts.get_child(1) as Label
	var sub_key: StringName = params.get("sub_key", &"")
	sub.visible = sub_key != &""
	sub.text = UiFormat.tr_fmt(sub_key, params) if sub.visible else ""
	panel.set_meta(&"key", key)
	if panel == _banner or panel.get_parent() == _top:
		_fit_width(panel, texts.get_children())

## Lets the lines wrap only when the alert would be wider than max_centre_width. Widths are read from
## the fonts, since a label's minimum size only updates on the next frame.
func _fit_width(panel: Control, lines: Array) -> void:
	var row := panel.get_child(0) as HBoxContainer
	var mark := row.get_child(0) as Control
	var extra := panel.get_theme_stylebox(&"panel").get_minimum_size().x + mark.custom_minimum_size.x 			+ row.get_theme_constant(&"separation")
	var widest := 0.0
	for line: Label in lines:
		if line.visible:
			var font := line.get_theme_font(&"font")
			widest = maxf(widest, font.get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				line.get_theme_font_size(&"font_size")).x)
	var wrap := extra + widest > max_centre_width
	for line: Label in lines:
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
		line.custom_minimum_size.x = max_centre_width - extra if wrap else 0.0
	if panel == _banner:
		_centre_banner.call_deferred()

## The banner sits on its own anchor; after a size change it is put back in the middle.
func _centre_banner() -> void:
	_banner.reset_size()
	var half := _banner.size * 0.5
	_banner.offset_left = -half.x
	_banner.offset_right = half.x
	_banner.offset_top = -half.y
	_banner.offset_bottom = half.y

## Updates the alert of the same group on screen (restarting its time) or waiting. False when none.
func _merge(key: StringName, params: Dictionary) -> bool:
	var group: Variant = params["merge"]
	for panel in _all_panels():
		if panel.visible and panel.get_meta(&"merge", &"") == group:
			_fill(panel, key, params)
			var tier := 1 if panel == _banner else (2 if panel.get_parent() == _top else 3)
			panel.set_meta(&"until", TimeManager.real_time + [banner_time, t2_time, t3_time][tier - 1])
			return true
	for item in _queue:
		if item.params.get("merge", &"") == group:
			item.key = key
			item.params = params
			return true
	return false

## Main line of each alert on screen, banner first. For tests.
func shown_texts() -> Array[String]:
	var texts: Array[String] = []
	for panel in _all_panels():
		if panel.visible:
			texts.append((panel.get_child(0).get_child(1).get_child(0) as Label).text)
	return texts

func _free_toast(column: VBoxContainer) -> Control:
	for toast in column.get_children():
		if not (toast as Control).visible:
			return toast
	return null

func _all_panels() -> Array[Control]:
	var panels: Array[Control] = [_banner]
	for column in [_top, _bottom]:
		for toast in column.get_children():
			panels.append(toast)
	return panels

func visible_toast_count() -> int:
	var count := 0
	for column in [_top, _bottom]:
		for toast in column.get_children():
			if (toast as Control).visible:
				count += 1
	return count

func is_banner_visible() -> bool:
	return _banner.visible

func waiting_count() -> int:
	return _queue.size()

## Keys of the alerts on screen now, banner first.
func shown_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	for panel in _all_panels():
		if panel.visible:
			keys.append(panel.get_meta(&"key", &""))
	return keys
