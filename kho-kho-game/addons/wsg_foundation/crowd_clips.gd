class_name WsgCrowdClips
extends RefCounted
## The crowd's motions, authored here as poses on the rig (so they are the studio's own, not licensed data), until
## the ActorCore crowd motions arrive (tools/bake_crowd.gd then bakes those instead). Each is a function of time on
## the canonical rig: limbs given as the way they point in the body's own frame (+Y up, +Z forward, +X its left),
## the rest as turns.
##   sit_idle      seated, breathing, shifting a little (loop)
##   sit_clap      seated, clapping: one clap a cycle (loop; the crowd's shader sets the rate and syncs it)
##   sit_to_stand  getting up (played by how far up a fan is; backwards it is sitting down)
##   stand_idle    standing, weight shifting (loop)
##   stand_clap    standing, clapping (loop, one clap a cycle)
##   cheer         standing, both arms up, waving (loop)

const CLIPS := {
	"sit_idle": [2.0, true], "sit_clap": [0.5, true], "sit_to_stand": [1.0, false], "stand_idle": [2.0, true],
	"stand_clap": [0.5, true], "cheer": [1.0, true],
}

## How far below the standing hips a seated fan's hips sit (metres, for 0.98 m hips): a seat 45 cm off the step.
const SIT_DROP := 0.415
## Seated, the feet are this far in front of where the hips would stand (m, for 0.98 m hips); the crowd puts each
## fan's origin this far behind the spot it is given (their feet), so the hips are over the seat.
const FEET_FORWARD := 0.34


static func q(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis.normalized(), deg_to_rad(deg))


## The pose at time t (seconds) of a clip: {bone: local Quaternion, "@hips": hips offset from rest (Vector3)}.
static func pose(clip: String, t: float) -> Dictionary:
	var len: float = CLIPS[clip][0]
	var u := fposmod(t, len) / len if CLIPS[clip][1] else clampf(t / len, 0.0, 1.0)
	match clip:
		"sit_idle":
			var p := _seated(0.0)
			var b := sin(u * TAU) * 0.5 + 0.5
			p["Spine1"] = q(Vector3.RIGHT, 2.0 + b * 2.0)
			p["Neck"] = q(Vector3.RIGHT, -3.0 + sin(u * TAU * 2.0) * 1.5)
			_arms(p, Vector3(0.15, -0.55, 0.8), Vector3(0.05, -0.35, 0.95), Vector3(-0.15, -0.55, 0.8), Vector3(-0.05, -0.35, 0.95))
			return _resolve(p)
		"sit_clap":
			var p := _seated(0.0)
			_clap(p, u)
			return _resolve(p)
		"sit_to_stand":
			# Lean forward over the feet, push up, straighten.
			var s := smoothstep(0.0, 1.0, u)
			var p := _seated(s)
			var lean := sin(clampf(u * 1.15, 0.0, 1.0) * PI) * 32.0
			p["Spine"] = q(Vector3.RIGHT, lean * 0.6)
			p["Spine1"] = q(Vector3.RIGHT, lean * 0.4)
			_arms(p, Vector3(0.18, -0.85, 0.45).lerp(Vector3(0.12, -1.0, 0.0), s), Vector3(0.05, -0.6, 0.8).lerp(Vector3(0.05, -0.95, 0.25), s),
				Vector3(-0.18, -0.85, 0.45).lerp(Vector3(-0.12, -1.0, 0.0), s), Vector3(-0.05, -0.6, 0.8).lerp(Vector3(-0.05, -0.95, 0.25), s))
			return _resolve(p)
		"stand_idle":
			var p := _seated(1.0)
			var w := sin(u * TAU)
			p["@hips"] = (p.get("@hips", Vector3.ZERO) as Vector3) + Vector3(w * 0.025, 0, 0)
			p["Spine"] = q(Vector3.BACK, -w * 2.0)
			_arms(p, Vector3(0.12, -1.0, 0.02), Vector3(0.06, -0.97, 0.18), Vector3(-0.12, -1.0, 0.02), Vector3(-0.06, -0.97, 0.18))
			return _resolve(p)
		"stand_clap":
			var p := _seated(1.0)
			_clap(p, u)
			return _resolve(p)
		"cheer":
			var p := _seated(1.0)
			var w := sin(u * TAU)
			p["Spine1"] = q(Vector3.RIGHT, -6.0)
			p["Neck"] = q(Vector3.RIGHT, -12.0)
			p["@hips"] = (p.get("@hips", Vector3.ZERO) as Vector3) + Vector3(0, absf(w) * 0.03, 0)
			_arms(p, Vector3(0.35 + w * 0.12, 0.93, 0.08), Vector3(0.12 + w * 0.3, 0.95, 0.12),
				Vector3(-0.35 + w * 0.12, 0.93, 0.08), Vector3(-0.12 + w * 0.3, 0.95, 0.12))
			p["LeftShoulder"] = q(Vector3.BACK, 18.0)
			p["RightShoulder"] = q(Vector3.FORWARD, 18.0)
			return _resolve(p)
	return {}


