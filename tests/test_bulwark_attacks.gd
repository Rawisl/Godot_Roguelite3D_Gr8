extends Node3D

## Test scene for Bulwark attack sequences & single attacks:
## - Attack 1: Stomp Slam (1x Stomp standard AoE)
## - Attack 2: Triple Stomp (3x consecutive stomps with expanding radius: 3.0m -> 4.5m -> 6.6m)
## - Attack 3: Combo Slam (1H Slash -> 1H Stab -> 2H Ground Slam AoE)
## - Attack 4: Guard Combo (Block posture -> 1H Slash -> 1H Stab -> 2H Attack)
## - Attack 5: Two-handed slash combo (Melee_2H_Attack x2)
## - Attack 6: Dual-wield sequence (Melee_Dualwield_Slash -> Dualwield_SlashCombo)
## - Attack 7: 1H Slash into reverse combo (Melee_1H_Slash -> Dualwield_SlashCombo)
## - Single moves: 1H Slash, 2H Attack, Dualwield Slash, Offhand/Reverse Slash, 1H Stab
## - Visual Telegraph Rings & Screen Shake on ground slam impacts
## - Multi-angle Camera: Front, Back, Side, Isometric
## - A stand-in commander you can move (arrows, or click the floor) to tune hitboxes and hit
##   timing: the current step's hitbox is drawn in yellow, then flashes red when it hits the
##   commander or white when it misses, and every hit is logged with its time in the sequence.

const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const COMMANDER_MODEL: PackedScene = preload("res://contents/assets/characters/fox_commander/fox_commander_model.tscn")
const COMMANDER_START := Vector3(0.0, 0.0, 2.2)
## The waves the wave script sends the Bulwark on, first to third appearance.
const BOSS_WAVES: Array[int] = [5, 15, 25]
const COMMANDER_RADIUS: float = 0.4  # same capsule as entities/commander/commander.tscn
const MOVE_STEP: float = 0.25
const FINE_STEP: float = 0.05
const HITBOX_FLASH_TIME: float = 0.6
const HITBOX_Y: float = 0.05
const LOG_LINES: int = 8
const COLOR_PREVIEW := Color(1.0, 0.85, 0.2)
const COLOR_HIT := Color(1.0, 0.2, 0.2)
const COLOR_MISS := Color(0.9, 0.9, 0.9)
const COLOR_BODY := Color(0.3, 1.0, 0.7)

enum CameraView {
	FRONT,
	BACK,
	SIDE,
	ISOMETRIC,
}

var _bulwark: Bulwark = null
var _telegraph_fx: TelegraphFxManager = null
var _current_view: CameraView = CameraView.FRONT
var _current_attack_title: String = "Ready (Idle)"
var _current_step_title: String = "Waiting for a command"
var _rotation_y: float = 0.0  # KayKit naturally faces +Z
var _shake_intensity: float = 0.0

var _commander: ShowcaseCommander = null
var _hitbox_mesh: ImmediateMesh = null
var _show_hitboxes: bool = true
## Hitbox of the step being wound up: {attack_id, step_name, hitbox}. Empty when none.
var _preview: Dictionary = {}
## Hitboxes frozen at the moment they hit: {hitbox, origin, forward, color, ttl}.
var _flashes: Array[Dictionary] = []
var _sequence_time: float = 0.0
var _hit_log: PackedStringArray = []
## AI mode: the boss fights the commander on its own instead of waiting for buttons.
var _ai_mode: bool = false

@onready var _camera: Camera3D = %Camera3D
@onready var _anim_info_label: Label = %AnimInfoLabel
@onready var _commander_label: Label = %CommanderLabel
@onready var _hit_log_label: Label = %HitLogLabel
@onready var _status_label: Label = %StatusLabel
@onready var _step_container: HBoxContainer = %StepContainer

@onready var _btn_attack1: Button = %BtnAttack1
@onready var _btn_triple_stomp: Button = %BtnTripleStomp
@onready var _btn_combo_slam: Button = %BtnComboSlam
@onready var _btn_attack2: Button = %BtnAttack2
@onready var _btn_attack3: Button = %BtnAttack3
@onready var _btn_idle: Button = %BtnIdle

@onready var _btn_single_1h: Button = %BtnSingle1H
@onready var _btn_single_2h: Button = %BtnSingle2H
@onready var _btn_single_dual: Button = %BtnSingleDual
@onready var _btn_single_offhand: Button = %BtnSingleOffhand
@onready var _btn_single_stab: Button = %BtnSingleStab

