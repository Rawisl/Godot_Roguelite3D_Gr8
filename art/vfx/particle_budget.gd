class_name ParticleBudget
extends RefCounted
## One particle budget for the whole game, set by the Graphics tab's particle limit (Low 500,
## Medium 1500, High 3000). Every effect manager that spawns particles joins the group
## "particle_source" and reports its live particles with active_particles(); the budget is the
## sum over all of them, so two managers can never fill it twice over.
## Secondary effects (muzzle flashes, arrow hits, skill trails, build dust) are skipped once a
## new one would go over the limit. Main effects (cannon blasts, a tower breaking, the boss)
## always play, so the budget only ever thins out the extras. Telegraphs use meshes, not
## particles, and are never touched.

const GROUP := &"particle_source"

static var limit := 1500


## Live particles of every source in the tree.
static func used(tree: SceneTree) -> int:
	if tree == null:
		return 0
	var total := 0
	for node in tree.get_nodes_in_group(GROUP):
		if node.has_method(&"active_particles"):
			total += int(node.call(&"active_particles"))
	return total


## True when an effect of cost particles may start. Main effects always may.
static func has_room(tree: SceneTree, cost: int, secondary: bool) -> bool:
	return not secondary or used(tree) + cost <= limit
