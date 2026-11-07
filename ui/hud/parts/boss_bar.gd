extends PanelContainer
## Boss HP in two segments (core red on the left, armor grey on the right), the immunities of the
## current phase, and the boss timer: yellow with an icon from the warning mark, red and larger in
## the last seconds, then the "ENRAGED" tag with its icon once the timer runs out. The text always
## says what the colours mean, so colour is never the only cue.

enum TimerTier { NORMAL, WARN, DANGER, ENRAGED }

## Bosses the bar can show; the first one stands in until the wave says which boss it is.
@export var bosses: Array[BossData] = []
## ui_alert_t2 and ui_alert_t1 in art/palette.md, like the T2 and T1 alerts.
@export var warn_color := Color(1.0, 0.6039, 0.1804)
@export var danger_color := Color(1.0, 0.1765, 0.1765)
@export var timer_font_size := 28
@export var danger_font_size := 40
@export var warn_icon: Texture2D
@export var enrage_icon: Texture2D

var _data: BossData
var _max_armor := 0
var _max_core := 0
var _enraged := false
var _tier := -1

@onready var _name: Label = %BossName
@onready var _timer: Label = %Timer
@onready var _timer_icon: TextureRect = %TimerIcon
@onready var _bars: HBoxContainer = %Bars
@onready var _core: ProgressBar = %CoreBar
@onready var _armor: ProgressBar = %ArmorBar
@onready var _hp_text: Label = %HpText
@onready var _resist_row: HBoxContainer = %ResistRow
@onready var _resist: Label = %Resist

func _ready() -> void:
	visible = false
	# TODO(kimvux): give warn_icon and enrage_icon their own art; both use the boss icon for now.
	# TODO(Ender-Via): emit boss_intro_started(boss_id) when BOSS_INTRO starts, so the bar knows which boss it shows.
	EventBus.boss_intro_started.connect(_on_boss_intro_started)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	# TODO(kiezroth): emit boss_timer_changed with the full time in BOSS_INTRO and while it runs in BOSS_COMBAT, then boss_enraged at 0.
	EventBus.boss_timer_changed.connect(_on_boss_timer_changed)
	EventBus.boss_enraged.connect(_on_boss_enraged)
	EventBus.boss_defeated.connect(_hide)
	EventBus.run_started.connect(_hide)
	EventBus.state_changed.connect(_on_state_changed)

func _on_boss_intro_started(boss_id: StringName) -> void:
	_show_boss(BossInfo.find(bosses, boss_id))

func _on_boss_spawned() -> void:
	if not visible:
		_show_boss(BossInfo.find(bosses, &""))

func _show_boss(data: BossData) -> void:
	_data = data
	_max_armor = 0
	_max_core = 0
	_enraged = false
	_name.text = tr(data.display_name_key) if data != null else ""
	_timer.visible = false
	_timer_icon.visible = false
	_tier = -1
	_hp_text.text = ""
	# No HP before the boss spawns at the end of the intro, so an empty bar never reads as a dead boss.
	_bars.visible = false
	_set_phase(Enums.BossPhase.ARMORED)
	visible = true

## The first values after a spawn are the full ones, so the largest value seen is the segment size.
func _on_boss_hp_changed(armor_hp: int, core_hp: int, phase: StringName) -> void:
	if not visible:
		_show_boss(BossInfo.find(bosses, &""))
	_bars.visible = true
	_max_armor = maxi(_max_armor, armor_hp)
	_max_core = maxi(_max_core, core_hp)
	_armor.max_value = maxi(1, _max_armor)
	_armor.value = armor_hp
	_core.max_value = maxi(1, _max_core)
	_core.value = core_hp
	_armor.size_flags_stretch_ratio = maxf(1.0, _max_armor)
	_core.size_flags_stretch_ratio = maxf(1.0, _max_core)
	_hp_text.text = UiFormat.tr_fmt(&"hud.boss.hp",
		{"armor": armor_hp, "armor_max": _max_armor, "core": core_hp, "core_max": _max_core})
	_set_phase(BossInfo.phase_from_name(phase))

func _on_boss_phase_changed(phase: StringName) -> void:
	_set_phase(BossInfo.phase_from_name(phase))

func _set_phase(phase: Enums.BossPhase) -> void:
	var names := BossInfo.immune_text(_data, phase)
	_resist_row.visible = names != ""
	_resist.text = UiFormat.tr_fmt(&"hud.boss.immune", {"types": names})

func _on_boss_timer_changed(seconds_left: float) -> void:
	if _enraged:
		return
	_timer.visible = true
	_timer.text = UiFormat.time_mmss(seconds_left)
	if seconds_left <= _mark(&"enrage_countdown_time"):
		_set_tier(TimerTier.DANGER)
	elif seconds_left <= _mark(&"enrage_warn_time"):
		_set_tier(TimerTier.WARN)
	else:
		_set_tier(TimerTier.NORMAL)

## The timer stops at 0 and turns into the ENRAGED tag until the boss dies.
func _on_boss_enraged() -> void:
	_enraged = true
	_timer.visible = true
	_timer.text = tr(&"hud.boss.enraged")
	_set_tier(TimerTier.ENRAGED)

## Seconds left at which the timer changes tier, from GameConfig. 0 while GameConfig does not
## have it yet, which keeps the timer plain until the boss timer values land.
func _mark(key: StringName) -> float:
	# TODO(WhoKeng): read GameConfig.enrage_warn_time and enrage_countdown_time directly once the boss timer values are on main.
	var value: Variant = GameConfig.get(key)
	return float(value) if value != null else 0.0

## The timer ticks every frame, so the colour, size and icon change only when the tier does.
func _set_tier(tier: TimerTier) -> void:
	if tier == _tier:
		return
	_tier = tier
	if tier == TimerTier.NORMAL:
		_timer.remove_theme_color_override(&"font_color")
	else:
		_timer.add_theme_color_override(&"font_color", warn_color if tier == TimerTier.WARN else danger_color)
	var large := tier == TimerTier.DANGER or tier == TimerTier.ENRAGED
	_timer.add_theme_font_size_override(&"font_size", danger_font_size if large else timer_font_size)
	_timer_icon.visible = tier != TimerTier.NORMAL
	_timer_icon.texture = enrage_icon if tier == TimerTier.ENRAGED else warn_icon

func _on_state_changed(new_state: StringName) -> void:
	if new_state == &"PREP" or new_state == &"SUMMARY":
		_hide()

func _hide() -> void:
	visible = false
	_data = null
	_enraged = false
