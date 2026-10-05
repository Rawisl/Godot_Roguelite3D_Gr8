extends MarginContainer
## RunLoading (SCR-06). Placeholder: the 8 init steps (3.2.1) belong to RunState (TV2).

@onready var _bar: ProgressBar = %ProgressBar
@onready var _tip: Label = %Tip

func _ready() -> void:
	_tip.text = tr(&"loading.tip.1")
	_bar.value = 0
	# TODO(3.2.1, TV2): create RunConfig/RunState here and report progress.
	# Wait for the fade-in to finish, otherwise change_state is refused.
	while ScreenManager.is_fading():
		await get_tree().process_frame
	_bar.value = 100
	GameState.change_state(GameState.AppState.RUN)
