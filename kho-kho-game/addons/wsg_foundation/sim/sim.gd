class_name WsgSim
extends RefCounted
## The automated match simulator (the owner: "find and fix bugs without relying on me to manually play every build"):
## runs one match of a game (WsgSimGame) with its own production code on a fixed step, headless and as fast as the
## computer goes (godot --fixed-fps 30: each frame is 1/30 s of game time however long it takes), checking every
## frame, and records what is needed to replay any failure from its seed. tools/wsg/sim.gd runs batches of them.
##
## The generic checks (every game; the game adds its sport's rules in WsgSimGame.rules()):
##   script errors (any GDScript error during the match - caught by a Logger, not just crashes);
##   NaN or infinite positions, and anything outside the game's bounds;
##   the score only going up, by a legal step; the clock only one way, never stuck while it runs, never jumping;
##   a body stuck (meant to move, its target far, hardly moved for STUCK_S);
##   an endless match (past the game's max_seconds);
##   bodies inside props and the ball through one (WsgSolidProps, WsgPropAudit);
##   feet: a planted foot's slip in a step over FOOT_SLIP_CM; no T- or A-pose (WsgNoteChecks), sampled bodies.
## A failure records: the seed, the config, the simulated time and frame, the state, the last EVENTS_KEPT events and
## log lines, and its signature (the failure with its numbers taken out: the batch report groups by it).

const FPS := 30.0
const STUCK_S := 6.0
const FOOT_SLIP_CM := 2.0
const EVENTS_KEPT := 300
const MAX_FAILS := 3
## How bad each kind of failure is (the batch report ranks signatures by how often x this).
const SEVERITY := {"script error": 5, "nan": 5, "out of bounds": 4, "score": 5, "clock": 4, "endless": 4, "stuck": 3,
	"prop": 3, "ball through": 3, "foot slip": 2, "pose": 3, "rule": 4, "start": 5, "determinism": 5, "timestep": 5}

static var _log: WsgSimLog = null
static var _warm := false

## Options: stop_frame (replay: stop there and print the state), verbose, realtime (1x: the determinism check),
## length_mix (the batch's: three matches in four shortened), short (force it: a replay), fps, sampled_pose,
## input (WsgSimInput plays the human), feet (sample feet and poses), wall_limit_s (a match taking longer on the wall
## clock is reported as slow, not failed), hash_every (frames between state hashes, for the determinism check).
var opts := {}


