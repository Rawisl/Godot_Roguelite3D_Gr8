extends Node3D
## Thử animation Bulwark. Stomp dùng một clip melee/Melee_2H_Slam cho cả wind-up lẫn cú nện
## (art/models_animations.md, mục Boss Bulwark).
## Hàng đầu: 4 cách khớp clip với wind-up 1.0 s game time và nhịp đánh 2.5 s (pha 1) / 1.9 s (pha 2).
##   A  pha 1, speed 1.0 suốt, blend sang Idle khi chùy về thế (clip 2.37 s)
##   B  pha 1, speed 0.97 trong wind-up để chùy chạm đất đúng 1.0 s, sau đó 1.0
##   C  pha 2 (đã chốt), speed 1.0 tới cú nện, đoạn hồi tăng lên 1.87 để chùy về thế ở 1.75 s
##      rồi blend 0.15 s sang Idle trước cú Stomp kế ở 1.9 s
##   D  pha 2, speed 1.0 suốt, chưa về thế đã blend sang Idle ở 1.75 s để kịp cú Stomp kế ở 1.9 s
## Hàng sau: Idle, Walking theo tốc độ pha 1 và pha 2 (chân phải bám đất, không trượt), Hit, Death.
## Vòng đỏ chỉ để giữ chỗ, chưa phải shader telegraph thật. Sát thương tính theo đồng hồ
## wind-up, còn "chạm đất" là lúc xương handslot.r xuống dưới GROUND_Y, để so hai mốc với nhau.
## Phím: Space dừng / chạy, R chạy lại từ đầu, 1-4 đổi tốc độ x0.25 / x1 / x2 / x3 (giả TimeManager).

const BULWARK := preload("res://contents/assets/characters/enemy and boss/boss_bulwark_model.tscn")

const SLAM := "melee/Melee_2H_Slam"
const IDLE := "general/Idle_A"
const WALK := "move/Walking_A"
const HIT := "general/Hit_A"
const DEATH := "general/Death_A"

const WINDUP := 1.0 # game time
const CLIP_RECOVERED := 2.37 # chùy về thế
const STOMP_RADIUS := 3.0
const BLEND := 0.15
const WALK_FOOT_SPEED := 1.42 # m/s mà Walking_A khớp ở speed_scale 1.0
const GROUND_Y := 0.25 # tay cầm chùy xuống dưới mức này coi như chùy chạm đất
const FLASH_TIME := 0.15
const HOLD_AFTER := 0.8 # Hit và Death đứng lại bao lâu trước khi lặp
const WALK_SPAN := 3.0 # quãng đi trước khi quay về chỗ cũ

const ROW_AXIS := Vector3(0.7071, 0, -0.7071) # hàng ngang trên màn hình
const TOWARD_CAMERA := Vector3(0.7071, 0, 0.7071)
const FRONT_DEPTH := 4.5
const BACK_DEPTH := -6.5
const FRONT_SPACING := 7.0
const BACK_SPACING := 5.5

const TIME_SCALES: Array[float] = [0.25, 1.0, 2.0, 3.0]

const SLAM_VARIANTS: Array[Dictionary] = [
	{"key": "A", "title": "Pha 1 · x1.0", "cadence": 2.5, "windup_speed": 1.0, "recovery_speed": 1.0, "cut": false},
	{"key": "B", "title": "Pha 1 · x0.97", "cadence": 2.5, "windup_speed": 0.97, "recovery_speed": 1.0, "cut": false},
	{"key": "C", "title": "Pha 2 · hồi x1.87 (chốt)", "cadence": 1.9, "windup_speed": 1.0, "recovery_speed": 1.87, "cut": false},
	{"key": "D", "title": "Pha 2 · cắt sang Idle", "cadence": 1.9, "windup_speed": 1.0, "recovery_speed": 1.0, "cut": true},
]

var _slams: Array[Dictionary] = []
var _others: Array[Dictionary] = []
var _time_scale := 1.0
var _paused := false

@onready var _info_label: Label = %InfoLabel
@onready var _table_label: Label = %TableLabel


