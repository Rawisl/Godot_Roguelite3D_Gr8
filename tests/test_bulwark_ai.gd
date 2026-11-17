extends Node3D

## AI test arena for the Bulwark.
## - Spawn the boss at any wave: HP/damage/speed are scaled with the real ScaleConfig, and the wave
##   decides the appearance (wave / boss_wave_interval) and so which moves are unlocked.
## - Set the boss HP to any % (armor + core together). At or below the core share the armor is
##   gone and the boss goes to phase 2 (EXPOSED), optionally through the real armor-break transition.
## - A stand-in commander you walk with WASD / arrows (Shift = run, Space = dodge roll, left click
##   on the floor = teleport). It never dies, so the AI can be watched for as long as needed.
## - Without structures the boss always fights the commander (taunt is refreshed every frame).
##   With "Towers + Fortress" on, three towers and a Fortress stand along the lane (-X) and the boss
##   picks freely: it minds the commander within 4 m or after being hit (J/K), and leaves it to push
##   on to the towers when the commander keeps out of reach. Structures take real stomp damage.
##   Every move the AI picks is logged and counted, every hit on the commander is logged.
## - The front cone the AI uses to choose between front / flank moves is drawn in cyan, the hitbox
##   of the step being wound up in yellow, a landed hit flashes red (white when it misses).

const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const COMMANDER_MODEL: PackedScene = preload("res://contents/assets/characters/fox_commander/fox_commander_model.tscn")
const SCALE_CONFIG: ScaleConfig = preload("res://data/config/scale_config.tres")
const GRASS_MATERIAL: Material = preload("res://art/materials/env_grass.tres")

const ARENA_HALF: float = 30.0
const BOSS_SPAWN := Vector3(0.0, 0.0, -8.0)
const COMMANDER_START := Vector3(0.0, 0.0, 0.0)
const COMMANDER_RADIUS: float = 0.4  # same capsule as entities/commander/commander.tscn
const WALK_SPEED: float = 5.0
const RUN_SPEED: float = 8.5
const DODGE_DISTANCE: float = 3.5
const DODGE_TIME: float = 0.35
const LOG_LINES: int = 12
const HITBOX_Y: float = 0.05
const HITBOX_FLASH_TIME: float = 0.6
const COLOR_PREVIEW := Color(1.0, 0.85, 0.2)
const COLOR_HIT := Color(1.0, 0.2, 0.2)
const COLOR_MISS := Color(0.9, 0.9, 0.9)
const COLOR_BODY := Color(0.3, 1.0, 0.7)
const COLOR_FRONT := Color(0.3, 0.85, 1.0, 0.8)
const QUICK_WAVES: Array[int] = [5, 10, 15, 20, 25, 30]
const QUICK_HP: Array[int] = [100, 75, 50, 45, 30, 10]
## First step of every move the AI can pick, to count picks.
const AI_FIRST_STEPS: Array[StringName] = [&"SLASH_1H", &"TRIPLE_STOMP_1", &"STOMP_WINDUP"]
## Towers along the lane ahead of the boss (the boss advances toward -X), then the Fortress.
const TOWER_SPOTS: Array[Vector3] = [Vector3(-6.0, 0.0, -10.0), Vector3(-12.0, 0.0, -5.0), Vector3(-18.0, 0.0, -10.0)]
const TOWER_HP: int = 300
const FORTRESS_POS := Vector3(-27.0, 0.0, -8.0)
const FORTRESS_SIZE := Vector3(2.0, 5.0, 12.0)
const FORTRESS_HP: int = 1500
## Where the boss stands to stomp the Fortress: 1.8 m outside its wall.
const MELEE_POINT_POS := Vector3(-24.2, 0.0, -8.0)
const COLOR_TOWER := Color(0.45, 0.55, 0.8)
const COLOR_FORTRESS := Color(0.75, 0.65, 0.45)

var _bulwark: Bulwark = null
var _commander: TestCommander = null
var _camera: Camera3D = null
var _camera_zoom: float = 1.0
var _shake_intensity: float = 0.0
var _hitbox_mesh: ImmediateMesh = null
var _show_hitboxes: bool = true
var _ai_paused: bool = false
var _preview: Dictionary = {}
var _flashes: Array[Dictionary] = []
var _log_lines: PackedStringArray = []
var _move_counts: Dictionary = {}
var _fight_time: float = 0.0
var _structures: Array[Node3D] = []
var _melee_point: Marker3D = null
var _last_target: Node3D = null

