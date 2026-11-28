extends Node3D
## Tavern room behind the main menu. The fox commander sits on a barrel and swings his legs.
## leave() plays the exit: he pushes off the barrel with his left hand, lands beside it, grabs
## the sword leaning on the bar with his left paw and drags it, tip scraping the floor, to the
## double door. Once his whole head is on screen the camera rises and keeps him in view.
## The door opens onto white light, he steps through and glances back over his right shoulder,
## the camera rushes in to catch his face and the screen fades to white. Then left_room is emitted.

signal left_room

const ENV_DIR := "res://contents/assets/environment/menu_room/"
## Room materials by the material name exported from Blender.
const MATERIALS := {
	"BO_Floor": "mat_floor", "BO_Wall": "mat_wall", "BO_Roof": "mat_roof",
	"BO_Beam": "mat_wood", "BO_Bar": "mat_wood", "BO_Barrel": "mat_wood",
	"BO_DoorFrame": "mat_wood", "BO_DoorPlank": "mat_wood",
	"BO_Iron": "mat_iron", "BO_Chandelier": "mat_chandelier", "BO_WindowGlass": "mat_window_glass",
	"BO_Paper": "mat_paper", "BO_Pin": "mat_pin", "BO_Flame": "mat_flame", "BO_Gold": "mat_gold",
}
## The floor the fox lands on after jumping off the barrel.
const FLOOR_Y := 0.0
## Where the jump animation sets the fox down, measured from where he sat. The barrel is taller
## than the one the animation was made for, so the rest of the drop is added while he jumps.
const JUMP_DROP := 0.555
## Size of the sword model in the room, and how far its tip is from the grip at that size.
const SWORD_SCALE := 0.67
const SWORD_LENGTH := 1.31
## Top of the hat above the head bone, before the fox's scale is applied.
const HEAD_TOP := 0.6
## Eye position from the head bone: up, towards the face, and to the side.
const EYE_UP := 0.28
const EYE_FORWARD := 0.24
const EYE_SIDE := 0.17

@export_group("Walk")
## Playback speed of the jump off the barrel. Above 1 is quicker.
@export var jump_speed := 1.5
@export var walk_speed := 2.0
## How fast the fox turns towards the next point, in radians per second.
@export var turn_speed := 2.0
@export_group("Camera")
## Wait after the fox starts walking before the camera lifts off.
@export var rise_delay := 1.6
## How long the camera takes to settle in behind the fox. It starts slowly and speeds up.
@export var rise_time := 2.0
## Camera spot while following, in metres: behind the fox, off to his right, and above the floor.
## It keeps the fox at about the size he is when he lands.
@export var follow_back := 4.6
@export var follow_side := 2.0
@export var follow_height := 2.6
## Where the camera looks: this far ahead of the fox and this high, so it looks down and across
## to the left.
@export var look_ahead := 1.8
@export var look_height := 1.5
@export var follow_smoothing := 3.0
@export_group("Sword")
@export var grab_time := 0.2
## How long the grip takes to come down from the bar to the paw's carrying spot.
@export var carry_time := 0.6
## How sharp the first turn after the grab has to be, in radians still to go, for him to lift the
## sword. He lifts it once only.
@export var lift_turn_angle := 0.35
@export var lift_speed := 1.5
@export_group("Paws")
## Near the door the right paw gives the backside a quick scratch.
@export var scratch_distance := 4.5
@export var scratch_time := 1.2
@export var scratch_speed := 3.0
@export var dust_color := Color(0.62, 0.52, 0.4, 0.5)
@export_group("Coin")
## Passing the CoinFlip marker the fox, still walking, looks at the chest, takes a coin from his
## pocket and flicks it onto the coins on the floor in front of the chest.
@export var coin_look_time := 0.4
@export var coin_pocket_time := 0.45
@export var coin_raise_time := 0.4
@export var coin_flight_time := 0.8
@export var coin_arc_height := 1.4
@export var coin_spins := 5.0
@export_group("Lights")
## How much the lights in the "flicker" group waver, as a share of their brightness.
@export var flicker_amount := 0.18
@export var flicker_speed := 6.0
## Torches waver more than the hanging lamps.
@export var torch_flicker_amount := 0.35
@export_group("Door Light")
## Light through the doorway once the leaves are open.
@export var door_sun_open := 12.0
@export var door_glow_open := 0.3
@export var door_glare_open := 0.5
@export var door_beam_open := 0.35
## Peak values while the camera rushes in and the screen turns white.
@export var door_sun_peak := 24.0
@export var door_glow_peak := 1.5
@export var door_glare_peak := 1.5
@export var white_out_exposure := 4.0
@export_group("Door")
## The leaves open outwards, away from the fox standing right at the door.
@export var door_open_degrees := 100.0
## Before bursting open the leaves give a little, as if pressed against a spring.
@export var door_squeeze_degrees := 4.0
@export var door_squeeze_time := 0.18
@export var door_open_time := 0.45
## How far the brim of the hat sticks out in front of the fox, in metres. The door is well open
## before that reaches the leaves.
@export var fox_front_reach := 0.8
@export var door_clearance := 0.25
## How long the glance back over the shoulder takes. It starts once the camera begins to fly in.
@export var glance_time := 0.6
@export var glance_delay := 0.05
## How far the head turns back over the right shoulder, in degrees. The upper body turns a third
## of that.
@export var glance_degrees := 95.0
## Camera rush towards the fox's face and fade to white, in seconds.
@export var rush_time := 1.1
## How close to the eye the rush ends, in metres.
@export var rush_end_distance := 0.12

