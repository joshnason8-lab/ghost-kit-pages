class_name WsgCrowdMocap
extends RefCounted
## The crowd's motions from the ActorCore crowd clips (when the build has them): the same six motions and the same
## pose format as WsgCrowdClips, cut from the takes so the crowd's shader can play them -
##   sit_idle      Crowd_Sit_Idle (a loop as it is)
##   sit_clap      one clap of Crowd_Sit_Clap, from one meeting of the hands to the next (the shader puts each on
##                 the clapping sound's beat)
##   stand_clap    one clap of Crowd_Stand_Clap
##   cheer         a stretch of Crowd_Cheer that ends where it began (loops without a jump)
##   sit_to_stand  Crowd_Stand_To_Sit's getting up, at its end
##   stand_idle    the standing it ends on
## Every frame is placed by the feet: their midpoint FEET_FORWARD in front of the fan's origin, as the authored
## motions have it, so seats, steps and getting up line up the same; and turned to face forward. Used by
## tools/bake_crowd.gd only (bake time): its output is licensed.

const FEET_FORWARD := WsgCrowdClips.FEET_FORWARD

var clips := {}          # name -> [length s, loop]
var _src := {}           # name -> [animation, t0, t1, reverse, yaw fix]
var _joints := WsgRig.default_joints()


static func available() -> bool:
	for n in ["Crowd_Sit_Idle", "Crowd_Sit_Clap", "Crowd_Stand_Clap", "Crowd_Cheer", "Crowd_Stand_To_Sit"]:
		if not WsgClips.has(n):
			return false
	return true


func _init() -> void:
	var lib := WsgClips.library()
	var si: Animation = lib.get_animation("Crowd_Sit_Idle")
	var cyc := float(WsgClips.meta("Crowd_Sit_Idle").get("cycle", 3.0))
	_add("sit_idle", si, 0.0, 1.0, false, true, cyc)
	for pair in [["sit_clap", "Crowd_Sit_Clap"], ["stand_clap", "Crowd_Stand_Clap"]]:
		var an: Animation = lib.get_animation(pair[1])
		var w := _one_clap(an)
		_add(pair[0], an, w[0], w[1], false, true)
	var ch: Animation = lib.get_animation("Crowd_Cheer")
	var cw := _seamless(ch, 2.0, 2.0, 4.0)
	_add("cheer", ch, cw[0], cw[1], false, true)
	# The owner's "stand to sit" take sits through most of its length and gets up at the end: that is the getting up,
	# and the standing it ends on (held, breathing a little in the shader's blend) the standing idle.
	var ss: Animation = lib.get_animation("Crowd_Stand_To_Sit")
	var tw := _getting_up(ss)
	_add("sit_to_stand", ss, tw[0], tw[1], false, false)
	_add("stand_idle", ss, maxf(tw[0], tw[1] - 0.06), tw[1], false, true, 1.5 / 0.06)
	for c in clips:
		print("crowd mocap %-12s %s %.2f-%.2f s (%.2f s)%s" % [c, _src[c][0].resource_name, _src[c][1], _src[c][2], clips[c][0], " reversed" if _src[c][3] else ""])


## time_scale: an animation stretched to one second (a loop) is played over its natural length.
func _add(name: String, an: Animation, t0: float, t1: float, reverse: bool, loop: bool, time_scale := 1.0) -> void:
	var length := (t1 - t0) * time_scale
	clips[name] = [length, loop]
	# The way it faces over the window, taken out.
	var ys := 0.0
	var n := 8
	for i in n:
		var t := lerpf(t0, t1, float(i) / (n - 1))
		var q := _rot(an, "Hips", t)
		var f := q * Vector3.BACK
		ys += atan2(f.x, f.z)
	_src[name] = [an, t0, t1, reverse, Quaternion(Vector3.UP, -ys / n), time_scale]


## The pose at time t: {bone: local Quaternion, "@hips": hips offset from the rest} (as WsgCrowdClips.pose).
func pose(name: String, t: float) -> Dictionary:
	var s: Array = _src[name]
	var an: Animation = s[0]
	var span: float = s[2] - s[1]
	var u: float = fposmod(t, clips[name][0]) / clips[name][0] if clips[name][1] else clampf(t / clips[name][0], 0.0, 1.0)
	var at: float = s[2] - u * span if s[3] else s[1] + u * span
	var out := {}
	for b in WsgRig.BONES:
		if WsgRig.is_helper(b[0]):
			continue
		out[b[0]] = _rot(an, b[0], at)
	out["Hips"] = (s[4] as Quaternion) * (out["Hips"] as Quaternion)
	var hp := _pos(an, at) - Vector3(0, 0.98, 0)
	hp = (s[4] as Quaternion) * Vector3(hp.x, 0, hp.z) + Vector3(0, hp.y, 0)
	# Placed by the feet.
	var feet := _feet_mid(out, hp)
	out["@hips"] = hp + Vector3(-feet.x, 0, FEET_FORWARD - feet.z)
	return out


