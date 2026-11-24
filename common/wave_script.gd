class_name WaveScript
extends Resource

@export var wave_of_entry: PackedInt32Array = PackedInt32Array()
@export var enemy_ids: Array[StringName] = []
@export var counts: PackedInt32Array = PackedInt32Array()
@export var escorts: PackedByteArray = PackedByteArray()
## Per-wave arrays use index wave - 1; entry arrays above share the same entry index.
@export var spawn_duration: PackedFloat32Array = PackedFloat32Array()
@export var hp_mult: PackedFloat32Array = PackedFloat32Array()
@export var dmg_mult: PackedFloat32Array = PackedFloat32Array()
@export var speed_mult: PackedFloat32Array = PackedFloat32Array()


func get_wave(wave: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if wave < 1:
		return entries
	var entry_count := mini(wave_of_entry.size(), mini(enemy_ids.size(), mini(counts.size(), escorts.size())))
	for index in range(entry_count):
		if wave_of_entry[index] == wave:
			entries.append({
				"enemy_type": enemy_ids[index],
				"count": counts[index],
				"is_escort": escorts[index] != 0,
			})
	return entries


## Last wave that has entries; waves after it are not scripted.
func get_last_wave() -> int:
	var last := 0
	for wave in wave_of_entry:
		last = maxi(last, wave)
	return last


## Which appearance of boss_id the boss of `wave` is: 1 on the first wave of the script that
## brings it in, 2 on the next. Waves after the script count every boss wave (a multiple of
## boss_wave_interval) as one more appearance. Returns 0 when the script never brings boss_id in.
func get_boss_appearance(boss_id: StringName, wave: int, boss_wave_interval: int) -> int:
	var last_wave := get_last_wave()
	var appearance := 0
	for scripted_wave in range(1, mini(wave, last_wave) + 1):
		for entry in get_wave(scripted_wave):
			if entry.enemy_type == boss_id and not entry.is_escort:
				appearance += 1
				break
	if appearance == 0:
		return 0
	var interval := maxi(1, boss_wave_interval)
	if wave > last_wave:
		appearance += wave / interval - last_wave / interval
	return appearance


func get_spawn_duration(wave: int) -> float:
	return _get_value(spawn_duration, wave, GameConfig.lbd_min_seconds_per_wave)


func get_hp_mult(wave: int) -> float:
	return _get_value(hp_mult, wave, 1.0)


func get_dmg_mult(wave: int) -> float:
	return _get_value(dmg_mult, wave, 1.0)


func get_speed_mult(wave: int) -> float:
	return _get_value(speed_mult, wave, 1.0)


## True when the script has a spawn duration for this wave.
func has_spawn_duration(wave: int) -> bool:
	return wave >= 1 and wave <= spawn_duration.size()


## True when the script has all three multipliers for this wave.
func has_mults(wave: int) -> bool:
	return wave >= 1 and wave <= mini(hp_mult.size(), mini(dmg_mult.size(), speed_mult.size()))


func _get_value(values: PackedFloat32Array, wave: int, fallback: float) -> float:
	if wave < 1 or wave > values.size():
		return fallback
	return snappedf(values[wave - 1], 0.0001)
