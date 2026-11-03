extends SceneTree
## WsgSim proves itself on its demo game (tests/sim_demo): a clean batch passes; every check catches the bug it is
## for (each a switch in the demo: a score jumping by two, a stuck player, an endless match, a NaN ball, a script error,
## a clock running backwards, a player walking through the bench, a ball through it, a fetcher turning back and forth
## in front of the bench) under its own signature; the ball fetched from behind each big prop; a
## failure replays from its seed; the same seed twice is the same match frame for frame, and a decision on the wall
## clock is caught diverging; the RNG lint finds a bare randf; the menu fuzzer walks every screen and catches a broken
## button and a dead end; a frozen match is recorded by the shard runner and the batch goes on.
##   godot --headless --fixed-fps 30 --path . -s tests/sim_test.gd

const Demo := preload("res://tests/sim_demo/demo_sim.gd")
const SCRATCH := "user://sim_test"

var fails := []


func _initialize() -> void:
	await process_frame
	var game := Demo.new()
	var sim := WsgSim.new()
	sim.opts = {"feet": false}
	# A clean little batch.
	var bad := 0
	for k in ["random", "extreme", "targeted:scoring", "targeted:timer", "targeted:collisions", "targeted:completion"]:
		for sd in [1, 2]:
			var r: Dictionary = await sim.run(game, k, sd, self)
			if not r.ok:
				bad += 1
				fails.append("clean %s#%d failed: %s" % [k, sd, (r.failures as Array).map(func(f: Dictionary) -> String: return f.message)])
	print("clean: 12 matches, %d failed" % bad)
	# Every bug caught, by the right check.
	var want := {"score_twice": "score", "stuck": "stuck", "endless": "clock", "nan": "nan", "script_error": "script error",
		"clock_back": "clock", "through_bench": "prop", "ball_through": "ball through"}
	var caught := {}
	for bug in want:
		var r: Dictionary = await sim.run(game, "bug:" + bug, 3, self)
		var checks := (r.failures as Array).map(func(f: Dictionary) -> String: return f.check)
		caught[bug] = checks
		var first: String = (r.failures as Array)[0].message if not (r.failures as Array).is_empty() else "-"
		print("bug %-14s -> %s (%s)" % [bug, checks, first])
		if not checks.has(want[bug]):
			fails.append("the %s bug was not caught by the %s check (got %s)" % [bug, want[bug], checks])
	# The fetch-behind-prop case: the ball behind each of the three largest props, fetched in time, nothing warned;
	# a fetcher turning back and forth in front of the bench (Sepak Takraw's freeze) caught by no progress and the
	# fetch's time, its steering warned of.
	for sd in [1, 2, 3]:
		var r: Dictionary = await sim.run(game, WsgSim.FETCH_KIND, sd, self)
		print("fetch #%d: %s%s" % [sd, r.get("fetch", "-"), "" if r.ok else " FAILED %s" % [(r.failures as Array).map(func(f: Dictionary) -> String: return f.message)]])
		if not r.ok or not String(r.get("fetch", "")).contains("reached") or r.has("warnings"):
			fails.append("a clean fetch behind a prop (seed %d): %s %s %s" % [sd, r.get("fetch", "-"), r.failures, r.get("warnings", [])])
	# Not wired: noted before the lead's time, failed from it.
	var unwired := Demo.new()
	unwired.no_fetch = true
	OS.set_environment("WSG_NOW", "2026-11-04T11:59Z")
	var ru1: Dictionary = await sim.run(unwired, WsgSim.FETCH_KIND, 1, self)
	OS.set_environment("WSG_NOW", "2026-11-04T12:00Z")
	var ru2: Dictionary = await sim.run(unwired, WsgSim.FETCH_KIND, 1, self)
	OS.set_environment("WSG_NOW", "")
	var u1: bool = ru1.ok and String(ru1.get("fetch", "")).contains("not wired")
	var u2: bool = (ru2.failures as Array).any(func(f: Dictionary) -> bool: return f.check == "fetch" and String(f.message).contains("not wired"))
	print("fetch not wired: before 2026-11-04 12:00 %s, from it %s" % ["noted" if u1 else "WRONG", "failed" if u2 else "WRONG"])
	if not u1 or not u2:
		fails.append("fetch not wired: before %s, from %s" % [ru1, ru2.failures])
	var rd: Dictionary = await sim.run(game, "bug:fetch_dither", 3, self)
	var dchecks := (rd.failures as Array).map(func(f: Dictionary) -> String: return f.check)
	print("bug fetch_dither -> %s, warnings %s" % [dchecks, rd.get("warnings", [])])
	if not dchecks.has("no progress") or not dchecks.has("fetch") or not str(rd.get("warnings", [])).contains("steer flip"):
		fails.append("the fetcher turning back and forth was not caught (no progress, fetch, steer flip): %s %s" % [dchecks, rd.get("warnings", [])])
	# A check put off for the game until a time, with its reason: reported, not failed, before it; failed after it.
	game.defer = {"stuck": ["2999-01-01T00:00Z", "the lead, a test: foundation fix pending"]}
	var rdf: Dictionary = await sim.run(game, "bug:stuck", 3, self)
	game.defer = {"stuck": ["2000-01-01T00:00Z", "the lead, a test: foundation fix pending"]}
	var rdp: Dictionary = await sim.run(game, "bug:stuck", 3, self)
	game.defer = {}
	var before_ok: bool = not (rdf.failures as Array).any(func(f: Dictionary) -> bool: return f.check == "stuck") and str(rdf.get("warnings", [])).contains("deferred stuck")
	var after_ok: bool = (rdp.failures as Array).any(func(f: Dictionary) -> bool: return f.check == "stuck")
	print("deferred stuck: before its time %s, after it %s" % ["reported, not failed" if before_ok else "WRONG", "failed" if after_ok else "WRONG"])
	if not before_ok or not after_ok:
		fails.append("a deferred check: before %s %s, after %s" % [rdf.failures, rdf.get("warnings", []), rdp.failures])
	# The endless match also ends as "endless" (the clock stood still, then the limit).
	if not (caught.endless as Array).has("endless"):
		fails.append("an endless match was not reported as endless: %s" % [caught.endless])
	# A failure replays from its seed, at the same frame.
	var r1: Dictionary = await sim.run(game, "bug:clock_back", 4, self)
	var f1: Dictionary = r1.failures[0]
	var rep := WsgSim.new()
	rep.opts = {"stop_frame": int(f1.frame), "feet": false}
	var r2: Dictionary = await rep.run(game, "bug:clock_back", 4, self)
	var again := (r2.failures as Array).any(func(f: Dictionary) -> bool: return f.signature == f1.signature and int(f.frame) == int(f1.frame))
	print("replay: the clock failure at frame %d %s" % [f1.frame, "happened again at the same frame" if again else "did NOT happen again"])
	if not again:
		fails.append("a failure did not replay from its seed")
	# Determinism: the same seed twice, frame for frame; a decision on the wall clock diverges.
	for k in ["random", "bug:wallclock"]:
		var a := WsgSim.new()
		a.opts = {"hash_every": 15, "feet": false}
		var b := WsgSim.new()
		b.opts = {"hash_every": 15, "feet": false}
		var ra: Dictionary = await a.run(game, k, 77, self)
		var rb: Dictionary = await b.run(game, k, 77, self)
		var same: bool = ra.hashes == rb.hashes
		print("determinism %s: %s (%d checks)" % [k, "the same frame for frame" if same else "diverged", (ra.hashes as Array).size()])
		if k == "random" and not same:
			fails.append("the same seed played two different matches")
		if k == "bug:wallclock" and same:
			fails.append("a decision on the wall clock was not caught diverging")
	# The RNG lint.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	var fx := FileAccess.open(SCRATCH + "/fixture.gd", FileAccess.WRITE)
	fx.store_string("var rng := RandomNumberGenerator.new()\nfunc a():\n\tvar x := randf()\n\tvar y := rng.randf()\n\tvar l := [1, 2]\n\tl.shuffle()\n\tvar z := randi() # wsg-rng-ok: a test\n")
	fx.close()
	var out := []
	var code := OS.execute("sh", [ProjectSettings.globalize_path("res://tools/rng_lint.sh"), ProjectSettings.globalize_path(SCRATCH)], out, true)
	var lines := Array(String(out[0]).split("\n", false)).filter(func(l: String) -> bool: return l.contains("fixture.gd:"))
	print("rng_lint on a fixture: exit %d, %d lines flagged (randf, shuffle; rng.randf and the marked one let off)" % [code, lines.size()])
	if code == 0 or lines.size() != 2:
		fails.append("rng_lint flagged %d lines (want 2: the bare randf and shuffle), exit %d: %s" % [lines.size(), code, lines])
	# The menu fuzzer: every screen, and a broken button and a dead end caught.
	var log := WsgSimLog.new()
	OS.add_logger(log)
	for mb in ["", "credits", "dead end"]:
		var g := Demo.new()
		g.menu_bug = mb
		var mf := WsgSimMenu.new(g, 11, self)
		var mr: Dictionary = await mf.run(250, log)
		g.stop()
		await process_frame
		print("menu fuzz (%s): %d presses on %d controls, %s" % ["clean" if mb == "" else mb, mr.presses, mr.get("controls", 0), "ok" if mr.ok else "FAIL %s" % [mr.failures]])
		if mb == "" and (not mr.ok or int(mr.get("controls", 0)) < 6):
			fails.append("the clean menu: %s" % mr)
		if mb != "" and mr.ok:
			fails.append("the menu's %s was not caught" % mb)
	# A frozen match: the shard runner records it and goes on.
	var sd := ProjectSettings.globalize_path(SCRATCH + "/shard")
	OS.execute("rm", ["-rf", sd])
	var env_out := []
	OS.execute("sh", ["-c", "HANG=10 sh '%s' '%s' '%s' --game res://tests/sim_demo/demo_sim.gd --kinds bug:freeze,random --from 1 --count 2 --no-feet" % [ProjectSettings.globalize_path("res://tools/sim_shard.sh"), ProjectSettings.globalize_path("res://"), sd]], env_out, true)
	var res := FileAccess.get_file_as_string(sd + "/results.jsonl")
	var froze := res.contains("\"freeze\"")
	var went_on := res.contains("\"ok\":true")
	print("a frozen match: %s; the batch went on: %s" % ["recorded as a freeze" if froze else "NOT recorded", went_on])
	if not froze or not went_on:
		fails.append("the shard runner: freeze recorded %s, batch went on %s\n%s" % [froze, went_on, env_out])
	for f in fails:
		printerr("FAIL: ", f)
	print("SIM TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
