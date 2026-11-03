extends WsgOwnerNote
const NOTE := {"id": "2026-11-03-getup-twitch", "game": "kabaddi", "date": "2026-11-03", "version": "0.14.1-beta",
	"words": "Getting up the kabaddi player had a leg twitch that made it look weird."}
const U := preload("res://tests/owner_note_util.gd")


## A defender up from each kind of dive (and every defender in turn): a get-up at a human pace, no knee snapping (its
## second difference over the whole get-up), and up into his crouch.
func check() -> void:
	var m: Node = U.start(tree, {"first_raider": 0, "passive": true})
	await U.until_raid(tree, m)
	var worst := 0.0
	for kind in ["dash", "ankle", "thigh", "waist"]:
		var d: Athlete = m.defenders()[["dash", "ankle", "thigh", "waist"].find(kind) % m.defenders().size()]
		d.tackle_kind = kind
		d.set_state("dive", 0.4)
		await U.frames(tree, 10)
		m._land(d, 0.9)
		var up_s: float = d.st_len
		expect(up_s >= m.GETUP_MIN - 0.001, "%s: up in %.2f s, faster than a person (%.2f)" % [kind, up_s, m.GETUP_MIN])
		var q := []
		var least := 180.0
		for f in 75:
			await tree.process_frame
			q.append([d.model.kn_l.quaternion, d.model.kn_r.quaternion])
			if (d.state == "recover" and d.st_t > d.st_len * 0.75) or d.state == "ready":
				least = minf(least, rad_to_deg(minf(d.model.kn_l.quaternion.get_angle(), d.model.kn_r.quaternion.get_angle())))
		var jolt := 0.0
		for f in range(2, q.size()):
			for k in 2:
				var d1: Quaternion = q[f - 1][k] * (q[f - 2][k] as Quaternion).inverse()
				var d2: Quaternion = q[f][k] * (q[f - 1][k] as Quaternion).inverse()
				var v := (d2 * d1.inverse()).normalized().get_angle()
				jolt = maxf(jolt, minf(v, TAU - v))
		info("%s dive: up in %.2f s, worst knee jolt %.2f rad a frame, knees at least %.0f deg as he readies" % [kind, up_s, jolt, least])
		expect(jolt < 0.5, "%s: the knee snaps getting up (%.2f rad a frame)" % [kind, jolt])
		expect(least > 25.0, "%s: stood up straight instead of into his crouch (%.0f deg)" % [kind, least])
		worst = maxf(worst, jolt)
	m.queue_free()
	await U.frames(tree, 2)
