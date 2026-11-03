extends TakrawNote
## The owner, 2026-11-03, for every game: "There will NEVER be a time when a player or referee should walk through a
## table or bench etc. A ball should also bounce off these items."

const NOTE := {"id": "2026-11-03-props-solid", "game": "sepak-takraw", "date": "2026-11-03", "version": "0.15.3",
	"words": "There will NEVER be a time when a player or referee should walk through a table or bench etc. A ball should also bounce off these items."}


## At every venue a Watch-AI match (game/prop_runs.gd, the shared prop audit's registry): every player and every
## official on his feet never more than 2 cm into a prop, the free ball never through one (WsgPropAudit). And a ball
## come to rest behind a team bench is fetched round the bench (0.15.4 left the fetcher in front of it for good).
func check() -> void:
	var runs: Object = (load("res://game/prop_runs.gd") as GDScript).new()
	for v in venues():
		var audit := WsgPropAudit.new()
		var m: Node = await runs.run(v, 1, 40.0, audit, tree)
		_made.append(m)
		var r := audit.report()
		info("%s: %d body frames, %d inside a prop; %d ball steps, %d through one" % [v, r.body_checks, r.body_cases, r.ball_steps, r.ball_tunnels])
		expect(int(r.body_checks) > 1000 and int(r.ball_steps) > 100, "%s: too little played (%d body frames, %d ball steps)" % [v, r.body_checks, r.ball_steps])
		expect(int(r.body_cases) == 0, "%s: %d times a body was inside a prop (worst %s)" % [v, r.body_cases, str(r.worst).left(200)])
		expect(int(r.ball_tunnels) == 0, "%s: the ball went through a prop %d times" % [v, r.ball_tunnels])
		m.queue_free()
		await frame()
	await clean()