@onready var _btn_cam_front: Button = %BtnCamFront
@onready var _btn_cam_back: Button = %BtnCamBack
@onready var _btn_cam_side: Button = %BtnCamSide
@onready var _btn_cam_iso: Button = %BtnCamIso
@onready var _speed_group: HBoxContainer = %SpeedGroup


func _ready() -> void:
	_setup_telegraph_fx()
	_setup_hitbox_drawer()
	_spawn_commander()
	_spawn_bulwark()
	_setup_ui()
	_set_camera_view(CameraView.FRONT)
	_build_idle_pills()
	EventBus.screen_shake_requested.connect(_on_screen_shake_requested)


func _exit_tree() -> void:
	if EventBus.screen_shake_requested.is_connected(_on_screen_shake_requested):
		EventBus.screen_shake_requested.disconnect(_on_screen_shake_requested)


func _setup_telegraph_fx() -> void:
	_telegraph_fx = TelegraphFxManager.new()
	_telegraph_fx.name = "TelegraphFxManagerInstance"
	add_child(_telegraph_fx)


func _spawn_bulwark() -> void:
	if _bulwark != null and is_instance_valid(_bulwark):
		_bulwark.queue_free()

	_bulwark = BULWARK_SCENE.instantiate() as Bulwark
	_bulwark.name = "BulwarkInstance"
	_bulwark.position = Vector3(0.0, 0.0, 0.0)
	_bulwark.rotation.y = _rotation_y
	add_child(_bulwark)

	# Start on the third appearance so every move is unlocked; N steps through the others.
	_bulwark.spawn_wave = BOSS_WAVES[2]

	# Disable physics process so gravity/navigation AI does not drop or move the boss in test environment
	_bulwark.set_physics_process(false)
	_bulwark.velocity = Vector3.ZERO

	# Play clean Idle
	if _bulwark.anim_player != null and _bulwark.anim_player.has_animation(&"general/Idle_A"):
		_bulwark.anim_player.play(&"general/Idle_A", 0.1)

	# Connect signals for live feedback
	_bulwark.attack_step_started.connect(_on_attack_step_started)
	_bulwark.attack_sequence_finished.connect(_on_attack_sequence_finished)
	_bulwark.attack_hit.connect(_on_attack_hit)
	_preview = {}


func _spawn_commander() -> void:
	_commander = ShowcaseCommander.new()
	_commander.name = "ShowcaseCommander"
	add_child(_commander)
	_commander.global_position = COMMANDER_START
	_commander.add_model(COMMANDER_MODEL)
	_commander.hit_taken.connect(_on_commander_hit_taken)


