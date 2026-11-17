class_name QualityApplier
extends Node
## Puts the quality rows of the Graphics tab on the level it sits in, at start and on every change:
## - shadow_quality: the level's sun casts shadows or not (QualitySettings.apply_shadows)
## - particle_limit: the particle budget of HitFxManager and SkillFxManager
## - see_through: OcclusionManager fades what hides the commander, or leaves it
## The values come from QualitySettings.current(), so a machine with no settings.cfg gets the
## preset of its GPU.


func _ready() -> void:
	EventBus.settings_changed.connect(_on_settings_changed)
	# The other managers of the level are ready by the next frame.
	_apply_all.call_deferred()


func _apply_all() -> void:
	for key in [&"shadow_quality", &"particle_limit", &"see_through"]:
		_apply(key)


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if QualitySettings.KEYS.has(key) and QualitySettings.is_valid(key, value):
		_apply(key)


func _apply(key: StringName) -> void:
	var level := get_parent()
	if level == null:
		return
	match key:
		&"shadow_quality":
			QualitySettings.apply_shadows(level)
		&"particle_limit":
			var budget := int(QualitySettings.current(&"particle_limit"))
			for node in level.get_children():
				if node is HitFxManager or node is SkillFxManager:
					node.set(&"particle_budget", budget)
		&"see_through":
			var on := int(QualitySettings.current(&"see_through")) == QualitySettings.SEE_THROUGH_DITHER
			for node in level.get_children():
				if node is OcclusionManager:
					(node as OcclusionManager).enabled = on