func _ready() -> void:
	for i in SLAM_VARIANTS.size():
		var offset := (i - (SLAM_VARIANTS.size() - 1) * 0.5) * FRONT_SPACING
		var rig := _spawn(ROW_AXIS * offset + TOWARD_CAMERA * FRONT_DEPTH, TOWARD_CAMERA)
		rig.merge(SLAM_VARIANTS[i])
		_add_telegraph(rig)
		_slams.append(rig)

	var back: Array[Dictionary] = [
		{"kind": "loop", "title": "Idle_A", "clip": IDLE, "speed": 1.0},
		{"kind": "walk", "title": "Walk 1.6 m/s", "clip": WALK, "move_speed": 1.6},
		{"kind": "walk", "title": "Walk pha 2 1.92 m/s", "clip": WALK, "move_speed": 1.92},
		{"kind": "once", "title": "Hit_A", "clip": HIT, "speed": 1.0},
		{"kind": "once", "title": "Death_A", "clip": DEATH, "speed": 1.0},
	]
	for i in back.size():
		var offset := (i - (back.size() - 1) * 0.5) * BACK_SPACING
		var facing := ROW_AXIS if back[i].kind == "walk" else TOWARD_CAMERA
		var rig := _spawn(ROW_AXIS * offset + TOWARD_CAMERA * BACK_DEPTH, facing)
		rig.merge(back[i])
		if rig.kind == "walk":
			rig["speed"] = rig.move_speed / WALK_FOOT_SPEED
			rig.home -= ROW_AXIS * WALK_SPAN * 0.5
		_others.append(rig)

	_build_buttons()
	_restart()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_SPACE:
			_paused = not _paused
		KEY_R:
			_restart()
		KEY_1, KEY_2, KEY_3, KEY_4:
			_time_scale = TIME_SCALES[key.physical_keycode - KEY_1]


func _process(delta: float) -> void:
	var dt := 0.0 if _paused else delta * _time_scale
	for rig in _slams:
		_step_slam(rig, dt)
	for rig in _others:
		_step_other(rig, dt)
	_refresh_text()