## Runs one match: {ok, seed, kind, config, failures: [{check, message, signature, severity, t, frame, state,
## events, log}], result, balance, sim_s, wall_s, speed, frames, hashes}.
func run(game: WsgSimGame, kind: String, seed: int, tree: SceneTree) -> Dictionary:
	if _log == null:
		_log = WsgSimLog.new()
		OS.add_logger(_log)
	# The engine's first frames after it starts are not yet on the fixed step, even with --fixed-fps (0.042, 0.029,
	# 0.030, 0.0325 s...): the first match of a run played differently from the same seed later (WsgSim's own
	# determinism check found it). Let them pass first.
	if not _warm:
		for k in 30:
			await tree.process_frame
		_warm = true
	_log.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cfg := game.config(kind, rng)
	cfg["seed"] = seed
	cfg["kind"] = kind
	# The match-length mix (the lead's speed default): a quarter of the matches full length (the end of a match,
	# extra time, penalties), the rest shortened (the game shortens its halves, every rule as it is) - targeted
	# matches as the game sets them.
	if opts.has("short"):
		cfg["short"] = bool(opts.short)          # (a replay: as the failing match was)
	elif not cfg.has("short"):
		cfg["short"] = not kind.begins_with("targeted:") and seed % 4 != 0 and bool(opts.get("length_mix", false))
	# Any stray global randf in the game is at least the same for the same seed (rng_lint finds them).
	seed(seed)
	WsgAutoTier.off = true
	var out := {"ok": true, "seed": seed, "kind": kind, "config": cfg, "failures": [], "hashes": []}
	var t_wall := Time.get_ticks_usec()
	var fps := float(opts.get("fps", FPS))
	if bool(opts.get("realtime", false)):
		Engine.max_fps = int(fps)
	var events := []
	# (A copy: a start() that shortens its config in place changed the saved one, and its replay shortened it again -
	# Kho Kho's replays diverged.)
	var root: Node = await game.start(cfg.duplicate(true), seed, tree)
	if root == null:
		_fail(out, "start", "the match did not start", 0.0, 0, {}, events)
		return _finish(out, game, t_wall, 0.0, 0)
	var dt := 1.0 / fps
	var t := 0.0
	var frame := 0
	var limit := game.max_seconds(cfg)
	var steps := game.score_steps()
	var bounds := game.bounds()
	var solid := game.solid()
	var audit := WsgPropAudit.new(solid) if solid else null
	var prev_score := []
	var clock_dir := 0.0
	var clock_prev := INF
	var clock_still := 0.0
	var phase := ""
	var moved := {}           # name -> [position, seconds hardly moving]
	var feet := {}            # name -> [frames, ankle rest, toe rest]
	var shown := {}           # body id -> [feet, T/A-pose] as last drawn ([] once used)
	# Sampled pose (the lead's speed default): a quarter of the bodies posed in full (planter IK, layers, helpers),
	# a different quarter each seed; the rest keep their animation, bones and foot contacts (WsgBody.set_sim_full).
	# The feet and pose checks follow the full quarter.
	if bool(opts.get("sampled_pose", true)):
		var bl0 := game.bodies()
		for bi in bl0.size():
			var wb0: Variant = (bl0[bi] as Dictionary).get("body")
			if wb0 is WsgBody and is_instance_valid(wb0):
				(wb0 as WsgBody).set_sim_full(bi % 4 == seed % 4)
	var input: WsgSimInput = null
	if bool(opts.get("input", false)) and game.human_team() >= 0:
		input = WsgSimInput.new(game, seed + 7919, tree)
	var stop_frame := int(opts.get("stop_frame", -1))
	var hash_every := int(opts.get("hash_every", 0))
	var beat := Time.get_ticks_usec()
	while true:
		# A heartbeat every 30 s of wall-clock in a long match (sim_shard.sh takes HANG seconds of silence for a freeze:
		# a full-length extreme Kho Kho match, 2,170 s simulated, ran 127 s without a line and was called frozen).
		if Time.get_ticks_usec() - beat > 30000000:
			beat = Time.get_ticks_usec()
			print("sim: %s seed %d still playing: %.0f s simulated, %d frames" % [kind, seed, t, frame])
		if input:
			input.tick(frame)
		await tree.process_frame
		t += dt
		frame += 1
		var real_dt := tree.root.get_process_delta_time()
		if absf(real_dt - dt) > 1e-4 and not bool(opts.get("realtime", false)):
			_fail(out, "timestep", "the frame's step was %.4f s, not %.4f: run with --fixed-fps %d (the match is not reproducible)" % [real_dt, dt, int(fps)], t, frame, {}, events)
		var st := game.state()
		for e in game.events():
			var ev: Dictionary = e
			ev["t"] = snappedf(t, 0.01)
			events.append(ev)
			if events.size() > EVENTS_KEPT:
				events.pop_front()
		# Script errors (the Logger saw them).
		for err in _log.take():
			_fail(out, "script error", err, t, frame, st, events)
		# The score: only up, by a legal step.
		var score: Array = st.get("score", [])
		if not prev_score.is_empty() and score.size() == prev_score.size():
			for side in score.size():
				var d := float(score[side]) - float(prev_score[side])
				if d < 0.0:
					_fail(out, "score", "side %d's score went down from %s to %s" % [side, prev_score[side], score[side]], t, frame, st, events)
				elif d > 0.0 and not steps.has(int(d)) and not steps.has(d):
					_fail(out, "score", "side %d's score went up by %s at once (legal: %s)" % [side, d, steps], t, frame, st, events)
		prev_score = score.duplicate()
		# The clock: one way within a phase, moving while it runs, never jumping.
		var ph := String(st.get("phase", ""))
		if ph != phase:
			phase = ph
			clock_dir = 0.0
			clock_prev = INF
			clock_still = 0.0
		if st.has("clock"):
			var c := float(st.clock)
			if is_nan(c) or is_inf(c):
				_fail(out, "nan", "the clock is %s" % c, t, frame, st, events)
			elif clock_prev != INF:
				var dc := c - clock_prev
				if absf(dc) > 5.0:
					_fail(out, "clock", "the clock jumped %.1f s in one frame" % dc, t, frame, st, events)
				elif dc != 0.0:
					if clock_dir != 0.0 and signf(dc) != clock_dir:
						_fail(out, "clock", "the clock ran backwards (%.2f to %.2f) in phase '%s'" % [clock_prev, c, ph], t, frame, st, events)
					clock_dir = signf(dc)
					clock_still = 0.0
				elif bool(st.get("clock_running", false)):
					clock_still += dt
					if clock_still > 2.0:
						_fail(out, "clock", "the clock stood still %.1f s while running (phase '%s')" % [clock_still, ph], t, frame, st, events)
						clock_still = -INF
			clock_prev = c
		# Bodies: numbers, bounds, stuck, props, feet, poses.
		var bl := game.bodies()
		for bi in bl.size():
			var b: Dictionary = bl[bi]
			var p: Vector3 = b.get("pos", Vector3.ZERO)
			var nm := String(b.get("name", "body %d" % bi))
			if not p.is_finite():
				_fail(out, "nan", "%s is at %s" % [nm, p], t, frame, st, events)
				continue
			if not bounds.has_point(p):
				_fail(out, "out of bounds", "%s is outside the game's bounds at %s" % [nm, p.snappedf(0.01)], t, frame, st, events)
			if audit:
				audit.body(nm, p, float(b.get("radius", 0.3)), float(b.get("height", 1.8)))
			var tgt: Vector3 = b.get("target", Vector3.INF)
			if bool(b.get("active", false)) and tgt != Vector3.INF and Vector2(tgt.x - p.x, tgt.z - p.z).length() > 1.5:
				var m: Array = moved.get(nm, [p, 0.0])
				if (m[0] as Vector3).distance_to(p) < 0.15:
					m[1] = float(m[1]) + dt
					if float(m[1]) > STUCK_S:
						_fail(out, "stuck", "%s hardly moved for %.0f s with its target %.1f m away" % [nm, m[1], Vector2(tgt.x - p.x, tgt.z - p.z).length()], t, frame, st, events)
						m[1] = -INF
				else:
					m = [p, 0.0]
				moved[nm] = m
			else:
				moved.erase(nm)
			var wb: Variant = b.get("body")
			# (A quarter of the bodies, chosen by the seed, followed every frame: feet are measured frame to frame.)
			if bool(opts.get("feet", true)) and wb is WsgBody and is_instance_valid(wb) and bi % 4 == seed % 4:
				var body := wb as WsgBody
				if not feet.has(nm):
					feet[nm] = [[], (body.joints["LeftFoot"] as Vector3).y * body.scale.y, (body.joints["LeftToeBase"] as Vector3).y * body.scale.y]
				# The pose as it is drawn, read as the skeleton finishes it: read here, after the frame, the bones are
				# back to the clip's (no planted feet, no hips' lift, no layers - 14 cm out on the test hurler, and
				# every slip the clip's own).
				var id := body.get_instance_id()
				if not shown.has(id):
					shown[id] = []
					body.skeleton.skeleton_updated.connect(func():
						shown[id] = [WsgNoteChecks.feet(body), WsgNoteChecks.t_or_a_pose(body)])
				var seen: Array = shown[id]
				if not seen.is_empty():
					shown[id] = []
					(feet[nm][0] as Array).append(seen[0])
					if seen[1] != "":
						_fail(out, "pose", "%s stands in a %s" % [nm, seen[1]], t, frame, st, events)
		var bd := game.ball()
		if not bd.is_empty():
			var bp: Vector3 = bd.get("pos", Vector3.ZERO)
			if not bp.is_finite():
				_fail(out, "nan", "the ball is at %s" % bp, t, frame, st, events)
			elif not bounds.has_point(bp):
				_fail(out, "out of bounds", "the ball is outside the game's bounds at %s" % bp.snappedf(0.01), t, frame, st, events)
			elif audit and bool(bd.get("live", true)):
				audit.ball(bp, float(bd.get("radius", 0.11)))
			elif audit:
				audit.ball_reset()
		if audit:
			audit.tick(dt)
		for r in game.rules():
			_fail(out, "rule", String(r), t, frame, st, events)
		if hash_every > 0 and frame % hash_every == 0:
			out.hashes.append([frame, _hash(st, bl, bd)])
		if stop_frame > 0 and frame >= stop_frame:
			print("REPLAY stopped at frame %d (%.2f s): %s" % [frame, t, JSON.stringify(_plain(st))])
			break
		if bool(st.get("finished", false)):
			break
		if t > limit:
			_fail(out, "endless", "not finished after %.0f s (the game's limit)" % limit, t, frame, st, events)
			break
		if (out.failures as Array).size() >= MAX_FAILS:
			break
	if audit:
		var rep := audit.report()
		for c: Dictionary in rep.worst:
			_fail(out, "prop" if c.kind == "body" else "ball through",
				"%s %.0f cm into the %s" % [c.who, float(c.depth) * 100.0, c.prop] if c.kind == "body" else "the ball went through the %s" % c.prop,
				float(c.time), int(float(c.time) * FPS), {}, [])
	for nm in feet:
		var f: Array = feet[nm]
		if (f[0] as Array).size() > 20:
			var s := WsgNoteChecks.foot_slip(f[0], f[1], f[2])
			if float(s.max_cm) > FOOT_SLIP_CM:
				_fail(out, "foot slip", "%s: a planted foot slid %.1f cm in a step (%.1f at most)" % [nm, s.max_cm, FOOT_SLIP_CM], t, frame, {}, [])
	out["result"] = game.result()
	out["balance"] = game.balance_keys(cfg)
	if input:
		out["input"] = input.summary()
	return _finish(out, game, t_wall, t, frame)


