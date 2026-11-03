extends WsgOwnerNote
const NOTE := {"id": "2026-11-02-stance-twitch", "game": "kabaddi", "date": "2026-11-02", "version": "0.13.1-beta",
	"words": "standing position is still awful guy is twitching"}
const U := preload("res://tests/owner_note_util.gd")
const JOINTS := ["hip_l", "hip_r", "kn_l", "kn_r", "spine", "sh_l", "sh_r", "el_l", "el_r"]


## Standing, no input: the user's raider waiting at the start of his raid, and every defender standing still in his
## stance - each joint's second difference over two seconds (a twitch is a jolt; quaternions, so no angle wraps).
func check() -> void:
	for side in [0, 1]:
		var m: Node = U.start(tree, {"first_raider": side, "passive": true})
		await U.until_raid(tree, m)
		await U.frames(tree, 20)   # the last stride to the mark settles first (a stride ending is not a twitch)
		var who: Array = [m.raider] if side == 0 else m.defenders().filter(func(a): return a.state in ["ready", "idle"])
		var hist := {}
		for f in 60:
			await tree.process_frame
			for a in who:
				if not hist.has(a):
					hist[a] = []
				hist[a].append([a.position] + JOINTS.map(func(j): return (a.model.get(j) as Node3D).quaternion))
		for a in hist:
			var h: Array = hist[a]
			# Standing: his feet where they were all through (a defender adjusting his place is walking, not standing).
			var moved := 0.0
			for f in h.size():
				moved = maxf(moved, (h[f][0] as Vector3).distance_to(h[0][0]))
			if moved > 0.05:
				continue
			var jerk := 0.0
			var at := ""
			for f in range(2, h.size()):
				for j in JOINTS.size():
					var d1: Quaternion = h[f - 1][j + 1] * (h[f - 2][j + 1] as Quaternion).inverse()
					var d2: Quaternion = h[f][j + 1] * (h[f - 1][j + 1] as Quaternion).inverse()
					var v := (d2 * d1.inverse()).normalized().get_angle()
					v = minf(v, TAU - v)
					if v > jerk:
						jerk = v
						at = JOINTS[j]
			var role := "raider" if a == m.raider else "defender"
			info("%s %s standing: worst jolt %.3f rad (%s)" % [role, a.name, jerk, at])
			expect(jerk < 0.02 or a.state not in ["ready", "idle", "raid"], "%s twitches standing: %.3f rad at the %s" % [role, jerk, at])
		m.queue_free()
		await U.frames(tree, 2)
