extends RefCounted
## Floorball's registry for the shared prop audit (tools/wsg/prop_audit.gd, ADOPTING 5.15): its three venues, and in
## each a Watch-AI match played on the game's own code feeding the audit every frame - every person on the rink, on
## the benches and in the penalty benches (their bodies 0.28 m round, 1.8 m tall), and the ball - against the venue's
## props as the hall declares them (Arena.solid). It fails on a body in a prop (over 2 cm) or a ball through one.
##   xvfb-run -a godot --path . -s res://tools/wsg/prop_audit.gd -- res://game/prop_runs.gd "$RUNNER_TEMP/prop_audit" 2 60

const MATCH := "res://game/match.gd"


static func venues() -> Array:
	return ["arena", "hall", "school"]


func run(venue: String, seed: int, seconds: float, audit: WsgPropAudit, tree: SceneTree) -> Node:
	var host: Node = tree.root.get_node_or_null("PropRunsHost")
	if host == null:
		host = Node.new()
		host.name = "PropRunsHost"
		tree.root.add_child(host)
	Game.main = host
	Game.settings.sound = false
	var m: Node = (load(MATCH) as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": venue, "user_team": -1, "demo": true, "seed": seed, "period": 4.0, "mode": "quick"}
	host.add_child(m)
	audit.solid = m.arena.solid
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var last := Vector3.INF
	for f in int(seconds / dt):
		await tree.physics_frame
		var people: Array = m.everyone() + m.sitters[0] + m.sitters[1]
		for p: Player in people:
			if p.visible:
				audit.body("%s %s%d" % ["ref" if p.role == "R" else ("home" if p.team == 0 else "away"), p.role, p.slot],
					Vector3(p.pos.x, 0.0, p.pos.y), Player.BODY_R, 1.8)
		var b: Vector3 = m.ball.pos
		# (Put somewhere new - a restart, a hit-in, held by the goalkeeper, on a stick - is not a flight through anything.)
		if last == Vector3.INF or b.distance_to(last) > 2.0 or m.ball.carrier != null or m.ball.held_by != null:
			audit.ball_reset()
		audit.ball(b, Ball.R)
		last = b
		audit.tick(dt)
	return m
