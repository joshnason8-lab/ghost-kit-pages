extends SceneTree
## WsgSim's batches (the owner: "Run thousands of simulated matches using the actual game logic ... headless and faster
## than real time ... reproducible random seeds"). Run with --fixed-fps 30 (each frame 1/30 s of game time, as fast as
## the computer goes) and --headless:
##
##   godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- <command> [options]
##
##   batch --game res://game/sim.gd --out DIR [--smoke | --from N --count M] [--kinds a,b] [--shard I/N] [--input]
##         [--no-feet]
##       Matches seed after seed. --smoke: 50 seeds (random and extreme) + every targeted kind x 3 seeds + every
##       permanent case (res://tests/sim_cases.json). Writes DIR/sim_report.json, DIR/SIM_REPORT.md (what ran, the
##       failures grouped by signature and ranked by how often x how bad, balance, speed, what it cannot see),
##       DIR/failures/<signature>/<seed>.json (each with its replay command). Exits 1 on any failure.
##   replay --game ... --failure DIR/failures/x/123.json
##       The same match again, stopping at the failure's frame with the state printed (add no --headless and drop
##       --fixed-fps to watch it).
##   determinism --game ... --seeds N [--realtime]
##       Each seed twice (the second at 1x real time with --realtime): their states must match frame for frame.
##   menu --game ... --seeds N --steps S [--saves]
##       The menu fuzzer (WsgSimMenu), each seed from the main menu; --saves spoils the save files first.
##   merge --out DIR DIR1 DIR2 ...     (shards' reports into one)
##   adopt DIR/failures/x/123.json     (that match into res://tests/sim_cases.json: run by every smoke batch for good)
##
## DIR must be outside the project (an export would pack it). tools/wsg/sim_shard.sh runs a batch so that a freeze or
## a crash is recorded and the batch goes on; tools/wsg/sim_ci.yml is the CI workflow (smoke on every push, nightly
## shards). ADOPTING.md §5.17.

const CASES := "res://tests/sim_cases.json"

var args := {}
var out_dir := ""


func _initialize() -> void:
	await process_frame
	var a := OS.get_cmdline_user_args()
	if a.is_empty():
		printerr("sim: -- batch|replay|determinism|menu|merge|adopt [options] (see tools/wsg/sim.gd)")
		quit(2)
		return
	var cmd := String(a[0])
	var pos := []
	var i := 1
	while i < a.size():
		var s := String(a[i])
		if s.begins_with("--"):
			if i + 1 < a.size() and not String(a[i + 1]).begins_with("--"):
				args[s.substr(2)] = a[i + 1]
				i += 2
				continue
			args[s.substr(2)] = true
		else:
			pos.append(s)
		i += 1
	if args.has("out"):
		out_dir = _outside(String(args.out))
		if out_dir == "":
			quit(2)
			return
		DirAccess.make_dir_recursive_absolute(out_dir)
	var code := 0
	match cmd:
		"batch":
			code = await _batch()
		"replay":
			code = await _replay()
		"determinism":
			code = await _determinism()
		"menu":
			code = await _menu()
		"merge":
			code = _merge(pos)
		"adopt":
			code = _adopt(pos)
		_:
			printerr("sim: no command '%s'" % cmd)
			code = 2
	quit(code)


func _game() -> WsgSimGame:
	var path := String(args.get("game", "res://game/sim.gd"))
	var s: Script = load(path)
	if s == null or not s.can_instantiate():
		printerr("sim: the game's adapter %s does not load (a parse error above?)" % path)
		quit(2)
		return null
	return s.new() as WsgSimGame


# ---------------------------------------------------------------- batch