var _leaving := false
var _tracking := false
var _rushing := false
var _door_opened := false
var _glance := 0.0
## Grows from 0 to 1 while the camera rises, so it starts turning gently instead of snapping.
var _track_weight := 0.0
var _flicker_noise := FastNoiseLite.new()
var _flicker_lights: Array[OmniLight3D] = []
var _flicker_base: Array[float] = []
var _flames: Array[Node3D] = []
var _time := 0.0
var _sword: MeshInstance3D
var _grab_weight := 0.0
var _carry_blend := 0.0
var _dragging := false
var _tip := Vector3.ZERO
## Dust puffs are plain quads made one by one: CPUParticles3D in the Compatibility renderer
## leaves unspawned particles drawn as squares at the emitter.
var _dust_mesh: QuadMesh
var _dust_wait := 0.0
## Hips position under the root bone while sitting, so the grip can bob with the hips.
var _hips_sit := Vector3.ZERO
## After the jump the root bone stays where it is at rest; the walk has no root track to reset it.
var _root_baked := false
## 0 while dragging, 1 while the sword is held straight up during a turn.
var _upright := 0.0
var _upright_target := 0.0
## The sword is lifted only for the first turn after the grab; later turns keep dragging it.
var _lift_done := false
## Head turn towards the chest during the coin flick, 0 to 1.
var _look_chest := 0.0
## Right paw: 0 at rest, 1 on its target, which moves from the pocket up to the flick spot.
var _coin_hand := 0.0
var _coin_hand_raise := 0.0
var _coin: MeshInstance3D
var _coin_in_hand := false
## Barrels on the floor as (centre x, centre z, radius), so the dragged tip slides round them.
var _barrels: Array[Vector3] = []
var _scratch_weight := 0.0
var _scratched := false

