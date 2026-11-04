extends WsgOwnerNote
## The owner, 2026-11-02 (Kabaddi beta): "standing position is still awful guy is twitching"

const NOTE := {"id": "2026-11-02-standing-twitch", "game": "kabaddi", "date": "2026-11-02", "version": "Kabaddi beta", "words": "standing position is still awful guy is twitching"}

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


## Standing still (before moving and after stopping, the settling half second left out): no bone turns more than 3
## degrees from one frame to the next, and none jerks back and forth (a turn over 1.5 degrees reversed the next
## frame, at most twice).
func check() -> void:
	if not Rig.have_clips():
		skip("no licensed clip library here")
		return
	var w: Array = await _walk()
	for si in [0, 6]:
		var poses: Array = _seg(w[0], si, 4).slice(15)
		var j := WsgNoteChecks.jitter(w[1], poses)
		info("standing (%s): the most a bone turned in a frame %.2f degrees (%s), %d jerks back and forth" % ["before" if si == 0 else "after stopping", j.max_deg, j.bone, j.reversals])
		expect(float(j.max_deg) <= 3.0, "standing, %s turned %.1f degrees in one frame" % [j.bone, j.max_deg])
		expect(int(j.reversals) <= 2, "standing, bones jerked back and forth %d times" % j.reversals)
	(w[1] as Node).queue_free()
