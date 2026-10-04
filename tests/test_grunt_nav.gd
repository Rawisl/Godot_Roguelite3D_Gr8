extends Node3D

## Scene kiểm thử khả năng tìm đường và di chuyển của Grunt với NavigationAgent3D.
## Chạy scene này bằng phím F6 trong Godot.

@onready var grunt: Enemy = $Grunt
@onready var target_marker: Marker3D = $TargetMarker
@onready var status_label: Label = $CanvasLayer/Panel/StatusLabel
@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

func _ready() -> void:
	# Khởi tạo NavigationMesh dạng phẳng cho sàn test 40x20m
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
	
	# Đợi NavigationServer3D đồng bộ mesh
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# Thiết lập điểm đến cho Grunt hướng về đích (TargetMarker ở bên trái x = -12)
	grunt.set_target_position(target_marker.global_position)
	print("Test Grunt: Bắt đầu tìm đường tới đích tại ", target_marker.global_position)

func _process(_delta: float) -> void:
	if grunt != null and is_instance_valid(grunt):
		var dist_to_dest: float = grunt.global_position.distance_to(target_marker.global_position)
		var reached_str := "ĐÃ ĐẾN ĐÍCH!" if dist_to_dest <= 1.2 else "ĐANG DI CHUYỂN BẰNG NAVIGATIONAGENT3D"
		status_label.text = "=== TEST GRUNT PLACEHOLDER & NAVIGATION ===\n" \
			+ "Trạng thái: %s\n" % reached_str \
			+ "Enemy ID: %s | Base HP: %d | Base DMG: %d\n" % [grunt.data.id if grunt.data else "N/A", grunt.health.hp, grunt.data.base_damage if grunt.data else 0] \
			+ "Vận tốc cấu hình (move_speed): %.1f m/s\n" % (grunt.data.move_speed if grunt.data else 0.0) \
			+ "Tọa độ hiện tại: (%.2f, %.2f, %.2f)\n" % [grunt.global_position.x, grunt.global_position.y, grunt.global_position.z] \
			+ "Khoảng cách còn lại: %.2f m" % dist_to_dest
