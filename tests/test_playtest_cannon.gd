extends Node3D
## Playtest for the Cannon tower (branch week3/cannon-tower). Press F6 on this scene.
## Slot buttons cycle: empty (+) -> Cannon C1 -> C2 -> C3 -> ruined (x) -> empty.
## Each blast draws its radius on the ground; the stats line counts shots, hits,
## damage, STAGGER (must stay 0, PRJ-08) and blast damage on towers (must stay 0, PRJ-03).

const CANNON_SCENE := preload("res://entities/tower/cannon.tscn")
const CANNON_DATA := preload("res://data/towers/cannon.tres")
const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const CLUSTER_CENTER := Vector3(8.0, 0.0, 0.0)
const RING_TIME := 0.6

var _buttons: Dictionary = {}  # StringName -> Button
var _hold_prep := false
var _stats := {
	"shots": 0, "blasts": 0, "hits": 0, "damage": 0, "max_hit": 0,
	"stagger": 0, "tower_blast_dmg": 0,
}
var _last_blast := ""
var _prev_state: Dictionary = {}  # Enemy instance id -> EnemyState
var _near_grunt: Enemy = null
var _near_cannon: Tower = null
var _ring_mat: StandardMaterial3D

## The SlotManager is the level's Slots node (levels/corridor/slots_layout.tscn).
@onready var slot_manager: SlotManager = $Level/Slots
@onready var wave_manager: WaveManager = %WaveManager
@onready var pool: ProjectilePool = %ProjectilePool
@onready var enemy_root: Node3D = %Enemy
@onready var slot_rows: VBoxContainer = %SlotRows
@onready var actions: HBoxContainer = %Actions
@onready var wave_label: Label = %WaveLabel
@onready var stats_label: Label = %StatsLabel
@onready var call_button: Button = %CallButton


func _ready() -> void:
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(1.0, 0.55, 0.1, 0.45)
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for zone in [Enums.SlotZone.WALL, Enums.SlotZone.GROUND]:
		var row := HBoxContainer.new()
		slot_rows.add_child(row)
		for slot in slot_manager.get_slots_in_zone(zone):
			var b := _make_button("", _on_slot_button_pressed.bind(slot))
			b.custom_minimum_size = Vector2(84, 36)
			b.tooltip_text = "Click: build L1 -> L2 -> L3 -> ruin -> clear"
			row.add_child(b)
			_buttons[slot.slot_id] = b
			_refresh_button(slot)

	actions.add_child(_make_button("Fill ground L1", _fill_ground))
	actions.add_child(_make_button("Spawn 10-Grunt cluster", _spawn_cluster))
	actions.add_child(_make_button("Grunt inside 4 m", _spawn_near))
	var hold := _make_button("Hold PREP", func(): _hold_prep = not _hold_prep)
	hold.toggle_mode = true
	actions.add_child(hold)
	actions.add_child(_make_button("Reset stats", _reset_stats))

	EventBus.slot_state_changed.connect(_on_slot_state_changed)
	EventBus.projectile_hit.connect(_on_projectile_hit)
	call_button.pressed.connect(func(): EventBus.early_call_requested.emit())


func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _process(_delta: float) -> void:
	if _hold_prep and wave_manager.wave_state == Enums.WaveState.PREP:
		wave_manager.prep_timer = maxf(wave_manager.prep_timer, 5.0)
	_hook_new_shells()

	var state: String = Enums.WaveState.keys()[wave_manager.wave_state]
	var text := "Wave %d  %s" % [wave_manager.current_wave, state]
	if wave_manager.wave_state == Enums.WaveState.PREP:
		text += "  %ds%s" % [ceili(maxf(0.0, wave_manager.prep_timer)), " (held)" if _hold_prep else ""]
	text += "  |  alive %d  queue %d" % [wave_manager.enemies_alive, wave_manager.spawn_queue.size()]
	wave_label.text = text
	call_button.disabled = wave_manager.wave_state != Enums.WaveState.PREP

	var avg: float = float(_stats.hits) / _stats.blasts if _stats.blasts > 0 else 0.0
	var s := "Shots %d  Blasts %d  Hits %d (%.1f / blast)  Damage %d  Max hit %d" % [
		_stats.shots, _stats.blasts, _stats.hits, avg, _stats.damage, _stats.max_hit]
	s += "\nSTAGGER seen %d (expect 0, PRJ-08)   Blast damage on towers %d (expect 0, PRJ-03)" % [
		_stats.stagger, _stats.tower_blast_dmg]
	s += "   Shells in flight %d" % pool.active_count()
	if _last_blast != "":
		s += "\nLast blast: " + _last_blast
	if _near_grunt != null and is_instance_valid(_near_grunt) and _near_cannon != null and is_instance_valid(_near_cannon):
		var d := Vector2(_near_grunt.global_position.x - _near_cannon.global_position.x,
				_near_grunt.global_position.z - _near_cannon.global_position.z).length()
		s += "\nGrunt %.1f m from %s: targeted = %s (TGT-05: ignored while < 4 m)" % [
			d, _near_cannon.get_parent().get_parent().name, str(_near_cannon.target == _near_grunt)]
	stats_label.text = s


