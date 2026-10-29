class_name MusicLibrary
extends Resource
## Music for each part of the game. Loops should be .ogg at -14 LUFS with loop on in the import
## settings. A missing track plays silence.

## MainMenu, MetaShop and Settings.
@export var menu: AudioStream
## PREP, and after the win sting in SUMMARY.
@export var prep: AudioStream
## COMBAT.
@export var combat: AudioStream
## BOSS_INTRO and BOSS_COMBAT.
@export var boss: AudioStream
## RunEnd, after the lose sting.
@export var run_end: AudioStream
## Played once when a wave is cleared (SUMMARY).
@export var win_sting: AudioStream
## Played once when the run is lost (RunEnd).
@export var lose_sting: AudioStream
