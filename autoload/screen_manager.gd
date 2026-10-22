extends CanvasLayer
## Switches screens with a fade and owns the system dialog layer.
## Screens that support Back implement go_back(); Esc calls the same function
## Dialogs that support Esc implement cancel(); otherwise they are freed.

signal screen_changed(scene_path: String)

const DIALOG_SCENE := preload("res://ui/screens/confirm_dialog.tscn")

## Fade duration of each half (out, then in), in real time
@export var fade_duration: float = 0.25

var _is_fading: bool = false
## System notices waiting for the current dialog or fade to finish.
var _pending_notices: Array[Control] = []

@onready var _fade: ColorRect = %Fade
@onready var _dialog_holder: Control = %DialogHolder

func _ready() -> void:
	# Deferred: the closing dialog is still a child while it exits the tree.
	_dialog_holder.child_exiting_tree.connect(func(_node: Node) -> void:
		_open_next_notice.call_deferred())
	EventBus.save_failed.connect(_on_save_failed)
	EventBus.run_recovered.connect(_on_run_recovered)

func _input(event: InputEvent) -> void:
	# Lock all input while fading
	if _is_fading:
		get_viewport().set_input_as_handled()
		return

	if not event.is_action_pressed(&"ui_cancel"):
		return

	# Esc closes the top dialog first, one step per press.
	if has_dialog():
		close_top_dialog()
		get_viewport().set_input_as_handled()
		return

	# Outside Run, Esc does the same as the screen's Back button
	# The Run scene has no go_back(), so Esc falls through to handling.
	var screen := get_tree().current_scene
	if screen != null and screen.has_method(&"go_back"):
		screen.go_back()
		get_viewport().set_input_as_handled()

func change_scene(scene_path: String) -> void:
	if _is_fading:
		return
	_is_fading = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade.visible = true

	await _tween_fade(1.0)
	close_all_dialogs()
	var err := get_tree().change_scene_to_file(scene_path)
	if err == OK:
		# The swap is deferred; wait until current_scene is the new screen.
		await get_tree().scene_changed
		screen_changed.emit(scene_path)
	else:
		push_error("ScreenManager: cannot load %s (error %d)" % [scene_path, err])
	await _tween_fade(0.0)

	_fade.visible = false
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_fading = false
	_open_next_notice()

func is_fading() -> bool:
	return _is_fading

func open_dialog(dialog: Control) -> bool:
	if has_dialog():
		dialog.queue_free()
		return false
	_dialog_holder.add_child(dialog)
	return true

## Unlike open_dialog, a notice is never dropped: it waits until no dialog is open
## and no fade is running, so one sent right before a screen change still shows.
func show_notice(title_key: StringName, body_key: StringName, params: Dictionary = {}) -> void:
	var dialog := DIALOG_SCENE.instantiate()
	dialog.setup_notice(title_key, body_key, params)
	_pending_notices.append(dialog)
	_open_next_notice.call_deferred()

func has_dialog() -> bool:
	return _dialog_holder.get_child_count() > 0

func close_top_dialog() -> void:
	if not has_dialog():
		return
	var dialog := _dialog_holder.get_child(-1)
	if dialog.has_method(&"cancel"):
		dialog.cancel()
	else:
		dialog.queue_free()

func close_all_dialogs() -> void:
	for dialog in _dialog_holder.get_children():
		dialog.queue_free()

func _open_next_notice() -> void:
	if _is_fading or has_dialog() or _pending_notices.is_empty():
		return
	_dialog_holder.add_child(_pending_notices.pop_front())

# TODO: add a Retry button once SaveManager can retry a failed write.
func _on_save_failed(reason: StringName) -> void:
	push_warning("ScreenManager: save failed (%s)" % reason)
	show_notice(&"dialog.save_failed.title", &"dialog.save_failed.body")

func _on_run_recovered(prestige_gain: int) -> void:
	show_notice(&"dialog.run_recovered.title", &"dialog.run_recovered.body", {"value": prestige_gain})

func _tween_fade(target_alpha: float) -> void:
	# Real time: ignores Engine.time_scale (x2/x3) and keeps running while paused.
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_fade, "color:a", target_alpha, fade_duration)
	await tween.finished
