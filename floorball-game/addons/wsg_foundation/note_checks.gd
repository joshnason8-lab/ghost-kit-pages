class_name WsgNoteChecks
extends RefCounted
## The checks the owner's notes keep coming back to, shared by every game's note tests (WsgOwnerNote) and the world
## check: the joystick on every camera, feet planted, no T- or A-pose, no block figures, no twitching while standing,
## the hands on what they hold, key sounds crisp. Each measures the symptom over its whole range and returns what
## failed (an empty Array: none) or the numbers.

## A stick (x right, y DOWN as Godot's Input.get_vector gives it: up is -1) as a direction on the ground for CAMERA:
## pushed up, the body goes the way the camera looks (its forward, flat on the ground); right, to the camera's right -
## on any camera: alongside, end-on behind a goal, from a corner, behind the player, and overhead (looking straight
## down: up the stick is up the screen). The games' mapping, or what joystick() checks theirs against. AT (the body's
## place) is not needed by this one; it is there for mappings that use it. Returns a flat unit vector.
static func stick_world(stick: Vector2, cam: Camera3D, _at := Vector3.ZERO) -> Vector3:
	if stick.length() < 0.001:
		return Vector3.ZERO
	var f := _ground_forward(cam)
	var r := Vector3(-f.z, 0, f.x)
	var w := r * stick.x - f * stick.y
	return w.normalized()


## The camera's forward flat on the ground (looking straight down: its up, the top of the screen).
static func _ground_forward(cam: Camera3D) -> Vector3:
	var b := cam.global_transform.basis
	var f := -b.z
	f.y = 0.0
	if f.length() < 0.2:
		f = b.y
		f.y = 0.0
	return f.normalized()


## The joystick on every camera: for each camera, at the screen's centre, its edges and its corners (10% in) - the
## body standing there - the stick pushed 8 ways, MAP(stick: Vector2, cam: Camera3D, at: Vector3) -> Vector3 (the
## game's own mapping: where the body would go) against the camera-relative ways: the camera's own flat forward
## (stick_world), the way from the camera to the body (behind-the-player cameras), or the screen-true way (the stick's
## direction on the screen where the body is drawn, met with the floor), within TOL degrees of any.
## A mapping fixed to the world (up the stick = up the court: the fault the owner saw on any camera not alongside the
## court) goes 90 to 180 degrees off. The cameras must be in a viewport. Returns the failures.
static func joystick(map: Callable, cameras: Array, tol := 25.0, ground_y := 0.0) -> Array:
	var out := []
	var names := ["centre", "top", "bottom", "left", "right", "top-left", "top-right", "bottom-left", "bottom-right"]
	var spots := [Vector2(0.5, 0.5), Vector2(0.5, 0.1), Vector2(0.5, 0.9), Vector2(0.1, 0.5), Vector2(0.9, 0.5),
		Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.1, 0.9), Vector2(0.9, 0.9)]
	var sticks := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0),
		"up-left": Vector2(-1, -1), "up-right": Vector2(1, -1), "down-left": Vector2(-1, 1), "down-right": Vector2(1, 1)}
	for cam: Camera3D in cameras:
		var size := cam.get_viewport().get_visible_rect().size
		var worst := 0.0
		var worst_what := ""
		for k in spots.size():
			var sp: Vector2 = spots[k] * size
			var o := cam.project_ray_origin(sp)
			var d := cam.project_ray_normal(sp)
			if d.y > -1e-3:
				continue        # (that part of the screen shows sky, not ground)
			var at := o + d * ((ground_y - o.y) / d.y)
			var to := at - cam.global_position
			to.y = 0.0
			for sn in sticks:
				var st: Vector2 = sticks[sn]
				var w: Vector3 = map.call(st, cam, at)
				w.y = 0.0
				if w.length() < 1e-4:
					out.append("camera '%s', %s, stick %s: the body does not move" % [cam.name, names[k], sn])
					continue
				var off := rad_to_deg(w.angle_to(stick_world(st, cam)))
				if to.length() > 1.0:
					var f := to.normalized()
					var r := Vector3(-f.z, 0, f.x)
					var e2 := (r * st.x - f * st.y).normalized()
					off = minf(off, rad_to_deg(w.angle_to(e2)))
				# Or the screen-true way: the floor point a little way from the body in the stick's direction on the
				# screen (Sepak Takraw's ray mapping: the body goes the stick's way where it is drawn - a flat 45-degree
				# floor diagonal is drawn up to 40 degrees off it at the top of a broadcast picture).
				var s2 := sp + st.normalized() * maxf(4.0, size.y * 0.03)
				var o2 := cam.project_ray_origin(s2)
				var d2 := cam.project_ray_normal(s2)
				if d2.y < -1e-3:
					var p2 := o2 + d2 * ((ground_y - o2.y) / d2.y)
					var e3 := Vector3(p2.x - at.x, 0, p2.z - at.z)
					if e3.length() > 1e-4:
						off = minf(off, rad_to_deg(w.angle_to(e3)))
				if off > worst:
					worst = off
					worst_what = "%s, stick %s" % [names[k], sn]
		if worst > tol:
			out.append("camera '%s', %s: goes %.0f degrees off the camera's way (at most %.0f)" % [cam.name, worst_what, worst, tol])
	return out


