class_name ChaseCameraSettings
extends Resource
## Numbers of the third-person camera the player turns on in the corridor. Same meaning and
## defaults as the "Chase camera" group of the Hazard Trial room; CameraRig reads them each time
## it switches the view on.

## Metres from the camera to its pivot above the commander at far_pitch_deg.
@export var distance: float = 9.0
## Metres from the camera to the pivot at the lowest pitch; the distance blends between the two
## with the pitch.
@export var distance_near: float = 6.0
## Downward angle of the camera when the view starts, in degrees.
@export_range(-89.0, -5.0) var pitch_deg: float = -45.0
## Highest and lowest angle the mouse can tilt the camera to, in degrees.
@export_range(-89.0, 60.0) var pitch_max_deg: float = 30.0
@export_range(-89.0, -5.0) var pitch_min_deg: float = -70.0
## Pitch at which the camera stands distance away; it comes nearer below it (distance_near at the
## lowest pitch) and above it (distance_up at the highest).
@export_range(-89.0, 60.0) var far_pitch_deg: float = -15.0
## Metres from the camera to the pivot at the highest pitch, before the floor pulls it in.
@export var distance_up: float = 3.0
## Lowest the camera goes above the floor when it looks up, in metres.
@export var min_height: float = 0.5
## Metres the camera stands to the right of the pivot, over the commander's shoulder.
@export var shoulder_offset: float = 1.0
## Nearest zoom of the mouse wheel, as a share of the normal distance.
@export_range(0.1, 1.0) var zoom_min: float = 0.35
## Share of the normal distance one wheel notch zooms in or out.
@export var zoom_step: float = 0.1
## Real seconds of smoothing of the wheel zoom.
@export var zoom_smoothing: float = 0.08
## Degrees the camera looks above its pivot, so the commander stays this far below the middle of
## the screen and the middle points at the ground in front of the commander.
@export_range(0.0, 30.0) var aim_tilt_deg: float = 10.0
## Vertical field of view, in degrees.
@export_range(20.0, 100.0) var fov: float = 60.0
## Real seconds of smoothing of the follow.
@export var smoothing: float = 0.12
## Height above the commander's feet of the point the camera orbits, in metres.
@export var pivot_height: float = 1.4
## Far plane of the camera.
@export var far: float = 1000.0
## Physics layers the camera cannot pass through: 1 world and 4 structure.
@export_flags_3d_physics var collision_mask: int = 9
## Radius of the sphere that checks for walls on the way to the camera, in metres.
@export var probe_radius: float = 0.3
## The camera never comes nearer to the pivot than this, in metres.
@export var min_distance: float = 1.0
## Real seconds the camera takes to ease back out after a wall stops blocking it.
@export var return_time: float = 0.25
## Real seconds the way has to stay clear before the camera starts to ease back out, so a wall edge
## does not make it flicker.
@export var release_delay: float = 0.15
## The way has to get clearer than this share of the way before the camera counts the wall as
## gone; smaller changes leave it where it is.
@export var release_margin: float = 0.01
## How far the commander may stand from the middle of the screen toward the left edge, as a share
## of that half width. A camera pulled in by a wall narrows its shoulder offset to stay inside it.
@export_range(0.0, 1.0) var max_screen_offset: float = 0.6
## A commander move bigger than this in one physics tick (Recall, Deploy, a respawn) cuts the
## camera onto it at once instead of following, in metres.
@export var teleport_snap_distance: float = 3.0
## The commander fades out with a dither while the camera is nearer to it than fade_start_distance
## (metres from camera to pivot), down to fade_min_alpha at fade_end_distance, so it does not fill
## the screen when a wall pulls the camera in.
@export var fade_start_distance: float = 2.0
@export var fade_end_distance: float = 1.0
## Nearer than this the commander is hidden completely; between this and fade_end_distance it goes
## from fade_min_alpha down to nothing.
@export var fade_hide_distance: float = 0.6
@export_range(0.0, 1.0) var fade_min_alpha: float = 0.3
## Real seconds from fully visible to hidden.
@export var fade_time: float = 0.15
## World yaw when the view starts, in degrees. -90 looks along the corridor toward +X, the way
## the enemies come.
@export_range(-180.0, 180.0) var start_yaw_deg: float = -90.0


## Profile for ChaseCameraOrbit.configure, with the keys HazardRoom.get_chase_settings uses.
func get_orbit_settings() -> Dictionary:
	return {
		"pitch": pitch_deg, "pitch_min": pitch_min_deg,
		"pitch_max": pitch_max_deg, "far_pitch": far_pitch_deg,
		"distance": distance, "distance_near": distance_near,
		"distance_up": distance_up, "pivot_height": pivot_height,
		"min_height": min_height, "shoulder": shoulder_offset,
		"aim_tilt": aim_tilt_deg, "follow_smoothing": smoothing,
		"zoom_min": zoom_min, "zoom_step": zoom_step,
		"zoom_smoothing": zoom_smoothing, "fov": fov, "far": far,
		"collision_mask": collision_mask, "probe_radius": probe_radius,
		"min_distance": min_distance, "return_time": return_time,
		"release_delay": release_delay, "release_margin": release_margin, "max_screen_offset": max_screen_offset,
		"teleport_snap_distance": teleport_snap_distance,
		"fade_hide_distance": fade_hide_distance,
		"fade_start_distance": fade_start_distance, "fade_end_distance": fade_end_distance,
		"fade_min_alpha": fade_min_alpha, "fade_time": fade_time
	}
