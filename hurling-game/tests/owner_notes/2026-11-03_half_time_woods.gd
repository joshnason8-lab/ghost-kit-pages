extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.21.0): "at halftime for some reason I watched players run off the field into the woods."

const NOTE := {"id": "2026-11-03-half-time-woods", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.21.0", "words": "at halftime for some reason I watched players run off the field into the woods."}
const Kit := preload("res://tests/note_kit.gd")

## Over the break, every player walks to his place for the second half: none goes on further out beyond the lines
## than he was at the whistle (a metre at most).
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "watch", "seed": 4, "length": 2.0}, 2)
	var out := func(p: Player) -> float: return maxf(absf(p.global_position.x) - Pitch.HALF_L, absf(p.global_position.z) - Pitch.HALF_W)
	var at_whistle := {}
	var worst := 0.0
	var seen := false
	var f := 0
	Engine.time_scale = 4.0
	while m.half < 2 and f < 30 * 400:
		await Kit.frames(tree, 1)
		f += 1
		if m.phase == m.P.HALF_TIME:
			for pl in m.all_players():
				var p: Player = pl
				if not p.visible:
					continue
				var o: float = out.call(p)
				if not seen:
					at_whistle[p] = maxf(o, 0.0)
				worst = maxf(worst, o - float(at_whistle.get(p, 0.0)))
			seen = true
	Engine.time_scale = 1.0
	info("half-time seen %s; the most any player went further out over the break: %.1f m" % [seen, worst])
	expect(seen, "the match never reached half-time")
	expect(worst < 1.0, "a player ran on off the field over the break (%.1f m further out)" % worst)
	await Kit.done(tree, m)
