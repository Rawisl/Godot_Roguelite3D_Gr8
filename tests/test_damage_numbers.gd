extends Node

## Automated test runner verifying floating damage numbers:
## - a hit on an enemy shows a white number, on the commander a red one, a heal a green "+n"
## - heals add up and show once per 0.5 s tick, even if healing stops before the tick
## - RESIST and IMMUNE show their tag in gray
## - hits from the same tower on the same target within 0.2 s add up into one number
## - at most 60 numbers on screen; the oldest is reused
## - nothing shows when disabled

const LAYER_SCRIPT := preload("res://art/vfx/damage_number_layer.gd")

@export var quit_when_done := true

var passes: int = 0
var fails: int = 0
var layer: DamageNumberLayer

func _ready() -> void:
	print("\n=======================================================")
	print("       AUTOMATED DAMAGE NUMBER TEST                    ")
	print("=======================================================")

	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 10, 10)
	cam.look_at(Vector3.ZERO)
	layer = LAYER_SCRIPT.new()
	add_child(layer)

	var enemy := _target(&"enemy", Vector3.ZERO)
	var commander := _target(&"commander", Vector3(3, 0, 0))
	await get_tree().process_frame

	var e_health: HealthComponent = enemy.get_node("Health")
	var c_health: HealthComponent = commander.get_node("Health")

	e_health.take_damage(DamageInfo.new(7))
	var item := _last()
	assert_true(item.amount == 7 and item.kind == DamageNumberLayer.Kind.NORMAL, "enemy hit shows a normal number")
	assert_true(layer._labels[_last_index()].label_settings.font_color.is_equal_approx(DamageNumberLayer.COLORS[DamageNumberLayer.Kind.NORMAL]), "normal number is white")
	var jitter: Vector3 = item.world - (enemy.global_position + DamageNumberLayer.HEAD_OFFSET)
	assert_true(absf(jitter.x) <= 0.3 and absf(jitter.z) <= 0.3, "random offset within 0.3 m")

	c_health.take_damage(DamageInfo.new(5))
	assert_true(_last().kind == DamageNumberLayer.Kind.COMMANDER, "commander hit shows a red number")

	c_health.hp = 50
	layer._last_hp[c_health] = 50
	for k in 6:
		c_health.heal(1)
		await get_tree().create_timer(0.05, true, false, true).timeout
	assert_true(_count(DamageNumberLayer.Kind.HEAL) == 0, "no heal number before the tick")
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_true(_count(DamageNumberLayer.Kind.HEAL) == 1 and layer._labels[_last_index()].text == "+6",
		"heal stopped early still shows its total +6 at the tick")

	await get_tree().create_timer(0.9, true, false, true).timeout
	for k in 22:
		c_health.heal(1)
		await get_tree().create_timer(0.05, true, false, true).timeout
	var ticks := _count(DamageNumberLayer.Kind.HEAL)
	assert_true(ticks >= 2 and ticks <= 3, "steady healing shows one number per 0.5 s tick (%d)" % ticks)
	await get_tree().create_timer(0.6, true, false, true).timeout

	layer.show_number(enemy, 3, DamageNumberLayer.Kind.RESIST)
	assert_true(layer._labels[_last_index()].text.ends_with(tr("fbk.resist")), "RESIST tag shown")
	layer.show_number(enemy, 0, DamageNumberLayer.Kind.IMMUNE)
	assert_true(layer._labels[_last_index()].text == tr("fbk.immune"), "IMMUNE tag shown")

	var tower := Tower.new()
	var before := layer.active_count()
	e_health.take_damage(DamageInfo.new(10, Enums.DamageType.PIERCE, tower))
	e_health.take_damage(DamageInfo.new(12, Enums.DamageType.PIERCE, tower))
	assert_true(layer.active_count() == before + 1 and _last().amount == 22, "two tower hits within 0.2 s merge into 22")

	await get_tree().create_timer(0.3, true, false, true).timeout
	before = layer.active_count()
	e_health.take_damage(DamageInfo.new(10, Enums.DamageType.PIERCE, tower))
	assert_true(layer.active_count() == before + 1 and _last().amount == 10, "a hit after 0.2 s starts a new number")

	for i in 100:
		layer.show_number(enemy, i + 1)
	assert_true(layer.active_count() == 60 and layer.get_child_count() == 60, "never more than 60 numbers")

	await get_tree().create_timer(1.0, true, false, true).timeout
	assert_true(layer.active_count() == 0, "numbers fade out")

	layer.enabled = false
	e_health.take_damage(DamageInfo.new(5))
	assert_true(layer.active_count() == 0, "nothing shows when disabled")

	tower.free()
	print("=======================================================")
	print("TEST SUMMARY: %d PASSED, %d FAILED" % [passes, fails])
	print("=======================================================\n")
	if quit_when_done and DisplayServer.get_name() == "headless":
		get_tree().quit(0 if fails == 0 else 1)
		return

	enemy.queue_free()
	commander.queue_free()
	layer.enabled = true
	_demo(cam)

