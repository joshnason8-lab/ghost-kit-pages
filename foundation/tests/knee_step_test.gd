extends SceneTree
## The planter's own steps never bend a knee backwards: the test hurler (licensed clips) walked and jogged at 1.3, 2.2,
## 3.0 and 4.5 m/s from standing, with a turn every other two seconds, 10 s each; on every frame as drawn, no bent knee
## is more than WsgNoteChecks.KNEE_BACK behind its hip-ankle line against the body's forward (the knees world rule's
## measure). (A step's swung-up thigh turned the knee's side over the hip: 7.9 cm behind at 4.5 m/s on the test hurler,
## 8-20 cm held 4 frames on Kabaddi's raider at High, 2026-11-04.)
##   godot --headless --fixed-fps 30 --path . -s tests/knee_step_test.gd

const Rig := preload("res://tests/note_rig.gd")

var sk: Skeleton3D
var legs: Array
var hits := []
var frame := 0


func _seen() -> void:
	var ks := WsgNoteChecks.knees(sk, legs)
	for i in 2:
		var k: Array = ks[i]
		if float(k[1]) >= WsgNoteChecks.KNEE_BENT and float(k[0]) < -WsgNoteChecks.KNEE_BACK:
			hits.append("frame %d, %s knee %.1f cm behind" % [frame, ["left", "right"][i], -float(k[0]) * 100.0])


func _initialize() -> void:
	await process_frame
	if not Rig.have_clips():
		print("KNEE STEP TEST: SKIPPED (no licensed clip library here)")
		quit(0)
		return
	var fails := []
	for sp: float in [1.3, 2.2, 3.0, 4.5]:
		var body := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
		root.add_child(body)
		var loco := WsgLocomotor.attach(body)
		await process_frame
		sk = body.skeleton
		legs = WsgNoteChecks.leg_bones(sk)
		hits = []
		sk.skeleton_updated.connect(_seen)
		var yaw := 0.0
		for t in 300:
			frame = t
			yaw += (0.6 if (t / 60) % 2 == 1 else 0.0) / 30.0
			var vel: Vector3 = Vector3(sin(yaw), 0, cos(yaw)) * sp
			body.position += vel / 30.0
			loco.drive(1.0 / 30.0, vel, yaw, vel)
			await process_frame
		print("at %.1f m/s: %d backward knee-frames of 600%s" % [sp, hits.size(), (" (" + ", ".join(hits.slice(0, 3)) + ")") if not hits.is_empty() else ""])
		if not hits.is_empty():
			fails.append("at %.1f m/s: %s" % [sp, hits[0]])
		sk.skeleton_updated.disconnect(_seen)
		body.queue_free()
		await process_frame
	print("KNEE STEP TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)
