class_name EnemyTraits
extends RefCounted
## The traits of an enemy type and their names, shared by the wave preview, the Hazard Trial
## tower tooltip and the enemy hover box, so all three always say the same thing.
# TODO(Ender-Via): add traits: Array[StringName] to EnemyData with the ids in ALL; of() already reads it, and the overrides used by the tests can go once the data has them.

const STEALTH := &"stealth"
const EXPLODE := &"explode"
const UNDYING := &"undying"
const REVIVE := &"revive"
const CHARGE := &"charge"
const ALL: Array[StringName] = [STEALTH, EXPLODE, UNDYING, REVIVE, CHARGE]

## enemy_id -> traits, used before EnemyData has them (tests and the stand-in data).
static var overrides: Dictionary = {}

## The data of an enemy type or a boss, or null for an unknown id.
static func data_of(enemy_id: StringName) -> EnemyData:
	for folder in ["enemies", "bosses"]:
		var path := "res://data/%s/%s.tres" % [folder, enemy_id]
		if ResourceLoader.exists(path):
			return load(path) as EnemyData
	return null

static func display_name(enemy_id: StringName) -> String:
	var data := data_of(enemy_id)
	var key := data.display_name_key if data != null else "enemy.%s" % enemy_id
	return TranslationServer.translate(StringName(key))

## Known traits of one enemy type, in the order of ALL.
static func of(enemy_id: StringName) -> Array[StringName]:
	var found: Array = []
	if overrides.has(enemy_id):
		found = overrides[enemy_id]
	else:
		var data := data_of(enemy_id)
		var value: Variant = data.get(&"traits") if data != null else null
		if value is Array:
			found = value
	var result: Array[StringName] = []
	for id in ALL:
		if found.has(id) or found.has(String(id)):
			result.append(id)
	return result

static func label(trait_id: StringName) -> String:
	return TranslationServer.translate(StringName("enemy.trait.%s" % trait_id))

## "Lính bộ (Tàng hình, Tự nổ)", or the name alone without traits.
static func name_with_traits(enemy_id: StringName) -> String:
	var name := display_name(enemy_id)
	var names := PackedStringArray()
	for id in of(enemy_id):
		names.append(label(id))
	return name if names.is_empty() else "%s (%s)" % [name, ", ".join(names)]
