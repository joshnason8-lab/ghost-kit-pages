extends SceneTree
## WsgFootPlanter back on after a while off, and its own steps:
##  - a planter not run while the game poses the body (inactive, the body moved 1.5 m under it), back on - with the
##    game's reset() or without - plants the feet where they are drawn now: not where it last drew them, far behind, and
##    let go to slide after the body (Sepak Takraw's players out of a set piece: 7 cm);
##  - a body carried on faster than its clip's stride: the feet the planter lets go at their reach take steps of their
##    own, and a step's toe stays over the floor until it lands - not skimming it, read as a planted foot sliding
##    (Sepak Takraw: 3.6 cm) - and the feet rule (WsgNoteChecks.foot_slip) passes (12.3 cm flat skid before);
##  - a far body, drawn (its planter run) every 3rd frame, coming down while going on at 0.64 m/s: planted on the first
##    draw within the touch (4 cm), its speed read over the 3 frames' ticks - read over one, 3 times as fast, it was
##    planted a draw late, 6.4 cm on, read as a planted slide (Kabaddi's far players).
##  - a body standing still, its clip's foot hovering 3.5 cm up and drifting at 0.85 m/s (an idle's settle: the ankle
##    faster than a stance foot's, the toe slow): planted - not left to drift under the feet rule's 3 cm touch (Kho Kho's
##    referee, extreme#28: 9.2 cm); and on a body scaled 0.95 at 2.9 cm (under the rule's unscaled 3 cm: 3.2 cm).
## Every case twice: on the rig in metres, and on the same rig in centimetres under a 0.01 node (Sepak Takraw's RealBody:
## its skeleton's world scale 0.0101 shrank every metre tolerance 100 times) - each must pass the same.
##   godot --headless --fixed-fps 30 --path . -s tests/planter_restart_test.gd

var fails := []


var _cm := false                 # the rig in centimetres under a 0.01 node
var _tag := ""


