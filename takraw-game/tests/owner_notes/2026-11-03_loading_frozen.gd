extends TakrawNote
## The owner, 2026-11-03, for every game: "On a lot of the games when you click start game there is a loading delay
## ... long enough on the slow phone that users might think the game has frozen."

const NOTE := {"id": "2026-11-03-loading-frozen", "game": "sepak-takraw", "date": "2026-11-03", "version": "0.15.1",
	"words": "On a lot of the games when you click start game there is a loading delay ... long enough on the slow phone that users might think the game has frozen."}


## Each way into a match - Quick match's Play, Watch AI's Watch, a season's Play, an international's Play - pressed
## as the player does: in that very frame the loading overlay is up and the button off; its bar moves; the match is
## playing when it comes down.
func check() -> void:
	Game.reset_settings_for_tests()
	Game.settings.sound = false
	FoundationLink.off = true
	var holder := Node.new()
	tree.root.add_child(holder)
	_made.append(holder)
	Game.main = holder
	for way in ["quick match", "watch AI", "season", "international"]:
		var screen: Node
		match way:
			"quick match":
				screen = Game.show_screen("res://ui/quick_setup.gd")
			"watch AI":
				screen = Game.show_screen("res://ui/quick_setup.gd", {"watch": true})
			"season":
				Game.new_season("MY", "PRK")
				screen = Game.show_screen("res://ui/season_hub.gd")
			"international":
				Game.new_cup("world", "THA")
				screen = Game.show_screen("res://ui/cup_screen.gd")
		await frame()
		var key := "WATCH" if way == "watch AI" else "PLAY"
		var btn: Button = null
		for b in screen.find_children("*", "Button", true, false):
			if (b as Button).text == TranslationServer.translate(key) and (b as Button).is_visible_in_tree():
				btn = b
				break
		if not expect(btn != null, "%s: no %s button" % [way, key]):
			continue
		var f0 := Engine.get_process_frames()
		btn.pressed.emit()
		var ld := WsgLoading.current()
		expect(ld != null and ld.is_inside_tree() and ld.visible and btn.disabled, "%s: the overlay is not up, the button off, in the tap's own frame" % way)
		var bar := {"moves": 0, "last": -1.0, "report": {}, "done": false}
		if ld:
			ld.progressed.connect(func(v: float, _what: String):
				if v > float(bar.last):
					bar.moves += 1
					bar.last = v)
			ld.finished.connect(func():
				bar.report = ld.report.duplicate()
				bar.done = true)
		# (By the clock: the files load on a thread in real time, and a headless run's frames go by far faster.)
		var t0 := Time.get_ticks_msec()
		while not bool(bar.done) and Time.get_ticks_msec() - t0 < 60000:
			await frame()
		await frame()   # (the match begins as the overlay's fade ends: Game.play_match)
		var waited := 0 if Time.get_ticks_msec() - t0 < 60000 else 30 * 60
		var m: Node = Game.current
		var playing: bool = m != null and m.has_method("set_paused") and m.process_mode != Node.PROCESS_MODE_DISABLED
		info("%s: the overlay up in the tap's frame; its bar moved %d times; down after %d frames, %.1f s %s" % [way, bar.moves, Engine.get_process_frames() - f0, (Time.get_ticks_msec() - t0) / 1000.0, str(bar.report.get("failed", ""))])
		expect(playing, "%s: no match playing when the overlay came down" % way)
		expect(int(bar.moves) >= 3, "%s: the bar moved only %d times" % [way, bar.moves])
		expect(waited < 30 * 60, "%s: still loading after 60 s" % way)
	Game.delete_season()
	Game.delete_cup()
	await clean()
