class_name ProjectilePool
extends Node3D

var _free: Dictionary = {}
var _active: Array[Projectile] = []

func _ready() -> void:
	add_to_group(&"projectile_pool")
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.run_ended.connect(_on_run_ended)

func can_acquire() -> bool:
	return _active.size() < GameConfig.max_projectiles

func active_count() -> int:
	return _active.size()

func acquire(scene: PackedScene) -> Projectile:
	if scene == null or not can_acquire():
		return null
	var key := scene.resource_path
	var list: Array = _free.get(key, [])
	var p: Projectile = null
	if list.is_empty():
		p = scene.instantiate() as Projectile
		if p == null:
			push_error("ProjectilePool: scene %s is not a Projectile" % key)
			return null
		p.pool_key = key
		p.released.connect(_on_released)
		add_child(p)
	else:
		p = list.pop_back()
	p.in_use = true
	p.visible = true
	p.set_physics_process(true)
	p.set_deferred(&"monitoring", true)
	_active.append(p)
	return p

## PRJ-06: clear every projectile in flight.
func release_all() -> void:
	for p in _active.duplicate():
		p.release()

func _on_released(p: Projectile) -> void:
	_active.erase(p)
	p.in_use = false
	p.target = null
	p.visible = false
	p.set_physics_process(false)
	p.set_deferred(&"monitoring", false)
	if not _free.has(p.pool_key):
		_free[p.pool_key] = []
	_free[p.pool_key].append(p)

## PRJ-06: SUMMARY ends when the next PREP starts
func _on_state_changed(new_state: StringName) -> void:
	if new_state == &"PREP":
		release_all()

func _on_run_ended(_end_type: StringName, _summary: Dictionary) -> void:
	release_all()
