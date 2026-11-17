extends Control
## Reads the save and recovers an interrupted run before MainMenu.

func _ready() -> void:
	await get_tree().process_frame
	# Right before the screen change: the recovery notice then waits for the fade instead of being closed by it.
	SaveManager.recover_interrupted_run()
	GameState.change_state(GameState.AppState.MAIN_MENU)
