extends Node
## AI matches, start to finish, headless, to see how they go: the count, the rayas and why, the rallies.
##   godot --headless --path . --fixed-fps 30 res://tests/match_sim.tscn -- [matches] [minutes] [rules]

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 2
	var mins := float(args[1]) if args.size() > 1 else 6.0
	var rules := String(args[2]) if args.size() > 2 else "ulama"
	var venue := "village" if rules == "ulama" else "stone"
	for i in n:
		var m: Node = load("res://game/match.gd").new()
		m.config = {"home": "ESC", "away": "LLA", "venue": venue, "rules": rules, "user_team": -1, "seed": 11 + i, "length": mins, "mode": "test", "difficulty": 1}
		add_child(m)
		var frames := 0
		while m.phase != m.P.OVER and frames < int(mins * 60 * 30) + 30 * 60:
			await get_tree().process_frame
			frames += 1
		var r: Dictionary = m.result()
		var why := {}
		for e in r.log:
			why[e[1]] = int(why.get(e[1], 0)) + 1
		print("match %d (%s): winner %d after %.1f min, %d rayas %s, longest rally %d, count %s" % [i, rules, int(r.winner), float(r.minutes),
			r.log.size(), JSON.stringify(why), int(r.longest_rally), JSON.stringify(r.count)])
		print("  strikes %s dives %s" % [[r.tstats[0].strikes, r.tstats[1].strikes], [r.tstats[0].dives, r.tstats[1].dives]])
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit()