@onready var _room: Node3D = $Room
@onready var _fox: Node3D = $Fox
@onready var _anim: AnimationPlayer = _fox.find_child("FoxAnimationPlayer", true, false)
@onready var _skeleton: Skeleton3D = _fox.find_child("Skeleton3D", true, false)
@onready var _camera: Camera3D = _room.find_child("Camera", true, false)
@onready var _door_l: Node3D = _room.find_child("DoorHinge_L", true, false)
@onready var _door_r: Node3D = _room.find_child("DoorHinge_R", true, false)
@onready var _door_glow: OmniLight3D = %DoorGlow
## Daylight through the doorway, so the floor just inside the door lights up in its shape.
@onready var _door_sun: SpotLight3D = %DoorSun
## A copy of the scene's Environment, so raising the exposure for the white-out never leaks into
## the next time the room is loaded.
@onready var _env: Environment = ($WorldEnvironment as WorldEnvironment).environment.duplicate()
@onready var _white: ColorRect = %White
@onready var _glare: ShaderMaterial = ($DoorGlare as MeshInstance3D).material_override
@onready var _door_beam: ShaderMaterial = ($DoorBeam as MeshInstance3D).material_override
## Positions you can drag in the editor. World ones sit under Markers; the ones under Fox move
## with him and are measured in his own frame.
@onready var _sword_lean_grip: Marker3D = %SwordLeanGrip
@onready var _sword_lean_tip: Marker3D = %SwordLeanTip
@onready var _coin_landing: Marker3D = %CoinLanding
@onready var _walk_path: Node3D = %WalkPath
@onready var _hip_marker: Marker3D = %HipGrip
@onready var _upright_marker: Marker3D = %UprightGrip
@onready var _butt_marker: Marker3D = %ButtScratch
@onready var _pocket_marker: Marker3D = %PocketRight
@onready var _flick_marker: Marker3D = %FlickHand


func _ready() -> void:
	($WorldEnvironment as WorldEnvironment).environment = _env
	_apply_materials(_room)
	_camera.current = true
	_door_glow.light_energy = 0.0
	_door_sun.light_energy = 0.0
	_white.color.a = 0.0
	_glare.set_shader_parameter(&"strength", 0.0)
	_door_beam.set_shader_parameter(&"intensity", 0.0)
	_anim.play(&"menu/Sit_Swing")
	_anim.advance(0.0)
	_make_sword()
	_make_dust()
	_hips_sit = _skeleton.get_bone_pose_position(_skeleton.find_bone(&"hips"))
	for barrel in _room.find_children("Barrel_Seat_*", "MeshInstance3D", true, false):
		var box: AABB = (barrel as MeshInstance3D).global_transform * (barrel as MeshInstance3D).get_aabb()
		var centre := box.get_center()
		_barrels.append(Vector3(centre.x, centre.z, maxf(box.size.x, box.size.z) * 0.5))
	_add_glance()
	_setup_flicker()


func _unhandled_input(event: InputEvent) -> void:
	# F6 on this scene: Enter makes the fox leave.
	if event.is_action_pressed(&"ui_accept") and get_tree().current_scene == self:
		leave()


func _process(delta: float) -> void:
	_flicker(delta)
	if not _tracking:
		return
	var t := (1.0 - exp(-follow_smoothing * delta)) * _track_weight
	_camera.global_transform = _camera.global_transform.interpolate_with(_follow_transform(), t)


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	_anim.play(&"menu/Sit_JumpDown", 0.2, jump_speed)
	var jump_time := _anim.current_animation_length / jump_speed
	var extra_drop := _fox.global_position.y - JUMP_DROP - FLOOR_Y
	if extra_drop > 0.0:
		var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_interval(jump_time * 0.35)
		fall.tween_property(_fox, "global_position:y", _fox.global_position.y - extra_drop, jump_time * 0.4)
	await _anim.animation_finished
	_bake_root_motion()
	_anim.play(&"general/Idle_A", 0.15)
	var grab := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	grab.tween_property(self, "_grab_weight", 1.0, grab_time)
	await grab.finished
	_tip = _sword_lean_tip.global_position
	_dragging = true
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT) 			.tween_property(self, "_carry_blend", 1.0, carry_time)
	_anim.play(&"move/Fox_Walk", 0.2)
	_start_follow()
	var points := _walk_path.get_children()
	for i in points.size():
		var marker := points[i] as Node3D
		await _walk_to(marker.global_position, i == points.size() - 1)
		if marker.name == &"CoinFlip":
			_flick_coin()
	_anim.play(&"general/Idle_A", 0.3)
	get_tree().create_timer(glance_delay).timeout.connect(_glance_back)
	await _rush_to_face()
	left_room.emit()


