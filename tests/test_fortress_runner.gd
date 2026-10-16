extends Node3D

## Visual test runner for the Fortress (SRS v1.7 sections 3.6.1, 6.5, 7.1 "Fortress, tower").
## Each group runs as its own stage with a title card, a fade between stages and a live
## pass/fail log, so the checks can be watched instead of running in the background.
const FORTRESS_SCENE: PackedScene = preload("res://entities/fortress/fortress.tscn")
const LEVEL_SCENE: PackedScene = preload("res://levels/corridor/level.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")

const COLOR_PASS := Color(0.45, 0.9, 0.45)
const COLOR_FAIL := Color(1.0, 0.4, 0.4)
const COLOR_INFO := Color(0.85, 0.85, 0.9)
const COLOR_HEAL := Color(0.4, 1.0, 0.6)
const COLOR_DAMAGE := Color(1.0, 0.55, 0.35)
const COLOR_BLOCKED := Color(0.6, 0.75, 1.0)
const STAGE_COUNT := 9

## Seconds between visible steps. Ignored in headless mode.
@export var step_delay: float = 0.6
## Seconds a stage title card stays on screen. Ignored in headless mode.
@export var title_delay: float = 1.4

var passes: int = 0
var fails: int = 0

var _visual: bool = true
var _stage_root: Node3D
var _base_world: Node3D
var _camera: Camera3D
var _title: Label
var _subtitle: Label
var _log: RichTextLabel
var _hp_bar: ProgressBar
var _hp_label: Label
var _info_label: Label
var _alert_banner: Label
var _fade: ColorRect
var _card: Label
var _summary: Label


func _ready() -> void:
	_visual = DisplayServer.get_name() != "headless"
	_build_world()
	_build_ui()
	EventBus.fortress_hp_changed.connect(_on_hp_changed)
	_run.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _summary.visible and event.is_pressed() and not event.is_echo():
		get_tree().quit(0 if fails == 0 else 1)


func _run() -> void:
	print("\n=======================================================")
	print("              AUTOMATED FORTRESS RUNNER TEST           ")
	print("=======================================================")

	await test_max_hp_meta()
	await test_damage_formula()
	await test_damage_gating_and_destroy_once()
	await test_low_hp_alert_once_per_wave()
	await test_repair_quotes()
	await test_repair_with_gold()
	await test_emergency_repair()
	await test_melee_slot_capacity()
	await test_grunts_attack_fortress_in_level()

	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")

	if not _visual:
		get_tree().quit(0 if fails == 0 else 1)
		return
	await _show_summary()


#region Test helpers
func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
		_log_line("PASS  " + test_name, COLOR_PASS)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)
		_log_line("FAIL  " + test_name, COLOR_FAIL)
	await _wait(step_delay)


func _note(text: String) -> void:
	print("    " + text)
	_log_line("·  " + text, COLOR_INFO)


func _wait(seconds: float) -> void:
	if _visual and seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	else:
		await get_tree().process_frame


func _spawn_fortress(level: int = 0) -> Fortress:
	var fortress := FORTRESS_SCENE.instantiate() as Fortress
	fortress.fort_hp_level = level
	_stage_root.add_child(fortress)
	return fortress


func _set_state(state: StringName) -> void:
	EventBus.state_changed.emit(state)
	_info_label.text = "Wave state: %s" % state
#endregion


