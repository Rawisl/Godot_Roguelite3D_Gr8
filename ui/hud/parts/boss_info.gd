class_name BossInfo
extends RefCounted
## Boss lookups shared by the boss bar and the boss intro card, so both name the boss and its
## immunities the same way.

## The boss with this id, or the first one when the id is empty or unknown.
static func find(bosses: Array[BossData], boss_id: StringName) -> BossData:
	for data in bosses:
		if data != null and data.id == boss_id:
			return data
	return bosses[0] if not bosses.is_empty() else null

## Damage type names the boss ignores in this phase, joined for one label; empty when none.
static func immune_text(data: BossData, phase: Enums.BossPhase) -> String:
	if data == null:
		return ""
	var names: PackedStringArray = []
	for damage_type: int in Enums.DamageType.values():
		if data.is_immune(damage_type, phase):
			var key := "damage." + String(Enums.DamageType.keys()[damage_type]).to_lower()
			names.append(TranslationServer.translate(StringName(key)))
	return ", ".join(names)

## ARMORED, TRANSITION or EXPOSED as sent on EventBus; an unknown name counts as ARMORED.
static func phase_from_name(phase: StringName) -> Enums.BossPhase:
	var index := Enums.BossPhase.keys().find(String(phase))
	return index as Enums.BossPhase if index >= 0 else Enums.BossPhase.ARMORED
