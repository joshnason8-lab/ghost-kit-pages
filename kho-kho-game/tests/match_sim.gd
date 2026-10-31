extends Node
## AI v AI matches measured against real ones (docs/AI.md): outs a minute, time a defender lasts, khos a minute, dives,
## pole dives, fouls, dream runs, the score. Headless:
##   godot --headless --path . --fixed-fps 30 res://tests/match_sim.tscn -- [matches] [classic|fast] [turn seconds] [user]
## user: the home side is yours, with your thumb off the stick (your defender runs himself: match.gd _user_auto).
## bot: the home side is yours, your defender steered as the phone playtest's tester steers him (tools/playtest/play.js:
## away from the active chaser, toward his back, off the lines).

var bot := false
var cur: Node = null
var safe_t := 0.0      # defender-seconds spent safe (the chase over SAFE_S away), on the field
var safe_still := 0.0  # ... of them standing (under 0.5 m/s)
var safe_dist := 0.0   # ... and the metres run in them
const SAFE_S := 3.2
var lone_t := 0.0      # seconds with one defender left in his batch
var lone_chain := 0.0  # ... of them within 3 m of the lane, or by a pole
var wide_t := 0.0      # seconds with three in, the two furthest from the chase off the lane
var wide_split := 0.0  # ... of them those two on opposite sides of it
var out_where := {"side line": 0, "pole": 0, "end line": 0, "field": 0}
var in_t := [0.0, 0.0, 0.0, 0.0]   # seconds with 0, 1, 2, 3 of the batch in
var out_dz := [0, 0, 0, 0]   # outs (not at a pole) by distance off the lane: 0-2, 2-4, 4-6, 6+ m


## The playtest tester's thumb, when the home side defends.
func _process(_d: float) -> void:
	if cur == null or not is_instance_valid(cur):
		return
	# Real defenders out of danger stand still and watch (docs/AI.md, "Watched"): how much do these?
	if cur.phase == "play" and cur.active != null:
		for d in cur.batch:
			if cur.d_state.get(d, "") == "in" and cur.reach_time(d.position) > SAFE_S:
				var v: float = Vector2(d.vel.x, d.vel.z).length()
				safe_t += _d
				safe_dist += v * _d
				if v < 0.5:
					safe_still += _d
	# Both matches watched end to end: the last of a batch lives on the chain and round the poles; with three in,
	# the two out of danger wait on opposite sides of the lane.
	if cur.phase == "play" and cur.active != null:
		var live: Array = []
		for d in cur.batch:
			if cur.d_state.get(d, "") == "in":
				live.append(d)
		in_t[mini(live.size(), 3)] += _d
		if live.size() == 1:
			var q: Vector3 = live[0].position
			lone_t += _d
			if absf(q.z) < 3.0 or absf(absf(q.x) - cur.f.pole_gap * 0.5) < 2.5:
				lone_chain += _d
		elif live.size() == 3:
			# The two the chase is furthest from: on opposite sides of the lane?
			live.sort_custom(func(x, y): return cur.reach_time(x.position) > cur.reach_time(y.position))
			if absf(live[0].position.z) > 1.0 and absf(live[1].position.z) > 1.0:
				wide_t += _d
				if signf(live[0].position.z) != signf(live[1].position.z):
					wide_split += _d
	if cur.controls == null:
		return
	var m = cur
	if m.phase == "interval":   # "Next turn"
		if m.hud._interval:
			m.hud._interval.queue_free()
			m.hud._interval = null
		m.next_turn()
		return
	if m.user_def == null or m.active == null or m.phase != "play":
		m.controls.joystick = Vector2.ZERO
		return
	if not bot:
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
	var tot := {"outs": 0, "khos": 0, "dives": 0, "pole": 0, "fouls": 0, "dream": 0, "limits": 0, "late": 0, "turns": 0, "secs": 0.0}
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
		var c := {"outs": 0, "khos": 0, "dives": 0, "pole": 0, "fouls": 0, "dream": 0, "limits": 0, "late": 0, "turns": 0}
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
		# Where the outs came: by a pole, at a side or end line, or in the field (and how far off the lane).
		for e in res.log:
			if String(e.kind) == "out" and e.has("dz"):
				var dz := float(e.dz)
				var ax := absf(float(e.x))
				if absf(ax - m.f.pole_gap * 0.5) < 2.5 and dz < 3.0:
					out_where.pole += 1
					continue
				out_dz[mini(int(dz / 2.0), 3)] += 1
				if m.f.width * 0.5 - dz < 2.0:
					out_where["side line"] += 1
				elif m.f.length * 0.5 - ax < 2.0:
					out_where["end line"] += 1
				else:
					out_where.field += 1
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
			c.turns += int(res.stats[id].get("pole_turns", 0))
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
	print("POLE TURNS: %.1f a minute" % (tot.turns / (tot.secs / 60.0)))
	print("SAFE defenders: %.0f%% of their safe time standing, %.1f m/s on average (%.0f defender-seconds safe)" % [
		100.0 * safe_still / maxf(safe_t, 0.001), safe_dist / maxf(safe_t, 0.001), safe_t])
	print("LONE defender: %.0f%% of his time on the chain or by a pole (%.0f s)" % [100.0 * lone_chain / maxf(lone_t, 0.001), lone_t])
	print("THREE in: the two the chase is furthest from on opposite sides %.0f%% of the time (%.0f s)" % [100.0 * wide_split / maxf(wide_t, 0.001), wide_t])
	print("BATCH: time with 0/1/2/3 in: %.0f / %.0f / %.0f / %.0f s" % in_t)
	print("OUTS where: ", out_where, "  away from the poles, by metres off the lane 0-2/2-4/4-6/6+: ", out_dz)
	get_tree().quit()
