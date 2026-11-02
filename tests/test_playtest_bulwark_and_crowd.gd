class_name TestPlaytestBulwarkAndCrowd
extends Node3D

const BULWARK_SCENE: PackedScene = preload("res://entities/enemy/bulwark.tscn")
const GRUNT_SCENE: PackedScene = preload("res://entities/enemy/grunt.tscn")
const ARCHER_SCENE: PackedScene = preload("res://entities/enemy/archer.tscn")
const BRUTE_SCENE: PackedScene = preload("res://entities/enemy/brute.tscn")

@onready var level: Node3D = %Level
@onready var wave_manager: WaveManager = %WaveManager
@onready var commander: CharacterBody3D = %Commander
@onready var enemy_container: Node3D = %Enemy

@onready var status_label: Label = %StatusLabel
@onready var log_text: RichTextLabel = %LogText

var _bulwark_instance: Bulwark = null
var _fortress: Node3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_fortress_reference()
	_setup_ui_connections()
	_connect_event_bus()
	_setup_initial_positions()
	_disable_auto_wave_spawning()
	_log_event("Bulwark & Crowd Playtest initialized.")


func _disable_auto_wave_spawning() -> void:
	if wave_manager == null:
		return
	wave_manager.set_physics_process(false)
	wave_manager.auto_advance_summary = false
	wave_manager.spawn_queue.clear()
	wave_manager.prep_timer = 999999.0


func _setup_ui_connections() -> void:
	_connect_button("%BtnSpawnBulwark", spawn_bulwark_boss)
	_connect_button("%BtnTriggerStomp", trigger_bulwark_stomp)
	_connect_button("%BtnTogglePhase", toggle_bulwark_phase)
	_connect_button("%BtnDamagePierce", func(): test_damage_bulwark(Enums.DamageType.PIERCE, 30))
	_connect_button("%BtnDamageMagic", func(): test_damage_bulwark(Enums.DamageType.MAGIC, 30))
	_connect_button("%BtnDamageBlast", func(): test_damage_bulwark(Enums.DamageType.BLAST, 30))
	_connect_button("%BtnDamageSlash", func(): test_damage_bulwark(Enums.DamageType.SLASH, 30))
	_connect_button("%BtnKillBulwark", func(): test_damage_bulwark(Enums.DamageType.TRUE, 999999))

	_connect_button("%BtnToggleDodge", toggle_commander_dodge)
	_connect_button("%BtnToggleDeploy", toggle_commander_deploying)
	_connect_button("%BtnRecall", trigger_commander_recall)
	_connect_button("%BtnMoveCommander", move_commander_to_boss)
	_connect_button("%BtnHealCommander", heal_commander)

	_connect_button("%BtnSpawn20Grunts", func(): spawn_fortress_crowd(20))
	_connect_button("%BtnSpawnAllyNearBoss", spawn_ally_grunt_near_boss)
	_connect_button("%BtnKill1Attacker", kill_single_attacker)
	_connect_button("%BtnKnockbackAttacker", knockback_single_attacker)
	_connect_button("%BtnKillAllEnemies", kill_all_enemies)

	_connect_button("%BtnStartWave5", start_wave_5_combat)
	_connect_button("%BtnTriggerRewardPick", func(): trigger_reward_pick_simulation(2))
	_connect_button("%BtnPickCard1", func(): pick_reward_card(&"whirlwind", &"ACTIVE"))
	_connect_button("%BtnPickCard2", func(): pick_reward_card(&"vitality", &"STAT"))

	_connect_button("%BtnSpeed1", func(): Engine.time_scale = 1.0; _log_event("Speed: 1.0x"))
	_connect_button("%BtnSpeed2", func(): Engine.time_scale = 2.0; _log_event("Speed: 2.0x"))
	_connect_button("%BtnSpeed3", func(): Engine.time_scale = 3.0; _log_event("Speed: 3.0x"))


func _connect_button(path: String, callable: Callable) -> void:
	var btn := get_node_or_null(path) as Button
	if btn != null:
		btn.pressed.connect(callable)


func _setup_fortress_reference() -> void:
	_fortress = get_tree().get_first_node_in_group(&"fortress") as Node3D


