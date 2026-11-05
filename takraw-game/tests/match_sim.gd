extends Node
## Plays AI-v-AI matches headless and reports how they went: the score, rally lengths, how points were won.
##   godot --headless --path . --fixed-fps 60 res://tests/match_sim.tscn -- [matches] [event] [venue]
## SEQ=1 prints each rally's touches, SEED=n starts the seeds from n, PAIR=THA,KOR plays only that match (docs/AI.md).

var results := []
var _kinds := {}                    # how the points were decided -> how many
var _rally_touches: Array[int] = []


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
	if OS.has_environment("PAIR"):
		pairs = [OS.get_environment("PAIR").split(",")]
	var seed0 := int(OS.get_environment("SEED")) if OS.has_environment("SEED") else 1000
	for i in n:
		var pr: Array = pairs[i % pairs.size()]
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": pr[0], "away": pr[1], "venue": venue, "event": ev, "sets": 3, "points": 15, "user_team": -1,
			"demo": true, "seed": seed0 + i, "mode": "quick"}
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
		# As the real matches are counted (docs/AI.md): how each point was decided.
		for r in res.log:
			var k := _decided_by(int(r[0]), String(r[1]))
			_kinds[k] = int(_kinds.get(k, 0)) + 1
			_rally_touches.append(int(r[0]))
			if OS.has_environment("SEQ"):
				print("   rally %-14s %s" % [k, r[3]])
		m.queue_free()
		await get_tree().process_frame
	var total := 0
	for k in _kinds:
		total += int(_kinds[k])
	var shares := []
	for k in _kinds:
		shares.append("%s %d%%" % [k, roundi(100.0 * int(_kinds[k]) / maxf(1, total))])
	_rally_touches.sort()
	print("points %d decided by: %s; median touches a rally %d" % [total, ", ".join(shares), _rally_touches[_rally_touches.size() / 2] if not _rally_touches.is_empty() else 0])
	get_tree().quit()


## How a point was decided, in the real matches' terms: a service fault, the serve (an ace, the reception failing on
## the first or second touch after it, or coming straight over to be put away), an attack's kill, a block, or another
## error.
static func _decided_by(touches: int, why: String) -> String:
	if why.begins_with("kill_") and touches <= 3:
		return "serve"   # the reception came straight over and was put away
	if why.begins_with("kill_"):
		return "kill"
	if why == "block":
		return "block"
	if why == "ace":
		return "serve"
	if touches <= 1 and (why in ["out", "in"] or why.begins_with("FAULT")):
		return "service fault"
	if touches <= 3 and (why in ["out", "in"] or why.begins_with("FAULT")):
		return "serve"   # (the reception failed: off the receiver, or the second touch)
	return "other error"
