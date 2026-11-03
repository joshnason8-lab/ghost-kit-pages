extends WsgOwnerNote
## The owner, 2026-10-30 (Hurling 0.18 on the A16): "I did see the arm bending the wrong way a few times."

const NOTE := {"id": "2026-10-30-arm-wrong-way", "game": "hurling", "date": "2026-10-30", "version": "Hurling 0.18 on the A16", "words": "I did see the arm bending the wrong way a few times."}

const Rig := preload("res://tests/note_rig.gd")
const Venues := preload("res://tests/crowd_venue_test.gd")


## Over a match's moves (standing, walking, jogging, turning, running, stopping), every frame: no elbow and no knee
## bends backwards (more than 3 degrees past straight).
func check() -> void:
	if not Rig.have_clips():
		skip("no licensed clip library here")
		return
	var bl: Array = await Rig.hurler(tree)
	var body: WsgBody = bl[0]
	var worst := {"elbow": 0.0, "knee": 0.0}
	var frames := [0]
	await Rig.drive(tree, body, bl[1], Rig.match_path(), func(_t: float, _si: int):
		frames[0] += 1
		for side in ["Left", "Right"]:
			var el := _bend(body, side + "Arm", side + "ForeArm", side + "Hand", Vector3.DOWN if side == "Left" else Vector3.UP)
			var kn := _bend(body, side + "UpLeg", side + "Leg", side + "Foot", Vector3.RIGHT)
			worst.elbow = minf(worst.elbow, el)
			worst.knee = minf(worst.knee, kn))
	info("%d frames: the most backwards an elbow went %.1f degrees, a knee %.1f" % [frames[0], worst.elbow, worst.knee])
	expect(worst.elbow >= -3.0, "an elbow bent %.1f degrees the wrong way" % -worst.elbow)
	expect(worst.knee >= -3.0, "a knee bent %.1f degrees the wrong way" % -worst.knee)
	body.queue_free()


## The hinge's bend, signed (rig_test's): positive the right way.
static func _bend(body: WsgBody, a: String, b: String, c: String, axis_local: Vector3) -> float:
	var ga := body.bone_world(a)
	var u := (body.bone_world(b).origin - ga.origin).normalized()
	var f := (body.bone_world(c).origin - body.bone_world(b).origin).normalized()
	return rad_to_deg(u.signed_angle_to(f, (ga.basis * axis_local).normalized()))