func _rot(an: Animation, bone: String, t: float) -> Quaternion:
	var i := an.find_track(NodePath("Skeleton3D:" + bone), Animation.TYPE_ROTATION_3D)
	return an.rotation_track_interpolate(i, t) if i >= 0 else Quaternion.IDENTITY


func _pos(an: Animation, t: float) -> Vector3:
	var i := an.find_track(NodePath("Skeleton3D:Hips"), Animation.TYPE_POSITION_3D)
	return an.position_track_interpolate(i, t) if i >= 0 else Vector3(0, 0.98, 0)


## Where the feet are (model space) for a pose: the ankles' midpoint.
func _feet_mid(loc: Dictionary, hips_off: Vector3) -> Vector3:
	var p := _fk(loc, hips_off)
	return ((p.LeftFoot as Vector3) + (p.RightFoot as Vector3)) * 0.5


func _fk(loc: Dictionary, hips_off: Vector3) -> Dictionary:
	var g := {}
	var p := {}
	for b in WsgRig.BONES:
		var nm: String = b[0]
		if WsgRig.is_helper(nm):
			continue
		var q: Quaternion = loc.get(nm, Quaternion.IDENTITY)
		if b[1] == "":
			g[nm] = q
			p[nm] = (_joints[nm] as Vector3) + hips_off
		else:
			g[nm] = (g[b[1]] as Quaternion) * q
			p[nm] = (p[b[1]] as Vector3) + (g[b[1]] as Quaternion) * ((_joints[nm] as Vector3) - (_joints[b[1]] as Vector3))
	return p


func _hands_apart(an: Animation, t: float) -> float:
	var loc := {}
	for b in WsgRig.BONES:
		if not WsgRig.is_helper(b[0]):
			loc[b[0]] = _rot(an, b[0], t)
	var p := _fk(loc, Vector3.ZERO)
	return (p.LeftHandMiddle1 as Vector3).distance_to(p.RightHandMiddle1)


## One clap: from one meeting of the hands to the next, near the middle of the take.
func _one_clap(an: Animation) -> Array:
	var ts := []
	var ds := []
	var t := 0.5
	while t < an.length - 0.5:
		ts.append(t)
		ds.append(_hands_apart(an, t))
		t += 1.0 / 60.0
	var minima := []
	for i in range(2, ds.size() - 2):
		if ds[i] < 0.14 and ds[i] <= ds[i - 1] and ds[i] <= ds[i + 1] and ds[i] <= ds[i - 2] and ds[i] <= ds[i + 2]:
			if minima.is_empty() or ts[i] - minima[-1] > 0.25:
				minima.append(ts[i])
	if minima.size() < 2:
		return [an.length * 0.4, an.length * 0.4 + 0.5]
	var mid := minima.size() / 2
	var a: float = minima[mid - 1] if mid > 0 else minima[0]
	var b: float = minima[mid] if mid > 0 else minima[1]
	return [a, b]


## A stretch from t0 that ends close to where it began (between min and max seconds long).
func _seamless(an: Animation, t0: float, lo: float, hi: float) -> Array:
	var best := t0 + lo
	var err := INF
	var t := t0 + lo
	while t < minf(t0 + hi, an.length - 0.1):
		var e := 0.0
		for b in ["Hips", "Spine1", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "Head"]:
			e += _rot(an, b, t).angle_to(_rot(an, b, t0))
		if e < err:
			err = e
			best = t
		t += 1.0 / 30.0
	return [t0, best]


## When the take gets up at its end: from the last moment its hips are at seated height to the first they are back
## at standing height.
func _getting_up(an: Animation) -> Array:
	var stand := -INF
	var seat := INF
	var t := 0.6
	while t < an.length:
		var y := _pos(an, t).y
		stand = maxf(stand, y)
		seat = minf(seat, y)
		t += 1.0 / 30.0
	var t_end := an.length
	t = an.length
	while t > 0.6 and _pos(an, t).y > stand - 0.02:
		t -= 1.0 / 30.0
	t_end = minf(an.length, t + 1.0 / 30.0)
	while t > 0.6 and _pos(an, t).y > seat + 0.03:
		t -= 1.0 / 30.0
	return [t, t_end]
