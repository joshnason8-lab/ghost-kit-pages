extends RefCounted
## Every ground's props, for the shared foundation's props audit (tools/wsg/prop_audit.gd; the owner: nobody ever
## walks through a bench, a wall or a flag, and the ball bounces off them): an AI-against-AI match at each ground at
## sim speed, every player's, official's and substitute's place and the ball's after each step of play handed to the
## audit (Match.stepped).
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/prop_audit.gd -- res://game/prop_runs.gd <out> 2 120
## (The night ground is the county ground under its floodlights: the same props.)

const SPEED := 6.0      # Engine.time_scale: the match steps in 0.05 s pieces however fast (Match._process)


static func venues() -> Array:
	return ["parish", "county", "stadium"]


func run(venue: String, seed: int, seconds: float, audit: WsgPropAudit, tree: SceneTree) -> Node:
	var host := Node.new()
	tree.root.add_child(host)
	Game.main = host
	Game.settings.sound = false
	var teams := ["KIL", "TIP", "GAL", "LIM", "COR", "WAT"]
	var home := String(teams[seed % teams.size()])
	var away := String(teams[(seed + 1) % teams.size()])
	Game.start_match({"home": home, "away": away, "venue": venue, "user_team": -1, "seed": seed, "mode": "test"})
	await tree.process_frame
	var m: Node = Game.current
	m.hud.visible = false
	audit.solid = m.stadium.solid
	var ball: Sliotar = m.ball
	var feed := func(dt: float) -> void:
		var people: Array = m.all_players() + m.officials.people + m._leaving
		for p: Player in people:
			if is_instance_valid(p) and p.visible:
				audit.body("%s %d %s" % [p.role if p.role != "" else "team %d" % p.team, p.num, String(p.data.get("name", ""))],
					p.global_position, Player.BODY_R, 1.8)
		if ball.state == Sliotar.FREE or ball.state == Sliotar.OUT:
			audit.ball(ball.global_position, Sliotar.RADIUS)
		else:
			audit.ball_reset()     # (held, carried or put down for a restart: its next flight starts afresh)
		audit.tick(dt)
	m.stepped.connect(feed)
	Engine.time_scale = SPEED
	var t := 0.0
	while t < seconds and is_instance_valid(m):
		await tree.process_frame
		t = float(m.now)
	Engine.time_scale = 1.0
	if is_instance_valid(m):
		m.stepped.disconnect(feed)
		m.set_process(false)     # (held still for the close-ups)
	return host
