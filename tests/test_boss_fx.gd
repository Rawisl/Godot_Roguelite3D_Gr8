extends Node3D
## Test for BossFxManager on the Bulwark model: the armor break (steam, plates, core, banner),
## Enrage (red core, vents, screen shake), the pulse limit and Reduced flashing, and cleanup.
## Not shipped. Run with F6, prints OK/FAIL per case then quits.

const BULWARK_MODEL: PackedScene = preload("res://contents/assets/characters/enemy and boss/boss_bulwark_model.tscn")

var _pass := 0
var _fail := 0
var _mgr: BossFxManager
var _boss: Node3D
var _alerts: Array[StringName] = []
var _shakes: Array[StringName] = []


func _ready() -> void:
	EventBus.alert_requested.connect(func(_tier: int, key: StringName, _p: Dictionary) -> void: _alerts.append(key))
	EventBus.screen_shake_requested.connect(func(_i: float, source: StringName) -> void: _shakes.append(source))
	_mgr = BossFxManager.new()
	add_child(_mgr)
	await _run()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _spawn_boss() -> void:
	if _boss != null:
		_boss.free()
	_boss = Node3D.new()
	_boss.name = "FakeBulwark"
	_boss.add_to_group(&"boss")
	_boss.add_child(BULWARK_MODEL.instantiate())
	add_child(_boss)
	_boss.global_position = Vector3(4, 0, 0)
	_alerts.clear()
	_shakes.clear()
	EventBus.boss_spawned.emit()
	EventBus.boss_phase_changed.emit(&"ARMORED")


func _energies(seconds: float, step := 0.02) -> Array[float]:
	var out: Array[float] = []
	var t := 0.0
	while t < seconds:
		TimeManager.game_time += step
		_mgr._process(step)
		out.append(_mgr.get_core_energy())
		t += step
	return out


## Number of times the glow passes its low point per second.
func _pulses_per_second(values: Array[float], step: float) -> float:
	var lows := 0
	for i in range(1, values.size() - 1):
		if values[i] < values[i - 1] and values[i] <= values[i + 1]:
			lows += 1
	return lows / (values.size() * step)


func _run() -> void:
	_spawn_boss()
	await get_tree().process_frame
	var rig := _mgr.get_rig()
	_check("the rig is built on the boss", not rig.is_empty())
	var core := rig.core as Node3D
	_check("the core follows the chest bone", core.get_parent().get_parent() is BoneAttachment3D)
	_check("the core sits on the chest, in front", core.global_position.y > 1.6 and core.global_position.y < 2.6
			and core.global_position.z > 0.2)
	_check("ARMORED: the core is dark", not _mgr.is_core_lit())

	# Armor break.
	EventBus.boss_phase_changed.emit(&"TRANSITION")
	_check("TRANSITION lights the core", _mgr.is_core_lit())
	_check("the core is orange", (rig.light as OmniLight3D).light_color.is_equal_approx(_mgr.exposed_color))
	_check("armor plates fly off", (rig.plates as CPUParticles3D).emitting and (rig.plates as CPUParticles3D).one_shot)
	_check("a burst of steam", (rig.break_steam as CPUParticles3D).emitting)
	_check("the 'Lộ lõi' banner is asked for once", _alerts == [&"alert.boss_core_exposed"])
	_check("the banner key exists in the locale file", FileAccess.get_file_as_string("res://data/locale/strings.csv").contains("alert.boss_core_exposed,"))
	EventBus.boss_phase_changed.emit(&"EXPOSED")
	_check("EXPOSED keeps the core lit", _mgr.is_core_lit())
	_check("EXPOSED does not repeat the burst or the banner", _alerts.size() == 1)
	var steam_mat := ((rig.break_steam as CPUParticles3D).mesh as QuadMesh).material as StandardMaterial3D
	_check("steam is dithered, not blended over the boss", steam_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH)

	# Pulse: slow enough, steady with Reduced flashing.
	var step := 0.02
	var glow := _energies(4.0, step)
	_check("the core pulses", glow.max() - glow.min() > 0.1)
	_check("the pulse stays under 3 per second (%.1f)" % _pulses_per_second(glow, step), _pulses_per_second(glow, step) <= 3.0)
	EventBus.settings_changed.emit(&"reduce_flash", true)
	glow = _energies(1.0, step)
	_check("Reduced flashing holds the glow steady", is_equal_approx(glow.max(), glow.min()))
	EventBus.settings_changed.emit(&"reduce_flash", false)

	# Paused: game time stops, so the glow holds.
	_mgr._process(0.016)
	var held := _mgr.get_core_energy()
	_mgr._process(0.016)
	_mgr._process(0.016)
	_check("the pulse holds while game time is stopped", is_equal_approx(_mgr.get_core_energy(), held))

	# Enrage.
	var exposed_peak := _mgr.exposed_energy
	EventBus.boss_enraged.emit()
	_check("Enrage marks the boss enraged", _mgr.is_enraged())
	_check("the core turns red", (rig.light as OmniLight3D).light_color.is_equal_approx(_mgr.enraged_color))
	_check("the core glows brighter", _energies(2.0, step).max() > exposed_peak)
	_check("the core's light stays low and local (%.2f, range %.1f m)" % [_mgr.get_core_light(), (rig.light as OmniLight3D).omni_range],
			_mgr.get_core_light() <= _mgr.enraged_light + 0.001 and (rig.light as OmniLight3D).omni_range <= 3.0)
	var vents: Array = rig.vents
	_check("steam vents from both shoulders", vents.size() == 2 and vents.all(func(v: CPUParticles3D) -> bool: return v.emitting and not v.one_shot))
	_check("Enrage shakes the screen once", _shakes.count(&"enrage") == 1)
	glow = _energies(4.0, step)
	_check("the enraged pulse stays under 3 per second (%.1f)" % _pulses_per_second(glow, step), _pulses_per_second(glow, step) <= 3.0)
	EventBus.boss_enraged.emit()
	_check("a second boss_enraged changes nothing", _shakes.count(&"enrage") == 1)

	# Death: vents stop, core goes dark.
	EventBus.boss_defeated.emit()
	_check("boss death stops the vents", vents.all(func(v: CPUParticles3D) -> bool: return not v.emitting))
	_check("boss death puts the core out", not _mgr.is_core_lit())

	# Enrage while the armor still holds: the core shows red at once.
	_spawn_boss()
	await get_tree().process_frame
	_check("a new boss starts dark and calm", not _mgr.is_core_lit() and not _mgr.is_enraged())
	EventBus.boss_enraged.emit()
	_check("Enrage in ARMORED lights the core red", _mgr.is_core_lit()
			and (_mgr.get_rig().light as OmniLight3D).light_color.is_equal_approx(_mgr.enraged_color))

	# The boss is freed: no crash, the next signal finds nothing.
	_boss.free()
	_boss = null
	EventBus.boss_phase_changed.emit(&"TRANSITION")
	_mgr._process(0.016)
	_check("signals after the boss is freed are ignored", not _mgr.is_core_lit())


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[test] OK   %s" % label)
	else:
		_fail += 1
		print("[test] FAIL %s" % label)