#region Stage presentation
func _build_world() -> void:
	_base_world = Node3D.new()
	_base_world.name = "BaseWorld"
	add_child(_base_world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 0.8
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_base_world.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_energy = 1.1
	_base_world.add_child(sun)

	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(60.0, 40.0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.25, 0.3, 0.22)
	ground_mesh.material = ground_mat
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	_base_world.add_child(ground)

	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_frame_fortress()

	_stage_root = Node3D.new()
	_stage_root.name = "Stage"
	add_child(_stage_root)


func _frame_fortress() -> void:
	_camera.position = Vector3(17.0, 11.0, 13.0)
	_camera.look_at_from_position(_camera.position, Vector3(1.0, 1.5, 0.0))
	_camera.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var top := VBoxContainer.new()
	top.position = Vector2(24.0, 16.0)
	layer.add_child(top)
	_title = _make_label(30, Color.WHITE)
	top.add_child(_title)
	_subtitle = _make_label(18, Color(0.8, 0.85, 0.95))
	top.add_child(_subtitle)
	_info_label = _make_label(18, Color(1.0, 0.9, 0.5))
	top.add_child(_info_label)

	var hp_box := VBoxContainer.new()
	hp_box.anchor_top = 1.0
	hp_box.anchor_bottom = 1.0
	hp_box.offset_left = 24.0
	hp_box.offset_top = -78.0
	hp_box.offset_right = 444.0
	layer.add_child(hp_box)
	_hp_label = _make_label(18, Color.WHITE)
	hp_box.add_child(_hp_label)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(420.0, 24.0)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.8, 0.4)
	_hp_bar.add_theme_stylebox_override(&"fill", fill)
	hp_box.add_child(_hp_bar)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -560.0
	panel.offset_top = 16.0
	panel.offset_right = -16.0
	panel.offset_bottom = -16.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override(&"panel", panel_style)
	layer.add_child(panel)
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.add_theme_font_size_override(&"normal_font_size", 15)
	panel.add_child(_log)

	_alert_banner = _make_label(26, Color.WHITE)
	_alert_banner.anchor_right = 1.0
	_alert_banner.offset_left = 24.0
	_alert_banner.offset_top = 150.0
	_alert_banner.offset_right = -600.0
	_alert_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.75, 0.15, 0.1, 0.85)
	banner_style.set_content_margin_all(10.0)
	_alert_banner.add_theme_stylebox_override(&"normal", banner_style)
	_alert_banner.visible = false
	layer.add_child(_alert_banner)

	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.05, 0.08, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)

	_card = _make_label(34, Color.WHITE)
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(_card)

	_summary = _make_label(44, Color.WHITE)
	_summary.set_anchors_preset(Control.PRESET_FULL_RECT)
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary.visible = false
	layer.add_child(_summary)


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 6)
	return label


func _log_line(text: String, color: Color) -> void:
	_log.push_color(color)
	_log.add_text(text)
	_log.pop()
	_log.newline()


func _begin_stage(index: int, title: String, description: String) -> void:
	print("\n[GROUP %d] %s" % [index, title])
	if _visual:
		await _fade_to(1.0, 0.35)
	for child in _stage_root.get_children():
		child.free()
	_alert_banner.visible = false
	_info_label.text = ""
	_hp_label.text = ""
	_hp_bar.value = 0.0
	_title.text = "%d/%d  %s" % [index, STAGE_COUNT, title]
	_subtitle.text = description
	_log_line("", COLOR_INFO)
	_log_line("[%d] %s" % [index, title], Color.WHITE)
	if _visual:
		_card.text = "Test %d / %d\n%s\n\n%s" % [index, STAGE_COUNT, title, description]
		_card.modulate.a = 1.0
		await _wait(title_delay)
		create_tween().tween_property(_card, ^"modulate:a", 0.0, 0.3)
		await _fade_to(0.0, 0.4)
	else:
		_card.modulate.a = 0.0
		_fade.color.a = 0.0


func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, ^"color:a", alpha, duration)
	await tween.finished


func _show_summary() -> void:
	await _fade_to(0.85, 0.5)
	var ok := fails == 0
	_summary.add_theme_color_override(&"font_color", COLOR_PASS if ok else COLOR_FAIL)
	_summary.text = "%s\n%d PASSED, %d FAILED\n\nPress any key to quit" % ["ALL TESTS PASSED" if ok else "SOME TESTS FAILED", passes, fails]
	_summary.visible = true


func _on_hp_changed(hp: int, max_hp: int, _delta: int) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "Fortress HP  %d / %d" % [hp, max_hp]
	var ratio := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	var fill := _hp_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	fill.bg_color = Color(0.85, 0.3, 0.25) if ratio <= 0.3 else Color(0.35, 0.8, 0.4)


