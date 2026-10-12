extends Node3D
## So sánh StandardMaterial3D (hàng sau) với toon.gdshader (hàng trước).
## Model đã dùng toon sẵn, hàng sau được đổi ngược về StandardMaterial3D để đối chiếu.

const MODELS := [
	"res://contents/assets/characters/commander/commander_model.tscn",
	"res://contents/assets/characters/enemy and boss/grunt_model.tscn",
	"res://contents/assets/characters/enemy and boss/archer_model.tscn",
	"res://contents/assets/characters/enemy and boss/brute_model.tscn",
]
const TOWER := "res://contents/assets/towers/arrow_tower_model.tscn"
const SPACING := 2.5

var _standard_cache := {}


func _ready() -> void:
	var x0 := -SPACING * (MODELS.size() - 1) / 2.0
	for i in MODELS.size():
		var scene: PackedScene = load(MODELS[i])
		var standard := scene.instantiate() as Node3D
		standard.position = Vector3(x0 + i * SPACING, 0, -2)
		add_child(standard)
		_apply_standard(standard)
		var toon := scene.instantiate() as Node3D
		toon.position = Vector3(x0 + i * SPACING, 0, 2)
		add_child(toon)
		_play_idle(standard)
		_play_idle(toon)
	var tower_scene: PackedScene = load(TOWER)
	var tower_std := tower_scene.instantiate() as Node3D
	tower_std.position = Vector3(-x0 + 2.5, 0, -2)
	add_child(tower_std)
	_apply_standard(tower_std)
	var tower_toon := tower_scene.instantiate() as Node3D
	tower_toon.position = Vector3(-x0 + 2.5, 0, 2)
	add_child(tower_toon)
	_add_label("StandardMaterial3D", Vector3(x0 - 2.5, 0.1, -2))
	_add_label("toon.gdshader", Vector3(x0 - 2.5, 0.1, 2))


func _apply_standard(root: Node) -> void:
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var src := m.material_override as ShaderMaterial
		if src == null:
			continue
		var tex: Texture2D = src.get_shader_parameter("albedo_texture")
		if not _standard_cache.has(tex):
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			_standard_cache[tex] = mat
		m.material_override = _standard_cache[tex]


func _play_idle(root: Node) -> void:
	for ap: AnimationPlayer in root.find_children("*", "AnimationPlayer", true, false):
		for anim_name in ap.get_animation_list():
			if "Idle" in anim_name:
				ap.play(anim_name)
				return


func _add_label(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.rotation_degrees = Vector3(-90, 0, 0)
	label.font_size = 48
	label.modulate = Color.BLACK
	add_child(label)
