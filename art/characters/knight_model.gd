extends Node3D
## Knight: while it cannot be hurt (set_invulnerable, called by the unit for its invuln_duration)
## the armour glows gold and a shield icon floats over its head, so the state reads by shape too,
## not only by colour. The glow breathes slowly (under 3 times a second) and holds steady with
## Reduce flashing.

@export var icon: Texture2D = preload("res://art/icons/traits/trait_undying.png")
@export var glow_color := Color(1.0, 0.82, 0.3)
@export_range(0.0, 3.0) var pulse_rate := 1.2
@export var icon_height := 2.4

var _on := false
var _reduce_flash := false
var _time := 0.0
var _glow: StandardMaterial3D
var _sprite: Sprite3D
var _meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	_reduce_flash = GameState.get_setting(&"reduce_flash", false) == true
	EventBus.settings_changed.connect(_on_settings_changed)
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.albedo_color = Color(glow_color, 0.0)
	for m in find_children("*", "MeshInstance3D", true, false):
		_meshes.append(m as MeshInstance3D)
	_sprite = Sprite3D.new()
	_sprite.name = "InvulnIcon"
	_sprite.texture = icon
	_sprite.pixel_size = 0.012
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.no_depth_test = true
	_sprite.modulate = glow_color
	_sprite.position = Vector3(0, icon_height, 0)
	_sprite.visible = false
	add_child(_sprite)
	set_process(false)


func set_invulnerable(on: bool) -> void:
	_on = on
	_time = 0.0
	for m in _meshes:
		m.material_overlay = _glow if on else null
	_sprite.visible = on
	_update_glow()
	set_process(on)


func is_invulnerable() -> bool:
	return _on


func _process(delta: float) -> void:
	_time += delta
	_update_glow()


func _update_glow() -> void:
	if not _on:
		return
	var strength := 0.45 if _reduce_flash else 0.3 + 0.25 * (0.5 + 0.5 * sin(_time * pulse_rate * TAU))
	_glow.albedo_color = Color(glow_color, strength)


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"reduce_flash":
		_reduce_flash = value == true