# UI
var _wave_spin: SpinBox = null
var _hp_slider: HSlider = null
var _hp_value_label: Label = null
var _seed_spin: SpinBox = null
var _hazard_check: CheckBox = null
var _enrage_check: CheckBox = null
var _transition_check: CheckBox = null
var _wave_info_label: Label = null
var _boss_label: Label = null
var _commander_label: Label = null
var _stats_label: Label = null
var _log_label: Label = null
var _pause_button: Button = null
var _structures_check: CheckBox = null


func _ready() -> void:
	_build_world()
	_build_hitbox_drawer()
	_spawn_commander()
	_build_ui()
	_update_wave_info()
	EventBus.screen_shake_requested.connect(_on_screen_shake_requested)
	_spawn_boss()


func _exit_tree() -> void:
	if EventBus.screen_shake_requested.is_connected(_on_screen_shake_requested):
		EventBus.screen_shake_requested.disconnect(_on_screen_shake_requested)
	Engine.time_scale = 1.0


# --- World ---

func _build_world() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.384, 0.455, 0.549)
	sky_mat.sky_horizon_color = Color(0.647, 0.655, 0.671)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var light := DirectionalLight3D.new()
	light.light_energy = 1.2
	light.shadow_enabled = true
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(light)

	# Floor collision (gravity) + a navmesh baked from that collider so the boss paths for real.
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA_HALF * 2.0 + 20.0, 2.0, ARENA_HALF * 2.0 + 20.0)
	var col := CollisionShape3D.new()
	col.shape = box
	col.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(col)

	var region := NavigationRegion3D.new()
	region.name = "NavRegion"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.agent_radius = 0.75  # a multiple of cell_size (0.25)
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

	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()


func _build_hitbox_drawer() -> void:
	_hitbox_mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "HitboxDrawer"
	mesh_instance.mesh = _hitbox_mesh
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _spawn_commander() -> void:
	_commander = TestCommander.new()
	_commander.name = "TestCommander"
	add_child(_commander)
	_commander.global_position = COMMANDER_START
	_commander.add_model(COMMANDER_MODEL)
	_commander.hit_taken.connect(_on_commander_hit_taken)


# --- Boss spawning ---

func _spawn_boss() -> void:
	_despawn_boss()
	_build_structures()
	var wave := int(_wave_spin.value)
	_bulwark = BULWARK_SCENE.instantiate() as Bulwark
	_bulwark.name = "Bulwark"
	_bulwark.position = BOSS_SPAWN
	# Same scaling call as WaveManager._spawn_boss.
	_bulwark.apply_wave_scale(SCALE_CONFIG.get_hp_mult(wave), SCALE_CONFIG.get_dmg_mult(wave),
			SCALE_CONFIG.get_speed_mult(wave), wave, SCALE_CONFIG)
	add_child(_bulwark)
	_bulwark.in_hazard_trial = _hazard_check.button_pressed
	_bulwark.set_ai_seed(int(_seed_spin.value))
	_bulwark.attack_step_started.connect(_on_attack_step_started)
	_bulwark.attack_sequence_finished.connect(_on_attack_sequence_finished)
	_bulwark.attack_hit.connect(_on_attack_hit)
	_bulwark.health.died.connect(_on_boss_died, CONNECT_DEFERRED)

	_apply_hp_percent(_hp_slider.value, false)
	if _enrage_check.button_pressed:
		_bulwark.enter_enrage()

	_move_counts.clear()
	_fight_time = 0.0
	_preview = {}
	_flashes.clear()
	_commander.total_damage = 0
	_log_lines.clear()
	_log("Spawned Bulwark: wave %d (appearance %d, moveset %d) | HP %d%% | seed %d%s%s" % [
		wave, _bulwark.get_appearance(), _bulwark.get_moveset_appearance(), int(_hp_slider.value),
		int(_seed_spin.value), " | Hazard" if _bulwark.in_hazard_trial else "",
		" | Enraged" if _bulwark.is_enraged else ""])
	_set_ai_paused(_ai_paused)


