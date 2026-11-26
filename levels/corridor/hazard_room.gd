class_name HazardRoom
extends Node3D
## Hazard Trial room: a round floating arena, far from the
## corridor so real wave units never reach it. Its navmesh is baked by the level's own regions,
## because the floor and walls sit in the nav_source group.
## - CommanderSpawn: the middle of the floor, where the commander appears.
## - EnemySpawns/S1..S5: round pads on the rim, on the arc at the top of the screen. S3 is the
##   larger pad and takes the boss on a boss wave.
## - CameraFrame: where the chase camera looks while there is no commander; camera_size is the
##   orthographic size kept on the corridor camera in the room.
## - SkySphere: the sky around the island (art/materials/hazard_sky.tres), a sphere of about
##   60 m that the shader keeps centred on the camera, so the corridor 85 m away stays hidden
##   behind it. Hidden outside the room; shown from hazard_trial_entered until
##   hazard_trial_exited, together with the lavender sun.
## The meshes come from hazard_room_builder.gd; run it again to change the shape.
## While the commander is inside (hazard_trial_entered until hazard_trial_exited) the sun turns
## lavender to match it, and goes back on the way out.

## Orthographic size kept on the corridor camera while the commander is in the room.
@export var camera_size: float = 31.0
## Index in get_enemy_spawns() of the larger pad that takes the boss.
@export var boss_spawn_index: int = 2

@export_group("Chase camera")
## Numbers of the chase camera in the room. start_yaw_deg is not used: the camera starts at the
## yaw of the corridor camera.
@export var chase_camera: ChaseCameraSettings = preload("res://data/config/hazard_chase_camera.tres")

@export_group("Ambience")
## The level's sun; without it the room keeps the level's light.
@export var sun: DirectionalLight3D
@export var sun_color := Color("#D9C2FF")
@export var sun_energy := 1.05
## Real seconds for the sun to change, the same as a camera frame change.
@export var fade_time := 0.5

var _inside := false
var _level_sun_color := Color.WHITE
var _level_sun_energy := 1.0
var _level_sun_known := false
var _tween: Tween

@onready var _commander_spawn: Marker3D = %CommanderSpawn
@onready var _enemy_spawns: Node3D = %EnemySpawns
@onready var _camera_frame: Marker3D = %CameraFrame
@onready var _sky: MeshInstance3D = %SkySphere


func _ready() -> void:
	add_to_group(&"hazard_room")
	EventBus.hazard_trial_entered.connect(_on_hazard_trial_entered)
	EventBus.hazard_trial_exited.connect(_on_hazard_trial_exited)
	_sky.visible = false
	_remember_level_sun()


func get_commander_spawn() -> Marker3D:
	return _commander_spawn


## Spawn markers in order S1..S5, each facing the middle of the room.
func get_enemy_spawns() -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for child in _enemy_spawns.get_children():
		if child is Marker3D:
			result.append(child)
	return result


## The larger pad that takes the boss, or null when the room has no spawn markers.
func get_boss_spawn() -> Marker3D:
	var spawns := get_enemy_spawns()
	if spawns.is_empty():
		return null
	return spawns[clampi(boss_spawn_index, 0, spawns.size() - 1)]


## Ground point the chase camera looks at while there is no commander.
func get_camera_focus() -> Vector3:
	return _camera_frame.global_position


## Profile for the reusable chase orbit, from the room's chase camera resource.
func get_chase_settings() -> Dictionary:
	if chase_camera == null:
		return ChaseCameraSettings.new().get_orbit_settings()
	return chase_camera.get_orbit_settings()


## True while the room light is on.
func is_ambience_on() -> bool:
	return _inside


func _on_hazard_trial_entered(_wave_index: int, _enemy_types: Array) -> void:
	if _inside:
		return
	_inside = true
	_sky.visible = true
	# The level's own light is read once, never in the middle of a fade back.
	_remember_level_sun()
	_fade_sun(sun_color, sun_energy)


func _on_hazard_trial_exited(_result: StringName, _kills: int, _gold: int, _xp: float, _mithril: int) -> void:
	if not _inside:
		return
	_inside = false
	_sky.visible = false
	if _level_sun_known:
		_fade_sun(_level_sun_color, _level_sun_energy)


func _remember_level_sun() -> void:
	if _level_sun_known or not is_instance_valid(sun):
		return
	_level_sun_color = sun.light_color
	_level_sun_energy = sun.light_energy
	_level_sun_known = true


func _fade_sun(color: Color, energy: float) -> void:
	if not is_instance_valid(sun):
		return
	if _tween != null:
		_tween.kill()
	# Real time: the change looks the same at x1, x2 and x3.
	_tween = create_tween().set_parallel().set_ignore_time_scale()
	_tween.tween_property(sun, "light_color", color, fade_time)
	_tween.tween_property(sun, "light_energy", energy, fade_time)