func _batch() -> int:
	var game := _game()
	var plan := []          # [kind, seed]
	var kinds: Array = String(args.get("kinds", "")).split(",", false) if args.has("kinds") else []
	var scen := game.scenarios()
	var targeted := scen.filter(func(k: String) -> bool: return k.begins_with("targeted:"))
	var general := scen.filter(func(k: String) -> bool: return not k.begins_with("targeted:"))
	if kinds.is_empty():
		kinds = general
	if args.has("smoke"):
		for n in 50:
			plan.append([kinds[n % kinds.size()], 1 + n])
		for k in targeted:
			for n in 3:
				plan.append([k, 101 + n])
		for c in _cases():
			plan.append([String(c.kind), int(c.seed)])
	else:
		var from := int(args.get("from", 1))
		var count := int(args.get("count", 100))
		for n in count:
			var sd := from + n
			# Every tenth seed a targeted case (in turn), the rest the general kinds (in turn).
			var k: String = targeted[(sd / 10) % targeted.size()] if not targeted.is_empty() and sd % 10 == 0 else kinds[sd % kinds.size()]
			plan.append([k, sd])
	if args.has("shard"):
		var sh := String(args.shard).split("/")
		var si := int(sh[0])
		var sn := int(sh[1])
		plan = plan.filter(func(p: Array) -> bool: return int(p[1]) % sn == si)
	var done := _done_seeds()
	var sim := WsgSim.new()
	sim.opts = {"input": args.has("input"), "feet": not args.has("no-feet")}
	var results := []
	var t0 := Time.get_ticks_msec()
	for p in plan:
		var key := "%s#%d" % [p[0], p[1]]
		if done.has(key):
			continue
		_progress("running\t%s\t%d" % [p[0], p[1]])
		var r: Dictionary = await sim.run(game, String(p[0]), int(p[1]), self)
		_strip(r)
		results.append(r)
		_append_done(key, r)
		var mark := "ok" if r.ok else "FAIL %s" % ", ".join((r.failures as Array).map(func(f: Dictionary) -> String: return f.signature))
		print("%-22s seed %6d  %6.1f s simulated in %5.2f s (x%.0f)  %s" % [p[0], p[1], r.sim_s, r.wall_s, r.speed, mark])
	_progress("")
	var all := _load_done()
	var rep := _report(game, all, (Time.get_ticks_msec() - t0) / 1000.0)
	_write_report(rep)
	print("SIM BATCH: %d matches, %d failed, %d signatures; x%.0f real time; report %s" % [rep.matches, rep.failed, (rep.signatures as Array).size(), rep.speed.median, out_dir.path_join("SIM_REPORT.md")])
	return 0 if rep.failed == 0 else 1


## What a result keeps for the report (the hashes are for determinism only).
func _strip(r: Dictionary) -> void:
	r.erase("hashes")


func _cases() -> Array:
	if not FileAccess.file_exists(CASES):
		return []
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(CASES))
	return (j as Dictionary).get("cases", []) if j is Dictionary else []


func _progress(s: String) -> void:
	var f := FileAccess.open(out_dir.path_join("progress.txt"), FileAccess.WRITE)
	f.store_string(s)
	f.close()


func _done_seeds() -> Dictionary:
	var d := {}
	for r: Dictionary in _load_done():
		d["%s#%d" % [r.kind, r.seed]] = true
	return d


func _load_done() -> Array:
	var p := out_dir.path_join("results.jsonl")
	var out := []
	if FileAccess.file_exists(p):
		for line in FileAccess.get_file_as_string(p).split("\n", false):
			var j: Variant = JSON.parse_string(line)
			if j is Dictionary:
				out.append(j)
	return out


func _append_done(_key: String, r: Dictionary) -> void:
	var p := out_dir.path_join("results.jsonl")
	var f := FileAccess.open(p, FileAccess.READ_WRITE if FileAccess.file_exists(p) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify(WsgSim._plain(r)))
	f.close()
	for fl: Dictionary in r.failures:
		var d := out_dir.path_join("failures").path_join(_slug(fl.signature))
		DirAccess.make_dir_recursive_absolute(d)
		var ff := FileAccess.open(d.path_join("%d.json" % int(r.seed)), FileAccess.WRITE)
		var rec := {"seed": r.seed, "kind": r.kind, "config": r.config, "failure": fl,
			"replay": "godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- replay --game %s --failure %s" % [args.get("game", "res://game/sim.gd"), d.path_join("%d.json" % int(r.seed))]}
		ff.store_string(JSON.stringify(WsgSim._plain(rec), "  "))
		ff.close()