func _despawn_boss() -> void:
	if _bulwark != null and is_instance_valid(_bulwark):
		_bulwark.stop_attack_sequence()
		_bulwark.queue_free()
	_bulwark = null
	_preview = {}


func _start_fight() -> void:
	_bulwark.spawn_grace = false
	_bulwark.is_in_spawn_zone = false
	_last_target = null
	if _structures_on():
		# The boss picks its own target: the commander or the next structure.
		_bulwark.change_state(Enums.EnemyState.ADVANCE)
		_bulwark._find_best_target()
		return
	_bulwark.set_target(_commander)
	_bulwark.change_state(Enums.EnemyState.CHASE)


func _structures_on() -> bool:
	return _structures_check != null and _structures_check.button_pressed


## Three towers along the lane and a Fortress at its end, at full HP. Cleared when the option is off.
func _build_structures() -> void:
	for node in _structures:
		if is_instance_valid(node):
			node.queue_free()
	_structures.clear()
	if _melee_point != null and is_instance_valid(_melee_point):
		_melee_point.queue_free()
	_melee_point = null
	if not _structures_on():
		return
	for i in TOWER_SPOTS.size():
		var tower := TestStructure.new()
		tower.setup(&"tower", "Tower %d" % (i + 1), TOWER_HP, Vector3(2.0, 3.0, 2.0), COLOR_TOWER, true)
		add_child(tower)
		tower.global_position = TOWER_SPOTS[i]
		tower.destroyed.connect(_on_structure_destroyed)
		_structures.append(tower)
	var fortress := TestStructure.new()
	fortress.setup(&"fortress", "Fortress", FORTRESS_HP, FORTRESS_SIZE, COLOR_FORTRESS, false)
	add_child(fortress)
	fortress.global_position = FORTRESS_POS
	fortress.destroyed.connect(_on_structure_destroyed)
	_structures.append(fortress)
	_melee_point = Marker3D.new()
	_melee_point.name = "BossMeleePoint"
	_melee_point.add_to_group(&"boss_melee_point")
	add_child(_melee_point)
	_melee_point.global_position = MELEE_POINT_POS


func _on_structure_destroyed(structure: Node3D) -> void:
	_log("%s destroyed" % structure.get("display_name"))
	_structures.erase(structure)


func _target_name(t: Node3D) -> String:
	if t == null or not is_instance_valid(t):
		return "-"
	if t == _commander:
		return "commander"
	var n: Variant = t.get("display_name")
	return str(n) if n != null else str(t.name)


## Sets armor + core to pct % of their total. Above the core share only the armor is chipped and
## the boss stays in phase 1; at or below it the armor is gone and the boss is in phase 2.
func _apply_hp_percent(pct: float, announce: bool = true) -> void:
	if not _boss_alive():
		return
	var b := _bulwark
	var total := b.max_armor_hp + b.max_core_hp
	var target := clampi(int(round(total * pct / 100.0)), 1, total)
	b.stop_attack_sequence()
	if target > b.max_core_hp:
		b.current_core_hp = b.max_core_hp
		b.current_armor_hp = target - b.max_core_hp
		if b.current_phase != Enums.BossPhase.ARMORED:
			# Back to phase 1: undo what the transition changed.
			b.phase_broken = false
			b.current_phase = Enums.BossPhase.ARMORED
			b.speed_multiplier = b.wave_speed_mult * (GameConfig.enrage_speed_mult if b.is_enraged else 1.0)
			EventBus.boss_phase_changed.emit(&"ARMORED")
	else:
		b.current_armor_hp = 0
		b.current_core_hp = target
		if b.current_phase == Enums.BossPhase.ARMORED:
			if _transition_check.button_pressed and announce:
				b._start_armor_break_transition()
			else:
				b.phase_broken = true
				b._on_transition_finished()
	if b.health != null:
		b.health.hp = b.current_armor_hp + b.current_core_hp
		b.health.hp_changed.emit(b.health.hp, b.health.max_hp)
	EventBus.boss_hp_changed.emit(b.current_armor_hp, b.current_core_hp, b._get_phase_name())
	if announce:
		_log("Boss HP set to %d%% -> armor %d / core %d (%s)" % [
			int(pct), b.current_armor_hp, b.current_core_hp, b._get_phase_name()])


