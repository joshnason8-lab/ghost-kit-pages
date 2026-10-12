extends Node
## Plays AI-vs-AI matches headless and prints raid outcomes and move use, for tuning.
## godot --headless --path . --fixed-fps 30 res://tests/ai_bench.tscn -- [matches] [difficulty]

var _done := false
var _result := {}
var _all_logs := []
# Footage-comparable measures (tools/mocap/raid_events.py reads the same things off match video).
var _style := {"first_attempt": [], "between": [], "attempt_gap": [], "dive_gap": [], "help": [], "near": [],
		"probe_speed": [], "top_speed": [], "def_depth": [], "def_width": [], "def_stagger": [], "tackle_after": []}
# The defence's shape (no footage numbers; for the team defence work, docs/TACKLE_SYSTEM.md): each set
# defender's nearest team-mate, pairs closer than two people stand (linked pairs aside), defenders within 2 m
# of the raider while he works, whether anyone is in his way home as he runs for it, and how many team-mates
# were near enough to help when he was first held.
var _shape := {"mate_gap": [], "bunched": [], "near_raider": [], "home_covered": [], "helpers_near": []}
var _cur = null
var _rs := {}
var _score_errors := []   # matches whose points do not add up
var _evs := []            # every gameplay event: [seconds, kind, info] (see _event_checks)
var _clock := 0.0
# Which hold each escape can slip (as Grapple.ESCAPES; kept here so the bench measures older builds too).
const FITS := {"dubki": {"waist": 1.0, "block": 1.0, "thigh": 0.35, "ankle": 0.0},
	"lion": {"ankle": 1.0, "thigh": 0.35, "waist": 0.0, "block": 0.0},
	"dodge": {"thigh": 1.0, "waist": 0.8, "block": 0.8, "ankle": 0.0}}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 2
	var diff := int(args[1]) if args.size() > 1 else 1
	var kinds := {}
	var landed := {}
	var tried := {}
	var caught := 0
	var dmv := {}
	var raids := 0
	var secs := 0.0
	var probe_secs := 0.0
	var pairs := [["MUM", "DEL"], ["PAT", "BLR"], ["IND", "IRN"], ["KOL", "JAI"]]
	for i in n:
		var pr: Array = pairs[i % pairs.size()]
		var m: Node = load("res://game/match.gd").new()
		m.config = {"home": pr[0], "away": pr[1], "arena": "dome", "mode": "quick", "autoplay": true, "autoplay_no_report": true, "length": 0, "difficulty": diff}
		_done = false
		m.finished.connect(func(r):
			_result = r
			_done = true)
		add_child(m)
		m.game_event.connect(func(kind, info): _evs.append([_clock, String(kind), (info as Dictionary).duplicate()]))
		while not _done:
			await get_tree().process_frame
			_clock += 1.0 / 30.0
			_sample(m, 1.0 / 30.0)
		_close_raid()
		print("match %d: %s %d - %d %s" % [i + 1, pr[0], _result.score[0], _result.score[1], pr[1]])
		_check_points(i + 1, _result)
		_all_logs.append_array(_result.raid_log)
		for r in _result.raid_log:
			var k: String = r.kind
			if k == "return":
				k = "success" if r.raid_pts > 0 else ("empty" if not r.raider_out else "out_rule")
			kinds[k] = kinds.get(k, 0) + 1
			raids += 1
			secs += float(r.t)
			probe_secs += float(r.get("probe_t", 0.0))
			if r.get("chain_caught", false):
				caught += 1
			if String(r.get("first_hold", "")) != "":
				dmv["held_" + k] = dmv.get("held_" + k, 0) + 1
			if k == "tackle":
				var fh: String = r.get("first_hold", "")
				dmv["T:" + fh] = dmv.get("T:" + fh, 0) + 1
			for mv in r.get("def_moves", []):
				dmv[mv] = dmv.get(mv, 0) + 1
			for mv in r.get("moves", []):
				landed[mv] = landed.get(mv, 0) + 1
		for k in _result.get("move_tries", {}):
			tried[k] = tried.get(k, 0) + int(_result.move_tries[k])
		m.queue_free()
		await get_tree().process_frame
	print("raids %d, avg %.1fs (%.1fs working the cover), outcomes %s" % [raids, secs / maxf(1, raids), probe_secs / maxf(1, raids), str(kinds)])
	print("points accounted for: %s" % ("every match" if _score_errors.is_empty() else "NOT in " + str(_score_errors)))
	var rp := 0
	var dp := 0
	var multi := 0
	for r in _all_logs:
		rp += int(r.raid_pts)
		dp += int(r.def_pts)
		if int(r.raid_pts) >= 2:
			multi += 1
	print("raid points %d, defence points %d, raids with 2+ points %d" % [rp, dp, multi])
	var held_pts := 0
	var held_n := 0
	var clean_pts := 0
	var clean_n := 0
	for r in _all_logs:
		if r.kind == "return" and int(r.raid_pts) > 0:
			if String(r.get("first_hold", "")) != "":
				held_pts += int(r.raid_pts)
				held_n += 1
			else:
				clean_pts += int(r.raid_pts)
				clean_n += 1
	var vias := {}
	for r in _all_logs:
		for v in r.get("vias", []):
			vias[v] = vias.get(v, 0) + 1
	print("touches by kind ", vias)
	print("successful raids: held %d (%d pts), clean %d (%d pts)" % [held_n, held_pts, clean_n, clean_pts])
	print("caught crossing a chain %d" % caught)
	print("moves landed %s" % str(landed))
	print("moves tried %s" % str(tried))
	print("defensive grips %s" % str(dmv))
	var rows := []
	for r in _all_logs:
		if String(r.get("first_hold", "")) != "":
			rows.append("%s d%.1f t%.1f h%d" % [r.kind, float(r.hold_depth), float(r.held_for), int(r.holders_end)])
	print("holds: ", ", ".join(rows.slice(0, 40)))
	_print_style()
	_event_checks()
	get_tree().quit()