static func _slug(s: String) -> String:
	var re := RegEx.new()
	re.compile("[^a-z0-9]+")
	return re.sub(s.to_lower(), "_", true).left(80).trim_suffix("_")


## The batch's report: what ran, failures by signature (ranked by count x severity), balance, speed, coverage gaps.
func _report(game: WsgSimGame, all: Array, wall: float) -> Dictionary:
	var sigs := {}
	var failed := 0
	var by_kind := {}
	var speeds := []
	var sim_total := 0.0
	for r: Dictionary in all:
		by_kind[r.kind] = int(by_kind.get(r.kind, 0)) + 1
		speeds.append(float(r.get("speed", 0.0)))
		sim_total += float(r.get("sim_s", 0.0))
		if not bool(r.ok):
			failed += 1
		for f: Dictionary in r.failures:
			var g: Dictionary = sigs.get(f.signature, {"signature": f.signature, "check": f.check, "severity": f.severity, "count": 0, "seeds": [], "example": f.message})
			g.count = int(g.count) + 1
			if (g.seeds as Array).size() < 10:
				(g.seeds as Array).append("%s#%d" % [r.kind, r.seed])
			sigs[f.signature] = g
	var ranked := sigs.values()
	ranked.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x.count) * int(x.severity) > int(y.count) * int(y.severity))
	speeds.sort()
	if wall <= 0.0:
		for r: Dictionary in all:
			wall += float(r.get("wall_s", 0.0))
	return {"game": game.game_name(), "matches": all.size(), "failed": failed, "by_kind": by_kind, "signatures": ranked,
		"balance": _balance(all),
		"speed": {"median": float(speeds[speeds.size() / 2]) if not speeds.is_empty() else 0.0,
			"min": float(speeds[0]) if not speeds.is_empty() else 0.0, "simulated_s": snappedf(sim_total, 0.1),
			"wall_s": snappedf(wall, 0.1)},
		"cannot_see": ["how it looks: animation quality, popping, clipping the checks do not measure",
			"on-device performance: stutter, frame times, load times and heat on the A16 (the on-device diagnostics screen, deferred, is the place)",
			"touch feel: the real touch screen, thumb reach, the on-screen joystick's dead zone",
			"audio as heard, haptics as felt", "the GPU: shaders, draw calls, texture memory (headless draws nothing)"]}


## Win rates, scores and lengths by each balance key's value; flags for the owner (never changed without their OK).
func _balance(all: Array) -> Dictionary:
	var groups := {}
	for r: Dictionary in all:
		var res: Dictionary = r.get("result", {})
		if res.is_empty():
			continue
		var keys: Dictionary = r.get("balance", {})
		keys["all"] = "all"
		for k in keys:
			var gk := "%s=%s" % [k, keys[k]]
			var g: Dictionary = groups.get(gk, {"n": 0, "home": 0, "away": 0, "draw": 0, "length": 0.0, "goals": 0.0, "fair": bool(keys.get("fair", false))})
			g.n = int(g.n) + 1
			var w := int(res.get("winner", -1))
			if w == 0:
				g.home = int(g.home) + 1
			elif w == 1:
				g.away = int(g.away) + 1
			else:
				g.draw = int(g.draw) + 1
			g.length = float(g.length) + float(r.get("sim_s", 0.0))
			var sc: Array = res.get("score", [])
			for v in sc:
				g.goals = float(g.goals) + float(v)
			groups[gk] = g
	var flags := []
	for gk in groups:
		var g: Dictionary = groups[gk]
		var n := float(g.n)
		g.home_rate = snappedf(g.home / n, 0.01)
		g.away_rate = snappedf(g.away / n, 0.01)
		g.draw_rate = snappedf(g.draw / n, 0.01)
		g.mean_length_s = snappedf(g.length / n, 0.1)
		g.mean_total_score = snappedf(g.goals / n, 0.01)
		if n >= 50 and String(gk).begins_with("fair=true") and absf(g.home_rate - g.away_rate) > 0.15:
			flags.append("%s: equal sides, but home wins %.0f%% and away %.0f%% (n %d)" % [gk, g.home_rate * 100.0, g.away_rate * 100.0, g.n])
		if n >= 50 and g.draw_rate > 0.35:
			flags.append("%s: %.0f%% draws (n %d)" % [gk, g.draw_rate * 100.0, g.n])
		if n >= 50 and String(gk).begins_with("strategy") and maxf(g.home_rate, g.away_rate) > 0.7:
			flags.append("%s: a dominant strategy? %.0f%% wins (n %d)" % [gk, maxf(g.home_rate, g.away_rate) * 100.0, g.n])
		if n >= 50 and g.mean_total_score < 0.2:
			flags.append("%s: hardly any scoring (%.2f a match, n %d)" % [gk, g.mean_total_score, g.n])
	return {"groups": groups, "flags_for_the_owner": flags}


