extends Node
## Plays AI-vs-AI matches headless and prints raid outcomes and move use, for tuning.
## godot --headless --path . --fixed-fps 30 res://tests/ai_bench.tscn -- [matches] [difficulty]

var _done := false
var _result := {}
var _all_logs := []
# Footage-comparable measures (tools/mocap/raid_events.py reads the same things off match video).
var _style := {"first_attempt": [], "between": [], "attempt_gap": [], "dive_gap": [], "help": [], "near": [],
		"probe_speed": [], "top_speed": [], "def_depth": [], "def_width": [], "tackle_after": []}
var _cur = null
var _rs := {}


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
		while not _done:
			await get_tree().process_frame
			_sample(m, 1.0 / 30.0)
		_close_raid()
		print("match %d: %s %d - %d %s" % [i + 1, pr[0], _result.score[0], _result.score[1], pr[1]])
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
	get_tree().quit()


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
		var ds := []
		var xs := []
		for d in defs:
			if d.state in ["ready", "idle"]:
				ds.append(m.depth_in(d.team, d.position))
				xs.append(d.position.x)
		if ds.size() >= 3:
			ds.sort()
			_style.def_depth.append(ds[ds.size() / 2])
			_style.def_width.append(xs.max() - xs.min())


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
	]
	for row in rows:
		var v: Array = _style[row[1]]
		print("  %-40s game %s [%s..%s] n%d   footage %s" % [row[0], _pct(v, 50), _pct(v, 10), _pct(v, 90), v.size(), str(ref.get(row[2], "-"))])