## Lamps and torches waver on their own noise, each at its own offset so they never pulse together.
func _setup_flicker() -> void:
	_flicker_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_flicker_noise.frequency = 1.0
	for node in get_tree().get_nodes_in_group(&"flicker"):
		if node is OmniLight3D and is_ancestor_of(node):
			_flicker_lights.append(node)
			_flicker_base.append((node as OmniLight3D).light_energy)
	for node in _room.find_children("Torch*_Flame*", "Node3D", true, false):
		_flames.append(node)


func _flicker(delta: float) -> void:
	_time += delta * flicker_speed
	for i in _flicker_lights.size():
		var light := _flicker_lights[i]
		var amount := torch_flicker_amount if String(light.name).begins_with("Torch") else flicker_amount
		light.light_energy = _flicker_base[i] * (1.0 + amount * _flicker_noise.get_noise_1d(_time + i * 37.0))
	for i in _flames.size():
		var wobble := 1.0 + 0.2 * _flicker_noise.get_noise_1d(_time * 1.3 + 200.0 + i * 53.0)
		_flames[i].scale = Vector3(wobble, 1.0 + (wobble - 1.0) * 1.6, wobble)


func _apply_materials(node: Node) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src and MATERIALS.has(src.resource_name):
				mi.set_surface_override_material(i, load(ENV_DIR + MATERIALS[src.resource_name] + ".tres"))


## The fox's own sword stays hidden in his paw; this copy leans on the bar until he grabs it.
func _make_sword() -> void:
	var sword := _fox.find_child("FoxSword", true, false) as MeshInstance3D
	if sword == null:
		return
	_sword = MeshInstance3D.new()
	_sword.mesh = sword.mesh
	_sword.material_override = sword.material_override
	add_child(_sword)
	sword.visible = false
	_place_sword(_sword_lean_grip.global_position, _sword_lean_tip.global_position)
	_make_coin()


## Grip at one end, tip at the other, edge kept upright.
## The flat of the blade faces the fox's sides, the way it hung on his hip.
func _place_sword(grip: Vector3, tip: Vector3) -> void:
	var along := (tip - grip).normalized()
	var side := _fox.global_basis.x.normalized()
	var face := side - along * side.dot(along)
	if face.length() < 0.01:
		face = _fox.global_basis.z.normalized() - along * _fox.global_basis.z.normalized().dot(along)
	face = face.normalized()
	var across := along.cross(face)
	_sword.global_transform = Transform3D(Basis(across, along, face).scaled(Vector3.ONE * SWORD_SCALE), grip)


## Dust kicked up where the tip scrapes the floor.
func _make_dust() -> void:
	_dust_mesh = QuadMesh.new()
	_dust_mesh.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = dust_color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_dust_mesh.material = mat


## One puff: rises a little, drifts, shrinks away and frees itself.
func _puff(at: Vector3) -> void:
	var puff := MeshInstance3D.new()
	puff.mesh = _dust_mesh
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puff)
	puff.global_position = at + Vector3(randf_range(-0.05, 0.05), 0.02, randf_range(-0.05, 0.05))
	var size := randf_range(0.6, 1.4)
	puff.scale = Vector3.ONE * size
	var life := randf_range(0.6, 0.9)
	var drift := Vector3(randf_range(-0.15, 0.15), randf_range(0.15, 0.35), randf_range(-0.15, 0.15))
	var tween := puff.create_tween().set_parallel()
	tween.tween_property(puff, "global_position", puff.global_position + drift, life).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector3.ZERO, life).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(puff.queue_free)


