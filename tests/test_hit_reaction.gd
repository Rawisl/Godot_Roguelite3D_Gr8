extends Node3D
## Test for HitReactionManager: a hit flashes the entity white for 0.1 s and freezes only its own
## animation for 0.05 s, plays the hit sound, never stops the game, skips damage over time, keeps
## a hover outline, holds to 3 flashes a second, and Reduce flashing turns the flash off.
## Not shipped. Run with F6 or headless, prints OK/FAIL per case then quits.

var _pass := 0
var _fail := 0
var _manager: HitReactionManager
var _sounds: Array[StringName] = []


func _ready() -> void:
	EventBus.sfx_requested.connect(func(id: StringName, _p: Vector3, _pr: int) -> void: _sounds.append(id))
	_manager = HitReactionManager.new()
	add_child(_manager)
	TimeManager.pausable_real_time = 10.0
	_run()
	EventBus.settings_changed.emit(&"reduce_flash", false)
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _unit(group: StringName) -> Array:
	var unit := Node3D.new()
	unit.add_to_group(group)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	unit.add_child(mesh)
	var player := AnimationPlayer.new()
	unit.add_child(player)
	var health := HealthComponent.new()
	health.name = "Health"
	health.max_hp = 1000
	unit.add_child(health)
	add_child(unit)
	return [unit, mesh, player, health]


func _hit(health: HealthComponent, dot := false) -> void:
	var info := DamageInfo.new(5)
	info.is_dot = dot
	health.take_damage(info)


func _step(seconds: float) -> void:
	TimeManager.pausable_real_time += seconds
	_manager._process(seconds)


func _run() -> void:
	var enemy := _unit(&"enemy")
	var unit: Node3D = enemy[0]
	var mesh: MeshInstance3D = enemy[1]
	var player: AnimationPlayer = enemy[2]
	var other := _unit(&"enemy")
	(other[2] as AnimationPlayer).speed_scale = 1.0
	player.speed_scale = 1.3

	_hit(enemy[3])
	_check("a hit flashes the enemy", _manager.is_flashing(unit) and mesh.material_overlay == _manager.flash_material)
	_check("a hit freezes its own animation", player.speed_scale == 0.0 and _manager.is_frozen(unit))
	_check("other enemies keep moving", (other[2] as AnimationPlayer).speed_scale == 1.0)
	_check("the game is not stopped", Engine.time_scale > 0.0 and not get_tree().paused)
	_check("the enemy hit sound plays", _sounds == [&"enemy_hit"])
	_step(0.06)
	_check("after 0.05 s the animation runs at its own speed again", is_equal_approx(player.speed_scale, 1.3))
	_check("the flash is still on before 0.1 s", mesh.material_overlay == _manager.flash_material)
	_step(0.05)
	_check("after 0.1 s the flash is off", mesh.material_overlay == null and not _manager.is_flashing(unit))

	# At most 3 flashes a second whatever the setting.
	_step(0.1)
	_hit(enemy[3])
	_check("a hit 0.21 s after the last flash does not flash", mesh.material_overlay == null)
	_check("but it still freezes", player.speed_scale == 0.0)
	_step(0.2)
	_hit(enemy[3])
	_check("a hit 0.41 s after the last flash flashes again", mesh.material_overlay == _manager.flash_material)
	_step(0.2)

	# Damage over time gets nothing.
	_sounds.clear()
	_step(1.0)
	_hit(enemy[3], true)
	_check("a damage over time tick does not flash, freeze or sound", mesh.material_overlay == null and player.speed_scale != 0.0 and _sounds.is_empty())

	# The hover outline is put back.
	var outline := StandardMaterial3D.new()
	mesh.material_overlay = outline
	_hit(enemy[3])
	_step(0.15)
	_check("the hover outline comes back after the flash", mesh.material_overlay == outline)
	mesh.material_overlay = null

	# An outline put on during the flash keeps the flash as "before"; when it is taken off later the
	# flash must not come back for good.
	_step(1.0)
	_hit(enemy[3])
	var kept_by_outline: Material = mesh.material_overlay
	mesh.material_overlay = outline
	_step(0.15)
	_check("the flash ends under an outline put on during it", mesh.material_overlay == outline)
	mesh.material_overlay = kept_by_outline
	_step(0.02)
	_check("taking the outline off later does not leave the flash on", mesh.material_overlay == null)
	_check("nothing is left to watch afterwards", _manager._handed_back.is_empty())

	# Someone else changes the speed while frozen: theirs is kept.
	_step(1.0)
	_hit(enemy[3])
	player.speed_scale = 0.5
	_step(0.06)
	_check("a speed set during the freeze is kept", is_equal_approx(player.speed_scale, 0.5))

	# Pause holds the timers: pausable real time does not move.
	_step(1.0)
	_hit(enemy[3])
	_manager._process(0.5)
	_check("while paused the freeze holds", player.speed_scale == 0.0)
	_step(0.06)

	# Commander: its own sound.
	var commander := _unit(&"commander")
	_sounds.clear()
	_hit(commander[3])
	_check("a hit on the commander flashes it and plays commander_hit",
		(commander[1] as MeshInstance3D).material_overlay == _manager.flash_material and _sounds == [&"commander_hit"])
	_step(0.15)

	# Reduce flashing: no flash, freeze and sound stay.
	EventBus.settings_changed.emit(&"reduce_flash", true)
	_sounds.clear()
	_step(1.0)
	_hit(enemy[3])
	_check("Reduce flashing: no flash", mesh.material_overlay == null)
	_check("Reduce flashing: still freezes and sounds", player.speed_scale == 0.0 and _sounds == [&"enemy_hit"])
	_step(0.1)
	EventBus.settings_changed.emit(&"reduce_flash", false)

	# A freed enemy is forgotten.
	unit.free()
	_step(0.2)
	_check("a freed enemy is dropped", not _manager._hits.has(unit))

	# Effects under a no-flash node keep their own look.
	_step(1.0)
	var fx_unit := _unit(&"enemy")
	var fx_root := Node3D.new()
	fx_root.add_to_group(HitReactionManager.NO_FLASH_GROUP)
	var fx_mid := Node3D.new()
	var fx_mesh := MeshInstance3D.new()
	fx_mesh.mesh = BoxMesh.new()
	var fx_overlay := StandardMaterial3D.new()
	fx_mesh.material_overlay = fx_overlay
	var fx_particles := CPUParticles3D.new()
	(fx_unit[0] as Node3D).add_child(fx_root)
	fx_root.add_child(fx_mid)
	fx_mid.add_child(fx_mesh)
	fx_mid.add_child(fx_particles)
	_hit(fx_unit[3])
	_check("a hit flashes the body but not a mesh under a no-flash node",
		(fx_unit[1] as MeshInstance3D).material_overlay == _manager.flash_material
		and fx_mesh.material_overlay == fx_overlay and fx_particles.material_overlay == null)
	_step(0.15)
	_check("the effect keeps its overlay after the flash",
		fx_mesh.material_overlay == fx_overlay and (fx_unit[1] as MeshInstance3D).material_overlay == null)
	(fx_unit[0] as Node3D).free()

	# A no-flash group above the entity does not stop its flash.
	_step(1.0)
	var holder := Node3D.new()
	holder.add_to_group(HitReactionManager.NO_FLASH_GROUP)
	add_child(holder)
	var held := _unit(&"enemy")
	(held[0] as Node3D).reparent(holder)
	_hit(held[3])
	_check("a no-flash group above the entity does not stop its flash",
		(held[1] as MeshInstance3D).material_overlay == _manager.flash_material)
	_step(0.15)
	holder.free()


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
