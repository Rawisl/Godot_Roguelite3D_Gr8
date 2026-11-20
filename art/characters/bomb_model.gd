extends Node3D
## Suicide Squad and Captain: the bomb on the back. While the fuse is lit (set_fuse, called by the
## unit during its explode wind-up) the bomb glows red and pulses, under 3 times a second; with
## Reduce flashing it glows steady instead. The red ring on the ground comes from the unit's
## telegraph_started, drawn by TelegraphFxManager.

## Pulses a second while the fuse burns; kept under 3.
@export_range(0.0, 3.0) var pulse_rate := 2.5
@export var glow_color := Color(1.0, 0.25, 0.1)
@export var glow_energy := 3.0

var _lit := false
var _reduce_flash := false
var _time := 0.0
var _glow: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	_reduce_flash = GameState.get_setting(&"reduce_flash", false) == true
	EventBus.settings_changed.connect(_on_settings_changed)
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.albedo_color = Color(glow_color, 0.0)
	var bomb := find_child("Bomb", true, false)
	if bomb != null:
		for m in bomb.find_children("*", "MeshInstance3D", true, false):
			_meshes.append(m as MeshInstance3D)
	set_process(false)


## Lights or puts out the fuse.
func set_fuse(lit: bool) -> void:
	_lit = lit
	_time = 0.0
	for m in _meshes:
		m.material_overlay = _glow if lit else null
	_update_glow()
	set_process(lit)


func is_fuse_lit() -> bool:
	return _lit


func _process(delta: float) -> void:
	_time += delta
	_update_glow()


func _update_glow() -> void:
	if not _lit:
		return
	var strength := 0.7 if _reduce_flash else 0.4 + 0.5 * (0.5 + 0.5 * sin(_time * pulse_rate * TAU))
	_glow.albedo_color = Color(glow_color, strength)


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_reduce_flash = value == true