## The glance back is added on top of whatever animation is playing.
func _add_glance() -> void:
	_anim.mixer_applied.connect(_apply_glance)


func _apply_glance() -> void:
	if _look_chest > 0.0:
		var to_chest := _coin_landing.global_position - _fox.global_position
		var forward := _fox.global_basis.z
		var angle := clampf(atan2(forward.cross(to_chest).y, forward.dot(to_chest)), -1.4, 1.4) * _look_chest
		for part: Array in [[&"head", 0.6], [&"spine", 0.4]]:
			var bone := _skeleton.find_bone(part[0])
			_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_pose_rotation(bone) * Quaternion(Vector3.UP, angle * part[1]))
	if _root_baked:
		var root_bone := _skeleton.find_bone(&"root")
		_skeleton.set_bone_pose_position(root_bone, _skeleton.get_bone_rest(root_bone).origin)
	_apply_paws()
	if _glance <= 0.0:
		return
	var angle := deg_to_rad(glance_degrees) * _glance
	for part: Array in [[&"head", 0.67], [&"spine", 0.33]]:
		var bone := _skeleton.find_bone(part[0])
		var turn := Quaternion(Vector3.UP, -angle * part[1])
		_skeleton.set_bone_pose_rotation(bone, _skeleton.get_bone_pose_rotation(bone) * turn)


## Paw poses laid over the walk: the left paw on the hilt, the right one scratching.
func _apply_paws() -> void:
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	if _grab_weight > 0.0 and _sword:
		var carried := _hip_grip().lerp(_upright_marker.global_position, _upright)
		var lean := _sword_lean_grip.global_position
		var grip := lean.lerp(carried, _carry_blend) if _dragging else lean
		_reach(&"upper_arm.L", &"forearm.L", &"", to_skeleton * grip, Vector3(1.0, 0.0, -1.0), _grab_weight)
		if _dragging:
			_drag_sword(grip)
	if _scratch_weight > 0.0:
		var wiggle := Vector3(0.02 * sin(_time * scratch_speed), 0.035 * sin(_time * scratch_speed * 2.0), 0.0)
		_reach(&"upper_arm.R", &"forearm.R", &"hand.R", _butt_marker.position + wiggle, Vector3(-1.0, 0.0, -0.6), _scratch_weight)
	if _coin_hand > 0.0:
		var hand := _pocket_marker.position.lerp(_flick_marker.position, _coin_hand_raise)
		_reach(&"upper_arm.R", &"forearm.R", &"hand.R", hand, Vector3(-1.0, -0.3, -0.4), _coin_hand)
	if _coin_in_hand:
		_coin.global_position = _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone(&"hand.R")).origin


## Two-bone reach: bends the arm so the end of the lower bone lands on the target, elbow towards
## the pole. Everything is in skeleton space.
func _reach(upper_name: StringName, lower_name: StringName, end_name: StringName, target: Vector3,
		pole: Vector3, weight: float) -> void:
	var upper := _skeleton.find_bone(upper_name)
	var lower := _skeleton.find_bone(lower_name)
	var shoulder := _skeleton.get_bone_global_pose(upper).origin
	var elbow_now := _skeleton.get_bone_global_pose(lower).origin
	var l1 := shoulder.distance_to(elbow_now)
	var l2 := l1
	if end_name != &"":
		l2 = elbow_now.distance_to(_skeleton.get_bone_global_pose(_skeleton.find_bone(end_name)).origin)
	var to_target := target - shoulder
	var d := clampf(to_target.length(), 0.01, l1 + l2 - 0.001)
	var dir := to_target.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var side := (pole - dir * pole.dot(dir)).normalized()
	var elbow := shoulder + dir * a + side * h
	_aim(upper, elbow - shoulder, weight)
	_aim(lower, shoulder + dir * d - elbow, weight)


