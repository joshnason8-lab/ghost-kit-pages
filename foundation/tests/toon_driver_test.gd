extends SceneTree
## WsgToonDriver: the motion capture on a game's own 17-bone toon (the Low tier).
##   godot --headless --path . --fixed-fps 30 -s tests/toon_driver_test.gd
## With the clip library: a walk and a run move the toon's bones; the feet stay under the hips and come down to the
## ground; knees and elbows bend inside their range and the right way (and the arms are bent when running); the
## stride frequency rises with speed and a planted foot does not skate; an override of 1 leaves the game's pose
## exactly as it was (all of it, or the arms only), pose() is the same pose as a dictionary, staggering poses only
## on its frames; a Kabaddi-like toon (A-pose, legs apart, facing -Z, its own bone names) runs the right way round;
## the feet rule on a toon walking to running, with plant (a foot down held) and without; and the CPU for 14 bodies
## is measured. Without the library (or with it hidden, as here at the end): available()
## is false and update() changes nothing.

const DT := 1.0 / 60.0
## ToonBody's bones (Netball; Takraw Smash's): identity rests, the arms hanging, facing +Z, the left +X.
const NETBALL := [
	["hips", -1, Vector3(0, 0.93, 0)], ["spine", 0, Vector3(0, 0.12, 0)], ["chest", 1, Vector3(0, 0.19, 0)],
	["neck", 2, Vector3(0, 0.2, 0)], ["head", 3, Vector3(0, 0.07, 0)],
	["upperarm_l", 2, Vector3(0.175, 0.15, 0)], ["forearm_l", 5, Vector3(0, -0.27, 0)], ["hand_l", 6, Vector3(0, -0.24, 0)],
	["upperarm_r", 2, Vector3(-0.175, 0.15, 0)], ["forearm_r", 8, Vector3(0, -0.27, 0)], ["hand_r", 9, Vector3(0, -0.24, 0)],
	["thigh_l", 0, Vector3(0.095, -0.05, 0)], ["shin_l", 11, Vector3(0, -0.43, 0)], ["foot_l", 12, Vector3(0, -0.41, 0)],
	["thigh_r", 0, Vector3(-0.095, -0.05, 0)], ["shin_r", 14, Vector3(0, -0.43, 0)], ["foot_r", 15, Vector3(0, -0.41, 0)]]
## Kabaddi's rigged body (player_01): an A-pose with the legs apart, facing -Z (its left -X), heads in model space,
## under its own names (bone_map), with fingers under the hands that the driver does not know.
const KABADDI := [
	["pelvis", -1, Vector3(0.003, 0.958, 0.024)], ["spine", 0, Vector3(0.002, 1.137, 0.032)],
	["chest", 1, Vector3(0.002, 1.328, 0.04)], ["neck", 2, Vector3(0.001, 1.555, 0.05)], ["head", 3, Vector3(-0.007, 1.647, 0.0)],
	["sh_l", 2, Vector3(-0.173, 1.527, 0.029)], ["el_l", 5, Vector3(-0.45, 1.344, 0.013)], ["wr_l", 6, Vector3(-0.699, 1.369, -0.055)],
	["sh_r", 2, Vector3(0.176, 1.523, 0.071)], ["el_r", 8, Vector3(0.415, 1.343, 0.035)], ["wr_r", 9, Vector3(0.766, 1.377, -0.062)],
	["hip_l", 0, Vector3(-0.122, 0.962, 0.016)], ["kn_l", 11, Vector3(-0.297, 0.53, 0.012)], ["an_l", 12, Vector3(-0.401, 0.124, 0.069)],
	["hip_r", 0, Vector3(0.128, 0.953, 0.031)], ["kn_r", 14, Vector3(0.311, 0.516, 0.025)], ["an_r", 15, Vector3(0.438, 0.108, 0.075)],
	["fingers_l", 7, Vector3(-0.786, 1.377, -0.079)], ["fingers_r", 10, Vector3(0.839, 1.385, -0.083)]]
const KABADDI_MAP := {"hips": "pelvis", "upperarm_l": "sh_l", "forearm_l": "el_l", "hand_l": "wr_l",
	"upperarm_r": "sh_r", "forearm_r": "el_r", "hand_r": "wr_r", "thigh_l": "hip_l", "shin_l": "kn_l", "foot_l": "an_l",
	"thigh_r": "hip_r", "shin_r": "kn_r", "foot_r": "an_r"}

