extends Node3D

## Visual verification scene for Grunt NavigationAgent3D pathfinding.

@onready var grunt: Enemy = %Grunt
@onready var target_marker: Marker3D = %TargetMarker
@onready var status_label: Label = %StatusLabel
@onready var nav_region: NavigationRegion3D = %NavigationRegion3D

func _ready() -> void:
	var nav_mesh := NavigationMesh.new()
	var vertices := PackedVector3Array([
		Vector3(-20, 0, -10),
		Vector3(-20, 0, 10),
		Vector3(20, 0, 10),
		Vector3(20, 0, -10)
	])
	nav_mesh.set_vertices(vertices)
	nav_mesh.add_polygon(PackedInt32Array([0, 1, 2]))
	nav_mesh.add_polygon(PackedInt32Array([0, 2, 3]))
	nav_region.navigation_mesh = nav_mesh
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	grunt.set_target_position(target_marker.global_position)
	print("Test Grunt: Target position set to ", target_marker.global_position)

func _process(_delta: float) -> void:
	if grunt != null and is_instance_valid(grunt):
		var dist_to_dest: float = grunt.global_position.distance_to(target_marker.global_position)
		var reached_str := "REACHED DESTINATION" if dist_to_dest <= 1.2 else "NAVIGATING"
		status_label.text = "=== GRUNT NAVIGATION TEST ===\n" \
			+ "Status: %s\n" % reached_str \
			+ "Enemy ID: %s | HP: %d/%d | DMG: %d\n" % [grunt.data.id if grunt.data else "N/A", grunt.health.hp, grunt.health.max_hp, grunt.data.base_damage if grunt.data else 0] \
			+ "Move Speed: %.1f m/s\n" % (grunt.data.move_speed if grunt.data else 0.0) \
			+ "Position: (%.2f, %.2f, %.2f)\n" % [grunt.global_position.x, grunt.global_position.y, grunt.global_position.z] \
			+ "Distance Remaining: %.2f m" % dist_to_dest