## Turns a bone so its length axis points along the direction, blended by weight.
func _aim(bone: int, direction: Vector3, weight: float) -> void:
	var pose := _skeleton.get_bone_global_pose(bone)
	var along := pose.basis.y.normalized()
	var turn := Quaternion.IDENTITY.slerp(Quaternion(along, direction.normalized()), weight)
	_skeleton.set_bone_global_pose(bone, Transform3D(Basis(turn) * pose.basis, pose.origin))


## The grip rides on the left hip under the paw; the tip trails behind on the floor, so the blade tilts with each step
## and never sinks into the floor.
## The left hip, moving up and down with the hips as the fox walks.
func _hip_grip() -> Vector3:
	var bob := _skeleton.get_bone_pose_position(_skeleton.find_bone(&"hips")) - _hips_sit
	return _hip_marker.global_position + _fox.global_basis * bob


func _drag_sword(grip: Vector3) -> void:
	var drop := grip.y - FLOOR_Y
	var reach := sqrt(maxf(SWORD_LENGTH * SWORD_LENGTH - drop * drop, 0.0))
	var trail := Vector3(_tip.x - grip.x, 0.0, _tip.z - grip.z)
	if trail.length() < 0.001:
		trail = -_fox.global_basis.z
	var tip := grip + trail.normalized() * reach
	tip.y = FLOOR_Y + 0.01
	var hanging := grip + Vector3.DOWN * SWORD_LENGTH
	hanging.y = maxf(hanging.y, FLOOR_Y + 0.02)
	tip = tip.lerp(hanging, _upright)
	for barrel in _barrels:
		var out := Vector2(tip.x - barrel.x, tip.z - barrel.y)
		var clear := barrel.z + 0.05
		if out.length() < clear:
			out = out.normalized() * clear if out.length() > 0.001 else Vector2(clear, 0.0)
			tip.x = barrel.x + out.x
			tip.z = barrel.y + out.y
	var moved := tip.distance_to(_tip)
	_tip = tip
	_place_sword(grip, tip)
	_dust_wait -= get_process_delta_time()
	if moved > 0.004 and _upright < 0.3 and _dust_wait <= 0.0:
		_dust_wait = 0.035
		_puff(tip)


func _make_coin() -> void:
	_coin = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.06
	disc.bottom_radius = 0.06
	disc.height = 0.014
	disc.radial_segments = 16
	_coin.mesh = disc
	_coin.material_override = load(ENV_DIR + "mat_gold.tres")
	_coin.visible = false
	add_child(_coin)


## Without breaking stride: looks at the chest, pulls a coin from the right pocket and flicks it
## onto the coins on the floor, then looks ahead again.
func _flick_coin() -> void:
	var look := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	look.tween_property(self, "_look_chest", 1.0, coin_look_time)
	var paw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	paw.tween_interval(coin_look_time * 0.5)
	paw.tween_property(self, "_coin_hand", 1.0, coin_pocket_time)
	await paw.finished
	_coin.visible = true
	_coin_in_hand = true
	var raise := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	raise.tween_property(self, "_coin_hand_raise", 1.0, coin_raise_time)
	await raise.finished
	# A little dip, then the flick.
	var dip := create_tween()
	dip.tween_property(self, "_coin_hand_raise", 0.85, 0.12)
	dip.tween_property(self, "_coin_hand_raise", 1.15, 0.08)
	await dip.finished
	_coin_in_hand = false
	var start := _coin.global_position
	var end := _coin_landing.global_position
	var fly := create_tween()
	fly.tween_method(_coin_flight.bind(start, end), 0.0, 1.0, coin_flight_time)
	var settle := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	settle.tween_property(self, "_coin_hand", 0.0, 0.35).set_delay(0.1)
	settle.tween_property(self, "_coin_hand_raise", 0.0, 0.35).set_delay(0.1)
	await fly.finished
	# Lands flat with a small hop.
	var land := create_tween()
	land.tween_property(_coin, "rotation", Vector3(0.0, 1.3, 0.0), 0.08)
	land.tween_property(_coin, "global_position:y", end.y + 0.06, 0.08).set_ease(Tween.EASE_OUT)
	land.tween_property(_coin, "global_position:y", end.y, 0.08).set_ease(Tween.EASE_IN)
	var back := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	back.tween_interval(0.25)
	back.tween_property(self, "_look_chest", 0.0, coin_look_time)


