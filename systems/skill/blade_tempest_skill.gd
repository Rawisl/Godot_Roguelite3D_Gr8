class_name BladeTempestSkill
extends RefCounted
## Blade Tempest: a channelled skill. For duration seconds the caster spins, hitting every enemy in the
## ring on its own interval, and after a short ramp fires sword waves in a fixed cycle of five directions.
## The caller owns the instance: it ticks it with game-time deltas and drops it when tick returns false.

const DIRECTION_COUNT := 5
## Guards the last-wave cut-off against float32 table values landing exactly on the boundary.
const TIME_EPSILON := 0.0001

## Called as on_wave.call(origin: Vector3, dir: Vector3) once per wave fired. No-op while invalid.
var on_wave: Callable
var elapsed: float = 0.0
var waves_fired: int = 0

var _caster: Node3D
var _data: SkillData
var _level: int
var _damage_mult: float
## Instance id of an enemy to the channel time at which the ring may hit it again.
var _next_whirl_hit: Dictionary[int, float] = {}


## Direction of wave number index, clockwise seen from above (+X right, +Z down on a top view).
static func wave_dir(index: int, start_angle_deg: float) -> Vector3:
	var theta := deg_to_rad(start_angle_deg + 360.0 / DIRECTION_COUNT * (index % DIRECTION_COUNT))
	return Vector3(cos(theta), 0.0, sin(theta))


func _init(caster: Node3D, data: SkillData, level: int, damage_mult: float) -> void:
	_caster = caster
	_data = data
	_level = level
	_damage_mult = damage_mult


## Advances by a game-time delta. Returns false once the channel is over (or the caster is gone).
func tick(delta: float) -> bool:
	var duration := _value(&"duration")
	# The epsilon keeps an accumulated 2.99999 s from granting one more tick than the duration allows.
	if elapsed >= duration - TIME_EPSILON or _caster == null or not is_instance_valid(_caster) or not _caster.is_inside_tree():
		return false
	_whirl()
	elapsed += delta
	_fire_due_waves(duration)
	return elapsed < duration - TIME_EPSILON


func _whirl() -> void:
	var base_damage := _value(&"whirl_damage")
	var interval := _value(&"hit_interval")
	for enemy in WhirlwindSkill.targets_in_radius(_caster, _value(&"radius")):
		var id := enemy.get_instance_id()
		# A new enemy is due at once. The schedule advances by whole intervals from the previous
		# due time, so the tick size does not shift later hits.
		var due: float = _next_whirl_hit.get(id, elapsed)
		if due - TIME_EPSILON > elapsed:
			continue
		due += interval
		while due <= elapsed + TIME_EPSILON:
			due += interval
		_next_whirl_hit[id] = due
		enemy.call(&"take_damage", DamageInfo.skill_hit(base_damage, _damage_mult, _data.damage_type, _caster, WhirlwindSkill.hit_direction(_caster, enemy)))


func _fire_due_waves(duration: float) -> void:
	var ramp := _value(&"ramp")
	var interval := _value(&"wave_interval")
	var last := duration - ramp - TIME_EPSILON
	while true:
		var due := ramp + waves_fired * interval
		if due > elapsed or due >= last:
			return
		var dir := wave_dir(waves_fired, _value(&"start_angle"))
		SwordWaveSkill.strike(_caster, dir, _value(&"wave_damage"), _value(&"width"), _value(&"range"),
				_value(&"radius"), _data.damage_type, _damage_mult)
		waves_fired += 1
		if on_wave.is_valid():
			on_wave.call(_caster.global_position, dir)


func _value(key: StringName) -> float:
	return _data.get_value(key, _level)
