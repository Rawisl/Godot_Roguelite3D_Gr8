class_name AuraFxManager
extends Node
## Frontline aura visuals:
## - a gold ring on the ground around the commander, at frontline_aura_radius, while the aura is on
## - a small aura icon above every tower that currently gets the bonus
## The ring follows EventBus.aura_changed. Towers have no signal for aura_active, so their flags
## are read every icon_poll seconds; the flag itself only changes once per scan_interval.
## Nothing is added to the commander or tower scenes.

const TOWER_ICON := preload("res://art/icons/aura_alter_icon.png")

@export_group("Ring")
## Colour, line and ripple are tuned in this material; radius and fade are set per ring.
@export var ring_material: ShaderMaterial = preload("res://art/materials/aura_ring.tres")
## Seconds to fade in or out.
@export var fade_time := 0.15
## Height above the commander's feet, enough to stay above the floor.
@export var ring_lift := 0.05
## Room outside the radius for the glow.
@export var ring_margin := 1.5

@export_group("Tower icon")
## Width of the icon in metres.
@export var icon_size := 1.1
## Scale when an icon starts to fade in; it grows to 1 as it becomes opaque.
@export var icon_start_scale := 0.6
## Gap between the top of the tower model and the bottom of the icon.
@export var icon_gap := 0.4
@export var icon_poll := 0.1
## Used when a tower has no mesh to measure.
@export var default_tower_height := 3.0

var _ring: MeshInstance3D
var _ring_radius := -1.0
var _aura_on := false
var _ring_fade := 0.0
var _commander: Node3D
var _icons: Dictionary = {}  # Tower -> Sprite3D
var _poll_left := 0.0


func _ready() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "AuraRing"
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.material_override = ring_material
	_ring.set_instance_shader_parameter(&"fade", 0.0)
	_ring.visible = false
	add_child(_ring)
	EventBus.aura_changed.connect(_on_aura_changed)
	_sync_with_commander.call_deferred()


## The commander may have sent aura_changed(true) before this node was ready.
func _sync_with_commander() -> void:
	var c := _get_commander()
	if c != null and c.has_method(&"is_aura_source"):
		_aura_on = c.is_aura_source()


func _on_aura_changed(active: bool) -> void:
	_aura_on = active


func _process(delta: float) -> void:
	_update_ring(delta)
	_poll_left -= delta
	if _poll_left <= 0.0:
		_poll_left = icon_poll
		_update_icons()
	_fade_icons(delta)


func _update_ring(delta: float) -> void:
	var c := _get_commander()
	var target := 1.0 if _aura_on and c != null else 0.0
	_ring_fade = move_toward(_ring_fade, target, delta / maxf(fade_time, 0.001))
	_ring.visible = _ring_fade > 0.0
	if not _ring.visible:
		return
	_set_radius(GameConfig.frontline_aura_radius)
	if c != null:
		_ring.global_position = c.global_position + Vector3.UP * ring_lift
	_ring.set_instance_shader_parameter(&"fade", _ring_fade)


func _set_radius(r: float) -> void:
	if is_equal_approx(r, _ring_radius):
		return
	_ring_radius = r
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0 * (r + ring_margin)
	_ring.mesh = plane
	_ring.set_instance_shader_parameter(&"radius", r)


func _update_icons() -> void:
	for tower in _icons.keys():
		if not is_instance_valid(tower):
			_icons[tower].queue_free()
			_icons.erase(tower)
	for node in get_tree().get_nodes_in_group(&"tower"):
		var tower := node as Tower
		if tower == null or not tower.is_inside_tree():
			continue
		var icon: Sprite3D = _icons.get(tower)
		if tower.aura_active and icon == null:
			icon = _new_icon()
			_icons[tower] = icon
		if icon != null:
			icon.set_meta(&"target", 1.0 if tower.aura_active else 0.0)
			icon.global_position = tower.global_position + Vector3.UP * (_tower_height(tower) + icon_gap + icon_size * 0.5)


func _fade_icons(delta: float) -> void:
	for tower in _icons:
		var icon: Sprite3D = _icons[tower]
		var a := move_toward(icon.modulate.a, float(icon.get_meta(&"target", 0.0)), delta / maxf(fade_time, 0.001))
		icon.modulate.a = a
		icon.scale = Vector3.ONE * lerpf(icon_start_scale, 1.0, a)
		icon.visible = a > 0.0


func _new_icon() -> Sprite3D:
	var icon := Sprite3D.new()
	icon.texture = TOWER_ICON
	icon.pixel_size = icon_size / float(TOWER_ICON.get_width())
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.shaded = false
	icon.no_depth_test = true
	icon.render_priority = 10
	icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	icon.modulate.a = 0.0
	icon.visible = false
	add_child(icon)
	return icon


## Top of the tower's meshes above its origin. Measured every poll because an upgrade swaps the model.
func _tower_height(tower: Tower) -> float:
	var top := -INF
	for mesh in tower.find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		var box := m.global_transform * m.get_aabb()
		top = maxf(top, box.end.y)
	if top == -INF:
		return default_tower_height
	return top - tower.global_position.y


func _get_commander() -> Node3D:
	if _commander == null or not is_instance_valid(_commander):
		_commander = get_tree().get_first_node_in_group(&"commander") as Node3D
	return _commander


## Ring opacity, 0 to 1. For tests.
func ring_fade() -> float:
	return _ring_fade


## True when the tower's icon is shown or fading in. For tests.
func has_icon(tower: Tower) -> bool:
	var icon: Sprite3D = _icons.get(tower)
	return icon != null and float(icon.get_meta(&"target", 0.0)) > 0.0