## Every point given once: each team's score is its breakdown (raids, tackles, all outs, extras), and its raid
## and tackle points are what its raids and its defence earned, raid by raid, as logged.
func _check_points(n: int, res: Dictionary) -> void:
	var ok := true
	var rsum := [0, 0]
	var dsum := [0, 0]
	var teams_known := true
	for r in res.raid_log:
		if not r.has("team"):
			teams_known = false
			continue
		rsum[int(r.team)] += int(r.raid_pts)
		dsum[1 - int(r.team)] += int(r.def_pts)
	for t in 2:
		var b: Dictionary = res.breakdown[t]
		if int(res.score[t]) != int(b.raid) + int(b.tackle) + int(b.allout) + int(b.extra):
			ok = false
		if teams_known and (rsum[t] != int(b.raid) or dsum[t] != int(b.tackle)):
			ok = false
	if not ok:
		_score_errors.append(n)


## Whether the gameplay events make sense together, over every raid played:
##   a touched defender's grab back (a hold not from a dive): how long after the touch (in the same frame is
##   no reaction at all);
##   a takedown: how long after the newest hold still on him (under 0.6 s, the hold had no time to be one);
##   an escape: whether it left him still held (then "Broke free!" is wrong), and whether the move could slip
##   that hold at all (a dubki out of an ankle hold, a jump out of arms round his middle);
##   a hold: on a part of him someone else already holds (one defender a part).
func _event_checks() -> void:
	var grab := []
	var same_frame := 0
	var downs := []
	var quick := 0
	var escapes := 0
	var partial := 0
	var misfit := 0
	var doubled := 0
	var holds := 0
	var holders := {}
	var slots := {}
	var since := {}
	var touched := {}
	for e in _evs:
		var t: float = e[0]
		var k: String = e[1]
		var info: Dictionary = e[2]
		var who := String(info.get("who", info.get("from", "")))
		match k:
			"touch":
				touched[who] = t
			"hold":
				holds += 1
				var slot := String(info.get("slot", ""))
				if slot != "" and slots.values().has(slot):
					doubled += 1
				slots[who] = slot
				holders[who] = String(info.get("style", ""))
				since[who] = t
				if touched.has(who) and t - float(touched[who]) < 1.0 and String(info.get("kind", "")) == "pile":
					grab.append(snappedf(t - float(touched[who]), 0.01))
					if t - float(touched[who]) < 0.02:
						same_frame += 1
					touched.erase(who)
			"release":
				holders.erase(who)
				slots.erase(who)
				since.erase(who)
			"escape":
				escapes += 1
				if holders.size() > 1:
					partial += 1
				var how := String(info.get("how", ""))
				if not FITS.has(how):
					how = "lion"
				if float(FITS[how].get(String(holders.get(who, "")), 1.0)) <= 0.0:
					misfit += 1
			"takedown":
				if not since.is_empty():
					var newest: float = since.values().max()
					downs.append(t - newest)
					if t - newest < 0.59:
						quick += 1
			"raid_end":
				holders.clear()
				slots.clear()
				since.clear()
				touched.clear()
	print("event checks")
	print("  %-40s %d, %d in the same frame as the touch; after %s s (median)" % ["grabs back at a touch", grab.size(), same_frame, _pct(grab, 50)])
	print("  %-40s %d of %d (newest hold to takedown, median %s s)" % ["takedowns within 0.6 s of a new hold", quick, downs.size(), _pct(downs, 50)])
	print("  %-40s %d of %d" % ["escapes that left him still held", partial, escapes])
	print("  %-40s %d of %d" % ["escapes the move could not make", misfit, escapes])
	print("  %-40s %d of %d" % ["holds on a part already held", doubled, holds])