## Real damage through take_damage, credited to the commander: tests the armor break naturally.
func _hit_boss(pct_of_total: float) -> void:
	if not _boss_alive():
		return
	var total := _bulwark.max_armor_hp + _bulwark.max_core_hp
	var amount := maxi(1, int(round(total * pct_of_total / 100.0)))
	var dealt := _bulwark.take_damage(DamageInfo.new(amount, Enums.DamageType.SLASH, _commander))
	_log("Commander hits boss for %d SLASH -> %d dealt (%s)" % [amount, dealt, _bulwark._get_phase_name()])


func _boss_alive() -> bool:
	return _bulwark != null and is_instance_valid(_bulwark) and not _bulwark.is_dead


func _set_ai_paused(paused: bool) -> void:
	_ai_paused = paused
	if _pause_button != null:
		_pause_button.text = "Resume AI (P)" if paused else "Pause AI (P)"
	if not _boss_alive():
		return
	_bulwark.velocity = Vector3.ZERO
	if paused:
		_bulwark.stop_attack_sequence()
		_bulwark.change_state(Enums.EnemyState.ADVANCE)
		_bulwark.set_physics_process(false)
		if _bulwark.anim_player != null and _bulwark.anim_player.has_animation(&"general/Idle_A"):
			_bulwark.anim_player.speed_scale = 1.0
			_bulwark.anim_player.play(&"general/Idle_A", 0.2)
	else:
		_bulwark.set_physics_process(true)
		_start_fight()


func _on_boss_died() -> void:
	_log("Boss died after %.1fs of fight. Press Spawn (Enter) for another." % _fight_time)
	_preview = {}


# --- Per frame ---

func _process(delta: float) -> void:
	_move_commander_from_input(delta)
	_update_camera(delta)

	for flash in _flashes:
		flash["ttl"] = float(flash["ttl"]) - delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return float(f["ttl"]) > 0.0)

	if _boss_alive() and not _ai_paused:
		_fight_time += delta
		if not _structures_on():
			# Nothing else to attack: keep the boss locked on the commander wherever it walks.
			_bulwark.taunted_by_player = true
			_bulwark.taunt_timer = 999.0
			if _bulwark.current_target != _commander and _bulwark.current_phase != Enums.BossPhase.TRANSITION:
				_bulwark.set_target(_commander)
		var target := _bulwark.current_target
		if target != _last_target and target != null and is_instance_valid(target):
			if _last_target == _commander and target != _commander:
				_log("Boss LEAVES the commander (out of reach %.1fs) -> %s" % [_bulwark.t_away, _target_name(target)])
			else:
				_log("Boss targets %s" % _target_name(target))
			_last_target = target
	_update_labels()
	_draw_debug()


func _move_commander_from_input(delta: float) -> void:
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
	# Real-time delta: the commander keeps its pace when the speed buttons slow the game down.
	var real_delta := delta / maxf(0.01, Engine.time_scale)
	_commander.tick(real_delta, dir, speed)
	var p := _commander.global_position
	_commander.global_position = Vector3(clampf(p.x, -ARENA_HALF, ARENA_HALF), 0.0, clampf(p.z, -ARENA_HALF, ARENA_HALF))


func _update_camera(delta: float) -> void:
	var focus := _commander.global_position
	if _boss_alive():
		focus = focus.lerp(_bulwark.global_position, 0.35)
	var offset := Vector3(0.0, 13.0, 11.0) * _camera_zoom
	var desired := focus + offset
	_camera.global_position = _camera.global_position.lerp(desired, minf(1.0, delta * 6.0)) if _camera.global_position != Vector3.ZERO else desired
	_camera.look_at(_camera.global_position - offset + Vector3(0.0, 1.0, 0.0))
	if _shake_intensity > 0.001:
		_camera.h_offset = randf_range(-_shake_intensity, _shake_intensity) * 0.08
		_camera.v_offset = randf_range(-_shake_intensity, _shake_intensity) * 0.08
		_shake_intensity = lerpf(_shake_intensity, 0.0, delta * 7.0)
	else:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0


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
				_place_commander_at_screen(click.position)
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
			_log("God dodge: %s" % ("ON (every hit misses)" if _commander.always_dodging else "OFF"))
		KEY_G:
			_commander.global_position = COMMANDER_START
		KEY_H:
			_show_hitboxes = not _show_hitboxes
		KEY_P:
			_set_ai_paused(not _ai_paused)
		KEY_ENTER, KEY_KP_ENTER:
			_spawn_boss()
		KEY_J:
			_hit_boss(5.0)
		KEY_K:
			_hit_boss(10.0)