## Both feet of a body as drawn: [left ankle, left toe, right ankle, right toe] (world).
static func feet(body: WsgBody) -> Array:
	return [body.bone_world("LeftFoot").origin, body.bone_world("LeftToeBase").origin,
		body.bone_world("RightFoot").origin, body.bone_world("RightToeBase").origin]


## Planted feet over a run of frames (feet() each frame; the two rest heights are no longer used - each foot's height
## on the ground is the lowest it goes over the run): a foot touching the ground (its ankle or toe within TOUCH of that)
## must stay where it touched down. Each step's slip: frame by frame while touching, how far the foot slid over the
## ground - the smaller of the heel's and the ball's move that frame - added up over the step. A heel-to-toe roll moves
## one of them at a time (the toe coming down about the heel, then the heel rising over the ball) and reads near 0; a
## slide moves both and reads in full. The frame a foot comes down in is its arrival, not counted: it is counted from
## the first frame it is down. (Until 2026-11-04 it took the smaller of each one's drift since the step began: a roll's
## two halves added up to 3 cm - Sepak Takraw found it - and a real 8 cm slide at a walk read 2.7. tests/foot_slip_test
## pins it: a pure roll under 0.5 cm, a planted foot pushed 3 cm 3 cm or more, the planter off 5 cm or more.)
## skid_cm: the most a foot FLAT on the ground (its heel and its toe both within FLAT of standing, this frame and the
## last) moved in one frame, the smaller of the two ends' moves - whatever the swing gate or the game's flags say. A foot
## coming in flat and fast, or snapped back by the clip as it lands, is gliding on the floor (a hard stop from a run
## snapped the foot back 7-8 cm in a frame, read as swinging - the lead, 2026-11-03). A swinging foot is never flat (its
## toe skims the grass, its heel well up): a walk's swing toe moves 8-12 cm a frame within 3 cm of the ground, not a skid.
## jump_cm: the most a LOW foot (heel or toe within LOW of standing, over four frames) jumped in a frame - the smaller of
## the change in its move into the frame and out of it, the smaller of the heel's and the toe's (a jump goes still -
## far - still; a landing changes sharply on one side only, a take-off on the other, a swing smoothly). Every game's
## walker, walking to sprinting and cutting at 8 m/s, reads 15.4 cm at most (tools/feet_calibrate, 2026-11-03); a stop
## from a sprint that re-planted the foot a stride on read 40-88.
## Returns {steps, max_cm, p90_cm, mean_cm, toe_up_cm (the most a toe rose off the ground with its heel down), skid_cm,
## jump_cm}.
const TOUCH := 0.03
## Flat on the floor (skid_cm): heel and toe both within this (m). (At 3 cm a walk's foot still coming down - heel 3.0,
## toe 2.2 cm up, the frame before it landed - read as an 11 cm skid; the glides it is for sit at 0-1.5 cm.)
const FLAT := 0.02
## A low foot (jump_cm): heel or toe within this of standing (m).
const LOW := 0.10

## A frame may carry the game's own planted flags as items 4 and 5 (left, right: the planter's contact, what the motion
## means to be on the ground); without them a foot touches when its ankle or toe is within TOUCH of its rest height
## and it is not swinging through (moving under SWING m/s: a walking foot's toe passes a centimetre or two over the
## grass at the speed of a stride).
const SWING := 1.2
const FRAME_DT := 1.0 / 30.0

