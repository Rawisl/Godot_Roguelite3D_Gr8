extends Node

## Visual check of the sword hits: the commander's combo 1-2-3 lands on a post, then a pause,
## on grass, seen from the game camera angle. Runs forever; close the window to stop.
## Edit art/vfx/styles/slash.tres in the Inspector while it runs; each hit reads its style fresh.

const HIT := preload("res://art/vfx/sword_hit.tscn")
const STYLES: Array[SwordHitStyle] = [
	preload("res://art/vfx/styles/slash.tres"),
	preload("res://art/vfx/styles/slash.tres"),
	preload("res://art/vfx/styles/slash.tres"),
]

## Seconds between combo hits, and the pause after the third.
@export var hit_gap := 0.45
@export var combo_pause := 1.0

func _ready() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.0
	cam.position = Vector3(2.4, 7.1, 6.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = preload("res://art/materials/env_grass.tres")
	add_child(ground)
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.08
	cyl.height = 1.6
	post.mesh = cyl
	post.position = Vector3(0, 0.8, 0)
	add_child(post)
	var caption := Label3D.new()
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.position = Vector3(0, 0.15, 1.2)
	caption.font_size = 48
	caption.modulate = Color.BLACK
	add_child(caption)

	var hit: SwordHit = HIT.instantiate()
	add_child(hit)
	# The commander stands between the post and the camera, so the slash faces the camera.
	var dir := Vector3(-0.3, 0, -1).normalized()
	while is_inside_tree():
		for i in STYLES.size():
			caption.text = "Đòn %d" % (i + 1)
			hit.play(Vector3(0, 1.0, 0), dir, STYLES[i])
			await get_tree().create_timer(hit_gap).timeout
		await get_tree().create_timer(combo_pause).timeout
