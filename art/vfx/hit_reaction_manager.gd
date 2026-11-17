class_name HitReactionManager
extends Node
## Hit feedback without a global hit stop: when an enemy or the commander takes a hit,
## - its meshes flash white for flash_time (a white overlay material on each mesh),
## - only its own AnimationPlayer freezes for freeze_time, the rest of the game keeps running,
## - the hit sound plays (enemy_hit or commander_hit) through EventBus.sfx_requested.
## "Reduce flashing" (setting reduce_flash) turns the flash off; the freeze and sound stay.
## Whatever the setting, one entity flashes at most max_flashes_per_second times a second.
## Damage over time ticks get none of this, so a burning enemy does not blink.
## Entities are found the way DamageNumberLayer finds them: every HealthComponent whose parent
## is in the enemy or commander group. Nothing is added to the entity scenes.
## Timers run on TimeManager's pausable real time: the same length at x2 and x3, held on Pause.

@export var flash_material: Material = preload("res://art/materials/hit_flash.tres")
## Seconds the white flash stays on.
@export var flash_time := 0.1
## Seconds the entity's animation stops.
@export var freeze_time := 0.05
@export var max_flashes_per_second := 3.0
@export var enemy_sound: StringName = &"enemy_hit"
@export var commander_sound: StringName = &"commander_hit"

var _reduce_flash := false
## target -> {flash_until, freeze_until, last_flash, meshes, player, speed}
var _hits: Dictionary = {}
## Meshes whose overlay slot was taken by something else during a flash -> overlay before the flash.
var _handed_back: Dictionary = {}


func _ready() -> void:
	_reduce_flash = GameState.get_setting(&"reduce_flash", false) == true
	EventBus.settings_changed.connect(_on_settings_changed)
	get_tree().node_added.connect(_on_node_added)
	for health in get_tree().root.find_children("*", "HealthComponent", true, false):
		_on_node_added(health)


## True while target shows the white flash.
func is_flashing(target: Node3D) -> bool:
	return _hits.has(target) and _hits[target].flash_until > TimeManager.pausable_real_time


## True while target's own animation is stopped by a hit.
func is_frozen(target: Node3D) -> bool:
	return _hits.has(target) and _hits[target].freeze_until > TimeManager.pausable_real_time


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_reduce_flash = value == true
		if _reduce_flash:
			for target in _hits.keys():
				_set_flash(_hits[target], false)


func _on_node_added(node: Node) -> void:
	var health := node as HealthComponent
	if health == null:
		return
	var target := health.get_parent() as Node3D
	if target == null or not (target.is_in_group(&"enemy") or target.is_in_group(&"commander") or target is Enemy):
		return
	if not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged.bind(target))


func _on_damaged(amount: int, info: DamageInfo, target: Node3D) -> void:
	if amount <= 0 or not is_instance_valid(target) or (info != null and info.is_dot):
		return
	var now := TimeManager.pausable_real_time
	var hit: Dictionary = _hits.get(target, {})
	if hit.is_empty():
		hit = {"flash_until": 0.0, "freeze_until": 0.0, "last_flash": -INF, "flash_on": false, "before": {},
			"meshes": target.find_children("*", "GeometryInstance3D", true, false),
			"player": _player_of(target), "speed": 1.0}
		_hits[target] = hit
		target.tree_exiting.connect(_forget.bind(target), CONNECT_ONE_SHOT)
	var is_commander := target.is_in_group(&"commander")
	EventBus.sfx_requested.emit(commander_sound if is_commander else enemy_sound, target.global_position, -1)
	_freeze(hit, now)
	if not _reduce_flash and now - hit.last_flash >= 1.0 / maxf(max_flashes_per_second, 0.001):
		hit.last_flash = now
		hit.flash_until = now + flash_time
		_set_flash(hit, true)
	set_process(true)


func _freeze(hit: Dictionary, now: float) -> void:
	var player: AnimationPlayer = hit.player
	if not is_instance_valid(player):
		return
	if hit.freeze_until <= now:
		hit.speed = player.speed_scale
	hit.freeze_until = now + freeze_time
	player.speed_scale = 0.0


func _process(_delta: float) -> void:
	var now := TimeManager.pausable_real_time
	var busy := false
	for target in _hits:
		var hit: Dictionary = _hits[target]
		if hit.flash_on and hit.flash_until <= now:
			_set_flash(hit, false)
		if hit.freeze_until > 0.0 and hit.freeze_until <= now:
			hit.freeze_until = 0.0
			var player: AnimationPlayer = hit.player
			# Something else (a slow, the boss) may have set its own speed meanwhile: keep that.
			if is_instance_valid(player) and player.speed_scale == 0.0:
				player.speed_scale = hit.speed
		busy = busy or hit.flash_on or hit.freeze_until > 0.0
	_settle_handed_back()
	if not busy and _handed_back.is_empty():
		set_process(false)


## The overlay a mesh had (the hover outline) is put back when the flash ends.
## If something else took the overlay slot during the flash (an outline that keeps the flash as
## "the overlay before", to put back later), the mesh is watched until that happens and the flash
## is then swapped for what was there before it, so it never stays on.
func _set_flash(hit: Dictionary, on: bool) -> void:
	if hit.flash_on == on:
		return
	hit.flash_on = on
	if on:
		hit.before = {}
	for mesh in hit.meshes:
		if not is_instance_valid(mesh):
			continue
		var geometry := mesh as GeometryInstance3D
		if on:
			_handed_back.erase(geometry)
			hit.before[geometry] = geometry.material_overlay
			geometry.material_overlay = flash_material
		elif geometry.material_overlay == flash_material:
			geometry.material_overlay = hit.before.get(geometry)
		else:
			_handed_back[geometry] = hit.before.get(geometry)


func _settle_handed_back() -> void:
	for geometry in _handed_back.keys():
		if not is_instance_valid(geometry):
			_handed_back.erase(geometry)
		elif geometry.material_overlay == flash_material:
			geometry.material_overlay = _handed_back[geometry]
			_handed_back.erase(geometry)


func _forget(target: Node3D) -> void:
	_hits.erase(target)


## The player with the entity's clips: the enemy's own reference, then the commander's, then any.
func _player_of(target: Node3D) -> AnimationPlayer:
	for key in [&"anim_player", &"_anim_player"]:
		var player = target.get(key)
		if player is AnimationPlayer:
			return player
	var players := target.find_children("*", "AnimationPlayer", true, false)
	return players[0] as AnimationPlayer if not players.is_empty() else null
