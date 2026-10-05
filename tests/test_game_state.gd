extends Control
## Manual test for GameState transitions (SRS 3.1). Not shipped.

func _ready() -> void:
	var S := GameState.AppState
	var cases := [
		[S.BOOT, S.MAIN_MENU, true],
		[S.MAIN_MENU, S.RUN_LOADING, true],   # FLOW-06
		[S.MAIN_MENU, S.RUN, false],          # must go through RunLoading
		[S.RUN, S.MAIN_MENU, false],          # only via RunEnd
		[S.RUN_END, S.META_SHOP, true],
		[S.META_SHOP, S.MAIN_MENU, true],
		[S.SETTINGS, S.RUN, false],
	]
	for c in cases:
		var allowed: bool = c[1] in GameState.TRANSITIONS[c[0]]
		print("[test] %s -> %s allowed=%s %s" % [S.keys()[c[0]], S.keys()[c[1]], allowed,
				"OK" if allowed == c[2] else "FAIL"])