## One frame of the running match: raider attempts, defenders' dives, holds and spacing.
func _sample(m: Node, dt: float) -> void:
	if m.phase != "raid" or m.raider == null:
		return
	if not is_same(m.raid, _cur):
		_close_raid()
		_cur = m.raid
		_rs = {"t": 0.0, "enter": -1.0, "last": "", "attempts": [], "def_state": {}, "hold": -1.0, "holders": 0, "top": 0.0, "pos": []}
	_rs.t += dt
	var r: Dictionary = m.raid
	if not r.entered:
		return
	if _rs.enter < 0.0:
		_rs.enter = _rs.t
	var t: float = _rs.t - _rs.enter
	var defs: Array = m.defenders()
	var near := 99.0
	for d in defs:
		near = minf(near, d.position.distance_to(m.raider.position))
	var held: bool = not r.holders.is_empty()
	if not held and near < 50.0:
		_style.near.append(near)
	var s: String = m.raider.state
	if s in ["touch", "kick", "backkick"] and s != _rs.last:
		_rs.attempts.append(t)
		_style.attempt_gap.append(near)
	_rs.last = s
	for d in defs:
		var was: String = _rs.def_state.get(d, "")
		if d.state == "telegraph" and was not in ["telegraph", "dive"] and _rs.hold < 0.0:
			_style.dive_gap.append(d.position.distance_to(m.raider.position))
		_rs.def_state[d] = d.state
	if held and _rs.hold < 0.0:
		_rs.hold = t
		_style.tackle_after.append(t)
		var close := 0
		for d in defs:
			if not r.holders.has(d) and d.position.distance_to(m.raider.position) < 4.2:
				close += 1
		_shape.helpers_near.append(close)
	if _rs.hold >= 0.0 and r.holders.size() > _rs.holders:
		if _rs.holders > 0:
			_style.help.append(t - _rs.hold)
		_rs.holders = r.holders.size()
	var sp: float = Vector2(m.raider.vel.x, m.raider.vel.z).length()
	# Top speed as the footage measures it: the best half second, from positions.
	_rs.pos.append(m.raider.position)
	if _rs.pos.size() > 15:
		_rs.pos.pop_front()
		_rs.top = maxf(_rs.top, Vector2(_rs.pos[-1].x - _rs.pos[0].x, _rs.pos[-1].z - _rs.pos[0].z).length() / (14.0 * dt))
	if r.get("ai_mode", "") == "probe" and not held:
		_style.probe_speed.append(sp)
	if not held and int(_rs.t * 30.0) % 10 == 0:
		_sample_shape(m, defs)
		var ds := []
		var xs := []
		for d in defs:
			if d.state in ["ready", "idle"]:
				ds.append(m.depth_in(d.team, d.position))
				xs.append(d.position.x)
		if ds.size() >= 3:
			# How far apart front to back: the standard deviation of their depths (0 for a straight line).
			var mean := 0.0
			for x in ds:
				mean += float(x) / ds.size()
			var var_sum := 0.0
			for x in ds:
				var_sum += pow(float(x) - mean, 2.0) / ds.size()
			_style.def_stagger.append(snappedf(sqrt(var_sum), 0.01))
			ds.sort()
			_style.def_depth.append(ds[ds.size() / 2])
			_style.def_width.append(xs.max() - xs.min())


