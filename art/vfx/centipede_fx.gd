class_name CentipedeFx
extends Node3D

## Visual effects of the Skeletal Centipede, one scene that sits next to the model under the
## boss's Model node. Scythe, head and eye effects ride on bones of the model's skeleton
## (give it to bind()). The slash trails run on VfxPlayer with the clips in
## centipede_fx_library.tres; the roll and spit effects have no clips: the boss drives them
## through the small API below, so their timing follows the attack clock in game time.
## Everything is local to the Model, so a scaled Model scales the trails and bones for free.
## Particles simulate in world space, so apply_scale() fixes what the parent scale does not:
## gravity, damping and linear acceleration.
# TODO(kiezroth): when the boss steps between combo hits, let the held slash trail play out to its
# end instead of freezing mid-effect, so hold_slash() and resume_slash() no longer cut a trail short.

## Seconds the eyes take to go from dark to full glow during the roar.
@export var eye_glow_rise_time: float = 0.8
## Seconds after the roar starts before the eye sparks begin.
@export var eye_sparks_delay: float = 0.15
## The body glow when a roll ends: seconds to rise, to hold, to fall.
@export var body_glow_rise: float = 0.15
@export var body_glow_hold: float = 0.6
@export var body_glow_fall: float = 0.23
## Overlay material that lights the whole body; needs an instance uniform named "glow".
@export var body_glow_material: Material = preload("res://art/materials/boss_roll_body_glow.tres")

const _SLASH_UNIFORMS: Array[StringName] = [&"progress", &"opacity", &"crack", &"shatter"]

var _body_mesh: MeshInstance3D

@onready var _vfx_player: AnimationPlayer = $VfxPlayer
@onready var _eyes: Array[MeshInstance3D] = [%EyeL, %EyeR]
@onready var _eye_halos: Array[MeshInstance3D] = [%HaloL, %HaloR]
@onready var _eye_sparks: Array[CPUParticles3D] = [%SparksL, %SparksR]
@onready var _star_particles: Array[CPUParticles3D] = [%StarParticlesR, %StarParticlesL]
@onready var _blades: Array[MeshInstance3D] = [%BladeGlowR.get_node("VFX_BladeR"), %BladeGlowL.get_node("VFX_BladeL")]
@onready var _speed_lines: MeshInstance3D = $RollSpeedLines
@onready var _spit_emitter: Node3D = %SpitEmitter
@onready var _spit_particles: Array[CPUParticles3D] = [
	%Core, %Drops, %Smoke]


func _ready() -> void:
	# The hit flash skips this whole subtree, so the effects do not turn white with the body.
	add_to_group(HitReactionManager.NO_FLASH_GROUP)


## Points every bone attachment at the model's skeleton and puts the glow overlay on the body
## mesh. Call once, after the model is in the tree.
func bind(skeleton: Skeleton3D, body_mesh: MeshInstance3D) -> void:
	for node in find_children("*", "BoneAttachment3D", true, false):
		var attachment := node as BoneAttachment3D
		attachment.use_external_skeleton = true
		attachment.external_skeleton = attachment.get_path_to(skeleton)
		# Set after entering the tree, the attachment does not follow the animation on its own.
		if not skeleton.skeleton_updated.is_connected(attachment.on_skeleton_update):
			skeleton.skeleton_updated.connect(attachment.on_skeleton_update)
		# A skeleton at rest sends no update, so place the attachment on its bone now.
		attachment.on_skeleton_update()
	_body_mesh = body_mesh
	if _body_mesh != null:
		_body_mesh.material_overlay = body_glow_material
	set_body_glow(0.0)


## Plays one of the slash trail clips (la1_vfx, la2_vfx, la3_vfx, combo_vfx) at the boss's
## attack speed.
func play_slash(anim: StringName, speed: float = 1.0) -> void:
	_reset_slash_trails()
	_vfx_player.play(anim, -1.0, speed)


## Freezes the running trail clip where it is (trail and blade glow keep their state).
func hold_slash() -> void:
	_vfx_player.pause()