## A spinning arc from the paw to the coins on the floor.
func _coin_flight(t: float, start: Vector3, end: Vector3) -> void:
	var p := start.lerp(end, t)
	p.y += coin_arc_height * 4.0 * t * (1.0 - t)
	_coin.global_position = p
	_coin.rotation = Vector3(t * TAU * coin_spins, t * 2.0, 0.0)


func _scratch() -> void:
	_scratched = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "_scratch_weight", 1.0, 0.35)
	tween.tween_interval(scratch_time)
	tween.tween_property(self, "_scratch_weight", 0.0, 0.35)


## The jump moves the root bone. Move the fox node to where it landed so the walk starts there.
func _bake_root_motion() -> void:
	var root_bone := _skeleton.find_bone("root")
	var landed := _skeleton.global_transform * _skeleton.get_bone_global_pose(root_bone).origin
	var rest := _skeleton.global_transform * _skeleton.get_bone_global_rest(root_bone).origin
	_fox.global_position += landed - rest
	_fox.global_position.y = FLOOR_Y
	_skeleton.set_bone_pose_position(root_bone, _skeleton.get_bone_rest(root_bone).origin)
	_root_baked = true


## Turns smoothly towards the point while walking. The fox slows down while it still faces away,
## so it curves round instead of snapping to the new direction.
func _walk_to(point: Vector3, last := false) -> void:
	var flat := Vector3(point.x, _fox.global_position.y, point.z)
	while _fox.global_position.distance_to(flat) > 0.05:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		var to_point := flat - _fox.global_position
		var target_yaw := atan2(to_point.x, to_point.z)
		var still_to_turn := absf(angle_difference(_fox.rotation.y, target_yaw))
		if _lift_done:
			_upright_target = 0.0
		elif still_to_turn > lift_turn_angle:
			_upright_target = 1.0
		elif _upright_target > 0.0:
			_upright_target = 0.0
			_lift_done = true
		_upright = move_toward(_upright, _upright_target, lift_speed * delta)
		var yaw := rotate_toward(_fox.rotation.y, target_yaw, turn_speed * delta)
		_fox.rotation.y = yaw
		var facing := Vector3(sin(yaw), 0.0, cos(yaw))
		var pace := clampf(facing.dot(to_point.normalized()), 0.2, 1.0)
		var step := minf(walk_speed * pace * delta, to_point.length())
		_fox.global_position += facing.lerp(to_point.normalized(), 0.5).normalized() * step
		if not _scratched and _fox.global_position.distance_to(_door_center()) < scratch_distance:
			_scratch()
		if not _door_opened and last and _distance_to_leaves() < _door_lead():
			_open_door()


## Distance from the fox to the closed leaves, along his way through the door.
func _distance_to_leaves() -> float:
	return _fox.global_position.z - _door_center().z


## How far out the door has to start opening: the squeeze, plus enough of the swing to clear the
## fox's face, plus his reach and a little room.
func _door_lead() -> float:
	return fox_front_reach + door_clearance + walk_speed * (door_squeeze_time + door_open_time * 0.35)


## Lifts the camera off and settles it in behind the fox, on his right, looking across to the left.
func _start_follow() -> void:
	await get_tree().create_timer(rise_delay).timeout
	if _rushing:
		return
	_tracking = true
	var rise := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rise.tween_property(self, "_track_weight", 1.0, rise_time)