func _physics_process(_delta: float) -> void:
	# PRJ-08: count every entry into STAGGER while Cannons fire.
	for node in get_tree().get_nodes_in_group(&"enemy"):
		var e := node as Enemy
		if e == null:
			continue
		var id := e.get_instance_id()
		var prev: int = _prev_state.get(id, -1)
		if e.current_state == Enums.EnemyState.STAGGER and prev != Enums.EnemyState.STAGGER:
			_stats.stagger += 1
		_prev_state[id] = e.current_state


#region Slots
func _on_slot_button_pressed(slot: Slot) -> void:
	if slot.state == Enums.SlotState.OCCUPIED:
		if slot.tower.level < slot.tower.data.levels.size():
			_set_level(slot.tower, slot.tower.level + 1)
			EventBus.tower_upgraded.emit(slot.slot_id, CANNON_DATA.id, slot.tower.level)
		else:
			slot.ruin()
		_refresh_button(slot)
		return
	if slot.state == Enums.SlotState.RUINED:
		slot.clear_tower()
		return
	_build(slot)


func _build(slot: Slot) -> void:
	if not slot.can_build(CANNON_DATA):
		push_warning("Playtest: Cannon is not allowed on slot %s" % slot.slot_id)
		return
	var t := CANNON_SCENE.instantiate() as Tower
	slot.place_tower(t)
	t.shot_started.connect(func(_target): _stats.shots += 1)
	t.health.damaged.connect(func(amount: int, info: DamageInfo):
		if info != null and info.damage_type == Enums.DamageType.BLAST:
			_stats.tower_blast_dmg += amount)
	EventBus.tower_built.emit(slot.slot_id, CANNON_DATA.id)
	_refresh_button(slot)


func _set_level(t: Tower, lv: int) -> void:
	t.apply_level(lv)
	# The model shows one mesh per level (Level1..Level3).
	for i in range(1, 4):
		var n := t.find_child("Level%d" % i, true, false) as Node3D
		if n != null:
			n.visible = i == lv


func _fill_ground() -> void:
	for slot in slot_manager.get_slots_in_zone(Enums.SlotZone.GROUND):
		if slot.is_free():
			if slot.state == Enums.SlotState.RUINED:
				slot.clear_tower()
			_build(slot)


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
			mark = "C%d" % slot.tower.level
		Enums.SlotState.RUINED:
			mark = "x"
	b.text = "%s  %s" % [slot.slot_id, mark]
#endregion


#region Enemies
func _spawn_grunt(pos: Vector3) -> Enemy:
	var g := GRUNT_SCENE.instantiate() as Enemy
	g.position = pos
	enemy_root.add_child(g)
	g.spawn_grace = false
	g.is_in_spawn_zone = false
	g.change_state(Enums.EnemyState.ADVANCE)
	return g


## Test 7.1 #12: a tight group so one shell hits several Grunts at once.
func _spawn_cluster() -> void:
	for i in 10:
		_spawn_grunt(CLUSTER_CENTER + Vector3((i % 5) * 0.6, 0.0, floorf(i / 5.0) * 0.6 - 0.3))


## TGT-05: a Grunt 2.5 m from the first ground Cannon must not be targeted by it.
func _spawn_near() -> void:
	for slot in slot_manager.get_slots_in_zone(Enums.SlotZone.GROUND):
		if slot.state == Enums.SlotState.OCCUPIED:
			_near_cannon = slot.tower
			_near_grunt = _spawn_grunt(slot.global_position + Vector3(2.5, 0.0, 0.0))
			return
	push_warning("Playtest: build a Cannon on a ground slot first")
#endregion


#region Blast overlay
func _hook_new_shells() -> void:
	for child in pool.get_children():
		var p := child as CannonProjectile
		if p != null and not p.exploded.is_connected(_on_exploded):
			p.exploded.connect(_on_exploded)


var _blast_hits: PackedStringArray = []

func _on_projectile_hit(_target: Node, amount: int, damage_type: StringName, _resist: float) -> void:
	if damage_type != &"BLAST":
		return
	_stats.damage += amount
	_stats.max_hit = maxi(_stats.max_hit, amount)
	_blast_hits.append(str(amount))


func _on_exploded(center: Vector3, radius: float, hits: int) -> void:
	_stats.blasts += 1
	_stats.hits += hits
	_last_blast = "r %.1f m, %d hit%s %s" % [radius, hits, "" if hits == 1 else "s",
			("(" + ", ".join(_blast_hits) + ")") if hits > 0 else ""]
	_blast_hits.clear()
	_draw_ring(center, radius)


func _draw_ring(center: Vector3, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.radial_segments = 48
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _ring_mat.duplicate()
	mi.position = Vector3(center.x, 0.05, center.z)
	add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, RING_TIME)
	tw.tween_callback(mi.queue_free)
#endregion


func _reset_stats() -> void:
	for k in _stats:
		_stats[k] = 0
	_last_blast = ""