## Visual check: one dummy per kind, spread along a row, each firing on its own beat forever.
func _demo(cam: Camera3D) -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 14.0
	cam.position = Vector3(0, 12, 12)
	cam.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	add_child(light)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 40)
	ground.mesh = plane
	ground.material_override = preload("res://art/materials/env_grass.tres")
	add_child(ground)

	var names := ["Thường", "Chỉ huy", "Hồi máu (0.5 s)", "RESIST", "IMMUNE", "Tower gộp 0.2 s"]
	var dummies: Array[Node3D] = []
	for i in names.size():
		var d := _target(&"commander" if i == 1 else &"enemy", Vector3(-10 + i * 4, 0, 0))
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1, 1.6, 1)
		body.mesh = box
		body.position.y = 0.8
		d.add_child(body)
		var caption := Label3D.new()
		caption.text = names[i]
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.position = Vector3(0, 0.2, 1.4)
		caption.font_size = 40
		caption.modulate = Color.BLACK
		d.add_child(caption)
		dummies.append(d)
	await get_tree().process_frame

	var tower := Tower.new()
	var healths: Array[HealthComponent] = []
	for d in dummies:
		healths.append(d.get_node("Health"))
	_drip_heal(healths[2])
	while is_inside_tree():
		for h in healths:
			h.hp = 50
			layer._last_hp[h] = 50
		healths[0].take_damage(DamageInfo.new(randi_range(5, 30)))
		healths[1].take_damage(DamageInfo.new(randi_range(5, 20)))
		layer.show_number(dummies[3], randi_range(2, 10), DamageNumberLayer.Kind.RESIST)
		layer.show_number(dummies[4], 0, DamageNumberLayer.Kind.IMMUNE)
		# Four hits 0.04 s apart from one tower land as a single "40".
		for k in 4:
			healths[5].take_damage(DamageInfo.new(10, Enums.DamageType.PIERCE, tower))
			await get_tree().create_timer(0.04).timeout
		await get_tree().create_timer(0.9).timeout

## 1 HP every 0.05 s like the heal station, stopping mid-tick so the wait-for-tick case shows too.
func _drip_heal(h: HealthComponent) -> void:
	while is_inside_tree():
		h.hp = 50
		layer._last_hp[h] = 50
		for k in 14:
			h.heal(1)
			await get_tree().create_timer(0.05).timeout
		await get_tree().create_timer(0.6).timeout

func _target(group: StringName, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.add_to_group(group)
	n.position = pos
	var h := HealthComponent.new()
	h.name = "Health"
	h.max_hp = 100
	n.add_child(h)
	add_child(n)
	return n

func _last_index() -> int:
	var best := -1
	var best_born := -INF
	for i in layer._items.size():
		var it: Dictionary = layer._items[i]
		if not it.is_empty() and it.born >= best_born:
			best_born = it.born
			best = i
	return best

func _count(kind: DamageNumberLayer.Kind) -> int:
	var n := 0
	for it in layer._items:
		if not it.is_empty() and it.kind == kind:
			n += 1
	return n

func _last() -> Dictionary:
	return layer._items[_last_index()]

func assert_true(cond: bool, test_name: String) -> void:
	if cond:
		passes += 1
		print("  [PASS] %s" % test_name)
	else:
		fails += 1
		printerr("  [FAIL] %s" % test_name)
