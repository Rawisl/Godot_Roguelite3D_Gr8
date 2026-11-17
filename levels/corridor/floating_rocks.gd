class_name FloatingRocks
extends Node3D
## Rocks drifting clockwise around the Hazard Trial island (seen from above, with -Z at the top of
## the screen as the room is built), each on its own circle at its own pace, bobbing up and down
## and turning slowly. Every child Node3D is a rock; its position in the scene is where it starts.
## Decoration only: it follows the game clock (stops on pause, faster at x2 and x3).

## Degrees per second around the island.
@export var orbit_speed_deg := 5.0
## Each rock is up to this much faster or slower than orbit_speed_deg (0.25 = 25%).
@export_range(0.0, 1.0) var speed_variation := 0.3
## Up and down movement in metres, and the seconds for one full bob.
@export var bob_height := 0.5
@export var bob_period := 5.0
## Degrees per second each rock turns on itself.
@export var spin_speed_deg := 10.0

var _rocks: Array[Dictionary] = []


func _ready() -> void:
	# Fixed seed: the rocks drift the same way in every run.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for child in get_children():
		var rock := child as Node3D
		if rock == null:
			continue
		var p := rock.position
		_rocks.append({
			"node": rock,
			"radius": Vector2(p.x, p.z).length(),
			"angle": atan2(p.z, p.x),
			"height": p.y,
			"speed": 1.0 + rng.randf_range(-speed_variation, speed_variation),
			"phase": rng.randf() * TAU,
			"axis": Vector3(rng.randf_range(-1, 1), 1.0, rng.randf_range(-1, 1)).normalized(),
		})


func _process(delta: float) -> void:
	var orbit := deg_to_rad(orbit_speed_deg) * delta
	var bob := TAU / maxf(bob_period, 0.1) * delta
	var spin := deg_to_rad(spin_speed_deg) * delta
	for r in _rocks:
		var rock: Node3D = r["node"]
		# A growing angle goes from +X (right) to +Z (bottom of the screen): clockwise.
		# Kept within one turn so the values stay small however long the room is shown.
		r["angle"] = fposmod(r["angle"] + orbit * r["speed"], TAU)
		r["phase"] = fposmod(r["phase"] + bob, TAU)
		var angle: float = r["angle"]
		var radius: float = r["radius"]
		rock.position = Vector3(cos(angle) * radius, r["height"] + sin(r["phase"]) * bob_height, sin(angle) * radius)
		rock.rotate(r["axis"], spin)
