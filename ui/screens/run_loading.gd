extends MarginContainer
## Prepares a new run: builds the run config with the meta shop upgrades and a new run seed,
## loads the run scene in the background and fills the bar while it loads. The run scene's
## RunState takes the config, puts the run on the Fortress and the commander, places the
## starter towers, writes the run flag and starts the first PREP.

const RUN_SCENE := "res://main.tscn"
## Share of the bar for building the config; the scene load fills the rest.
const CONFIG_SHARE := 10.0

@onready var _bar: ProgressBar = %ProgressBar
@onready var _tip: Label = %Tip
## Holds the loaded scene so it stays in the cache until the scene change has used it.
var _run_scene: PackedScene


func _ready() -> void:
	_tip.text = tr(&"loading.tip.1")
	_bar.value = 0
	RunLoader.hand_over(RunLoader.build_config(RunLoader.saved_meta_levels()))
	_bar.value = CONFIG_SHARE
	await _load_run_scene()
	# Wait for the fade-in to finish, otherwise change_state is refused.
	while ScreenManager.is_fading():
		await get_tree().process_frame
	_bar.value = 100
	GameState.change_state(GameState.AppState.RUN)


## Loads the run scene on a thread so the bar moves. The loaded scene stays in the resource
## cache, so the scene change that follows does not load it again.
func _load_run_scene() -> void:
	if ResourceLoader.load_threaded_request(RUN_SCENE) != OK:
		return
	var progress := []
	while true:
		var status := ResourceLoader.load_threaded_get_status(RUN_SCENE, progress)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			break
		if not progress.is_empty():
			_bar.value = CONFIG_SHARE + float(progress[0]) * (100.0 - CONFIG_SHARE)
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(RUN_SCENE) == ResourceLoader.THREAD_LOAD_LOADED:
		_run_scene = ResourceLoader.load_threaded_get(RUN_SCENE) as PackedScene