func _setup_hitbox_drawer() -> void:
	_hitbox_mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "HitboxDrawer"
	mesh_instance.mesh = _hitbox_mesh
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _setup_ui() -> void:
	_btn_attack1.pressed.connect(_on_attack1_pressed)
	_btn_triple_stomp.pressed.connect(_on_triple_stomp_pressed)
	_btn_combo_slam.pressed.connect(_on_combo_slam_pressed)
	_btn_attack2.pressed.connect(_on_attack2_pressed)
	_btn_attack3.pressed.connect(_on_attack3_pressed)
	_btn_idle.pressed.connect(_on_idle_pressed)

	_btn_single_1h.pressed.connect(_on_single_1h_pressed)
	_btn_single_2h.pressed.connect(_on_single_2h_pressed)
	_btn_single_dual.pressed.connect(_on_single_dual_pressed)
	_btn_single_offhand.pressed.connect(_on_single_offhand_pressed)
	_btn_single_stab.pressed.connect(_on_single_stab_pressed)

	_btn_cam_front.pressed.connect(func() -> void: _set_camera_view(CameraView.FRONT))
	_btn_cam_back.pressed.connect(func() -> void: _set_camera_view(CameraView.BACK))
	_btn_cam_side.pressed.connect(func() -> void: _set_camera_view(CameraView.SIDE))
	_btn_cam_iso.pressed.connect(func() -> void: _set_camera_view(CameraView.ISOMETRIC))

	var speeds: Array[float] = [0.25, 0.5, 1.0, 2.0]
	for spd in speeds:
		var btn := Button.new()
		btn.text = "x%.2f" % spd
		btn.custom_minimum_size = Vector2(70, 32)
		btn.pressed.connect(func() -> void: Engine.time_scale = spd)
		_speed_group.add_child(btn)


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_place_commander_at_screen(click.position)
		return

	var key := event as InputEventKey
	if key == null or not key.pressed:
		return

	# Arrow keys repeat while held, so the commander can be walked into place.
	var step := FINE_STEP if key.shift_pressed else MOVE_STEP
	match key.physical_keycode:
		KEY_UP:
			_move_commander(_camera_forward() * step)
			return
		KEY_DOWN:
			_move_commander(-_camera_forward() * step)
			return
		KEY_LEFT:
			_move_commander(-_camera_right() * step)
			return
		KEY_RIGHT:
			_move_commander(_camera_right() * step)
			return
	if key.echo:
		return

	match key.physical_keycode:
		KEY_T:
			_commander.is_dodging = not _commander.is_dodging
			_log("Dodge: %s" % ("ON (dodges every hit)" if _commander.is_dodging else "OFF"))
		KEY_G:
			_commander.global_position = COMMANDER_START
		KEY_H:
			_show_hitboxes = not _show_hitboxes
		KEY_A:
			_set_ai_mode(not _ai_mode)
		KEY_K:
			_toggle_boss_low_hp()
		KEY_N:
			_cycle_boss_appearance()
		KEY_Z:
			_bulwark.in_hazard_trial = not _bulwark.in_hazard_trial
			_log("Boss in Hazard Trial: %s" % ("YES (moveset %d appearance(s) back)" % (_bulwark.data as BossData).hazard_appearance_offset if _bulwark.in_hazard_trial else "NO"))
		KEY_1:
			_on_attack1_pressed()
		KEY_2:
			_on_triple_stomp_pressed()
		KEY_3:
			_on_combo_slam_pressed()
		KEY_4:
			_on_attack2_pressed()
		KEY_5:
			_on_attack3_pressed()
		KEY_6:
			_on_single_1h_pressed()
		KEY_7:
			_on_single_2h_pressed()
		KEY_8:
			_on_single_dual_pressed()
		KEY_9:
			_on_single_offhand_pressed()
		KEY_0:
			_on_single_stab_pressed()
		KEY_SPACE:
			_on_idle_pressed()
		KEY_C:
			_cycle_camera_view()
		KEY_F:
			_set_camera_view(CameraView.FRONT)
		KEY_B:
			_set_camera_view(CameraView.BACK)
		KEY_S:
			_set_camera_view(CameraView.SIDE)
		KEY_I:
			_set_camera_view(CameraView.ISOMETRIC)
		KEY_Q:
			_rotate_bulwark(-PI * 0.125)
		KEY_E:
			_rotate_bulwark(PI * 0.125)
		KEY_R:
			_rotation_y = 0.0
			_spawn_bulwark()
			_current_attack_title = "Position reset (Idle)"
			_current_step_title = "Waiting for a command"
			_build_idle_pills()


func _camera_forward() -> Vector3:
	var fwd := -_camera.global_transform.basis.z
	fwd.y = 0.0
	return fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD


func _camera_right() -> Vector3:
	var right := _camera.global_transform.basis.x
	right.y = 0.0
	return right.normalized() if right.length_squared() > 0.001 else Vector3.RIGHT


func _move_commander(offset: Vector3) -> void:
	if _commander != null:
		_commander.global_position += offset


func _place_commander_at_screen(screen_pos: Vector2) -> void:
	if _commander == null:
		return
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if hit != null:
		_commander.global_position = hit as Vector3


func _set_ai_mode(enabled: bool) -> void:
	_ai_mode = enabled
	if _bulwark == null:
		return
	_bulwark.stop_attack_sequence()
	_bulwark.set_physics_process(enabled)
	_bulwark.velocity = Vector3.ZERO
	if enabled:
		_bulwark.spawn_grace = false
		_bulwark.is_in_spawn_zone = false
		_bulwark.set_target(_commander)
		_bulwark.change_state(Enums.EnemyState.CHASE)
		_current_attack_title = "AI: BOSS FIGHTS THE COMMANDER"
		_reset_sequence_clock()
	else:
		_bulwark.change_state(Enums.EnemyState.ADVANCE)
		_bulwark.set_physics_process(false)
		_current_attack_title = "AI off (Idle)"
		if _bulwark.anim_player != null:
			_bulwark.anim_player.play(&"general/Idle_A", 0.2)
	_log("AI: %s" % ("ON" if enabled else "OFF"))


