extends WsgOwnerNote
## The owner, 2026-11-03 (Kho Kho Rush 0.12.1): "On a lot of the games when you click start game there is a loading delay ... long enough on the slow phone that users might think the game has frozen. We either need a little load screen or load bar by the start buttons."

const NOTE := {"id": "2026-11-03-start-looks-frozen", "game": "kho-kho", "date": "2026-11-03", "version": "Kho Kho Rush 0.12.1", "words": "On a lot of the games when you click start game there is a loading delay ... long enough on the slow phone that users might think the game has frozen. We either need a little load screen or load bar by the start buttons."}
const KK := preload("res://tests/note_kk.gd")


## Start from the home screen, at every ground: the loading overlay is up in the tap's own frame, a second tap starts
## nothing, the bar only goes forward to the end, and the match is played once it goes.
func check() -> void:
	KK.prepare(tree)
	for venue in ["maidan", "school", "arena", "floodlit"]:
		Game.show_screen("res://ui/main_menu.gd")
		await KK.frames(tree, 10)
		var menu: Node = Game.current
		Game.play_match({"home": "MAH", "away": "ODI", "venue": venue, "format": KhoRules.FAST if venue == "arena" else KhoRules.CLASSIC,
			"turn_len": 60.0, "user_team": 0, "seed": 3, "mode": "quick", "test": true, "chase_first": 0})
		var ld := WsgLoading.current()
		if not expect(ld != null and ld.is_inside_tree(), "%s: no overlay in the tap's frame" % venue):
			continue
		var bar: Array = []
		ld.progressed.connect(func(fr: float, _l: String): bar.append(fr))
		Game.play_match({"home": "MAH", "away": "ODI", "venue": venue})
		expect(WsgLoading.current() == ld and Game.current == menu, "%s: a second tap started something" % venue)
		var guard := 0
		while not (Game.current != menu and Game.current.get("live") == true) and guard < 1200:
			await frame()
			guard += 1
		var ok := bar.size() > 2 and float(bar[-1]) >= 0.999
		for i in range(1, bar.size()):
			ok = ok and float(bar[i]) >= float(bar[i - 1])
		expect(ok, "%s: the bar went back or stopped short (%s)" % [venue, bar])
		expect(Game.current != menu and Game.current.get("live") == true, "%s: the match never started" % venue)
		await KK.frames(tree, 40)
		if is_instance_valid(Game.current) and Game.current != menu:
			Game.current.queue_free()
		Game.current = null
		await KK.frames(tree, 2)
