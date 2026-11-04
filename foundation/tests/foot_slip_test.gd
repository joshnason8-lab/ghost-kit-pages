extends SceneTree
## Pins the feet measure (WsgNoteChecks.foot_slip: a planted foot's slide, summed frame by frame as the least its
## ankle or toe moved that frame), so it can neither go blind to real slides nor read a rolling foot as one:
## - a pure heel-to-toe roll (the ankle still while the toe comes down, then the toe still while the heel lifts)
##   reads under 0.5 cm (the measure before 2026-11-04 summed the two halves: 2-3 cm of slide that was not there);
## - a planted foot pushed 3 cm along the ground reads 3 cm or more, wherever in the step the push comes;
## - the hurler walking with the planter off (the clips' own feet, which do slide) reads 5 cm or more at every
##   speed, driven every frame as the world check drives a game's walker;
## - a foot flat on the floor that slides in a frame (a landing snapped back) reads as a skid, a swing skimming the
##   grass with its heel up does not;
## - a body posed every 3rd frame (FoundationLink.pose_every 3, far bodies) is read per frame: a flat foot creeping
##   0.9 cm a frame is no skid (it read 2.7 cm "in one frame", Kabaddi's officials), one sliding 3 cm a frame is; a
##   stride's swing read every 3rd frame jumps as it does read every frame.
##   godot --headless --fixed-fps 30 --path . -s tests/foot_slip_test.gd

const L := 0.15            # ankle to toe along the ground
const ANKLE_Y := 0.08      # the ankle's height standing
const WALK_SPEEDS := [1.3, 1.8, 2.2, 3.0]

var fails := []


## One step of the left foot, [ankle, toe, ankle, toe] a frame (the right foot stands still, far off: a second step,
## of nothing), PUSH metres
## along +x spread over the frames of PHASE ("flat": both ends down; "heel": the heel lifting about the toe;
## "strike": the toe coming down about the heel; "": none).
static func step(push: float, phase: String) -> Array:
	var frames := []
	var x := 0.0          # where the heel stands (the ankle's ground point)
	var right_a := Vector3(0, ANKLE_Y, 0.4)
	var right_t := right_a + Vector3(L, -ANKLE_Y, 0)
	var add := func(a: Vector3, t: Vector3) -> void:
		frames.append([a, t, right_a, right_t])
	# Swinging in: high and fast.
	for k in 6:
		var sx := -0.6 + k * 0.1
		add.call(Vector3(sx, ANKLE_Y + 0.12, 0), Vector3(sx + L * cos(0.5), ANKLE_Y + 0.12 + L * sin(0.5) - ANKLE_Y, 0))
	# Heel strike: the ankle down, the toe turning down about it (30 degrees to flat) over 6 frames.
	var n_strike := 6
	# (The frame it touches in is its arrival - the measure cannot tell the last of a swing from a push - so a push
	# while the toe comes down starts the frame after: it is counted from the first frame the foot is down.)
	for k in n_strike + 1:
		if phase == "strike" and k > 1:
			x += push / (n_strike - 1)
		var th := deg_to_rad(30.0) * (1.0 - float(k) / n_strike)
		add.call(Vector3(x, ANKLE_Y, 0), Vector3(x + L * cos(th), L * sin(th), 0))
	# Flat: 10 frames.
	var n_flat := 10
	for k in n_flat:
		if phase == "flat":
			x += push / n_flat
		add.call(Vector3(x, ANKLE_Y, 0), Vector3(x + L, 0, 0))
	# Heel off: the toe down, the ankle turning up about it (to 40 degrees) over 8 frames.
	var n_heel := 8
	var toe := x + L
	for k in range(1, n_heel + 1):
		if phase == "heel":
			toe += push / n_heel
		var ph := deg_to_rad(40.0) * float(k) / n_heel
		add.call(Vector3(toe - L * cos(ph), ANKLE_Y + L * sin(ph), 0), Vector3(toe, 0, 0))
	# Toe off: up and away, fast.
	for k in range(1, 6):
		var ph := deg_to_rad(40.0)
		add.call(Vector3(toe - L * cos(ph) + k * 0.1, ANKLE_Y + L * sin(ph) + k * 0.03, 0), Vector3(toe + k * 0.1, k * 0.04, 0))
	return frames


