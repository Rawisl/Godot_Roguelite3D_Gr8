class_name HoverHighlight
extends Node
## Hover feedback: outline and range ring on towers, a short info tooltip on enemies,
## and the hovered object handed to the occlusion fade so nothing hides it.

const OUTLINE_SHADER := preload("res://ui/world/outline.gdshader")
const SHADOW_PROXY_META := &"occlusion_shadow_proxy"
const ENEMY_TOOLTIP_DELAY := 0.3
const TOOLTIP_OFFSET := Vector2(20, 20)

var _outline: ShaderMaterial
var _outlined: Dictionary = {}  # MeshInstance3D -> material_overlay it had before
var _tooltip_target: Enemy = null
var _tooltip_at := 0.0
var _occlusion: OcclusionManager = null

@onready var _selection: SelectionController = %SelectionController
@onready var _ring: RangeRing = %HoverRing
@onready var _tooltip: Control = %EnemyTooltip
@onready var _tooltip_text: Label = %TooltipText
@onready var _bars: EnemyBarLayer = %EnemyBarLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection.hovered_changed.connect(_on_hovered_changed)

func _on_hovered_changed(node: Node) -> void:
	_clear_outline()
	_ring.hide_ring()
	_tooltip.visible = false
	_tooltip_target = null
	_bars.hovered = node
	_set_occlusion_target(node as Node3D)
	if node is Tower:
		var t := node as Tower
		_add_outline(t)
		var attack_range := t.data.levels[t.level - 1].attack_range
		if attack_range > 0.0:
			_ring.show_at(t.global_position, attack_range)
	elif node is Enemy:
		_tooltip_target = node as Enemy
		_tooltip_at = TimeManager.real_time + ENEMY_TOOLTIP_DELAY

## Real time, so the delay is the same at x1, x2 and x3.
func _process(_delta: float) -> void:
	if _tooltip_target == null:
		return
	if not is_instance_valid(_tooltip_target) or _tooltip_target.is_dead:
		_tooltip.visible = false
		_tooltip_target = null
		return
	if TimeManager.real_time < _tooltip_at:
		return
	var e := _tooltip_target
	_tooltip_text.text = UiFormat.tr_fmt(&"hover.enemy.hp", {
		"name": tr(e.data.display_name_key), "hp": e.health.hp, "max": e.health.max_hp}) \
		+ "\n" + UiFormat.tr_fmt(&"hover.enemy.target", {"target": _target_name(e.current_target)})
	_tooltip.position = _tooltip.get_viewport().get_mouse_position() + TOOLTIP_OFFSET
	_tooltip.visible = true

func _add_outline(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta(SHADOW_PROXY_META):
			continue
		_outlined[mi] = mi.material_overlay
		mi.material_overlay = _outline

func _clear_outline() -> void:
	for mi in _outlined:
		if is_instance_valid(mi):
			mi.material_overlay = _outlined[mi]
	_outlined.clear()

func _set_occlusion_target(target: Node3D) -> void:
	if not is_instance_valid(_occlusion):
		var scene := get_tree().current_scene
		if scene != null:
			_occlusion = scene.find_child("OcclusionManager", true, false) as OcclusionManager
	if _occlusion != null:
		_occlusion.set_hover_target(target)

func _target_name(target: Node) -> String:
	if target == null or not is_instance_valid(target):
		return tr(&"hover.target.none")
	if target is Tower:
		return tr((target as Tower).data.display_name)
	if target.is_in_group(&"commander"):
		return tr(&"hud.commander")
	return tr(&"hud.fortress")