func _setup_initial_positions() -> void:
	if commander != null:
		commander.global_position = Vector3(-6.0, 0.0, 0.0)


func _connect_event_bus() -> void:
	EventBus.telegraph_started.connect(_on_telegraph_started)
	EventBus.screen_shake_requested.connect(_on_screen_shake_requested)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.reward_picked.connect(_on_reward_picked)


func _process(_delta: float) -> void:
	_update_status_display()





func spawn_bulwark_boss() -> void:
	if _bulwark_instance != null and is_instance_valid(_bulwark_instance) and not _bulwark_instance.is_dead:
		_log_event("Bulwark already exists.")
		return

	_bulwark_instance = BULWARK_SCENE.instantiate() as Bulwark
	_bulwark_instance.position = Vector3(1.0, 0.0, 0.0)
	_bulwark_instance.spawn_grace = false
	_bulwark_instance.is_in_spawn_zone = false

	if enemy_container != null:
		enemy_container.add_child(_bulwark_instance)
	else:
		add_child(_bulwark_instance)

	_log_event("Bulwark spawned at (1.0, 0.0, 0.0).")


func trigger_bulwark_stomp() -> void:
	if _bulwark_instance == null or not is_instance_valid(_bulwark_instance) or _bulwark_instance.is_dead:
		_log_event("No active Bulwark to perform Stomp. Spawning one first...")
		spawn_bulwark_boss()

	_log_event("Bulwark started Stomp attack wind-up (1.0s).")
	_bulwark_instance._play_attack_anim()

	var timer := get_tree().create_timer(_bulwark_instance._get_attack_windup())
	timer.timeout.connect(func():
		if _bulwark_instance != null and is_instance_valid(_bulwark_instance) and not _bulwark_instance.is_dead:
			_bulwark_instance.execute_stomp()
			_log_event("Bulwark Stomp impacted! AoE: 3.0m.")
	)


func toggle_bulwark_phase() -> void:
	if _bulwark_instance == null or not is_instance_valid(_bulwark_instance) or _bulwark_instance.is_dead:
		_log_event("No active Bulwark to toggle phase.")
		return

	if _bulwark_instance.current_phase == Enums.BossPhase.ARMORED:
		_bulwark_instance.current_phase = Enums.BossPhase.EXPOSED
		_log_event("Bulwark switched to Phase: EXPOSED (Piercing/Magic vulnerabilities active).")
	else:
		_bulwark_instance.current_phase = Enums.BossPhase.ARMORED
		_log_event("Bulwark switched to Phase: ARMORED (Immune to Piercing & Magic).")


func test_damage_bulwark(type: Enums.DamageType, amount: int = 30) -> void:
	if _bulwark_instance == null or not is_instance_valid(_bulwark_instance) or _bulwark_instance.is_dead:
		_log_event("No active Bulwark to receive attack.")
		return

	var resist: float = _bulwark_instance.get_resist(type)
	var type_name: String = Enums.DamageType.keys()[type]
	var info := DamageInfo.new(amount, type, commander)
	_bulwark_instance.take_damage(info)
	_log_event("Hit Bulwark with %s (base: %d, resist: %.1f). Health left: %d" % [
		type_name, amount, resist, _bulwark_instance.health.hp
	])


func toggle_commander_dodge() -> void:
	if commander == null:
		return
	commander.is_dodging = not commander.is_dodging
	_log_event("Commander Dodge i-frame set to: %s" % str(commander.is_dodging))


func toggle_commander_deploying() -> void:
	if commander == null:
		return
	commander.is_deploying = not commander.is_deploying
	_log_event("Commander Deploying (knockback immunity) set to: %s" % str(commander.is_deploying))


func trigger_commander_recall() -> void:
	EventBus.recall_completed.emit()
	_log_event("Commander Recall completed event emitted. Enemies cleared aggro.")


func move_commander_to_boss() -> void:
	if commander == null or _bulwark_instance == null or not is_instance_valid(_bulwark_instance):
		return
	commander.global_position = _bulwark_instance.global_position + Vector3(1.5, 0.0, 0.0)
	_log_event("Commander moved into Bulwark melee range.")


func heal_commander() -> void:
	if commander != null and commander.health != null:
		commander.health.hp = commander.health.max_hp
		_log_event("Commander health restored to %d." % commander.health.max_hp)


