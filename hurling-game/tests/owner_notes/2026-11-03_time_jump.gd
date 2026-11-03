extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.21.0): "There was a large time jump for some reason while watching an AI game."

const NOTE := {"id": "2026-11-03-time-jump", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.21.0", "words": "There was a large time jump for some reason while watching an AI game."}
const Kit := preload("res://tests/note_kit.gd")

## Watching the AI, at 1x and at 2x: a stoppage put on the match's clock at once (90 s) is run up to on the score bug
## over frames you can see (at least 0.4 s of real time), never backwards, and caught up within 2 s; through live play
## between, it moves with the match.
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "watch", "seed": 4, "length": 4.0}, 2)
	var f := 0
	while m.phase != m.P.LIVE and f < 30 * 20:
		await Kit.frames(tree, 1)
		f += 1
	for speed in [1.0, 2.0]:
		Engine.time_scale = speed
		await Kit.frames(tree, 10)
		var start: float = m.hud._shown_clock
		m.clock += 90.0           # (a stoppage put on the watch at once)
		var last := start
		var frames_up := 0
		var back := false
		var caught := -1
		for i in 60:
			await Kit.frames(tree, 1)
			var c: float = m.hud._shown_clock
			back = back or c < last - 0.001
			if caught < 0 and absf(float(m.clock) - c) < 0.5:
				caught = i + 1
			elif caught < 0:
				frames_up += 1
			last = c
		info("at %.0fx: 90 s run up over %d frames (%.2f s), caught up after %d frames, backwards %s" % [speed, frames_up + 1, (frames_up + 1) / 30.0, caught, back])
		expect(frames_up + 1 >= 12, "at %.0fx the 90 s showed in %d frames: a jump" % [speed, frames_up + 1])
		expect(caught > 0 and caught <= 60, "at %.0fx the score bug never caught up with the clock in 2 s" % speed)
		expect(not back, "at %.0fx the score bug's clock went backwards" % speed)
	Engine.time_scale = 1.0
	await Kit.done(tree, m)
