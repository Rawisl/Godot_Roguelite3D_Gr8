extends CanvasLayer
## Draws only from EventBus signals; never reads gameplay nodes.

func _ready() -> void:
	# F1 must still work while the run is paused, for screenshots.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_hud"):
		visible = not visible
		get_viewport().set_input_as_handled()
