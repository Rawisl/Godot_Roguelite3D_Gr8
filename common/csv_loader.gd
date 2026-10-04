class_name CsvLoader
extends RefCounted

## Utility for reading and parsing balance CSV tables.

static func load_csv_as_dicts(file_path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(file_path):
		return result
		
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return result
		
	var headers: PackedStringArray = []
	var line_num: int = 0
	
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
			
		var tokens := line.split(",")
		for i in range(tokens.size()):
			tokens[i] = tokens[i].strip_edges()
			
		if line_num == 0:
			headers = tokens
		else:
			var row_dict: Dictionary = {}
			for i in range(mini(headers.size(), tokens.size())):
				row_dict[headers[i]] = tokens[i]
			result.append(row_dict)
		line_num += 1
		
	file.close()
	return result

static func load_enemy_data_from_csv(file_path: String) -> Array[EnemyData]:
	var dicts := load_csv_as_dicts(file_path)
	var enemies: Array[EnemyData] = []
	for d in dicts:
		var ed := EnemyData.new()
		ed.id = StringName(d.get("id", "enemy"))
		ed.display_name_key = d.get("display_name_key", "enemy." + str(ed.id))
		ed.base_hp = int(d.get("base_hp", 40))
		ed.base_damage = int(d.get("base_damage", 6))
		ed.attack_interval = float(d.get("attack_interval", 1.0))
		ed.attack_range = float(d.get("attack_range", 1.5))
		ed.move_speed = float(d.get("move_speed", 3.5))
		ed.damage_type = int(d.get("damage_type", Enums.DamageType.SLASH)) as Enums.DamageType
		ed.spawn_cost = int(d.get("spawn_cost", 1))
		ed.is_flying = (d.get("is_flying", "false").to_lower() == "true")
		ed.is_ranged = (d.get("is_ranged", "false").to_lower() == "true")
		ed.knockback_immune = (d.get("knockback_immune", "false").to_lower() == "true")
		ed.aggro_range = float(d.get("aggro_range", 10.0))
		ed.avoid_radius = float(d.get("avoid_radius", 0.5))
		ed.avoid_priority = int(d.get("avoid_priority", 1))
		ed.gold_reward = int(d.get("gold_reward", 4))
		ed.prestige_reward = int(d.get("prestige_reward", 1))
		enemies.append(ed)
	return enemies