func _write_report(rep: Dictionary) -> void:
	var f := FileAccess.open(out_dir.path_join("sim_report.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(rep, "  "))
	f.close()
	var md := PackedStringArray()
	md.append("# %s: simulated matches" % rep.game)
	md.append("")
	md.append("**%d matches ran, %d failed.** Kinds: %s." % [rep.matches, rep.failed, JSON.stringify(rep.by_kind)])
	md.append("Speed: x%.0f real time (median; slowest x%.0f): %.0f simulated seconds in %.0f wall seconds." % [rep.speed.median, rep.speed.min, rep.speed.simulated_s, rep.speed.wall_s])
	md.append("")
	md.append("## Failures, by signature (ranked: how often x how bad)")
	if (rep.signatures as Array).is_empty():
		md.append("None.")
	for s: Dictionary in rep.signatures:
		md.append("- **%s** - %d matches, severity %d. e.g. %s. Seeds: %s" % [s.signature, s.count, s.severity, s.example, ", ".join(s.seeds)])
	md.append("")
	md.append("## Balance (for the owner: no change without their OK)")
	var flags: Array = rep.balance.flags_for_the_owner
	md.append("Flags: " + ("none" if flags.is_empty() else ""))
	for fl in flags:
		md.append("- " + fl)
	for gk in rep.balance.groups:
		var g: Dictionary = rep.balance.groups[gk]
		md.append("- %s: n %d, home %.0f%%, away %.0f%%, draws %.0f%%, %.1f scored a match, %.0f s long" % [gk, g.n, g.home_rate * 100.0, g.away_rate * 100.0, g.draw_rate * 100.0, g.mean_total_score, g.mean_length_s])
	md.append("")
	md.append("## What this cannot see")
	for c in rep.cannot_see:
		md.append("- " + c)
	var mf := FileAccess.open(out_dir.path_join("SIM_REPORT.md"), FileAccess.WRITE)
	mf.store_string("\n".join(md) + "\n")
	mf.close()


# ---------------------------------------------------------------- replay, determinism, menu

func _replay() -> int:
	var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(args.failure)))
	if not rec is Dictionary:
		printerr("sim replay: cannot read %s" % args.failure)
		return 2
	var sim := WsgSim.new()
	sim.opts = {"stop_frame": int(rec.failure.frame), "input": args.has("input")}
	var r: Dictionary = await sim.run(_game(), String(rec.kind), int(rec.seed), self)
	var again := (r.failures as Array).any(func(f: Dictionary) -> bool: return f.signature == rec.failure.signature)
	print("REPLAY seed %d (%s): %s" % [rec.seed, rec.kind, "the failure happened again: %s" % rec.failure.message if again else "the failure did NOT happen again"])
	return 0 if again else 1


