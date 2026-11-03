extends WsgOwnerNote
## The owner, 2026-11-02 (Netball 0.8.x): "players gliding around not running, arms just stretched out when running."

const NOTE := {"id": "2026-11-02-gliding-arms", "game": "netball", "date": "2026-11-02", "version": "Netball 0.8.x", "words": "players gliding around not running, arms just stretched out when running."}

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


## Jogging and running: the feet step (at least 1.6 steps a second) and stay planted (each step under 4 cm of slip);
## the arms bent as a runner's (elbows 45 degrees or more on average), not stretched out straight.
func check() -> void:
	if not Rig.have_clips():
		skip("no licensed clip library here")
		return
	var w: Array = await _walk()
	var names: Array = ["standing", "walk", "jog", "jog, turned", "run", "stop", "standing again"]
	var secs := [1.5, 2.5, 2.0, 2.0, 2.5, 1.5, 2.0]
	for si in [2, 3, 4]:
		var s := WsgNoteChecks.foot_slip(_seg(w[0], si, 1), w[2], w[3])
		var elbows := 0.0
		var arms: Array = _seg(w[0], si, 2)
		for a: Dictionary in arms:
			elbows += (float(a.Left[1]) + float(a.Right[1])) * 0.5
		elbows /= maxf(1.0, arms.size())
		var rate := float(s.steps) / float(secs[si])
		info("%-12s %.1f steps a second, slip max %.1f cm; elbows bent %.0f degrees on average" % [names[si], rate, s.max_cm, elbows])
		expect(rate >= 1.6, "%s: %.1f steps a second - gliding, not running" % [names[si], rate])
		expect(float(s.max_cm) <= 4.0, "%s: a planted foot slid %.1f cm" % [names[si], s.max_cm])
		expect(elbows >= 45.0, "%s: the arms nearly straight (elbows %.0f degrees on average)" % [names[si], elbows])
	(w[1] as Node).queue_free()