func spawn_fortress_crowd(count: int = 20) -> void:
	var spawn_pos := Vector3(12.0, 0.0, 0.0)
	for i in range(count):
		var grunt := GRUNT_SCENE.instantiate() as Enemy
		var offset_z := ((i % 5) - 2) * 1.2
		var offset_x := floorf(float(i) / 5.0) * 1.5
		grunt.position = spawn_pos + Vector3(offset_x, 0.0, offset_z)
		grunt.spawn_grace = false
		grunt.is_in_spawn_zone = false

		if enemy_container != null:
			enemy_container.add_child(grunt)
		else:
			add_child(grunt)

	_log_event("Spawned %d Grunts toward Fortress." % count)


func spawn_ally_grunt_near_boss() -> void:
	if _bulwark_instance == null or not is_instance_valid(_bulwark_instance):
		spawn_bulwark_boss()

	var grunt := GRUNT_SCENE.instantiate() as Enemy
	grunt.position = _bulwark_instance.position + Vector3(1.0, 0.0, 1.0)
	grunt.spawn_grace = false
	grunt.is_in_spawn_zone = false

	if enemy_container != null:
		enemy_container.add_child(grunt)
	else:
		add_child(grunt)

	_log_event("Spawned ally Grunt 1.4m from Bulwark to verify friendly fire immunity.")


func kill_single_attacker() -> void:
	if _fortress == null:
		return
	var slots: MeleeSlotSet = _fortress.get_node_or_null("MeleeSlots") as MeleeSlotSet
	if slots == null:
		return

	var owners: Array = slots.get("_owners")
	for holder in owners:
		if holder != null and is_instance_valid(holder) and holder.has_method("take_damage"):
			holder.take_damage(DamageInfo.new(99999, Enums.DamageType.TRUE))
			_log_event("Killed active slot attacker. Checking waiter replacement...")
			return

	_log_event("No active slot attacker found to kill.")


func knockback_single_attacker() -> void:
	if _fortress == null:
		return
	var slots: MeleeSlotSet = _fortress.get_node_or_null("MeleeSlots") as MeleeSlotSet
	if slots == null:
		return

	var owners: Array = slots.get("_owners")
	for holder in owners:
		var node3d := holder as Node3D
		if node3d != null and is_instance_valid(node3d):
			node3d.global_position += Vector3(4.5, 0.0, 0.0)
			slots._audit()
			_log_event("Knocked attacker 4.5m away. Slot freed by audit.")
			return

	_log_event("No active slot attacker found to knock back.")


func kill_all_enemies() -> void:
	if wave_manager != null:
		wave_manager.set_physics_process(false)
		wave_manager.spawn_queue.clear()
		wave_manager.prep_timer = 999999.0
	var count := 0
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		var e := enemy as Enemy
		if e != null and is_instance_valid(e) and not e.is_dead:
			e.take_damage(DamageInfo.new(999999, Enums.DamageType.TRUE))
			count += 1
	_log_event("Killed %d active enemies." % count)


func start_wave_5_combat() -> void:
	if wave_manager == null:
		return
	wave_manager.set_physics_process(true)
	wave_manager.current_wave = 5
	wave_manager.start_combat()
	_log_event("Started Wave 5 Combat! State: %s" % Enums.WaveState.keys()[wave_manager.wave_state])


func trigger_reward_pick_simulation(picks: int = 2) -> void:
	if wave_manager == null:
		return
	var tracker := wave_manager.get("_xp_tracker") as Node
	if tracker != null:
		tracker.set("pending_picks", picks)
	wave_manager.wave_state = Enums.WaveState.SUMMARY
	wave_manager.advance_from_summary()
	_log_event("Advanced from SUMMARY into REWARD_PICK with %d pending picks." % picks)


func pick_reward_card(card_id: StringName, slot_kind: StringName) -> void:
	EventBus.reward_picked.emit(card_id, slot_kind, 1)
	_log_event("Card picked: %s (%s)." % [card_id, slot_kind])


func _cycle_time_scale() -> void:
	if Engine.time_scale <= 1.0:
		Engine.time_scale = 2.0
	elif Engine.time_scale <= 2.0:
		Engine.time_scale = 3.0
	else:
		Engine.time_scale = 1.0
	_log_event("Engine time scale set to: %.1fx" % Engine.time_scale)


