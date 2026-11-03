extends WsgOwnerNote
## The owner, 2026-10-22 (Floorball 0.1).

const NOTE := {"id": "2026-10-22-passive-play", "game": "floorball", "date": "2026-10-22", "version": "0.1",
	"words": "the cpu just kept passing it back and forth on their side for quite some time before even trying to be offensive. passive play seems to be too often"}

const Lib := preload("res://tests/note_lib.gd")


## AI matches in the three venues, 3 x 3 minutes: a team does not keep the ball in its own half for long - its longest
## spell there under 20 seconds - and passive play is warned at most twice a match (507.20, as in a league match).
func check() -> void:
	var keep := FoundationLink.off
	FoundationLink.off = true
	for c in [["SWE", "FIN", "arena"], ["NOR", "DEN", "hall"], ["GER", "POL", "school"]]:
		var m: Node = (load(Lib.MATCH) as Script).new()
		m.config = {"home": c[0], "away": c[1], "venue": c[2], "user_team": -1, "demo": true, "seed": 31, "mode": "quick", "period": 3.0}
		var done := [false]
		m.finished.connect(func(_r): done[0] = true)
		Lib.host(tree).add_child(m)
		var spell := 0.0
		var longest := 0.0
		var guard := 0
		while not done[0] and guard < 60 * 60 * 15:
			await tree.physics_frame
			guard += 1
			var car: Player = m.ball.carrier
			if String(m.phase) == "live" and car and m.ball.floor_pos().x * m.attack_dir(car.team) < 0.0:
				spell += 1.0 / 60.0
				longest = maxf(longest, spell)
			elif String(m.phase) == "live":
				spell = 0.0 if (m.ball.carrier == null and m.ball.last_team < 0) or (car and m.ball.floor_pos().x * m.attack_dir(car.team) >= 0.0) else spell
		var warned := 0
		for k: Dictionary in m.calls:
			if String(k.get("kind", "")) == "passive":
				warned += 1
		info("%s v %s (%s): the longest spell with the ball in its own half %.0f s; passive play warned %d times" % [c[0], c[1], c[2], longest, warned])
		expect(longest < 20.0, "%s v %s: a team kept the ball in its own half %.0f s" % [c[0], c[1], longest])
		expect(warned <= 2, "%s v %s: passive play warned %d times" % [c[0], c[1], warned])
		await Lib.done(tree, m)
	FoundationLink.off = keep
