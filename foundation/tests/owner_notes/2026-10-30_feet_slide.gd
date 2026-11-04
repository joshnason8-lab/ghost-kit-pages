extends WsgOwnerNote
## The owner, 2026-10-30 (Hurling 0.18 on the A16): "The feet do not seem to slide or skate thats great."

const NOTE := {"id": "2026-10-30-feet-slide", "game": "hurling", "date": "2026-10-30", "version": "Hurling 0.18 on the A16", "words": "The feet do not seem to slide or skate thats great."}

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


## Kept as it was when the owner saw it: no step's planted foot (on the ground and not swinging through) moves more
## than 4 cm over the ground, 1.5 on average, standing, walking, jogging, turning, running and stopping.
func check() -> void:
	if not Rig.have_clips():
		skip("no licensed clip library here")
		return
	var w: Array = await _walk()
	var names: Array = ["standing", "walk", "jog", "jog, turned", "run", "stop", "standing again"]
	for si in names.size():
		var s := WsgNoteChecks.foot_slip(_seg(w[0], si, 1), w[2], w[3])
		info("%-15s %2d steps, slip max %.1f cm, mean %.1f cm" % [names[si], s.steps, s.max_cm, s.mean_cm])
		expect(float(s.max_cm) <= 4.0, "%s: a planted foot slid %.1f cm in one step (4 at most)" % [names[si], s.max_cm])
		expect(float(s.mean_cm) <= 1.5, "%s: planted feet slide %.1f cm a step on average (1.5 at most)" % [names[si], s.mean_cm])
	(w[1] as Node).queue_free()