func _place_commander_at_screen(screen_pos: Vector2) -> void:
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if hit != null:
		_commander.global_position = hit as Vector3


func _on_screen_shake_requested(intensity: float, _source: StringName) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)


# --- Labels ---

func _update_wave_info() -> void:
	var wave := int(_wave_spin.value)
	var interval := maxi(1, GameConfig.boss_wave_interval)
	var appearance := maxi(1, wave / interval)
	var offset := 1
	if _boss_alive() and _bulwark.data is BossData:
		offset = (_bulwark.data as BossData).hazard_appearance_offset
	var moveset := maxi(1, appearance - (offset if _hazard_check.button_pressed else 0))
	_wave_info_label.text = "Wave %d%s -> appearance %d, moveset %d\nHP x%.2f | DMG x%.2f | SPD x%.2f" % [
		wave, "" if wave % interval == 0 else " (not a boss wave)", appearance, moveset,
		SCALE_CONFIG.get_hp_mult(wave), SCALE_CONFIG.get_dmg_mult(wave), SCALE_CONFIG.get_speed_mult(wave)]


func _update_labels() -> void:
	_hp_value_label.text = "%d%%" % int(_hp_slider.value)
	if _boss_alive():
		var b := _bulwark
		var bd := b.data as BossData
		var to_cmd := _commander.global_position - b.global_position
		to_cmd.y = 0.0
		var dist := to_cmd.length()
		var unlock_text := ""
		if bd != null:
			var ms := b.get_moveset_appearance()
			unlock_text = "triple stomp %s (from %d) | combo %s (from %d, below %d%% HP)" % [
				"ON" if ms >= bd.triple_stomp_unlock_appearance else "locked", bd.triple_stomp_unlock_appearance,
				"ON" if ms >= bd.combo_unlock_appearance else "locked", bd.combo_unlock_appearance,
				int(bd.combo_hp_threshold * 100.0)]
		var score_parts: PackedStringArray = []
		for action: StringName in BulwarkBrain.ACTIONS:
			score_parts.append("%s %.2f" % [action, float(b.last_scores.get(action, 0.0))])
		unlock_text += "\nScores: %s -> %s | out of reach %.1fs | push commit %.1fs | turn %.0f deg/s" % [
			" ".join(score_parts), b.last_decision if b.last_decision != &"" else &"-",
			b.t_away, b.push_commit_left, rad_to_deg(b.get_turn_rate_rad())]
		_boss_label.text = "BOSS  wave %d | appearance %d | moveset %d%s%s | %s%s\nHP %d%%  armor %d/%d  core %d/%d  | state %s | move speed x%.2f | attack interval %.2fs\nAI: last pick %s | triple cooldown %.1fs | range stomp cooldown %.1fs | commander %s, %.1f m | fight %.1fs\nUnlocks: %s" % [
			b.spawn_wave, b.get_appearance(), b.get_moveset_appearance(),
			" | Hazard" if b.in_hazard_trial else "", " | ENRAGED" if b.is_enraged else "",
			b._get_phase_name(), " | AI PAUSED" if _ai_paused else "",
			int(round(b.get_hp_fraction() * 100.0)), b.current_armor_hp, b.max_armor_hp,
			b.current_core_hp, b.max_core_hp, Enums.EnemyState.keys()[b.current_state],
			b.speed_multiplier, b._get_attack_interval(),
			b.last_chosen_move if b.last_chosen_move != &"" else &"-", b.triple_stomp_cooldown_left, b.commander_stomp_cooldown_left,
			"IN FRONT" if b.is_in_front(_commander) else "FLANK/BEHIND", dist, _fight_time,
			unlock_text]
	else:
		_boss_label.text = "BOSS  none / dead. Press Spawn (Enter)."
	_commander_label.text = "COMMANDER  x=%.1f z=%.1f | damage taken %d | hits %d | %s" % [
		_commander.global_position.x, _commander.global_position.z, _commander.total_damage,
		_commander.hit_count, "GOD DODGE" if _commander.always_dodging else ("dodging" if _commander.is_dodging else "-")]
	if _boss_alive():
		var parts: PackedStringArray = []
		for node in _structures:
			if is_instance_valid(node):
				parts.append("%s %d" % [node.get("display_name"), int(node.get("hp"))])