func _follow_transform() -> Transform3D:
	var forward := _fox.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var base := _fox.global_position
	var eye := base - forward * follow_back + right * follow_side + Vector3.UP * follow_height
	var look := base + forward * look_ahead + Vector3.UP * look_height
	return Transform3D(Basis.looking_at(look - eye), eye)


func _head() -> Vector3:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("head")).origin


func _head_top() -> Vector3:
	return _head() + Vector3.UP * HEAD_TOP * _fox.scale.y


func _door_center() -> Vector3:
	return _door_l.global_position.lerp(_door_r.global_position, 0.5)


func _open_door() -> void:
	_door_opened = true
	var open := deg_to_rad(door_open_degrees)
	var squeeze := deg_to_rad(door_squeeze_degrees)
	var doors := create_tween()
	# Pressed back a little, then let go: they spring open past the stop and settle.
	doors.tween_property(_door_l, "rotation:y", -squeeze, door_squeeze_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	doors.parallel().tween_property(_door_r, "rotation:y", squeeze, door_squeeze_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	doors.tween_property(_door_l, "rotation:y", open, door_open_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	doors.parallel().tween_property(_door_r, "rotation:y", -open, door_open_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	doors.parallel().tween_property(_door_sun, "light_energy", door_sun_open, door_open_time * 0.5)
	doors.parallel().tween_property(_door_glow, "light_energy", door_glow_open, door_open_time * 0.5)
	doors.parallel().tween_method(func(v: float) -> void: _glare.set_shader_parameter(&"strength", v), 0.0, door_glare_open, door_open_time * 0.5)
	doors.parallel().tween_method(func(v: float) -> void: _door_beam.set_shader_parameter(&"intensity", v), 0.0, door_beam_open, door_open_time * 0.5)


## In front of the door the fox looks back over his right shoulder, towards the camera.
func _glance_back() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(v: float) -> void: _glance = v, 0.0, 1.0, glance_time)
	await tween.finished


## The camera rushes into the fox's eye while the light swells to full white. The eye is followed
## every frame, since the head is still turning during the rush.
func _rush_to_face() -> void:
	_tracking = false
	_rushing = true
	var from := _camera.global_transform
	var rush := create_tween().set_parallel()
	rush.tween_method(_rush_step.bind(from), 0.0, 1.0, rush_time) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	rush.tween_property(_env, "tonemap_exposure", white_out_exposure, rush_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	rush.tween_property(_door_sun, "light_energy", door_sun_peak, rush_time)
	rush.tween_property(_door_glow, "light_energy", door_glow_peak, rush_time)
	rush.tween_method(func(v: float) -> void: _glare.set_shader_parameter(&"strength", v), door_glare_open, door_glare_peak, rush_time)
	rush.tween_property(_white, "color:a", 1.0, rush_time * 0.35).set_delay(rush_time * 0.65)
	await rush.finished


func _rush_step(weight: float, from: Transform3D) -> void:
	# Flies in a straight line from where it stood into the eye, still facing the door. The heading
	# only settles a little at the start so the eye ends up dead centre.
	var eye := _eye()
	var line := eye - from.origin
	var end_pos := eye - line.normalized() * rush_end_distance
	var pos := from.origin.lerp(end_pos, weight)
	var heading := from.basis.get_rotation_quaternion().slerp(
			Basis.looking_at(line).get_rotation_quaternion(), minf(weight * 3.0, 1.0))
	_camera.global_transform = Transform3D(Basis(heading), pos)


func _head_basis() -> Basis:
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(_skeleton.find_bone("head"))).basis


## The fox's eye on the camera's side, from the head bone, before the fox's scale is applied.
func _eye() -> Vector3:
	var b := _head_basis()
	var s := _fox.scale.y
	var centre := _head() + b.y.normalized() * EYE_UP * s + b.z.normalized() * EYE_FORWARD * s
	var side := b.x.normalized() * EYE_SIDE * s
	var cam := _camera.global_position
	return centre + side if (centre + side).distance_to(cam) < (centre - side).distance_to(cam) else centre - side
