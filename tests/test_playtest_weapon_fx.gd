extends Node3D
## Playable look at the weapon models and their effects. Run with F6.
## The commander stands on the level's grass in front of three Grunts pinned to their spots that
## never die; pick a weapon with the buttons on the left (no PREP needed) and attack them. The HP buttons walk Rampage through its
## bands, and "Reduce flashing" toggles the accessibility setting.

const GRUNT_SCENE := preload("res://entities/enemy/grunt.tscn")
const WEAPONS: Array[StringName] = [&"sword_base", &"frost", &"chain_lightning", &"burn", &"rampage", &"swift"]
const GRUNT_POSITIONS: Array[Vector3] = [Vector3(0, 0, -2.0), Vector3(1.4, 0, -2.6), Vector3(-1.4, 0, -2.6)]

@onready var _commander: Node3D = $Commander

var _run_state: RunState
var _status: Label
var _grunts: Array[Enemy] = []


func _ready() -> void:
	process_physics_priority = 100
	_run_state = RunState.new()
	add_child(_run_state)
	for id in WEAPONS:
		_run_state.grant_weapon(id)
	add_child(HitFxManager.new())
	add_child(WeaponFxManager.new())
	for pos in GRUNT_POSITIONS:
		_spawn_grunt(pos)
	_commander.health.invulnerable = true
	_build_ui()
	_equip.call_deferred(&"sword_base")


func _process(_delta: float) -> void:
	# The dummies stay put and never die, so the effects can be watched as long as needed.
	for i in _grunts.size():
		var grunt := _grunts[i]
		if not is_instance_valid(grunt) or grunt.is_dead:
			_grunts[i] = _spawn_grunt(GRUNT_POSITIONS[i], false)
			continue
		grunt.health.hp = grunt.health.max_hp
	if _status != null:
		var health: HealthComponent = _commander.health
		_status.text = "Equipped: %s\nCommander HP: %d / %d\nChain cooldown: %.1f s" % [
			_run_state.equipped_weapon, health.hp, health.max_hp, _run_state.chain_cd]


## Runs after the enemies' own physics step, so walking and knockback never move them.
func _physics_process(_delta: float) -> void:
	for i in _grunts.size():
		var grunt := _grunts[i]
		if is_instance_valid(grunt) and not grunt.is_dead:
			grunt.velocity = Vector3.ZERO
			grunt.global_position = GRUNT_POSITIONS[i]


func _spawn_grunt(pos: Vector3, append := true) -> Enemy:
	var grunt := GRUNT_SCENE.instantiate() as Enemy
	grunt.position = pos
	add_child(grunt)
	grunt.speed_multiplier = 0.0
	grunt.spawn_grace = false
	grunt.health.max_hp = 99999
	grunt.health.hp = 99999
	if append:
		_grunts.append(grunt)
	return grunt


## Equips without the PREP rule: this scene is only for looking at the weapons.
func _equip(id: StringName) -> void:
	_run_state.equipped_weapon = id
	EventBus.weapon_equipped.emit(id)


func _set_hp_share(share: float) -> void:
	var health: HealthComponent = _commander.health
	health.hp = maxi(1, roundi(health.max_hp * share))
	health.hp_changed.emit(health.hp, health.max_hp)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "WEAPON FX PLAYTEST\nWASD move, left click attack"
	box.add_child(title)
	for id in WEAPONS:
		_add_button(box, String(id), _equip.bind(id))
	box.add_child(HSeparator.new())
	for share in [1.0, 0.7, 0.4, 0.2]:
		_add_button(box, "Commander HP %d%%" % int(share * 100), _set_hp_share.bind(share))
	var flash := CheckButton.new()
	flash.text = "Reduce flashing"
	flash.focus_mode = Control.FOCUS_NONE
	flash.button_pressed = GameState.get_setting(&"reduce_flash", false) == true
	flash.toggled.connect(func(on: bool) -> void: EventBus.settings_changed.emit(&"reduce_flash", on))
	box.add_child(flash)
	box.add_child(HSeparator.new())
	_status = Label.new()
	box.add_child(_status)


func _add_button(box: Container, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	box.add_child(button)