d		_commander_label.text += "\nBOSS TARGET %s%s" % [_target_name(_bulwark.current_target),
				("  |  " + ", ".join(parts)) if not parts.is_empty() else ""]
	var total := 0
	for k: StringName in _move_counts:
		total += int(_move_counts[k])
	var parts: PackedStringArray = []
	for k: StringName in _move_counts:
		var n := int(_move_counts[k])
		parts.append("%s %d (%d%%)" % [k, n, int(round(100.0 * n / maxf(1.0, total)))])
	_stats_label.text = "AI PICKS (%d): %s" % [total, ", ".join(parts) if not parts.is_empty() else "-"]


func _log(text: String) -> void:
	_log_lines.append("[%6.1fs] %s" % [_fight_time, text])
	while _log_lines.size() > LOG_LINES:
		_log_lines.remove_at(0)
	if _log_label != null:
		_log_label.text = "\n".join(_log_lines)
	print(text)


# --- Boss signals ---

func _on_attack_step_started(attack_id: int, step_name: StringName, clip: StringName, duration: float) -> void:
	if step_name in AI_FIRST_STEPS:
		var move := _bulwark.last_chosen_move
		_move_counts[move] = int(_move_counts.get(move, 0)) + 1
		_log("AI picks %s (%s, %.1f m)" % [move,
			"front" if _bulwark.is_in_front(_commander) else "flank/behind",
			_bulwark.global_position.distance_to(_commander.global_position)])
	_log("   %s (%s, %.2fs)" % [step_name, clip.get_file(), duration])
	var hitbox := _bulwark.get_step_hitbox(attack_id, step_name)
	if not (attack_id == 1 and step_name == &"STOMP_SLAM"):  # keep the wind-up ring until the hit
		_preview = {} if hitbox.is_empty() else {"hitbox": hitbox}


func _on_attack_sequence_finished(_attack_id: int) -> void:
	_preview = {}


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
		_log("   %s MISSED%s" % [step_name, " (dodging)" if _commander.is_dodging else ""])


func _on_commander_hit_taken(amount: int, damage_type: Enums.DamageType, knockback: float) -> void:
	_log("   -> commander takes %d %s%s" % [amount, Enums.DamageType.keys()[damage_type],
		(" | knockback %.1f m" % knockback) if knockback > 0.0 else ""])


# --- Debug drawing ---

func _draw_debug() -> void:
	_hitbox_mesh.clear_surfaces()
	if not _show_hitboxes:
		return
	_hitbox_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_circle(_commander.global_position, COMMANDER_RADIUS, COLOR_BODY)
	if _boss_alive():
		var bd := _bulwark.data as BossData
		var fwd := _bulwark.global_transform.basis.z
		if bd != null:
			_add_sector(_bulwark.global_position, fwd, 4.0, bd.ai_front_arc_deg, COLOR_FRONT)
		if not _preview.is_empty() and _bulwark.is_in_attack_state():
			_add_hitbox(_preview["hitbox"], _bulwark.global_position, fwd, COLOR_PREVIEW)
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
			_add_line(origin, center, color)
		&"sector":
			_add_sector(origin, forward, float(hitbox["reach"]), float(hitbox["arc_deg"]), color)
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
	a.y = HITBOX_Y
	b.y = HITBOX_Y
	_hitbox_mesh.surface_set_color(color)
	_hitbox_mesh.surface_add_vertex(a)
	_hitbox_mesh.surface_set_color(color)
	_hitbox_mesh.surface_add_vertex(b)


