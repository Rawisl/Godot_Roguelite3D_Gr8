class_name HitFxManager
extends Node
## Plays hit and firing effects in the level from pooled instances:
## - melee hits: the commander's sword on enemies, enemies on the commander or a structure
## - tower arrows hitting enemies, cannon shells exploding
## - enemy arrows hitting the commander or a structure
## - the muzzle flash when a tower releases a shot
## Picks up health components, cannon shells and towers as they enter the tree, so no other
## system has to call it. Effects run on game time, like the particles inside them.

const SWORD_HIT := preload("res://art/vfx/sword_hit.tscn")
const ARROW_HIT := preload("res://art/vfx/arrow_hit.tscn")
const CANNON_BLAST := preload("res://art/vfx/cannon_blast.tscn")
const MUZZLE := preload("res://art/vfx/muzzle_flash.tscn")

@export_group("Styles")
## Every melee hit, from the commander or from enemies, uses this one slash.
@export var slash: SwordHitStyle = preload("res://art/vfx/styles/slash.tres")
@export var arrow_muzzle: MuzzleStyle = preload("res://art/vfx/styles/arrow_muzzle.tres")
@export var cannon_muzzle: MuzzleStyle = preload("res://art/vfx/styles/cannon_muzzle.tres")
## Enemy arrows reuse the arrow hit in the enemy colours.
@export var enemy_arrow_ring := Color("#FFFFFF")
@export var enemy_arrow_spark_start := Color("#FFFFFF")
@export var enemy_arrow_spark_end := Color("#FFFFFF")

@export_group("Pools")
@export var sword_pool := 16
@export var arrow_pool := 24
@export var blast_pool := 8
@export var muzzle_pool := 16

@export_group("Budget")
## Particle cap for the current graphics preset (Low 500, Medium 1500, High 3000).
## Over it, muzzle flashes and arrow hits are skipped first; cannon blasts always play.
@export var particle_budget := 1500
## Height above a unit's origin where its hits show.
@export var hit_height := 1.0
## How far the hit is pulled from the unit's centre toward the attacker, so it shows on
## the near side of the model instead of inside it.
@export var hit_offset := 0.35

var _pools: Dictionary = {}  # PackedScene -> Array[Node3D]
var _next: Dictionary = {}  # PackedScene -> next index to reuse when all are busy
var _enemy_arrows: Array[Node3D] = []


func _ready() -> void:
	for pair in [[SWORD_HIT, sword_pool], [ARROW_HIT, arrow_pool], [CANNON_BLAST, blast_pool], [MUZZLE, muzzle_pool]]:
		_fill(pair[0], pair[1])
	for i in maxi(arrow_pool / 3, 1):
		var hit: ArrowHit = ARROW_HIT.instantiate()
		hit.ring_color = enemy_arrow_ring
		hit.spark_color_start = enemy_arrow_spark_start
		hit.spark_color_end = enemy_arrow_spark_end
		add_child(hit)
		_enemy_arrows.append(hit)
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)


func _fill(scene: PackedScene, count: int) -> void:
	var list: Array[Node3D] = []
	for i in maxi(count, 1):
		var fx: Node3D = scene.instantiate()
		add_child(fx)
		list.append(fx)
	_pools[scene] = list
	_next[scene] = 0


func _on_node_added(node: Node) -> void:
	if node is HealthComponent:
		var health := node as HealthComponent
		var owner_node := health.get_parent() as Node3D
		if owner_node != null and not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged.bind(owner_node))
	elif node is CannonProjectile:
		var shell := node as CannonProjectile
		if not shell.exploded.is_connected(_on_exploded):
			shell.exploded.connect(_on_exploded.bind(shell))
	elif node is Tower:
		var tower := node as Tower
		if not tower.shot_started.is_connected(_on_shot_started):
			tower.shot_started.connect(_on_shot_started.bind(tower))