## Seated (s = 0) to standing (s = 1): the hips, thighs, knees and feet.
static func _seated(s: float) -> Dictionary:
	var thigh := lerpf(-88.0, 0.0, s)
	var knee := lerpf(88.0, 0.0, s)
	var p := {}
	# Seated, the hips are over the seat and the feet in front; standing, the feet stay where they were (in front of the
	# seat, on the step), so the body comes forward as it gets up.
	p["@hips"] = Vector3(0, -SIT_DROP * (1.0 - s), lerpf(-0.08, FEET_FORWARD, s))
	for side in ["Left", "Right"]:
		p[side + "UpLeg"] = q(Vector3.RIGHT, thigh) * q(Vector3.BACK, (6.0 if side == "Left" else -6.0) * (1.0 - s))
		p[side + "Leg"] = q(Vector3.RIGHT, knee)
		p[side + "Foot"] = q(Vector3.RIGHT, 0.0)
	return p


## Clapping at phase u: the hands meet in front of the chest at u = 0 and are apart at u = 0.5.
static func _clap(p: Dictionary, u: float) -> void:
	var open := 0.5 - 0.5 * cos(u * TAU)
	var ua := Vector3(0.28, -0.62, 0.72)
	var fa := Vector3(-0.62 + 0.55 * open, 0.32, 0.72)
	_arms(p, ua, fa, Vector3(-ua.x, ua.y, ua.z), Vector3(-fa.x, fa.y, fa.z))
	p["LeftHand"] = q(Vector3.RIGHT, -80.0)
	p["RightHand"] = q(Vector3.LEFT, -80.0)


## The arms pointing the given ways (upper arm, forearm; body frame), left then right.
static func _arms(p: Dictionary, lu: Vector3, lf: Vector3, ru: Vector3, rf: Vector3) -> void:
	p["@aim"] = {"LeftArm": lu.normalized(), "LeftForeArm": lf.normalized(), "RightArm": ru.normalized(), "RightForeArm": rf.normalized()}


## Turns the "@aim" directions into local turns, through the parents' turns (forward kinematics on the rest).
static func _resolve(p: Dictionary) -> Dictionary:
	var aim: Dictionary = p.get("@aim", {})
	var rest_dir := {"LeftArm": Vector3.RIGHT, "LeftForeArm": Vector3.RIGHT, "RightArm": Vector3.LEFT, "RightForeArm": Vector3.LEFT}
	var g := {}
	var out := {}
	for b in WsgRig.BONES:
		var nm: String = b[0]
		if WsgRig.is_helper(nm):
			continue
		var pg: Quaternion = g.get(b[1], Quaternion.IDENTITY)
		var local: Quaternion = p.get(nm, Quaternion.IDENTITY)
		if aim.has(nm) and nm.ends_with("Arm") and not nm.ends_with("ForeArm"):
			# The upper arm to its aim, spun about its length so the elbow's hinge holds the forearm's aim too.
			var u: Vector3 = aim[nm]
			var f: Vector3 = aim[nm.replace("Arm", "ForeArm")]
			var ga := Quaternion(rest_dir[nm], u)
			var hinge_local := Vector3.DOWN if nm.begins_with("Left") else Vector3.UP
			var n := u.cross(f)
			if n.length() > 0.05:
				var now := ga * hinge_local
				ga = Quaternion(u, now.signed_angle_to(n.normalized(), u)) * ga
			local = pg.inverse() * ga
		elif aim.has(nm) and nm.ends_with("ForeArm"):
			# The elbow bends about its hinge by the angle between the upper arm and the forearm's aim.
			var u: Vector3 = pg * rest_dir[nm]
			var f: Vector3 = aim[nm]
			var hinge_local := Vector3.DOWN if nm.begins_with("Left") else Vector3.UP
			local = Quaternion(hinge_local, u.angle_to(f))
		g[nm] = pg * local
		if local != Quaternion.IDENTITY:
			out[nm] = local
	out["@hips"] = p.get("@hips", Vector3.ZERO)
	return out
