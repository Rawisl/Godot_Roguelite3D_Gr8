class_name ImmuneFxManager
extends Node
## Immune icon above a tower that idles because every target in its range is immune to its
## damage type (Tower.is_immune_blocked), so the player sees why it is not shooting.
## Follows EventBus.tower_immunity_changed. The icon is a shield with a red "no" sign; the sign
## and the shape carry the meaning, not the colour alone. It fades in and out and never blinks.
## When the tower also shows the Frontline aura icon, this one sits above it.
## Nothing is added to the tower scenes.

const ICON := preload("res://art/icons/tower_immune_icon.png")

## Width of the icon in metres.
@export var icon_size := 1.0
## Scale when an icon starts to fade in; it grows to 1 as it becomes opaque.
@export var icon_start_scale := 0.6
## Gap between the top of the tower model (or of the aura icon) and the bottom of this icon.
@export var icon_gap := 0.4
@export var fade_time := 0.15
## Used when a tower has no mesh to measure.
@export var default_tower_height := 3.0
## Room the aura icon takes above a tower when both show (AuraFxManager.icon_size + icon_gap).
@export var aura_icon_room := 1.5

var _icons: Dictionary = {}  # Tower -> Sprite3D


func _ready() -> void:
	EventBus.tower_immunity_changed.connect(_on_tower_immunity_changed)
	_sync_existing.call_deferred()


## Towers already blocked before this node was ready.
func _sync_existing() -> void:
	for node in get_tree().get_nodes_in_group(&"tower"):
		var tower := node as Tower
		if tower != null and tower.is_immune_blocked:
			_set_shown(tower, true)


func _on_tower_immunity_changed(slot_id: StringName, is_immune: bool) -> void:
	var tower := _find_tower(slot_id)
	if tower != null:
		_set_shown(tower, is_immune)


func _set_shown(tower: Tower, shown: bool) -> void:
	var icon: Sprite3D = _icons.get(tower)
	if icon == null:
		if not shown:
			return
		icon = _new_icon()
		_icons[tower] = icon
	icon.set_meta(&"target", 1.0 if shown else 0.0)
	_place(tower, icon)


func _process(delta: float) -> void:
	for tower in _icons.keys():
		var icon: Sprite3D = _icons[tower]
		if not is_instance_valid(tower) or not tower.is_inside_tree():
			icon.queue_free()
			_icons.erase(tower)
			continue
		var a := move_toward(icon.modulate.a, float(icon.get_meta(&"target", 0.0)), delta / maxf(fade_time, 0.001))
		icon.modulate.a = a
		icon.scale = Vector3.ONE * lerpf(icon_start_scale, 1.0, a)
		icon.visible = a > 0.0
		if icon.visible:
			_place(tower, icon)


func _place(tower: Tower, icon: Sprite3D) -> void:
	var lift := _tower_height(tower) + icon_gap + icon_size * 0.5
	if tower.aura_active:
		lift += aura_icon_room
	icon.global_position = tower.global_position + Vector3.UP * lift


func _new_icon() -> Sprite3D:
	var icon := Sprite3D.new()
	icon.name = "ImmuneIcon"
	icon.texture = ICON
	icon.pixel_size = icon_size / float(ICON.get_width())
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


func _find_tower(slot_id: StringName) -> Tower:
	for node in get_tree().get_nodes_in_group(&"tower"):
		var tower := node as Tower
		if tower != null and tower.slot_id == slot_id:
			return tower
	return null


## Top of the tower's meshes above its origin; an upgrade can swap the model, so it is measured again.
func _tower_height(tower: Tower) -> float:
	var top := -INF
	for mesh in tower.find_children("*", "MeshInstance3D", true, false):
		var m := mesh as MeshInstance3D
		if not m.is_visible_in_tree() or m.mesh == null:
			continue
		top = maxf(top, (m.global_transform * m.get_aabb()).end.y)
	if top == -INF:
		return default_tower_height
	return top - tower.global_position.y


## True when the tower's immune icon is shown or fading in. For tests.
func has_icon(tower: Tower) -> bool:
	var icon: Sprite3D = _icons.get(tower)
	return icon != null and float(icon.get_meta(&"target", 0.0)) > 0.0


## The icon node of a tower, or null. For tests.
func get_icon(tower: Tower) -> Sprite3D:
	return _icons.get(tower)
