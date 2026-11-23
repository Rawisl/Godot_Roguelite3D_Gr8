extends Node3D

## AI test arena for the Skeletal Centipede (press F6; nothing is asserted here).
## - Spawn the boss at any wave: HP, damage and speed come from the real ScaleConfig, and the wave
##   decides the appearance and so which moves are unlocked.
## - Set the boss HP to any % (armor + core together), or enrage it.
## - A stand-in commander you walk with WASD / arrows (Shift = run, Space = dodge roll, left click
##   on the floor = teleport). It never dies.
## - Without structures the boss always fights the commander. With "Towers + Fortress" on it also
##   picks between the commander and the structures along the lane (-X).
## - Cyan: the front cone the AI reads. Yellow: slash sector, spit cone, pool circle and roll circle
##   of the boss, plus the three dash steps (green = worth taking, red = blocked or toward the spawn).
##   Every move is logged, the scores behind the last pick are shown.
## - Scale sets the boss's model scale (3.0 to 4.5) at the next spawn.

const BOSS_SCENE: PackedScene = preload("res://entities/enemy/skeletal_centipede.tscn")
const COMMANDER_MODEL: PackedScene = preload("res://contents/assets/characters/fox_commander/fox_commander_model.tscn")
const SCALE_CONFIG: ScaleConfig = preload("res://data/config/scale_config.tres")
const GRASS_MATERIAL: Material = preload("res://art/materials/env_grass.tres")

const ARENA_HALF: float = 30.0
const BOSS_SPAWN := Vector3(0.0, 0.0, -10.0)
const COMMANDER_START := Vector3(0.0, 0.0, 0.0)
const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.5
const DODGE_DISTANCE: float = 3.5
const DODGE_TIME: float = 0.35
const LOG_LINES: int = 14
const DRAW_Y: float = 0.05
const COLOR_HITBOX := Color(1.0, 0.85, 0.2)
const COLOR_BODY := Color(0.3, 1.0, 0.7)
const COLOR_FRONT := Color(0.3, 0.85, 1.0, 0.8)
const COLOR_DASH_WORTH := Color(0.4, 1.0, 0.4)
const COLOR_DASH_POOR := Color(1.0, 0.35, 0.3)
const DASH_ARROW_HEAD: float = 0.8
const COLOR_TOWER := Color(0.45, 0.55, 0.8)
const COLOR_FORTRESS := Color(0.75, 0.65, 0.45)
const TOWER_SPOTS: Array[Vector3] = [Vector3(-6.0, 0.0, -14.0), Vector3(-12.0, 0.0, -6.0), Vector3(-18.0, 0.0, -14.0)]
const TOWER_HP: int = 300
const FORTRESS_POS := Vector3(-27.0, 0.0, -10.0)
const FORTRESS_SIZE := Vector3(2.0, 5.0, 12.0)
const FORTRESS_HP: int = 1500
const MELEE_POINT_POS := Vector3(-24.2, 0.0, -10.0)

var _boss: SkeletalCentipede = null
var _commander: TestCommander = null
var _camera: Camera3D = null
var _camera_zoom: float = 1.0
var _drawer: ImmediateMesh = null
var _show_hitboxes: bool = true
var _log_lines: PackedStringArray = []
var _fight_time: float = 0.0
var _structures: Array[Node3D] = []
var _melee_point: Marker3D = null
var _picks: Dictionary = {}

var _wave_spin: SpinBox = null
var _hp_slider: HSlider = null
var _seed_spin: SpinBox = null
var _scale_spin: SpinBox = null
var _structures_check: CheckBox = null
var _info_label: Label = null
var _log_label: Label = null


func _ready() -> void:
	_build_world()
	_commander = TestCommander.new()
	_commander.name = "TestCommander"
	add_child(_commander)
	_commander.global_position = COMMANDER_START
	_commander.add_model(COMMANDER_MODEL)
	_commander.hit_taken.connect(_on_commander_hit)
	_build_ui()
	_spawn_boss()


func _build_world() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var light := DirectionalLight3D.new()
	light.shadow_enabled = true
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(light)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA_HALF * 2.0 + 20.0, 2.0, ARENA_HALF * 2.0 + 20.0)
	var col := CollisionShape3D.new()
	col.shape = box
	col.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(col)
	var region := NavigationRegion3D.new()
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_radius = 1.75  # a multiple of cell_size (0.25), at least the boss's radius
	region.navigation_mesh = nav_mesh
	region.add_child(floor_body)
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA_HALF * 2.0, ARENA_HALF * 2.0)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	floor_mesh.material_override = GRASS_MATERIAL
	region.add_child(floor_mesh)
	add_child(region)
	region.bake_navigation_mesh(false)

	_drawer = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	var drawer := MeshInstance3D.new()
	drawer.mesh = _drawer
	drawer.material_override = mat
	drawer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drawer)

	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()


