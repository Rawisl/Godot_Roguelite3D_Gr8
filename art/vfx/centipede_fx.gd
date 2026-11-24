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
## When the boss steps between combo hits, detach_slash() hands the trails that are still showing
## to a ghost left in the world, which plays them out on its own, and holds the rest of the clip
## (blade glow, stars) until resume_slash().

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


## Leaves the slash trails that are still showing standing in the world where they are and lets
## them play out to their last key on their own, then holds the clip like hold_slash(). The
## trails on the model stay hidden until the next play_slash() or stop_all(). Returns the ghost
## that carries the trails, or null when no trail is showing.
func detach_slash() -> Node3D:
	var ghost := _make_slash_ghost()
	hold_slash()
	return ghost


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


## Copies the trails that are showing now (opacity above zero) into a Node3D in the current
## scene, hides the originals, and plays their tracks on the copies from the clip's current time
## at its current speed. The ghost frees itself when the last of those tracks has ended.
func _make_slash_ghost() -> Node3D:
	if not _vfx_player.is_playing() or get_tree().current_scene == null:
		return null
	var clip := _vfx_player.get_animation(_vfx_player.assigned_animation)
	var now := _vfx_player.current_animation_position
	var shown := _showing_trails(clip, now)
	if shown.is_empty():
		return null
	var ghost := Node3D.new()
	ghost.name = &"CentipedeSlashGhost"
	get_tree().current_scene.add_child(ghost)
	var ghost_clip := Animation.new()
	for source: MeshInstance3D in shown:
		var copy := source.duplicate() as MeshInstance3D
		ghost.add_child(copy)
		copy.global_transform = source.global_transform
		for uniform in _SLASH_UNIFORMS:
			copy.set_instance_shader_parameter(uniform, source.get_instance_shader_parameter(uniform))
		source.visible = false
		_copy_trail_tracks(clip, source, ghost_clip)
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	library.add_animation(&"slash", ghost_clip)
	player.add_animation_library(&"", library)
	ghost.add_child(player)
	player.animation_finished.connect(func(_anim: StringName) -> void: ghost.queue_free())
	player.play(&"slash", -1.0, _vfx_player.get_playing_speed())
	player.seek(now, true)
	return ghost


## The slash trail meshes the clip drives that are lit now and still have keys ahead of at_time.
func _showing_trails(clip: Animation, at_time: float) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for i in clip.get_track_count():
		var mesh := get_node_or_null(NodePath(clip.track_get_path(i).get_concatenated_names())) as MeshInstance3D
		if mesh == null or found.has(mesh) or not mesh.name.begins_with("VFX_Slash"):
			continue
		var opacity: Variant = mesh.get_instance_shader_parameter(&"opacity")
		if opacity == null or float(opacity) <= 0.0:
			continue
		if _trail_end(clip, mesh) <= at_time:
			continue
		found.append(mesh)
	return found


## Time of the last key among the tracks of one mesh.
func _trail_end(clip: Animation, mesh: Node) -> float:
	var end := 0.0
	for i in clip.get_track_count():
		if get_node_or_null(NodePath(clip.track_get_path(i).get_concatenated_names())) != mesh:
			continue
		end = maxf(end, clip.track_get_key_time(i, clip.track_get_key_count(i) - 1))
	return end


## Adds the tracks of one mesh to the ghost clip, aimed at the copy (a child of the ghost with the
## same name), and stretches the ghost clip to the last key.
func _copy_trail_tracks(clip: Animation, mesh: Node, ghost_clip: Animation) -> void:
	for i in clip.get_track_count():
		var path := clip.track_get_path(i)
		if get_node_or_null(NodePath(path.get_concatenated_names())) != mesh:
			continue
		var track := ghost_clip.add_track(clip.track_get_type(i))
		ghost_clip.track_set_path(track, NodePath("%s:%s" % [mesh.name, path.get_concatenated_subnames()]))
		ghost_clip.track_set_interpolation_type(track, clip.track_get_interpolation_type(i))
		ghost_clip.track_set_interpolation_loop_wrap(track, clip.track_get_interpolation_loop_wrap(i))
		ghost_clip.value_track_set_update_mode(track, clip.value_track_get_update_mode(i))
		for key in clip.track_get_key_count(i):
			ghost_clip.track_insert_key(track, clip.track_get_key_time(i, key), clip.track_get_key_value(i, key), clip.track_get_key_transition(i, key))
		ghost_clip.length = maxf(ghost_clip.length, clip.track_get_key_time(i, clip.track_get_key_count(i) - 1))


func _reset_slash_trails() -> void:
	for node in find_children("VFX_Slash*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = true
		for uniform in _SLASH_UNIFORMS:
			(node as MeshInstance3D).set_instance_shader_parameter(uniform, 0.0)
	for blade in _blades:
		blade.set_instance_shader_parameter(&"glow", 0.0)
	for stars in _star_particles:
		stars.emitting = false
