extends SceneTree
## The planter on a fast sidestep: the test hurler standing, then going at 2 m/s 74 degrees off the way he faces (an
## official shuffling across, still facing the play) and stopping, still facing the same way - the feet rule
## (WsgNoteChecks.foot_slip) on every frame as drawn: planted slides, flat skids and low-foot jumps within its bounds.
## Real officials turn and jog above a slow sidestep (the lead, 2026-11-04: Kabaddi caps theirs at 1 m/s), but the
## planter must hold its feet on its own merits: Kabaddi's referee, side-on at 2 m/s, slid 14.9 cm in a step.
##   godot --headless --fixed-fps 30 --path . -s tests/sidestep_test.gd

const PATH := [[1.0, Vector2.ZERO, 0.0, "standing"],
	[2.0, Vector2(sin(deg_to_rad(74.0)), cos(deg_to_rad(74.0))) * 2.0, 0.0, "sidestep 2 m/s at 74"],
	[1.5, Vector2.ZERO, 0.0, "stop"],
	[2.0, Vector2(sin(deg_to_rad(-74.0)), cos(deg_to_rad(-74.0))) * 2.0, 0.0, "sidestep back"],
	[1.5, Vector2.ZERO, 0.0, "stop again"]]

const FADE := 0.22
var fails := []


## A game's own pose over the capture (its layer before the planter): standing, at WEIGHT.
class GamePose extends SkeletonModifier3D:
	var weight := 0.0

	func _process_modification_with_delta(_d: float) -> void:
		var sk := get_skeleton()
		if sk == null or weight <= 0.0:
			return
		for b in sk.get_bone_count():
			var rest := sk.get_bone_rest(b)
			sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b).slerp(rest.basis.get_rotation_quaternion(), weight))
			sk.set_bone_pose_position(b, sk.get_bone_pose_position(b).lerp(rest.origin, weight))


func _initialize() -> void:
	await process_frame
	if not FileAccess.file_exists("res://addons/wsg_foundation/data/mobility.res"):
		print("SIDESTEP TEST: SKIPPED (no licensed clip library)")
		quit(0)
		return
	var body := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
	root.add_child(body)
	var loco := WsgLocomotor.attach(body)
	await process_frame
	for every in [1, 3]:
		var r: Array = await _run(body, loco, every, 0)
		_check(r, "every %d" % every)
	# Handed back mid-sidestep: the game's whole pose (a signal: standing, carried by the body) over the first 0.3 s of
	# the sidestep, then faded out over 0.22 s under the capture as the games' links do (FADE), the planter on again at
	# once with the body already at 1.3 m/s side-on - Kabaddi's referee out of his signal into the shuffle (14.9 cm).
	var layer := GamePose.new()
	body.skeleton.add_child(layer)
	body.skeleton.move_child(layer, 0)
	for every in [1, 3]:
		var r: Array = await _run(body, loco, every, roundi(1.3 / WsgWorldRules.DT), layer)
		_check(r, "every %d, handed back at speed" % every)
	body.queue_free()
	print("SIDESTEP TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)


## The path driven as a game drives a body posed every EVERY frames (a far official: Kabaddi's link drives the
## locomotor once every 2nd or 3rd frame with the time since), the feet read on the frames it is posed.
## Under the game's own whole pose (keep_pose; its feet not read) until frame POSE_UNTIL. [frames, held, segments, gaps].
func _run(body: WsgBody, loco: WsgLocomotor, every: int, pose_until: int, layer: GamePose = null) -> Array:
	loco.planter.reset()
	var frames := []
	var held := []
	var segs := []
	var gaps := PackedInt32Array()
	var vel := Vector2.ZERO
	var pos := body.position
	var n := 0
	var acc := 0.0
	for si in PATH.size():
		var seg: Array = PATH[si]
		for k in roundi(float(seg[0]) / WsgWorldRules.DT):
			var want: Vector2 = seg[1]
			var lim := (WsgWorldRules.ACCEL if want.length() > vel.length() else WsgWorldRules.DECEL) * WsgWorldRules.DT
			vel = vel.move_toward(want, lim)
			pos += Vector3(vel.x, 0, vel.y) * WsgWorldRules.DT
			body.position = pos
			acc += WsgWorldRules.DT
			n += 1
			if n % every == 0:
				loco.planter.keep_pose = n <= pose_until
				if layer:
					# (The game's pose: whole until handed back, then fading out over FADE; the planter reset at the hand-back.)
					if n <= pose_until:
						layer.weight = 1.0
					else:
						if layer.weight >= 1.0:
							loco.planter.reset()
						layer.weight = maxf(0.0, layer.weight - acc / FADE)
				loco.drive(acc, Vector3(vel.x, 0, vel.y), deg_to_rad(float(seg[2])), Vector3(want.x, 0, want.y))
				acc = 0.0
				await body.skeleton.skeleton_updated
				if loco.planter.keep_pose:
					await process_frame
					continue
				frames.append(WsgNoteChecks.feet(body))
				held.append([loco.planter.holding(0), loco.planter.holding(1)])
				segs.append(si)
				gaps.append(every)
			await process_frame
	return [frames, held, segs, gaps]


func _check(rr: Array, label: String) -> void:
	var frames: Array = rr[0]
	var held: Array = rr[1]
	var segs: Array = rr[2]
	var gaps: PackedInt32Array = rr[3]
	var every: int = rr[3][0] if (rr[3] as PackedInt32Array).size() > 0 else 1
	print(label + ":")
	# Each segment on its own (and the whole), so a failure names the move.
	for si in PATH.size():
		var run := []
		var hr := []
		for k in frames.size():
			if int(segs[k]) == si or (k + 1 < frames.size() and int(segs[k + 1]) == si):
				run.append(frames[k])
				hr.append(held[k])
		var gr := PackedInt32Array()
		gr.resize(run.size())
		gr.fill(every)
		var r := WsgNoteChecks.foot_slip(run, 0.0, 0.0, 0.0, gr, hr)
		print("  %-22s slide %.1f cm, skid %.1f cm, jump %.1f cm" % [PATH[si][3], r.max_cm, r.skid_cm, r.jump_cm])
	var all := WsgNoteChecks.foot_slip(frames, 0.0, 0.0, 0.0, gaps, held)
	var what := label + ": "
	print("all: slide %.1f cm (frames %s), skid %.1f cm, jump %.1f cm" % [all.max_cm, all.max_at, all.skid_cm, all.jump_cm])
	if float(all.max_cm) > 2.0:
		fails.append(what + "a planted foot slid %.1f cm in a step (2.0 at most; %s)" % [all.max_cm, all.max_at])
	if float(all.skid_cm) > 2.0:
		fails.append(what + "a foot flat on the ground slid %.1f cm in one frame (2.0 at most; %s)" % [all.skid_cm, all.skid_at])
	if float(all.jump_cm) > WsgWorldRules.JUMP_MAX_CM:
		fails.append(what + "a low foot jumped %.1f cm in one frame (%.0f at most; %s)" % [all.jump_cm, WsgWorldRules.JUMP_MAX_CM, all.jump_at])
