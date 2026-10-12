extends Node3D
## Thử animation chỉ huy: combo 3 đòn và Dodge trước / sau, lặp liên tục.
## Bên trái đòn 3 dùng melee/Melee_2H_Attack_Spin (đủ lấy đà -> xoay -> về thế).
## Bên phải đòn 3 dùng melee/Melee_2H_Attack_Spinning (chỉ đoạn xoay), blend vào và ra.
## Dodge: chỉ trong lúc dodge mới bật AnimationPlayer.root_motion_track để khóa chuyển động
## của xương root, script tự di chuyển dodge_distance trong thời lượng clip, blend 0.1 s về Idle
## rồi mới tắt. Không bật thường trực vì cú xoay của đòn 3 cũng nằm ở xương root.

const COMMANDER := preload("res://contents/assets/characters/commander/commander_model.tscn")
const STATS := preload("res://data/config/commander_stats.tres")

const ROOT_TRACK := NodePath("Rig_Medium/Skeleton3D:root")
const IDLE := "general/Idle_A"
const HIT_1 := "melee/Melee_1H_Attack_Chop"
const HIT_2 := "melee/Melee_1H_Attack_Slice_Diagonal"
const HIT_3_SPIN := "melee/Melee_2H_Attack_Spin"
const HIT_3_SPINNING := "melee/Melee_2H_Attack_Spinning"
const DODGE_FORWARD := "advance/Dodge_Forward"
const DODGE_BACKWARD := "advance/Dodge_Backward"
const BLEND := 0.1
const SPINNING_BLEND := 0.15
const PAUSE := 0.6
const FACING := Vector3(1, 0, 0) # cả hai nhìn sang +X, dodge dọc trục X

var _rigs: Array[Dictionary] = []

@onready var _step_label: Label = %StepLabel


func _ready() -> void:
	_rigs.append(_spawn(Vector3(-2.5, 0, -3), HIT_3_SPIN, "Spin 2.40s"))
	_rigs.append(_spawn(Vector3(-2.5, 0, 3), HIT_3_SPINNING, "Spinning 0.67s"))
	for rig in _rigs:
		_loop(rig)


func _spawn(pos: Vector3, hit_3: String, title: String) -> Dictionary:
	var model := COMMANDER.instantiate() as Node3D
	model.position = pos
	# KayKit quay mặt về +Z, nên góc Y = atan2(x, z) thay vì công thức cho -Z
	model.rotation.y = atan2(FACING.x, FACING.z)
	add_child(model)
	var ap := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var label := Label3D.new()
	label.text = title
	label.position = Vector3(0, 2.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.outline_size = 8
	model.add_child(label)
	return {"model": model, "ap": ap, "hit_3": hit_3, "home": pos}


func _loop(rig: Dictionary) -> void:
	var ap: AnimationPlayer = rig.ap
	var model: Node3D = rig.model
	var spinning: bool = rig.hit_3 == HIT_3_SPINNING
	while is_inside_tree():
		model.position = rig.home
		_show(rig, "Idle")
		ap.play(IDLE, BLEND)
		await _wait(PAUSE)

		_show(rig, "Hit 1")
		await _play_once(ap, HIT_1, BLEND)
		_show(rig, "Hit 2")
		await _play_once(ap, HIT_2, BLEND)
		_show(rig, "Hit 3")
		await _play_once(ap, rig.hit_3, SPINNING_BLEND if spinning else BLEND)
		_show(rig, "Idle")
		ap.play(IDLE, SPINNING_BLEND if spinning else BLEND)
		await _wait(PAUSE)

		_show(rig, "Dodge forward")
		await _dodge(rig, DODGE_FORWARD, FACING)
		await _wait(PAUSE)

		# Đứng yên thì lùi về sau hướng aim (SRS 3.5)
		_show(rig, "Dodge backward")
		await _dodge(rig, DODGE_BACKWARD, -FACING)
		await _wait(PAUSE)


func _play_once(ap: AnimationPlayer, clip: String, blend: float) -> void:
	ap.play(clip, blend)
	await _wait(ap.get_animation(clip).length)


func _dodge(rig: Dictionary, clip: String, dir: Vector3) -> void:
	var ap: AnimationPlayer = rig.ap
	var model: Node3D = rig.model
	var duration := ap.get_animation(clip).length
	ap.root_motion_track = ROOT_TRACK
	ap.play(clip, BLEND)
	var tween := create_tween()
	tween.tween_property(model, "position", model.position + dir * STATS.dodge_distance, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished
	ap.play(IDLE, BLEND)
	await _wait(BLEND)
	ap.root_motion_track = NodePath()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _show(rig: Dictionary, step: String) -> void:
	rig["step"] = step
	var lines := PackedStringArray()
	for r in _rigs:
		lines.append("%s: %s" % [r.hit_3.get_file(), r.get("step", "")])
	_step_label.text = "\n".join(lines)
