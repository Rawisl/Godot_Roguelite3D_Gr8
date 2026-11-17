class_name QualitySettings
extends RefCounted
## Quality rows of the Graphics tab. A preset is only a set of values for the rows below it:
## picking one sets them, changing one row by hand turns the preset to CUSTOM.
##   graphics_preset: LOW, MEDIUM, HIGH or CUSTOM. Without a saved value it follows the GPU
##     (a dedicated card HIGH, a built-in one MEDIUM, a software renderer LOW, unknown MEDIUM).
##   shadow_quality: SHADOW_OFF, SHADOW_LOW or SHADOW_HIGH
##   particle_limit: 500, 1500 or 3000 particles for the hit and skill effects
##   see_through: SEE_THROUGH_DITHER fades whatever hides the commander, SEE_THROUGH_OFF leaves it
## The parts that use a row read current() when they start and follow settings_changed after,
## so a value loaded from settings.cfg and a change in the tab work the same way.

const LOW := &"LOW"
const MEDIUM := &"MEDIUM"
const HIGH := &"HIGH"
const CUSTOM := &"CUSTOM"
const PRESET_IDS: Array[StringName] = [LOW, MEDIUM, HIGH, CUSTOM]

const SHADOW_OFF := 0
const SHADOW_LOW := 1
const SHADOW_HIGH := 2
const SHADOW_LEVELS: Array[int] = [SHADOW_OFF, SHADOW_LOW, SHADOW_HIGH]
## Directional shadow map size per level; off keeps the low size, the lights stop casting.
const SHADOW_ATLAS := {SHADOW_OFF: 2048, SHADOW_LOW: 2048, SHADOW_HIGH: 4096}

const PARTICLE_LIMITS: Array[int] = [500, 1500, 3000]

const SEE_THROUGH_DITHER := 0
const SEE_THROUGH_OFF := 1
const SEE_THROUGH_STYLES: Array[int] = [SEE_THROUGH_DITHER, SEE_THROUGH_OFF]

## Values each preset puts on the rows it covers. See-through is a taste, not a cost: no preset sets it.
const PRESETS := {
	LOW: {&"shadow_quality": SHADOW_OFF, &"particle_limit": 500},
	MEDIUM: {&"shadow_quality": SHADOW_LOW, &"particle_limit": 1500},
	HIGH: {&"shadow_quality": SHADOW_HIGH, &"particle_limit": 3000},
}
const KEYS: Array[StringName] = [&"graphics_preset", &"shadow_quality", &"particle_limit", &"see_through"]


## Current value of a row: the one set last and valid, or the default of the GPU preset.
static func current(key: StringName) -> Variant:
	var value: Variant = GameState.get_setting(key)
	if value != null and is_valid(key, value):
		return value
	return default_value(key)


static func default_value(key: StringName) -> Variant:
	var preset := default_preset()
	match key:
		&"graphics_preset":
			return preset
		&"see_through":
			return SEE_THROUGH_DITHER
	return PRESETS[preset].get(key)


## The preset for this machine when the player has not picked one.
static func default_preset() -> StringName:
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			return HIGH
		RenderingDevice.DEVICE_TYPE_CPU:
			return LOW
	return MEDIUM


## The preset whose values match these rows, or CUSTOM.
static func preset_for(shadow: int, particles: int) -> StringName:
	for id: StringName in PRESETS:
		if PRESETS[id][&"shadow_quality"] == shadow and PRESETS[id][&"particle_limit"] == particles:
			return id
	return CUSTOM


static func is_valid(key: StringName, value: Variant) -> bool:
	match key:
		&"graphics_preset":
			return (value is StringName or value is String) and PRESET_IDS.has(StringName(value))
		&"shadow_quality":
			return value is int and SHADOW_LEVELS.has(value)
		&"particle_limit":
			return value is int and PARTICLE_LIMITS.has(value)
		&"see_through":
			return value is int and SEE_THROUGH_STYLES.has(value)
	return false


## Engine-wide part of a row. Called by GameState for every settings_changed.
static func apply(key: StringName, value: Variant) -> void:
	if not KEYS.has(key):
		return
	# settings.cfg is a text file a player can edit: an unknown value is left alone.
	if not is_valid(key, value):
		push_warning("QualitySettings: %s = %s is not a valid value, ignored" % [key, value])
		return
	if key == &"shadow_quality":
		RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS[value], true)


## Shadow casting of the sun lights under root for the current shadow row. A light the scene
## made without shadows never gets them.
static func apply_shadows(root: Node) -> void:
	var on := int(current(&"shadow_quality")) != SHADOW_OFF
	for node in root.find_children("*", "DirectionalLight3D", true, false):
		var light := node as Light3D
		if not light.has_meta(&"scene_shadow"):
			light.set_meta(&"scene_shadow", light.shadow_enabled)
		light.shadow_enabled = on and bool(light.get_meta(&"scene_shadow"))
