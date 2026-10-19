extends Node3D

const ARROW_SCENE := preload("res://entities/tower/arrow.tscn")
const ARROW_DATA := preload("res://data/towers/arrow.tres")
const STATE_MARK := {
	Enums.SlotState.EMPTY: "+",
	Enums.SlotState.OCCUPIED: "Arrow",
	Enums.SlotState.RUINED: "x",
}

var _buttons: Dictionary = {}  # StringName -> Button

## The SlotManager is the level's Slots node (levels/corridor/slots_layout.tscn).
@onready var slot_manager: SlotManager = %Level.get_node("%Slots")
@onready var wave_manager: WaveManager = %WaveManager
@onready var slot_rows: VBoxContainer = %SlotRows
@onready var wave_label: Label = %WaveLabel
@onready var call_button: Button = %CallButton


func _ready() -> void:
	for zone in [Enums.SlotZone.WALL, Enums.SlotZone.GROUND]:
		var row := HBoxContainer.new()
		slot_rows.add_child(row)
		for slot in slot_manager.get_slots_in_zone(zone):
			var b := Button.new()
			b.custom_minimum_size = Vector2(110, 44)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_on_slot_button_pressed.bind(slot))
			row.add_child(b)
			_buttons[slot.slot_id] = b
			_refresh_button(slot)

	# Also catches towers that enemies destroy on their own.
	EventBus.slot_state_changed.connect(_on_slot_state_changed)
	call_button.pressed.connect(func(): EventBus.early_call_requested.emit())


func _process(_delta: float) -> void:
	var state: String = Enums.WaveState.keys()[wave_manager.wave_state]
	var text := "Wave %d  %s" % [wave_manager.current_wave, state]
	if wave_manager.wave_state == Enums.WaveState.PREP:
		text += "  %ds" % ceili(maxf(0.0, wave_manager.prep_timer))
	text += "  |  alive %d  queue %d" % [wave_manager.enemies_alive, wave_manager.spawn_queue.size()]
	wave_label.text = text
	call_button.disabled = wave_manager.wave_state != Enums.WaveState.PREP


func _on_slot_button_pressed(slot: Slot) -> void:
	if slot.state == Enums.SlotState.OCCUPIED:
		slot.ruin()
		return
	if not slot.can_build(ARROW_DATA):
		push_warning("Playtest: Arrow is not allowed on slot %s" % slot.slot_id)
		return
	slot.place_tower(ARROW_SCENE.instantiate() as Tower)
	EventBus.tower_built.emit(slot.slot_id, ARROW_DATA.id)


func _on_slot_state_changed(slot_id: StringName, _state: StringName) -> void:
	var slot := slot_manager.get_slot(slot_id)
	if slot != null:
		_refresh_button(slot)


func _refresh_button(slot: Slot) -> void:
	var b: Button = _buttons.get(slot.slot_id)
	if b != null:
		b.text = "%s  %s" % [slot.slot_id, STATE_MARK[slot.state]]
