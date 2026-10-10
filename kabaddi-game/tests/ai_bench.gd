extends Node
## Plays AI-vs-AI matches headless and prints raid outcomes and move use, for tuning.
## godot --headless --path . --fixed-fps 30 res://tests/ai_bench.tscn -- [matches] [difficulty]

var _done := false
var _result := {}
var _all_logs := []


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
	get_tree().quit()
