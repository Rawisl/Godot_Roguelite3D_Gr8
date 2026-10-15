class_name Projectile
extends Area3D
 
## Ranged projectile supporting linear and parabolic trajectories (AI-02).
## Emits DamageInfo on impact; respects Dodge i-frames on the Commander.
 
## Pooled projectiles (PRJ-04): ProjectilePool owns them, call release() instead of queue_free().
## Emitted by release(); the pool listens and takes the projectile back.
signal released(projectile: Projectile)
 
## Set by ProjectilePool.
var in_use: bool = false
var pool_key: String = ""
 
@export var speed: float = 20.0
@export var damage: int = 8
@export var damage_type: Enums.DamageType = Enums.DamageType.PIERCE
@export var is_parabolic: bool = true
@export var arc_height: float = 2.5
 
var source: Node = null
var target: Node3D = null
 
var start_pos: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO
var duration: float = 0.5
var elapsed_time: float = 0.0
var has_launched: bool = false
 
@onready var life_timer: Timer = get_node_or_null("LifeTimer")
 
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if life_timer != null:
		life_timer.timeout.connect(queue_free)
		if life_timer.is_stopped():
			life_timer.start(5.0)
 
	_ensure_visual_fallback()
 
func _ensure_visual_fallback() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model != null and model.get_child_count() == 0:
		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.4)
		mesh_inst.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.3, 0.2)
		mesh_inst.material_override = mat
		model.add_child(mesh_inst)
 
var intended_target: Node3D = null

func launch(
	p_start: Vector3,
	p_target_pos: Vector3,
	p_damage: int,
	p_source: Node = null,
	p_damage_type: Enums.DamageType = Enums.DamageType.PIERCE,
	p_parabolic: bool = true,
	p_arc_height: float = 2.5,
	p_intended_target: Node3D = null,
	p_speed: float = 20.0
) -> void:
	start_pos = p_start
	target_pos = p_target_pos
	damage = p_damage
	source = p_source
	damage_type = p_damage_type
	is_parabolic = p_parabolic
	arc_height = p_arc_height
	intended_target = p_intended_target
	speed = p_speed if p_speed > 0.0 else 20.0
 
	global_position = start_pos
	var flat_dist := Vector2(target_pos.x - start_pos.x, target_pos.z - start_pos.z).length()
	duration = maxf(0.15, flat_dist / maxf(1.0, speed))
	elapsed_time = 0.0
	has_launched = true
 
	_update_transform_at(0.0)
 
func _physics_process(delta: float) -> void:
	if not has_launched:
		return
 
	elapsed_time += delta
	var t := clampf(elapsed_time / duration, 0.0, 1.0)
	_update_transform_at(t)
 
	if t >= 1.0:
		_on_impact_at_target()
 
func _update_transform_at(t: float) -> void:
	var current_pos := start_pos.lerp(target_pos, t)
	if is_parabolic:
		var height_offset := 4.0 * arc_height * t * (1.0 - t)
		current_pos.y += height_offset
 
		var dt_height := 4.0 * arc_height * (1.0 - 2.0 * t)
		var tangent := (target_pos - start_pos) + Vector3(0.0, dt_height, 0.0)
		if tangent.length_squared() > 0.001:
			var look_target := global_position + tangent.normalized()
			if not look_target.is_equal_approx(global_position):
				look_at(look_target, Vector3.UP)
	else:
		var dir := (target_pos - start_pos)
		if dir.length_squared() > 0.001:
			var look_target := global_position + dir.normalized()
			if not look_target.is_equal_approx(global_position):
				look_at(look_target, Vector3.UP)
 
	global_position = current_pos
 
func _on_body_entered(body: Node) -> void:
	if body == source:
		return
	if not has_launched:
		return
	_apply_hit(body)
 
func _on_area_entered(area: Area3D) -> void:
	if area == source or area.get_parent() == source:
		return
	if not has_launched:
		return
	var parent_body := area.get_parent()
	if parent_body != null and parent_body != source and parent_body.has_method("take_damage"):
		_apply_hit(parent_body)
 
func _apply_hit(target_node: Node) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return

	# AI-02: Parabolic projectile is not blocked by Barricade unless Barricade is the intended target
	var is_barricade := target_node.is_in_group(&"barricade")
	if not is_barricade and "data" in target_node and target_node.data != null and "id" in target_node.data:
		is_barricade = (target_node.data.id == &"barricade")

	if is_barricade:
		if intended_target != null and intended_target != target_node:
			return
		elif intended_target == null and target_node.global_position.distance_to(target_pos) > 2.0:
			return

	if target_node.has_method("take_damage"):
		var hit_dir := (target_pos - start_pos).normalized() if (target_pos - start_pos).length_squared() > 0.001 else Vector3.FORWARD
		var info := DamageInfo.new(damage, damage_type, source, 0.0, hit_dir)
		target_node.take_damage(info)
		EventBus.projectile_hit.emit(target_node, damage, Enums.DamageType.keys()[damage_type], 0.0)
	queue_free()
 
const IMPACT_RADIUS: float = 1.0

func _on_impact_at_target() -> void:
	if intended_target != null and is_instance_valid(intended_target):
		var diff := global_position - intended_target.global_position
		diff.y = 0.0
		if diff.length() <= IMPACT_RADIUS and intended_target.has_method("take_damage"):
			_apply_hit(intended_target)
			return
	queue_free()
 
## Pooled flight toward a node (tower shots). Subclasses set up their movement here.
## Named fire() because launch() is the Archer's position-based flight above.
func fire(from: Vector3, to: Node3D, dmg: int, dmg_type: Enums.DamageType, spd: float) -> void:
	global_position = from
	target = to
	damage = dmg
	damage_type = dmg_type
	speed = spd
 
func release() -> void:
	if not in_use:
		return
	released.emit(self)
 