extends RefCounted
## The game's registry for the foundation's props audit (tools/wsg/prop_audit.gd, ADOPTING §5.15): a Watch-AI match at
## each venue, stepped at sim speed, every player, umpire and reserve and the ball handed to the audit every step. It
## fails on any body more than 2 cm into a prop (a bench, a table, a board, a post's pad, a wall, a fence) and on any
## ball step through one.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/prop_audit.gd -- res://tests/prop_runs.gd "$RUNNER_TEMP/prop_audit" 1 240
## Each venue at Medium (the courtside stands, the LED boards and goal lights, the chairs, the reserves), the arena at
## Low as well (its own stands, no chairs). The match is stepped by hand (Match._process, a 30th of a second at a
## time), drawn once every STEPS_A_FRAME of them, so a slow machine plays it as fast as one that draws it.

const STEPS_A_FRAME := 60
const DT := 1.0 / 30.0


static func venues() -> Array:
	return ["arena", "hall", "outdoor", "arena (Low)"]


func run(venue: String, seed: int, seconds: float, audit: WsgPropAudit, tree: SceneTree) -> Node:
	var low := venue.ends_with("(Low)")
	Game.settings.graphics = Game.GFX_LOW if low else Game.GFX_MEDIUM
	var m: Match = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "AUS", "away": "NZL", "venue": venue.get_slice(" ", 0), "user_team": -1, "demo": true, "seed": seed,
		"quarter": 15, "mode": "quick", "headless_hud": true, "need_winner": false}
	tree.root.add_child(m)
	await tree.process_frame
	m.set_process(false)
	# (No replays: they show the play again, not new steps.)
	if m.wsg_replay:
		m.wsg_replay.queue_free()
		m.wsg_replay = null
	audit.solid = m.arena.solid
	var was_state := ""
	for f in int(seconds / DT):
		m._process(DT)
		for t in 2:
			for pl: Player in m.players[t]:
				audit.body("%s %s" % ["home" if t == 0 else "away", pl.pos], Vector3(pl.p.x, 0, pl.p.y), Player.BODY_R, Player.BODY_H)
		for u: Umpire in m.umpires:
			audit.body("umpire %d" % u.half, Vector3(u.p.x, 0, u.p.y), Player.BODY_R, Player.BODY_H)
		# (Gathered each step: a team change rebuilds them.)
		var reserves: Array = []
		var rs := m.get_node_or_null("Reserves")
		if rs:
			for c in rs.get_children():
				if c is Node3D and not (c is FoundationLink):
					reserves.append(c)
		for k in reserves.size():
			# A reserve on her bench: her body over the seat and her lower legs in front of it (Match.reserve_parts),
			# checked, not excused as seated; up clapping a goal, her whole body where she stands.
			var r: Node3D = reserves[k]
			if not is_instance_valid(r):
				continue
			for part: Array in Match.reserve_parts(r):
				audit.body("reserve %d" % k, part[0], part[1], part[2])
		# The ball put somewhere (a restart's spot, the taker's hands): no step from where it was.
		var st: String = m.ball.state
		if st != was_state and (was_state == "dead" or st == "dead"):
			audit.ball_reset()
		was_state = st
		audit.ball(m.ball.pos, Ball.R)
		audit.tick(DT)
		if m.phase == "over":
			break
		if f % STEPS_A_FRAME == 0:
			await tree.process_frame
	return m