func _finish(out: Dictionary, game: WsgSimGame, t_wall: int, t: float, frame: int) -> Dictionary:
	game.stop()
	Engine.max_fps = 0
	var wall := (Time.get_ticks_usec() - t_wall) / 1e6
	out.sim_s = snappedf(t, 0.01)
	out.wall_s = snappedf(wall, 0.01)
	out.speed = snappedf(t / maxf(wall, 1e-3), 0.1)
	out.frames = frame
	out.ok = (out.failures as Array).is_empty()
	return out


func _fail(out: Dictionary, check: String, msg: String, t: float, frame: int, st: Dictionary, events: Array) -> void:
	var sig := check + ": " + _signature(msg)
	for f: Dictionary in out.failures:
		if f.signature == sig:
			return
	out.failures.append({"check": check, "message": msg, "signature": sig, "severity": int(SEVERITY.get(check, 3)),
		"t": snappedf(t, 0.01), "frame": frame, "state": _plain(st), "events": events.slice(-60).map(_plain),
		"log": _log.recent() if _log else []})
	out.ok = false


## A failure's message with its numbers and names of bodies taken out: the same bug, wherever and whoever.
static func _signature(msg: String) -> String:
	var re := RegEx.new()
	re.compile("[-+]?[0-9]+(\\.[0-9]+)?")
	var s := re.sub(msg, "#", true)
	re.compile("\\([^)]*\\)")
	s = re.sub(s, "(..)", true)
	return s


## A state's numbers rounded and its vectors as lists (JSON).
static func _plain(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var o := {}
			for k in v:
				o[String(k)] = _plain(v[k])
			return o
		TYPE_ARRAY:
			return (v as Array).map(_plain)
		TYPE_VECTOR3:
			return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]
		TYPE_VECTOR2:
			return [snappedf(v.x, 0.001), snappedf(v.y, 0.001)]
		TYPE_FLOAT:
			return snappedf(v, 0.0001)
		TYPE_OBJECT:
			return str(v)
	return v


## The state, the bodies and the ball to the millimetre, hashed (two runs of one seed must match frame for frame).
static func _hash(st: Dictionary, bl: Array, bd: Dictionary) -> int:
	var parts := [JSON.stringify(_plain(st))]
	for b: Dictionary in bl:
		parts.append(str((b.get("pos", Vector3.ZERO) as Vector3).snappedf(0.001)))
	if not bd.is_empty():
		parts.append(str((bd.get("pos", Vector3.ZERO) as Vector3).snappedf(0.001)))
	return "|".join(parts).hash()

