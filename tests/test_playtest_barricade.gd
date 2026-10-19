extends Node3D
## Playtest for the Barricade (branch week3/barricade). Press F6 on this scene.
## Ground slot buttons cycle: empty (+) -> Barricade B1 -> B2 -> B3 -> ruined (x) -> empty.
## Markers show the 5 attack positions of every Barricade: green free, red taken.
## The stats line shows attackers per Barricade (max 5, TWR-06), Grunts waiting,
## how long attackers took to choose again after a Barricade fell (TWR-07) and stuck units.

const BARRICADE_SCENE := preload("res://entities/tower/barricade.tscn")
const BARRICADE_DATA := preload("res://data/towers/barricade.tres")
const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const BRUTE_SCENE := preload("res://entities/enemy/brute.tscn")
const SPAWN_POINT := Vector3(9.0, 0.0, 0.0)
const STUCK_SPEED := 0.3
const STUCK_TIME := 1.5

var _buttons: Dictionary = {}  # StringName -> Button
var _hold_prep := false
var _markers: Dictionary = {}  # Barricade instance id -> Array[MeshInstance3D]
var _mat_free: StandardMaterial3D
var _mat_taken: StandardMaterial3D
var _slow_time: Dictionary = {}  # Enemy instance id -> seconds below STUCK_SPEED
var _lost: Dictionary = {}
var _last_retarget := ""
var _max_retarget := 0.0

## The SlotManager is the level's Slots node (levels/corridor/slots_layout.tscn).
@onready var slot_manager: SlotManager = %Level.get_node("%Slots")
@onready var wave_manager: WaveManager = %WaveManager
@onready var enemy_root: Node3D = %Enemy
@onready var slot_rows: VBoxContainer = %SlotRows
@onready var actions: HBoxContainer = %Actions
@onready var wave_label: Label = %WaveLabel
@onready var stats_label: Label = %StatsLabel
@onready var call_button: Button = %CallButton


func _ready() -> void:
	_mat_free = _flat_mat(Color(0.2, 0.9, 0.3))
	_mat_taken = _flat_mat(Color(0.95, 0.2, 0.2))

	var row := HBoxContainer.new()
	slot_rows.add_child(row)
	for slot in slot_manager.get_slots_in_zone(Enums.SlotZone.GROUND):
		var b := _make_button("", _on_slot_button_pressed.bind(slot))
		b.custom_minimum_size = Vector2(84, 36)
		b.tooltip_text = "Click: build L1 -> L2 -> L3 -> ruin -> clear"
		row.add_child(b)
		_buttons[slot.slot_id] = b
		_refresh_button(slot)

	actions.add_child(_make_button("Fill ground L1", _fill_ground))
	actions.add_child(_make_button("6 Grunts", _spawn_grunts.bind(6)))
	actions.add_child(_make_button("Brute", _spawn_brute))
	actions.add_child(_make_button("Ruin all", _ruin_all))
	var hold := _make_button("Hold PREP", func(): _hold_prep = not _hold_prep)
	hold.toggle_mode = true
	actions.add_child(hold)

	EventBus.slot_state_changed.connect(_on_slot_state_changed)
	call_button.pressed.connect(func(): EventBus.early_call_requested.emit())


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _process(delta: float) -> void:
	if _hold_prep and wave_manager.wave_state == Enums.WaveState.PREP:
		wave_manager.prep_timer = maxf(wave_manager.prep_timer, 5.0)

	var state: String = Enums.WaveState.keys()[wave_manager.wave_state]
	var text := "Wave %d  %s" % [wave_manager.current_wave, state]
	if wave_manager.wave_state == Enums.WaveState.PREP:
		text += "  %ds%s" % [ceili(maxf(0.0, wave_manager.prep_timer)), " (held)" if _hold_prep else ""]
	text += "  |  alive %d  queue %d" % [wave_manager.enemies_alive, wave_manager.spawn_queue.size()]
	wave_label.text = text
	call_button.disabled = wave_manager.wave_state != Enums.WaveState.PREP

	_update_markers()
	_track_retarget(delta)
	stats_label.text = _stats_text(delta)


#region Slots
func _on_slot_button_pressed(slot: Slot) -> void:
	if slot.state == Enums.SlotState.OCCUPIED:
		if slot.tower.level < slot.tower.data.levels.size():
			slot.tower.apply_level(slot.tower.level + 1)
			EventBus.tower_upgraded.emit(slot.slot_id, BARRICADE_DATA.id, slot.tower.level)
		else:
			slot.ruin()
		_refresh_button(slot)
		return
	if slot.state == Enums.SlotState.RUINED:
		slot.clear_tower()
		return
	_build(slot)


func _build(slot: Slot) -> void:
	if not slot.can_build(BARRICADE_DATA):
		push_warning("Playtest: Barricade is not allowed on slot %s" % slot.slot_id)
		return
	var t := BARRICADE_SCENE.instantiate() as Barricade
	slot.place_tower(t)
	t.destroyed.connect(_on_barricade_destroyed)
	EventBus.tower_built.emit(slot.slot_id, BARRICADE_DATA.id)
	_refresh_button(slot)


func _fill_ground() -> void:
	for slot in slot_manager.get_slots_in_zone(Enums.SlotZone.GROUND):
		if slot.is_free():
			if slot.state == Enums.SlotState.RUINED:
				slot.clear_tower()
			_build(slot)