var fails := []


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func():
		printerr("TOON DRIVER TEST: timed out")
		quit(2))
	if WsgClips.available():
		await _with_data()
		var on: Array = await _feet_rule(true)
		var off: Array = await _feet_rule(false)
		print("feet rule, walk-jog-run: planted slide %.1f cm, skid %.1f, jump %.1f (the clip's feet as they come: %.1f, %.1f, %.1f)" % [on[0], on[1], on[2], off[0], off[1], off[2]])
		_check(float(off[0]) > 2.0, "the case tests it: the clip's own feet slide over 2 cm a step on the toon (%.1f)" % off[0])
		_check(float(on[0]) <= 2.0, "a foot down is held: planted slide %.1f cm (2.0 at most)" % on[0])
		_check(float(on[1]) <= 2.0, "a held foot does not skid: %.1f cm in a frame (2.0 at most)" % on[1])
		_check(float(on[2]) <= WsgWorldRules.JUMP_MAX_CM, "a held foot let go does not jump: %.1f cm (%.0f at most)" % [on[2], WsgWorldRules.JUMP_MAX_CM])
	else:
		print("(no clip library in this build: only the fallback is tested)")
	_without_data()
	for f in fails:
		printerr("FAIL: ", f)
	print("TOON DRIVER TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		fails.append(what)


## A toon in the scene: [holder Node3D, Skeleton3D]. Bones given as model-space heads (absolute) or offsets.
func _toon(spec: Array, absolute: bool) -> Array:
	var holder := Node3D.new()
	root.add_child(holder)
	var sk := Skeleton3D.new()
	holder.add_child(sk)
	for i in spec.size():
		sk.add_bone(spec[i][0])
		var p: int = spec[i][1]
		var off: Vector3 = spec[i][2]
		if p >= 0:
			sk.set_bone_parent(i, p)
			if absolute:
				off = off - (spec[p][2] as Vector3)
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, off))
	sk.reset_bone_poses()
	return [holder, sk]


func _wpos(sk: Skeleton3D, name: String) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(name)).origin