func _spawn(pos: Vector3, facing: Vector3) -> Dictionary:
	var model := BULWARK.instantiate() as Node3D
	model.position = pos
	# KayKit quay mặt về +Z, nên góc Y = atan2(x, z)
	model.rotation.y = atan2(facing.x, facing.z)
	add_child(model)
	var ap := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	# Tự đẩy animation bằng advance() để dừng, tua và đổi tốc độ khớp với đồng hồ của scene
	ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skel := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var label := Label3D.new()
	label.position = Vector3(0, 4.3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 44
	label.pixel_size = 0.01
	label.outline_size = 10
	model.add_child(label)
	return {"model": model, "ap": ap, "skel": skel, "hand": skel.find_bone("handslot.r"),
		"label": label, "home": pos, "t": 0.0}


func _add_telegraph(rig: Dictionary) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = STOMP_RADIUS
	disc.bottom_radius = STOMP_RADIUS
	disc.height = 0.02
	disc.radial_segments = 48
	var area := MeshInstance3D.new()
	area.mesh = disc
	area.position.y = 0.02
	area.material_override = _flat_material(Color(0.9, 0.1, 0.1, 0.2))
	var fill := MeshInstance3D.new()
	fill.mesh = disc
	fill.position.y = 0.03
	fill.material_override = _flat_material(Color(0.9, 0.1, 0.1, 0.45))
	rig.model.add_child(area)
	rig.model.add_child(fill)
	rig["area"] = area
	rig["fill"] = fill


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat


func _restart() -> void:
	for rig in _slams:
		_start_slam(rig, 0.0)
		rig["contact_t"] = -1.0
		rig["impact_clip"] = -1.0
	for rig in _others:
		rig.t = 0.0
		rig.model.position = rig.home
		var ap: AnimationPlayer = rig.ap
		ap.speed_scale = rig.speed
		ap.play(rig.clip)
		ap.seek(0.0, true)
		rig["idle"] = false


func _start_slam(rig: Dictionary, blend: float) -> void:
	rig.t = 0.0
	rig["impacted"] = false
	rig["idle"] = false
	rig["flash"] = 0.0
	rig["contact_pending"] = true
	var ap: AnimationPlayer = rig.ap
	ap.speed_scale = rig.windup_speed
	ap.play(SLAM, blend)
	if blend == 0.0:
		ap.seek(0.0, true)


func _step_slam(rig: Dictionary, dt: float) -> void:
	var ap: AnimationPlayer = rig.ap
	var prev_t: float = rig.t
	rig.t += dt
	if rig.t >= rig.cadence:
		# Giữ phần dư của khung để các nhịp sau không lệch dần khỏi đồng hồ
		var left: float = rig.t - rig.cadence
		ap.advance(dt - left)
		_start_slam(rig, BLEND)
		rig.t = left
		ap.advance(left)
	elif rig.t >= WINDUP and not rig.impacted:
		# Sát thương theo đồng hồ wind-up, không chờ khung animation. Đổi tốc độ đúng mốc 1.0 s
		ap.advance(WINDUP - prev_t)
		rig.impacted = true
		rig.impact_clip = ap.current_animation_position
		rig.flash = FLASH_TIME
		ap.speed_scale = rig.recovery_speed
		ap.advance(rig.t - WINDUP)
	else:
		ap.advance(dt)
	var recovered: bool = not rig.cut and ap.current_animation_position >= CLIP_RECOVERED
	# Blend sang Idle trước khi hết nhịp để cú Stomp kế bắt đầu từ thế đứng, không giật
	var out_of_time: bool = rig.t >= rig.cadence - BLEND
	if rig.impacted and not rig.idle and (recovered or out_of_time):
		rig.idle = true
		ap.speed_scale = 1.0
		ap.play(IDLE, BLEND)

	if rig.contact_pending and rig.t > 0.5 and _hand_y(rig) < GROUND_Y:
		rig.contact_pending = false
		rig.contact_t = rig.t

	var winding: bool = not rig.impacted
	rig.fill.visible = winding
	rig.fill.scale = Vector3(1, 1, 1) * clampf(rig.t / WINDUP, 0.01, 1.0)
	rig.flash = maxf(0.0, rig.flash - dt)
	rig.area.visible = winding or rig.flash > 0.0
	var area_mat: StandardMaterial3D = rig.area.material_override
	area_mat.albedo_color = Color(1, 0.85, 0.8, 0.6) if rig.flash > 0.0 else Color(0.9, 0.1, 0.1, 0.2)


func _step_other(rig: Dictionary, dt: float) -> void:
	var ap: AnimationPlayer = rig.ap
	rig.t += dt
	match rig.kind:
		"walk":
			var travelled: float = fmod(rig.t * rig.move_speed, WALK_SPAN)
			rig.model.position = rig.home + ROW_AXIS * travelled
		"once":
			var length := ap.get_animation(rig.clip).length
			if rig.t >= length + HOLD_AFTER:
				rig.t = 0.0
				rig.idle = false
				ap.speed_scale = rig.speed
				ap.play(rig.clip, BLEND)
				ap.seek(0.0, true)
			elif rig.clip == HIT and rig.t >= length and not rig.idle:
				# Death giữ khung cuối, Hit đứng Idle chờ lượt sau
				rig.idle = true
				ap.play(IDLE, BLEND)
	ap.advance(dt)


func _hand_y(rig: Dictionary) -> float:
	var skel: Skeleton3D = rig.skel
	return (skel.global_transform * skel.get_bone_global_pose(rig.hand)).origin.y


func _slam_state(rig: Dictionary) -> String:
	if not rig.impacted:
		return "WIND-UP"
	if rig.flash > 0.0:
		return "NỆN"
	return "IDLE" if rig.idle else "HỒI"


func _refresh_text() -> void:
	var rows := PackedStringArray()
	rows.append("    t / nhịp       trạng thái  speed  clip           chạm đất  sát thương  lệch")
	for rig in _slams:
		var ap: AnimationPlayer = rig.ap
		rig.label.text = "%s  %s\n%.2f / %.2f s  %s\nspeed_scale %.2f" % [
			rig.key, rig.title, rig.t, rig.cadence, _slam_state(rig), ap.speed_scale]
		var contact := "--" if rig.contact_t < 0.0 else "%.2f s" % rig.contact_t
		var diff := "--" if rig.contact_t < 0.0 else "%+.2f s" % (rig.contact_t - WINDUP)
		rows.append("%s   %.2f / %.2f s  %-10s  %.2f   %-4s %.2f/%.2f  %-8s  %.2f s      %s" % [
			rig.key, rig.t, rig.cadence, _slam_state(rig), ap.speed_scale,
			ap.current_animation.get_file().left(4), ap.current_animation_position,
			ap.current_animation_length, contact, WINDUP, diff])
	_table_label.text = "\n".join(rows)
	for rig in _others:
		var ap: AnimationPlayer = rig.ap
		rig.label.text = "%s\n%.2f / %.2f s\nspeed_scale %.2f" % [
			rig.title, ap.current_animation_position, ap.current_animation_length, ap.speed_scale]
	_info_label.text = "Tốc độ game x%s%s   ·   Space dừng, R chạy lại, 1-4 = x0.25 / x1 / x2 / x3" % [
		str(_time_scale), "  (ĐANG DỪNG)" if _paused else ""]


func _build_buttons() -> void:
	var bar: HBoxContainer = %Buttons
	for level in TIME_SCALES:
		var button := Button.new()
		button.text = "x%s" % str(level)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: _time_scale = level)
		bar.add_child(button)
	var pause := Button.new()
	pause.text = "Dừng / chạy"
	pause.focus_mode = Control.FOCUS_NONE
	pause.pressed.connect(func() -> void: _paused = not _paused)
	bar.add_child(pause)
	var restart := Button.new()
	restart.text = "Chạy lại"
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(_restart)
	bar.add_child(restart)
