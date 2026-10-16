class_name Archer
extends Enemy

## Archer enemy archetype with parabolic ranged attacks (AI-02).
## Prioritizes targets based on data.target_rules (PLAYER, TOWER_WALL, TOWER_GROUND, BARRICADE, FORTRESS).

const ARROW_SCENE: PackedScene = preload("res://entities/projectile/enemy_projectile.tscn")

func _ready() -> void:
	super._ready()

func _play_attack_anim() -> void:
	var aim_clip: StringName = data.anim_attack if (data != null and not data.anim_attack.is_empty()) else &"ranged/Ranged_2H_Aiming"
	play_anim(aim_clip, 1.0)

func _execute_attack_action() -> void:
	if current_target == null or not is_instance_valid(current_target) or not _is_target_valid(current_target):
		return

	var shoot_clip: StringName = data.anim_shoot if (data != null and not data.anim_shoot.is_empty()) else &"ranged/Ranged_2H_Shoot"
	play_anim(shoot_clip, 1.0)

	var muzzle := get_node_or_null("Muzzle") as Marker3D
	var spawn_pos: Vector3 = muzzle.global_position if muzzle != null else global_position + Vector3(0.0, 1.2, 0.0)

	var target_center: Vector3 = current_target.global_position
	if current_target is CharacterBody3D or current_target is StaticBody3D:
		target_center.y += 0.9

	var arrow := ARROW_SCENE.instantiate() as Projectile
	if arrow != null:
		var root := get_tree().current_scene if get_tree() else null
		if root != null:
			root.add_child(arrow)
		elif get_parent() != null:
			get_parent().add_child(arrow)
		else:
			add_child(arrow)

		var dmg: int = data.base_damage if data else 8
		var dmg_type: Enums.DamageType = data.damage_type if data else Enums.DamageType.PIERCE
		var spd: float = data.projectile_speed if (data != null and data.projectile_speed > 0.0) else 20.0
		arrow.launch(spawn_pos, target_center, dmg, self, dmg_type, true, 2.5, current_target, spd)
