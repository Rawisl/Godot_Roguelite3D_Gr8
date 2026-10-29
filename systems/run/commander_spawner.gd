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
	if commander_scene == null or deploy_point == null:
		push_warning("CommanderSpawner: commander_scene or deploy_point is not set")
		return
	commander = commander_scene.instantiate() as Node3D
	# The commander reads its spawn position in _ready, so place it before add_child.
	commander.position = to_local(deploy_point.global_position)
	add_child(commander)
