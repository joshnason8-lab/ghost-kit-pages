extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.21.0): "Players are still gliding/hovering some when running or strafing sideways."

const NOTE := {"id": "2026-11-03-gliding", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.21.0", "words": "Players are still gliding/hovering some when running or strafing sideways."}
const Kit := preload("res://tests/note_kit.gd")


## At least 12 s of live play on High, every body the camera poses every frame, as drawn: no planted foot slides over the
## grass more than 4 cm in a step, 1.5 cm a step on average (WsgNoteChecks.foot_slip), running, turning, strafing or
## standing. The watch goes on (up to 60 s) until it has at least MIN_POSED posed frames of feet, the number 12 s gave
## before the Rule 2.1 throw-in (the lead, 4 November 2026): with everyone behind the 45s at the throw-in, the opening
## play on this seed goes to the far side, out of the broadcast camera's every-frame range, and 12 s saw no feet at all.
## The bounds are unchanged; only the time it takes to see as many feet is longer.
const MIN_POSED := 607
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
	var watched := 0
	while watched < 360 or (_posed(runs) < MIN_POSED and watched < 1800):
		await Kit.frames(tree, 30)
		watched += 30
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
	info("%d posed frames over %.0f s" % [_posed(runs), watched / 30.0])
	expect(_posed(runs) >= MIN_POSED, "only %d posed frames of feet in %.0f s (%d wanted)" % [_posed(runs), watched / 30.0, MIN_POSED])
	info("%d planted steps: the most a foot slid in a step %.1f cm (%s), %.2f cm on average" % [steps, worst, worst_who, mean])
	expect(steps >= 20, "only %d steps seen" % steps)
	expect(worst <= 4.0, "%s: a planted foot slid %.1f cm in one step (4 at most)" % [worst_who, worst])
	expect(mean <= 1.5, "planted feet slide %.2f cm a step on average (1.5 at most)" % mean)
	await Kit.done(tree, m)
	Game.settings.graphics = keep


static func _posed(runs: Dictionary) -> int:
	var n := 0
	for who in runs:
		for fr in runs[who]:
			if fr != null:
				n += 1
	return n
