class_name SyncStatus
extends HBoxContainer
## Sync state as an icon with its name (Guest, Synced, Syncing, Offline, Error), so it never relies
## on the icon alone. Shown on MainMenu and in the Account tab; starts from the last state GameState
## heard and follows EventBus.sync_state_changed.

const STATES: Array[StringName] = [&"GUEST", &"SYNCED", &"SYNCING", &"OFFLINE", &"ERROR"]

var state: StringName = &"GUEST"

@onready var _glyph: SyncGlyph = %Glyph
@onready var _label: Label = %StateLabel

func _ready() -> void:
	EventBus.sync_state_changed.connect(_on_sync_state_changed)
	show_state(GameState.sync_state, GameState.sync_detail)

func show_state(new_state: StringName, detail: String = "") -> void:
	state = new_state if STATES.has(new_state) else &"ERROR"
	_glyph.state = state
	_label.text = tr(StringName("sync.state.%s" % String(state).to_lower()))
	tooltip_text = detail if detail != "" else tr(StringName("sync.tip.%s" % String(state).to_lower()))

func _on_sync_state_changed(new_state: StringName, detail: String) -> void:
	show_state(new_state, detail)