## gaps: for a body not posed every frame (FoundationLink.pose_every 2-3 on far bodies), how many frames each sample
## is after the one before (empty: every frame). A move over N frames is N frames' moves: the skid and the jump are per
## frame (the jump per frame per frame), the cut's bound and a swing's speed scale with it, the slip (a distance over the
## step) does not (Kabaddi: an official posed every 3rd frame, a landing foot read 2.7 cm "in one frame" from three
## frames' 0.9).
## held: for each sample, [left, right] - whether the planter had that foot then (WsgFootPlanter.holding); given, a
## skid counts only a foot it had in both samples (a clip's own low swing is the jump's to judge, not the skid's).
static func foot_slip(frames: Array, _ankle_rest := 0.0, _toe_rest := 0.0, ground_y := 0.0, gaps := PackedInt32Array(), held := []) -> Dictionary:
	var slips := []
	var toe_up := 0.0
	var skid := 0.0
	var jump := 0.0
	# Where each was worst: [foot (0 left), first frame, last frame] (indexes into FRAMES; -1: none).
	var slip_at := [-1, -1, -1]
	var slip_most := 0.0
	var skid_at := [-1, -1, -1]
	var jump_at := [-1, -1, -1]
	for side in 2:
		# Where this foot's ankle and toe are when it stands on the ground: the lowest each goes over the run (a rig's
		# rest heights are not where its bones stand: the test hurler's ankle bone stands 13 cm below its rest
		# height - every frame read as planted, a slow walk away one long slide).
		var ankle_rest := INF
		var toe_rest := INF
		for f: Array in frames:
			ankle_rest = minf(ankle_rest, (f[side * 2] as Vector3).y - ground_y)
			toe_rest = minf(toe_rest, (f[side * 2 + 1] as Vector3).y - ground_y)
		var prev_a := Vector3.INF
		var touching_for := 0
		var worst := 0.0
		var prev_t := Vector3.INF
		var was_flat := false
		for fi in frames.size():
			var f: Array = frames[fi]
			var g := float(maxi(1, gaps[fi])) if fi < gaps.size() else 1.0
			var a: Vector3 = f[side * 2]
			var t: Vector3 = f[side * 2 + 1]
			var ha := a.y - ground_y - ankle_rest
			var ht := t.y - ground_y - toe_rest
			if ha < TOUCH * 0.5:
				toe_up = maxf(toe_up, ht)
			# A body put somewhere new (a kick-off, a restart: more than 0.4 m in a frame) is a cut, not a slide.
			if prev_t != Vector3.INF and Vector2(t.x - prev_t.x, t.z - prev_t.z).length() > 0.4 * g:
				if touching_for > 2:
					slips.append(worst * 100.0)
					if worst * 100.0 > slip_most:
						slip_most = worst * 100.0
						slip_at = [side, fi - touching_for, fi - 1]
				touching_for = 0
				worst = 0.0
				prev_t = t
				prev_a = a
				was_flat = false
				continue
			var down: bool
			if f.size() > 5:
				down = bool(f[4 + side])
			else:
				var sp := Vector2(t.x - prev_t.x, t.z - prev_t.z).length() / (FRAME_DT * g) if prev_t != Vector3.INF else 0.0
				down = minf(ha, ht) < TOUCH and sp < SWING
			var step_a := Vector2(a.x - prev_a.x, a.z - prev_a.z).length() if prev_a != Vector3.INF else 0.0
			var step_t := Vector2(t.x - prev_t.x, t.z - prev_t.z).length() if prev_t != Vector3.INF else 0.0
			prev_t = t
			prev_a = a
			var flat := maxf(ha, ht) < FLAT
			var had: bool = held.is_empty() or (fi < held.size() and fi > 0 and bool(held[fi][side]) and bool(held[fi - 1][side]))
			if flat and was_flat and had and minf(step_a, step_t) / g > skid:
				skid = minf(step_a, step_t) / g
				skid_at = [side, fi - 1, fi]
			was_flat = flat
			if down:
				touching_for += 1
				if touching_for >= 2:
					worst += minf(step_a, step_t)
			else:
				if touching_for > 2:
					slips.append(worst * 100.0)
					if worst * 100.0 > slip_most:
						slip_most = worst * 100.0
						slip_at = [side, fi - touching_for, fi - 1]
				touching_for = 0
				worst = 0.0
		if touching_for > 2:
			slips.append(worst * 100.0)
			if worst * 100.0 > slip_most:
				slip_most = worst * 100.0
				slip_at = [side, frames.size() - touching_for, frames.size() - 1]
		# The jump: over each four frames with the foot low throughout. (A body put somewhere new moves metres: over 1.5 m
		# in a frame is a cut, not a jump - not the slip's 0.4 m, which the stop teleports it is for passed, 40-95 cm.)
		for k in range(2, frames.size() - 1):
			var lowk := true
			for j in range(k - 2, k + 2):
				var fj: Array = frames[j]
				if minf((fj[side * 2] as Vector3).y - ground_y - ankle_rest, (fj[side * 2 + 1] as Vector3).y - ground_y - toe_rest) >= LOW:
					lowk = false
					break
			if not lowk:
				continue
			var jmp := INF
			for e in 2:
				var p1: Vector3 = frames[k - 2][side * 2 + e]
				var p2: Vector3 = frames[k - 1][side * 2 + e]
				var p3: Vector3 = frames[k][side * 2 + e]
				var p4: Vector3 = frames[k + 1][side * 2 + e]
				var g2 := float(maxi(1, gaps[k - 1])) if k - 1 < gaps.size() else 1.0
				var g3 := float(maxi(1, gaps[k])) if k < gaps.size() else 1.0
				var g4 := float(maxi(1, gaps[k + 1])) if k + 1 < gaps.size() else 1.0
				if Vector2(p3.x - p2.x, p3.z - p2.z).length() > 1.5 * g3:
					jmp = 0.0
					break
				# (The change in the per-frame move per frame: with every frame posed, the second difference. A body
				# posed every 3rd frame changes its move over 3 frames: per frame, a smooth stride reads as it does
				# posed every frame - the bound's calibration - where a raw difference read 9 times as much.)
				var v12 := Vector2(p2.x - p1.x, p2.z - p1.z) / g2
				var v23 := Vector2(p3.x - p2.x, p3.z - p2.z) / g3
				var v34 := Vector2(p4.x - p3.x, p4.z - p3.z) / g4
				var into := (v23 - v12).length() / ((g2 + g3) * 0.5)
				var out := (v34 - v23).length() / ((g3 + g4) * 0.5)
				jmp = minf(jmp, minf(into, out))
			if jmp > jump:
				jump = jmp
				jump_at = [side, k - 2, k + 1]
	slips.sort()
	var mean := 0.0
	for s in slips:
		mean += float(s)
	return {"steps": slips.size(), "max_cm": float(slips[-1]) if not slips.is_empty() else 0.0,
		"p90_cm": float(slips[int(slips.size() * 0.9)]) if not slips.is_empty() else 0.0,
		"mean_cm": mean / maxf(1.0, slips.size()), "toe_up_cm": toe_up * 100.0, "skid_cm": skid * 100.0,
		"jump_cm": jump * 100.0, "max_at": slip_at, "skid_at": skid_at, "jump_at": jump_at}