## Runs the toon along +Z (yaw 0) at speed for secs, measuring as it goes. toon_face: the yaw its node is turned by
## to face +Z; toon_fwd: its front in its own frame (+Z, or -Z for Kabaddi's). names: [hips, thigh_l, shin_l, foot_l, thigh_r, shin_r, foot_r, upperarm_l,
## forearm_l, hand_l, upperarm_r, forearm_r, hand_r].
func _run(d: WsgToonDriver, holder: Node3D, sk: Skeleton3D, speed: float, secs: float, names: Array, toon_face: float, toon_fwd := Vector3.BACK) -> Dictionary:
	var ankle_rest: float = sk.get_bone_global_rest(sk.find_bone(names[3])).origin.y
	var r := {"crossings": 0, "below": true, "knee": [INF, -INF], "knee_wrong": 0, "elbow": [INF, -INF], "elbow_sum": 0.0,
		"elbow_wrong": 0, "frames": 0, "thigh_min": INF, "thigh_max": -INF, "ankle_low": [INF, INF], "ankles": [[], []]}
	var pos := holder.position
	var last_sign := 0.0
	var settle := 1.0
	var t := 0.0
	var fwd := Vector3.BACK
	while t < secs + settle:
		var vel := Vector3(0, 0, speed)
		pos += vel * DT
		holder.position = pos
		holder.rotation.y = toon_face          # the game turns its own node to the facing
		d.update(DT, vel, 0.0)
		await process_frame
		t += DT
		if t < settle:
			continue
		r.frames += 1
		var hips := _wpos(sk, names[0])
		var fl := _wpos(sk, names[3])
		var fr := _wpos(sk, names[6])
		if fl.y > hips.y - 0.15 or fr.y > hips.y - 0.15:
			r.below = false
		var s := signf((fl - fr).dot(fwd))
		if s != 0.0 and last_sign != 0.0 and s != last_sign:
			r.crossings += 1
		if s != 0.0:
			last_sign = s
		var q: Quaternion = sk.get_bone_pose_rotation(sk.find_bone(names[1]))
		var ang := q.get_euler().x
		r.thigh_min = minf(r.thigh_min, ang)
		r.thigh_max = maxf(r.thigh_max, ang)
		for side in 2:
			var o := side * 3
			var hip := _wpos(sk, names[1 + o])
			var knee := _wpos(sk, names[2 + o])
			var ankle := _wpos(sk, names[3 + o])
			var th := knee - hip
			var sh := ankle - knee
			var kd := rad_to_deg(th.angle_to(sh))
			r.knee[0] = minf(r.knee[0], kd)
			r.knee[1] = maxf(r.knee[1], kd)
			# A bent knee points forward: the knee in front of the hip-ankle line.
			if kd > 15.0:
				var line := ankle - hip
				var off := (knee - hip) - line.normalized() * (knee - hip).dot(line.normalized())
				if off.dot(fwd) < 0.0:
					r.knee_wrong += 1
			# The sole: a heel and a ball of the foot under the ankle (the foot bone's rest is upright, its front
			# the toon's).
			var fb := sk.global_transform * sk.get_bone_global_pose(sk.find_bone(names[3 + o]))
			var heel := fb * (Vector3(0, -ankle_rest, 0) + toon_fwd * -0.04)
			var ball := fb * (Vector3(0, -ankle_rest, 0) + toon_fwd * 0.12)
			(r.ankles[side] as Array).append([heel, ball])
			r.ankle_low[side] = minf(r.ankle_low[side], ankle.y)
			var sh_p := _wpos(sk, names[7 + o])
			var el := _wpos(sk, names[8 + o])
			var wr := _wpos(sk, names[9 + o])
			var u := el - sh_p
			var f := wr - el
			var ed := rad_to_deg(u.angle_to(f))
			r.elbow[0] = minf(r.elbow[0], ed)
			r.elbow[1] = maxf(r.elbow[1], ed)
			r.elbow_sum += ed
			# A bent elbow points back (the forearm comes forward of the upper arm), within WsgLegacyPose's range.
			if ed > 15.0 and absf(rad_to_deg(WsgLegacyPose.elbow_turn(u.normalized(), f.normalized()))) > WsgLegacyPose.TURN_MAX:
				r.elbow_wrong += 1
	# Slide: a heel or ball of the foot on the ground (within 2 cm of it, this frame and the last) must not move over it.
	var slides := []
	for side in 2:
		var a: Array = r.ankles[side]
		for i in range(1, a.size()):
			for k in 2:
				var p0: Vector3 = a[i - 1][k]
				var p1: Vector3 = a[i][k]
				if p0.y < 0.02 and p1.y < 0.02:
					slides.append(Vector2(p1.x - p0.x, p1.z - p0.z).length() / DT)
	slides.sort()
	r.slide_mean = 0.0
	for s in slides:
		r.slide_mean += s
	r.slide_mean = r.slide_mean / maxf(slides.size(), 1) * 100.0
	r.slide_p50 = (slides[slides.size() / 2] if not slides.is_empty() else 0.0) * 100.0
	r.touch = slides.size()
	r.cycles = r.crossings * 0.5 / secs
	r.elbow_mean = r.elbow_sum / maxf(r.frames * 2, 1)
	r.erase("ankles")
	return r


