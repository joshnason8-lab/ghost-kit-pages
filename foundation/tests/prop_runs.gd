extends RefCounted
## The foundation's own registry for tools/prop_audit.gd (a game's is the same shape: its venues, and a Watch-AI match
## at each feeding the audit): a court with a bench, a scorers' table, a pole, a goal, a glass pane and its floor;
## ten bodies chasing points across it (some behind props) with WsgSolidProps.move, a ball shot about with bounce.
##   godot --headless --path . -s res://tools/prop_audit.gd -- res://tests/prop_runs.gd /tmp/wsg_prop_audit 1 20
## WSG_PROPS_IGNORED=1: the runners walk straight through the props (the audit must fail it).


static func venues() -> Array:
	return ["test court"]


func run(_venue: String, seed: int, seconds: float, audit: WsgPropAudit, tree: SceneTree) -> Node:
	var s := WsgSolidProps.new()
	var scene := Node3D.new()
	tree.root.add_child(scene)
	var props := [
		{"name": "bench", "kind": "box", "position": Vector3(0, 0, 6), "size": Vector3(5.0, 0.45, 0.4), "material": "wood"},
		{"name": "scorers' table", "kind": "box", "position": Vector3(-6, 0, 3), "yaw": 0.5, "size": Vector3(1.8, 0.76, 0.8), "material": "wood"},
		{"name": "pole", "kind": "cylinder", "position": Vector3(4, 0, 0), "radius": 0.05, "height": 1.2},
		{"name": "post L", "kind": "cylinder", "position": Vector3(-1.5, 0, -8), "radius": 0.05, "height": 2.0, "material": "metal"},
		{"name": "post R", "kind": "cylinder", "position": Vector3(1.5, 0, -8), "radius": 0.05, "height": 2.0, "material": "metal"},
		{"name": "crossbar", "kind": "capsule", "a": Vector3(-1.5, 2, -8), "b": Vector3(1.5, 2, -8), "radius": 0.05, "material": "metal"},
		{"name": "pane", "kind": "panel", "position": Vector3(8, 0, 4), "size": Vector3(0.02, 1.0, 3.0), "material": "glass"},
		{"name": "floor", "kind": "floor", "y": 0.0}]
	for p in props:
		s.add(p)
		if p.kind == "box" or p.kind == "panel":
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = p.size
			mi.mesh = bm
			mi.position = (p.position as Vector3) + Vector3.UP * (p.size as Vector3).y * 0.5
			mi.rotation.y = float(p.get("yaw", 0.0))
			scene.add_child(mi)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 14, 16)
	scene.add_child(cam)
	cam.look_at(Vector3.ZERO)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	scene.add_child(sun)
	audit.solid = s
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pos := []
	var goal := []
	var memo := []
	for i in 10:
		pos.append(s.free_spot(Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)), 0.3))
		goal.append(s.free_spot(Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)), 0.3))
		memo.append({})
	var ball := Vector3(0, 1, 0)
	var bv := Vector3(20, 4, 9)
	var dt := 1.0 / 30.0
	for f in int(seconds / dt):
		for i in 10:
			var want: Vector3 = goal[i] - pos[i]
			if want.length() < 0.4:
				goal[i] = s.free_spot(Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)), 0.3)
				continue
			if OS.has_environment("WSG_PROPS_IGNORED"):
				# (The audit's own check: runners that ignore the props must be caught.)
				pos[i] = pos[i] + want.normalized() * 6.0 * dt
			else:
				var m := s.move(pos[i], want.normalized() * 6.0, dt, 0.3, 1.8, goal[i], memo[i])
				pos[i] = m[0]
			audit.body("runner %d" % i, pos[i], 0.3, 1.8)
		bv.y -= 9.8 * dt
		var b := s.bounce(ball, bv, 0.11, dt)
		ball = b.pos
		bv = b.vel
		if bv.length() < 2.0 or absf(ball.x) > 14.0 or absf(ball.z) > 14.0:
			# A new shot from the middle: the ball put there, not moved through the props.
			ball = Vector3(rng.randf_range(-3, 3), 1.0, rng.randf_range(-3, 3))
			bv = Vector3(rng.randf_range(-1, 1), rng.randf_range(0, 0.4), rng.randf_range(-1, 1)).normalized() * rng.randf_range(8, 40)
			audit.ball_reset()
		audit.ball(ball, 0.11)
		audit.tick(dt)
		if f % 300 == 0:
			await tree.process_frame
	return scene
