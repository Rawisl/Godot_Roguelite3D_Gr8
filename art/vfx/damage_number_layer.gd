class_name DamageNumberLayer
extends Control
## Floating damage numbers over enemies and the commander, from a fixed pool of labels.
## Hits from the same tower on the same target within MERGE_TIME add up into one number.
## Heals add up per target and show as one "+N" every HEAL_TICK, counted from the first heal;
## if healing stops before the tick, the total still shows at the tick.
## Runs on pausable real time like the HP bars: not sped up at x2/x3, frozen while paused.

enum Kind { NORMAL, RESIST, IMMUNE, COMMANDER, HEAL }

const MAX_NUMBERS := 60
const MERGE_TIME := 0.2
const HEAL_TICK := 0.5
const LIFE := 0.8
const RISE := 1.2
const JITTER := 0.3
const HEAD_OFFSET := Vector3(0, 2.0, 0)
const COLORS := {
	Kind.NORMAL: Color("#FFFFFF"),
	Kind.RESIST: Color("#C8C8C8"),
	Kind.IMMUNE: Color("#C8C8C8"),
	Kind.COMMANDER: Color("#E04545"),
	Kind.HEAL: Color("#9CFF6A"),
}

## Off when the player disables damage numbers in Settings.
@export var enabled := true

var _labels: Array[Label] = []
var _items: Array[Dictionary] = []  # one per label: world, born, amount, kind, key
var _merge: Dictionary = {}  # [target, tower] -> label index, while inside MERGE_TIME
var _last_hp: Dictionary = {}  # HealthComponent -> hp, to spot heals
var _heal_pending: Dictionary = {}  # target -> {amount, due}, healed since the last "+N"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var settings := LabelSettings.new()
	settings.font_size = 26
	settings.outline_size = 8
	settings.outline_color = Color(0, 0, 0, 1)
	for i in MAX_NUMBERS:
		var label := Label.new()
		label.label_settings = settings.duplicate()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.visible = false
		add_child(label)
		_labels.append(label)
		_items.append({})
	get_tree().node_added.connect(_on_node_added)
	for h in get_tree().root.find_children("*", "HealthComponent", true, false):
		_on_node_added(h)


func _on_node_added(node: Node) -> void:
	var health := node as HealthComponent
	if health == null or health.damaged.is_connected(_on_damaged):
		return
	var owner_node := health.get_parent() as Node3D
	if owner_node == null or not (owner_node.is_in_group(&"enemy") or owner_node.is_in_group(&"commander") or owner_node is Enemy):
		return
	health.damaged.connect(_on_damaged.bind(owner_node))
	health.hp_changed.connect(_on_hp_changed.bind(health, owner_node))
	health.tree_exiting.connect(func() -> void: _last_hp.erase(health))
	_last_hp[health] = health.hp if health.hp > 0 else health.max_hp


func _on_damaged(amount: int, info: DamageInfo, target: Node3D) -> void:
	var kind := Kind.COMMANDER if target.is_in_group(&"commander") else Kind.NORMAL
	var tower: Node = info.source if info != null and info.source is Tower else null
	show_number(target, amount, kind, tower)


func _on_hp_changed(hp: int, _max_hp: int, health: HealthComponent, target: Node3D) -> void:
	var before: int = _last_hp.get(health, hp)
	_last_hp[health] = hp
	if hp <= before:
		return
	var pending: Dictionary = _heal_pending.get(target, {})
	if pending.is_empty():
		pending = {"amount": 0, "due": TimeManager.pausable_real_time + HEAL_TICK}
		_heal_pending[target] = pending
	pending.amount += hp - before


func _flush_heals(now: float) -> void:
	for target in _heal_pending.keys():
		var pending: Dictionary = _heal_pending[target]
		if not is_instance_valid(target):
			_heal_pending.erase(target)
		elif now >= pending.due:
			_heal_pending.erase(target)
			show_number(target, pending.amount, Kind.HEAL)


## Shows a number above target. Pass the tower as merge_source to add up its hits within MERGE_TIME.
## RESIST adds the "RESIST" tag; IMMUNE shows only the "IMMUNE" tag.
func show_number(target: Node3D, amount: int, kind: Kind = Kind.NORMAL, merge_source: Node = null) -> void:
	if not enabled or not is_instance_valid(target):
		return
	var now := TimeManager.pausable_real_time
	if merge_source != null:
		var key := [target, merge_source]
		var idx: int = _merge.get(key, -1)
		if idx >= 0 and _items[idx].get("key") == key and now - _items[idx].born_merge <= MERGE_TIME:
			_items[idx].amount += amount
			_items[idx].born_merge = now
			_items[idx].born = now
			_set_text(idx)
			return
	var slot := _free_slot(now)
	var offset := Vector3(randf_range(-JITTER, JITTER), 0, randf_range(-JITTER, JITTER))
	_items[slot] = {
		"world": target.global_position + HEAD_OFFSET + offset,
		"born": now,
		"born_merge": now,
		"amount": amount,
		"kind": kind,
		"key": [target, merge_source] if merge_source != null else null,
	}
	if merge_source != null:
		_merge[[target, merge_source]] = slot
	_labels[slot].label_settings.font_color = COLORS[kind]
	_set_text(slot)


func active_count() -> int:
	var n := 0
	for item in _items:
		if not item.is_empty():
			n += 1
	return n


func _set_text(idx: int) -> void:
	var item: Dictionary = _items[idx]
	match item.kind:
		Kind.IMMUNE:
			_labels[idx].text = tr("fbk.immune")
		Kind.RESIST:
			_labels[idx].text = "%d %s" % [item.amount, tr("fbk.resist")]
		Kind.HEAL:
			_labels[idx].text = "+%d" % item.amount
		_:
			_labels[idx].text = str(item.amount)


## A free label, or the oldest one when all 60 are in use.
func _free_slot(now: float) -> int:
	var oldest := 0
	var oldest_born := INF
	for i in _items.size():
		if _items[i].is_empty() or now - _items[i].born > LIFE:
			_release(i)
			return i
		if _items[i].born < oldest_born:
			oldest_born = _items[i].born
			oldest = i
	_release(oldest)
	return oldest


func _release(idx: int) -> void:
	var key = _items[idx].get("key")
	if key != null and _merge.get(key, -1) == idx:
		_merge.erase(key)
	_items[idx] = {}
	_labels[idx].visible = false


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var now := TimeManager.pausable_real_time
	_flush_heals(now)
	for i in _items.size():
		var item: Dictionary = _items[i]
		if item.is_empty():
			continue
		var t: float = (now - item.born) / LIFE
		if t > 1.0:
			_release(i)
			continue
		var world: Vector3 = item.world + Vector3.UP * RISE * t
		if cam == null or cam.is_position_behind(world):
			_labels[i].visible = false
			continue
		var label := _labels[i]
		label.position = cam.unproject_position(world) - label.size * 0.5
		label.modulate.a = 1.0 - maxf(0.0, t - 0.6) / 0.4
		label.visible = true
