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
## (stick_world), or the way from the camera to the body (behind-the-player cameras), within TOL degrees of either.
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
## must stay where it touched down. Each
## step's slip: how far the planted part (the slower of heel and ball) moved over the ground while touching, from the
## frame after it landed. Returns {steps, max_cm, p90_cm, mean_cm, toe_up_cm (the most a toe rose off the ground with
## its heel down)}.
const TOUCH := 0.03

## A frame may carry the game's own planted flags as items 4 and 5 (left, right: the planter's contact, what the motion
## means to be on the ground); without them a foot touches when its ankle or toe is within TOUCH of its rest height
## and it is not swinging through (moving under SWING m/s: a walking foot's toe passes a centimetre or two over the
## grass at the speed of a stride).
const SWING := 1.2
const FRAME_DT := 1.0 / 30.0

static func foot_slip(frames: Array, _ankle_rest := 0.0, _toe_rest := 0.0, ground_y := 0.0) -> Dictionary:
	var slips := []
	var toe_up := 0.0
	for side in 2:
		# Where this foot's ankle and toe are when it stands on the ground: the lowest each goes over the run (a rig's
		# rest heights are not where its bones stand: the test hurler's ankle bone stands 13 cm below its rest
		# height - every frame read as planted, a slow walk away one long slide).
		var ankle_rest := INF
		var toe_rest := INF
		for f: Array in frames:
			ankle_rest = minf(ankle_rest, (f[side * 2] as Vector3).y - ground_y)
			toe_rest = minf(toe_rest, (f[side * 2 + 1] as Vector3).y - ground_y)
		var start_a := Vector3.INF
		var start_t := Vector3.INF
		var touching_for := 0
		var worst := 0.0
		var prev_t := Vector3.INF
		for f: Array in frames:
			var a: Vector3 = f[side * 2]
			var t: Vector3 = f[side * 2 + 1]
			var ha := a.y - ground_y - ankle_rest
			var ht := t.y - ground_y - toe_rest
			if ha < TOUCH * 0.5:
				toe_up = maxf(toe_up, ht)
			# A body put somewhere new (a kick-off, a restart: more than 0.4 m in a frame) is a cut, not a slide.
			if prev_t != Vector3.INF and Vector2(t.x - prev_t.x, t.z - prev_t.z).length() > 0.4:
				if touching_for > 2:
					slips.append(worst * 100.0)
				touching_for = 0
				worst = 0.0
				prev_t = t
				continue
			var down: bool
			if f.size() > 5:
				down = bool(f[4 + side])
			else:
				var sp := Vector2(t.x - prev_t.x, t.z - prev_t.z).length() / FRAME_DT if prev_t != Vector3.INF else 0.0
				down = minf(ha, ht) < TOUCH and sp < SWING
			prev_t = t
			if down:
				touching_for += 1
				if touching_for == 2:
					start_a = a
					start_t = t
				elif touching_for > 2:
					var da := Vector2(a.x - start_a.x, a.z - start_a.z).length()
					var dt := Vector2(t.x - start_t.x, t.z - start_t.z).length()
					worst = maxf(worst, minf(da, dt))
			else:
				if touching_for > 2:
					slips.append(worst * 100.0)
				touching_for = 0
				worst = 0.0
		if touching_for > 2:
			slips.append(worst * 100.0)
	slips.sort()
	var mean := 0.0
	for s in slips:
		mean += float(s)
	return {"steps": slips.size(), "max_cm": float(slips[-1]) if not slips.is_empty() else 0.0,
		"p90_cm": float(slips[int(slips.size() * 0.9)]) if not slips.is_empty() else 0.0,
		"mean_cm": mean / maxf(1.0, slips.size()), "toe_up_cm": toe_up * 100.0}


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


## "" if the body stands naturally, else what it looks like: "T-pose" (both arms out level, straight) or "A-pose" (both
## out past 35 degrees, nearly straight) - a body left in its rest pose, or a game's base stance that is one (Pok Ta
## Pok: "base position is still like an A pose").
static func t_or_a_pose(body: WsgBody) -> String:
	var a := arms(body)
	var l: Array = a.Left
	var r: Array = a.Right
	if float(l[0]) > 70.0 and float(r[0]) > 70.0 and float(l[1]) < 25.0 and float(r[1]) < 25.0:
		return "T-pose (arms out %.0f and %.0f degrees, straight)" % [l[0], r[0]]
	if float(l[0]) > 35.0 and float(r[0]) > 35.0 and float(l[1]) < 25.0 and float(r[1]) < 25.0:
		return "A-pose (arms out %.0f and %.0f degrees, straight)" % [l[0], r[0]]
	return ""


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
