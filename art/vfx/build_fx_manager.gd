class_name BuildFxManager
extends Node
## Hiệu ứng dựng tower 0.5 s khi xây xong: tower hiện ra nhỏ và ép xuống lấy đà,
## bật lên vừa to dần vừa kéo dãn và xoay một vòng, rơi xuống về cỡ thường, tiếp đất phình ra kèm bụi.
## Chỉ làm động node Model, collider và tầm bắn không đổi nên tower hoạt động ngay.

const DUST := preload("res://art/vfx/build_dust.tscn")

@export var jump_height := 0.8
## Ép lúc lấy đà và lúc tiếp đất (X và Z phình, Y ép).
@export var squash := Vector3(1.3, 0.6, 1.3)
@export var land_squash := Vector3(1.2, 0.8, 1.2)
## Kéo dãn lúc đang bay.
@export var stretch := Vector3(0.8, 1.3, 0.8)
## Cỡ tổng thể nhân thêm vào ép/dãn: nhỏ lúc xuất hiện, to nhất ở đỉnh nhảy, về 1 khi tiếp đất.
@export var start_size := 0.6
@export var peak_size := 1.15

func _ready() -> void:
	EventBus.tower_built.connect(_on_tower_built)

func _on_tower_built(slot_id: StringName, _type: StringName) -> void:
	for slot in get_tree().get_nodes_in_group(&"slot"):
		if slot.slot_id == slot_id and is_instance_valid(slot.tower):
			play(slot.tower)
			return

func play(tower: Node3D) -> void:
	var model := tower.get_node_or_null(^"Model") as Node3D
	if model == null:
		return
	var base_y := model.position.y
	var base_rot := model.rotation.y
	model.scale = squash * start_size
	# Thời gian thật: luôn đúng 0.5 s kể cả khi tua x2, x3.
	var tw := model.create_tween().set_ignore_time_scale()
	# Lấy đà
	tw.tween_property(model, "scale", squash * Vector3(1.04, 0.92, 1.04) * start_size, 0.10)
	# Bật lên: kéo dãn
	tw.tween_property(model, "position:y", base_y + jump_height, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(model, "scale", stretch * peak_size, 0.18)
	# Rơi xuống
	tw.tween_property(model, "position:y", base_y, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "scale", stretch.lerp(Vector3.ONE, 0.4), 0.12)
	# Tiếp đất: phình, ép và bụi
	tw.tween_callback(_spawn_dust.bind(tower.global_position))
	tw.tween_property(model, "scale", land_squash, 0.06)
	tw.tween_property(model, "scale", Vector3.ONE, 0.04)
	# Xoay một vòng trong suốt lúc bay (bật lên và rơi xuống), tween riêng để không kéo dài nhịp nhảy.
	var spin := model.create_tween().set_ignore_time_scale()
	spin.tween_interval(0.10)
	spin.tween_property(model, "rotation:y", base_rot + TAU, 0.30)
	spin.tween_callback(func() -> void: model.rotation.y = base_rot)

func _spawn_dust(at: Vector3) -> void:
	var fx := DUST.instantiate() as Node3D
	get_tree().current_scene.add_child(fx)
	fx.global_position = at
	var dust := fx.get_node(^"Dust") as CPUParticles3D
	dust.finished.connect(fx.queue_free)
	dust.emitting = true
