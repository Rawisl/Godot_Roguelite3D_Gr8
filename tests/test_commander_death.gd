extends Node
## Manual test for commander death, prep heal, safe phases, fall recovery and low HP flag.
## Not shipped. Run with F6, prints OK/FAIL per case then quits.

var _pass := 0
var _fail := 0
var _died_count := 0
var _low_events: Array[bool] = []

func _ready() -> void:
	EventBus.commander_died.connect(func(): _died_count += 1)
	EventBus.commander_low_hp_changed.connect(func(is_low: bool): _low_events.append(is_low))
	_run()
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

func _spawn() -> CharacterBody3D:
	var commander := (load("res://entities/commander/commander.tscn") as PackedScene).instantiate()
	add_child(commander)
	EventBus.state_changed.emit(&"COMBAT")
	_died_count = 0
	_low_events.clear()
	return commander

func _hit(commander: CharacterBody3D, amount: int, type := Enums.DamageType.SLASH) -> void:
	commander.take_damage(DamageInfo.new(amount, type))

func _run() -> void:
	# Two lethal hits in the same frame: one death signal.
	var c := _spawn()
	_hit(c, 500)
	_hit(c, 500)
	_check("dies at 0 HP", c.is_dead and c.health.hp == 0)
	_check("commander_died emitted exactly once", _died_count == 1)
	_hit(c, 50)
	_check("no second death after more damage", _died_count == 1)
	c.free()

	# Commander mode is invulnerable.
	c = _spawn()
	EventBus.mode_changed.emit(&"COMMANDER")
	_hit(c, 500)
	_hit(c, 500, Enums.DamageType.TRUE)
	_check("commander mode takes no damage", c.health.hp == c.health.max_hp and not c.is_dead)
	c.free()

	# Death while stunned.
	c = _spawn()
	c.apply_stun(1.0)
	_check("stunned", c.is_stunned)
	_hit(c, 500)
	_check("dies while stunned, stun cleared", c.is_dead and not c.is_stunned and _died_count == 1)
	c.free()

	# PREP and SUMMARY are safe.
	c = _spawn()
	EventBus.state_changed.emit(&"PREP")
	_hit(c, 50)
	_check("no damage in PREP", c.health.hp == c.health.max_hp)
	EventBus.state_changed.emit(&"SUMMARY")
	_hit(c, 50)
	_check("no damage in SUMMARY", c.health.hp == c.health.max_hp)
	EventBus.state_changed.emit(&"COMBAT")
	_hit(c, 50)
	_check("damage works again in COMBAT", c.health.hp == c.health.max_hp - 50)
	c.free()

	# Prep heal: 60% of max, capped, not when dead.
	c = _spawn()
	c.health.hp = 20
	EventBus.state_changed.emit(&"PREP")
	_check("prep heal adds 60 HP", c.health.hp == 80)
	EventBus.state_changed.emit(&"COMBAT")
	EventBus.state_changed.emit(&"PREP")
	_check("prep heal capped at max HP", c.health.hp == 100)
	c.free()

	c = _spawn()
	_hit(c, 500)
	EventBus.state_changed.emit(&"PREP")
	_check("dead commander is not healed", c.health.hp == 0)
	c.free()

	# Fall recovery: 15% TRUE damage, never lethal.
	c = _spawn()
	c.global_position = Vector3(3, -20, 3)
	c._recover_from_fall()
	_check("fall costs 15 HP", c.health.hp == 85)
	_check("fall moves back above the void", c.global_position.y > -5.0 and c.velocity.is_zero_approx())
	c.health.hp = 10
	c._recover_from_fall()
	_check("fall never kills, minimum 1 HP", c.health.hp == 1 and not c.is_dead)
	c._recover_from_fall()
	_check("fall at 1 HP costs nothing", c.health.hp == 1)
	c.free()

	# Low HP flag flips only when crossing the threshold.
	c = _spawn()
	_hit(c, 70)
	_check("no low HP warning at 30%", _low_events.is_empty())
	_hit(c, 6)
	_check("low HP warning below 25%", _low_events == [true])
	_hit(c, 1)
	_check("warning is not repeated", _low_events == [true])
	c.health.heal(50)
	_check("warning clears after healing", _low_events == [true, false])
	_hit(c, 60)
	_check("warning returns when low again", _low_events == [true, false, true])
	_hit(c, 500)
	_check("warning clears on death", _low_events == [true, false, true, false])
	c.free()

func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("[test] %s %s" % [label, "OK" if ok else "FAIL"])
