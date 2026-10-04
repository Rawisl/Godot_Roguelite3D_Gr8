extends CanvasLayer
## Switches screens with a fade and owns the system dialog layer.
## Screens that support Back implement go_back(); Esc calls the same function (SCR-13).
## Dialogs that support Esc implement cancel(); otherwise they are freed.

signal screen_changed(scene_path: String)

## Fade duration of each half (out, then in), in real time (SCR-15).
@export var fade_duration: float = 0.25

var _is_fading: bool = false

@onready var _fade: ColorRect = $Fade
@onready var _dialog_holder: Control = $DialogHolder

func _input(event: InputEvent) -> void:
	# Lock all input while fading (SCR-15).
	if _is_fading:
		get_viewport().set_input_as_handled()
		return

	if not event.is_action_pressed(&"ui_cancel"):
		return

	# Esc closes the top dialog first (INP-03 step 1), one step per press.
	if has_dialog():
		close_top_dialog()
		get_viewport().set_input_as_handled()
		return

	# Outside Run, Esc does the same as the screen's Back button (SCR-13).
	# The Run scene has no go_back(), so Esc falls through to INP-03 handling.
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

func is_fading() -> bool:
	return _is_fading

func open_dialog(dialog: Control) -> void:
	_dialog_holder.add_child(dialog)

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

func _tween_fade(target_alpha: float) -> void:
	# Real time: ignores Engine.time_scale (x2/x3) and keeps running while paused (UI-02).
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_fade, "color:a", target_alpha, fade_duration)
	await tween.finished
