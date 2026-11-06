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
	print("test_gold_manager: OK")