## The legs of skeleton SK, as bone indices [[hip, knee, ankle, toe], [...]] (left, right), or [] if it has none we know:
## the names its WsgFootPlanter maps (a game's own rig on the planter), then the rig's own names, bare or with a Mixamo
## prefix; NAMES (a game's own, [[hip, knee, ankle, toe] x2] by name - or with the toe a Vector3, the body's forward at
## rest in the skeleton's space, for a rig with no toe bone) first if given.
static func leg_bones(sk: Skeleton3D, names: Array = []) -> Array:
	var tries := []
	if names.size() == 2:
		tries.append(names)
	for c in sk.get_children():
		if c is WsgFootPlanter:
			var pl := c as WsgFootPlanter
			tries.append(WsgFootPlanter.LEGS.map(func(leg: Array) -> Array:
				return leg.map(func(n: String) -> String: return pl.bone_prefix + String(pl.bone_map.get(n, n)))))
	for pre in ["", "mixamorig_", "mixamorig:", "mixamorig1:"]:
		tries.append(WsgFootPlanter.LEGS.map(func(leg: Array) -> Array: return leg.map(func(n: String) -> String: return pre + n)))
	for t: Array in tries:
		# (A leg's fourth may be its forward at rest, in the skeleton's space, for a rig with no toe: kept as it is.)
		var ix := (t as Array).map(func(leg: Array) -> Array: return leg.map(func(n: Variant) -> Variant:
			return n if n is Vector3 else sk.find_bone(String(n))))
		if ix.all(func(leg: Array) -> bool: return leg.size() == 4 and leg.all(func(b: Variant) -> bool: return b is Vector3 or int(b) >= 0)):
			return ix
	return []


