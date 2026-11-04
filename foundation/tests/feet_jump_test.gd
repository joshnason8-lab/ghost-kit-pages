extends SceneTree
## Pins the low-foot jump (WsgNoteChecks.foot_slip's jump_cm, over WsgWorldRules.JUMP_MAX_CM fails):
## - a foot low over the floor that goes still - 56 cm in one frame - still (Hurling's stop shuffle) reads over it;
## - a sprint's swing low over the floor, speeding up to 35 cm a frame and slowing again, reads well under it;
## - the hurler driven every frame through a walk, a jog, a run, a sprint at 8 m/s, a 90-degree cut at it, a stop from
##   it, a 180-degree cut and a stop at 6 (tools/feet_calibrate's path) jumps no more than it anywhere (the planter
##   before 2026-11-04 re-planted a foot a stride on stopping from 8 m/s: 82.5 cm).
##   godot --headless --fixed-fps 30 --path . -s tests/feet_jump_test.gd

var fails := []


func check(what: String, ok: bool, got: String) -> void:
	print("  %-62s %s  %s" % [what, "ok  " if ok else "FAIL", got])
	if not ok:
		fails.append("%s (%s)" % [what, got])


## The left foot along +x a frame at a time (cm a frame), 5 cm up throughout; the right foot standing still.
static func run_of(moves: Array) -> Array:
	var frames := []
	var x := 0.0
	var ra := Vector3(0, 0.08, 0.4)
	var rt := Vector3(0.15, 0.0, 0.4)
	# (The lowest each end goes over the run is its standing height: one frame of each down on the floor first.)
	frames.append([Vector3(-1.0, 0.08, 0), Vector3(-0.85, 0.0, 0), ra, rt])
	for m in moves:
		x += float(m) / 100.0
		frames.append([Vector3(x, 0.13, 0), Vector3(x + 0.15, 0.05, 0), ra, rt])
	return frames


func _initialize() -> void:
	await process_frame
	var lim := WsgWorldRules.JUMP_MAX_CM
	var shuffle := WsgNoteChecks.foot_slip(run_of([0, 0, 0, 0, 56, 0, 0, 0, 0]))
	check("a shuffle (still, 56 cm, still) jumps over %.0f cm" % lim, shuffle.jump_cm > lim, "%.1f cm" % shuffle.jump_cm)
	var swing := WsgNoteChecks.foot_slip(run_of([0, 5, 12, 20, 28, 34, 35, 33, 27, 19, 10, 3, 0, 0]))
	check("a sprint swing (up to 35 cm a frame, smoothly) stays under", swing.jump_cm < lim * 0.5, "%.1f cm" % swing.jump_cm)
	if not FileAccess.file_exists("res://addons/wsg_foundation/data/mobility.res"):
		print("The hurler: SKIPPED (no licensed clip library)")
	else:
		var path: Array = (load("res://tools/feet_calibrate.gd") as GDScript).get_script_constant_map()["PATH"]
		var body := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
		root.add_child(body)
		var loco := WsgLocomotor.attach(body)
		await process_frame
		var segs := {}
		await WsgWorldRules.drive(self, body, loco, path, func(_t: float, si: int):
			if not segs.has(si):
				segs[si] = []
			(segs[si] as Array).append(WsgNoteChecks.feet(body)))
		print("The hurler, driven every frame:")
		for si in path.size():
			var s := WsgNoteChecks.foot_slip(segs.get(si, []))
			check("%s: no low foot jumps over %.0f cm" % [path[si][3], lim], s.jump_cm <= lim, "%.1f cm" % s.jump_cm)
		body.queue_free()
	# Near a bound, warned (the lead: Kabaddi's stop 24.1 against 25): within 3 cm of the jump's 25, within 0.3 of 2 cm.
	var nr := WsgWorldRules.result("feet")
	WsgWorldRules._near(nr, "a", 24.1, WsgWorldRules.JUMP_MAX_CM)
	WsgWorldRules._near(nr, "b", 21.0, WsgWorldRules.JUMP_MAX_CM)
	WsgWorldRules._near(nr, "c", 1.8, WsgWorldRules.FEET_MAX_CM)
	WsgWorldRules._near(nr, "d", 1.5, WsgWorldRules.FEET_MAX_CM)
	WsgWorldRules._near(nr, "e", 26.0, WsgWorldRules.JUMP_MAX_CM)
	var named := (nr.warnings as Array).map(func(w: String) -> String: return w.substr(0, 1))
	check("near a bound: 24.1 of 25 and 1.8 of 2 warned; 21, 1.5 and a failure not", named == ["a", "c"], str(nr.warnings))
	print("FEET JUMP TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)
