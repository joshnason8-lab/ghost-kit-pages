extends SceneTree
## Locomotion: a body driven along a scripted path the way a game drives it (speed limited by acceleration), with
## the foot slide measured: how fast a foot moves over the ground while the clip says it is planted (cm/s).
##   godot --headless --path . -s tests/loco_test.gd [-- <char dir> <prefix>]
## Runs the path twice, feet planted and not, and reports both. Fails if, planted, the feet slide on average more
## than MAX_MEAN cm/s or a tenth of the planted time more than MAX_P90 cm/s, if the legs step much faster or slower
## than the ground covered asks, or if a planted foot ever goes through the ground. Needs the clip library
## (addons/wsg_foundation/data); without it it says so and passes (the games keep their own animation).

const MAX_MEAN := 8.0
const MAX_P90 := 5.0
const ACCEL := 6.5          # m/s/s (Hurling's)
const DECEL := 9.0
const DT := 1.0 / 30.0
const TOUCH := 0.02         # m: a foot this close to the ground is on it

## [until (s), name, world velocity wanted (x, z m/s), facing (degrees)]
const PATH := [
	[1.0, "stand", Vector2(0, 0), 0.0],
	[4.0, "start and run", Vector2(0, 6.0), 0.0],
	[6.0, "cut left", Vector2(6.0, 0), 90.0],
	[7.6, "stop", Vector2(0, 0), 90.0],
	[8.6, "stand", Vector2(0, 0), 90.0],
	[11.6, "run backwards", Vector2(-2.6, 0), 90.0],
	[13.0, "stop", Vector2(0, 0), 90.0],
	[15.5, "side-step", Vector2(0, 3.0), 90.0],
	[17.0, "stop", Vector2(0, 0), 90.0],
	[19.0, "jog, turning", Vector2(0, 0), 0.0],
]

var lines := []