## A knee bent backwards (KNEE_BACK m behind the line from its hip to its ankle, against the body's forward, with the
## leg bent at least KNEE_BENT off straight), as drawn: the owner's "broken backwards knees" (Sepak Takraw's Low
## RealBody, 2026-11-04: the foot planter bent them 10-25 cm behind on a rig whose thigh +Z points back). 4 cm, about 5
## degrees on a grown leg: a locked knee in a standing or striding clip goes 1.5-2.6 cm past straight (Hurling's
## players, a frame now and then), which no one sees as broken.
const KNEE_BACK := 0.04
const KNEE_BENT := 0.015


## Each leg of SK (LEGS from leg_bones) now, read as drawn (call it inside skeleton_updated): [[how far the knee is in
## front of its hip-ankle line along the body's forward (m; negative behind), how far off that line it is (m)], ...].
## The body's forward is the rest pose's (its feet's way, heel to toe, standing) carried as its hips (the thighs'
## parent) now turn: whichever way the rig's bones face, and not the foot's own way now (a running stride's heel kicked
## up behind points its toe back).
static func knees(sk: Skeleton3D, legs: Array) -> Array:
	var out := []
	var xf := sk.global_transform
	var hips := sk.get_bone_parent(int(legs[0][0]))
	var rest_way := Vector3.ZERO
	for leg: Array in legs:
		rest_way += (leg[3] as Vector3) if leg[3] is Vector3 else sk.get_bone_global_rest(leg[3]).origin - sk.get_bone_global_rest(leg[2]).origin
	rest_way.y = 0.0
	var fwd := rest_way
	if hips >= 0:
		var rb := sk.get_bone_global_rest(hips).basis
		var nb := sk.get_bone_global_pose(hips).basis
		fwd = nb * (rb.inverse() * rest_way)
	fwd = xf.basis * fwd
	fwd.y = 0.0
	for leg: Array in legs:
		var hip := xf * sk.get_bone_global_pose(leg[0]).origin
		var knee := xf * sk.get_bone_global_pose(leg[1]).origin
		var ank := xf * sk.get_bone_global_pose(leg[2]).origin
		var line := ank - hip
		if line.length() < 0.0001 or fwd.length() < 0.0001:
			out.append([0.0, 0.0])
			continue
		line = line.normalized()
		var off := (knee - hip) - line * (knee - hip).dot(line)
		out.append([off.dot(fwd.normalized()), off.length()])
	return out


## A body's arms now: {"Left": [how far the upper arm is out from hanging down (degrees), the elbow's bend (degrees,
## 0 straight)], "Right": [...]}.
static func arms(body: WsgBody) -> Dictionary:
	var out := {}
	var down := -body.global_transform.basis.y.normalized()
	for side in ["Left", "Right"]:
		var sh := body.bone_world(side + "Arm").origin
		var el := body.bone_world(side + "ForeArm").origin
		var wr := body.bone_world(side + "Hand").origin
		var up := (el - sh).normalized()
		var fo := (wr - el).normalized()
		out[side] = [rad_to_deg(up.angle_to(down)), rad_to_deg(up.angle_to(fo))]
	return out


