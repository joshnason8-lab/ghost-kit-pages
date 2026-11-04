extends RefCounted
## Every ground for the foundation's prop audit (tools/wsg/prop_audit.gd: the owner's rule that nobody ever walks through
## a table, a bench, a pole or a barricade): a Watch-AI match at each, every player and official measured every frame
## against the ground's solid things (Arena.solid). Kho kho has no ball.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/prop_audit.gd -- res://game/prop_runs.gd OUT 2 120


static func venues() -> Array:
	return ["maidan", "school", "arena", "floodlit"]


func run(venue: String, seed: int, seconds: float, audit: WsgPropAudit, tree: SceneTree) -> Node:
	Game.main = tree.root
	Game.settings.sound = false
	Game.settings.coach = false
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "MAH", "away": "ODI", "venue": venue, "format": KhoRules.FAST if venue == "arena" else KhoRules.CLASSIC,
		"turn_len": 90.0, "user_team": -1, "seed": seed, "mode": "quick", "watch": true, "test": true, "chase_first": seed % 2}
	tree.root.add_child(m)
	audit.solid = m.arena.solid
	var t := 0.0
	while t < seconds and is_instance_valid(m):
		await tree.process_frame
		var dt := tree.root.get_process_delta_time()
		t += dt
		for a in m.everyone():
			if is_instance_valid(a) and a.is_inside_tree():
				var who := String(a.data.get("name", a.name)) if a.data else String(a.name)
				audit.body(who, a.position, Athlete.BODY_R, 1.8)
		audit.tick(dt)
	return m
