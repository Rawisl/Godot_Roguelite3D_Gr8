extends Node

func _ready() -> void:
	var g := GoldManager.new()
	add_child(g)
	g.reset()
	var start := GameConfig.starting_gold
	assert(g.gold == start)
	assert(not g.try_spend(start + 1))
	assert(g.gold == start)
	assert(g.shortfall(start + 30) == 30)
	g.add(50)
	assert(g.gold == start + 50)
	assert(g.try_spend(50))
	assert(g.gold == start)
	g.add(-10)
	assert(g.gold == start)

	# run_gold_earned only follows gold that counts as earned.
	var rs := RunState.new()
	add_child(rs)
	g.reset()
	var base := g.gold
	g.add(30)
	assert(g.gold == base + 30)
	assert(rs.run_gold_earned == 30)
	g.add(20, true, false)
	assert(g.gold == base + 50)
	assert(rs.run_gold_earned == 30)
	g.add(0, true, false)
	g.add(-5, true, false)
	assert(g.gold == base + 50)
	assert(rs.run_gold_earned == 30)
	print("test_gold_manager: OK")
