class_name GameCredits
extends RefCounted
## Everything the Credits screen lists, in order: the team, then every outside asset with its
## author and licence. CREDITS.md at the repo root says the same in text; keep the two together.
## Kevin MacLeod's music is CC BY 4.0, so its lines must keep the exact attribution below.
## CC0 entries need no credit but are listed as thanks.
##
## Each section: title (locale key) and entries. Each entry: name, by, licence, url (all
## optional except name). `source` lists the repo folders the entry covers, so a test can check
## that every folder with a licence file is credited.

const CC0 := "CC0 1.0"
const CC_BY_4 := "Creative Commons: By Attribution 4.0 License"
const CC_BY_4_URL := "http://creativecommons.org/licenses/by/4.0/"

const SECTIONS: Array[Dictionary] = [
	{
		"title": &"credits.section.team",
		"entries": [
			{"name": "Ngọc"},
			{"name": "Kiệt"},
			{"name": "Mạnh"},
			{"name": "Khang"},
			{"name": "Kim"},
		],
	},
	{
		"title": &"credits.section.music",
		"entries": [
			{"name": "\"Skye Cuillin\"", "by": "Kevin MacLeod (incompetech.com)", "licence": CC_BY_4, "url": CC_BY_4_URL, "source": ["audio/music"]},
			{"name": "\"Morning\"", "by": "Kevin MacLeod (incompetech.com)", "licence": CC_BY_4, "url": CC_BY_4_URL, "source": ["audio/music"]},
			{"name": "\"Silver Blue Light\"", "by": "Kevin MacLeod (incompetech.com)", "licence": CC_BY_4, "url": CC_BY_4_URL, "source": ["audio/music"]},
			{"name": "\"Crusade - Heavy Industry\"", "by": "Kevin MacLeod (incompetech.com)", "licence": CC_BY_4, "url": CC_BY_4_URL, "source": ["audio/music"]},
			{"name": "\"Killers\"", "by": "Kevin MacLeod (incompetech.com)", "licence": CC_BY_4, "url": CC_BY_4_URL, "source": ["audio/music"]},
			{"name": "Music Jingles", "by": "Kenney (www.kenney.nl)", "licence": CC0, "source": ["audio/music"]},
		],
	},
	{
		"title": &"credits.section.sound",
		"entries": [
			{"name": "Impact Sounds, Interface Sounds, Sci-Fi Sounds", "by": "Kenney (www.kenney.nl)", "licence": CC0, "source": ["audio/sfx"]},
			{"name": "Bump", "by": "pyzaist (freesound.org)", "licence": CC0, "source": ["audio/sfx"]},
			{"name": "Slingshot Fly by 2", "by": "saturdaysoundguy (freesound.org)", "licence": CC0, "source": ["audio/sfx"]},
			{"name": "Monster Cry", "by": "Algoto (freesound.org)", "licence": CC0, "source": ["audio/sfx"]},
		],
	},
	{
		"title": &"credits.section.models",
		"entries": [
			{"name": "KayKit: Adventurers Character Pack", "by": "Kay Lousberg (www.kaylousberg.com)", "licence": CC0, "source": ["contents/assets/characters/commander"]},
			{"name": "KayKit Character Pack: Skeletons", "by": "Kay Lousberg (www.kaylousberg.com)", "licence": CC0, "source": ["contents/assets/characters/enemy and boss"]},
			{"name": "KayKit: Character Animations", "by": "Kay Lousberg (www.kaylousberg.com)", "licence": CC0, "source": ["contents/assets/characters/additional animations"]},
			{"name": "credits.item.towers_env", "by": "CraftPix (craftpix.net)", "licence": "CraftPix File License", "url": "https://craftpix.net/file-licenses/", "source": ["contents/assets/towers", "contents/assets/fortress", "contents/assets/environment/bush", "contents/assets/environment/stone"]},
			{"name": "credits.item.barricade", "by": "credits.by.team_rodin"},
			{"name": "credits.item.ai_models", "by": "credits.by.team_ai"},
			{"name": "credits.item.rubble", "by": "credits.by.team"},
		],
	},
	{
		"title": &"credits.section.font",
		"entries": [
			{"name": "Be Vietnam Pro", "by": "The Be Vietnam Pro Project Authors", "licence": "SIL Open Font License 1.1", "url": "https://github.com/bettergui/BeVietnamPro", "source": ["ui/theme/fonts"]},
		],
	},
	{
		"title": &"credits.section.tools",
		"entries": [
			{"name": "Godot Engine", "by": "Juan Linietsky, Ariel Manzur and contributors", "licence": "MIT", "url": "https://godotengine.org/license"},
			{"name": "Blender", "by": "Blender Foundation"},
		],
	},
]


## Folders that hold a licence file and must be covered by some entry's `source`. For tests.
static func credited_sources() -> PackedStringArray:
	var out := PackedStringArray()
	for section in SECTIONS:
		for entry in section.entries:
			for path in entry.get("source", []):
				out.append(path)
	return out