# --- Boss ---

func _spawn_boss() -> void:
	if _boss != null and is_instance_valid(_boss):
		_boss.stop_attack_sequence()
		_boss.queue_free()
	_build_structures()
	var wave := int(_wave_spin.value)
	_boss = BOSS_SCENE.instantiate() as SkeletalCentipede
	_boss.name = "SkeletalCentipede"
	_boss.position = BOSS_SPAWN
	# The scene's data is shared, so the boss gets its own copy at the chosen scale.
	var boss_data := _boss.data.duplicate() as CentipedeBossData
	boss_data.model_scale = _scale_spin.value
	_boss.data = boss_data
	# Same scaling call as WaveManager._spawn_boss.
	_boss.apply_wave_scale(SCALE_CONFIG.get_hp_mult(wave), SCALE_CONFIG.get_dmg_mult(wave),
			SCALE_CONFIG.get_speed_mult(wave), wave, SCALE_CONFIG)
	add_child(_boss)
	_boss.set_ai_seed(int(_seed_spin.value))
	_boss.move_started.connect(_on_move_started)
	_boss.move_hit.connect(_on_move_hit)
	_boss.spawn_grace = false
	_boss.is_in_spawn_zone = false
	_apply_hp_percent(_hp_slider.value)
	_picks.clear()
	_fight_time = 0.0
	_log_lines.clear()
	_log("Spawned at wave %d (appearance %d) | HP %d%% | scale %.2f" % [
		wave, _boss.get_appearance(), int(_hp_slider.value), _boss.cdata.model_scale])
	if _structures_check.button_pressed:
		_boss.change_state(Enums.EnemyState.ADVANCE)
		_boss._find_best_target()
	else:
		_boss.set_target(_commander)
		_boss.change_state(Enums.EnemyState.CHASE)


func _apply_hp_percent(pct: float) -> void:
	if _boss == null or not is_instance_valid(_boss) or _boss.is_dead:
		return
	var total := _boss.max_armor_hp + _boss.max_core_hp
	var target := clampi(int(round(total * pct / 100.0)), 1, total)
	if target > _boss.max_core_hp:
		_boss.current_core_hp = _boss.max_core_hp
		_boss.current_armor_hp = target - _boss.max_core_hp
	else:
		_boss.current_armor_hp = 0
		_boss.current_core_hp = target
		if _boss.current_phase == Enums.BossPhase.ARMORED:
			_boss.phase_broken = true
			_boss._on_transition_finished()
	_boss.health.hp = _boss.current_armor_hp + _boss.current_core_hp
	EventBus.boss_hp_changed.emit(_boss.current_armor_hp, _boss.current_core_hp, _boss._get_phase_name())


func _hit_boss(pct_of_total: float) -> void:
	if _boss == null or not is_instance_valid(_boss) or _boss.is_dead:
		return
	var total := _boss.max_armor_hp + _boss.max_core_hp
	var amount := maxi(1, int(round(total * pct_of_total / 100.0)))
	var dealt := _boss.take_damage(DamageInfo.new(amount, Enums.DamageType.SLASH, _commander))
	_log("Commander hits boss for %d SLASH -> %d dealt (%s)" % [amount, dealt, _boss._get_phase_name()])


func _build_structures() -> void:
	for node in _structures:
		if is_instance_valid(node):
			node.queue_free()
	_structures.clear()
	if _melee_point != null and is_instance_valid(_melee_point):
		_melee_point.queue_free()
	_melee_point = null
	if not _structures_check.button_pressed:
		return
	for i in TOWER_SPOTS.size():
		var tower := TestStructure.new()
		tower.setup(&"tower", "Tower %d" % (i + 1), TOWER_HP, Vector3(2.0, 3.0, 2.0), COLOR_TOWER, true)
		add_child(tower)
		tower.global_position = TOWER_SPOTS[i]
		_structures.append(tower)
	var fortress := TestStructure.new()
	fortress.setup(&"fortress", "Fortress", FORTRESS_HP, FORTRESS_SIZE, COLOR_FORTRESS, false)
	add_child(fortress)
	fortress.global_position = FORTRESS_POS
	_structures.append(fortress)
	_melee_point = Marker3D.new()
	_melee_point.name = "BossMeleePoint"
	_melee_point.add_to_group(&"boss_melee_point")
	add_child(_melee_point)
	_melee_point.global_position = MELEE_POINT_POS