func _on_damaged(_amount: int, info: DamageInfo, target: Node3D) -> void:
	if info == null or not is_instance_valid(target):
		return
	var source := info.source
	var point := target.global_position + Vector3.UP * hit_height
	var dir := info.hit_direction
	if dir.length_squared() < 0.0001 and source is Node3D:
		dir = target.global_position - (source as Node3D).global_position
	if dir.length_squared() > 0.0001:
		point -= Vector3(dir.x, 0.0, dir.z).normalized() * hit_offset
	var on_enemy := target.is_in_group(&"enemy")

	if on_enemy and source != null and source.is_in_group(&"commander"):
		play_sword(point, dir, slash, target.global_position.y)
	elif on_enemy and source is Tower and info.damage_type == Enums.DamageType.PIERCE:
		play_arrow(point, dir)
	elif not on_enemy and source is Archer:
		play_arrow(point, dir, true)
	elif not on_enemy and source is Enemy:
		play_sword(point, dir, slash, target.global_position.y)


func _on_exploded(center: Vector3, radius: float, _hits: int, shell: CannonProjectile) -> void:
	var dir := -shell.global_basis.z if is_instance_valid(shell) else Vector3.DOWN
	play_blast(center, dir, radius)


## Waits for the tower's release delay so the flash shows when the shot leaves.
func _on_shot_started(target: Node3D, tower: Tower) -> void:
	var delay: float = tower.data.release_delay if tower.data != null else 0.0
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(tower):
		return
	var muzzle: Node3D = tower.get("_muzzle_node")
	if muzzle == null:
		muzzle = tower.muzzle
	var aim := (target.global_position - muzzle.global_position) if is_instance_valid(target) else -tower.global_basis.z
	var is_cannon := tower.data != null and tower.data.damage_type == Enums.DamageType.BLAST
	play_muzzle(muzzle.global_position, aim, cannon_muzzle if is_cannon else arrow_muzzle)


func play_sword(point: Vector3, dir: Vector3, style: SwordHitStyle, ground_y := 0.0) -> void:
	var cost := style.spark_count + (style.dust_count if style.dust_enabled else 0)
	var fx := _take(SWORD_HIT, cost, false) as SwordHit
	if fx != null:
		fx.play(point, dir, style, ground_y)


func play_arrow(point: Vector3, dir: Vector3, enemy := false) -> void:
	var fx: ArrowHit
	if enemy:
		fx = _oldest_free(_enemy_arrows) as ArrowHit
		if not _fits(fx.spark_count, true):
			return
	else:
		var sample: ArrowHit = _pools[ARROW_HIT][0]
		fx = _take(ARROW_HIT, sample.spark_count, true) as ArrowHit
	if fx != null:
		fx.set_meta(&"cost", fx.spark_count)
		fx.play(point, dir)


func play_blast(center: Vector3, dir: Vector3, radius: float) -> void:
	var fx := _take(CANNON_BLAST, 10, false) as CannonBlast
	if fx != null:
		fx.play(center, dir, radius)


func play_muzzle(point: Vector3, dir: Vector3, style: MuzzleStyle) -> void:
	var fx := _take(MUZZLE, style.puff_count, true) as MuzzleFlash
	if fx != null:
		fx.play(point, dir, style)


## Particles of every effect still playing.
func active_particles() -> int:
	var total := 0
	for list in _pools.values():
		for fx in list:
			if fx.is_playing():
				total += int(fx.get_meta(&"cost", 0))
	for fx in _enemy_arrows:
		if fx.is_playing():
			total += int(fx.get_meta(&"cost", 0))
	return total


func _fits(cost: int, secondary: bool) -> bool:
	return not secondary or active_particles() + cost <= particle_budget


## A free instance from the pool, or the next one in turn when all are busy.
## Secondary effects are skipped when the particle budget is full.
func _take(scene: PackedScene, cost: int, secondary: bool) -> Node3D:
	if not _fits(cost, secondary):
		return null
	var list: Array = _pools[scene]
	var fx: Node3D = null
	for candidate in list:
		if not candidate.is_playing():
			fx = candidate
			break
	if fx == null:
		var i: int = _next[scene]
		fx = list[i]
		_next[scene] = (i + 1) % list.size()
	fx.set_meta(&"cost", cost)
	return fx


func _oldest_free(list: Array[Node3D]) -> Node3D:
	for fx in list:
		if not fx.is_playing():
			return fx
	return list[0]
