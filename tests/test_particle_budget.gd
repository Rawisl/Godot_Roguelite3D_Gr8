extends Node3D
## One particle budget for the whole game: the limit comes from the Graphics tab (500, 1500,
## 3000), every effect manager counts toward the same total, secondary effects are skipped once
## it is full and main effects always play. Headless: checks and quits.

var _pass := 0
var _fail := 0


class FakeSource extends Node:
	var live := 0
	func active_particles() -> int:
		return live


func _ready() -> void:
	var before := ParticleBudget.limit
	var hit_fx := HitFxManager.new()
	add_child(hit_fx)
	var skill_fx := SkillFxManager.new()
	add_child(skill_fx)
	var other := FakeSource.new()
	other.add_to_group(ParticleBudget.GROUP)
	add_child(other)

	# The Graphics tab sets the one limit, through the quality applier of the level.
	var level := Node3D.new()
	level.add_child(QualityApplier.new())
	add_child(level)
	await get_tree().process_frame
	for limit in QualitySettings.PARTICLE_LIMITS:
		EventBus.settings_changed.emit(&"particle_limit", limit)
		_check("particle limit %d sets the shared budget" % limit, ParticleBudget.limit == limit and hit_fx.particle_budget == limit and skill_fx.particle_budget == limit)
	EventBus.settings_changed.emit(&"particle_limit", 500)

	# The total is the sum over every source.
	other.live = 300
	_check("the budget adds up every source", ParticleBudget.used(get_tree()) == 300 + hit_fx.active_particles() + skill_fx.active_particles())

	# Room for an extra while under the limit.
	_check("an extra fits while there is room", ParticleBudget.has_room(get_tree(), 100, true))
	other.live = 480
	_check("an extra that would go over is skipped", not ParticleBudget.has_room(get_tree(), 40, true))
	_check("a main effect always plays", ParticleBudget.has_room(get_tree(), 400, false))

	# The hit effects follow it: an arrow hit is skipped, a cannon blast plays.
	var sample: ArrowHit = hit_fx._pools[HitFxManager.ARROW_HIT][0]
	other.live = ParticleBudget.limit - sample.spark_count + 1
	hit_fx.play_arrow(Vector3.ZERO, Vector3.FORWARD)
	_check("full budget: the arrow hit (extra) is skipped", hit_fx._pools[HitFxManager.ARROW_HIT].all(func(fx: Node) -> bool: return not fx.is_playing()))
	hit_fx.play_blast(Vector3.ZERO, Vector3.DOWN, 2.0)
	_check("full budget: the cannon blast (main) still plays", hit_fx._pools[HitFxManager.CANNON_BLAST].any(func(fx: Node) -> bool: return fx.is_playing()))
	other.live = 0
	hit_fx.play_arrow(Vector3.ZERO, Vector3.FORWARD)
	_check("room again: the arrow hit plays", hit_fx._pools[HitFxManager.ARROW_HIT].any(func(fx: Node) -> bool: return fx.is_playing()))

	# Every effect manager of the level joins the shared count.
	var managers := [BuildFxManager.new(), DestroyFxManager.new(), BossFxManager.new()]
	for m in managers:
		add_child(m)
	var joined := managers.all(func(m: Node) -> bool: return m.is_in_group(ParticleBudget.GROUP) and m.has_method(&"active_particles"))
	_check("build, destroy and boss effects count toward the same budget", joined and hit_fx.is_in_group(ParticleBudget.GROUP) and skill_fx.is_in_group(ParticleBudget.GROUP))

	ParticleBudget.limit = before
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("OK   ", label)
	else:
		_fail += 1
		print("FAIL ", label)
