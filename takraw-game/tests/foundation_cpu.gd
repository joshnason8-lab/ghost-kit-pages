extends Node
## CPU per frame of a match (the game's own work: its logic, its bodies' poses, the foundation's when it draws them;
## each frame's wall time headless, nothing drawn) at Low, Medium and High, with the shared foundation and without:
##   godot --headless --path . --fixed-fps 30 res://tests/foundation_cpu.tscn -- [frames=600] [venue=national]
## The same seeded AI match (a regu) from its first serve on, each frame's process time; the median, the mean and the
## 90th percentile, ms; each level twice (after a warm-up match), the steadier kept.

func _ready() -> void:
	var n := 600
	var venue := "national"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frames="):
			n = int(a.substr(7))
		elif a.begins_with("venue="):
			venue = a.substr(6)
	Game.main = self
	Game.reset_settings_for_tests()
	Game.settings.sound = false
	var configs := [[Game.GFX_MEDIUM, false, true]]     # (a warm-up first: shaders, caches)
	for rep in 2:
		for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
			for on in [false, true]:
				if not on or WsgClips.available():
					configs.append([g, on, false])
	var best := {}
	for c in configs:
		var g: int = c[0]
		var on: bool = c[1]
		FoundationLink.off = not on
		Game.settings.graphics = g
		WsgFoundation.tier = g
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "THA", "away": "MAS", "venue": venue, "event": "regu", "sets": 1, "points": 15, "user_team": -1,
			"demo": true, "seed": 11, "mode": "quick"}
		add_child(m)
		var guard := 0
		while m.state != m.S.TOSS and guard < 3000:
			await get_tree().process_frame
			guard += 1
		var ms := []
		FoundationLink.cost_usec = 0
		FoundationLink.cost_mods_usec = 0
		var t := Time.get_ticks_usec()
		for i in n:
			await get_tree().process_frame
			# (Headless, frames run back to back: a frame's wall time is its CPU time, nothing drawn.)
			var now := Time.get_ticks_usec()
			ms.append((now - t) / 1000.0)
			t = now
		var fnd := FoundationLink.cost_usec / 1000.0 / n
		var mods := FoundationLink.cost_mods_usec / 1000.0 / n
		var links := 0
		for b in m._all_bodies():
			links += int((b as RealBody).link != null)
		ms.sort()
		var mean: float = ms.reduce(func(x, y): return x + y, 0.0) / ms.size()
		var row := "%-6s foundation %-3s  links %2d  the foundation's own %5.2f ms (modifiers %4.2f)  frame median %5.2f ms  mean %5.2f ms  90th %5.2f ms" % [["Low", "Medium", "High"][g],
			"on" if on else "off", links, fnd, mods, ms[ms.size() / 2], mean, ms[int(ms.size() * 0.9)]]
		print(("(warm-up) " if c[2] else "") + row)
		var key := "%d%s" % [g, on]
		if not c[2] and (not best.has(key) or float(ms[ms.size() / 2]) < float(best[key][0])):
			best[key] = [ms[ms.size() / 2], row]
		m.queue_free()
		for i in 5:
			await get_tree().process_frame
	print("")
	for g in 3:
		for on in [false, true]:
			if best.has("%d%s" % [g, on]):
				print("foundation_cpu: " + best["%d%s" % [g, on]][1])
	FoundationLink.off = false
	get_tree().quit()
