extends WsgOwnerNote
## The owner, 2026-11-02 (Pok Ta Pok 0.6.x): "base position is still like an A pose"

const NOTE := {"id": "2026-11-02-a-pose", "game": "pok-ta-pok", "date": "2026-11-02", "version": "Pok Ta Pok 0.6.x", "words": "base position is still like an A pose"}

const Rig := preload("res://tests/note_rig.gd")
const Venues := preload("res://tests/crowd_venue_test.gd")


## The match path's frames: [segment index, feet + the planter's flags, arms, t/a-pose, pose] each frame.
func _walk() -> Array:
	var bl: Array = await Rig.hurler(tree)
	var body: WsgBody = bl[0]
	var loco: WsgLocomotor = bl[1]
	var out := []
	await Rig.drive(tree, body, loco, Rig.match_path(), func(_t: float, si: int):
		out.append([si, WsgNoteChecks.feet(body), WsgNoteChecks.arms(body), WsgNoteChecks.t_or_a_pose(body), WsgNoteChecks.pose(body)]))
	var res := [out, body, (body.joints["LeftFoot"] as Vector3).y, (body.joints["LeftToeBase"] as Vector3).y]
	return res


func _seg(frames: Array, si: int, k: int) -> Array:
	var o := []
	for f in frames:
		if int(f[0]) == si:
			o.append(f[k])
	return o


## Standing (before moving and after stopping), every frame: no T-pose or A-pose (both arms out past 35 degrees and
## straight); and moving, never either.
func check() -> void:
	if not Rig.have_clips():
		skip("no licensed clip library here")
		return
	var w: Array = await _walk()
	var bad := 0
	var first := ""
	var arms_out := 0.0
	for f in w[0]:
		var a: Dictionary = f[2]
		if int(f[0]) in [0, 6]:
			arms_out = maxf(arms_out, maxf(a.Left[0], a.Right[0]))
		if String(f[3]) != "":
			bad += 1
			if first == "":
				first = f[3]
	info("standing, the arms at most %.0f degrees out from hanging; %d frames of %d a T- or A-pose" % [arms_out, bad, (w[0] as Array).size()])
	expect(bad == 0, "%d frames in a T- or A-pose: %s" % [bad, first])
	expect(arms_out < 30.0, "standing with the arms %.0f degrees out (an A-pose's beginning)" % arms_out)
	(w[1] as Node).queue_free()
