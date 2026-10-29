class_name CommanderSpawner
extends Node3D
## Puts the commander into the run at the level's deploy point when the scene starts.
## The commander finds its camera, HUD and aura by the "commander" group, so nothing
## else has to be wired here.

@export var commander_scene: PackedScene = preload("res://entities/commander/commander.tscn")
## Marker the commander starts on. The commander also remembers this spot as its spawn position.
@export var deploy_point: Marker3D

var commander: Node3D


func _ready() -> void:
	# TODO(week 10): move the spawn into RunState / RunLoading so the commander is placed when the run starts, then remove this node from main.tscn.
	# The exported path can be broken (level loaded differently), so look the marker up by name.
	if deploy_point == null:
		var scene := get_tree().current_scene
		deploy_point = scene.find_child("DeployPoint", true, false) as Marker3D if scene != null else null
	if commander_scene == null or deploy_point == null:
		push_warning("CommanderSpawner: commander_scene is not set or no DeployPoint marker was found")
		return
	commander = commander_scene.instantiate() as Node3D
	# The commander reads its spawn position in _ready, so place it before add_child.
	commander.position = to_local(deploy_point.global_position)
	add_child(commander)
	# Face the way the marker points (-Z) so the commander starts looking down the corridor.
	commander.call(&"face_toward", -deploy_point.global_basis.z)