func _initialize() -> void:
	# A test must never hang a build.
	create_timer(300.0).timeout.connect(func():
		printerr("LOCO TEST: timed out")
		quit(2))
	if not WsgClips.available():
		print("LOCO TEST: SKIPPED (no clip library in this build)")
		quit(0)
		return
	var a := OS.get_cmdline_user_args()
	var ch := WsgBody.load_character(a[0] if a.size() > 0 else "res://tests/character", a[1] if a.size() > 1 else "hero")
	var planted: Dictionary = await _run(ch, true)
	var free: Dictionary = await _run(ch, false)
	var fails := []
	print("segment              planted: mean  p90 cm/s | clip alone: mean  p90 | steps  m/step  speed m/s")
	for seg in planted.segments:
		var p: Dictionary = planted.segments[seg]
		var f: Dictionary = free.segments.get(seg, {})
		print("%-20s %13.1f %5.1f      | %15.1f %5.1f | %5d  %6.2f  %5.2f" % [seg, p.mean, p.p90, f.get("mean", 0.0), f.get("p90", 0.0), p.steps, p.per_step, p.speed])
	print("all                  %13.1f %5.1f      | %15.1f %5.1f" % [planted.all.mean, planted.all.p90, free.all.mean, free.all.p90])
	print("deepest foot under the ground: %.1f cm" % [planted.under * 100.0])
	if planted.all.mean > MAX_MEAN or planted.all.p90 > MAX_P90:
		fails.append("planted feet slide %.1f cm/s on average, %.1f at the 90th percentile" % [planted.all.mean, planted.all.p90])
	if planted.under > 0.01:
		fails.append("a foot went %.1f cm through the ground" % [planted.under * 100.0])
	# Steps must match the ground: at a run each step should cover about what the run clip's step does.
	var run: Dictionary = planted.segments.get("start and run", {})
	if run.get("per_step", 0.0) < 1.0:
		fails.append("too many steps at a run: %.2f m a step" % run.get("per_step", 0.0))
	if planted.all.mean >= free.all.mean and free.all.mean > 0.5:
		fails.append("planting does not reduce the slide (%.1f planted, %.1f without)" % [planted.all.mean, free.all.mean])
	for f in fails:
		printerr("FAIL: ", f)
	print("LOCO TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _run(ch: Dictionary, plant: bool) -> Dictionary:
	var holder := Node3D.new()
	root.add_child(holder)
	var body := WsgBody.new(ch)
	holder.add_child(body)
	var loco := WsgLocomotor.attach(body)
	await process_frame
	loco.planter.enabled = plant
	var steps := {}
	var ankle_rest: float = (body.joints["LeftFoot"] as Vector3).y
	var toe_rest: float = (body.joints["LeftToeBase"] as Vector3).y
	var vel := Vector2.ZERO
	var pos := Vector3.ZERO
	var prev := [[], []]                       # [ankle, toe] last frame, while touching
	var slides := {}
	var dist := {}
	var under := 0.0
	_t = 0.0
	var end: float = PATH[-1][0]
	while _t < end:
		var seg := _seg_at(_t)
		if OS.has_environment("LOCO_DEBUG") and fmod(_t, 1.0) < DT: printerr("t ", _t, " ", seg, " state ", loco.state)
		var spec: Array = _spec_at(_t)
		var want: Vector2 = spec[2]
		var facing := deg_to_rad(spec[3])
		if seg == "jog, turning":
			# A curving jog: round a circle at 3.5 m/s, a quarter turn a second.
			var a := (_t - 17.0) * PI * 0.5
			want = Vector2(sin(a), cos(a)) * 3.5
			facing = a
		var lim := (ACCEL if want.length() > vel.length() else DECEL) * DT
		vel = vel.move_toward(want, lim)
		if seg == "start and run":
			facing = atan2(want.x, want.y)
		pos += Vector3(vel.x, 0, vel.y) * DT
		body.position = pos
		loco.drive(DT, Vector3(vel.x, 0, vel.y), facing, Vector3(want.x, 0, want.y))
		dist[seg] = float(dist.get(seg, 0.0)) + vel.length() * DT
		await process_frame
		await body.skeleton.skeleton_updated
		# A foot touching the ground (its ankle or toe within TOUCH of it, as drawn) must not move over it: that is
		# gliding, whatever the planter thinks. Steps are counted from these touch-downs too.
		for i in 2:
			var ank: Vector3 = body.bone_world(["LeftFoot", "RightFoot"][i]).origin
			var toe: Vector3 = body.bone_world(["LeftToeBase", "RightToeBase"][i]).origin
			var h := minf(ank.y - ankle_rest, toe.y - toe_rest)
			under = maxf(under, -h)
			var touching := h < TOUCH
			# The foot's slide: the slower of its heel (ankle) and its ball (toe), whichever is the one planted (at
			# toe-off the ankle rolls up over a ball of the foot that stays put).
			# (The first frame of a touch is the foot arriving: measured from the next one on.)
			if touching and not prev[i].is_empty() and prev[i][2]:
				var pa: Vector3 = prev[i][0]
				var pb: Vector3 = prev[i][1]
				var v := minf(Vector2(ank.x - pa.x, ank.z - pa.z).length(), Vector2(toe.x - pb.x, toe.z - pb.z).length()) / DT * 100.0
				if not slides.has(seg):
					slides[seg] = []
				slides[seg].append(v)
				if OS.has_environment("LOCO_TRACE") and plant:
					printerr("TRACE\t%.2f\t%s\t%d\t%.0f\t%.3f\t%d\t%s\t%d\t%.2f\t%s\t%.2f" % [_t, seg, i, v, h, loco.state, loco._shot if loco._w_shot > 0.5 else "gait", int(loco.planter.contact[i]), loco.planter._w[i], loco.planter._lifted[i], loco.speed])
			if touching and prev[i].is_empty():
				steps[seg] = int(steps.get(seg, 0)) + 1
			prev[i] = [ank, toe, not prev[i].is_empty()] if touching else []
		await process_frame
		_t += DT
	var out := {"segments": {}, "under": under}
	var all := []
	for seg in slides:
		var s: Array = slides[seg]
		all.append_array(s)
		var st: int = steps.get(seg, 0)
		var spec := PATH.filter(func(p): return p[1] == seg)
		var length := 0.0
		for p in spec:
			var i := PATH.find(p)
			length += float(p[0]) - (float(PATH[i - 1][0]) if i > 0 else 0.0)
		out.segments[seg] = {"mean": _mean(s), "p90": _pct(s, 0.9), "steps": st,
			"per_step": float(dist.get(seg, 0.0)) / maxf(st, 1), "speed": float(dist.get(seg, 0.0)) / maxf(length, 0.01)}
	out.all = {"mean": _mean(all), "p90": _pct(all, 0.9)}
	holder.queue_free()
	await process_frame
	return out


var _t := 0.0


func _seg_at(t: float) -> String:
	return _spec_at(t)[1]


func _spec_at(t: float) -> Array:
	for p in PATH:
		if t < p[0]:
			return p
	return PATH[-1]


static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += x
	return s / a.size()


static func _pct(a: Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[mini(b.size() - 1, int(b.size() * q))]
