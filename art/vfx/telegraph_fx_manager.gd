class_name TelegraphFxManager
extends Node
## Boss AoE telegraphs (FBK-06): a red ring on the ground for every EventBus.telegraph_started.
## The area fills from the centre and a countdown arc sweeps round over the wind-up, so the
## hit time reads without sound (ACC-09). Drawn without depth test, so nothing hides it.
## Runs on game time: it follows x2 / x3 and holds while the game is paused, like the wind-up.
## Never culled by the particle budget (FBK-09).

## Colour, line and hatching are tuned in this material; radius, progress and fade are set per ring.
@export var ring_material: ShaderMaterial = preload("res://art/materials/telegraph_ring.tres")
## Seconds to fade out after the hit. Fades, never blinks (ACC-06).
@export var fade_time := 0.15
## Height above the given position, enough to stay above the floor.
@export var ring_lift := 0.05
## Room outside the radius for the outline.
@export var ring_margin := 0.3

var _rings: Array[Dictionary] = []  # {mesh, duration, elapsed}


func _ready() -> void:
	EventBus.telegraph_started.connect(_on_telegraph_started)


## Number of telegraphs still on screen, fading ones included.
func get_active_count() -> int:
	return _rings.size()


func _on_telegraph_started(_kind: StringName, pos: Vector3, radius: float, duration: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0 * (radius + ring_margin)
	var mesh := MeshInstance3D.new()
	mesh.name = "Telegraph"
	mesh.mesh = plane
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = ring_material
	mesh.set_instance_shader_parameter(&"radius", radius)
	mesh.set_instance_shader_parameter(&"progress", 0.0)
	mesh.set_instance_shader_parameter(&"fade", 1.0)
	add_child(mesh)
	mesh.global_position = pos + Vector3.UP * ring_lift
	_rings.append({"mesh": mesh, "duration": maxf(duration, 0.001), "elapsed": 0.0})


func _process(delta: float) -> void:
	for ring in _rings.duplicate():
		var mesh: MeshInstance3D = ring.mesh
		ring.elapsed += delta
		var progress: float = minf(ring.elapsed / ring.duration, 1.0)
		var fade := 1.0 - clampf((ring.elapsed - ring.duration) / maxf(fade_time, 0.001), 0.0, 1.0)
		mesh.set_instance_shader_parameter(&"progress", progress)
		mesh.set_instance_shader_parameter(&"fade", fade)
		if fade <= 0.0:
			mesh.queue_free()
			_rings.erase(ring)