func _sample_shape(m: Node, defs: Array) -> void:
	var set := defs.filter(func(d): return d.state in ["ready", "idle"])
	var bunched := 0
	var near := 0
	for d in set:
		var best := 99.0
		for o in defs:
			if o == d:
				continue
			var g := Vector2(o.position.x - d.position.x, o.position.z - d.position.z).length()
			best = minf(best, g)
			if set.has(o) and o.get_instance_id() > d.get_instance_id() and g < 0.9 and d.chain_partner != o:
				bunched += 1
		if best < 99.0:
			_shape.mate_gap.append(best)
		if d.position.distance_to(m.raider.position) < 2.0:
			near += 1
	_shape.bunched.append(bunched)
	if m.raid.get("ai_mode", "") in ["probe", "approach"]:
		_shape.near_raider.append(near)
	# Running home after a touch: is anyone between him and the midline, in his lane?
	var home := Vector3(0, 0, m.side(m.raiding))
	var dep: float = m.depth_in(1 - m.raiding, m.raider.position)
	if not m.raid.touched.is_empty() and m.raider.vel.dot(home) > 1.0 and dep > 0.8:
		var covered := 0.0
		for d in defs:
			if d.state in ["ready", "idle", "telegraph", "dive"]:
				var dd: float = m.depth_in(1 - m.raiding, d.position)
				if dd > 0.0 and dd < dep and absf(d.position.x - m.raider.position.x) < 1.2:
					covered = 1.0
		_shape.home_covered.append(covered)


func _close_raid() -> void:
	if _cur == null or _rs.is_empty() or _rs.enter < 0.0:
		_cur = null
		return
	var a: Array = _rs.attempts
	if a.size() > 0:
		_style.first_attempt.append(a[0])
	for i in range(1, a.size()):
		_style.between.append(a[i] - a[i - 1])
	_style.top_speed.append(_rs.top)
	_cur = null


func _pct(v: Array, q: float) -> String:
	if v.is_empty():
		return "-"
	var s := v.duplicate()
	s.sort()
	return "%.2f" % float(s[clampi(int(round(q / 100.0 * (s.size() - 1))), 0, s.size() - 1)])


func _print_style() -> void:
	var ref := {}
	var f := FileAccess.open("res://tools/mocap/footage/style.json", FileAccess.READ)
	if f:
		ref = JSON.parse_string(f.get_as_text()).get("combined", {})
	print("footage comparison (game: median [p10..p90]; footage from tools/mocap/footage/style.json)")
	var rows := [
		["first attempt after entering (s)", "first_attempt", "first_attempt_after_s"],
		["between attempts (s)", "between", "between_attempts_s"],
		["nearest defender at an attempt (m)", "attempt_gap", "attempt_gap_m"],
		["nearest defender while raiding (m)", "near", "nearest_defender_median_m"],
		["defender's gap when going for him (m)", "dive_gap", "dive_gap_m"],
		["first hold after entering (s)", "tackle_after", "tackle_after_s"],
		["help after the first hold (s)", "help", "help_after_hold_s"],
		["raider speed working the cover (m/s)", "probe_speed", "raider_probing_ms"],
		["raider top speed (m/s)", "top_speed", "raider_top_ms"],
		["defenders' line depth (m)", "def_depth", "defender_depth_m"],
		["defenders' spread across (m)", "def_width", "defender_width_m"],
		["defenders' depths, front to back (sd, m)", "def_stagger", "defender_stagger_m"],
	]
	for row in rows:
		var v: Array = _style[row[1]]
		print("  %-40s game %s [%s..%s] n%d   footage %s" % [row[0], _pct(v, 50), _pct(v, 10), _pct(v, 90), v.size(), str(ref.get(row[2], "-"))])
	print("defence shape")
	print("  %-40s %s [%s..%s]" % ["set defender's nearest team-mate (m)", _pct(_shape.mate_gap, 50), _pct(_shape.mate_gap, 10), _pct(_shape.mate_gap, 90)])
	print("  %-40s %.2f" % ["pairs closer than 0.9 m (unlinked, mean)", _mean(_shape.bunched)])
	print("  %-40s %.2f" % ["defenders within 2 m of the raider (mean)", _mean(_shape.near_raider)])
	print("  %-40s %.0f%%" % ["way home covered as he runs for it", 100.0 * _mean(_shape.home_covered)])
	print("  %-40s %.2f" % ["team-mates within 4.2 m at the first hold", _mean(_shape.helpers_near)])


func _mean(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var t := 0.0
	for x in v:
		t += float(x)
	return t / v.size()
