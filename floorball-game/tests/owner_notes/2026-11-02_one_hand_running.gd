extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.1-beta).

const NOTE := {"id": "2026-11-02-one-hand-running", "game": "floorball", "date": "2026-11-02", "version": "0.9.1-beta",
	"words": "I’m watching real video I see players running with the stick in only one hand"}

const Lib := preload("res://tests/note_lib.gd")


## Over AI play: a skater sprinting away from the ball (over 3 m/s, the ball over 4 m off, not his) carries the stick
## in his top hand alone - every such frame, after the first half second of it - and one with the ball, or near it,
## has both hands on it.
func check() -> void:
	var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": 9, "period": 4.0})
	var sprint := 0
	var sprint_one := 0
	var carry := 0
	var carry_two := 0
	var run_for := {}
	for f in 60 * 40:
		await tree.physics_frame
		for t in 2:
			for p: Player in m.skaters(t):
				if not p.visible or not p.on_rink:
					continue
				var bd: float = p.pos.distance_to(m.ball.floor_pos())
				var one: bool = p.get("_one_hand")
				if m.ball.carrier == p:
					carry += 1
					if not one:
						carry_two += 1
				var fast: bool = p.vel.length() > 3.2 and bd > 4.5 and m.ball.carrier != p and p.act == "" and p.windup <= 0.0
				run_for[p] = int(run_for.get(p, 0)) + 1 if fast else 0
				if int(run_for[p]) > 30:
					sprint += 1
					if one:
						sprint_one += 1
	info("sprinting away from the ball: one hand in %d of %d frames; with the ball: two hands in %d of %d" % [sprint_one, sprint, carry_two, carry])
	expect(sprint > 60, "too little sprinting seen to judge (%d frames)" % sprint)
	expect(sprint_one >= sprint * 0.95, "sprinting away from the ball, the stick in one hand in only %d of %d frames" % [sprint_one, sprint])
	expect(carry_two == carry, "with the ball, one hand on the stick in %d frames" % (carry - carry_two))
	await Lib.done(tree, m)