func _with_data() -> void:
	_check(WsgToonDriver.available(), "available() with the clip library")
	# --- Netball's toon.
	var t := _toon(NETBALL, false)
	var holder: Node3D = t[0]
	var sk: Skeleton3D = t[1]
	var d := WsgToonDriver.new(sk, {}, {"offset": 0})
	_check(d.loco != null and d.body.mesh_instance == null, "a hidden rig with no mesh")
	_check(not d.body.is_inside_tree(), "the hidden rig is not in the scene")
	var names := ["hips", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r", "upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r", "hand_r"]
	var ankle_rest: float = sk.get_bone_global_rest(sk.find_bone("foot_l")).origin.y
	var rest := sk.get_bone_pose_rotation(sk.find_bone("thigh_l"))
	print("speed   cycles/s  thigh swing  knee deg   elbow deg (mean)  ankle low cm  slide mean/p50 cm/s (frames down)")
	var cyc := []
	for spd in [1.5, 3.5, 6.0, 7.5]:
		var r: Dictionary = await _run(d, holder, sk, spd, 4.0, names, 0.0)
		cyc.append(r.cycles)
		print("%4.1f    %5.2f     %5.1f deg   %3.0f-%3.0f   %3.0f-%3.0f (%3.0f)    %+5.1f %+5.1f    %5.1f %5.1f (%d)" % [spd, r.cycles,
			rad_to_deg(r.thigh_max - r.thigh_min), r.knee[0], r.knee[1], r.elbow[0], r.elbow[1], r.elbow_mean,
			(r.ankle_low[0] - ankle_rest) * 100.0, (r.ankle_low[1] - ankle_rest) * 100.0, r.slide_mean, r.slide_p50, r.touch])
		_check(r.thigh_max - r.thigh_min > deg_to_rad(20.0), "%.1f m/s: the thigh swings (%.0f deg)" % [spd, rad_to_deg(r.thigh_max - r.thigh_min)])
		_check(r.below, "%.1f m/s: the feet stay under the hips" % spd)
		_check(r.knee[0] >= 0.0 and r.knee[1] <= WsgRig.KNEE_MAX and r.knee_wrong == 0,
			"%.1f m/s: knees in range and bending forward (%.0f-%.0f deg, %d frames the wrong way)" % [spd, r.knee[0], r.knee[1], r.knee_wrong])
		_check(r.elbow[1] <= WsgRig.ELBOW_MAX and r.elbow_wrong == 0,
			"%.1f m/s: elbows in range and bending the right way (%.0f-%.0f deg, %d frames the wrong way)" % [spd, r.elbow[0], r.elbow[1], r.elbow_wrong])
		_check(absf(r.ankle_low[0] - ankle_rest) < 0.06 and absf(r.ankle_low[1] - ankle_rest) < 0.06,
			"%.1f m/s: the feet come down to the ground (%+.1f, %+.1f cm)" % [spd, (r.ankle_low[0] - ankle_rest) * 100.0, (r.ankle_low[1] - ankle_rest) * 100.0])
		if spd >= 3.5:
			_check(r.elbow_mean > 40.0, "%.1f m/s: the arms are bent running (%.0f deg)" % [spd, r.elbow_mean])
		# (No planter: the clips' own stride matching. The sprint's feet cover a third less ground than its root, and
		# the toon's foot is rigid (no toes), so at a sprint its push-off pivots; only up to a run is it held to this.)
		if spd <= 6.0:
			_check(r.slide_p50 < 45.0, "%.1f m/s: a planted foot does not skate (%.1f cm/s at the median)" % [spd, r.slide_p50])
	for i in range(1, cyc.size()):
		_check(cyc[i] > cyc[i - 1], "the stride frequency rises with speed (%s)" % [cyc])
	_check(not sk.get_bone_pose_rotation(sk.find_bone("thigh_l")).is_equal_approx(rest), "the toon's bones are posed")
	# --- The game's pose wins: an override of 1 over the whole body leaves the game's pose as it was.
	var game := {}
	for i in sk.get_bone_count():
		var q := Quaternion(Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized(), randf() * 0.6)
		sk.set_bone_pose_rotation(i, q)
		game[i] = q
	var hp := sk.get_bone_pose_position(0) + Vector3(0, -0.07, 0)
	sk.set_bone_pose_position(0, hp)
	d.set_override(1.0)
	var fresh := d.update(DT, Vector3(0, 0, 4), 0.0)
	var same := not fresh
	for i in game:
		same = same and sk.get_bone_pose_rotation(i) == game[i]
	same = same and sk.get_bone_pose_position(0) == hp
	_check(same, "override 1 (the whole body): the game's pose untouched, nothing posed")
	# Arms only: the arms are the game's, the legs the capture's.
	d.set_override(1.0, WsgToonDriver.ARMS)
	for i in game:
		sk.set_bone_pose_rotation(i, game[i])
	d.update(DT, Vector3(0, 0, 4), 0.0)
	var arms_same := true
	for b in WsgToonDriver.ARMS:
		arms_same = arms_same and sk.get_bone_pose_rotation(sk.find_bone(b)) == game[sk.find_bone(b)]
	_check(arms_same, "override 1 on the arms: the game's arms untouched")
	_check(sk.get_bone_pose_rotation(sk.find_bone("thigh_l")) != game[sk.find_bone("thigh_l")], "override on the arms: the legs still the capture's")
	# Faded: halfway after half the fade.
	d.set_override(0.0, [], 0.2)
	d.update(0.1, Vector3(0, 0, 4), 0.0)
	_check(absf(d.override("upperarm_l") - 0.5) < 0.01 and d.override("thigh_l") == 0.0, "an override eases over its fade (%.2f)" % d.override("upperarm_l"))
	d.set_override(0.0)
	# pose(): the same pose as a dictionary; with auto_apply off the skeleton is left alone.
	d.auto_apply = false
	for i in game:
		sk.set_bone_pose_rotation(i, game[i])
	d.update(DT, Vector3(0, 0, 4), 0.0)
	var p := d.pose()
	_check(p.size() == 18 and p.has("@hips") and p.has("forearm_r"), "pose(): the 17 bones and the hips (%d keys)" % p.size())
	_check(sk.get_bone_pose_rotation(sk.find_bone("thigh_l")) == game[sk.find_bone("thigh_l")], "auto_apply off: update() leaves the skeleton to the game")
	d.apply(1.0)
	_check(sk.get_bone_pose_rotation(sk.find_bone("thigh_l")).is_equal_approx(p["thigh_l"]), "apply(): the pose() on the skeleton")
	d.auto_apply = true
	# Staggered: every 3rd update poses afresh, the others lay the last pose again.
	d.every = 3
	var n_fresh := 0
	for i in 9:
		if d.update(DT, Vector3(0, 0, 4), 0.0):
			n_fresh += 1
	_check(n_fresh == 3, "every = 3: posed on 3 of 9 updates (%d)" % n_fresh)
	d.every = 1
	d = null
	holder.free()
	# --- Kabaddi's rigged body: A-pose, legs apart, facing -Z, its own names; it must run forward, not backward.
	var k := _toon(KABADDI, true)
	var kh: Node3D = k[0]
	var ks: Skeleton3D = k[1]
	var kd := WsgToonDriver.new(ks, KABADDI_MAP, {"face": PI})
	var kn := ["pelvis", "hip_l", "kn_l", "an_l", "hip_r", "kn_r", "an_r", "sh_l", "el_l", "wr_l", "sh_r", "el_r", "wr_r"]
	var ka: float = ks.get_bone_global_rest(ks.find_bone("an_l")).origin.y
	var kr: Dictionary = await _run(kd, kh, ks, 3.5, 3.0, kn, PI, Vector3.FORWARD)
	print("Kabaddi-like toon at 3.5 m/s: %.2f cycles/s, knee %.0f-%.0f, elbow %.0f-%.0f (%.0f), ankle low %+.1f %+.1f cm, slide %.1f/%.1f cm/s" % [kr.cycles,
		kr.knee[0], kr.knee[1], kr.elbow[0], kr.elbow[1], kr.elbow_mean, (kr.ankle_low[0] - ka) * 100.0, (kr.ankle_low[1] - ka) * 100.0, kr.slide_mean, kr.slide_p50])
	_check(kr.below and kr.knee_wrong == 0 and kr.elbow_wrong == 0 and kr.knee[1] <= WsgRig.KNEE_MAX,
		"Kabaddi-like toon: feet under the hips, knees and elbows the right way (%d, %d frames wrong)" % [kr.knee_wrong, kr.elbow_wrong])
	_check(absf(kr.ankle_low[0] - ka) < 0.06 and absf(kr.ankle_low[1] - ka) < 0.06, "Kabaddi-like toon: the feet come down to the ground")
	# Its legs straight under it, not splayed as at its rest: the ankles about a hip's width apart.
	var gap := absf((_wpos(ks, "an_l") - _wpos(ks, "an_r")).x)
	_check(gap < 0.4, "Kabaddi-like toon: the A-pose's splayed legs brought under the body (ankles %.2f m apart)" % gap)
	# The left hand on the body's left (-X of its own frame, +X in the world as it faces +Z).
	_check(_wpos(ks, "wr_l").x > _wpos(ks, "pelvis").x, "Kabaddi-like toon: faces the way it runs (its left hand on its left)")
	_check(kd.skeleton.get_bone_pose_rotation(ks.find_bone("fingers_l")) == Quaternion.IDENTITY, "Kabaddi-like toon: bones the driver does not know are left alone")
	kd = null
	kh.free()
	# --- CPU: 14 bodies (a netball match), update() each frame, every frame and staggered.
	var drivers := []
	var holders := []
	for i in 14:
		var tt := _toon(NETBALL, false)
		holders.append(tt[0])
		drivers.append(WsgToonDriver.new(tt[1]))
	for every in [1, 2, 3]:
		for dd: WsgToonDriver in drivers:
			dd.every = every
		for f in 30:
			for dd: WsgToonDriver in drivers:
				dd.update(DT, Vector3(0, 0, 5), 0.0)
		var t0 := Time.get_ticks_usec()
		var frames := 90
		for f in frames:
			for i in drivers.size():
				var spd := 3.0 + 3.0 * sin(f * 0.05 + i)
				(drivers[i] as WsgToonDriver).update(DT, Vector3(sin(i) * spd, 0, cos(i) * spd), i)
		var us := float(Time.get_ticks_usec() - t0) / frames
		print("CPU, 14 bodies, posed every %d: %.2f ms a frame (%.3f ms a body)" % [every, us / 1000.0, us / 1000.0 / 14.0])
		if every == 1:
			_check(us / 14.0 < 600.0, "CPU: under 0.6 ms a body even on a slow CI machine (%.3f ms)" % [us / 14000.0])
	drivers.clear()
	for h in holders:
		h.free()


## The feet rule (WsgNoteChecks.foot_slip) on a toon walking, jogging and running (1.5, 3.5, 6 m/s, 2.5 s each), with
## the driver's plant (a foot down held where it landed) and without: the clip's feet slid under the toon's own body -
## Pok Ta Pok's Low players 7-15 cm a step. [planted slide, flat skid, low-foot jump] in cm.
func _feet_rule(plant: bool) -> Array:
	var t := _toon(NETBALL, false)
	var holder: Node3D = t[0]
	var sk: Skeleton3D = t[1]
	var d := WsgToonDriver.new(sk, {}, {"offset": 0, "plant": plant})
	var frames := []
	var pos := holder.position
	# (A second's settle first, from the toon's rest into the clip, as _run does: not measured.)
	for spd in [0.0, 1.5, 3.5, 6.0]:
		for k in roundi((1.0 if spd == 0.0 else 2.5) / DT):
			var vel := Vector3(0, 0, spd)
			pos += vel * DT
			holder.position = pos
			d.update(DT, vel, 0.0)
			await process_frame
			if spd == 0.0:
				continue
			var fl := _wpos(sk, "foot_l")
			var fr := _wpos(sk, "foot_r")
			frames.append([fl, fl, fr, fr])
	holder.queue_free()
	var r := WsgNoteChecks.foot_slip(frames)
	print("  (plant %s: slide at %s, skid at %s, jump at %s; %d frames a phase)" % [plant, r.max_at, r.skid_at, r.jump_at, roundi(2.5 / DT)])
	return [float(r.max_cm), float(r.skid_cm), float(r.jump_cm)]


## Without the library: available() is false, a driver does nothing, the game's pose stays as it was.
func _without_data() -> void:
	var lib = WsgClips._lib
	var tried: bool = WsgClips._tried
	WsgClips._lib = null
	WsgClips._tried = true
	_check(not WsgToonDriver.available(), "available() false without the clip library")
	var t := _toon(NETBALL, false)
	var sk: Skeleton3D = t[1]
	var q := Quaternion(Vector3.RIGHT, 0.4)
	sk.set_bone_pose_rotation(sk.find_bone("thigh_l"), q)
	var d := WsgToonDriver.new(sk)
	var posed := false
	for i in 10:
		posed = d.update(DT, Vector3(0, 0, 4), 0.0) or posed
	d.set_override(1.0, WsgToonDriver.ARMS, 0.2)
	d.apply(1.0)
	_check(not posed and d.loco == null and d.body == null and d.pose().is_empty(), "without the library: update() is a no-op")
	_check(sk.get_bone_pose_rotation(sk.find_bone("thigh_l")) == q, "without the library: the game's pose untouched")
	(t[0] as Node).free()
	WsgClips._lib = lib
	WsgClips._tried = tried
