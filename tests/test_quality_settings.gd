extends Node3D
## Test for the quality rows of the Graphics tab: presets set shadows and the particle limit, a
## row changed by hand turns the preset to Custom, the level's sun, the particle budget and the
## see-through follow the setting, and a bad value from settings.cfg is ignored.
## Not shipped. Run with F6 or headless, prints OK/FAIL per case then quits.

const TAB_SCENE := preload("res://ui/screens/tab_graphics.tscn")

var _pass := 0
var _fail := 0


func _ready() -> void:
	for key in QualitySettings.KEYS:
		GameState._settings.erase(key)
	await _run()
	for key in QualitySettings.KEYS:
		GameState._settings.erase(key)
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _run() -> void:
	# Rules.
	_check("presets match their rows", QualitySettings.preset_for(0, 500) == &"LOW"
		and QualitySettings.preset_for(1, 1500) == &"MEDIUM" and QualitySettings.preset_for(2, 3000) == &"HIGH")
	_check("any other mix is Custom", QualitySettings.preset_for(2, 500) == &"CUSTOM")
	var default_preset := QualitySettings.default_preset()
	_check("with nothing saved the preset follows the GPU (%s)" % default_preset,
		QualitySettings.current(&"graphics_preset") == default_preset
		and QualitySettings.current(&"particle_limit") == QualitySettings.PRESETS[default_preset][&"particle_limit"])
	_check("see-through defaults to fading", QualitySettings.current(&"see_through") == QualitySettings.SEE_THROUGH_DITHER)

	# A small level: a sun with shadows, a lamp without, the hit effects and the occlusion.
	var level := Node3D.new()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	level.add_child(sun)
	var other_sun := DirectionalLight3D.new()
	other_sun.shadow_enabled = false
	level.add_child(other_sun)
	var hit_fx := HitFxManager.new()
	level.add_child(hit_fx)
	var occlusion := OcclusionManager.new()
	level.add_child(occlusion)
	level.add_child(QualityApplier.new())
	add_child(level)
	await get_tree().process_frame

	# The tab: picking a preset sets the rows.
	var tab: Control = TAB_SCENE.instantiate()
	add_child(tab)
	tab._preset.select(0)
	tab._preset.item_selected.emit(0)
	_check("Low: shadows off, 500 particles", GameState.get_setting(&"shadow_quality") == 0 and GameState.get_setting(&"particle_limit") == 500
		and GameState.get_setting(&"graphics_preset") == &"LOW")
	_check("Low: the sun stops casting shadows", not sun.shadow_enabled)
	_check("Low: the hit effects budget is 500", hit_fx.particle_budget == 500)
	tab._preset.item_selected.emit(2)
	_check("High: shadows high, 3000 particles", GameState.get_setting(&"shadow_quality") == 2 and hit_fx.particle_budget == 3000)
	_check("High: the sun casts shadows again", sun.shadow_enabled)
	_check("a light made without shadows never gets them", not other_sun.shadow_enabled)

	# One row by hand: Custom; back to a preset's values: that preset.
	tab._particles.item_selected.emit(0)
	_check("a row changed by hand turns the preset to Custom", GameState.get_setting(&"graphics_preset") == &"CUSTOM"
		and tab._preset.selected == QualitySettings.PRESET_IDS.find(&"CUSTOM"))
	_check("the hand-picked row applies", hit_fx.particle_budget == 500 and sun.shadow_enabled)
	tab._shadow.item_selected.emit(0)
	_check("rows that match a preset show that preset", GameState.get_setting(&"graphics_preset") == &"LOW")
	tab._preset.item_selected.emit(3)
	_check("picking Custom keeps the rows", GameState.get_setting(&"particle_limit") == 500 and GameState.get_setting(&"graphics_preset") == &"LOW")

	# See-through.
	tab._see_through.item_selected.emit(1)
	_check("see-through off stops the fading", not occlusion.enabled)
	_check("a preset does not touch see-through", (func() -> bool:
		tab._preset.item_selected.emit(1)
		return not occlusion.enabled).call())
	tab._see_through.item_selected.emit(0)
	_check("see-through back on", occlusion.enabled)

	# A bad value from settings.cfg is ignored.
	EventBus.settings_changed.emit(&"particle_limit", 999)
	_check("an unknown particle limit is ignored", hit_fx.particle_budget == 1500 and QualitySettings.current(&"particle_limit") == 1500)
	EventBus.settings_changed.emit(&"shadow_quality", "high")
	_check("a wrong type for shadows is ignored", QualitySettings.current(&"shadow_quality") == 1 and sun.shadow_enabled)

	# A level made later reads the stored values.
	EventBus.settings_changed.emit(&"shadow_quality", 0)
	var later := Node3D.new()
	var later_sun := DirectionalLight3D.new()
	later_sun.shadow_enabled = true
	later.add_child(later_sun)
	later.add_child(QualityApplier.new())
	add_child(later)
	await get_tree().process_frame
	_check("a level loaded after the change starts with it", not later_sun.shadow_enabled)
	_check("the Keep panel stays below the new rows", tab._keep_panel.get_index() == tab._keep_panel.get_parent().get_child_count() - 1)
	tab.free()


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