## Toggles the boss between full health and 45% (armor nearly gone, still in the armored phase),
## to try the low-health move table without breaking the armor.
func _toggle_boss_low_hp() -> void:
	if _bulwark == null:
		return
	if _bulwark.get_hp_fraction() < 1.0:
		_bulwark.current_armor_hp = _bulwark.max_armor_hp
	else:
		var total := _bulwark.max_armor_hp + _bulwark.max_core_hp
		_bulwark.current_armor_hp = maxi(1, int(round(total * 0.45)) - _bulwark.current_core_hp)
	_log("Boss HP: %d%%" % int(round(_bulwark.get_hp_fraction() * 100.0)))


## Steps the boss through its three scripted appearances (waves 5, 15, 25) to try each unlocked
## moveset. Only the move table changes; HP and damage stay at the wave 1 numbers.
func _cycle_boss_appearance() -> void:
	if _bulwark == null:
		return
	var next := _bulwark.get_appearance() + 1
	if next > BOSS_WAVES.size():
		next = 1
	_bulwark.spawn_wave = BOSS_WAVES[next - 1]
	_log("Boss appearance %d (wave %d)" % [next, _bulwark.spawn_wave])


func _rotate_bulwark(angle_delta: float) -> void:
	_rotation_y += angle_delta
	if _bulwark != null and is_instance_valid(_bulwark):
		_bulwark.rotation.y = _rotation_y


func _on_screen_shake_requested(intensity: float, _source: StringName) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)


func _process(delta: float) -> void:
	# Camera shake decay
	if _camera != null and is_instance_valid(_camera):
		if _shake_intensity > 0.001:
			_camera.h_offset = randf_range(-_shake_intensity, _shake_intensity) * 0.08
			_camera.v_offset = randf_range(-_shake_intensity, _shake_intensity) * 0.08
			_shake_intensity = lerpf(_shake_intensity, 0.0, delta * 7.0)
		else:
			_camera.h_offset = 0.0
			_camera.v_offset = 0.0

	if _bulwark == null or not is_instance_valid(_bulwark):
		return

	var ap := _bulwark.anim_player
	if ap != null and ap.is_playing():
		var cur_anim := ap.current_animation
		var pos := ap.current_animation_position
		var len_s := ap.current_animation_length
		_anim_info_label.text = "Clip: %s | %.2fs / %.2fs (anim speed: x%.2f, engine: x%.2f)" % [
			cur_anim, pos, len_s, ap.speed_scale, Engine.time_scale
		]
	else:
		_anim_info_label.text = "AnimationPlayer: stopped / no clip"

	_status_label.text = "ACTION: %s\nSTEP: %s" % [_current_attack_title, _current_step_title]

	# delta is game time here (scaled by the speed buttons), the same clock the boss uses.
	if _boss_attacking():
		_sequence_time += delta
	for flash in _flashes:
		flash["ttl"] = float(flash["ttl"]) - delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return float(f["ttl"]) > 0.0)

	if _ai_mode:
		# Keep the boss locked on the commander wherever it is moved; no Fortress in this scene.
		_bulwark.taunted_by_player = true
		_bulwark.taunt_timer = 999.0
	_update_commander_view()
	_draw_hitboxes()


## The single stomp runs on the ATTACK state timers, not as a sequence, so count that too.
func _boss_attacking() -> bool:
	return _bulwark.is_in_attack_sequence or (_ai_mode and _bulwark.current_state == Enums.EnemyState.ATTACK)


func _update_commander_view() -> void:
	if _commander == null:
		return
	var to_boss := _bulwark.global_position - _commander.global_position
	to_boss.y = 0.0
	if to_boss.length_squared() > 0.001:
		_commander.rotation.y = atan2(to_boss.x, to_boss.z)

	var offset := -to_boss
	var dist := offset.length()
	var fwd := _bulwark.global_transform.basis.z
	fwd.y = 0.0
	var angle := rad_to_deg(fwd.normalized().angle_to(offset)) if dist > 0.01 else 0.0
	var right_side := fwd.cross(offset).y < 0.0
	_commander_label.text = "Commander: x=%.2f z=%.2f | %.2f m from boss center (%.2f m from body edge) | %.0f° off boss facing, %s (%s) | Dodge: %s | Damage taken: %d
Boss: HP %d%% | appearance %d (moveset %d%s) | AI: %s | triple stomp cooldown: %.1fs" % [
		_commander.global_position.x, _commander.global_position.z, dist,
		maxf(0.0, dist - COMMANDER_RADIUS), angle, "right" if right_side else "left",
		"IN FRONT" if _bulwark.is_in_front(_commander) else "FLANK/BEHIND",
		"ON" if _commander.is_dodging else "off", _commander.total_damage,
		int(round(_bulwark.get_hp_fraction() * 100.0)), _bulwark.get_appearance(),
		_bulwark.get_moveset_appearance(), ", Hazard" if _bulwark.in_hazard_trial else "",
		"ON" if _ai_mode else "off",
		_bulwark.triple_stomp_cooldown_left,
	]


