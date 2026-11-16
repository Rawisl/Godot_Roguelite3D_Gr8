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


func get_spawn_duration(wave: int) -> float:
	return _get_value(spawn_duration, wave, GameConfig.lbd_min_seconds_per_wave)


func get_hp_mult(wave: int) -> float:
	return _get_value(hp_mult, wave, 1.0)


func get_dmg_mult(wave: int) -> float:
	return _get_value(dmg_mult, wave, 1.0)


func get_speed_mult(wave: int) -> float:
	return _get_value(speed_mult, wave, 1.0)


func _get_value(values: PackedFloat32Array, wave: int, fallback: float) -> float:
	if wave < 1 or wave > values.size():
		return fallback
	return snappedf(values[wave - 1], 0.0001)