func _ruin_all() -> void:
	for slot in slot_manager.get_slots_in_zone(Enums.SlotZone.GROUND):
		if slot.state == Enums.SlotState.OCCUPIED:
			slot.tower.take_damage(100000)


func _on_slot_state_changed(slot_id: StringName, _state: StringName) -> void:
	var slot := slot_manager.get_slot(slot_id)
	if slot != null:
		_refresh_button(slot)


func _refresh_button(slot: Slot) -> void:
	var b: Button = _buttons.get(slot.slot_id)
	if b == null:
		return
	var mark := "+"
	match slot.state:
		Enums.SlotState.OCCUPIED:
			mark = "B%d" % slot.tower.level
		Enums.SlotState.RUINED:
			mark = "x"
	b.text = "%s  %s" % [slot.slot_id, mark]
#endregion


#region Enemies
func _spawn(scene: PackedScene, pos: Vector3) -> Enemy:
	var g := scene.instantiate() as Enemy
	g.position = pos
	enemy_root.add_child(g)
	g.spawn_grace = false
	g.is_in_spawn_zone = false
	g.change_state(Enums.EnemyState.ADVANCE)
	return g


func _spawn_grunts(count: int) -> void:
	for i in count:
		_spawn(GRUNT_SCENE, SPAWN_POINT + Vector3((i % 3) * 0.8, 0.0, floorf(i / 3.0) * 0.8 - 0.4))


## Brute only targets the Fortress: shows it walking past Barricades without hitting them.
func _spawn_brute() -> void:
	_spawn(BRUTE_SCENE, SPAWN_POINT)
#endregion


#region Overlay and stats
func _barricades() -> Array[Barricade]:
	var out: Array[Barricade] = []
	for n in get_tree().get_nodes_in_group(&"barricade"):
		var b := n as Barricade
		if b != null and is_instance_valid(b) and b.health.hp > 0:
			out.append(b)
	return out


func _update_markers() -> void:
	var alive := {}
	for b in _barricades():
		var id := b.get_instance_id()
		alive[id] = true
		if not _markers.has(id):
			var made: Array[MeshInstance3D] = []
			for p in b.melee_slots.get_world_points():
				var mi := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.25
				mesh.bottom_radius = 0.25
				mesh.height = 0.05
				mi.mesh = mesh
				mi.position = p + Vector3(0, 0.04, 0)
				add_child(mi)
				made.append(mi)
			_markers[id] = made
		var taken := _taken_points(b)
		var list: Array = _markers[id]
		for i in list.size():
			(list[i] as MeshInstance3D).material_override = _mat_taken if taken.has(i) else _mat_free
	for id in _markers.keys():
		if not alive.has(id):
			for mi in _markers[id]:
				(mi as Node).queue_free()
			_markers.erase(id)


## Indices of the attack positions held by a unit.
func _taken_points(b: Barricade) -> Dictionary:
	var out := {}
	var pts := b.melee_slots.get_world_points()
	for e in get_tree().get_nodes_in_group(&"enemy"):
		var en := e as Enemy
		if en != null and b.has_melee_slot(en):
			var p := b.get_melee_slot_position(en)
			for i in pts.size():
				if pts[i].is_equal_approx(p):
					out[i] = true
	return out


func _on_barricade_destroyed(t: Tower) -> void:
	for e in get_tree().get_nodes_in_group(&"enemy"):
		var en := e as Enemy
		if en != null and en.current_target == t:
			_lost[en] = 0.0


## TWR-07: time from the Barricade falling until each of its attackers has a new target.
func _track_retarget(delta: float) -> void:
	for en in _lost.keys():
		if not is_instance_valid(en):
			_lost.erase(en)
			continue
		_lost[en] += delta
		# The old target may already be freed: check it before any typed use.
		var moved_on: bool = en.has_target_position
		if not moved_on and is_instance_valid(en.current_target):
			var t: Node3D = en.current_target
			moved_on = not (t is Barricade and (t as Barricade).health.hp <= 0)
		if moved_on:
			_max_retarget = maxf(_max_retarget, _lost[en])
			_last_retarget = "%.2f s (worst %.2f s)" % [_lost[en], _max_retarget]
			_lost.erase(en)


func _stats_text(delta: float) -> String:
	var parts := PackedStringArray()
	for b in _barricades():
		var used := GameConfig.max_attackers_per_barricade - b.get_free_melee_slots()
		parts.append("%s %d/5 hp %d" % [b.get_parent().get_parent().name, used, b.health.hp])
	var waiting := 0
	var stuck := 0
	for e in get_tree().get_nodes_in_group(&"enemy"):
		var en := e as Enemy
		if en == null or en.is_dead:
			continue
		if en.current_state == Enums.EnemyState.WAIT:
			waiting += 1
		var walking := en.current_state == Enums.EnemyState.ADVANCE or en.current_state == Enums.EnemyState.CHASE
		var id := en.get_instance_id()
		if walking and Vector2(en.velocity.x, en.velocity.z).length() < STUCK_SPEED:
			_slow_time[id] = _slow_time.get(id, 0.0) + delta
		else:
			_slow_time[id] = 0.0
		if _slow_time[id] >= STUCK_TIME:
			stuck += 1
	var s := "Barricades: " + ("  |  ".join(parts) if not parts.is_empty() else "none")
	s += "\nWAIT %d   Stuck walking > %.1f s: %d (expect 0)" % [waiting, STUCK_TIME, stuck]
	s += "\nRetarget after a Barricade fell: " + (_last_retarget if _last_retarget != "" else "-")
	return s
#endregion
