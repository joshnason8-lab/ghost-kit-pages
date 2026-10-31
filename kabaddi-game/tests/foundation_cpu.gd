extends Node
## CPU per frame of a match (the game's own work: its logic, its bodies' poses, the foundation's when it draws them;
## Godot's process time, nothing drawn) at Low, Medium and High, with the shared foundation and without:
##   godot --headless --path . --fixed-fps 30 res://tests/foundation_cpu.tscn -- [frames=450] [arena=dome]
## The same seeded AI match from the first raid on, each frame's process time; the median and the mean, ms; each level
## twice (after a warm-up match), the steadier kept.

func _ready() -> void:
	var n := 450
	var arena := "dome"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frames="):
			n = int(a.substr(7))
		elif a.begins_with("arena="):
			arena = a.substr(6)
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	Game.settings.models = 1
	Game.settings.camera = Game.CAM_TV
	var rows := []
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
		if true:
			FoundationLink.off = not on
			Game.settings.graphics = g
			WsgFoundation.tier = g
			Game.start_match({"home": "MUM", "away": "DEL", "arena": arena, "mode": "quick", "autoplay": true,
				"autoplay_no_report": true, "length": 0, "difficulty": 2, "seed": 11})
			var m: Node = Game.current
			var guard := 0
			while m.phase != "raid" and guard < 3000:
				await get_tree().process_frame
				guard += 1
			var ms := []
			FoundationLink.cost_usec = 0
			for i in n:
				await get_tree().process_frame
				ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			var fnd := FoundationLink.cost_usec / 1000.0 / n
			var links := 0
			for a in m.athletes + m.officials._homes.keys():
				links += int(a.model.link != null)
			ms.sort()
			var mean: float = ms.reduce(func(x, y): return x + y, 0.0) / ms.size()
			var row := "%-6s foundation %-3s  links %2d  the foundation's own %5.2f ms  process median %5.2f ms  mean %5.2f ms  90th %5.2f ms" % [["Low", "Medium", "High"][g],
				"on" if on else "off", links, fnd, ms[ms.size() / 2], mean, ms[int(ms.size() * 0.9)]]
			print(("(warm-up) " if c[2] else "") + row)
			var key := "%d%s" % [g, on]
			if not c[2] and (not best.has(key) or float(ms[ms.size() / 2]) < float(best[key][0])):
				best[key] = [ms[ms.size() / 2], row]
			m.queue_free()
			Game.current = null
			for i in 5:
				await get_tree().process_frame
	for g in 3:
		for on in [false, true]:
			if best.has("%d%s" % [g, on]):
				rows.append(best["%d%s" % [g, on]][1])
	print("")
	for r in rows:
		print("foundation_cpu: " + r)
	get_tree().quit()