# --- UI ---

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Left: control panel.
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(340, 0)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	box.add_child(_title("BULWARK AI TEST", 20, Color(1.0, 0.85, 0.3)))

	# Wave
	box.add_child(_title("Spawn wave", 14, Color(0.7, 0.9, 1.0)))
	var wave_row := HBoxContainer.new()
	_wave_spin = SpinBox.new()
	_wave_spin.min_value = 1
	_wave_spin.max_value = 100
	_wave_spin.value = GameConfig.boss_wave_interval
	_wave_spin.custom_minimum_size = Vector2(110, 0)
	_wave_spin.value_changed.connect(func(_v: float) -> void: _update_wave_info())
	wave_row.add_child(_wave_spin)
	var spawn_btn := Button.new()
	spawn_btn.text = "Spawn / Respawn (Enter)"
	spawn_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_btn.pressed.connect(_spawn_boss)
	wave_row.add_child(spawn_btn)
	box.add_child(wave_row)
	var quick_wave_row := HBoxContainer.new()
	for w in QUICK_WAVES:
		var btn := Button.new()
		btn.text = "W%d" % w
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void:
			_wave_spin.value = w
			_spawn_boss())
		quick_wave_row.add_child(btn)
	box.add_child(quick_wave_row)
	_wave_info_label = _small_label(Color(0.85, 0.85, 0.85))
	box.add_child(_wave_info_label)

	# HP
	box.add_child(_title("Boss HP %", 14, Color(0.7, 0.9, 1.0)))
	var hp_row := HBoxContainer.new()
	_hp_slider = HSlider.new()
	_hp_slider.min_value = 1
	_hp_slider.max_value = 100
	_hp_slider.step = 1
	_hp_slider.value = 100
	_hp_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(_hp_slider)
	_hp_value_label = Label.new()
	_hp_value_label.custom_minimum_size = Vector2(44, 0)
	hp_row.add_child(_hp_value_label)
	var apply_hp := Button.new()
	apply_hp.text = "Apply"
	apply_hp.pressed.connect(func() -> void: _apply_hp_percent(_hp_slider.value))
	hp_row.add_child(apply_hp)
	box.add_child(hp_row)
	var quick_hp_row := HBoxContainer.new()
	for pct in QUICK_HP:
		var btn := Button.new()
		btn.text = "%d%%" % pct
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void:
			_hp_slider.value = pct
			_apply_hp_percent(pct))
		quick_hp_row.add_child(btn)
	box.add_child(quick_hp_row)
	_transition_check = CheckBox.new()
	_transition_check.text = "Play armor-break transition when dropping to phase 2"
	_transition_check.button_pressed = true
	_transition_check.add_theme_font_size_override("font_size", 12)
	box.add_child(_transition_check)
	var hit_row := HBoxContainer.new()
	for pct in [5.0, 10.0, 25.0]:
		var btn := Button.new()
		btn.text = "Hit boss %d%%" % int(pct)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: _hit_boss(pct))
		hit_row.add_child(btn)
	box.add_child(hit_row)

	# Modifiers
	box.add_child(_title("Modifiers (applied on spawn)", 14, Color(0.7, 0.9, 1.0)))
	_hazard_check = CheckBox.new()
	_hazard_check.text = "Hazard Trial (moveset one appearance back)"
	_hazard_check.toggled.connect(func(on: bool) -> void:
		_update_wave_info()
		if _boss_alive():
			_bulwark.in_hazard_trial = on)
	box.add_child(_hazard_check)
	_enrage_check = CheckBox.new()
	_enrage_check.text = "Enraged (needs respawn to turn off)"
	_enrage_check.toggled.connect(func(on: bool) -> void:
		if on and _boss_alive():
			_bulwark.enter_enrage())
	box.add_child(_enrage_check)
	_structures_check = CheckBox.new()
	_structures_check.text = "Towers + Fortress (boss may leave the commander)"
	_structures_check.button_pressed = true
	_structures_check.toggled.connect(func(_on: bool) -> void: _spawn_boss())
	box.add_child(_structures_check)
	var seed_row := HBoxContainer.new()
	var seed_label := Label.new()
	seed_label.text = "AI seed"
	seed_row.add_child(seed_label)
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0
	_seed_spin.max_value = 99999
	_seed_spin.value = 1
	_seed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_spin)
	var random_seed := Button.new()
	random_seed.text = "Random"
	random_seed.pressed.connect(func() -> void: _seed_spin.value = randi() % 100000)
	seed_row.add_child(random_seed)
	box.add_child(seed_row)

	# AI / time
	var ai_row := HBoxContainer.new()
	_pause_button = Button.new()
	_pause_button.text = "Pause AI (P)"
	_pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_button.pressed.connect(func() -> void: _set_ai_paused(not _ai_paused))
	ai_row.add_child(_pause_button)
	var kill := Button.new()
	kill.text = "Despawn"
	kill.pressed.connect(_despawn_boss)
	ai_row.add_child(kill)
	var reset_stats := Button.new()
	reset_stats.text = "Reset stats"
	reset_stats.pressed.connect(func() -> void:
		_move_counts.clear()
		_commander.total_damage = 0
		_commander.hit_count = 0)
	ai_row.add_child(reset_stats)
	box.add_child(ai_row)
	var speed_row := HBoxContainer.new()
	var speed_label := Label.new()
	speed_label.text = "Speed"
	speed_row.add_child(speed_label)
	for spd: float in [0.25, 0.5, 1.0, 2.0]:
		var btn := Button.new()
		btn.text = "x%s" % str(spd)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: Engine.time_scale = spd)
		speed_row.add_child(btn)
	box.add_child(speed_row)

	var help := _small_label(Color(0.75, 0.75, 0.75))
	help.text = "WASD/arrows: walk (Shift run) | Space: dodge roll\nClick floor: teleport | G: back to start | T: god dodge\nJ/K: hit boss 5%/10% (also makes it mind you) | P: pause AI\nH: hitboxes | Mouse wheel: zoom | Cyan cone = AI front arc\nRespawn (Enter) also rebuilds the towers at full HP"
	box.add_child(help)

	# Right/top: live info.
	var info_panel := PanelContainer.new()
	info_panel.anchor_left = 1.0
	info_panel.anchor_right = 1.0
	info_panel.offset_left = -760
	info_panel.offset_right = -12
	info_panel.offset_top = 12
	layer.add_child(info_panel)
	var info_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		info_margin.add_theme_constant_override("margin_" + side, 10)
	info_panel.add_child(info_margin)
	var info_box := VBoxContainer.new()
	info_margin.add_child(info_box)
	_boss_label = _mono_label(Color(1.0, 1.0, 1.0), 13)
	info_box.add_child(_boss_label)
	_commander_label = _mono_label(Color(0.55, 1.0, 0.75), 13)
	info_box.add_child(_commander_label)
	_stats_label = _mono_label(Color(1.0, 0.85, 0.3), 13)
	info_box.add_child(_stats_label)
	_log_label = _mono_label(Color(1.0, 0.8, 0.7), 12)
	info_box.add_child(_log_label)


