class_name Enums
extends RefCounted
## GLOBAL ENUMS
## IF NEEDED, ADD ENUMS FROM THE BOTTOM, DO NOT CHANGE ANYTHING ABOVE

enum WaveState { PREP = 0, COMBAT = 1, SUMMARY = 2, BOSS_INTRO = 3, BOSS_COMBAT = 4, REWARD_PICK = 5 }
enum CommanderMode { FRONTLINE = 0, COMMANDER = 1 }
enum EndType { FORTRESS_DESTROYED = 0, COMMANDER_DIED = 1, ABANDONED = 2 }
enum DamageType { PIERCE = 0, BLAST = 1, SLASH = 2, MAGIC = 3, TRAP = 4, TRUE = 5 }
enum TargetPriority { FIRST = 0, NEAREST = 1, HIGHEST_HP = 2, LOWEST_HP = 3 }
enum SlotState { EMPTY = 0, OCCUPIED = 1, RUINED = 2 }
enum SlotZone { WALL = 0, NEAR = 1, FAR = 2 }
enum BossPhase { ARMORED = 0, TRANSITION = 1, EXPOSED = 2 }
enum AlertTier { T1 = 1, T2 = 2, T3 = 3 }