## Carries on the held trail clip from at_time (its own seconds) at the given speed.
func resume_slash(at_time: float, speed: float = 1.0) -> void:
	var anim := _vfx_player.assigned_animation
	if anim == &"":
		return
	_vfx_player.play(anim, -1.0, speed)
	_vfx_player.seek(at_time, true)


## Stops every effect: trails, blade glow, sparks, eyes, speed lines, body glow and the spit.
func stop_all() -> void:
	_vfx_player.stop()
	_reset_slash_trails()
	set_eye_glow(0.0)
	set_eye_sparks(false)
	set_speed_lines(0.0)
	set_body_glow(0.0)
	set_spit_emitting(false)


## Lights the eye spheres and the halos drawn over them (0 dark, 1 full).
func set_eye_glow(value: float) -> void:
	for eye in _eyes:
		eye.set_instance_shader_parameter(&"glow", value)
	for halo in _eye_halos:
		halo.set_instance_shader_parameter(&"glow", value)


func set_eye_sparks(on: bool) -> void:
	for sparks in _eye_sparks:
		sparks.emitting = on


func set_speed_lines(value: float) -> void:
	_speed_lines.set_instance_shader_parameter(&"intensity", value)


func set_body_glow(value: float) -> void:
	if _body_mesh != null:
		_body_mesh.set_instance_shader_parameter(&"glow", value)


func set_spit_emitting(on: bool) -> void:
	for particles in _spit_particles:
		particles.emitting = on


## Where the spit leaves the mouth, in world space.
func get_spit_origin() -> Vector3:
	return _spit_emitter.global_position


## Matches the particle physics to a model scale s. The parent scale already scales emission
## points, start velocity and particle size; gravity, damping and linear acceleration are
## world values, so they are multiplied here. The authored values are kept the first time,
## so calling it again with another scale does not compound.
func apply_scale(s: float) -> void:
	for node in find_children("*", "CPUParticles3D", true, false):
		var p := node as CPUParticles3D
		if not p.has_meta(&"authored_gravity"):
			p.set_meta(&"authored_gravity", p.gravity)
			p.set_meta(&"authored_damping_min", p.damping_min)
			p.set_meta(&"authored_damping_max", p.damping_max)
			p.set_meta(&"authored_linear_accel_min", p.linear_accel_min)
			p.set_meta(&"authored_linear_accel_max", p.linear_accel_max)
		p.gravity = (p.get_meta(&"authored_gravity") as Vector3) * s
		p.damping_min = (p.get_meta(&"authored_damping_min") as float) * s
		p.damping_max = (p.get_meta(&"authored_damping_max") as float) * s
		p.linear_accel_min = (p.get_meta(&"authored_linear_accel_min") as float) * s
		p.linear_accel_max = (p.get_meta(&"authored_linear_accel_max") as float) * s


## Scales the start speed of the three spit particles (Core, Drops, Smoke) to k times their
## authored speed, so the stream lands where the boss wants it. It is a world-space share on
## top of the model scale. The authored speeds are kept the first time, so calling it again
## does not compound.
func set_spit_speed_scale(k: float) -> void:
	for p in _spit_particles:
		if not p.has_meta(&"authored_velocity_min"):
			p.set_meta(&"authored_velocity_min", p.initial_velocity_min)
			p.set_meta(&"authored_velocity_max", p.initial_velocity_max)
		p.initial_velocity_min = (p.get_meta(&"authored_velocity_min") as float) * k
		p.initial_velocity_max = (p.get_meta(&"authored_velocity_max") as float) * k


func _reset_slash_trails() -> void:
	for node in find_children("VFX_Slash*", "MeshInstance3D", true, false):
		for uniform in _SLASH_UNIFORMS:
			(node as MeshInstance3D).set_instance_shader_parameter(uniform, 0.0)
	for blade in _blades:
		blade.set_instance_shader_parameter(&"glow", 0.0)
	for stars in _star_particles:
		stars.emitting = false
