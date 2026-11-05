extends RefCounted
## Sepak Takraw's registry for the shared prop audit (tools/wsg/prop_audit.gd; the owner: "There will NEVER be a time
## when a player or referee should walk through a table or bench etc. A ball should also bounce off these items."):
## at each venue a Watch-AI match played at sim speed, every player and every official on his feet handed to the audit
## each frame, and the ball while it is free (flying or loose; carried or held it goes where the hands are).
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/prop_audit.gd -- res://game/prop_runs.gd "$RUNNER_TEMP/prop_audit" 2 120
## (The referee sits in his chair and the substitutes on their benches: on them by design, not walking.)

const DT := 1.0 / 30.0


static func venues() -> Array:
	return DB.VENUES.map(func(v): return String(v[0]))


func run(venue: String, seed: int, seconds: float, audit: WsgPropAudit, tree: SceneTree) -> Node:
	Game.reset_settings_for_tests()
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_LOW
	FoundationLink.off = true
	var teams: Array = [["THA", "MAS"], ["VIE", "INA"], ["SPB", "NPT"], ["JPN", "KOR"]][seed % 4]
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": teams[0], "away": teams[1], "venue": venue, "event": "regu", "sets": 3, "points": 15,
		"user_team": -1, "demo": true, "seed": seed, "mode": "watch"}
	tree.root.add_child(m)
	audit.solid = m.arena.solid
	var walkers := []
	for o in m.get("_officials").list:
		if o.standing:
			walkers.append(o.body)
	var free_was := false
	for f in int(seconds / DT):
		m._process(DT)
		m.set("_start_replay_after", -1.0)   # (no replays: they put bodies back where they were)
		if int(m.state) == int(m.S.OVER):
			break
		for side in 2:
			for pp in m.players_on(side):
				var pl: Player = pp
				audit.body("%s %s" % [pl.data.get("id", "player"), ["tekong", "feeder", "striker", "fourth"][clampi(pl.role, 0, 3)]],
					pl.global_position, Player.BODY_R, Player.BODY_H)
		for b in walkers:
			audit.body("official", (b as Node3D).global_position, 0.25, 1.8)
		var free: bool = m.ball.flying or m.ball.loose
		if free and free_was:
			audit.ball(m.ball.global_position, Ball.RADIUS)
		else:
			audit.ball_reset()   # (in a hand, or put down for the serve: moved there, not through anything)
			if free:
				audit.ball(m.ball.global_position, Ball.RADIUS)
		free_was = free
		audit.tick(DT)
		if f % 600 == 0:
			await tree.process_frame
	return m
