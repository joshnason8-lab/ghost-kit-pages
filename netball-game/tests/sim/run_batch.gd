extends Node
## Simulated matches in a batch (docs/SIM.md): N AI v AI matches of the real game code, headless and faster than real
## time, each from its own seed, the netball rules checked after every step and at every event
## (tests/sim/netball_checks.gd). Failures are written OUTSIDE the project, one JSON a match, with what replays it.
##
##   XDG_DATA_HOME=$TMPDIR/x godot --headless --path . --fixed-fps 30 res://tests/sim/run_batch.tscn -- n=60 out=$TMPDIR/sim
##
## Arguments (key=value, any order):
##   n=60            matches                         seed=1         the batch's seed (match i's config and seed follow
##                                                                  from it and i alone)
##   quarter_s=60    seconds a quarter               first=0        the first match's index (only=i: that one alone)
##   venues=arena,outdoor,hall                       levels=low,medium,high   (each match takes the next venue, and
##                                                                  the level cycles with the venue's round)
##   wsg=off|on      the shared foundation's bodies (FoundationLink) on Medium/High when the licensed data is here
##   steps=4         match steps a frame (each the step a frame always takes: 1/fixed-fps, cut at 0.05 s)
##   dt=0            the step's seconds (0: the frame's)
##   mix=1           vary the settings: knockouts, Double Zone, time-outs, rolling changes, whistle rates (0: plain)
##   hud=off|on      the match's HUD built (as Watch AI's is) or not (as the home screen's match)
##   replays=skip|play   a goal's or intercept's replay skipped at once (a tap) or played
##   repro=0|1       play each match twice and compare (the same seed must give the same match)
##   checks=on|off   the rules checked (off: to time the match alone)
##   profile=0|1     every tenth frame, time the players' and umpires' bodies posed again (what a step's cost is)
##   out=DIR         where failures and the summary go (default $TMPDIR/netball_sim); never inside the project
## Exits 1 when any match has an error-level violation (warnings are counted and ranked, not failures).

const Checks := preload("res://tests/sim/netball_checks.gd")
const LEVELS := {"low": 0, "medium": 1, "high": 2}
const HARMLESS := ["ALSA", "drivers/alsa", "drivers/pulseaudio", "audio_server.cpp", "PulseAudio", "pulseaudio", "AudioDriver", "audio driver", "Audio driver"]

var args := {"n": "60", "seed": "1", "quarter_s": "60", "first": "0", "venues": "arena,outdoor,hall", "levels": "low,medium,high",
	"wsg": "off", "steps": "4", "checks": "on", "profile": "0", "dt": "0", "mix": "1", "hud": "off", "replays": "skip", "repro": "0", "out": ""}
var out_dir := ""
var log_errors: ErrorLog