# --- Hitbox drawing ---

func _draw_hitboxes() -> void:
	_hitbox_mesh.clear_surfaces()
	if not _show_hitboxes:
		return
	_hitbox_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_circle(_commander.global_position, COMMANDER_RADIUS, COLOR_BODY)
	if not _preview.is_empty() and _boss_attacking():
		_add_hitbox(_preview["hitbox"], _bulwark.global_position, _bulwark.global_transform.basis.z, COLOR_PREVIEW)
	for flash in _flashes:
		_add_hitbox(flash["hitbox"], flash["origin"], flash["forward"], flash["color"])
	_hitbox_mesh.surface_add_vertex(Vector3.ZERO)  # a surface needs at least one vertex pair
	_hitbox_mesh.surface_add_vertex(Vector3.ZERO)
	_hitbox_mesh.surface_end()


func _add_hitbox(hitbox: Dictionary, origin: Vector3, forward: Vector3, color: Color) -> void:
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.BACK
	var right := Vector3.UP.cross(forward)
	match hitbox.get("shape", &""):
		&"circle":
			var center := origin + forward * float(hitbox.get("forward_offset", 0.0))
			_add_circle(center, float(hitbox["radius"]), color)
			_add_line(origin, center, color)  # links the boss to where its mace lands
		&"sector":
			var reach := float(hitbox["reach"])
			var half := deg_to_rad(float(hitbox["arc_deg"]) * 0.5)
			var segments := 24
			var prev := origin + forward.rotated(Vector3.UP, -half) * reach
			_add_line(origin, prev, color)
			for i in range(1, segments + 1):
				var a := lerpf(-half, half, float(i) / segments)
				var p := origin + forward.rotated(Vector3.UP, a) * reach
				_add_line(prev, p, color)
				prev = p
			_add_line(prev, origin, color)
		&"box":
			var reach := float(hitbox["reach"])
			var w := float(hitbox["width"]) * 0.5
			var a := origin - right * w
			var b := origin + right * w
			var c := b + forward * reach
			var d := a + forward * reach
			_add_line(a, b, color)
			_add_line(b, c, color)
			_add_line(c, d, color)
			_add_line(d, a, color)


func _add_circle(center: Vector3, radius: float, color: Color) -> void:
	var segments := 48
	var prev := center + Vector3(radius, 0.0, 0.0)
	for i in range(1, segments + 1):
		var a := TAU * float(i) / segments
		var p := center + Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		_add_line(prev, p, color)
		prev = p


func _add_line(a: Vector3, b: Vector3, color: Color) -> void:
	a.y = HITBOX_Y
	b.y = HITBOX_Y
	_hitbox_mesh.surface_set_color(color)
	_hitbox_mesh.surface_add_vertex(a)
	_hitbox_mesh.surface_set_color(color)
	_hitbox_mesh.surface_add_vertex(b)


# --- Hit log ---

func _log(text: String) -> void:
	_hit_log.append(text)
	while _hit_log.size() > LOG_LINES:
		_hit_log.remove_at(0)
	_hit_log_label.text = "Hit log (t = game seconds since the sequence started):\n" + "\n".join(_hit_log)
	print(text)


func _on_commander_hit_taken(amount: int, damage_type: Enums.DamageType, knockback: float) -> void:
	_log("[t=%5.2fs]   -> commander takes %d %s%s" % [
		_sequence_time, amount, Enums.DamageType.keys()[damage_type],
		(" | knockback %.1f m" % knockback) if knockback > 0.0 else "",
	])


func _on_attack_hit(_attack_id: int, step_name: StringName, targets: Array) -> void:
	var hit := targets.has(_commander)
	if not _preview.is_empty():
		_flashes.append({
			"hitbox": _preview["hitbox"],
			"origin": _bulwark.global_position,
			"forward": _bulwark.global_transform.basis.z,
			"color": COLOR_HIT if hit else COLOR_MISS,
			"ttl": HITBOX_FLASH_TIME,
		})
		_preview = {}
	if not hit:
		_log("[t=%5.2fs] %s lands: MISSED the commander%s" % [
			_sequence_time, step_name, " (dodging)" if _commander.is_dodging else ""])