func _boss_alive() -> bool:
	return _boss != null and is_instance_valid(_boss) and not _boss.is_dead


# --- Per frame ---

func _process(delta: float) -> void:
	_move_commander(delta)
	_update_camera(delta)
	if _boss_alive():
		_fight_time += delta
		if not _structures_check.button_pressed:
			# Nothing else to attack: keep the boss locked on the commander wherever it walks.
			_boss.taunted_by_player = true
			_boss.taunt_timer = 999.0
			if _boss.current_target != _commander and _boss.current_phase != Enums.BossPhase.TRANSITION \
					and not _boss.is_in_attack_state():
				_boss.set_target(_commander)
	_update_info()
	_draw_debug()


func _move_commander(delta: float) -> void:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	var dir := Vector3.ZERO
	if input != Vector2.ZERO:
		input = input.normalized()
		dir = _camera_forward() * input.y + _camera_right() * input.x
	var speed := RUN_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else WALK_SPEED
	_commander.tick(delta / maxf(0.01, Engine.time_scale), dir, speed)
	var p := _commander.global_position
	_commander.global_position = Vector3(clampf(p.x, -ARENA_HALF, ARENA_HALF), 0.0, clampf(p.z, -ARENA_HALF, ARENA_HALF))


func _update_camera(delta: float) -> void:
	var focus := _commander.global_position
	if _boss_alive():
		focus = focus.lerp(_boss.global_position, 0.4)
	var offset := Vector3(0.0, 16.0, 14.0) * _camera_zoom
	var desired := focus + offset
	_camera.global_position = _camera.global_position.lerp(desired, minf(1.0, delta * 6.0)) if _camera.global_position != Vector3.ZERO else desired
	_camera.look_at(_camera.global_position - offset + Vector3(0.0, 1.0, 0.0))


func _camera_forward() -> Vector3:
	var fwd := -_camera.global_transform.basis.z
	fwd.y = 0.0
	return fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD


func _camera_right() -> Vector3:
	var right := _camera.global_transform.basis.x
	right.y = 0.0
	return right.normalized() if right.length_squared() > 0.001 else Vector3.RIGHT


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		match click.button_index:
			MOUSE_BUTTON_LEFT:
				var origin := _camera.project_ray_origin(click.position)
				var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, _camera.project_ray_normal(click.position))
				if hit != null:
					_commander.global_position = hit as Vector3
			MOUSE_BUTTON_WHEEL_UP:
				_camera_zoom = clampf(_camera_zoom - 0.08, 0.4, 2.5)
			MOUSE_BUTTON_WHEEL_DOWN:
				_camera_zoom = clampf(_camera_zoom + 0.08, 0.4, 2.5)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_SPACE:
			_commander.start_dodge(DODGE_DISTANCE, DODGE_TIME)
		KEY_T:
			_commander.always_dodging = not _commander.always_dodging
		KEY_G:
			_commander.global_position = COMMANDER_START
		KEY_H:
			_show_hitboxes = not _show_hitboxes
		KEY_ENTER, KEY_KP_ENTER:
			_spawn_boss()
		KEY_J:
			_hit_boss(5.0)
		KEY_K:
			_hit_boss(10.0)


# --- Logging ---

func _log(text: String) -> void:
	_log_lines.append("[%6.1fs] %s" % [_fight_time, text])
	while _log_lines.size() > LOG_LINES:
		_log_lines.remove_at(0)
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)
	print(text)


func _on_move_started(move: StringName, clip: StringName, duration: float) -> void:
	_picks[move] = int(_picks.get(move, 0)) + 1
	if move == SkeletalCentipede.MOVE_DASH:
		_log("dash %s (%s, %.2fs)" % [_dash_name(), clip.get_file(), duration])
		return
	_log("%s (%s, %.2fs)" % [move, clip.get_file(), duration])


## Which way the dash that just started goes (left, right or front), from the AI's pick.
func _dash_name() -> String:
	return String(_boss.last_decision).trim_prefix("dash_")


func _on_move_hit(move: StringName, window: int, targets: Array) -> void:
	if targets.has(_commander):
		_log("   %s hit %d lands on the commander" % [move, window])


