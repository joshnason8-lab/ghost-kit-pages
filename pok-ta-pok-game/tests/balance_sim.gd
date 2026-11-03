extends Node
## Balance, computer against computer (the lead's ask, 0.6.15): N seeds of one cell of levels, headless on Low, each
## match to its end (eight, or time), the venue, rules, teams and side size turned by the seed; home's wins with a 95%
## interval (Wilson). A side that wins more as home than as away, levels alike, is a bug in the code before it is
## balance (the foundation's demo: home moved first every frame).
##   godot --headless --path . --fixed-fps 30 res://tests/balance_sim.tscn -- <home level> <away level> <first seed> <count> [minutes] [swap] [ulama|classic]
## One line a match (BAL ...) and a summary (BALANCE ...).

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.graphics = Game.GFX_LOW
	Game.settings.auto_gfx = false
	var args := OS.get_cmdline_user_args()
	var lv := [int(args[0]) if args.size() > 0 else 1, int(args[1]) if args.size() > 1 else 1]
	var first := int(args[2]) if args.size() > 2 else 1
	var n := int(args[3]) if args.size() > 3 else 10
	var mins := float(args[4]) if args.size() > 4 else 10.0
	# "swap": the first serve alternates by seed (odd seeds away serve first), to tell home from serving first apart;
	# "ulama" / "classic": only that rule set's courts.
	var opts := Array(args.slice(5))
	var wins := [0, 0]
	var draws := 0
	for i in n:
		var s := first + i
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("balance|%d" % s)
		var venue: String = DB.VENUE_ORDER[rng.randi() % DB.VENUE_ORDER.size()]
		for k in 64:
			if not ("ulama" in opts or "classic" in opts) or String(DB.VENUES[venue].rules) in opts:
				break
			venue = DB.VENUE_ORDER[rng.randi() % DB.VENUE_ORDER.size()]
		var first_serve := (s % 2) if "swap" in opts else 0
		var rules := String(DB.VENUES[venue].rules)
		var teams: Array = DB.teams_for(rules)
		var home: String = teams[rng.randi() % teams.size()]
		var away: String = teams[rng.randi() % teams.size()]
		while away == home:
			away = teams[rng.randi() % teams.size()]
		var sides: Array = Rules.side_sizes(rules)
		var m: Node = load("res://game/match.gd").new()
		m.config = {"home": home, "away": away, "venue": venue, "rules": rules, "side": sides[rng.randi() % sides.size()],
			"user_team": -1, "seed": s, "length": mins, "mode": "watch", "levels": lv, "difficulty": maxi(lv[0], lv[1]),
			"urria": "3_7", "ritual": false, "first_serve": first_serve}
		add_child(m)
		var frames := 0
		while m.phase != m.P.OVER and frames < int(mins * 60 * 30 * 1.6) + 30 * 420:
			await get_tree().process_frame
			if m.phase != m.P.REPLAY:
				frames += 1
		var w: int = int(m.count.winner)
		if w < 0:
			w = Rules.at_time(m.count)
		if w >= 0:
			wins[w] += 1
		else:
			draws += 1
		print("BAL seed %d %s %s v %s %s side %s: winner %d after %.1f min first %d" % [s, venue, home, away, rules, str(m.config.side), w, float(m.clock) / 60.0, first_serve])
		m.queue_free()
		await get_tree().process_frame
	var played: int = wins[0] + wins[1]
	var p := float(wins[0]) / maxf(1.0, played)
	var z := 1.96
	var den := 1.0 + z * z / maxf(1.0, played)
	var mid := (p + z * z / (2.0 * maxf(1.0, played))) / den
	var half := z * sqrt(p * (1.0 - p) / maxf(1.0, played) + z * z / (4.0 * maxf(1.0, played) * maxf(1.0, played))) / den
	print("BALANCE levels %d-%d seeds %d..%d: home %d, away %d, draws %d; home %.0f%% (95%% %.0f-%.0f%%)" % [lv[0], lv[1], first,
		first + n - 1, wins[0], wins[1], draws, p * 100.0, (mid - half) * 100.0, (mid + half) * 100.0])
	get_tree().quit()