## A foot coming down flat and fast and snapped back by the clip as it lands (a hard stop from a run: 23 cm a frame
## flat on the floor, then 7 cm back), and a walk's swing whose toe skims the grass (1.5 cm up, 10 cm a frame) with its
## heel well up. [ankle, toe, ankle, toe] a frame, the right foot standing still.
static func landing(snap: bool) -> Array:
	var frames := []
	var right_a := Vector3(0, ANKLE_Y, 0.4)
	var right_t := right_a + Vector3(L, -ANKLE_Y, 0)
	if snap:
		for x in [-0.9, -0.6, -0.37, -0.14]:   # high, coming down
			frames.append([Vector3(x, ANKLE_Y + 0.15, 0), Vector3(x + L, 0.12, 0), right_a, right_t])
		for x in [0.09, 0.32, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25]:   # flat on the floor: 23 cm, 23 cm, 7 cm back, still
			frames.append([Vector3(x, ANKLE_Y + 0.005, 0), Vector3(x + L, 0.003, 0), right_a, right_t])
	else:
		for k in 12:
			var x := -0.6 + k * 0.1
			frames.append([Vector3(x, ANKLE_Y + 0.08, 0), Vector3(x + L, 0.015, 0), right_a, right_t])
		for k in 8:
			frames.append([Vector3(0.6, ANKLE_Y, 0), Vector3(0.6 + L, 0, 0), right_a, right_t])
	return frames


## A flat foot moving PER_FRAME metres a frame along x for 30 frames, read every EVERY frames: [frames, gaps].
static func creep(per_frame: float, every: int) -> Array:
	var frames := []
	var gaps := PackedInt32Array()
	var right_a := Vector3(0, ANKLE_Y, 0.4)
	var right_t := right_a + Vector3(L, -ANKLE_Y, 0)
	for k in range(0, 30, every):
		var x := k * per_frame
		frames.append([Vector3(x, ANKLE_Y, 0), Vector3(x + L, 0, 0), right_a, right_t])
		gaps.append(every)
	return [frames, gaps]


## A low swing (a foot within 10 cm of the ground, its move easing up and down: a stride's), read every EVERY frames.
static func low_swing(every: int) -> Array:
	var frames := []
	var gaps := PackedInt32Array()
	var right_a := Vector3(0, ANKLE_Y, 0.4)
	var right_t := right_a + Vector3(L, -ANKLE_Y, 0)
	for k in range(0, 36, every):
		var x := 0.6 * (1.0 - cos(PI * k / 35.0))   # 1.2 m over 35 frames, 0 to 5 cm a frame and back
		frames.append([Vector3(x, ANKLE_Y + 0.03, 0), Vector3(x + L, 0.03, 0), right_a, right_t])
		gaps.append(every)
	return [frames, gaps]


func check(what: String, ok: bool, got: String) -> void:
	print("  %-58s %s  %s" % [what, "ok  " if ok else "FAIL", got])
	if not ok:
		fails.append("%s (%s)" % [what, got])


