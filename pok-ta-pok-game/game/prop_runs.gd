extends RefCounted
## The props' audit's registry (the shared tools/wsg/prop_audit.gd, ADOPTING §5.15): at each venue a Watch-AI match,
## copal and all, stepped at sim speed, every player, judge and the elder and the ball handed to the audit each step.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/prop_audit.gd -- res://game/prop_runs.gd "$RUNNER_TEMP/prop_audit" 2 120
## Nobody may stand more than 2 cm into a prop round the court, and the ball may never pass through one (in play or
## running on after the call: Ball.simulate sweeps it against Venue.solid).

const SHOTS := 120            # balls struck off the court at the props, after the match

const TEAMS := {"village": ["ESC", "LLA"], "festival": ["LLA", "ESC"], "stone": ["PIS", "VAL"], "night": ["VAL", "PIS"]}


static func venues() -> Array:
	return ["village", "festival", "stone", "night"]


func run(venue: String, seed: int, seconds: float, audit: WsgPropAudit, tree: SceneTree) -> Node:
	Game.settings.sound = false
	Game.settings.coach = false
	var classic := venue in ["stone", "night"]
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": TEAMS[venue][0], "away": TEAMS[venue][1], "venue": venue, "rules": "classic" if classic else "ulama",
		"user_team": -1, "seed": seed, "length": 0.0, "mode": "watch", "difficulty": seed % 3, "ritual": true}
	tree.root.add_child(m)
	await tree.process_frame
	await tree.process_frame
	audit.solid = m.venue.solid
	# Stepped here, step by step (the audit sees every one of the ball's steps, not a frame's several at 2x).
	m.set_process(false)
	var dt := 1.0 / 30.0
	var was_phase := -1
	for f in int(seconds / dt):
		if m._finished or m.phase == m.P.OVER:
			break
		if m.phase == m.P.REPLAY:
			m._skip_replay = true
		m._tick(dt)
		if m.phase != was_phase:
			# A replay, a new serve: the ball is put somewhere, not moved there.
			audit.ball_reset()
			was_phase = m.phase
		for p in m.all_players():
			audit.body("%s %d" % [TEAMS[venue][(p as Player).team], (p as Player).number if "number" in p else 0],
				(p as Player).global_position, Player.WALK_R)
		for j in m.officials.judges:
			audit.body("judge", (j as Node3D).global_position, Player.WALK_R)
		if m.ritual != null and not m.ritual.done:
			audit.body("elder", m.ritual.elder.global_position, Player.WALK_R)
		if m.ball.held:
			audit.ball_reset()
		else:
			audit.ball(m.ball.pos, Ball.RADIUS)
		audit.tick(dt)
		if f % 10 == 0:
			await tree.process_frame
	# Play seldom sends the ball as far as the props (a ball over a side is called out and runs on only a moment), so
	# then the ball is struck from the court at them: the game's own ball (Ball.step, Court.contact and the props'
	# sweep) at 6-30 m/s, low and high, at the benches, stands, coping, terraces, end walls, posts and houses.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7 + 3
	var ball: Ball = m.ball
	var court: Court = m.court
	for k in SHOTS:
		var from := Vector3(rng.randf_range(-court.half_l() * 0.8, court.half_l() * 0.8), rng.randf_range(0.3, 1.2), rng.randf_range(-1.0, 1.0))
		var across := rng.randf_range(-1.0, 1.0)
		var dir := Vector3(across * 1.5, 0.0, 1.0 if rng.randf() < 0.5 else -1.0) if rng.randf() < 0.8 else Vector3(signf(across), 0.0, across * 0.4)
		dir = dir.normalized()
		var v := dir * rng.randf_range(6.0, 30.0) + Vector3(0, rng.randf_range(0.0, 9.0), 0)
		ball.launch(from, v, 0, null)
		audit.ball_reset()
		for i in 150:
			ball.step(dt)
			audit.ball(ball.pos, Ball.RADIUS)
			audit.tick(dt)
			if ball.dead():
				break
		if k % 4 == 0:
			await tree.process_frame
	return m
