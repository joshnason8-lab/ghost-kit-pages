extends RefCounted
## Every ground's props audited over the game's own matches (the owner: "There will NEVER be a time when a player or
## referee should walk through a table or bench"): tools/wsg/prop_audit.gd plays Watch-AI matches here at sim speed and
## checks every body on its feet against the ground's WsgSolidProps each frame (Arena.solid; no ball in kabaddi).
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/prop_audit.gd -- res://game/prop_runs.gd "$RUNNER_TEMP/prop_audit" 2 120
## Bodies sitting down (the out players on their bench, the scorers at their table) are not walking: not checked.


static func venues() -> Array:
	return ["dome", "stadium", "village", "monsoon", "beach"]


func run(venue: String, seed: int, seconds: float, audit: WsgPropAudit, tree: SceneTree) -> Node:
	var host := Node.new()
	host.name = "PropRun"
	tree.root.add_child(host)
	Game.main = host
	Game.settings.sound = false
	Game.loading_overlay = false
	Game.start_match({"home": "MUM", "away": "PUN", "arena": venue, "mode": "quick", "length": 2, "difficulty": 2,
		"autoplay": true, "autoplay_no_report": true, "seed": seed})
	var m: Node = Game.current
	audit.solid = m.arena.solid
	Engine.time_scale = 3.0
	var t := 0.0
	while t < seconds and is_instance_valid(m) and m.is_inside_tree():
		await tree.process_frame
		var dt := tree.root.get_process_delta_time()
		t += dt
		var bodies: Array = m.athletes.duplicate()
		bodies.append_array(m.officials.find_children("*", "Athlete", false, false))
		for a in bodies:
			if not is_instance_valid(a) or a.state == "sit" or a in m.officials.scorers:
				continue
			# Still rising from the bench (his hips over the seat as he stands): not yet on his feet.
			if a.model and a.model.seated > 0.1:
				continue
			audit.body("%s (%s)" % [a.name, a.state], a.position, Athlete.PROP_R, 1.8)
		audit.tick(dt)
	Engine.time_scale = 1.0
	return host