func _initialize() -> void:
	await process_frame
	print("Synthetic steps:")
	var roll := WsgNoteChecks.foot_slip(step(0.0, ""))
	check("a pure heel-to-toe roll reads under 0.5 cm", roll.steps == 2 and roll.max_cm < 0.5,
		"%d steps, %.2f cm" % [roll.steps, roll.max_cm])
	for phase in ["strike", "flat", "heel"]:
		var s := WsgNoteChecks.foot_slip(step(0.03, phase))
		# (The positions are single-precision: 3 cm in steps comes back within a micrometre of 3.)
		check("a planted foot pushed 3 cm (%s) reads 3 cm or more" % phase, s.steps == 2 and s.max_cm >= 3.0 - 1e-4,
			"%d steps, %.2f cm" % [s.steps, s.max_cm])
	# Where: the foot and frames of the worst slide (WsgSim reports them - the failure's frame, for its replay).
	var fl := WsgNoteChecks.foot_slip(step(0.03, "flat"))
	var at: Array = fl.max_at
	check("the slide's place: the left foot, over the flat frames (13-22)", int(at[0]) == 0 and int(at[1]) <= 13 and int(at[2]) >= 22 \
		and int(at[2]) < step(0.03, "flat").size(), "%s" % [at])
	var snap := WsgNoteChecks.foot_slip(landing(true))
	check("the skid's place: the left foot", int(snap.skid_at[0]) == 0 and int(snap.skid_at[2]) == int(snap.skid_at[1]) + 1, "%s" % [snap.skid_at])
	check("a foot snapped back flat on the floor reads a skid over 2 cm", snap.skid_cm > 2.0,
		"skid %.1f cm" % snap.skid_cm)
	var skim := WsgNoteChecks.foot_slip(landing(false))
	check("a swing skimming the grass, heel up, is no skid", skim.skid_cm < 0.5, "skid %.2f cm" % skim.skid_cm)
	check("a pure roll is no skid", roll.skid_cm < 0.5, "skid %.2f cm" % roll.skid_cm)
	# The skid counts a foot the planter has (held), not the clip's own low swing before it lands (Pok Ta Pok).
	var lf := landing(true)
	var all_held := []
	var none_held := []
	for f in lf.size():
		all_held.append([true, true])
		none_held.append([false, false])
	var sh := WsgNoteChecks.foot_slip(lf, 0.0, 0.0, 0.0, PackedInt32Array(), all_held)
	var sn := WsgNoteChecks.foot_slip(lf, 0.0, 0.0, 0.0, PackedInt32Array(), none_held)
	check("the snap, the planter holding the foot: a skid", sh.skid_cm > 2.0, "skid %.1f cm" % sh.skid_cm)
	check("the same move, the clip's own swing (not held): no skid", sn.skid_cm < 0.5, "skid %.1f cm" % sn.skid_cm)
	print("A body posed every 3rd frame:")
	var c := creep(0.009, 3)
	var raw := WsgNoteChecks.foot_slip(c[0])
	var per := WsgNoteChecks.foot_slip(c[0], 0.0, 0.0, 0.0, c[1])
	check("0.9 cm a frame read every 3rd: no skid", per.skid_cm < 2.0 and absf(per.skid_cm - 0.9) < 0.05,
		"skid %.2f cm (as if every frame: %.2f)" % [per.skid_cm, raw.skid_cm])
	var fast := creep(0.03, 3)
	var fs := WsgNoteChecks.foot_slip(fast[0], 0.0, 0.0, 0.0, fast[1])
	check("3 cm a frame read every 3rd: a skid", fs.skid_cm > 2.0, "skid %.2f cm" % fs.skid_cm)
	var one := low_swing(1)
	var three := low_swing(3)
	var j1 := float(WsgNoteChecks.foot_slip(one[0], 0.0, 0.0, 0.0, one[1]).jump_cm)
	var j3 := float(WsgNoteChecks.foot_slip(three[0], 0.0, 0.0, 0.0, three[1]).jump_cm)
	var j3raw := float(WsgNoteChecks.foot_slip(three[0]).jump_cm)
	check("a low swing read every 3rd jumps as read every frame", j1 > 0.0 and absf(j3 - j1) < 0.25 * j1 + 0.05,
		"every frame %.2f, every 3rd %.2f cm (as if every frame: %.2f)" % [j1, j3, j3raw])
	if not FileAccess.file_exists("res://addons/wsg_foundation/data/mobility.res"):
		print("Planter off: SKIPPED (no licensed clip library)")
	else:
		print("The hurler, planter off, driven every frame:")
		for speed: float in WALK_SPEEDS:
			var body := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
			root.add_child(body)
			var loco := WsgLocomotor.attach(body)
			loco.planter.enabled = false
			await process_frame
			var frames := []
			await WsgWorldRules.drive(self, body, loco, [[1.5, Vector2(0, speed), NAN], [6.0, Vector2(0, speed), NAN]],
				func(_t: float, si: int):
					if si == 1:
						frames.append(WsgNoteChecks.feet(body)))
			var s := WsgNoteChecks.foot_slip(frames)
			check("planter off at %.1f m/s reads 5 cm or more" % speed, s.max_cm >= 5.0,
				"%d steps, worst %.1f cm, mean %.1f cm" % [s.steps, s.max_cm, s.mean_cm])
			body.queue_free()
			await process_frame
	print("FOOT SLIP TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)
