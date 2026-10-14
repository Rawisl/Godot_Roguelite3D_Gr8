extends Node3D
## Vertical slice đo FPS (tiêu chí task TV5: >= 60 FPS với tối thiểu 8 quân).
## Dùng level thật, model thật, shader toon và ánh sáng của level.
## Chỉ huy chạy vòng, Grunt, Archer, Brute đi dọc hành lang về cổng,
## tower nhiều loại và nhiều cấp trên các slot, Fortress.
## Tắt VSync để đo được FPS thật, kết quả in ra Output và hiện góc trái màn hình.

const LEVEL := preload("res://levels/corridor/level.tscn")
const COMMANDER := preload("res://contents/assets/characters/commander/commander_model.tscn")
const FORTRESS := preload("res://contents/assets/fortress/fortress_model.tscn")
const ENEMY_DIR := "res://contents/assets/characters/enemy and boss/"
const TOWER_DIR := "res://contents/assets/towers/"

# Loại quân: số lượng, tốc độ theo bảng quân SRS 3.7, clip di chuyển
const ENEMIES := [
	{"scene": "grunt_model.tscn", "count": 6, "speed": 3.5, "clip": "move/Running_A"},
	{"scene": "archer_model.tscn", "count": 4, "speed": 3.0, "clip": "move/Running_A"},
	{"scene": "brute_model.tscn", "count": 2, "speed": 2.0, "clip": "move/Walking_B"},
]
# Tower theo slot trong level.tscn: loại, cấp, vị trí
const TOWERS := [
	{"scene": "arrow_tower_model.tscn", "level": 3, "pos": Vector3(-16, 4, -3.6)}, # W2
	{"scene": "cannon_tower_model.tscn", "level": 2, "pos": Vector3(-16, 4, 3.6)}, # W5
	{"scene": "arrow_tower_model.tscn", "level": 1, "pos": Vector3(-11, 0, -6.5)}, # N1
	{"scene": "arrow_tower_model.tscn", "level": 2, "pos": Vector3(-11, 0, -3.5)}, # N2
	{"scene": "cannon_tower_model.tscn", "level": 1, "pos": Vector3(-11, 0, 3.5)}, # N3
	{"scene": "barricade_tower_model.tscn", "level": 2, "pos": Vector3(-11, 0, 6.5)}, # N4
	{"scene": "barricade_tower_model.tscn", "level": 1, "pos": Vector3(2, 0, -3.5)}, # F2
	{"scene": "cannon_tower_model.tscn", "level": 3, "pos": Vector3(2, 0, 3.5)}, # F3
]
const LANE_START_X := 18.0
const LANE_END_X := -13.0
const WARMUP_TIME := 2.0
const MEASURE_TIME := 10.0
const TARGET_FPS := 60.0

var _enemies: Array[Node3D] = []
var _speeds: PackedFloat32Array = []
var _commander: Node3D
var _time := 0.0
var _frame_times: PackedFloat32Array = []
var _done := false

@onready var _label: Label = %FpsLabel


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var level := LEVEL.instantiate()
	add_child(level)
	# Ẩn khối blockout fortress, thay bằng model
	level.get_node("NavigationRegion3D/Geometry/Fortress/Model").visible = false
	level.get_node("NavigationRegion3D/Geometry/GateVisual").visible = false

	var fortress := FORTRESS.instantiate() as Node3D
	fortress.position = Vector3(-18.8, 0, 0)
	add_child(fortress)

	for t in TOWERS:
		var tower := (load(TOWER_DIR + t.scene) as PackedScene).instantiate() as Node3D
		tower.position = t.pos
		add_child(tower)
		for i in range(1, 4):
			tower.get_node("Level%d" % i).visible = (i == t.level)

	_commander = COMMANDER.instantiate() as Node3D
	add_child(_commander)
	_play(_commander, "move/Running_A")

	var rng := RandomNumberGenerator.new()
	rng.seed = 8 # cố định để mỗi lần đo giống nhau
	for e in ENEMIES:
		var scene := load(ENEMY_DIR + e.scene) as PackedScene
		for i in e.count:
			var unit := scene.instantiate() as Node3D
			unit.position = Vector3(rng.randf_range(LANE_END_X + 4, LANE_START_X), 0, rng.randf_range(-6, 6))
			unit.rotation.y = -PI / 2 # quay mặt về phía Fortress (-X)
			add_child(unit)
			_play(unit, e.clip)
			_enemies.append(unit)
			_speeds.append(e.speed)


func _process(delta: float) -> void:
	_time += delta
	for i in _enemies.size():
		var unit := _enemies[i]
		unit.position.x -= _speeds[i] * delta
		if unit.position.x < LANE_END_X:
			unit.position.x = LANE_START_X
	var angle := _time * 0.8
	_commander.position = Vector3(-6 + cos(angle) * 4, 0, sin(angle) * 4)
	_commander.rotation.y = -angle

	if _done:
		return
	if _time > WARMUP_TIME:
		_frame_times.append(delta)
	var fps := Engine.get_frames_per_second()
	_label.text = "FPS %d | %d enemies + commander | %d towers" % [fps, _enemies.size(), TOWERS.size()]
	if _time > WARMUP_TIME + MEASURE_TIME:
		_report()


func _play(root: Node, clip: String) -> void:
	var ap := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	ap.play(clip)


func _report() -> void:
	_done = true
	var sorted := _frame_times.duplicate()
	sorted.sort()
	var total := 0.0
	for t in sorted:
		total += t
	var avg_fps := sorted.size() / total
	var worst_1pct := sorted[int(sorted.size() * 0.99)]
	var low_1pct_fps := 1.0 / worst_1pct
	var min_fps := 1.0 / sorted[sorted.size() - 1]
	var passed := avg_fps >= TARGET_FPS and low_1pct_fps >= 45.0
	var result := "avg %.0f FPS | 1%% low %.0f FPS | min %.0f FPS | %s" % [
		avg_fps, low_1pct_fps, min_fps, "PASS" if passed else "FAIL"]
	print("[PerfSlice] ", result)
	print("[PerfSlice] GPU: ", RenderingServer.get_video_adapter_name(), " | renderer: ",
		ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	_label.text = "%s\n%s" % [result, RenderingServer.get_video_adapter_name()]
