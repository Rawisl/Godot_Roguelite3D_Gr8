extends Node
## Run scene for quick playtests: main.tscn plus the cheat panel (PageUp). Open it with F6.
## RunState starts a run by itself only inside res://main.tscn, so this root repeats its start
## steps in the same order: config in _enter_tree, then scene values, starter towers and run start.
## Progress made here is never written to the save, the cloud or the leaderboard.

const RUN_STATE_PATH := ^"Gameplay/RunState"


func _enter_tree() -> void:
	# The app state only knows main.tscn as a run, so set it by hand; otherwise Esc and the
	# end of the run would not work.
	GameState.current = GameState.AppState.RUN
	SaveManager.can_write = false
	# When this scene is the main scene (F6), its _enter_tree runs before the SaveManager autoload
	# is ready, so the save data is still empty and has no repository. Load it here so the run
	# config reads the real meta levels; SaveManager reloads it again in its own _ready.
	if SaveManager.repository == null:
		SaveManager.set_repository(LocalSaveRepository.new())
		SaveManager.load_save()
		SaveManager.can_write = false
	var run_state := _run_state()
	if run_state == null:
		return
	run_state.init_from_config(RunLoader.take())


func _ready() -> void:
	_start_run.call_deferred()


func _exit_tree() -> void:
	# Drops every in-memory change of this run and restores the write flag of the real save.
	SaveManager.load_save()


func _start_run() -> void:
	# SaveManager._ready (F6) and load_save() both set can_write back to true, so block the
	# writes again now that every autoload is ready and before start_run() records the run.
	SaveManager.can_write = false
	var run_state := _run_state()
	if run_state == null:
		return
	run_state.apply_to_scene()
	run_state.place_starter_towers()
	run_state.start_run()


func _run_state() -> RunState:
	return get_node_or_null(RUN_STATE_PATH) as RunState
