class_name DestroyFxManager
extends Node
## Tower destroyed: the tower shrinks a little, then lifts and swells like a balloon and pops into a burst of
## smoke and flying debris, and the rubble drops in with a small squash. Follows
## EventBus.tower_destroyed, so a drained heal station gets the same effect.
## The slot frees the tower at once, so its Model is moved to a stand-in node for the swell; the
## stand-in does not process, so the model's own scripts never touch the freed tower.
## Only visuals move: the rubble collision is there from the first frame.
## The swell runs on TimeManager's pausable real-time clock: the same pace at x2 and x3, and it
## holds while the game is paused. Smoke, debris and the rubble drop follow BuildFxManager.

const BURST := preload("res://art/vfx/destroy_burst.tscn")

@export_group("Swell")
## Size at the start, before it swells (X and Z, then Y squashed a bit more).
@export var shrink_scale := Vector3(0.9, 0.85, 0.9)
## Part of swell_time spent shrinking.
@export_range(0.0, 0.6) var shrink_part := 0.25
## How far the tower lifts while it swells.
@export var swell_lift := 0.35
## Size at the end of the swell, just before the pop.
@export var swell_scale := Vector3(1.18, 1.12, 1.18)
@export var swell_time := 0.4

@export_group("Rubble")
## Height the rubble falls from.
@export var drop_height := 0.6
## Scale of the rubble when it appears, and its squash when it lands (X and Z wide, Y flat).
@export var start_scale := Vector3(0.7, 1.3, 0.7)
@export var land_squash := Vector3(1.15, 0.8, 1.15)
@export var drop_time := 0.18
@export var settle_time := 0.16

var _swells: Array[Dictionary] = []
## Smoke and debris still playing; their speed follows the game speed every frame.
var _particles: Array[CPUParticles3D] = []


func _ready() -> void:
	EventBus.tower_destroyed.connect(_on_tower_destroyed)


func _on_tower_destroyed(slot_id: StringName) -> void:
	for node in get_tree().get_nodes_in_group(&"slot"):
		var slot := node as Slot
		if slot != null and slot.slot_id == slot_id:
			play(slot, _dying_tower(slot))
			return


## The tower the slot has just let go of: still in the tree until the end of the frame.
## Relies on Slot.ruin() calling queue_free() on the tower before it emits tower_destroyed. If
## that order changes, no tower is found and the effect skips the swell and only pops;
## test_destroy_fx checks that the model reaches the stand-in, so it would show there.
func _dying_tower(slot: Slot) -> Tower:
	for node in slot.find_children("*", "Tower", true, false):
		var tower := node as Tower
		if tower.is_queued_for_deletion():
			return tower
	return null


func play(slot: Slot, tower: Tower = null) -> void:
	var rubble := _rubble_visual(slot)
	var model := tower.get_node_or_null(^"Model") as Node3D if tower != null else null
	if model == null:
		_pop(slot, rubble)
		return
	var stand_in := Node3D.new()
	stand_in.name = "DestroyingTower"
	stand_in.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().current_scene.add_child(stand_in)
	stand_in.global_transform = model.global_transform
	model.reparent(stand_in, true)
	if rubble != null:
		rubble.visible = false
	_swells.append({
		"stand_in": stand_in, "slot": slot, "rubble": rubble,
		"start": TimeManager.pausable_real_time,
		"base_y": stand_in.position.y, "base_scale": stand_in.scale,
	})


func _process(_delta: float) -> void:
	_update_particle_speed()
	var now := TimeManager.pausable_real_time
	for swell in _swells.duplicate():
		var t := clampf((now - float(swell.start)) / maxf(swell_time, 0.001), 0.0, 1.0)
		var stand_in := swell.stand_in as Node3D
		if is_instance_valid(stand_in):
			# It lifts only once the shrink is over.
			var lift_t := clampf((t - shrink_part) / maxf(1.0 - shrink_part, 0.001), 0.0, 1.0)
			stand_in.position.y = float(swell.base_y) + swell_lift * sin(lift_t * PI * 0.5)
			stand_in.scale = (swell.base_scale as Vector3) * _swell_size(t)
		if t < 1.0:
			continue
		_swells.erase(swell)
		if is_instance_valid(stand_in):
			stand_in.queue_free()
		var rubble := swell.rubble as Node3D
		if rubble != null and is_instance_valid(rubble):
			rubble.visible = true
		if is_instance_valid(swell.slot):
			_pop(swell.slot, rubble)


