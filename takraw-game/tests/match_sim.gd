extends Node
## Plays AI-v-AI matches headless and reports how they went: the score, rally lengths, how points were won.
##   godot --headless --path . --fixed-fps 60 res://tests/match_sim.tscn -- [matches] [event] [venue]

var results := []


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var n := int(a[0]) if a.size() > 0 else 1
	var ev := String(a[1]) if a.size() > 1 else "regu"
	var venue := String(a[2]) if a.size() > 2 else "national"
	Game.main = self
	Game.reset_settings_for_tests()
	var pairs := [["THA", "MAS"], ["VIE", "INA"], ["SPB", "NPT"], ["JPN", "KOR"]]
	if OS.has_environment("SWAP"):
		pairs = [["MAS", "THA"], ["INA", "VIE"], ["NPT", "SPB"], ["KOR", "JPN"]]
	for i in n:
		var pr: Array = pairs[i % pairs.size()]
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": pr[0], "away": pr[1], "venue": venue, "event": ev, "sets": 3, "points": 15, "user_team": -1,
			"demo": true, "seed": 1000 + i, "mode": "quick"}
		add_child(m)
		var t0 := Time.get_ticks_msec()
		var res: Dictionary = await m.finished
		var frames := Engine.get_process_frames()
		print("match %d %s v %s: sets %s %s, potm %s (%.1f s real)" % [i, pr[0], pr[1], res.sets, res.set_scores, "#%d" % int(res.potm.get("num", 0)), (Time.get_ticks_msec() - t0) / 1000.0])
		var tot := {"kills": 0, "aces": 0, "blocks": 0, "digs": 0, "errors": 0, "serves": 0}
		for id in res.stats:
			for k in tot:
				tot[k] += int(res.stats[id][k])
		print("   totals ", tot, " sim minutes %.1f" % (m.now / 60.0))
		var how := {}
		var lens := 0
		for r in res.log:
			var k := "%s:%d" % [r[1], int(r[2])]
			how[k] = int(how.get(k, 0)) + 1
			lens += int(r[0])
		print("   rallies %d, mean touches %.1f, ended by %s" % [res.log.size(), float(lens) / maxf(1, res.log.size()), how])
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit()
