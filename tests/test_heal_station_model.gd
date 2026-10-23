extends Node

## Visual check of the heal station and rubble models next to the towers and the commander,
## each on a 2 m grid cell with its slot ring, on grass, from the game camera angle.
## The rubble stands on a RUINED slot so its ring shows the ruined colour.

const COMMANDER := preload("res://contents/assets/characters/commander/commander_model.tscn")
const ARROW_TOWER := preload("res://contents/assets/towers/arrow_tower_model.tscn")
const CANNON_TOWER := preload("res://contents/assets/towers/cannon_tower_model.tscn")
const HEAL_STATION := preload("res://contents/assets/towers/heal_station_model.tscn")
const RUBBLE := preload("res://contents/assets/towers/rubble_model.tscn")
const RING := preload("res://art/materials/slot_ring.tres")

## Ortho camera size; about 8 is close, 14 is the in-game Frontline view.
@export var camera_size := 8.0

func _ready() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = camera_size
	add_child(cam)
	cam.global_basis = Basis.from_euler(Vector3(deg_to_rad(-45), deg_to_rad(20), 0))
	cam.global_position = Vector3(0, 1.0, 0) + cam.global_basis.z * 30.0
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.shadow_enabled = true
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	add_child(env)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 40)
	ground.mesh = plane
	ground.material_override = preload("res://art/materials/env_grass.tres")
	add_child(ground)

	# Lined up across the screen, one 2 m cell apart.
	var stage := Node3D.new()
	stage.rotation_degrees.y = 20.0
	add_child(stage)
	var row := [
		[ARROW_TOWER, "Arrow", false],
		[CANNON_TOWER, "Cannon", false],
		[HEAL_STATION, "Trạm hồi lực", false],
		[RUBBLE, "Đổ nát (RUINED)", true],
		[COMMANDER, "Chỉ huy", false],
	]
	for i in row.size():
		var x := (i - 2) * 2.6
		var model: Node3D = row[i][0].instantiate()
		stage.add_child(model)
		model.position = Vector3(x, 0, 0)
		for lv in ["Level2", "Level3"]:
			var n := model.get_node_or_null(lv) as Node3D
			if n:
				n.visible = false
		if row[i][0] != COMMANDER:
			_ring(stage, Vector3(x, 0.02, 0), row[i][2])
		var label := Label3D.new()
		label.text = row[i][1]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 40
		label.outline_size = 10
		label.position = Vector3(x, 0.05, 1.7)
		stage.add_child(label)


func _ring(parent: Node3D, at: Vector3, ruined: bool) -> void:
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.8, 2.8)
	ring.mesh = plane
	ring.material_override = RING
	ring.position = at
	parent.add_child(ring)
	ring.set_instance_shader_parameter(&"ruined", 1.0 if ruined else 0.0)