## Size over the swell (0 to 1): shrinks first, fills quickly, a short wobble, then the last
## push before the pop.
func _swell_size(t: float) -> Vector3:
	if t < shrink_part:
		return Vector3.ONE.lerp(shrink_scale, sin(t / maxf(shrink_part, 0.001) * PI * 0.5))
	# The rest of the swell, rescaled to 0..1.
	var u := (t - shrink_part) / maxf(1.0 - shrink_part, 0.001)
	var first := swell_scale.lerp(Vector3.ONE, 0.4)
	var wobble := swell_scale.lerp(Vector3.ONE, 0.55)
	if u < 0.45:
		return shrink_scale.lerp(first, sin(u / 0.45 * PI * 0.5))
	if u < 0.65:
		return first.lerp(wobble, (u - 0.45) / 0.2)
	var k := (u - 0.65) / 0.35
	return wobble.lerp(swell_scale, k * k)


func _pop(slot: Slot, rubble: Node3D) -> void:
	_spawn_burst(slot.global_position)
	if rubble != null and is_instance_valid(rubble):
		_drop(rubble)


## The node that draws the rubble: any child of Slot/Rubble other than its shape and obstacle.
func _rubble_visual(slot: Slot) -> Node3D:
	for child in slot.rubble.get_children():
		if child is Node3D and not child is CollisionShape3D and not child is NavigationObstacle3D:
			return child
	return null


func _spawn_burst(at: Vector3) -> void:
	var fx := BURST.instantiate() as Node3D
	get_tree().current_scene.add_child(fx)
	fx.global_position = at
	var left := 0
	for particles in fx.get_children():
		var p := particles as CPUParticles3D
		if p == null:
			continue
		p.speed_scale = _real_speed()
		p.emitting = true
		_particles.append(p)
		left += 1
		p.finished.connect(func() -> void:
			_particles.erase(p)
			left -= 1
			if left == 0:
				fx.queue_free())


## Particles run on game time; scaled back so a burst lasts the same at x2 and x3, also when
## the speed changes while it plays.
func _update_particle_speed() -> void:
	var speed := _real_speed()
	for p in _particles.duplicate():
		if not is_instance_valid(p):
			_particles.erase(p)
		elif not is_equal_approx(p.speed_scale, speed):
			p.speed_scale = speed


func _real_speed() -> float:
	return 1.0 / maxf(Engine.time_scale, 0.001)


func _drop(model: Node3D) -> void:
	# Rest pose saved once, so a drop that starts during an earlier one ends in the right place.
	if not model.has_meta(&"destroy_fx_rest"):
		model.set_meta(&"destroy_fx_rest", [model.position.y, model.scale])
	var rest: Array = model.get_meta(&"destroy_fx_rest")
	var base_y: float = rest[0]
	var base_scale: Vector3 = rest[1]
	if model.has_meta(&"destroy_fx_tween"):
		var old: Tween = model.get_meta(&"destroy_fx_tween")
		if old != null and old.is_valid():
			old.kill()
	model.position.y = base_y + drop_height
	model.scale = base_scale * start_scale
	var tw := model.create_tween().set_ignore_time_scale()
	model.set_meta(&"destroy_fx_tween", tw)
	tw.tween_property(model, "position:y", base_y, drop_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "scale", base_scale, drop_time)
	tw.tween_property(model, "scale", base_scale * land_squash, settle_time * 0.4)
	tw.tween_property(model, "scale", base_scale, settle_time * 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
