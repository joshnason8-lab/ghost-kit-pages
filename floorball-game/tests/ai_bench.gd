extends Node
## AI v AI matches, measured against real floorball (docs/RULES.md, "How the AI plays"): goals, shots, save rate,
## penalties and stoppages, all scaled to 60 minutes of play.
##   godot --headless --path . --fixed-fps 60 res://tests/ai_bench.tscn -- [matches] [period minutes]

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 3
	var mins := float(args[1]) if args.size() > 1 else 4.0
	var pairs := [["SWE", "FIN"], ["SUI", "CZE"], ["LAT", "NOR"], ["GER", "SVK"], ["SWE", "THA"], ["FIN", "DEN"]]
	var tot := {"goals": 0, "sog": 0, "shots": 0, "saves": 0, "sa": 0, "pens": 0, "fo": 0, "fh": 0, "hi": 0, "minutes": 0.0}
	for i in n:
		var pr: Array = pairs[i % pairs.size()]
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": pr[0], "away": pr[1], "venue": "hall", "user_team": -1, "demo": true, "seed": 100 + i, "period": mins}
		add_child(m)
		var res: Dictionary = await m.finished
		var g: Array = res.goals
		var ts: Array = res.team_stats
		tot.goals += int(g[0]) + int(g[1])
		tot.sog += int(ts[0].sog) + int(ts[1].sog)
		tot.shots += int(ts[0].shots) + int(ts[1].shots)
		tot.fo += int(ts[0].fo) + int(ts[1].fo)
		for id in res.stats:
			tot.saves += int(res.stats[id].saves)
			tot.sa += int(res.stats[id].sa)
		for e in res.log:
			if String(e.kind) == "penalty":
				tot.pens += 1
		for c in res.calls:
			if String(c.kind) == "free_hit":
				tot.fh += 1
		tot.minutes += mins * 3.0
		print("%s v %s %d-%d  sog %d-%d shots %d-%d" % [pr[0], pr[1], g[0], g[1], ts[0].sog, ts[1].sog, ts[0].shots, ts[1].shots])
		m.queue_free()
		await get_tree().process_frame
	var k := 60.0 / maxf(1.0, tot.minutes)
	print("per 60 min: goals %.1f, shots %.1f, on goal %.1f, scored of all shots %.1f%%, save rate %.1f%%, penalties %.1f, free-hits %.1f, face-offs %.1f" % [
		tot.goals * k, tot.shots * k, tot.sog * k, 100.0 * tot.goals / maxf(1, tot.shots), 100.0 * tot.saves / maxf(1, tot.sa), tot.pens * k, tot.fh * k, tot.fo * k])
	get_tree().quit()
