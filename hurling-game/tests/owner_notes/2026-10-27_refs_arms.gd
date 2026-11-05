extends WsgOwnerNote
## The owner, 2026-10-27 (Hurling 0.11.1): "The refs body and arms still look very weird"

const NOTE := {"id": "2026-10-27-refs-arms", "game": "hurling", "date": "2026-10-27", "version": "Hurling 0.11.1", "words": "The refs body and arms still look very weird"}
const Kit := preload("res://tests/note_kit.gd")

## The referee, the linesmen and the umpires through 3 s of live play, every frame each is drawn: on the hurlers'
## skinned model (no block figure), never in a T- or A-pose, no elbow bent the wrong way.
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "test", "seed": 8}, 2)
	var f := 0
	while m.phase != m.P.LIVE and f < 30 * 20:
		await Kit.frames(tree, 1)
		f += 1
	var st := {"worst": 0.0, "frames": 0, "poses": []}
	var cbs := []
	for p in m.officials.people:
		var o := p as Player
		if o.link == null:
			fail("the %s is not drawn on the shared model" % o.role)
			continue
		var bf := WsgNoteChecks.block_figure(o) if o.link.body.is_visible_in_tree() else ""
		expect(bf == "" or not o.link.body.is_visible_in_tree(), "the %s: %s" % [o.role, bf])
		cbs.append([o.link.body, Kit.watch(o.link.body, func(b: WsgBody) -> void:
			st.frames += 1
			var pose := WsgNoteChecks.t_or_a_pose(b)
			if pose != "" and (st.poses as Array).size() < 5:
				st.poses.append("the %s in a %s" % [o.role, pose])
			for side in ["Left", "Right"]:
				st.worst = minf(st.worst, Kit.bend(b, side + "Arm", side + "ForeArm", side + "Hand", Vector3.DOWN if side == "Left" else Vector3.UP)))])
	await Kit.frames(tree, 90)
	for c in cbs:
		Kit.unwatch(c[0], c[1])
	for p in st.poses:
		fail(p)
	info("%d officials, %d frames drawn: an elbow's most backwards %.1f degrees" % [m.officials.people.size(), st.frames, -st.worst])
	expect(st.frames > 30, "the officials were hardly drawn (%d frames)" % st.frames)
	expect(st.worst >= -3.0, "an official's elbow bent %.1f degrees the wrong way" % -st.worst)
	await Kit.done(tree, m)