class ErrorLog extends Logger:
	var mutex := Mutex.new()
	var lines: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_keep("%s %s:%d %s: %s %s" % [["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)], file, line, function, code, rationale])

	func _log_message(message: String, error: bool) -> void:
		if error and (message.begins_with("ERROR") or message.begins_with("SCRIPT ERROR")):
			_keep(message.strip_edges())

	func _keep(s: String) -> void:
		for h in HARMLESS:
			if s.contains(h):
				return
		mutex.lock()
		lines.append(s)
		mutex.unlock()

	func take() -> Array[String]:
		mutex.lock()
		var l := lines.duplicate()
		lines.clear()
		mutex.unlock()
		return l


func _ready() -> void:
	Game.main = self
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	if args.has("only"):
		args.first = args.only
		args.n = "1"
	out_dir = String(args.out)
	if out_dir == "":
		var tmp := OS.get_environment("TMPDIR")
		out_dir = (tmp if tmp != "" else "/tmp").path_join("netball_sim")
	out_dir = out_dir.simplify_path()
	var project := ProjectSettings.globalize_path("res://").simplify_path()
	if out_dir.begins_with(project):
		push_error("run_batch: out=%s is inside the project; failure artifacts go outside it" % out_dir)
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	log_errors = ErrorLog.new()
	OS.add_logger(log_errors)
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.auto_gfx = false
	Game.settings.dev = false
	Engine.max_fps = 0            # (--fixed-fps already runs frames back to back; a Smooth or Battery saver cap is not ours)
	FoundationLink.off = String(args.wsg) != "on"
	var n := int(args.n)
	var first := int(args.first)
	var venues := String(args.venues).split(",")
	var levels := String(args.levels).split(",")
	print("run_batch: %d matches from %d, seed %s, %s s quarters, %s x %s, foundation %s (licensed data %s), %s steps a frame, mix %s, out %s" % [
		n, first, args.seed, args.quarter_s, ",".join(venues), ",".join(levels), args.wsg, "here" if WsgClips.available() else "absent",
		args.steps, args.mix, out_dir])
	var all: Array = []
	var t_batch := Time.get_ticks_msec()
	for i in range(first, first + n):
		var venue := venues[i % venues.size()]
		var level := levels[(i / venues.size()) % levels.size()]
		var cfg := scenario(i, venue)
		var r: Dictionary = await play(cfg, level)
		if args.repro == "1":
			var again: Dictionary = await play(cfg, level)
			if again.fingerprint != r.fingerprint:
				r.violations.append({"t": 0.0, "q": 0, "phase": "", "check": "not_reproducible", "severity": "error",
					"msg": "the same seed played twice: %s then %s" % [r.fingerprint, again.fingerprint]})
				r.counts["not_reproducible"] = 1
		r.index = i
		all.append(r)
		var errs := 0
		var warns := 0
		for v in r.violations:
			if v.severity == "error":
				errs += 1
			else:
				warns += 1
		print("sim %3d %-7s %-6s %s %3d-%-3d %s v %s, %d periods, %5.0f s of play in %5.1f s: %5.1fx (%5.1fx a CPU second; stepping %.0f%%, checks %.0f%%)  errors %d, warnings %d%s" % [i, venue, level,
			"KO" if cfg.need_winner else "  ", r.score[0], r.score[1], cfg.home, cfg.away, r.periods, r.sim_s, r.real_s,
			r.sim_s / maxf(r.real_s, 0.001), r.sim_s / maxf(r.cpu_s, 0.001), 100.0 * r.match_s / maxf(r.real_s, 0.001), 100.0 * r.checks_s / maxf(r.real_s, 0.001), errs, warns, "" if r.finished else "  (DID NOT FINISH)"])
		if args.profile == "1":
			print("    a step: %.2f ms in all; the 14 players' moves and bodies %.2f ms, the umpires' %.2f ms" % [r.profile_ms[2], r.profile_ms[0], r.profile_ms[1]])
		if errs + warns > 0:
			_write(out_dir.path_join("match_%04d.json" % i), r)
	_summary(all, (Time.get_ticks_msec() - t_batch) / 1000.0)


## Match i's config, from the batch's seed and i alone (so only=i replays it).
func scenario(i: int, venue: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(args.seed), i])
	var ids: Array = DB.team_ids()
	var home: String = ids[rng.randi() % ids.size()]
	var away: String = ids[rng.randi() % ids.size()]
	while away == home:
		away = ids[rng.randi() % ids.size()]
	var cfg := {"home": home, "away": away, "venue": venue, "user_team": -1, "demo": true, "seed": rng.randi(),
		"quarter_s": float(args.quarter_s), "quarter": 15, "mode": "quick", "need_winner": false,
		"headless_hud": String(args.hud) != "on"}
	if args.mix == "1":
		cfg.need_winner = rng.randf() < 0.3
		cfg.double_zone = rng.randf() < 0.4
		cfg.timeouts = rng.randf() < 0.4
		cfg.rolling = rng.randf() < 0.3
		cfg.whistles = rng.randi_range(0, 2)
		if rng.randf() < 0.3:
			# Teams close in rating: more draws, more extra time. (Never a team against itself: the game does not allow
			# it, and its players' box-score entries would be one.)
			var near := ids.filter(func(x): return x != home)
			near.sort_custom(func(a, b): return absf(DB.team_rating(a) - DB.team_rating(home)) < absf(DB.team_rating(b) - DB.team_rating(home)))
			cfg.away = near[0]
	return cfg


## One match: built as the game builds it, stepped by this node (steps a frame), checked after every step.
func play(cfg: Dictionary, level: String) -> Dictionary:
	Game.settings.graphics = int(LEVELS.get(level, 0))
	WsgFoundation.tier = int(Game.settings.graphics)
	log_errors.take()
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = cfg.duplicate(true)
	var checks := Checks.new()
	add_child(m)
	m.set_process(false)          # stepped from here: steps a frame, the checks between them
	checks.begin(m)
	var fp := []
	m.game_event.connect(func(k: String, info: Dictionary):
		checks.check_event(m, k, info)
		if k in ["goal", "call", "period_end", "substitution", "timeout", "suspension"]:
			fp.append("%s:%s@%.2f" % [k, info.get("team", info.get("kind", "")), checks.t]))
	var done := [null]
	m.finished.connect(func(r): done[0] = r)
	var steps := maxi(1, int(args.steps))
	var limit := float(cfg.quarter_s) * 12.0 + 600.0
	var t0 := Time.get_ticks_usec()
	var c0 := cpu_s()
	var sim := 0.0
	var skipped := 0
	var us_match := 0
	var us_checks := 0
	var prof := [0, 0, 0]
	while done[0] == null and checks.t < limit:
		await get_tree().process_frame
		var delta := float(args.dt) if float(args.dt) > 0.0 else get_process_delta_time()
		for k in steps:
			if m.phase == "replay" and args.replays == "skip":
				m._end_replay()   # a tap skips it
				skipped += 1
			var replay: bool = m.phase == "replay"
			var u0 := Time.get_ticks_usec()
			m._process(delta)
			var u1 := Time.get_ticks_usec()
			var dt := 0.0 if replay else minf(delta, 0.05)
			sim += dt
			if args.checks != "off":
				checks.check_frame(m, dt)
			us_match += u1 - u0
			us_checks += Time.get_ticks_usec() - u1
			if done[0] != null:
				break
		if args.profile == "1" and Engine.get_process_frames() % 10 == 0 and m.phase != "replay":
			# What a step's parts cost: the players' and umpires' moves and bodies posed again where they stand (dt 0:
			# nothing moves), against the whole step.
			var p0 := Time.get_ticks_usec()
			for side in 2:
				for pl in m.players[side]:
					pl.advance(0.0)
			var p1 := Time.get_ticks_usec()
			for u in m.umpires:
				u.advance(0.0, m.ball.court_pos())
			var p2 := Time.get_ticks_usec()
			prof[0] += p1 - p0
			prof[1] += p2 - p1
			prof[2] += 1
	var real_s := (Time.get_ticks_usec() - t0) / 1e6
	var cpu := cpu_s() - c0
	var res: Dictionary = done[0] if done[0] != null else {}
	checks.finish(m, res, done[0] != null)
	for e in log_errors.take():
		checks.violations.append({"t": checks.t, "q": m.q, "phase": m.phase, "check": "engine_error", "severity": "error", "msg": e})
		checks.counts["engine_error"] = int(checks.counts.get("engine_error", 0)) + 1
	var out := {"config": cfg, "level": level, "wsg": not FoundationLink.off and FoundationLink.enabled(), "steps": steps,
		"score": m.score.duplicate(), "periods": m.q, "finished": done[0] != null, "sim_s": sim, "real_s": real_s,
		"cpu_s": cpu, "match_s": us_match / 1e6, "checks_s": us_checks / 1e6,
		"profile_ms": [prof[0] / 1000.0 / maxf(prof[2], 1.0), prof[1] / 1000.0 / maxf(prof[2], 1.0), us_match / 1000.0 / maxf(sim * 30.0, 1.0)], "replays_skipped": skipped, "violations": checks.violations, "counts": checks.counts, "stats": checks.stats,
		"fingerprint": "%s|%s|%d" % [m.score, ",".join(fp).md5_text(), m.q],
		"replay": "godot --headless --path . --fixed-fps 30 res://tests/sim/run_batch.tscn -- only=%d seed=%s quarter_s=%s venues=%s levels=%s wsg=%s steps=%d mix=%s hud=%s replays=%s" % [
			0, args.seed, args.quarter_s, args.venues, args.levels, args.wsg, steps, args.mix, args.hud, args.replays]}
	m.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return out


## This process's CPU seconds (Linux: /proc/self/stat's user and system ticks, 100 a second), or -1: the speed
## measured on a shared machine, which wall-clock time misstates when other work runs beside it.
static func cpu_s() -> float:
	var f := FileAccess.open("/proc/self/stat", FileAccess.READ)
	if f == null:
		return -1.0
	var s := f.get_line()   # (a /proc file has no length: read by line)
	var parts := s.substr(s.rfind(")") + 2).split(" ")
	return (float(parts[11]) + float(parts[12])) / 100.0


func _write(path: String, d: Dictionary) -> void:
	var c := d.duplicate(true)
	if c.has("replay"):
		c.replay = String(c.replay).replace("only=0", "only=%d" % int(d.get("index", 0)))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(c, "  "))


func _summary(all: Array, wall: float) -> void:
	var by_check := {}       # check -> {severity, n, matches}
	var speed := {}          # venue/level -> [sim, real]
	var errors := 0
	var unfinished := 0
	var sim_all := 0.0
	var real_all := 0.0
	var cpu_all := 0.0
	for r in all:
		var key := "%s/%s" % [r.config.venue, r.level]
		var s: Array = speed.get(key, [0.0, 0.0, 0, 0.0])
		speed[key] = [float(s[0]) + float(r.sim_s), float(s[1]) + float(r.real_s), int(s[2]) + 1, float(s[3]) + float(r.cpu_s)]
		sim_all += float(r.sim_s)
		real_all += float(r.real_s)
		cpu_all += float(r.cpu_s)
		if not r.finished:
			unfinished += 1
		var seen := {}
		for v in r.violations:
			if not by_check.has(v.check):
				by_check[v.check] = {"severity": v.severity, "n": 0, "matches": 0, "example": "%s (match %d, %.1f s, q%d)" % [v.msg, r.index, v.t, v.q]}
			if not seen.has(v.check):
				seen[v.check] = true
				by_check[v.check].matches += 1
		for c in r.counts:
			if by_check.has(c):
				by_check[c].n += int(r.counts[c])
		for v in r.violations:
			if v.severity == "error":
				errors += 1
				break
	print("\nrun_batch: %d matches, %d did not finish, %d with errors; %.0f s of play in %.0f s of stepping (%.1fx real time; %.1fx a CPU second), %.0f s in all" % [
		all.size(), unfinished, errors, sim_all, real_all, sim_all / maxf(real_all, 0.001), sim_all / maxf(cpu_all, 0.001), wall])
	print("speed (s of play a wall second, and a CPU second), by venue and level:")
	var keys := speed.keys()
	keys.sort()
	for k in keys:
		print("  %-16s %5.1fx  %5.1fx CPU  (%d matches)" % [k, float(speed[k][0]) / maxf(float(speed[k][1]), 0.001),
			float(speed[k][0]) / maxf(float(speed[k][3]), 0.001), speed[k][2]])
	var ranked := by_check.keys()
	ranked.sort_custom(func(a, b): return [by_check[a].severity == "error", by_check[a].matches, by_check[a].n] > [by_check[b].severity == "error", by_check[b].matches, by_check[b].n])
	print("violations (check, severity, matches with it, times, an example):")
	for k in ranked:
		var c: Dictionary = by_check[k]
		print("  %-26s %-5s %3d matches %5d times  %s" % [k, c.severity, c.matches, c.n, c.example])
	_write(out_dir.path_join("summary.json"), {"args": args, "matches": all.size(), "unfinished": unfinished, "with_errors": errors,
		"sim_s": sim_all, "real_s": real_all, "cpu_s": cpu_all, "speed": speed, "checks": by_check})
	print("run_batch: failures and summary in %s" % out_dir)
	get_tree().quit(1 if errors > 0 or unfinished > 0 else 0)
