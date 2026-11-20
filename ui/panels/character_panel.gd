extends PanelContainer

signal closed
signal weapons_requested

func _ready() -> void:
	%Title.text = tr(&"hud.commander")
	%TitleIcon.texture = preload("res://art/icons/frontline_mode_with_border_icon.png")
	%TitleIcon.show()

	%CloseButton.focus_mode = Control.FOCUS_NONE
	%CloseButton.pressed.connect(closed.emit)
	%WeaponSlot.open_requested.connect(weapons_requested.emit)
	EventBus.commander_hp_changed.connect(_on_hp_changed)
	EventBus.xp_changed.connect(_on_xp_changed)

func _on_hp_changed(hp: int, maximum: int) -> void:
	%Health.text = UiFormat.tr_fmt(&"hud.ratio", {"value": hp, "max": maximum})
	%HealthBar.max_value = maximum
	%HealthBar.value = hp

func _on_xp_changed(xp: float, level: int, to_next: float, _pending: int) -> void:
	%Level.text = tr(&"character.recruit") if level == 0 else UiFormat.tr_fmt(&"hud.xp.level", {"level": level})
	%Experience.text = UiFormat.tr_fmt(&"hud.ratio", {"value": floori(xp), "max": ceili(to_next)})
	%ExperienceBar.max_value = to_next
	%ExperienceBar.value = xp
