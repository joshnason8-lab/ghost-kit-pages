class_name Mocap
## Recorded movement, retargeted to the bodies' seventeen bones (tools/mocap/bvh_retarget.py writes assets/anim/*.json
## from the CMU Graphics Lab Motion Capture Database). Clips hold each bone's turn (Euler YXZ degrees, as Body.apply
## reads them) 30 times a second, and the hips' small offsets that keep a planted foot still. A clip is turned into
## quaternions once, at first use; sampling gives a pose that Moves.blend and Body.apply take like any other.
## The clips in use (docs/PROGRESS.md lists the source takes): the run (CMU 09_02) and the underhand toss of the serve
## (CMU 124_12).

const RUN := "run_09_02"
const TOSS := "serve_toss_124_12"
const ALL := [RUN, TOSS]

static var _clips := {}
static var light := false     # Low graphics: the nearest frame, no blending between frames


static func clip(name: String) -> Dictionary:
	if _clips.has(name):
		return _clips[name]
	var c := {}
	var f := FileAccess.open("res://assets/anim/%s.json" % name, FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			c = _prepare(d)
	_clips[name] = c
	return c


static func _prepare(d: Dictionary) -> Dictionary:
	var frames: Array = []
	for fr in d.frames:
		var q := {}
		for b in Body.BONES:
			var e: Array = fr.get(b[0], [0, 0, 0])
			q[b[0]] = Basis.from_euler(Vector3(deg_to_rad(e[0]), deg_to_rad(e[1]), deg_to_rad(e[2])), EULER_ORDER_YXZ).get_rotation_quaternion()
		q["hips_y"] = float(fr.get("hips_y", 0.0))
		q["hips_side"] = float(fr.get("hips_side", 0.0))
		q["hips_fwd"] = float(fr.get("hips_fwd", 0.0))
		frames.append(q)
	var c := {"frames": frames, "fps": float(d.fps), "loop": bool(d.loop), "duration": float(d.duration),
		"cycle_m": float(d.get("cycle_m", 0.0)), "speed": float(d.get("speed", 0.0)), "hit": float(d.get("hit", 0.0)),
		"held": float(d.get("held", d.duration)), "source": String(d.source)}
	# A loop's phase: where the left thigh swings furthest forward, so it lines up with Moves.run (a quarter cycle).
	if c.loop:
		var best := 0
		for i in frames.size():
			if _flex(frames[i]) > _flex(frames[best]):
				best = i
		c["flex_u"] = float(best) / frames.size()
	return c


static func _flex(fr: Dictionary) -> float:
	# How far forward the left thigh points: its bone's -y turned into the hips' space.
	return ((fr.hips as Quaternion) * (fr.thigh_l as Quaternion) * Vector3.DOWN).z


static func loaded(name: String) -> bool:
	return not clip(name).is_empty()


## The pose at t seconds into a clip (looped or held at its ends).
static func sample(name: String, t: float) -> Dictionary:
	var c := clip(name)
	if c.is_empty():
		return {}
	var frames: Array = c.frames
	var n := frames.size()
	var x := t * float(c.fps)
	var i0: int
	var i1: int
	var w: float
	if c.loop:
		x = fposmod(x, float(n))
		i0 = int(x) % n
		i1 = (i0 + 1) % n
	else:
		x = clampf(x, 0.0, float(n - 1))
		i0 = mini(int(x), n - 1)
		i1 = mini(i0 + 1, n - 1)
	w = x - floorf(x)
	if light:
		return frames[i1 if w > 0.5 else i0]
	var a: Dictionary = frames[i0]
	var b: Dictionary = frames[i1]
	var out := {}
	for k in a:
		if a[k] is Quaternion:
			out[k] = (a[k] as Quaternion).slerp(b[k], w)
		else:
			out[k] = lerpf(a[k], b[k], w)
	return out


## The run at the game's phase (cycles, one cycle two steps, as Moves.run).
static func run(phase: float) -> Dictionary:
	var c := clip(RUN)
	if c.is_empty():
		return {}
	return sample(RUN, fposmod(phase - 0.25 + float(c.flex_u), 1.0) * float(c.duration))


## The serve's toss, u from 0 to 1 over Moves.SERVE_T: the recorded release falls on Moves.SERVE_HIT.
static func toss(u: float) -> Dictionary:
	var c := clip(TOSS)
	if c.is_empty():
		return {}
	var hit := float(c.hit)
	var t := u / Moves.SERVE_HIT * hit if u < Moves.SERVE_HIT else hit + (u - Moves.SERVE_HIT) / (1.0 - Moves.SERVE_HIT) * (float(c.duration) - hit)
	return sample(TOSS, t)
