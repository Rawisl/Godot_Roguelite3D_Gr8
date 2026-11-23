extends Node3D
## Weapon effects: icy mist and a blue tint on slowed units, flames on burning units, a bolt per Chain Lightning jump,
## the blade effect of each weapon model, the Rampage glow and mark per HP band, and the
## Reduce flashing setting. Headless: checks and quits.

const WEAPONS := ["frost", "chain_lightning", "burn", "rampage", "swift"]

var _pass := 0
var _fail := 0


class FakeCommander extends Node3D:
	var health: HealthComponent


func _ready() -> void:
	var limit_before := ParticleBudget.limit
	var flash_before: Variant = GameState.get_setting(&"reduce_flash", false)
	EventBus.settings_changed.emit(&"reduce_flash", false)
	var fx := WeaponFxManager.new()
	add_child(fx)
	var hit_fx := HitFxManager.new()
	add_child(hit_fx)

	var a := _grunt(Vector3(0, 0, 0))
	var b := _grunt(Vector3(1.5, 0, 0))
	var c := _grunt(Vector3(3.0, 0, 0))
	await get_tree().process_frame

	# Frost: icy mist and a blue tint while slowed, both gone after.
	a.apply_slow(0.2, 0.3)
	await _frames(3)
	_check("a slowed unit gives off icy mist", fx.has_frost(a))
	_check("a slowed unit is tinted blue", fx.has_tint(a))
	_check("a unit that is not slowed has no mist and no tint", not fx.has_frost(b) and not fx.has_tint(b))
	_check("the mist counts toward the particle budget", fx.active_particles() == fx.frost_amount)
	a.slow_timer = 0.0
	a.slow_pct = 0.0
	await _frames(2)
	_check("the mist and the tint stop when the slow ends", not fx.has_frost(a) and not fx.has_tint(a))

	# Burn: flames while burning, counted in the budget.
	b.apply_burn(50.0, 5.0, Enums.DamageType.SLASH)
	await _frames(2)
	_check("a burning unit shows flames", fx.has_fire(b))
	_check("the flames count toward the particle budget", fx.active_particles() == fx.fire_amount and fx.is_in_group(ParticleBudget.GROUP))
	b.burn_timer = 0.0
	await _frames(2)
	_check("the flames stop when the burn ends", not fx.has_fire(b))
	ParticleBudget.limit = 0
	c.apply_burn(50.0, 5.0, Enums.DamageType.SLASH)
	await _frames(2)
	_check("full budget: a new burn gets no flames", not fx.has_fire(c))
	ParticleBudget.limit = limit_before
	c.burn_timer = 0.0

	# Chain Lightning: one bolt per jump, all in one frame.
	var commander := FakeCommander.new()
	commander.add_to_group(&"commander")
	commander.position = Vector3(-2, 0, 0)
	add_child(commander)
	await get_tree().physics_frame
	for target in [a, b, c]:
		var bolt := DamageInfo.outgoing(2.0, 1.0, Enums.DamageType.SLASH, commander)
		bolt.is_weapon_effect = true
		target.take_damage(bolt)
	_check("a chain over three units draws three bolts", fx.bolt_count() == 3)
	_check("every unit the chain hits shows a white orb", fx.orb_count() == 3 and fx._orbs[0].get_child_count() == 1)
	_check("chain bolts play no sword slash", hit_fx._pools[HitFxManager.SWORD_HIT].all(func(n: Node) -> bool: return not n.is_playing()))
	var first: MeshInstance3D = fx._bolts[0]
	var second: MeshInstance3D = fx._bolts[1]
	_check("the first bolt, with its white and yellow strands, starts at the commander", (first.mesh as ImmediateMesh).get_surface_count() == 1 + fx.bolt_strand_colors.size() and _bolt_start(first).distance_to(commander.global_position + Vector3.UP * fx.bolt_height) < 0.01)
	_check("the next bolt starts at the previous target", _bolt_start(second).distance_to(a.global_position + Vector3.UP * fx.bolt_height) < 0.01)
	await _seconds(maxf(fx.bolt_time, fx.orb_time) + 0.1)
	_check("the bolts and orbs fade out", fx.bolt_count() == 0 and fx.orb_count() == 0)
	var tick := DamageInfo.outgoing(2.0, 1.0, Enums.DamageType.SLASH, commander, 0.0, Vector3.ZERO, true)
	tick.is_weapon_effect = true
	a.take_damage(tick)
	_check("a burn tick draws no bolt and no orb", fx.bolt_count() == 0 and fx.orb_count() == 0)
	EventBus.settings_changed.emit(&"reduce_flash", true)
	var dim := DamageInfo.outgoing(2.0, 1.0, Enums.DamageType.SLASH, commander)
	dim.is_weapon_effect = true
	await get_tree().physics_frame
	a.take_damage(dim)
	_check("Reduce flashing: the bolt is the violet strand only", fx.bolt_count() == 1 and (fx._bolts[0].mesh as ImmediateMesh).get_surface_count() == 1 and fx._orbs[0].get_child_count() == 0)
	EventBus.settings_changed.emit(&"reduce_flash", false)

	# Every weapon model carries its blade effect.
	var all_ok := true
	for id in WEAPONS:
		var data := load("res://data/weapons/%s.tres" % id) as WeaponData
		var model := data.model.instantiate() if data != null and data.model != null else null
		var blade := model as WeaponBladeFx
		if blade == null:
			all_ok = false
			print("  missing blade effect on ", id)
			if model != null:
				model.free()
			continue
		add_child(blade)
		var particles := blade.get_node_or_null("BladeParticles") as GPUParticles3D
		all_ok = all_ok and particles != null and blade.is_in_group(ParticleBudget.GROUP)
		all_ok = all_ok and blade.find_children("*", "MeshInstance3D", true, false).size() > 0
		blade.free()
	_check("every weapon model has a mesh and a blade effect in the budget", all_ok)

	# Rampage: the glow and the mark follow the HP bands of the weapon data.
	var rampage_data := load("res://data/weapons/rampage.tres") as WeaponData
	var bands_ok := true
	for pair in [[0.9, 0], [0.81, 0], [0.8, 1], [0.51, 1], [0.5, 2], [0.31, 2], [0.3, 3], [0.1, 3]]:
		bands_ok = bands_ok and WeaponBladeFx.rampage_band(pair[0], rampage_data) == pair[1]
	_check("Rampage bands follow the weapon data thresholds", bands_ok)

	var health := HealthComponent.new()
	health.name = "Health"
	commander.add_child(health)
	commander.health = health
	health.max_hp = 100
	health.hp = 100
	var rampage := rampage_data.model.instantiate() as WeaponBladeFx
	commander.add_child(rampage)
	await _frames(2)
	var glow := rampage._blade_material
	_check("Rampage at full HP: faint glow, embers on the blade and no mark", rampage.get_band() == 0 and glow != null and glow.emission_energy_multiplier > 0.0 and (rampage.get_node("BladeParticles") as GPUParticles3D).emitting and (rampage.get_mark() == null or not rampage.get_mark().visible))
	var energies: Array[float] = []
	var marks_ok := true
	for hp in [70, 40, 20]:
		health.hp = hp
		await _frames(1)
		energies.append(glow.emission_energy_multiplier)
		var mark := rampage.get_mark()
		marks_ok = marks_ok and mark != null and mark.visible and mark.text.length() == rampage.get_band()
	_check("Rampage glows brighter at each lower HP band", energies[0] > 0.0 and energies[1] > energies[0] and energies[2] > energies[1])
	_check("Rampage shows one, two, three chevrons, not colour alone", marks_ok)
	EventBus.settings_changed.emit(&"reduce_flash", true)
	await _frames(1)
	_check("Reduce flashing: the Rampage glow is lower", glow.emission_energy_multiplier < energies[2])
	EventBus.settings_changed.emit(&"reduce_flash", false)
	rampage.free()

	EventBus.settings_changed.emit(&"reduce_flash", flash_before == true)
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _grunt(pos: Vector3) -> Enemy:
	var enemy := preload("res://entities/enemy/grunt.tscn").instantiate() as Enemy
	enemy.position = pos
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.spawn_grace = false
	enemy.health.max_hp = 500
	enemy.health.hp = 500
	return enemy


func _bolt_start(bolt: MeshInstance3D) -> Vector3:
	var arrays := (bolt.mesh as ImmediateMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	return (verts[0] + verts[1]) * 0.5


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _seconds(time: float) -> void:
	await get_tree().create_timer(time).timeout
	await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
