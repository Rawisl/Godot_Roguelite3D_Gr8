extends Panel
## Light blue screen border while the commander is in Commander mode and cannot be hurt.

func _ready() -> void:
	visible = false
	EventBus.run_started.connect(_on_run_started)
	EventBus.mode_changed.connect(_on_mode_changed)

func _on_run_started() -> void:
	visible = false

func _on_mode_changed(mode: StringName) -> void:
	visible = mode == &"COMMANDER"
