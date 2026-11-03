extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.21.0): "Players are still gliding/hovering some when running or strafing sideways."

const NOTE := {"id": "2026-11-03-gliding", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.21.0", "words": "Players are still gliding/hovering some when running or strafing sideways."}
const Kit := preload("res://tests/note_kit.gd")


## 12 s of live play on High, every body the camera poses every frame, as drawn: no planted foot slides over the grass more
## than 4 cm in a step, 1.5 cm a step on average (WsgNoteChecks.foot_slip), running, turning, strafing or standing.
func check() -> void:
	# (High: every body within 60 m of the camera posed every frame, as the owner sees them close.)
	var keep = Game.settings.graphics
	Game.settings.graphics = Game.GFX_HIGH
	var m: Node = await Kit.match(tree, {"mode": "test", "seed": 6}, 2)
	var f := 0
	while m.phase != m.P.LIVE and f < 30 * 20:
		await Kit.frames(tree, 1)
		f += 1
	var runs := {}
	var cbs := []
	for p in m.all_players() + m.officials.people:
		var pl := p as Player
		if pl.link == null:
			continue
		var who := "%s %d" % [pl.role if pl.role != "" else "team %d" % pl.team, pl.num]
		runs[who] = []
		cbs.append([pl.link.body, Kit.watch(pl.link.body, func(b: WsgBody) -> void:
			if pl._pose_every == 1 and b.is_visible_in_tree():
				(runs[who] as Array).append(WsgNoteChecks.feet(b))
			elif not (runs[who] as Array).is_empty():
				(runs[who] as Array).append(null))])     # (a gap: not posed every frame here)
	await Kit.frames(tree, 360)
	for c in cbs:
		Kit.unwatch(c[0], c[1])
	var steps := 0
	var worst := 0.0
	var worst_who := ""
	var sum := 0.0
	for who in runs:
		var b: WsgBody = null
		for p in m.all_players() + m.officials.people:
			if (p as Player).link and "%s %d" % [(p as Player).role if (p as Player).role != "" else "team %d" % (p as Player).team, (p as Player).num] == who:
				b = (p as Player).link.body
		if b == null:
			continue
		var k: float = b.global_transform.basis.get_scale().y
		# Each unbroken run of frames posed one after another, measured on its own.
		var seg := []
		for fr in (runs[who] as Array) + [null]:
			if fr == null:
				if seg.size() > 10:
					var s := WsgNoteChecks.foot_slip(seg, (b.joints["LeftFoot"] as Vector3).y * k, (b.joints["LeftToeBase"] as Vector3).y * k)
					steps += int(s.steps)
					sum += float(s.mean_cm) * int(s.steps)
					if float(s.max_cm) > worst:
						worst = float(s.max_cm)
						worst_who = who
				seg = []
			else:
				seg.append(fr)
	var mean := sum / maxf(1.0, steps)
	info("%d planted steps over 12 s: the most a foot slid in a step %.1f cm (%s), %.2f cm on average" % [steps, worst, worst_who, mean])
	expect(steps >= 20, "only %d steps seen" % steps)
	expect(worst <= 4.0, "%s: a planted foot slid %.1f cm in one step (4 at most)" % [worst_who, worst])
	expect(mean <= 1.5, "planted feet slide %.2f cm a step on average (1.5 at most)" % mean)
	await Kit.done(tree, m)
	Game.settings.graphics = keep
