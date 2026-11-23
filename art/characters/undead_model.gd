extends Node3D
## Undead: while it lies waiting to come back (set_reviving, called by the unit for revive_delay)
## small green bones swirl up around it and a faint green ring glows on the ground. The swirl is
## a slow drift, nothing blinks. Particles follow game time like the other unit effects.

@export var bone_color := Color(0.75, 1.0, 0.6)
@export var ring_color := Color(0.35, 0.9, 0.4, 0.5)
@export var bone_count := 14
@export var radius := 0.7

var _on := false
var _bones: CPUParticles3D
var _ring: MeshInstance3D


func _ready() -> void:
	_bones = CPUParticles3D.new()
	_bones.name = "ReviveBones"
	_bones.emitting = false
	_bones.amount = bone_count
	_bones.lifetime = 1.6
	var bone := BoxMesh.new()
	bone.size = Vector3(0.05, 0.18, 0.05)
	var bone_mat := StandardMaterial3D.new()
	bone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bone_mat.albedo_color = bone_color
	bone_mat.emission_enabled = true
	bone_mat.emission = bone_color
	bone.material = bone_mat
	_bones.mesh = bone
	_bones.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_bones.emission_ring_axis = Vector3.UP
	_bones.emission_ring_radius = radius
	_bones.emission_ring_inner_radius = radius * 0.6
	_bones.emission_ring_height = 0.05
	_bones.direction = Vector3.UP
	_bones.spread = 15.0
	_bones.initial_velocity_min = 0.4
	_bones.initial_velocity_max = 0.8
	_bones.gravity = Vector3.ZERO
	_bones.orbit_velocity_min = 0.35
	_bones.orbit_velocity_max = 0.5
	_bones.angular_velocity_min = 90.0
	_bones.angular_velocity_max = 180.0
	_bones.scale_amount_min = 0.8
	_bones.scale_amount_max = 1.3
	add_child(_bones)
	_ring = MeshInstance3D.new()
	_ring.name = "ReviveRing"
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.85
	torus.outer_radius = radius
	torus.rings = 24
	_ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = ring_color
	_ring.material_override = ring_mat
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position = Vector3(0, 0.03, 0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func set_reviving(on: bool) -> void:
	_on = on
	_bones.emitting = on
	_ring.visible = on


func is_reviving() -> bool:
	return _on


## Live particles, for the shared particle budget.
func active_particles() -> int:
	return _bones.amount if _bones.emitting else 0
