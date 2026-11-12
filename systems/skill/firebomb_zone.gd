class_name FirebombZone
extends Node3D
## Burning ground left by Firebomb. Once per game second it damages every enemy inside the radius
## with a damage-over-time hit from the caster, so the kill counts for the commander's XP.
## Frees itself after the last tick. The flames are drawn by the VFX, not by this node.

const ENEMY_GROUP: StringName = &"enemy"
const TICK_SECONDS := 1.0

var caster: Node3D
var damage_per_tick: float = 0.0
var damage_mult: float = 1.0
var damage_type: Enums.DamageType = Enums.DamageType.BLAST
var radius: float = 0.0
var tick_count: int = 0
var ticks_done: int = 0

var _clock: float = 0.0


## Call before adding the zone to the tree. duration is in game seconds, one tick per second.
func setup(p_caster: Node3D, data: SkillData, level: int, p_mult: float) -> void:
	caster = p_caster
	damage_per_tick = data.get_value(&"dps", level)
	radius = data.get_value(&"radius", level)
	tick_count = maxi(1, roundi(data.get_value(&"duration", level) / TICK_SECONDS))
	damage_mult = p_mult
	damage_type = data.damage_type


func _physics_process(delta: float) -> void:
	tick(delta)


## delta is game time (scaled by TimeManager, stopped by Pause).
func tick(delta: float) -> void:
	_clock += delta
	while _clock >= TICK_SECONDS and ticks_done < tick_count:
		_clock -= TICK_SECONDS
		ticks_done += 1
		_burn()
	if ticks_done >= tick_count and not is_queued_for_deletion():
		queue_free()


func _burn() -> void:
	var source: Node3D = caster if caster != null and is_instance_valid(caster) else null
	var radius_sq := radius * radius
	for node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.get("is_dead") == true or not enemy.has_method("take_damage"):
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		if offset.length_squared() > radius_sq:
			continue
		var direction := offset.normalized() if not offset.is_zero_approx() else Vector3.FORWARD
		enemy.call(&"take_damage", DamageInfo.skill_hit(damage_per_tick, damage_mult, damage_type, source, direction, true))
