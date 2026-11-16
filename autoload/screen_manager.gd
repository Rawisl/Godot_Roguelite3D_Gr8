extends CanvasLayer
## Switches screens with a fade and owns the system dialog layer.
## Screens that support Back implement go_back(); Esc calls the same function
## Dialogs that support Esc implement cancel(); otherwise they are freed.
## A save problem found while loading at start, before this node listens, is shown once after the first screen change.

signal screen_changed(scene_path: String)
signal dialog_context_changed

const DIALOG_SCENE := preload("res://ui/screens/confirm_dialog.tscn")
const NOTICE_SCENE := preload("res://ui/screens/notice_dialog.tscn")

## Fade duration of each half (out, then in), in real time
@export var fade_duration: float = 0.25

var _is_fading: bool = false
## System notices waiting for the current dialog or fade to finish.
var _pending_notices: Array[Control] = []

@onready var _fade: ColorRect = %Fade
@onready var _dialog_holder: Control = %DialogHolder

func _ready() -> void:
	_dialog_holder.child_entered_tree.connect(func(_node: Node) -> void:
		dialog_context_changed.emit())
	# Deferred: the closing dialog is still a child while it exits the tree.
	_dialog_holder.child_exiting_tree.connect(func(_node: Node) -> void:
		dialog_context_changed.emit()
		_open_next_notice.call_deferred())
	EventBus.save_failed.connect(_on_save_failed)
	EventBus.run_recovered.connect(_on_run_recovered)
	_watch_startup_load_failure()

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
	_queue_notice(dialog)

## A NoticeDialog built by the caller (tone, short lines, value rows), queued like show_notice.
func show_notice_dialog(dialog: NoticeDialog) -> void:
	_queue_notice(dialog)

## A save problem: the lines say what happened, the note what the action does. Without an
## action it is a plain notice.
func _show_save_notice(tone: StringName, prefix: String, action_key: StringName = &"", action: Callable = Callable()) -> void:
	var dialog := NOTICE_SCENE.instantiate() as NoticeDialog
	dialog.setup(tone, StringName(prefix + ".title"), [tr(StringName(prefix + ".line1")), tr(StringName(prefix + ".line2"))],
		[], tr(StringName(prefix + ".note")))
	if action.is_valid():
		dialog.set_buttons(action_key, &"dialog.close")
		dialog.confirmed.connect(func() -> void: action.call())
	else:
		dialog.set_buttons(&"dialog.ok")
	_queue_notice(dialog)

func _queue_notice(dialog: Control) -> void:
	_pending_notices.append(dialog)
	_open_next_notice.call_deferred()

func has_dialog() -> bool:
	return _dialog_holder.get_child_count() > 0

## A sell or repair dialog is open, so starting the wave must wait.
func has_transaction_dialog() -> bool:
	for dialog in _dialog_holder.get_children():
		if dialog.has_method(&"is_transaction") and dialog.is_transaction():
			return true
	return false

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

func _on_save_failed(reason: StringName) -> void:
	push_warning("ScreenManager: save failed (%s)" % reason)
	match reason:
		SaveManager.REASON_CORRUPT:
			_show_save_notice(NoticeDialog.DANGER, "dialog.save_corrupt", &"dialog.save_corrupt.new", SaveManager.start_new_save)
		SaveManager.REASON_WRITE_ERROR:
			_show_save_notice(NoticeDialog.WARNING, "dialog.save_failed", &"dialog.save_failed.retry", SaveManager.save)
		SaveManager.REASON_VERSION_TOO_NEW:
			_show_save_notice(NoticeDialog.WARNING, "dialog.save_too_new")
		_:
			_show_save_notice(NoticeDialog.WARNING, "dialog.save_blocked")

## SaveManager loads before this node listens, so a failure from that first load is missed.
## Wait for the first screen change: the fade has closed all dialogs by then and the notice
## opens on the new screen.
func _watch_startup_load_failure() -> void:
	if SaveManager.load_failure == &"":
		return
	if screen_changed.is_connected(_show_startup_load_failure):
		return
	screen_changed.connect(_show_startup_load_failure, CONNECT_ONE_SHOT)

func _show_startup_load_failure(_scene_path: String) -> void:
	if SaveManager.load_failure == &"":
		return
	_on_save_failed(SaveManager.load_failure)

func _on_run_recovered(prestige_gain: int) -> void:
	show_notice(&"dialog.run_recovered.title", &"dialog.run_recovered.body", {"value": prestige_gain})

func _tween_fade(target_alpha: float) -> void:
	# Real time: ignores Engine.time_scale (x2/x3) and keeps running while paused.
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_fade, "color:a", target_alpha, fade_duration)
	await tween.finished