func _initialize() -> void:
	await process_frame
	var hero := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
	root.add_child(hero)
	await process_frame
	for cm in [false, true]:
		_cm = cm
		_tag = "[cm rig] " if cm else ""
		var before := fails.size()
		await _cases(hero)
		for k in range(before, fails.size()):
			fails[k] = _tag + String(fails[k])
	hero.queue_free()
	print("PLANTER RESTART TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)


func _cases(hero: WsgBody) -> void:
	for with_reset in [false, true]:
		var r: Array = await _restart(hero.skeleton, with_reset)
		var what := "back on%s" % (" (reset)" if with_reset else "")
		print(_tag + "%s: contact %s (a foot up on %d of 6 frames); the left ankle %.1f cm from under the body; moved at most %.1f cm a frame after" % [what, r[0], r[3], r[1] * 100.0, r[2] * 100.0])
		if float(r[0][0]) < 0.5 or float(r[0][1]) < 0.5 or int(r[3]) > 0:
			fails.append("%s: a standing foot not planted (contact %s at the end; a foot up on %d of 6 frames)" % [what, r[0], r[3]])
		if float(r[1]) > 0.03:
			fails.append("%s: the left ankle drawn %.1f cm from under the body (where it was before, 1.5 m behind)" % [what, float(r[1]) * 100.0])
		if float(r[2]) > 0.01:
			fails.append("%s: a planted ankle moved %.1f cm in a frame" % [what, float(r[2]) * 100.0])
	var s: Array = await _carried(hero.skeleton)
	print(_tag + "carried: %d steps; the lowest a stepping toe went over the floor %.1f cm; slid %.1f cm, skid %.1f cm" % [s[0], s[1] * 100.0, s[2].max_cm, s[2].skid_cm])
	if int(s[0]) == 0:
		fails.append("carried: no steps taken (the case does not test them)")
	if float(s[1]) < 0.03:
		fails.append("carried: a stepping toe %.1f cm over the floor before it landed (3.0 at least)" % (float(s[1]) * 100.0))
	if float(s[2].max_cm) > 2.0:
		fails.append("carried: a planted foot slid %.1f cm in a step (2.0 at most)" % float(s[2].max_cm))
	if float(s[2].skid_cm) > 2.0:
		fails.append("carried: a foot flat on the ground slid %.1f cm in one frame (2.0 at most)" % float(s[2].skid_cm))
	# The knees bend forward, whichever way the rig's thigh bones face (Sepak Takraw's Mixamo RealBody: the thigh's +Z
	# points back; taken for forward, every bent knee was flipped behind - the owner's "broken backwards knees").
	for back in [false, true]:
		var kn: Array = await _knees(hero.skeleton, back)
		var rig := "thigh +Z backward" if back else "thigh +Z forward"
		print(_tag + "crouching, the feet held (%s): the knees %.1f and %.1f cm in front of the hip-ankle line (forward of the feet)" % [rig, float(kn[0]) * 100.0, float(kn[1]) * 100.0])
		if float(kn[0]) < 0.01 or float(kn[1]) < 0.01:
			fails.append("crouching (%s): a knee %.1f cm in front of the hip-ankle line - bent backwards (1.0 at least)" % [rig, minf(float(kn[0]), float(kn[1])) * 100.0])
	var far: float = await _landing_far(hero.skeleton)
	print(_tag + "landing, drawn every 3rd frame: planted with the ankle %.1f cm over its standing height (the first draw within the touch, 4 cm: 3.4-4.4)" % (far * 100.0))
	if far < 0.02:
		fails.append("landing, drawn every 3rd frame: planted with the ankle %.1f cm up - a draw late, 6.4 cm on (the first draw within the touch, 4 cm: 3.4-4.4)" % (far * 100.0))
	for c in [[1.0, 0.035], [0.95, 0.029]]:
		var hv: Array = await _hover_still(hero.skeleton, float(c[0]), float(c[1]))
		print(_tag + "standing, scale %.2f, a foot hovering %.1f cm up and drifting: planted %s, moved %.1f cm once planted" % [c[0], float(c[1]) * 100.0, hv[0], float(hv[1]) * 100.0])
		if not bool(hv[0]):
			fails.append("standing, scale %.2f: a foot hovering %.1f cm up, drifting at 0.85 m/s, never planted (it slides under the feet rule's 3 cm touch)" % [c[0], float(c[1]) * 100.0])
		elif float(hv[1]) > 0.02:
			fails.append("standing, scale %.2f: the hovering foot moved %.1f cm once planted (2.0 at most)" % [c[0], float(hv[1]) * 100.0])


## A copy of SRC's skeleton at rest, a planter under it.
func _rig(src: Skeleton3D, thigh_z_back := false) -> Array:
	var own := Skeleton3D.new()
	for i in src.get_bone_count():
		own.add_bone(src.get_bone_name(i))
	var half := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	for i in src.get_bone_count():
		var rest := src.get_bone_rest(i)
		if thigh_z_back:
			# (The thigh turned half round its own length - its +Z pointing back, as on a Mixamo RealBody - and the shin
			# turned back again, so every bone stands where it stood.)
			if src.get_bone_name(i).ends_with("UpLeg"):
				rest = rest * half
			elif src.get_bone_parent(i) >= 0 and src.get_bone_name(src.get_bone_parent(i)).ends_with("UpLeg"):
				rest = half * rest
		if _cm:
			rest.origin *= 100.0
		own.set_bone_parent(i, src.get_bone_parent(i))
		own.set_bone_rest(i, rest)
		own.set_bone_pose_position(i, rest.origin)
		own.set_bone_pose_rotation(i, rest.basis.get_rotation_quaternion())
	var holder := Node3D.new()
	root.add_child(holder)
	if _cm:
		var unit := Node3D.new()
		unit.scale = Vector3.ONE * 0.01
		holder.add_child(unit)
		unit.add_child(own)
	else:
		holder.add_child(own)
	var pl := WsgFootPlanter.new()
	own.add_child(pl)
	pl.ground_y = 0.0     # (the rest pose stands on y 0)
	return [holder, own, pl]


## Standing 6 frames, the planter off (not run - as a game posing the body whole turns it) while the body goes 1.5 m
## over 10 frames, then on (with the game's reset() if WITH_RESET) for 6 more: [contact, how far the left ankle is drawn
## from under the body at the end, the most it moved a frame once planted again].
func _restart(src: Skeleton3D, with_reset: bool) -> Array:
	var r := _rig(src)
	var holder: Node3D = r[0]
	var own: Skeleton3D = r[1]
	var pl: WsgFootPlanter = r[2]
	var ankle := own.find_bone("LeftFoot")
	var drawn := []
	own.skeleton_updated.connect(func(): drawn.append(own.global_transform * own.get_bone_global_pose(ankle).origin))
	for f in 6:
		pl.tick(1.0 / 30.0)
		await process_frame
	pl.active = false
	for f in 10:
		holder.position.x += 0.15
		await process_frame
	if with_reset:
		pl.reset()
	pl.active = true
	var from := drawn.size()
	var dropped := 0
	for f in 6:
		pl.tick(1.0 / 30.0)
		await process_frame
		if float(pl.contact[0]) < 0.5 or float(pl.contact[1]) < 0.5:
			dropped += 1
	var under := own.global_transform * own.get_bone_global_rest(ankle).origin
	var last: Vector3 = drawn[-1]
	var most := 0.0
	for k in range(from + 2, drawn.size()):
		var a: Vector3 = drawn[k - 1]
		var b: Vector3 = drawn[k]
		most = maxf(most, Vector2(b.x - a.x, b.z - a.z).length())
	var out := [pl.contact.duplicate(), Vector2(last.x - under.x, last.z - under.z).length(), most, dropped]
	holder.queue_free()
	return out


## Standing, then carried on at 2.5 m/s for 2 s, on tiptoe (a clip whose feet never leave the ground, pitched toe-down:
## a step lifting the ankle alone drags the toe) under the planter: [steps taken, the lowest a stepping toe went over the floor before landing, the feet rule's reading].
func _carried(src: Skeleton3D) -> Array:
	var r := _rig(src)
	var holder: Node3D = r[0]
	var own: Skeleton3D = r[1]
	var pl: WsgFootPlanter = r[2]
	_tiptoe(own, 0.03)
	var bones := ["LeftFoot", "LeftToeBase", "RightFoot", "RightToeBase"].map(func(n): return own.find_bone(n))
	var frames := []
	var steps := [0]
	var lowest := [INF]
	var stepping := [false, false]
	var toe_floor := 0.0
	own.skeleton_updated.connect(func():
		var f := []
		for b in bones:
			f.append(own.global_transform * own.get_bone_global_pose(b).origin)
		frames.append(f)
		for i in 2:
			var st := float(pl._step[i])
			if st >= 0.25 and st < 1.0:
				lowest[0] = minf(lowest[0], (f[i * 2 + 1] as Vector3).y - toe_floor)
			if st >= 0.0 and not stepping[i]:
				steps[0] += 1
			stepping[i] = st >= 0.0)
	for f in 6:
		pl.tick(1.0 / 30.0)
		await process_frame
	toe_floor = minf((frames[-1][1] as Vector3).y, (frames[-1][3] as Vector3).y)
	frames.clear()
	pl.body_speed = 2.5
	for f in 60:
		# (Game time at 0.7 of the frame's - a game's pace, as Sepak Takraw's: the step's last tick before it lands
		# then comes nearer the ground.)
		holder.position.x += 2.5 * 0.7 / 30.0
		pl.tick(0.7 / 30.0)
		await process_frame
	var rule := WsgNoteChecks.foot_slip(frames)
	holder.queue_free()
	return [steps[0], lowest[0], rule]


## The body standing, then lowered 8 cm while the planter holds its feet on the floor (the knees must bend): how far each
## knee is drawn in front of the line from its hip to its ankle, along the foot's way (heel to toe).
func _knees(src: Skeleton3D, thigh_z_back: bool) -> Array:
	var r := _rig(src, thigh_z_back)
	var holder: Node3D = r[0]
	var own: Skeleton3D = r[1]
	var pl: WsgFootPlanter = r[2]
	var out := [0.0, 0.0]
	# (Read as drawn, the planter's legs on: in the skeleton's update.)
	own.skeleton_updated.connect(func():
		for k in 2:
			var side: String = ["Left", "Right"][k]
			var g := func(n: String) -> Vector3: return own.global_transform * own.get_bone_global_pose(own.find_bone(side + n)).origin
			var hip: Vector3 = g.call("UpLeg")
			var knee: Vector3 = g.call("Leg")
			var ank: Vector3 = g.call("Foot")
			var fwd: Vector3 = g.call("ToeBase") - ank
			fwd.y = 0.0
			var line := (ank - hip).normalized()
			var off := (knee - hip) - line * (knee - hip).dot(line)
			out[k] = off.dot(fwd.normalized()))
	for f in 6:
		pl.tick(1.0 / 30.0)
		await process_frame
	for f in 10:
		holder.position.y -= 0.008
		pl.tick(1.0 / 30.0)
		await process_frame
	holder.queue_free()
	return out


## The clip's pose on tiptoe: the hips up RISE, each foot pitched toe-down until its toe is back where it stood.
func _tiptoe(own: Skeleton3D, rise: float) -> void:
	var hips := own.find_bone("Hips")
	own.set_bone_pose_position(hips, own.get_bone_pose_position(hips) + Vector3(0, rise * (100.0 if _cm else 1.0), 0))
	for side in ["Left", "Right"]:
		var foot := own.find_bone(side + "Foot")
		var toe := own.find_bone(side + "ToeBase")
		var want := own.get_bone_global_rest(toe).origin.y
		var ank := own.get_bone_global_pose(foot).origin
		var v := own.get_bone_global_pose(toe).origin - ank
		var axis := v.cross(Vector3.UP).normalized()
		var g := own.get_bone_global_pose(foot).basis
		var parent := own.get_bone_global_pose(own.get_bone_parent(foot)).basis
		var best := 0.0
		for k in 46:
			var a := deg_to_rad(float(k))
			if absf(ank.y + v.rotated(axis, -a).y - want) < absf(ank.y + v.rotated(axis, -best).y - want):
				best = a
		own.set_bone_pose_rotation(foot, (parent.inverse() * Basis(axis, -best) * g).get_rotation_quaternion())


## Both feet coming down 0.3 cm a frame from 6 cm up while the body goes on at 0.64 m/s: the planter ticked every
## frame but run (and the pose read) only every 3rd, as a far body is drawn. How high the left ankle was over its height
## standing on the floor when first planted.
func _landing_far(src: Skeleton3D) -> float:
	var r := _rig(src)
	var holder: Node3D = r[0]
	var own: Skeleton3D = r[1]
	var pl: WsgFootPlanter = r[2]
	var ankle := own.find_bone("LeftFoot")
	var standing := (own.global_transform * own.get_bone_global_rest(ankle).origin).y   # (the rest pose stands on y 0)
	var planted_at := [INF]
	own.skeleton_updated.connect(func():
		if pl.active and float(pl.contact[0]) > 0.5 and planted_at[0] == INF:
			planted_at[0] = (own.global_transform * own.get_bone_global_pose(ankle).origin).y)
	holder.position.y = 0.06
	for k in 45:
		pl.active = k % 3 == 0
		pl.body_speed = 0.64
		holder.position.x += 0.64 / 30.0
		holder.position.y = maxf(0.0, holder.position.y - 0.003)
		pl.tick(1.0 / 30.0)
		await process_frame
	holder.queue_free()
	return float(planted_at[0]) - standing


## A body standing (body_speed 0) at SCALE, the whole pose drifting 0.85 m/s across, its feet 10 cm up and then held UP
## over where they stand (the clip's idle: both feet just off the floor): [the left foot planted within 6 frames of
## coming down, how far its ankle was drawn to move from then on].
func _hover_still(src: Skeleton3D, scale: float, up: float) -> Array:
	var r := _rig(src)
	var holder: Node3D = r[0]
	var own: Skeleton3D = r[1]
	var pl: WsgFootPlanter = r[2]
	holder.scale = Vector3.ONE * scale
	var ankle := own.find_bone("LeftFoot")
	var drawn := []
	var planted_at := [-1]
	own.skeleton_updated.connect(func():
		drawn.append(own.global_transform * own.get_bone_global_pose(ankle).origin)
		if planted_at[0] < 0 and float(pl.contact[0]) > 0.5:
			planted_at[0] = drawn.size() - 1)
	# (Drifting 10 cm up first - its speed already read - then down to UP: no earlier frame reads it still.)
	holder.position.y = 0.10
	pl.body_speed = 0.0
	for f in 16:
		if f == 4:
			holder.position.y = up
			planted_at[0] = -1
			drawn.clear()
		holder.position.x += 0.85 / 30.0
		pl.tick(1.0 / 30.0)
		await process_frame
	var most := 0.0
	if planted_at[0] >= 0:
		for k in range(planted_at[0] + 1, drawn.size()):
			var a: Vector3 = drawn[k - 1]
			var b: Vector3 = drawn[k]
			most = maxf(most, Vector2(b.x - a.x, b.z - a.z).length())
	var out := [planted_at[0] >= 0 and planted_at[0] < 6, most]
	holder.queue_free()
	return out
