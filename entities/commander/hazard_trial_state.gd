class_name HazardTrialState
extends Node

const COMMANDER_FIELDS: Array[StringName] = [
	&"_dodge_cooldown_timer", &"_battle_cry_cd_timer", &"_battle_cry_active_timer",
	&"is_dead", &"is_stunned", &"_stun_timer", &"_stun_immunity_timer",
]

var _commander: CharacterBody3D
var _run_state: RunState
var _in_room := false
var _hp_cap_ref := -1


func _ready() -> void:
	_commander = get_parent() as CharacterBody3D
	EventBus.hazard_trial_entered.connect(_on_entered)
	EventBus.hazard_trial_exited.connect(_on_exited)
	EventBus.run_ended.connect(_on_run_ended)


func _exit_tree() -> void:
	_clear()


func is_in_room() -> bool:
	return _in_room


func _on_entered(_wave_index: int, _enemy_types: Array) -> void:
	if _in_room:
		return
	_run_state = get_tree().get_first_node_in_group(&"run_state") as RunState
	if _run_state == null:
		push_warning("HazardTrialState requires a RunState before entering the room")
		return
	var fields := {}
	for field in COMMANDER_FIELDS:
		fields[field] = _commander.get(field)
	_run_state.hazard_session = {
		"hp": _commander.health.get_precise_hp(),
		"max_hp": _commander.health.max_hp,
		"dot_remainder": _commander.health.dot_remainder,
		"stats": _commander.stat_block.export_state(),
		"skills": _commander.skill_runner.export_state(),
		"fields": fields,
		"mode_cooldown": _commander._mode_switch.cooldown_left,
		"weapon": _run_state.equipped_weapon,
		"chain_cd": _run_state.chain_cd,
	}
	_in_room = true
	_hp_cap_ref = -1
	DamageCalc.set_cap_hook(func(info: DamageInfo, _target: Node) -> int:
		return _cap() if info.is_from_commander() else -1)


func _on_exited(_result: StringName, _kills: int, _gold: int, _xp: float, _mithril: int) -> void:
	if not _in_room:
		return
	DamageCalc.clear_cap_hook()
	if is_instance_valid(_run_state) and not _run_state.hazard_session.is_empty():
		var saved := _run_state.hazard_session
		# Room actions must not finish later against enemies outside the room.
		if _commander.is_dodging:
			_commander._end_dodge()
		_commander._interrupt_attack()
		_commander._interrupt_skill()
		_commander._mode_switch.reset()
		_commander.velocity = Vector3.ZERO
		_commander._knockback_velocity = Vector3.ZERO
		_commander._hit_reaction_timer = 0.0
		_commander._post_action_timer = 0.0
		for field in COMMANDER_FIELDS:
			_commander.set(field, saved["fields"][field])
		_run_state.equipped_weapon = saved["weapon"]
		_run_state.chain_cd = saved["chain_cd"]
		_commander._apply_weapon(saved["weapon"])
		_commander.stat_block.import_state(saved["stats"])
		_commander.skill_runner.import_state(saved["skills"])
		_commander._mode_switch.cooldown_left = saved["mode_cooldown"]
		_commander.health.restore_state(saved["hp"], saved["max_hp"], saved["dot_remainder"])
		EventBus.skill_cooldown_changed.emit(&"dodge", _commander._dodge_cooldown_timer,
			_commander.get_stat(&"dodge_cooldown", 1.5))
		EventBus.skill_cooldown_changed.emit(&"battle_cry", _commander._battle_cry_cd_timer,
			_commander.get_stat(&"skill_cooldown", 12.0))
		EventBus.mode_switch_cooldown_started.emit(_commander._mode_switch.cooldown_left)
		_commander._refresh_aura()
	_clear()


func _on_run_ended(_end_type: StringName, _summary: Dictionary) -> void:
	_clear()


func _clear() -> void:
	if _in_room:
		DamageCalc.clear_cap_hook()
		if is_instance_valid(_run_state):
			_run_state.hazard_session.clear()
	_in_room = false
	_hp_cap_ref = -1


func _cap() -> int:
	if _hp_cap_ref < 0:
		var candidate_hp_ref := 0
		for enemy in get_tree().get_nodes_in_group(&"enemy"):
			if enemy.is_queued_for_deletion():
				continue
			if "max_core_hp" in enemy:
				candidate_hp_ref = maxi(candidate_hp_ref, int(enemy.max_core_hp))
			else:
				var health := enemy.get("health") as HealthComponent
				if health != null:
					candidate_hp_ref = maxi(candidate_hp_ref, health.max_hp)
		if candidate_hp_ref <= 0:
			return 0
		_hp_cap_ref = candidate_hp_ref
	return floori(GameConfig.hazard_damage_cap_pct * _hp_cap_ref)