## "" if the body stands naturally, else what it looks like: "T-pose" (both arms out level, 70 to 110 degrees from
## hanging, straight) or "A-pose" (both out 35 to 70 degrees, nearly straight) - and out to the SIDES, as a rig's rest
## pose holds them - a body left in its rest pose, or a game's base stance that is one (Pok Ta Pok: "base position is
## still like an A pose"). Arms raised overhead (a catch at the top of a leap, a defended shot: over 110 degrees), or
## reaching forward (a catch, a mark), are moves, not a rest pose (Netball: 1-5 players a mode were flagged at
## 61-146 degrees while catching and defending).
static func t_or_a_pose(body: WsgBody) -> String:
	var a := arms(body)
	var l: Array = a.Left
	var r: Array = a.Right
	if float(l[1]) >= 25.0 or float(r[1]) >= 25.0:
		return ""
	if not (_sideways(body, "Left") and _sideways(body, "Right")):
		return ""
	if float(l[0]) > 70.0 and float(r[0]) > 70.0 and float(l[0]) <= 110.0 and float(r[0]) <= 110.0:
		return "T-pose (arms out %.0f and %.0f degrees, straight)" % [l[0], r[0]]
	if float(l[0]) > 35.0 and float(r[0]) > 35.0 and float(l[0]) <= 70.0 and float(r[0]) <= 70.0:
		return "A-pose (arms out %.0f and %.0f degrees, straight)" % [l[0], r[0]]
	return ""


## The upper arm goes out to the body's side (its across-the-body part the most of its level part), not forward or
## back.
static func _sideways(body: WsgBody, side: String) -> bool:
	var up := body.bone_world(side + "ForeArm").origin - body.bone_world(side + "Arm").origin
	var across := (body.bone_world("RightArm").origin - body.bone_world("LeftArm").origin)
	across.y = 0.0
	var level := Vector3(up.x, 0, up.z)
	if level.length() < 1e-4 or across.length() < 1e-4:
		return false
	return absf(level.normalized().dot(across.normalized())) >= 0.7


## "" if NODE is drawn as a person, else why it is a block figure: no skinned mesh under it, or primitive shapes (a
## box, a capsule, a cylinder over 15 cm) standing in for one (Pok Ta Pok: "the man doing the smoke ritual looks like
## a block figure").
static func block_figure(node: Node) -> String:
	var skinned := false
	var prims := []
	for n in node.find_children("*", "GeometryInstance3D", true, false):
		if not (n as GeometryInstance3D).is_visible_in_tree():
			continue
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh is PrimitiveMesh and (mi.mesh as PrimitiveMesh).get_aabb().get_longest_axis_size() > 0.15:
				prims.append("%s (%s)" % [mi.name, mi.mesh.get_class()])
			elif mi.mesh != null and mi.skin != null:
				skinned = true
	if not skinned:
		return "no skinned body is drawn"
	if not prims.is_empty():
		return "drawn with primitive shapes: %s" % ", ".join(prims)
	return ""


## Every bone's turn now (the skeleton's own space), for jitter().
static func pose(body: WsgBody) -> Array:
	var sk := body.skeleton
	var out := []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_global_pose(i).basis.get_rotation_quaternion())
	return out


## A standing body's twitching (Kabaddi: "standing position is still awful guy is twitching"): over POSES (pose()
## each frame), the most any bone turned from one frame to the next, and how often a bone jerked back the way it came
## (a turn over 1.5 degrees reversed the next frame). Returns {max_deg, bone, reversals}.
static func jitter(body: WsgBody, poses: Array) -> Dictionary:
	var sk := body.skeleton
	var worst := 0.0
	var bone := ""
	var reversals := 0
	for i in sk.get_bone_count():
		var prev_axis := Vector3.ZERO
		var prev_ang := 0.0
		for f in range(1, poses.size()):
			var q0: Quaternion = poses[f - 1][i]
			var q1: Quaternion = poses[f][i]
			var dq := q0.inverse() * q1
			var ang := rad_to_deg(dq.get_angle())
			if ang > 180.0:
				ang = 360.0 - ang
			if ang > worst:
				worst = ang
				bone = sk.get_bone_name(i)
			var axis := dq.get_axis() if ang > 0.01 else Vector3.ZERO
			if ang > 1.5 and prev_ang > 1.5 and axis.dot(prev_axis) < -0.5:
				reversals += 1
			prev_axis = axis
			prev_ang = ang
	return {"max_deg": worst, "bone": bone, "reversals": reversals}


## A key sound stays crisp at a distance (the post clang the owner could not hear): KIND is one WsgAudio plays with
## no distance filter. Returns the failures.
static func bright(au: WsgAudio, kinds: Array) -> Array:
	var out := []
	for k in kinds:
		if not au.bright_kinds.has(k):
			out.append("'%s' is played dulled by distance (not in WsgAudio.bright_kinds)" % k)
	return out
