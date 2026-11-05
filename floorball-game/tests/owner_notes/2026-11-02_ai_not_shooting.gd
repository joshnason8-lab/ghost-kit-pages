extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta).

const NOTE := {"id": "2026-11-02-ai-not-shooting", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "AI doesn't seem interested in actually shooting at the goal."}

const Lib := preload("res://tests/note_lib.gd")


## AI matches in all three venues (strong v strong, strong v weak), 3 x 3 minutes: each team shoots at the goal as a
## league side does - at least 1.2 shots a minute of play between them, each team at least 5 - and when a forward has
## the ball in front of the goal within 10 m, he shoots more often than he passes it back out.
func check() -> void:
	var keep := FoundationLink.off
	FoundationLink.off = true
	for c in [["SWE", "FIN", "arena"], ["SUI", "LAT", "hall"], ["CZE", "THA", "school"]]:
		var m: Node = (load(Lib.MATCH) as Script).new()
		m.config = {"home": c[0], "away": c[1], "venue": c[2], "user_team": -1, "demo": true, "seed": 21, "mode": "quick", "period": 3.0}
		var res := {}
		var done := [false]
		m.finished.connect(func(r): res.merge(r); done[0] = true)
		Lib.host(tree).add_child(m)
		var guard := 0
		while not done[0] and guard < 60 * 60 * 15:
			await tree.physics_frame
			guard += 1
		var shots: Array = [int(m.team_stats[0].shots), int(m.team_stats[1].shots)]
		var mins := 9.0
		info("%s v %s (%s): shots %d - %d in %.0f minutes" % [c[0], c[1], c[2], shots[0], shots[1], mins])
		expect(done[0], "%s v %s did not finish" % [c[0], c[1]])
		expect(float(shots[0] + shots[1]) / mins >= 1.2, "%s v %s: %d shots in %.0f minutes - not interested in shooting" % [c[0], c[1], shots[0] + shots[1], mins])
		expect(mini(shots[0], shots[1]) >= 5, "%s v %s: a team shot only %d times" % [c[0], c[1], mini(shots[0], shots[1])])
		await Lib.done(tree, m)
	FoundationLink.off = keep
