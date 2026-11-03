extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta), with a video of a penalty shot.

const NOTE := {"id": "2026-11-02-penalty-contort", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "Then coming back to shoot again his body contorts horribly."}

const Lib := preload("res://tests/note_lib.gd")


## Penalty shots, three shots: after each, pulling up and coming back for the next, the shooter as drawn stays a
## person - his chest never turned over 60 degrees from his hips, no T- or A-pose, no elbow bent past 160 degrees, no
## wrist over 70 degrees.
func check() -> void:
	if not Lib.have_foundation():
		skip("no licensed clips here: the shared foundation's bodies are not drawn")
		return
	var m: Node = (load(Lib.MATCH) as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "practice", "practice": true, "period": 20.0, "seed": 3}
	Lib.host(tree).add_child(m)
	var worst := {"twist": 0.0, "elbow": 0.0, "wrist": 0.0, "pose": 0, "frames": 0}
	var hooked := []
	for f in 60 * 30:
		var st := String(m._so.get("stage", ""))
		m.touch.joystick = Vector2(0, -1) if st == "run" else Vector2.ZERO
		var sh: Player = m._so.get("shooter")
		if st == "run" and sh and (sh.pos.x * float(m._so.get("dir", 1.0))) > Rules.GOAL_LINE - 5.0:
			m._on_action("SHOOT")
		if sh and sh.link and sh.link.body and not hooked.has(sh):
			hooked.append(sh)
			sh.link.body.posed.connect(func():
				var s2 := String(m._so.get("stage", ""))
				if not (s2 in ["end", "walk", "setup"]) and not (s2 == "run" and bool(m._so.get("shot", false))):
					return
				var b: WsgBody = sh.link.body
				var hips := b.bone_world("Hips").basis
				var chest := b.bone_world("Spine2").basis
				var hf := hips * Vector3.FORWARD
				var cf := chest * Vector3.FORWARD
				worst.twist = maxf(worst.twist, Lib.deg(Vector3(hf.x, 0, hf.z), Vector3(cf.x, 0, cf.z)))
				var arms: Dictionary = WsgNoteChecks.arms(b)
				worst.elbow = maxf(worst.elbow, maxf(float(arms.Left[1]), float(arms.Right[1])))
				if WsgNoteChecks.t_or_a_pose(b) != "":
					worst.pose += 1
				for side in ["Left", "Right"]:
					var fore := b.bone_world(side + "ForeArm").origin
					var hand := b.bone_world(side + "Hand").origin
					var kn := b.bone_world(side + "HandMiddle1").origin
					worst.wrist = maxf(worst.wrist, Lib.deg(hand - fore, kn - hand))
				worst.frames += 1)
		await tree.physics_frame
		if int(m._practice.get("shot", 0)) >= 3:
			break
	info("%d frames after the shots: chest turned from the hips at most %.0f degrees, elbows %.0f, wrists %.0f; %d T/A-poses" % [worst.frames, worst.twist, worst.elbow, worst.wrist, worst.pose])
	expect(worst.frames > 60, "too little seen after the shots (%d frames)" % worst.frames)
	expect(worst.twist <= 60.0, "the body twisted %.0f degrees between hips and chest" % worst.twist)
	expect(worst.elbow <= 160.0, "an elbow bent %.0f degrees" % worst.elbow)
	expect(worst.wrist <= 70.0, "a wrist bent %.0f degrees" % worst.wrist)
	expect(worst.pose == 0, "%d frames in a T- or A-pose" % worst.pose)
	await Lib.done(tree, m)
