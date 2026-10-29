class_name DeployPointFinder
extends RefCounted
## Picks where the commander lands when leaving Commander mode. Pure and deterministic:
## the same inputs always give the same point, so crowded gates can be tested.

const RING_DIRECTIONS: int = 8


## origin: the default deploy point. toward: where the first candidate of every ring points (the Fortress).
## enemy_positions: ground positions of living enemies.
## resolve: Callable(Vector3) -> Variant, the usable landing position for a raw candidate,
## or null when it is off the navmesh, inside a zone or blocked by a collider.
## Returns the chosen position, or null when no candidate works.
static func find(origin: Vector3, toward: Vector3, enemy_positions: PackedVector3Array,
		clear_radius: float, search_radius: float, resolve: Callable) -> Variant:
	if _is_clear(origin, enemy_positions, clear_radius):
		return origin

	var start := Vector3(toward.x - origin.x, 0.0, toward.z - origin.z)
	if start.length_squared() < 0.0001:
		start = Vector3.RIGHT
	start = start.normalized()

	var ring := 1.0
	while ring <= search_radius + 0.0001:
		for i in RING_DIRECTIONS:
			# Negative angle turns clockwise when seen from above.
			var angle := -TAU * float(i) / float(RING_DIRECTIONS)
			var candidate := origin + start.rotated(Vector3.UP, angle) * ring
			var resolved: Variant = resolve.call(candidate)
			if resolved == null:
				continue
			if _is_clear(resolved, enemy_positions, clear_radius):
				return resolved
		ring += 1.0
	return null


static func _is_clear(point: Vector3, enemy_positions: PackedVector3Array, clear_radius: float) -> bool:
	for enemy_pos in enemy_positions:
		var flat := Vector2(enemy_pos.x - point.x, enemy_pos.z - point.z)
		if flat.length() < clear_radius:
			return false
	return true
