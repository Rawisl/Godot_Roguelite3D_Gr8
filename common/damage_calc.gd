class_name DamageCalc
extends RefCounted
## Single damage formula for hits on regular enemies and bosses.
## damage = round(raw * dealt_mult * taken_mult * resist), rounded once at the end.
## dealt_mult stacks additively (1 + sum), taken_mult multiplies, the two groups multiply together.

## Optional ceiling per hit. Signature: (info: DamageInfo, target: Node) -> int, a negative value means no cap.
## Process-wide: whoever sets it must clear it on every exit path (room end, abandon, scene exit).
static var _cap_hook: Callable = Callable()


static func dealt_mult(bonuses: Array[float]) -> float:
	var total := 1.0
	for b in bonuses:
		total += b
	return total


static func taken_mult(factors: Array[float]) -> float:
	var total := 1.0
	for f in factors:
		total *= f
	return total


## One non-DoT hit. Regular enemies take at least 1 when raw > 0, bosses have no floor.
static func hit(raw: float, dealt: float, taken: float, resist: float, is_boss: bool) -> int:
	if raw <= 0.0 or resist <= 0.0:
		return 0
	var value := roundi(raw * dealt * taken * resist)
	return value if is_boss else maxi(1, value)


## One DoT tick. Returns [damage_to_apply, new_remainder]. No floor of 1 per tick.
static func dot_tick(remainder: float, raw: float, dealt: float, taken: float, resist: float) -> Array:
	if raw <= 0.0 or resist <= 0.0:
		return [0, remainder]
	var acc := remainder + raw * dealt * taken * resist
	var whole := floori(acc)
	return [whole, acc - float(whole)]


static func set_cap_hook(hook: Callable) -> void:
	_cap_hook = hook


static func clear_cap_hook() -> void:
	_cap_hook = Callable()


static func has_cap_hook() -> bool:
	return _cap_hook.is_valid()


## Resolves info against target, writes the result back into info (amount, resist, immune)
## and returns the final amount. The result depends only on raw, so one DamageInfo can be
## sent to several targets and each target gets its own resist, taken_mult and boss rules.
static func resolve(info: DamageInfo, target: Node) -> int:
	if info.damage_type == Enums.DamageType.TRUE:
		info.amount = maxi(0, roundi(info.raw))
		return info.amount

	var resist := 1.0
	if target != null and target.has_method(&"get_resist"):
		resist = float(target.call(&"get_resist", info.damage_type))
	var taken := 1.0
	if target != null and target.has_method(&"get_taken_mult"):
		taken = float(target.call(&"get_taken_mult"))
	var is_boss := target != null and (target.is_in_group(&"boss") or target.get(&"data") is BossData)

	info.resist = resist
	info.immune = resist <= 0.0
	if info.immune:
		info.amount = 0
		return 0

	var health: HealthComponent = null
	if info.is_dot and target != null:
		health = target.get("health") as HealthComponent
	if info.is_dot and health != null:
		var tick := dot_tick(health.dot_remainder, info.raw, info.dealt_mult, taken, resist)
		info.amount = int(tick[0])
		health.dot_remainder = float(tick[1])
	else:
		info.amount = hit(info.raw, info.dealt_mult, taken, resist, is_boss)

	if _cap_hook.is_valid():
		var cap := int(_cap_hook.call(info, target))
		if cap >= 0:
			info.amount = mini(info.amount, cap)
	return info.amount