func _on_commander_hit(amount: int, damage_type: Enums.DamageType, knockback: float) -> void:
	_log("   -> commander takes %d %s%s" % [amount, Enums.DamageType.keys()[damage_type],
		(" | knockback %.1f m" % knockback) if knockback > 0.0 else ""])


func _update_info() -> void:
	if not _boss_alive():
		_info_label.text = "BOSS  none / dead. Press Spawn (Enter)."
		return
	var b := _boss
	var to_cmd := _commander.global_position - b.global_position
	to_cmd.y = 0.0
	var score_parts: PackedStringArray = []
	for action: StringName in CentipedeBrain.ACTIONS:
		score_parts.append("%s %.2f" % [action, float(b.last_scores.get(action, 0.0))])
	var pick_parts: PackedStringArray = []
	for move: StringName in _picks:
		pick_parts.append("%s %d" % [move, _picks[move]])
	_info_label.text = "BOSS  wave %d | appearance %d | %s%s | state %s | HP %d%% (armor %d, core %d)\nScores: %s -> %s | out of reach %.1fs | commander %.1f m, %s\nCooldowns: combo %.1f spit %.1f roll+charge roll %.1f dash %.1f front dash %.1f | dash buff %.1f | recent turns %d | picks: %s\nCOMMANDER damage taken %d | target %s" % [
		b.spawn_wave, b.get_appearance(), b._get_phase_name(), " ENRAGED" if b.is_enraged else "",
		Enums.EnemyState.keys()[b.current_state], int(round(b.get_hp_fraction() * 100.0)),
		b.current_armor_hp, b.current_core_hp, " ".join(score_parts),
		b.last_decision if b.last_decision != &"" else &"-", b.t_away, to_cmd.length(),
		"IN FRONT" if b.is_in_front(_commander) else "FLANK/BEHIND", b.combo_cooldown_left,
		b.spit_cooldown_left, b.roll_cooldown_left, b.dash_cooldown_left,
		b.dash_front_cooldown_left,
		b.dash_buff_left, b.recent_turn_count(), ", ".join(pick_parts) if not pick_parts.is_empty() else "-",
		_commander.total_damage, b.current_target.name if b.current_target != null and is_instance_valid(b.current_target) else "-"]


# --- Debug drawing ---

func _draw_debug() -> void:
	_drawer.clear_surfaces()
	if not _show_hitboxes:
		return
	_drawer.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_circle(_commander.global_position, 0.4, COLOR_BODY)
	if _boss_alive():
		var d := _boss.cdata
		var origin := _boss.global_position
		var fwd := _boss._combo_forward()
		_add_sector(origin, fwd, 6.0, d.ai_front_arc_deg, COLOR_FRONT)
		_add_sector(origin, fwd, d.body(d.slash_range), d.slash_arc_deg, COLOR_HITBOX)
		var apex := _boss.get_spit_apex()
		_add_sector(apex, fwd, _boss._spit_stream_reach(apex), d.spit_stream_half_angle_deg * 2.0, COLOR_HITBOX)
		_add_circle(_boss.to_global(d.body_v3(d.roll_ring_center)), d.body(d.roll_hit_radius), COLOR_HITBOX)
		_add_circle(_boss._pool_center_world(), d.pool_radius, COLOR_HITBOX)
		for action: StringName in [CentipedeBrain.DASH_LEFT, CentipedeBrain.DASH_RIGHT, CentipedeBrain.DASH_FRONT]:
			_add_dash_arrow(action)
	for child in get_children():
		if child is PoisonPool and _boss_alive():
			_add_circle(child.global_position, _boss.cdata.pool_radius, COLOR_HITBOX)
	_drawer.surface_add_vertex(Vector3.ZERO)  # a surface needs at least one vertex pair
	_drawer.surface_add_vertex(Vector3.ZERO)
	_drawer.surface_end()


## The step a dash would take; its colour runs from red (no score) to green (full score).
func _add_dash_arrow(action: StringName) -> void:
	var direction := _boss._combo_forward() if action == CentipedeBrain.DASH_FRONT else _boss._dash_direction(action)
	var share := _boss._dash_front_share() if action == CentipedeBrain.DASH_FRONT else _boss._dash_side_share(action)
	var color := COLOR_DASH_POOR.lerp(COLOR_DASH_WORTH, share)
	var from := _boss.global_position
	var to := from + _boss.dash_travel(action)
	_add_line(from, to, color)
	var back := -direction * DASH_ARROW_HEAD
	_add_line(to, to + back.rotated(Vector3.UP, deg_to_rad(25.0)), color)
	_add_line(to, to + back.rotated(Vector3.UP, deg_to_rad(-25.0)), color)


