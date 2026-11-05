extends WsgOwnerNote
## The owner, 2026-11-03 (Floorball 0.9.6-beta).

const NOTE := {"id": "2026-11-03-goalie-hold-loop", "game": "floorball", "date": "2026-11-03", "version": "0.9.6-beta",
	"words": "A critical error happens in game where the goalie seems to just hold the ball when the players are too close and doesn't release. He releases and grabs over and over."}

const Lib := preload("res://tests/note_lib.gd")


## The goalkeeper holding the ball with one, two and three opponents pressing him (from 1 m), in three matches each:
## he throws it out once inside the three seconds (507.16), and never catches his own throw again.
func check() -> void:
	var regrabs := 0
	var late := 0
	var cases := 0
	for press in [1, 2, 3]:
		for seed in [11, 12, 13]:
			var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": seed, "period": 4.0})
			var gk: Player = m.keeper(0)
			var a: float = m.attack_dir(0)
			m.ball.release()
			m.ball.hold(gk, Vector3(gk.pos.x, 0.7, gk.pos.y))
			m.ball.last_player = gk
			m.ball.last_team = 0
			m.gk_hold = 0.0
			var opp: Array = m.skaters(1)
			for k in press:
				(opp[k] as Player).respawn(gk.pos + Vector2(a * (1.0 + k * 0.5), (k - 1) * 1.1))
			var was := true
			var released_at := -1
			for f in 360:
				await tree.physics_frame
				var now: bool = m.ball.held_by == gk
				if was and not now and released_at < 0:
					released_at = f
				if now and not was and m.ball.last_player == gk:
					regrabs += 1
				was = now
			cases += 1
			if released_at < 0 or released_at > 180:
				late += 1
			await Lib.done(tree, m)
	info("%d cases (1 to 3 opponents pressing, 3 seeds): %d caught his own throw again, %d held over 3 s" % [cases, regrabs, late])
	expect(regrabs == 0, "the goalkeeper caught his own throw again %d times" % regrabs)
	expect(late == 0, "the goalkeeper held the ball over 3 seconds in %d of %d cases" % [late, cases])
