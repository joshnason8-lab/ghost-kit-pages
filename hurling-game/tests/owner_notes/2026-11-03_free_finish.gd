extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.21.0 (with a screenshot)): "Finish of the free take swing is still awkward, does that look like a normal body to you. See screenshot."

const NOTE := {"id": "2026-11-03-free-finish", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.21.0 (with a screenshot)", "words": "Finish of the free take swing is still awkward, does that look like a normal body to you. See screenshot."}
const Kit := preload("res://tests/note_kit.gd")
const FINISH_FROM := 1.9     # s into free_strike: past contact (1.8), the follow-through and its held finish

## The taker's free, every frame as drawn (lift, strike, follow-through, its held finish): no elbow or knee bent the
## wrong way (3 degrees past straight), the hurley's shaft never into the trunk, and the finish upright (from just after
## contact: the neck over the hips within 35 degrees; he bends down to the sliotar to lift it before).
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "practice", "user_team": 0, "seed": 2}, 20, true)
	m.set_process(false)
	var pl: Player = m.taker
	pl.visible_on_screen = true
	pl.set_pose_rate(1)
	var st := {"frames": 0, "elbow": 0.0, "knee": 0.0, "stick": INF, "lean": 0.0}
	var cb := Kit.watch(pl.link.body, func(b: WsgBody) -> void:
		if pl.action != "free_strike":
			return
		st.frames += 1
		for side in ["Left", "Right"]:
			st.elbow = minf(st.elbow, Kit.bend(b, side + "Arm", side + "ForeArm", side + "Hand", Vector3.DOWN if side == "Left" else Vector3.UP))
			st.knee = minf(st.knee, Kit.bend(b, side + "UpLeg", side + "Leg", side + "Foot", Vector3.RIGHT))
		st.stick = minf(st.stick, Kit.stick_clearance(pl.link))
		if pl.action_t > FINISH_FROM:
			var spine: Vector3 = b.bone_world("Neck").origin - b.bone_world("Hips").origin
			st.lean = maxf(st.lean, rad_to_deg(spine.angle_to(Vector3.UP))))
	pl.play("free_strike")
	var len := float(Player.ACTIONS.free_strike[0])
	var t := 0.0
	while t <= len:
		pl.action_t = t
		pl.animate(float(m.now) + t)
		await Kit.frames(tree, 1)
		t += 1.0 / 30.0
	Kit.unwatch(pl.link.body, cb)
	info("%d frames: elbow most backwards %.1f deg, knee %.1f deg; the hurley's shaft closest to the trunk %.0f mm; the finish leaned at most %.0f deg" % [
		st.frames, -st.elbow, -st.knee, st.stick * 1000.0, st.lean])
	expect(st.frames > 20, "the free was not drawn (%d frames)" % st.frames)
	expect(st.elbow >= -3.0, "an elbow bent %.1f degrees the wrong way" % -st.elbow)
	expect(st.knee >= -3.0, "a knee bent %.1f degrees the wrong way" % -st.knee)
	expect(st.stick >= 0.0, "the hurley %.0f mm into the trunk" % (-st.stick * 1000.0))
	expect(st.lean <= 35.0, "the finish folded %.0f degrees off upright" % st.lean)
	await Kit.done(tree, m)
