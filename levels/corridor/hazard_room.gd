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
## Metres from the chase camera to its pivot above the commander at chase_far_pitch_deg.
@export var chase_distance: float = 9.0
## Metres from the chase camera to the pivot at the lowest pitch; the distance blends between
## the two with the pitch.
@export var chase_distance_near: float = 6.0
## Downward angle of the chase camera when entering the room, in degrees.
@export_range(-89.0, -5.0) var chase_pitch_deg: float = -45.0
## Highest and lowest angle the mouse can tilt the chase camera to, in degrees.
@export_range(-89.0, 60.0) var chase_pitch_max_deg: float = 30.0
@export_range(-89.0, -5.0) var chase_pitch_min_deg: float = -70.0
## Pitch at which the chase camera stands chase_distance away; it comes nearer below it
## (chase_distance_near at the lowest pitch) and above it (chase_distance_up at the highest).
@export_range(-89.0, 60.0) var chase_far_pitch_deg: float = -15.0
## Metres from the chase camera to the pivot at the highest pitch, before the floor pulls it in.
@export var chase_distance_up: float = 3.0
## Lowest the chase camera goes above the floor when it looks up, in metres.
@export var chase_min_height: float = 0.5
## Metres the chase camera stands to the right of the pivot, over the commander's shoulder.
@export var chase_shoulder_offset: float = 1.0
## Nearest zoom of the mouse wheel, as a share of the normal distance; the wheel never zooms
## out past the normal distance, so the corridor stays behind the sky.
@export_range(0.1, 1.0) var chase_zoom_min: float = 0.35
## Share of the normal distance one wheel notch zooms in or out.
@export var chase_zoom_step: float = 0.1
## Real seconds of smoothing of the wheel zoom.
@export var chase_zoom_smoothing: float = 0.08
## Degrees the chase camera looks above its pivot, so the commander stays this far below the
## middle of the screen and the middle points at the ground in front of the commander.
@export_range(0.0, 30.0) var chase_aim_tilt_deg: float = 10.0
## Vertical field of view of the chase camera, in degrees.
@export_range(20.0, 100.0) var chase_fov: float = 60.0
## Real seconds of smoothing of the chase follow.
@export var chase_smoothing: float = 0.12
## Height above the commander's feet of the point the chase camera orbits, in metres.
@export var chase_pivot_height: float = 1.4
## Far plane of the chase camera; has to reach past the sky sphere.
@export var chase_far: float = 1000.0

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