func _update_status_display() -> void:
	if status_label == null:
		return

	var wave_info := "WAVE: %d (%s)" % [
		wave_manager.current_wave if wave_manager else 1,
		Enums.WaveState.keys()[wave_manager.wave_state] if wave_manager else "NONE"
	]
	var paused_info := "PAUSED: %s" % ("YES (Reward Pick)" if TimeManager.is_paused else "NO")

	var cmd_hp: int = int(commander.health.hp) if commander and commander.health else 0
	var cmd_dodge := "YES" if commander and commander.is_dodging else "NO"
	var cmd_deploy := "YES" if commander and commander.is_deploying else "NO"
	var cmd_stun := "YES" if commander and commander.is_stunned else "NO"
	var cmd_info := "COMMANDER: HP %d | Dodge: %s | Deploy: %s | Stun: %s" % [
		cmd_hp, cmd_dodge, cmd_deploy, cmd_stun
	]

	var boss_info := "BULWARK: Not Spawned"
	if _bulwark_instance != null and is_instance_valid(_bulwark_instance) and not _bulwark_instance.is_dead:
		var phase_str: String = "EXPOSED" if _bulwark_instance.current_phase == Enums.BossPhase.EXPOSED else "ARMORED"
		boss_info = "BULWARK: HP %d | Phase: %s | Pierce: %.1f | Magic: %.1f" % [
			_bulwark_instance.health.hp,
			phase_str,
			_bulwark_instance.get_resist(Enums.DamageType.PIERCE),
			_bulwark_instance.get_resist(Enums.DamageType.MAGIC)
		]

	var fortress_info := "FORTRESS SLOTS: None"
	if _fortress != null:
		var slots: MeleeSlotSet = _fortress.get_node_or_null("MeleeSlots") as MeleeSlotSet
		if slots != null:
			var owners: Array = slots.get("_owners")
			var total_slots: int = owners.size() if not owners.is_empty() else 12
			var free_slots: int = slots.free_count()
			var occupied: int = total_slots - free_slots
			var waiting: int = 0
			for e in get_tree().get_nodes_in_group(&"enemy"):
				var enemy := e as Enemy
				if enemy != null and is_instance_valid(enemy) and not enemy.is_dead and enemy.current_state == Enums.EnemyState.WAIT:
					waiting += 1
			fortress_info = "FORTRESS SLOTS: %d/%d Occupied | %d Waiting on Ring" % [occupied, total_slots, waiting]

	var tracker := wave_manager.get("_xp_tracker") as Node if wave_manager else null
	var pending_picks: int = tracker.get("pending_picks") if tracker else 0
	var picks_info := "PENDING PICKS: %d" % pending_picks

	status_label.text = "%s | %s | %s\n%s\n%s\n%s" % [
		wave_info, paused_info, picks_info, boss_info, fortress_info, cmd_info
	]


func _on_telegraph_started(shape: StringName, pos: Vector3, radius: float, duration: float) -> void:
	_log_event("[TELEGRAPH] %s ring at (%.1f, %.1f), r=%.1f, dur=%.1fs" % [shape, pos.x, pos.z, radius, duration])


func _on_screen_shake_requested(intensity: float, source: StringName) -> void:
	_log_event("[SHAKE] Screen shake intensity: %.2f (source: %s)" % [intensity, source])


func _on_state_changed(new_state: StringName) -> void:
	_log_event("[FSM] State changed to: %s" % new_state)


func _on_boss_spawned() -> void:
	_log_event("[BOSS] Boss spawned signal received!")


func _on_boss_defeated() -> void:
	_log_event("[BOSS] Boss defeated signal received!")


func _on_reward_picked(card_id: StringName, slot_kind: StringName, new_level: int) -> void:
	_log_event("[REWARD] Picked card '%s' (%s, lv %d)" % [card_id, slot_kind, new_level])


func _log_event(msg: String) -> void:
	var time_str: String = "%.2fs" % (Time.get_ticks_msec() / 1000.0)
	var formatted := "[%s] %s" % [time_str, msg]
	print(formatted)
	if log_text != null:
		log_text.append_text(formatted + "\n")