func _determinism() -> int:
	var game := _game()
	var n := int(args.get("seeds", 3))
	var bad := 0
	for k in n:
		var seed := 900 + k
		var kind: String = game.scenarios()[k % game.scenarios().size()]
		var a := WsgSim.new()
		a.opts = {"hash_every": 15, "feet": false}
		var ra: Dictionary = await a.run(game, kind, seed, self)
		var b := WsgSim.new()
		b.opts = {"hash_every": 15, "feet": false, "realtime": args.has("realtime")}
		var rb: Dictionary = await b.run(game, kind, seed, self)
		var ha: Array = ra.hashes
		var hb: Array = rb.hashes
		var diverged := -1
		for i in mini(ha.size(), hb.size()):
			if ha[i][1] != hb[i][1]:
				diverged = int(ha[i][0])
				break
		if diverged < 0 and ha.size() != hb.size():
			diverged = int(ha[mini(ha.size(), hb.size()) - 1][0]) if not ha.is_empty() else 0
		print("seed %d (%s): %s" % [seed, kind, "the same, frame for frame (%d checks)" % ha.size() if diverged < 0 else "DIVERGED at frame %d (%.1f s)" % [diverged, diverged / WsgSim.FPS]])
		if diverged >= 0:
			bad += 1
	print("SIM DETERMINISM: ", "PASS" if bad == 0 else "FAIL (%d of %d seeds)" % [bad, n])
	return 0 if bad == 0 else 1


func _menu() -> int:
	var game := _game()
	var n := int(args.get("seeds", 5))
	var steps := int(args.get("steps", 300))
	var log := WsgSimLog.new()
	OS.add_logger(log)
	var bad := 0
	for k in n:
		var m := WsgSimMenu.new(game, 500 + k, self)
		if args.has("saves"):
			var olds := game.old_saves()
			for p in game.save_paths():
				var mode: String = ["truncate", "garbage", "empty", "flip", "old"][k % 5]
				print("  ", m.corrupt(String(p), mode, String(olds[k % olds.size()]) if not olds.is_empty() else ""))
		var r: Dictionary = await m.run(steps, log)
		print("menu seed %d: %d presses on %d controls: %s" % [500 + k, r.presses, r.get("controls", 0), "ok" if r.ok else "FAIL %s" % [r.failures]])
		if not r.ok:
			bad += 1
		for c in root.get_children():
			c.queue_free()
		await process_frame
	print("SIM MENU: ", "PASS" if bad == 0 else "FAIL (%d of %d)" % [bad, n])
	return 0 if bad == 0 else 1


# ---------------------------------------------------------------- merge, adopt

func _merge(dirs: Array) -> int:
	var all := []
	for d in dirs:
		var p := String(d).path_join("results.jsonl")
		if FileAccess.file_exists(p):
			for line in FileAccess.get_file_as_string(p).split("\n", false):
				var j: Variant = JSON.parse_string(line)
				if j is Dictionary:
					all.append(j)
	var f := FileAccess.open(out_dir.path_join("results.jsonl"), FileAccess.WRITE)
	for r in all:
		f.store_line(JSON.stringify(r))
	f.close()
	var rep := _report(_game(), all, 0.0)
	_write_report(rep)
	print("SIM MERGE: %d matches from %d shards, %d failed" % [rep.matches, dirs.size(), rep.failed])
	return 0 if rep.failed == 0 else 1


func _adopt(files: Array) -> int:
	var data := {"about": "Matches WsgSim once found a bug in: every smoke batch runs them for good (tools/wsg/sim.gd adopt).", "cases": _cases()}
	for p in files:
		var rec: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(p)))
		if rec is Dictionary:
			data.cases.append({"kind": rec.kind, "seed": rec.seed, "signature": rec.failure.signature, "found": Time.get_date_string_from_system()})
			print("adopted %s#%d: %s" % [rec.kind, rec.seed, rec.failure.signature])
	var f := FileAccess.open(CASES, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, " "))
	f.close()
	return 0


## OUT made absolute; "" (and an error) if it is inside the project.
func _outside(d: String) -> String:
	var abs_d := ProjectSettings.globalize_path(d) if d.begins_with("res://") or d.begins_with("user://") else d
	if not abs_d.begins_with("/"):
		abs_d = OS.get_environment("PWD").path_join(abs_d)
	var project := ProjectSettings.globalize_path("res://").simplify_path()
	if d.begins_with("res://") or abs_d.simplify_path().begins_with(project):
		printerr("sim: write outside the project (%s is in it: an export would pack it)" % d)
		return ""
	return abs_d.simplify_path()