## Floating text above a point, used for damage, heals and blocked hits.
func _pop_text(at: Vector3, text: String, color: Color) -> void:
	if not _visual:
		return
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color.BLACK
	label.outline_size = 12
	label.font_size = 96
	label.pixel_size = 0.01
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	_stage_root.add_child(label)
	label.global_position = at
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, ^"global_position", at + Vector3(0.0, 2.0, 0.0), 1.2)
	tween.tween_property(label, ^"modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.chain().tween_callback(label.queue_free)


func _hit(fortress: Fortress, damage: Variant) -> void:
	var before := fortress.get_hp()
	fortress.take_damage(damage)
	var lost := before - fortress.get_hp()
	var at := fortress.global_position + Vector3(3.0, 4.5, randf_range(-4.0, 4.0))
	if lost > 0:
		_pop_text(at, "-%d" % lost, COLOR_DAMAGE)
		_flash(fortress, Color(1.0, 0.4, 0.3))
	else:
		_pop_text(at, "blocked", COLOR_BLOCKED)


func _heal_pop(fortress: Fortress, amount: int, text: String) -> void:
	if amount > 0:
		_pop_text(fortress.global_position + Vector3(3.0, 4.5, 0.0), text, COLOR_HEAL)
		_flash(fortress, Color(0.4, 1.0, 0.5))


func _flash(fortress: Fortress, color: Color) -> void:
	if not _visual:
		return
	var blockout := fortress.get_node_or_null(^"Model/Blockout") as MeshInstance3D
	if blockout == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.6
	blockout.material_overlay = mat
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(blockout):
		blockout.material_overlay = null


func _make_dummy(color: Color) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	var dummy := MeshInstance3D.new()
	dummy.mesh = mesh
	_stage_root.add_child(dummy)
	return dummy


func _tint(dummy: MeshInstance3D, color: Color) -> void:
	((dummy.mesh as CapsuleMesh).material as StandardMaterial3D).albedo_color = color


func _move_dummy(dummy: MeshInstance3D, to: Vector3) -> void:
	if _visual:
		create_tween().tween_property(dummy, ^"global_position", to, 0.5)
	else:
		dummy.global_position = to


func _collapse(fortress: Fortress) -> void:
	if not _visual:
		return
	_alert_banner.text = "FORTRESS DESTROYED"
	_alert_banner.visible = true
	var model := fortress.get_node(^"Model") as Node3D
	var tween := create_tween().set_parallel()
	tween.tween_property(model, ^"scale:y", 0.25, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, ^"position:y", -1.5, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
#endregion


func test_max_hp_meta() -> void:
	await _begin_stage(1, "Max HP and FORT_HP meta", "FORT-04, 6.5: max HP = 1000 × (1 + 0.05 × level), starts full")
	var f0 := _spawn_fortress(0)
	_info_label.text = "FORT_HP level 0"
	await _wait(step_delay)
	await assert_true(f0.get_max_hp() == 1000 and f0.get_hp() == 1000, "Level 0: 1000/1000")
	f0.free()
	var f1 := _spawn_fortress(1)
	_info_label.text = "FORT_HP level 1"
	await _wait(step_delay)
	await assert_true(f1.get_max_hp() == 1050 and f1.is_full(), "Level 1: 1050, starts full")
	f1.free()
	var f5 := _spawn_fortress(5)
	_info_label.text = "FORT_HP level 5"
	await _wait(step_delay)
	await assert_true(Fortress.compute_max_hp(1000, 5) == 1250 and f5.get_max_hp() == 1250, "Level 5: 1250")


func test_damage_formula() -> void:
	await _begin_stage(2, "Damage formula", "3.6.1, APL-03: ceil(raw × (1 - armor)), min 1, armor capped at 60%, TRUE ignores armor")
	var f := _spawn_fortress()
	var cases := [
		[6, Enums.DamageType.SLASH, 0.0, 6, "armor 0: raw 6 -> 6"],
		[100, Enums.DamageType.SLASH, 0.6, 40, "armor 60%: 100 -> 40"],
		[100, Enums.DamageType.SLASH, 0.9, 40, "armor 90% clamped to 60%: 100 -> 40"],
		[1, Enums.DamageType.SLASH, 0.6, 1, "minimum 1 damage"],
		[7, Enums.DamageType.PIERCE, 0.25, 6, "rounds up once: ceil(5.25) = 6"],
		[350, Enums.DamageType.TRUE, 0.6, 350, "TRUE ignores armor (OVL-01)"],
		[-5, Enums.DamageType.SLASH, 0.0, 0, "negative damage does nothing (FORT-03)"],
	]
	for c in cases:
		var result := Fortress.compute_damage(c[0], c[1], c[2])
		_info_label.text = "raw %d %s, armor %d%%  ->  %d" % [c[0], Enums.DamageType.keys()[c[1]], roundi(c[2] * 100.0), result]
		_pop_text(f.global_position + Vector3(3.0, 4.5, randf_range(-4.0, 4.0)), "-%d" % result if result > 0 else "0", COLOR_DAMAGE)
		await assert_true(result == c[3], c[4])


func test_damage_gating_and_destroy_once() -> void:
	await _begin_stage(3, "Wave gating, clamp and destroy once", "FORT-05: damage only in COMBAT/BOSS_COMBAT. FORT-02/03: HP locks at 0, fortress_destroyed fires once")
	var f := _spawn_fortress()
	var destroyed := [0]
	var on_destroyed := func(): destroyed[0] += 1
	EventBus.fortress_destroyed.connect(on_destroyed)

	_set_state(&"PREP")
	await _wait(step_delay)
	_hit(f, 100)
	await assert_true(f.get_hp() == 1000, "No damage in PREP (FORT-05)")
	_set_state(&"SUMMARY")
	await _wait(step_delay)
	_hit(f, 100)
	await assert_true(f.get_hp() == 1000, "No damage in SUMMARY (FORT-05)")
	_set_state(&"BOSS_INTRO")
	await _wait(step_delay)
	_hit(f, 100)
	await assert_true(f.get_hp() == 1000, "No damage in BOSS_INTRO (only COMBAT / BOSS_COMBAT)")

	var last_delta := [0]
	var on_hp := func(_hp: int, _max_hp: int, delta: int): last_delta[0] = delta
	EventBus.fortress_hp_changed.connect(on_hp)
	_set_state(&"COMBAT")
	await _wait(step_delay)
	_hit(f, DamageInfo.new(100, Enums.DamageType.SLASH))
	await assert_true(f.get_hp() == 900, "COMBAT: 100 damage -> 900")
	await assert_true(last_delta[0] == -100, "fortress_hp_changed delta = -100 (EVB-07)")
	EventBus.fortress_hp_changed.disconnect(on_hp)
	_note("Three 600-damage hits in the same frame")
	await _wait(step_delay)
	_hit(f, 600)
	_hit(f, 600)
	_hit(f, 600)
	await assert_true(f.get_hp() == 0, "HP clamped at 0 (FORT-03)")
	await _collapse(f)
	await assert_true(destroyed[0] == 1, "fortress_destroyed emitted exactly once (FORT-02)")
	await assert_true(f.is_destroyed(), "is_destroyed() true")
	await assert_true(f.emergency_repair(0.2) == 0, "No repair after destroyed")

	EventBus.fortress_destroyed.disconnect(on_destroyed)


func test_low_hp_alert_once_per_wave() -> void:
	await _begin_stage(4, "Low HP alert once per wave", "ALR-01: at 30% HP one T1 alert per wave, again in the next wave")
	var f := _spawn_fortress()
	var alerts: Array = []
	var on_alert := func(tier: int, key: StringName, _p: Dictionary):
		alerts.append([tier, key])
		_alert_banner.text = "ALERT T%d  %s" % [tier, key]
		_alert_banner.visible = true
	EventBus.alert_requested.connect(on_alert)

	EventBus.wave_started.emit(1)
	_set_state(&"COMBAT")
	_info_label.text = "Wave 1, COMBAT"
	for i in 3:
		_hit(f, 230)
		await _wait(step_delay * 0.5)
	await assert_true(alerts.is_empty(), "31% HP: no alert yet")
	_hit(f, 10)
	await assert_true(alerts.size() == 1 and alerts[0][0] == 1 and alerts[0][1] == &"alert.fortress_low", "30% HP: one T1 alert")
	_hit(f, 50)
	await assert_true(alerts.size() == 1, "Further damage in the same wave: no second alert")

	_alert_banner.visible = false
	_set_state(&"PREP")
	var healed := f.repair_with_gold(0.0, 10000)
	_heal_pop(f, healed.heal, "+%d" % healed.heal)
	_note("PREP: full repair before wave 2")
	await _wait(step_delay)
	EventBus.wave_started.emit(2)
	_set_state(&"COMBAT")
	_info_label.text = "Wave 2, COMBAT"
	_hit(f, 750)
	await assert_true(alerts.size() == 2, "Next wave: alert fires again")

	EventBus.alert_requested.disconnect(on_alert)


func test_repair_quotes() -> void:
	await _begin_stage(5, "Repair prices", "REP-01, REP-06, GLD-07: 4 gold per 1% missing, partial repair when gold is short")
	_spawn_fortress()
	var cases := [
		[0.0, 800, 1000, 9999, 80, 200, "Missing 20% of 1000: full repair 80 gold"],
		[0.0, 1200, 1500, 9999, 80, 300, "Missing 20% of 1500: still 80 gold (REP-06)"],
		[10.0, 1033, 1050, 9999, 7, 17, "1050 HP at 1033: +10% repairs the 1.619% left for 7 gold"],
		[10.0, 800, 1000, 6, 4, 10, "Gold 6, missing 20%: +10% repairs 1% for 4 gold"],
		[25.0, 800, 1000, 50, 48, 120, "Gold 50, +25% on 20% missing: 12% for 48 gold"],
		[10.0, 500, 1000, 9999, 40, 100, "+10% on 50% missing: 100 HP for 40 gold"],
		[25.0, 500, 1000, 9999, 100, 250, "+25% on 50% missing: 250 HP for 100 gold"],
		[10.0, 1000, 1000, 9999, 0, 0, "Full HP: refused, no gold (REP-04)"],
		[10.0, 995, 1000, 1, 0, 0, "Missing 0.5%, gold 1 < ceil(2): refused"],
		[10.0, 995, 1000, 2, 2, 5, "Missing 0.5%, gold 2: repairs all of it"],
	]
	for c in cases:
		var q := Fortress.quote_repair(c[0], c[1], c[2], c[3], 4)
		_hp_bar.max_value = c[2]
		_hp_bar.value = c[1]
		_hp_label.text = "Quote on %d / %d HP" % [c[1], c[2]]
		var step := "full" if c[0] <= 0.0 else "+%d%%" % roundi(c[0])
		var gold := "unlimited" if c[3] >= 9999 else str(c[3])
		_info_label.text = "%s with %s gold  ->  +%d HP for %d gold" % [step, gold, q.heal, q.cost]
		await assert_true(q.cost == c[4] and q.heal == c[5], c[6])


func test_repair_with_gold() -> void:
	await _begin_stage(6, "Gold repair rules", "REP-04: refused at full HP. REP-05: only in PREP")
	var f := _spawn_fortress()
	var repaired: Array = []
	var on_repaired := func(amount: int, source: StringName): repaired.append([amount, source])
	EventBus.fortress_repaired.connect(on_repaired)
	var gold := [1000]

	_set_state(&"PREP")
	var r := f.repair_with_gold(f.stats.repair_step_small_pct, 100)
	await assert_true(r.cost == 0, "Full HP in PREP: refused (REP-04)")

	_set_state(&"COMBAT")
	_hit(f, 400)
	await _wait(step_delay)
	r = f.repair_with_gold(f.stats.repair_step_small_pct, gold[0])
	await assert_true(r.cost == 0 and f.get_hp() == 600, "COMBAT: gold repair refused (REP-05)")

	_set_state(&"PREP")
	await _wait(step_delay)
	r = _gold_repair(f, f.stats.repair_step_small_pct, gold)
	await assert_true(r.cost == 40 and f.get_hp() == 700, "PREP +10%: 700 HP, 40 gold")
	r = _gold_repair(f, f.stats.repair_step_large_pct, gold)
	await assert_true(r.cost == 100 and f.get_hp() == 950, "PREP +25%: 950 HP, 100 gold")
	r = _gold_repair(f, 0.0, gold)
	await assert_true(r.cost == 20 and f.get_hp() == 1000, "PREP full: exactly max HP, 20 gold")
	await assert_true(repaired.size() == 3 and repaired[0][1] == &"GOLD", "fortress_repaired(GOLD) emitted per repair")

	EventBus.fortress_repaired.disconnect(on_repaired)


func _gold_repair(fortress: Fortress, step: float, gold: Array) -> Dictionary:
	var r := fortress.repair_with_gold(step, gold[0])
	gold[0] -= r.cost
	_heal_pop(fortress, r.heal, "+%d HP  -%d gold" % [r.heal, r.cost])
	_info_label.text = "Wave state: PREP    Gold: %d" % gold[0]
	return r


func test_emergency_repair() -> void:
	await _begin_stage(7, "Emergency repair", "CMD-02: heal a share of max HP for free. CMD-07: refused at full HP. CMD-08: overheal clamps")
	var f := _spawn_fortress()
	await assert_true(f.emergency_repair(0.2) == 0, "Full HP: refused (CMD-07)")
	_set_state(&"COMBAT")
	_hit(f, 500)
	await _wait(step_delay)
	var healed := f.emergency_repair(0.2)
	_heal_pop(f, healed, "+%d" % healed)
	await assert_true(healed == 200 and f.get_hp() == 700, "20% of 1000 heals 200")
	healed = f.emergency_repair(0.29)
	_heal_pop(f, healed, "+%d" % healed)
	await assert_true(healed == 290 and f.get_hp() == 990, "29% of 1000 heals 290")
	healed = f.emergency_repair(0.2)
	_heal_pop(f, healed, "+%d" % healed)
	await assert_true(healed == 10 and f.is_full(), "Overheal clamped at max (CMD-08, FORT-03)")


func test_melee_slot_capacity() -> void:
	await _begin_stage(8, "Melee slots", "FORT-01, CRD-01, CRD-03: 12 slots on the gate, extra attackers wait, a dead attacker frees its slot")
	var f := _spawn_fortress()
	var attackers: Array[MeshInstance3D] = []
	for i in 20:
		var dummy := _make_dummy(Color(0.8, 0.8, 0.8))
		dummy.global_position = Vector3(9.0 + (i % 2) * 1.2, 0.8, -7.0 + i * 0.7)
		attackers.append(dummy)
	await _wait(step_delay)

	var claimed := 0
	for i in attackers.size():
		var a := attackers[i]
		if f.claim_melee_slot(a):
			claimed += 1
			_tint(a, Color(0.35, 0.85, 0.4))
			_move_dummy(a, f.get_melee_slot_position(a) + Vector3(0.0, 0.8, 0.0))
		else:
			_tint(a, Color(0.9, 0.35, 0.3))
		_info_label.text = "Slot holders: %d    Waiting: %d" % [claimed, i + 1 - claimed]
		await _wait(step_delay * 0.25)
	await assert_true(claimed == 12, "20 attackers: exactly 12 get a slot")
	await assert_true(f.get_free_melee_slots() == 0, "No free slot left")

	var points := {}
	var outside := true
	for a in attackers:
		if f.has_melee_slot(a):
			var p := f.get_melee_slot_position(a)
			points[Vector2(snappedf(p.x, 0.01), snappedf(p.z, 0.01))] = true
			outside = outside and p.x > 2.5
	await assert_true(points.size() == 12, "12 distinct slot positions")
	await assert_true(outside, "All slots stand outside the gate face (+X)")

	var holder: MeshInstance3D = null
	for a in attackers:
		if f.has_melee_slot(a):
			holder = a
			break
	_pop_text(holder.global_position + Vector3(0.0, 1.5, 0.0), "dies", COLOR_FAIL)
	holder.free()
	await assert_true(f.get_free_melee_slots() == 1, "Freed attacker releases its slot (CRD-03)")
	var waiting: MeshInstance3D = null
	for a in attackers:
		if is_instance_valid(a) and not f.has_melee_slot(a):
			waiting = a
			break
	var took := f.claim_melee_slot(waiting)
	if took:
		_tint(waiting, Color(0.35, 0.85, 0.4))
		_move_dummy(waiting, f.get_melee_slot_position(waiting) + Vector3(0.0, 0.8, 0.0))
	await assert_true(took, "A waiting attacker takes the freed slot")
	f.release_melee_slot(waiting)
	_tint(waiting, Color(0.9, 0.35, 0.3))
	await assert_true(f.get_free_melee_slots() == 1, "release_melee_slot frees the slot")


func test_grunts_attack_fortress_in_level() -> void:
	await _begin_stage(9, "Grunts attack the gate in the level", "7.1 'Slot Fortress': 20 Grunts reach the gate, 12 attack from slots, the rest wait")
	_base_world.visible = false
	var level := LEVEL_SCENE.instantiate()
	_stage_root.add_child(level)
	var fortress := get_tree().get_first_node_in_group(&"fortress") as Fortress
	await assert_true(fortress != null and fortress.get_parent().name == &"Geometry", "Level instances the Fortress scene")
	var gate := fortress.global_position
	_camera.look_at_from_position(gate + Vector3(16.0, 13.0, 12.0), gate + Vector3(4.0, 0.0, 0.0))
	_camera.make_current()
	_set_state(&"COMBAT")
	for i in 3:
		await get_tree().physics_frame

	var grunts: Array[Enemy] = []
	for i in 20:
		var g := GRUNT_SCENE.instantiate() as Enemy
		g.data = g.data.duplicate()
		g.data.target_rules = [&"FORTRESS"] as Array[StringName]
		g.position = Vector3(-8.0 + (i % 4) * 1.2, 0.1, -6.0 + floori(i / 4.0) * 3.0)
		level.add_child(g)
		g.spawn_grace = false
		g.is_in_spawn_zone = false
		g.change_state(Enums.EnemyState.ADVANCE)
		grunts.append(g)

	var max_holders := 0
	var saw_wait := false
	var time_budget := 30.0 if _visual else 15.0
	var elapsed := 0.0
	var settle := 0
	while elapsed < time_budget:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var holders := 0
		var waiting := 0
		for g in grunts:
			if fortress.has_melee_slot(g):
				holders += 1
			if g.current_state == Enums.EnemyState.WAIT:
				saw_wait = true
				waiting += 1
		max_holders = maxi(max_holders, holders)
		_info_label.text = "Slot holders: %d / 12    Waiting: %d" % [holders, waiting]
		if fortress.get_hp() < 1000 and holders == 12 and saw_wait:
			settle += 1
			if not _visual or settle > 120:
				break

	var attacking := 0
	for g in grunts:
		if g.current_state == Enums.EnemyState.ATTACK:
			attacking += 1
	_note("fortress hp = %d, slot holders max = %d, attacking now = %d" % [fortress.get_hp(), max_holders, attacking])
	await assert_true(fortress.get_hp() < 1000, "Grunts damage the Fortress from their slots")
	await assert_true(max_holders == 12, "Never more than 12 slot holders, and all 12 get used")
	await assert_true(saw_wait, "Extra Grunts WAIT instead of piling in (CRD-01)")

	var victim: Enemy = null
	for g in grunts:
		if fortress.has_melee_slot(g):
			victim = g
			break
	_pop_text(victim.global_position + Vector3(0.0, 2.0, 0.0), "killed", COLOR_FAIL)
	victim.take_damage(DamageInfo.new(999, Enums.DamageType.TRUE))
	await get_tree().physics_frame
	await assert_true(fortress.get_free_melee_slots() >= 1, "Dead Grunt frees its slot (CRD-03)")
	await _wait(step_delay * 2.0)

	_set_state(&"PREP")
	level.queue_free()
	_base_world.visible = true
	_frame_fortress()
	await get_tree().process_frame
