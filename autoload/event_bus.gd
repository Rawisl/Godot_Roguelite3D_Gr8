extends Node

#Khai báo toàn bộ signal ở đây, tránh conflict code

# Run và wave
signal run_started
signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)
signal state_changed(new_state: StringName)
signal fortress_destroyed
signal fortress_hp_changed(hp: int, max_hp: int)
# Commander
signal commander_died
signal commander_hp_changed(hp: int, max_hp: int)
signal mode_changed(mode: StringName)
# Kinh te va xay dung
signal gold_changed(gold: int)
signal tower_built(slot_id: StringName, type: StringName)
signal tower_sold(slot_id: StringName)
signal tower_destroyed(slot_id: StringName)
# Boss
signal boss_spawned
signal boss_timer_changed(t: float)
signal boss_defeated
# Thoi gian
signal time_scale_changed(scale: int)
