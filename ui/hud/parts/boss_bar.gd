extends PanelContainer

@export var bosses: Array[BossData] = []
var _data: BossData
var _max_armor := 0
var _max_core := 0
@onready var _name: Label = %BossName
@onready var _bars: Control = %Bars
@onready var _core: ProgressBar = %CoreBar
@onready var _armor: ProgressBar = %ArmorBar
@onready var _resist_row: HBoxContainer = %ResistRow

func _ready() -> void:
	visible = false
	EventBus.boss_intro_started.connect(_on_boss_intro_started)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
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
	_name.text = tr(data.display_name_key) if data != null else ""
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
	_set_phase(BossInfo.phase_from_name(phase))

func _on_boss_phase_changed(phase: StringName) -> void:
	_set_phase(BossInfo.phase_from_name(phase))

func _set_phase(phase: Enums.BossPhase) -> void:
	for icon in _resist_row.get_children():
		icon.visible = _data != null and _data.is_immune(icon.damage_type, phase)
	_resist_row.visible = _resist_row.get_children().any(func(icon: Control) -> bool: return icon.visible)

func _on_state_changed(new_state: StringName) -> void:
	if new_state == &"PREP" or new_state == &"SUMMARY":
		_hide()

func _hide() -> void:
	visible = false
	_data = null
