extends Node
## AI v AI matches measured against real ones (docs/AI.md): outs a minute, time a defender lasts, khos a minute, dives,
## pole dives, fouls, dream runs, the score. Headless:
##   godot --headless --path . --fixed-fps 30 res://tests/match_sim.tscn -- [matches] [classic|fast] [turn seconds] [user]
## user: the home side is yours, with your thumb off the stick (your defender runs himself: match.gd _user_auto).
## bot: the home side is yours, your defender steered as the phone playtest's tester steers him (tools/playtest/play.js:
## away from the active chaser, toward his back, off the lines).

var bot := false
var cur: Node = null


## The playtest tester's thumb, when the home side defends.
func _process(_d: float) -> void:
	if not bot or cur == null or not is_instance_valid(cur) or cur.controls == null:
		return
	var m = cur
	if m.user_def == null or m.active == null or m.phase != "play":
		m.controls.joystick = Vector2.ZERO
		return
	var me: Vector3 = m.user_def.position
	var c: Vector3 = m.active.position
	var v := Vector2(me.x - c.x, me.z - c.z).normalized() * 3.0
	v.x += -float(m.chase.dir) * 2.0
	if absf(me.z) > m.f.width / 2.0 - 1.5:
		v.y += -signf(me.z) * 4.0
	if absf(me.x) > m.f.length / 2.0 - 1.5:
		v.x += -signf(me.x) * 4.0
	m.controls.joystick = v.normalized()


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 2
	var fmt := KhoRules.FAST if args.size() > 1 and args[1] == "fast" else KhoRules.CLASSIC
	var tl := float(args[2]) if args.size() > 2 else 180.0
	var you := 0 if args.size() > 3 and args[3] in ["user", "bot"] else -1
	bot = args.size() > 3 and args[3] == "bot"
	var pairs := [["MAH", "ODI"], ["KAR", "KER"], ["IND", "NEP"], ["TEL", "DEL"]]
	var tot := {"outs": 0, "khos": 0, "dives": 0, "pole": 0, "fouls": 0, "dream": 0, "limits": 0, "late": 0, "secs": 0.0}
	for i in n:
		var p: Array = pairs[i % pairs.size()]
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": p[0], "away": p[1], "venue": "maidan", "format": fmt, "turn_len": tl, "user_team": you, "seed": 100 + i,
			"mode": "quick", "test": true, "chase_first": i % 2, "follow_on": false}
		add_child(m)
		cur = m
		var res: Dictionary = await m.finished
		cur = null
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
		if you >= 0:
			var yours := {}
			for e in res.log:
				if String(e.kind) == "out" and int(e.get("side", -1)) == you:
					yours[String(e.get("how", ""))] = int(yours.get(String(e.get("how", "")), 0)) + 1
			print("  your side's outs by kind ", yours)
		var hist := {"<1s": 0, "1-2s": 0, "2-4s": 0, ">4s": 0}
		var near_lane := 0
		for e in res.log:
			if String(e.kind) == "out" and e.has("since_kho"):
				var t := float(e.since_kho)
				hist["<1s" if t < 1.0 else ("1-2s" if t < 2.0 else ("2-4s" if t < 4.0 else ">4s"))] += 1
				if float(e.dz) < 2.0:
					near_lane += 1
		var shown := 0
		for e in res.log:
			if String(e.kind) == "foul" and String(e.get("how", "")) == "cross_lane" and shown < 6:
				shown += 1
				print("   lane foul: act %s x %.1f z %.2f vz %.1f half %d plan %s" % [e.act, e.x, e.z, e.vz, e.half, e.plan])
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