# --- Attack triggers ---

func _on_attack1_pressed() -> void:
	if _bulwark == null:
		return
	_current_attack_title = "ATTACK 1: STOMP (SINGLE SLAM R=3.0m)"
	_current_step_title = "Winding up..."
	_build_pills(["1. Wind-up [1.0s]", "2. Slam [R=3.0m]"])
	_highlight_step(0)
	_reset_sequence_clock()
	_bulwark.play_attack_1()


func _on_triple_stomp_pressed() -> void:
	if _bulwark == null:
		return
	_current_attack_title = "ATTACK 2: TRIPLE STOMP (GROWING RINGS)"
	_current_step_title = "Preparing stomp 1..."
	var pills: Array[String] = []
	for i in range(_bulwark.get_triple_stomp_count()):
		pills.append("%d. Stomp %d [R=%.1fm, %.2fs]" % [i + 1, i + 1, _bulwark.get_triple_stomp_radius(i), _bulwark.get_triple_stomp_step_length()])
	_build_pills(pills)
	_highlight_step(0)
	_reset_sequence_clock()
	_bulwark.play_triple_stomp()


func _on_combo_slam_pressed() -> void:
	if _bulwark == null:
		return
	_current_attack_title = "ATTACK 3: SLASH - STAB - TWO-HANDED GROUND SLAM"
	_current_step_title = "Opening one-handed slash..."
	_build_pills(["1. One-handed slash [1.57s]", "2. One-handed stab [1.40s]", "3. Two-handed ground slam [2.83s]"])
	_highlight_step(0)
	_reset_sequence_clock()
	_bulwark.play_attack_combo_slam()


func _on_attack2_pressed() -> void:
	if _bulwark == null:
		return
	_current_attack_title = "ATTACK 4: GUARD + THREE-HIT COMBO"
	_current_step_title = "Raising guard..."
	_build_pills(["1. Guard [Melee_Block]", "2. One-handed slash [Melee_1H_Slash]", "3. One-handed stab [Melee_1H_Stab]", "4. Two-handed chop [Melee_2H_Attack]"])
	_highlight_step(0)
	_reset_sequence_clock()
	_bulwark.play_attack_2()


func _on_attack3_pressed() -> void:
	if _bulwark == null:
		return
	_current_attack_title = "ATTACK 5: TWO TWO-HANDED SLASHES"
	_current_step_title = "Starting the two-handed slashes..."
	_build_pills(["1. Two-handed slash 1 [Melee_2H_Attack]", "2. Two-handed slash 2 [Melee_2H_Attack]"])
	_highlight_step(0)
	_reset_sequence_clock()
	_bulwark.play_attack_3()


func _on_single_1h_pressed() -> void:
	if _bulwark == null:
		return
	_current_attack_title = "NORMAL ATTACK: ONE-HANDED SLASH (WITH HITBOX)"
	_current_step_title = "One-handed swing [Melee_1H_Slash] (1.57s)"
	_build_pills(["One-handed slash [Melee_1H_Slash 1.57s]"])
	_highlight_step(0)
	_reset_sequence_clock()
	_bulwark.play_normal_attack()


func _on_single_2h_pressed() -> void:
	if _bulwark == null:
		return
	_current_attack_title = "SINGLE: TWO-HANDED SLASH"
	_current_step_title = "Two-handed chop [Melee_2H_Attack] (1.33s)"
	_build_pills(["Two-handed slash [Melee_2H_Attack 1.33s]"])
	_highlight_step(0)
	_reset_sequence_clock()
	_bulwark.play_attack_2h()


func _on_single_dual_pressed() -> void:
	if _bulwark == null:
		return
	_current_attack_title = "SINGLE: DUAL-WIELD SLASH"
	_current_step_title = "Dual-wield cross slash [Melee_Dualwield_Slash] (1.03s)"
	_build_pills(["Dual-wield slash [Melee_Dualwield_Slash 1.03s]"])
	_highlight_step(0)
	_reset_sequence_clock()
	_bulwark.play_dualwield_slash()


func _on_single_offhand_pressed() -> void:
	if _bulwark == null:
		return
	_current_attack_title = "SINGLE: OFF-HAND / REVERSE SLASH"
	_current_step_title = "Turning off-hand reverse slash [Dualwield_SlashCombo] (1.60s)"
	_build_pills(["Off-hand slash [Dualwield_SlashCombo 1.60s]"])
	_highlight_step(0)
	_reset_sequence_clock()
	_bulwark.play_offhand_slash()


