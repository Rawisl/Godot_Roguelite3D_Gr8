extends Control
## Test for the REWARD_PICK card look: theme variations per kind, readable colours, hover / press /
## picked effects on UI time while the game is paused, the greyed state and Reduced motion.
## Not shipped. Run with F6, prints OK/FAIL per case then quits.

const CARD_SCENE: PackedScene = preload("res://ui/screens/reward_card.tscn")
const THEME: Theme = preload("res://ui/theme/main_theme.tres")
const SKILLS := {
	&"ACTIVE": "res://data/skills/firebomb.tres",
	&"PASSIVE": "res://data/skills/sharpness.tres",
	&"STAT": "res://data/skills/vitality.tres",
}

var _pass := 0
var _fail := 0


func _ready() -> void:
	theme = THEME
	await _run()
	get_tree().paused = false
	print("[test] done: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _card_data(kind: StringName) -> Dictionary:
	var data := load(SKILLS[kind]) as SkillData
	return {"id": data.id, "kind": kind, "data": data, "is_new": kind == &"ACTIVE", "level": 1, "next_level": 2}


func _new_card(kind: StringName) -> RewardCard:
	var card := CARD_SCENE.instantiate() as RewardCard
	add_child(card)
	card.size = card.custom_minimum_size
	card.show_card(_card_data(kind))
	return card


func _wait_real(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


## WCAG contrast ratio between two colours.
func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var ch := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


func _run() -> void:
	# Theme: one variation per part, one frame and band per kind.
	for type in [&"RewardCard", &"RewardCardTitle", &"RewardCardText", &"RewardCardLevel", &"RewardKindLabel",
			&"RewardKindLabelLight", &"RewardFrameActive", &"RewardFramePassive", &"RewardFrameStat",
			&"RewardKindActive", &"RewardKindPassive", &"RewardKindStat"]:
		_check("the theme has the %s variation" % type, THEME.get_type_variation_base(type) != &"")
	for state in [&"normal", &"hover", &"pressed", &"disabled", &"picked"]:
		_check("RewardCard has a '%s' style" % state, THEME.has_stylebox(state, &"RewardCard"))

	var cards := {}
	for kind in SKILLS:
		cards[kind] = _new_card(kind)
	await get_tree().process_frame

	var frames := {}
	for kind: StringName in cards:
		var card: RewardCard = cards[kind]
		var frame := card.get_node("%Frame") as Panel
		var band := card.get_node("%KindBand") as PanelContainer
		_check("%s: frame and band take the kind's variations" % kind,
			frame.theme_type_variation == RewardCard.KIND_STYLES[kind][0] and band.theme_type_variation == RewardCard.KIND_STYLES[kind][1])
		var band_box := band.get_theme_stylebox(&"panel") as StyleBoxFlat
		frames[kind] = (frame.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color
		var label := card.get_node("%Kind") as Label
		var ratio := _contrast(label.get_theme_color(&"font_color"), band_box.bg_color)
		_check("%s: the kind label reads on its band (contrast %.1f)" % [kind, ratio], ratio >= 4.5)
		_check("%s: the kind is written, not only coloured" % kind, label.text != "")
	_check("the three kinds have different frame colours",
		frames[&"ACTIVE"] != frames[&"PASSIVE"] and frames[&"PASSIVE"] != frames[&"STAT"] and frames[&"ACTIVE"] != frames[&"STAT"])
	var active_slot := Color(1, 0.78431374, 0.23921569, 1)
	var passive_slot := Color(0.47843137, 0.30980393, 0.627451, 1)
	_check("active and passive frames match their slot groups on the screen",
		(frames[&"ACTIVE"] as Color).is_equal_approx(active_slot) and (frames[&"PASSIVE"] as Color).is_equal_approx(passive_slot))

	var card: RewardCard = cards[&"PASSIVE"]
	var bg := (card.get_theme_stylebox(&"normal") as StyleBoxFlat).bg_color
	for part in [&"%Name", &"%Level", &"%Desc"]:
		var l := card.get_node(String(part)) as Label
		var ratio := _contrast(l.get_theme_color(&"font_color"), bg)
		_check("%s reads on the card (contrast %.1f)" % [part, ratio], ratio >= 4.5)

	# Effects run on UI time: the game is paused on this screen.
	get_tree().paused = true
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.mouse_entered.emit()
	await _wait_real(0.3)
	_check("hover grows the card while the game is paused", is_equal_approx(card.scale.x, card.hover_scale))
	_check("a grown card draws over its neighbours", card.z_index > 0)
	card.mouse_exited.emit()
	await _wait_real(0.3)
	_check("leaving it settles back", is_equal_approx(card.scale.x, 1.0) and card.z_index == 0)

	var picked: Array[Dictionary] = []
	card.chosen.connect(func(c: Dictionary) -> void: picked.append(c))
	card.pressed.emit()
	await _wait_real(0.3)
	_check("pressing sends the card", picked.size() == 1 and picked[0].get("kind") == &"PASSIVE")
	_check("the picked card keeps its glow", card.is_picked() and card.get_theme_stylebox(&"disabled") == THEME.get_stylebox(&"picked", &"RewardCard"))
	_check("the picked card stays a little larger", is_equal_approx(card.scale.x, card.picked_scale))

	# The screen greys every card while it waits: the others dim, the picked one does not.
	for c: RewardCard in cards.values():
		c.disabled = true
	await get_tree().process_frame
	var other: RewardCard = cards[&"STAT"]
	_check("a greyed card dims its frame and band", (other.get_node("%Frame") as Panel).modulate.a < 1.0)
	_check("the picked card keeps its frame", (card.get_node("%Frame") as Panel).modulate.a == 1.0)
	other.mouse_entered.emit()
	await _wait_real(0.2)
	_check("a greyed card does not grow on hover", is_equal_approx(other.scale.x, 1.0))

	# The next offer resets the card.
	card.disabled = false
	card.show_card(_card_data(&"ACTIVE"))
	await get_tree().process_frame
	_check("a new offer clears the picked state", not card.is_picked() and is_equal_approx(card.scale.x, 1.0)
			and card.get_theme_stylebox(&"normal") == THEME.get_stylebox(&"normal", &"RewardCard"))

	# Reduced motion: instant changes.
	EventBus.settings_changed.emit(&"reduced_motion", true)
	card.mouse_entered.emit()
	_check("Reduced motion changes the size at once", is_equal_approx(card.scale.x, card.hover_scale))
	EventBus.settings_changed.emit(&"reduced_motion", false)


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("[test] OK   %s" % label)
	else:
		_fail += 1
		print("[test] FAIL %s" % label)
