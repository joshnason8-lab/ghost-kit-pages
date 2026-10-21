extends Node
## AI v AI matches measured against real ones (docs/AI.md): outs a minute, time a defender lasts, khos a minute, dives,
## pole dives, fouls, dream runs, the score. Headless:
##   godot --headless --path . --fixed-fps 30 res://tests/match_sim.tscn -- [matches] [classic|fast] [turn seconds]

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 2
	var fmt := KhoRules.FAST if args.size() > 1 and args[1] == "fast" else KhoRules.CLASSIC
	var tl := float(args[2]) if args.size() > 2 else 180.0
	var pairs := [["MAH", "ODI"], ["KAR", "KER"], ["IND", "NEP"], ["TEL", "DEL"]]
	var tot := {"outs": 0, "khos": 0, "dives": 0, "pole": 0, "fouls": 0, "dream": 0, "limits": 0, "late": 0, "secs": 0.0}
	for i in n:
		var p: Array = pairs[i % pairs.size()]
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": p[0], "away": p[1], "venue": "maidan", "format": fmt, "turn_len": tl, "user_team": -1, "seed": 100 + i,
			"mode": "quick", "test": true, "chase_first": i % 2, "follow_on": false}
		add_child(m)
		var res: Dictionary = await m.finished
		var fouls := {}
		var c := {"outs": 0, "khos": 0, "dives": 0, "pole": 0, "fouls": 0, "dream": 0, "limits": 0, "late": 0}
		for e in res.log:
			match String(e.kind):
				"out":
					c.outs += 1
					if e.kind == "out" and String(e.get("how", "")) == "":
						pass
				"kho":
					c.khos += 1
				"foul":
					c.fouls += 1
					fouls[String(e.get("how", ""))] = int(fouls.get(String(e.get("how", "")), 0)) + 1
				"dream":
					c.dream += int(e.pts)
		var kinds := {}
		for e in res.log:
			if String(e.kind) == "out":
				kinds[String(e.get("how", ""))] = int(kinds.get(String(e.get("how", "")), 0)) + 1
		print("  outs by kind ", kinds, "  fouls ", fouls)
		var hist := {"<1s": 0, "1-2s": 0, "2-4s": 0, ">4s": 0}
		var near_lane := 0
		for e in res.log:
			if String(e.kind) == "out" and e.has("since_kho"):
				var t := float(e.since_kho)
				hist["<1s" if t < 1.0 else ("1-2s" if t < 2.0 else ("2-4s" if t < 4.0 else ">4s"))] += 1
				if float(e.dz) < 2.0:
					near_lane += 1
		print("  time since the last kho ", hist, "  within 2 m of the lane ", near_lane)
		for id in res.stats:
			c.dives += int(res.stats[id].dives)
			c.pole += int(res.stats[id].pole_dives)
		var secs: float = tl * float(res.turns.size())
		print("%s v %s: %s  outs %d (%.2f a min)  khos %d (%.1f a min)  dives %d  pole dives %d  fouls %d  dream %d" % [p[0], p[1],
			str(res.score), c.outs, c.outs / (secs / 60.0), c.khos, c.khos / (secs / 60.0), c.dives, c.pole, c.fouls, c.dream])
		for k in c:
			tot[k] += c[k]
		tot.secs += secs
		m.queue_free()
		await get_tree().process_frame
	print("ALL: outs %.2f a min, khos %.1f a min, a dive every %.0f s, fouls %.2f a min, dream points %d" % [tot.outs / (tot.secs / 60.0),
		tot.khos / (tot.secs / 60.0), tot.secs / maxf(1, tot.dives + tot.pole), tot.fouls / (tot.secs / 60.0), tot.dream])
	get_tree().quit()