func _on_single_stab_pressed() -> void:
	if _bulwark == null:
		return
	_current_attack_title = "SINGLE: ONE-HANDED STAB"
	_current_step_title = "Straight one-handed stab [Melee_1H_Stab] (1.40s)"
	_build_pills(["One-handed stab [Melee_1H_Stab 1.40s]"])
	_highlight_step(0)
	_reset_sequence_clock()
	_bulwark.play_stab_1h()


func _on_idle_pressed() -> void:
	if _bulwark == null:
		return
	_bulwark.stop_attack_sequence()
	_current_attack_title = "ATTACK CANCELLED -> IDLE"
	_current_step_title = "Attack stopped"
	_build_idle_pills()


# --- Attack lifecycle events ---

func _reset_sequence_clock() -> void:
	_sequence_time = 0.0
	_preview = {}
	_hit_log.clear()
	_log("--- New sequence ---")


func _on_attack_step_started(attack_id: int, step_name: StringName, clip: StringName, duration: float) -> void:
	if _ai_mode and step_name in [&"SLASH_1H", &"TRIPLE_STOMP_1", &"STOMP_WINDUP"]:
		_sequence_time = 0.0
		_log("AI picks: %s" % _bulwark.last_chosen_move)
	_log("[t=%5.2fs] %s starts (%s, %.2fs long)" % [_sequence_time, step_name, clip.get_file(), duration])
	var hitbox := _bulwark.get_step_hitbox(attack_id, step_name)
	if not (attack_id == 1 and step_name == &"STOMP_SLAM"):  # keep the wind-up ring until the hit
		_preview = {} if hitbox.is_empty() else {"attack_id": attack_id, "step_name": step_name, "hitbox": hitbox}

	match attack_id:
		1:
			if step_name == &"STOMP_WINDUP":
				_current_step_title = "Step 1/2: Stomp wind-up (%s, %.2fs)" % [clip, duration]
				_highlight_step(0)
			elif step_name == &"STOMP_SLAM":
				_current_step_title = "Step 2/2: Stomp slam impact (%s, %.2fs)" % [clip, duration]
				_highlight_step(1)
		2:
			match step_name:
				&"BLOCK_POSE":
					_current_step_title = "Step 1/4: Guard [Melee_Block] (%.2fs)" % duration
					_highlight_step(0)
				&"SLASH":
					_current_step_title = "Step 2/4: One-handed slash [Melee_1H_Slash] (%.2fs)" % duration
					_highlight_step(1)
				&"STAB":
					_current_step_title = "Step 3/4: One-handed stab [Melee_1H_Stab] (%.2fs)" % duration
					_highlight_step(2)
				&"2H_ATTACK":
					_current_step_title = "Step 4/4: Two-handed chop [Melee_2H_Attack] (%.2fs)" % duration
					_highlight_step(3)
		3:
			match step_name:
				&"2H_SLASH_1":
					_current_step_title = "Step 1/2: First two-handed slash [Melee_2H_Attack] (%.2fs)" % duration
					_highlight_step(0)
				&"2H_SLASH_2":
					_current_step_title = "Step 2/2: Follow-up two-handed slash [Melee_2H_Attack] (%.2fs)" % duration
					_highlight_step(1)
		4:
			match step_name:
				&"DUAL_SLASH":
					_current_step_title = "Step 1/2: Dual-wield cross slash [Melee_Dualwield_Slash] (%.2fs)" % duration
					_highlight_step(0)
				&"DUAL_COMBO":
					_current_step_title = "Step 2/2: Dual-wield flurry [Dualwield_SlashCombo] (%.2fs)" % duration
					_highlight_step(1)
		5:
			match step_name:
				&"SLASH_1H":
					_current_step_title = "Step 1/2: Forehand slash [Melee_1H_Slash] (%.2fs)" % duration
					_highlight_step(0)
				&"REVERSE_COMBO":
					_current_step_title = "Step 2/2: Spinning reverse slash [Dualwield_SlashCombo] (%.2fs)" % duration
					_highlight_step(1)
		6:
			match step_name:
				&"SLASH_1H":
					_current_step_title = "Step 1/3: Opening one-handed slash [Melee_1H_Slash] (%.2fs)" % duration
					_highlight_step(0)
				&"STAB_1H":
					_current_step_title = "Step 2/3: Straight one-handed stab [Melee_1H_Stab] (%.2fs)" % duration
					_highlight_step(1)
				&"2H_GROUND_SLAM":
					_current_step_title = "Step 3/3: Two-handed ground slam AoE [Melee_2H_Slam] (%.2fs)" % duration
					_highlight_step(2)
		7:
			var index := String(step_name).trim_prefix("TRIPLE_STOMP_").to_int() - 1
			_current_step_title = "Stomp %d/%d: Slam [R=%.1fm, clip cut to %.2fs]" % [
				index + 1, _bulwark.get_triple_stomp_count(), _bulwark.get_triple_stomp_radius(index), duration]
			_highlight_step(index)
		_:
			_current_step_title = "Attack: %s [%s] (%.2fs)" % [step_name, clip, duration]
			_highlight_step(0)


