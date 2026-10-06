extends Control
## Reads the save and recovers an interrupted run before MainMenu.

func _ready() -> void:
	# TODO: SaveManager load and interrupted run recovery.
	await get_tree().process_frame
	GameState.change_state(GameState.AppState.MAIN_MENU)