func _add_sector(origin: Vector3, forward: Vector3, reach: float, arc_deg: float, color: Color) -> void:
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.BACK
	var half := deg_to_rad(arc_deg * 0.5)
	var segments := 24
	var prev := origin + forward.rotated(Vector3.UP, -half) * reach
	_add_line(origin, prev, color)
	for i in range(1, segments + 1):
		var p := origin + forward.rotated(Vector3.UP, lerpf(-half, half, float(i) / segments)) * reach
		_add_line(prev, p, color)
		prev = p
	_add_line(prev, origin, color)


func _add_circle(center: Vector3, radius: float, color: Color) -> void:
	var segments := 48
	var prev := center + Vector3(radius, 0.0, 0.0)
	for i in range(1, segments + 1):
		var a := TAU * float(i) / segments
		var p := center + Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		_add_line(prev, p, color)
		prev = p


func _add_line(a: Vector3, b: Vector3, color: Color) -> void:
	a.y = DRAW_Y
	b.y = DRAW_Y
	_drawer.surface_set_color(color)
	_drawer.surface_add_vertex(a)
	_drawer.surface_set_color(color)
	_drawer.surface_add_vertex(b)


# --- UI ---

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(8.0, 8.0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	var wave_row := HBoxContainer.new()
	box.add_child(wave_row)
	wave_row.add_child(_small_label("Wave"))
	_wave_spin = SpinBox.new()
	_wave_spin.min_value = 1
	_wave_spin.max_value = 40
	_wave_spin.value = 15
	wave_row.add_child(_wave_spin)
	wave_row.add_child(_small_label("Scale"))
	_scale_spin = SpinBox.new()
	_scale_spin.min_value = 3.0
	_scale_spin.max_value = 4.5
	_scale_spin.step = 0.25
	_scale_spin.value = 3.0
	wave_row.add_child(_scale_spin)
	wave_row.add_child(_small_label("Seed"))
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0
	_seed_spin.max_value = 99999
	_seed_spin.value = 1234
	wave_row.add_child(_seed_spin)
	var spawn := Button.new()
	spawn.text = "Spawn (Enter)"
	spawn.pressed.connect(_spawn_boss)
	wave_row.add_child(spawn)

	var hp_row := HBoxContainer.new()
	box.add_child(hp_row)
	hp_row.add_child(_small_label("HP %"))
	_hp_slider = HSlider.new()
	_hp_slider.min_value = 1
	_hp_slider.max_value = 100
	_hp_slider.value = 100
	_hp_slider.custom_minimum_size = Vector2(220.0, 0.0)
	_hp_slider.value_changed.connect(_apply_hp_percent)
	hp_row.add_child(_hp_slider)
	var enrage := Button.new()
	enrage.text = "Enrage"
	enrage.pressed.connect(func() -> void:
		if _boss_alive():
			_boss.enter_enrage())
	hp_row.add_child(enrage)

	_structures_check = CheckBox.new()
	_structures_check.text = "Towers + Fortress (respawn to apply)"
	box.add_child(_structures_check)

	box.add_child(_small_label("WASD move | Shift run | Space dodge | T god dodge | G reset | H hitboxes | J/K hit boss 5/10%"))
	_info_label = _small_label()
	box.add_child(_info_label)
	_log_label = _small_label()
	box.add_child(_log_label)


func _small_label(text: String = "") -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_constant_override("outline_size", 3)
	return label


## Stand-in tower or Fortress: same group, collider and health the boss reads. Takes damage and
## frees itself at 0 HP. It does not block movement (collision layer 0).
class TestStructure extends StaticBody3D:
	var display_name: String = ""
	var hp: int = 1
	var max_hp: int = 1
	var health: Node = null
	var _label: Label3D = null

	func setup(group: StringName, p_name: String, p_hp: int, size: Vector3, color: Color, round_shape: bool) -> void:
		add_to_group(group)
		display_name = p_name
		name = p_name.replace(" ", "")
		hp = p_hp
		max_hp = p_hp
		health = self
		collision_layer = 0
		collision_mask = 0
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var mesh := MeshInstance3D.new()
		if round_shape:
			var cyl := CylinderShape3D.new()
			cyl.radius = size.x * 0.5
			cyl.height = size.y
			col.shape = cyl
			var cyl_mesh := CylinderMesh.new()
			cyl_mesh.top_radius = size.x * 0.4
			cyl_mesh.bottom_radius = size.x * 0.5
			cyl_mesh.height = size.y
			mesh.mesh = cyl_mesh
		else:
			var box := BoxShape3D.new()
			box.size = size
			col.shape = box
			var box_mesh := BoxMesh.new()
			box_mesh.size = size
			mesh.mesh = box_mesh
		col.position = Vector3(0.0, size.y * 0.5, 0.0)
		mesh.position = col.position
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mesh.material_override = mat
		add_child(col)
		add_child(mesh)
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 48
		_label.outline_size = 8
		_label.position = Vector3(0.0, size.y + 0.8, 0.0)
		add_child(_label)
		_update_label()

	func take_damage(info: DamageInfo) -> void:
		if hp <= 0:
			return
		hp = maxi(0, hp - info.amount)
		_update_label()
		if hp == 0:
			queue_free()

	func _update_label() -> void:
		if _label != null:
			_label.text = "%s\n%d / %d" % [display_name, hp, max_hp]


## Stand-in for the commander: same group, body capsule and flags the boss reads. Walks, rolls and
## gets knocked back, never dies.
class TestCommander extends StaticBody3D:
	signal hit_taken(amount: int, damage_type: Enums.DamageType, knockback: float)

	var is_dodging: bool = false
	var always_dodging: bool = false
	var is_deploying: bool = false
	var is_commander_mode: bool = false
	var total_damage: int = 0
	var _model: Node3D = null
	var _anim: AnimationPlayer = null
	var _facing := Vector3.FORWARD
	var _dodge_left: float = 0.0
	var _dodge_velocity := Vector3.ZERO
	var _knockback := Vector3.ZERO

	func _init() -> void:
		add_to_group(&"commander")
		collision_layer = 0
		collision_mask = 0
		var shape := CapsuleShape3D.new()
		shape.radius = 0.4
		shape.height = 1.8
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = shape
		col.position = Vector3(0.0, 0.9, 0.0)
		add_child(col)

	func add_model(scene: PackedScene) -> void:
		_model = scene.instantiate() as Node3D
		add_child(_model)
		_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer

	func tick(delta: float, dir: Vector3, speed: float) -> void:
		is_dodging = always_dodging or _dodge_left > 0.0
		if _dodge_left > 0.0:
			_dodge_left -= delta
			global_position += _dodge_velocity * delta
		elif dir != Vector3.ZERO:
			global_position += dir * speed * delta
			_facing = dir
		if _knockback.length_squared() > 0.0001:
			global_position += _knockback * delta
			_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
		if _facing != Vector3.ZERO:
			rotation.y = lerp_angle(rotation.y, atan2(_facing.x, _facing.z), minf(1.0, delta * 15.0))
		_play_anim(dir != Vector3.ZERO, speed)

	func start_dodge(distance: float, duration: float) -> void:
		if _dodge_left > 0.0:
			return
		_dodge_left = duration
		_dodge_velocity = _facing.normalized() * (distance / duration)

	func _play_anim(moving: bool, speed: float) -> void:
		if _anim == null:
			return
		var wanted := _first_anim(["Running_A", "move/Running_A", "Walking_A", "move/Walking_A"] if moving and speed > 6.0
				else (["Walking_A", "move/Walking_A", "Running_A", "move/Running_A"] if moving
				else ["Idle", "Idle_A", "general/Idle_A"]))
		if wanted != &"" and _anim.current_animation != wanted:
			_anim.play(wanted, 0.15)

	func _first_anim(names: Array) -> StringName:
		for n: String in names:
			if _anim.has_animation(n):
				return StringName(n)
		return &""

	func take_damage(info: DamageInfo) -> void:
		total_damage += info.amount
		if info.knockback_force > 0.0:
			var dir := info.hit_direction
			dir.y = 0.0
			if dir.length_squared() > 0.001:
				# Starting speed that slides exactly knockback_force metres at 30 m/s^2 braking.
				_knockback = dir.normalized() * sqrt(60.0 * info.knockback_force)
		hit_taken.emit(info.amount, info.damage_type, info.knockback_force)
		if _model != null:
			_model.scale = Vector3.ONE * 1.25
			create_tween().tween_property(_model, "scale", Vector3.ONE, 0.25)

	func apply_stun(_duration: float) -> void:
		pass