func _on_attack_sequence_finished(attack_id: int) -> void:
	_preview = {}
	_log("[t=%5.2fs] Attack %d finished" % [_sequence_time, attack_id])
	_current_attack_title = "ATTACK %d DONE" % attack_id
	_current_step_title = "Sequence finished -> back to Idle"
	_highlight_step(-1)


# --- Dynamic Step Pills ---

func _build_idle_pills() -> void:
	_build_pills(["Ready / Idle"])
	_highlight_step(-1)


func _build_pills(labels: Array[String]) -> void:
	for child in _step_container.get_children():
		child.queue_free()

	for text in labels:
		var pill := PanelContainer.new()
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 13)
		pill.add_child(label)
		_step_container.add_child(pill)


func _highlight_step(active_idx: int) -> void:
	var children := _step_container.get_children()
	for i in range(children.size()):
		var pill := children[i] as PanelContainer
		if pill == null or pill.is_queued_for_deletion():
			continue
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		if i == active_idx:
			style.bg_color = Color(0.9, 0.6, 0.1, 0.9) # Amber active
			style.border_color = Color(1.0, 1.0, 1.0, 1.0)
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.15, 0.15, 0.2, 0.6) # Muted
			style.border_color = Color(0.3, 0.3, 0.4, 0.5)
			style.set_border_width_all(1)
		pill.add_theme_stylebox_override("panel", style)


# --- Camera Controls ---

func _cycle_camera_view() -> void:
	var next_view_idx := (_current_view + 1) % 4
	_set_camera_view(next_view_idx as CameraView)


func _set_camera_view(view: CameraView) -> void:
	_current_view = view
	match view:
		CameraView.FRONT:
			_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			_camera.fov = 42.0
			_camera.position = Vector3(0.2, 2.2, 5.2)
			_camera.look_at(Vector3(0.0, 1.7, 0.0))
		CameraView.BACK:
			_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			_camera.fov = 42.0
			_camera.position = Vector3(0.2, 2.5, -4.8)
			_camera.look_at(Vector3(0.0, 1.7, 0.0))
		CameraView.SIDE:
			_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			_camera.fov = 42.0
			_camera.position = Vector3(5.2, 2.0, 1.0)
			_camera.look_at(Vector3(0.0, 1.7, 0.0))
		CameraView.ISOMETRIC:
			_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			_camera.size = 9.0
			_camera.position = Vector3(8.0, 10.0, 8.0)
			_camera.look_at(Vector3(0.0, 1.5, 0.0))


## Stand-in for the commander: same group, same body capsule and the flags the boss reads,
## so Bulwark hitboxes treat it exactly like the real one. It never moves on its own and never
## dies, so a spot can be tested over and over.
class ShowcaseCommander extends StaticBody3D:
	signal hit_taken(amount: int, damage_type: Enums.DamageType, knockback: float)

	var is_dodging: bool = false
	var is_deploying: bool = false
	var is_commander_mode: bool = false
	var total_damage: int = 0
	var _model: Node3D = null

	func _init() -> void:
		add_to_group(&"commander")
		collision_layer = 0
		collision_mask = 0
		var shape := CapsuleShape3D.new()
		shape.radius = COMMANDER_RADIUS
		shape.height = 1.8
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = shape
		col.position = Vector3(0.0, 0.9, 0.0)
		add_child(col)

	func add_model(scene: PackedScene) -> void:
		_model = scene.instantiate() as Node3D
		add_child(_model)

	func take_damage(info: DamageInfo) -> void:
		total_damage += info.amount
		hit_taken.emit(info.amount, info.damage_type, info.knockback_force)
		if _model != null:
			_model.scale = Vector3.ONE * 1.25
			create_tween().tween_property(_model, "scale", Vector3.ONE, 0.25)

	func apply_stun(_duration: float) -> void:
		pass
