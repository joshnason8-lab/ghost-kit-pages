extends WsgOwnerNote
## The owner, 2026-11-03 (every game): "On a lot of the games when you click start game there is a loading delay ...
## long enough on the slow phone that users might think the game has frozen."

const NOTE := {"id": "2026-11-03-loading-frozen", "game": "pok-ta-pok", "date": "2026-11-03", "version": "every game", "words": "On a lot of the games when you click start game there is a loading delay ... long enough on the slow phone that users might think the game has frozen."}


## Every way into a match (quick match at each venue, Watch AI, the tournament) through Game.start_match: the overlay
## is up in the same frame as the tap with the screen's buttons off, a second tap starts nothing, the build is cut so
## no stretch of it holds the screen past 250 ms (headless here: the build's own work, not the GPU's), and the match
## comes up built and playing when it goes.
func check() -> void:
	Game.settings.sound = false
	Game.overlay_headless = true
	var keep_main: Variant = Game.main
	var main := Node.new()
	tree.root.add_child(main)
	Game.main = main    # where Game puts each screen and match
	var ways := [{"venue": "village", "rules": "ulama", "mode": "quick"}, {"venue": "festival", "rules": "ulama", "mode": "quick"},
		{"venue": "stone", "rules": "classic", "mode": "quick"}, {"venue": "night", "rules": "classic", "mode": "watch", "user_team": -1},
		{"venue": "village", "rules": "ulama", "mode": "cup"}]
	for w: Dictionary in ways:
		var host := Control.new()
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var start := Button.new()
		host.add_child(start)
		main.add_child(host)
		Game.current = host
		await frame()
		var cfg := {"home": "ESC" if w.rules == "ulama" else "PIS", "away": "LLA" if w.rules == "ulama" else "VAL", "venue": w.venue,
			"rules": w.rules, "user_team": int(w.get("user_team", 0)), "seed": 4, "length": 0.0, "mode": w.mode, "difficulty": 1, "ritual": false}
		Game.start_match(cfg)
		var name := "%s %s" % [w.mode, w.venue]
		expect(WsgLoading.busy() and start.disabled, "%s: no overlay in the frame of the tap (the buttons left on)" % name)
		var ld := WsgLoading.current()
		Game.start_match(cfg)   # a second tap
		expect(WsgLoading.current() == ld, "%s: a second tap started a second load" % name)
		var n := 0
		while WsgLoading.busy() and n < 30 * 60:
			await frame()
			n += 1
		expect(not WsgLoading.busy(), "%s: the overlay never went" % name)
		var rep: Dictionary = ld.report if ld else {}
		info("%s: %s" % [name, JSON.stringify(rep).left(260)])
		expect(float(rep.get("longest_slice_ms", 9999.0)) <= 250.0, "%s: the build held the screen %.0f ms in one stretch (%s)" % [name, float(rep.get("longest_slice_ms", -1.0)), rep.get("longest_slice", "?")])
		for i in 3:
			await frame()   # (the overlay gone, the match's clock starts: Game.start_match's kick_off)
		var m: Node = Game.current
		var up: bool = m != null and m.has_method("kick_off") and bool(m.built) and m.is_processing()
		expect(up, "%s: the match did not come up built and playing (%s, built %s, playing %s)" % [name, m.get_script().resource_path if m and m.get_script() else str(m),
			m.get("built") if m else null, m.is_processing() if m else null])
		if m and is_instance_valid(m):
			m.queue_free()
		Game.current = null
		await frame()
	Game.overlay_headless = false
	Game.main = keep_main if is_instance_valid(keep_main) else null
	main.queue_free()
