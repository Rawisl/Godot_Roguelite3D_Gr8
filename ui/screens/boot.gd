extends Control
## Boot / Splash (SCR-01). Reads save and recovers an interrupted run (3.12.4)
## before MainMenu.

func _ready() -> void:
	# TODO(3.12.4, TV3): SaveManager load + interrupted run recovery here.
	await get_tree().process_frame
	GameState.change_state(GameState.AppState.MAIN_MENU)