func _title(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _small_label(color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	return label


func _mono_label(color: Color, size: int) -> Label:
	var label := Label.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "Monospace"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Stand-in tower or Fortress: same group, collider and health the boss reads. Takes stomp damage
## and frees itself at 0 HP. It does not block movement (collision layer 0).
class TestStructure extends StaticBody3D:
	signal destroyed(structure: Node3D)

	var display_name: String = ""
	var hp: int = 1
	var max_hp: int = 1
	## The boss checks target.health.hp; the structure carries its own hp.
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
			destroyed.emit(self)
			queue_free()

	func _update_label() -> void:
		if _label != null:
			_label.text = "%s\n%d / %d" % [display_name, hp, max_hp]


## Stand-in for the commander: same group, body capsule and flags the boss reads, so the boss AI
## and its hitboxes treat it like the real one. Walks, rolls and gets knocked back, never dies.
class TestCommander extends StaticBody3D:
	signal hit_taken(amount: int, damage_type: Enums.DamageType, knockback: float)

	var is_dodging: bool = false
	var always_dodging: bool = false
	var is_deploying: bool = false
	var is_commander_mode: bool = false
	var total_damage: int = 0
	var hit_count: int = 0
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
		hit_count += 1
		if info.knockback_force > 0.0:
			var dir := info.hit_direction
			dir.y = 0.0
			if dir.length_squared() > 0.001:
				# Starting speed that slides exactly knockback_force metres at 30 m/s² braking.
				_knockback = dir.normalized() * sqrt(60.0 * info.knockback_force)
		hit_taken.emit(info.amount, info.damage_type, info.knockback_force)
		if _model != null:
			_model.scale = Vector3.ONE * 1.25
			create_tween().tween_property(_model, "scale", Vector3.ONE, 0.25)

	func apply_stun(_duration: float) -> void:
		pass
