extends Node
## AI v AI matches, played headless at a fixed frame rate, to see how they go: the score, how scores came, the
## restarts, the fouls and cards. godot --headless --path . --fixed-fps 30 res://tests/match_sim.tscn -- [n] [length]

var n := 1
var length := 14.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	if args.size() > 1:
		length = float(args[1])
	var first := 0
	for a in args:
		if String(a).begins_with("start="):
			first = int(String(a).substr(6))
	Game.main = self
	Game.settings.sound = false
	var ids := DB.counties_ranked()
	var totals := {"goals": 0, "points": 0, "shots": 0, "wides": 0, "frees": 0, "s65": 0, "puckouts": 0, "yellow": 0, "black": 0, "red": 0}
	for i in range(first, first + n):
		var home: String = ids[i % 8]
		var away: String = ids[(i * 3 + 1) % 8]
		if home == away:
			away = ids[9]
		var cfg := {"home": home, "away": away, "venue": "county", "user_team": -1, "seed": 100 + i, "length": length, "mode": "sim_test"}
		var m: Node = load("res://game/match.gd").new()
		m.config = cfg
		m.set_meta("test", true)
		add_child(m)
		var frames := 0
		while m.phase != m.P.OVER and frames < int(length * 60.0 * 30.0 * 1.6):
			await get_tree().process_frame
			frames += 1
		var s: Array = m.score
		var fat := []
		for pl in m.all_players():
			fat.append(snappedf((pl as Player).fatigue, 0.01))
		fat.sort()
		print("   fatigue at the end: median %.2f, most %.2f; subs %d and %d" % [fat[fat.size() / 2], fat[-1], m.teams[0].subs, m.teams[1].subs])
		print("%s %s v %s %s  (%.1f real min, %.1f live, phase %d)" % [home, Rules.fmt(s[0][0], s[0][1]), Rules.fmt(s[1][0], s[1][1]), away, frames / 1800.0, m.live_real / 60.0, m.phase])
		for k in 2:
			var t: Dictionary = m.tstats[k]
			print("   %s shots %d (play %d placed %d) scored play %d placed %d wides %d frees %d 65s %d sidelines %d puckouts %d cards y%d b%d r%d" % [
				["home", "away"][k], t.shots, t.shots_play, t.shots_placed, t.scores_play, t.scores_placed, t.wides, t.frees, t.s65, t.sidelines, t.puckouts, t.yellow, t.black, t.red])
			totals.goals += int(s[k][0])
			totals.points += int(s[k][1])
			for key in ["shots", "wides", "frees", "s65", "puckouts", "yellow", "black", "red"]:
				totals[key] += int(t[key])
		if "v" in args:
			for e in m.events:
				print("      %d' %s %s %s %s" % [e.t, ["H", "A"][int(e.team)], e.kind, e.how, e.by])
		m.queue_free()
		await get_tree().process_frame
	print("per match: %s" % JSON.stringify(totals))
	get_tree().quit()
