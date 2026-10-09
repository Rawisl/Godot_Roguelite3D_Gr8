class_name TowerModel
extends Node3D



@export var aim_node_name: StringName = &"Arrow"
## Projectile spawn point
@export var muzzle_node_name: StringName = &"Muzzle"
@export var shoot_anim: StringName = &"shoot"

var _tower: Tower = null
var _player: AnimationPlayer = null

# Runs before the Tower's _ready (children first)
func _ready() -> void:
	_tower = _find_tower()
	if _tower == null:
		push_warning("TowerModel: no Tower above %s" % name)
		return
	_tower.set_visuals(_find_named(aim_node_name), _find_named(muzzle_node_name))
	if shoot_anim == &"":
		return
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player == null or not _player.has_animation(shoot_anim):
		push_warning("TowerModel: %s has no '%s' animation" % [name, shoot_anim])
		_player = null
		return
	_tower.shot_started.connect(_on_shot_started)

func _find_tower() -> Tower:
	var n := get_parent()
	while n != null and not n is Tower:
		n = n.get_parent()
	return n as Tower

func _find_named(node_name: StringName) -> Node3D:
	if node_name == &"":
		return null
	var n := find_child(String(node_name), true, false) as Node3D
	if n == null:
		push_warning("TowerModel: node '%s' not found in %s" % [node_name, name])
	return n

func _on_shot_started(_target: Node3D) -> void:
	if _tower.data == null:
		return
	var lv: TowerLevelData = _tower.data.levels[_tower.level - 1]
	var anim_len := _player.get_animation(shoot_anim).length
	# Speed the animation up if the tower fires faster .
	_player.play(shoot_anim, -1.0, maxf(1.0, anim_len * lv.fire_rate))
	# play() ignores a call while the same animation is still running; restart it.
	_player.seek(0.0, true)
