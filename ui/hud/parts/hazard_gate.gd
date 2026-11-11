class_name HazardGate
extends Button
## The Hazard Trial tower marker, shown only in PREP: the state ("Ready" with the E key, or why it
## is locked) and, on hover, the enemy types of the group and the Mithril for a win. E (the
## hazard_enter action), a click on the marker or a click on the tower asks to enter; the wave
## side checks the rules again. The marker sits over the tower; without a tower in the level it
## docks at the top right.
# TODO(kimvux): add the hazard_portal tower to the level (group hazard_portal, a click area on layer 7) so the marker follows it.

const PREP := &"PREP"
const HAZARD := &"HAZARD_TRIAL"
const COMMANDER := &"COMMANDER"
const ACTION := &"hazard_enter"

@export var portal_group := &"hazard_portal"
## Height above the tower where the marker sits, in metres.
@export var marker_height := 3.0
## Gap from the top right corner while no tower is in the level.
@export var dock_margin := Vector2(40.0, 240.0)
@export var locked_modulate := Color(1, 1, 1, 0.6)

var _state: StringName = &""
var _commander := false
var _paused := false
var _used := false
var _sent := false
var _enemy_types: Array = []
var _mithril := 0

@onready var _status: Label = %Status
@onready var _key_cap: Control = %KeyCap
@onready var _key: Label = %KeyLabel
@onready var _title: Label = %Title
@onready var _body: Control = %Body

func _ready() -> void:
	add_to_group(&"hazard_gate")
	focus_mode = Control.FOCUS_NONE
	_title.text = tr(&"hud.hazard.title")
	_key.text = _key_text()
	pressed.connect(try_enter)
	EventBus.run_started.connect(_on_run_started)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.mode_changed.connect(_on_mode_changed)
	EventBus.pause_changed.connect(_on_pause_changed)
	EventBus.hazard_trial_offered.connect(_on_offered)
	EventBus.hazard_trial_exited.connect(_on_exited)
	if GameState.wave_state != &"":
		_state = GameState.wave_state
	_refresh()

## E in PREP only; in combat E belongs to the heal channel.
func _unhandled_input(event: InputEvent) -> void:
	if _state == PREP and event.is_action_pressed(ACTION) and not event.is_echo():
		try_enter()
		get_viewport().set_input_as_handled()

## The wave side checks again; the marker only stops a request it already knows is refused.
func try_enter() -> void:
	if _state != PREP or _sent or lock_reason() != &"":
		return
	_sent = true
	EventBus.hazard_enter_requested.emit()
	_refresh()

## Empty when the room can be entered. Same order as the rules: pause, dialog, mode, used.
func lock_reason() -> StringName:
	if _paused:
		return &"hud.hazard.paused"
	if ScreenManager.has_dialog():
		return &"hud.hazard.dialog"
	if _commander:
		return &"hud.hazard.frontline"
	if _used:
		return &"hud.hazard.used"
	return &""

## A dialog sends no signal, so the lock and the position are checked every frame while shown.
func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh()
	_place()

func _refresh() -> void:
	visible = _state == PREP
	var reason := lock_reason()
	var can_enter := reason == &"" and not _sent
	_key_cap.visible = can_enter
	_status.text = tr(&"hud.hazard.ready") if can_enter else tr(reason) if reason != &"" else ""
	_body.modulate = Color.WHITE if can_enter else locked_modulate
	disabled = not can_enter
	tooltip_text = _tooltip(reason)

func _tooltip(reason: StringName) -> String:
	var lines := PackedStringArray()
	if reason != &"":
		lines.append(tr(reason))
	if not _enemy_types.is_empty():
		var names := PackedStringArray()
		for id in _enemy_types:
			var name := tr(StringName("enemy.%s" % id))
			if not names.has(name):
				names.append(name)
		lines.append(UiFormat.tr_fmt(&"hud.hazard.group", {"types": ", ".join(names)}))
	if _mithril > 0:
		lines.append(UiFormat.tr_fmt(&"hud.hazard.reward", {"mithril": _mithril}))
	return "\n".join(lines)

## Over the tower when the level has one, docked at the top right otherwise.
func _place() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	var portal := get_tree().get_first_node_in_group(portal_group) as Node3D
	var cam := get_viewport().get_camera_3d()
	if portal != null and cam != null:
		var point := portal.global_position + Vector3.UP * marker_height
		if not cam.is_position_behind(point):
			var screen := cam.unproject_position(point)
			position = screen - Vector2(size.x * 0.5, size.y)
			return
	position = Vector2(parent.size.x - size.x - dock_margin.x, dock_margin.y)

func _key_text() -> String:
	if not InputMap.has_action(ACTION):
		return ""
	for event in InputMap.action_get_events(ACTION):
		var key := event as InputEventKey
		if key != null:
			return OS.get_keycode_string(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	return ""

func _on_run_started() -> void:
	_used = false
	_sent = false
	_enemy_types = []
	_mithril = 0
	_refresh()

## Coming back to PREP from the room keeps the wave's "used"; a new wave's PREP clears it.
func _on_state_changed(new_state: StringName) -> void:
	if new_state == PREP and _state != HAZARD:
		_used = false
	_state = new_state
	_sent = false
	_refresh()

func _on_mode_changed(mode: StringName) -> void:
	_commander = mode == COMMANDER
	_refresh()

func _on_pause_changed(is_paused: bool) -> void:
	_paused = is_paused
	_refresh()

# TODO(Ender-Via): emit hazard_trial_offered(wave_index, enemy_types, mithril) at the start of PREP, so the tooltip lists the group.
func _on_offered(_wave_index: int, enemy_types: Array, mithril: int) -> void:
	_enemy_types = enemy_types.duplicate()
	_mithril = mithril
	_refresh()

func _on_exited(_result: StringName, _kills: int, _gold: int, _xp: float, _mithril_won: int) -> void:
	_used = true
	_refresh()
