extends SceneTree
## WsgSolidProps: bodies never inside a prop (pushed out, steered round, sent round by a path, their targets moved to
## a free spot), the ball never through one at any speed (a 60 m/s shot at a 2 cm pane, and 3,000 random throws),
## each material's bounce, the hit's sound; the same props as Godot colliders; props found in a scene, opt-outs
## kept with their reason; the audit catching a walk through a bench and a ball through a pane when nothing stops
## them; and the cost of 38 bodies a frame.
##   godot --headless --path . -s tests/solid_props_test.gd

const R := 0.3
const H := 1.8

var fails := []


func _initialize() -> void:
	await process_frame          # (the tree is up from the first frame: register reads nodes' places)
	var solid := _ground()
	_bodies(solid)
	_paths(solid)
	_path_from_touching()
	_ball(solid)
	_ball_path()
	await _physics(solid)
	_register()
	_cost(solid)
	for f in fails:
		printerr("FAIL: ", f)
	print("SOLID PROPS TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


## A ball that bounces off a wall inside a frame (sub-stepped physics), past a camera tripod by the wall - Sepak
## Takraw's mall atrium (0.15.9), its own numbers: the straight line between the frames passes 2.3 cm "into" the
## tripod; the path it took never touches it. With the path given (WsgSimGame.ball's "path"), no tunnel; without it,
## one; and a path whose own step goes through the tripod is still caught.
func _ball_path() -> void:
	var s := WsgSolidProps.new()
	s.add({"name": "tripod", "kind": "cylinder", "position": Vector3(-10.6, 0, 6.75), "radius": 0.36, "height": 1.6})
	s.add({"name": "end wall", "kind": "box", "position": Vector3(-11.6, 0, 6.5), "size": Vector3(1.0, 3.0, 6.0)})
	var r := 0.068
	var a := Vector3(-10.72, 0.69, 6.30)
	var b := Vector3(-10.99, 0.67, 6.57)
	var path := [Vector3(-10.83, 0.685, 6.37), Vector3(-10.93, 0.68, 6.44), Vector3(-11.03, 0.675, 6.50), b]
	var straight := WsgPropAudit.new(s)
	straight.ball(a, r)
	straight.ball(b, r)
	var swept := WsgPropAudit.new(s)
	swept.ball(a, r)
	swept.ball(b, r, "ball", path)
	var through := WsgPropAudit.new(s)
	through.ball(a, r)
	through.ball(b, r, "ball", [Vector3(-10.62, 0.68, 6.45), b])
	print("ball path: the straight line %d tunnel(s), the path swept %d, a path through the tripod %d" % [straight.ball_tunnels, swept.ball_tunnels, through.ball_tunnels])
	if straight.ball_tunnels != 1:
		fails.append("the straight line past the tripod should read as a tunnel (it cuts 2.3 cm in): %d" % straight.ball_tunnels)
	if swept.ball_tunnels != 0:
		fails.append("the bouncing path past the tripod read as a tunnel: %s" % [swept.report().worst])
	if through.ball_tunnels < 1:
		fails.append("a path whose step goes through the tripod was not caught")


## A court's side: a bench, a turned officials' table, a pole, a goal (posts and a crossbar overhead), a glass pane,
## a net, a mat on the floor (stepped over).
func _ground() -> WsgSolidProps:
	var s := WsgSolidProps.new()
	s.add({"name": "bench", "kind": "box", "position": Vector3(0, 0, 6), "size": Vector3(5.0, 0.45, 0.4), "material": "wood"})
	s.add({"name": "table", "kind": "box", "position": Vector3(-6, 0, 3), "yaw": deg_to_rad(30.0), "size": Vector3(1.8, 0.76, 0.8), "material": "wood"})
	s.add({"name": "pole", "kind": "cylinder", "position": Vector3(4, 0, 0), "radius": 0.05, "height": 1.2, "material": "wood"})
	for x in [-1.5, 1.5]:
		s.add({"name": "goal post", "kind": "cylinder", "position": Vector3(x, 0, -8), "radius": 0.05, "height": 2.0, "material": "metal"})
	s.add({"name": "crossbar", "kind": "capsule", "a": Vector3(-1.5, 2.0, -8), "b": Vector3(1.5, 2.0, -8), "radius": 0.05, "material": "metal"})
	s.add({"name": "pane", "kind": "panel", "position": Vector3(8, 0, 4), "size": Vector3(0.02, 1.0, 3.0), "material": "glass"})
	s.add({"name": "net", "kind": "box", "position": Vector3(0, 0, -9), "size": Vector3(3.0, 2.0, 0.05), "material": "net"})
	s.add({"name": "mat", "kind": "box", "position": Vector3(-3, 0, -3), "size": Vector3(2.0, 0.05, 1.0), "material": "padding"})
	s.add({"name": "court", "kind": "floor", "y": 0.0, "material": "wood"})
	s.skip("centre logo", "a decal on the floor")
	return s


func _bodies(s: WsgSolidProps) -> void:
	# Pushed out: a body standing in the middle of the bench.
	var p := s.push_out(Vector3(0.3, 0, 6.05), R, H)
	var pen := s.penetration(p, R, H)
	print("pushed out of the bench to %s (%.3f m in after)" % [p, pen[0]])
	if float(pen[0]) > 0.001 or p.distance_to(Vector3(0.3, 0, 6.05)) > 0.6:
		fails.append("push_out left the body %.3f m in the bench, at %s" % [pen[0], p])
	# Stepped over: the mat.
	if float(s.penetration(Vector3(-3, 0, -3), R, H)[0]) > 0.0:
		fails.append("a 5 cm mat stops a body")
	# Not under the crossbar either (it is over their heads).
	if float(s.penetration(Vector3(0, 0, -8), R, H)[0]) > 0.0:
		fails.append("the crossbar, 2 m up, stops a body walking under it")
	# A target inside the table: the nearest free spot.
	var t := s.free_spot(Vector3(-6, 0, 3), R, H)
	print("a target inside the table moved to %s" % t)
	if float(s.penetration(t, R, H)[0]) > 0.0 or t.distance_to(Vector3(-6, 0, 3)) > 1.3:
		fails.append("free_spot gave %s for a target in the table" % t)
	# Steered: 24 bodies each walking at 6 m/s at a goal straight through a prop, with move(); the audit watches.
	var audit := WsgPropAudit.new(s)
	var stuck := 0
	var cases := [[Vector3(0, 0, 9), Vector3(0, 0, 3)], [Vector3(4, 0, -3), Vector3(4, 0, 3)], [Vector3(-9, 0, 3), Vector3(-3, 0, 3)],
		[Vector3(0, 0, -11), Vector3(0, 0, -5)], [Vector3(11, 0, 4), Vector3(5, 0, 4)], [Vector3(-6, 0, 6), Vector3(-6, 0, 0)]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for c in cases:
		for k in 4:
			var pos: Vector3 = (c[0] as Vector3) + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			var goal: Vector3 = s.free_spot((c[1] as Vector3) + Vector3(rng.randf_range(-0.3, 0.3), 0, 0), R, H)
			var memo := {}
			for f in 240:
				var want := (goal - pos)
				want.y = 0.0
				var v := want.normalized() * minf(6.0, want.length() * 4.0)
				var m := s.move(pos, v, 1.0 / 30.0, R, H, goal, memo)
				pos = m[0]
				audit.body("walker", pos, R, H)
			if pos.distance_to(goal) > 0.5:
				stuck += 1
	var rep := audit.report()
	print("24 walks at a goal through a prop: %d body frames, %d inside a prop, %d not there in 8 s" % [rep.body_checks, rep.body_cases, stuck])
	if rep.body_cases > 0:
		fails.append("steered walkers went into props: %s" % [rep.worst])
	if stuck > 0:
		fails.append("%d of 24 steered walkers did not reach their goal round the prop" % stuck)
	# The audit sees a walk straight through the bench (nothing stopping it).
	var naive := WsgPropAudit.new(s)
	for f in 60:
		naive.body("ghost", Vector3(0, 0, 9).lerp(Vector3(0, 0, 3), f / 59.0), R, H)
	if naive.body_cases == 0:
		fails.append("the audit missed a body walking through the bench")


func _paths(s: WsgSolidProps) -> void:
	# An out-of-play walk from behind the bench to in front of it, and round the table: the way clear, B last.
	for pair in [[Vector3(0.2, 0, 8), Vector3(0.4, 0, 4)], [Vector3(-8, 0, 1.5), Vector3(-4, 0, 4.5)]]:
		var a: Vector3 = pair[0]
		var way := s.path(a, pair[1], R, H)
		var prev := a
		var worst := 0.0
		var length := 0.0
		for w in way:
			for k in 21:
				worst = maxf(worst, float(s.penetration(prev.lerp(w, k / 20.0), R, H)[0]))
			length += prev.distance_to(w)
			prev = w
		print("path %s -> %s: %d waypoints, %.1f m, deepest %.3f m" % [a, pair[1], way.size(), length, worst])
		if worst > 0.005 or way.is_empty() or way[way.size() - 1].distance_to(pair[1]) > 0.8:
			fails.append("path %s -> %s: %s (deepest %.3f)" % [a, pair[1], way, worst])


## A walk starting against a prop (a door beside a bench seat, the body brushing it): it steps out, then goes round -
## never the straight way through (Floorball's fetch: path() gave the line through the 0.465 m seat).
func _path_from_touching() -> void:
	var s := WsgSolidProps.new()
	s.add({"kind": "box", "name": "near bench seat", "size": Vector3(2.0, 0.465, 0.42), "position": Vector3(2.2, 0, 11.3)})
	var a := Vector3(2.2, 0, 10.8)
	var b := Vector3(0, 0, 15.3)
	for r in [0.3, 0.35]:
		var way := s.path(a, b, r, H)
		var worst := 0.0
		# (From the start: no deeper than the overlap it starts in.)
		var start_pen := float(s.penetration(a, r, H)[0])
		var prev := a
		for w in way:
			for k in 21:
				worst = maxf(worst, float(s.penetration(prev.lerp(w, k / 20.0), r, H)[0]) - start_pen)
			prev = w
		print("path from touching the seat (radius %.2f): %s, deepest past its start %.3f m" % [r, way, worst])
		if way.is_empty() or worst > 0.005 or way[way.size() - 1].distance_to(b) > 0.8:
			fails.append("path from touching the seat (radius %.2f): %s (deepest %.3f)" % [r, way, worst])


func _ball(s: WsgSolidProps) -> void:
	# A 60 m/s shot at a 2 cm pane, a frame at 30 fps covering 2 m: it bounces back, glass's restitution, a knock.
	var heard := []
	var r := s.bounce(Vector3(6, 0.5, 4), Vector3(60, 0, 0), 0.11, 1.0 / 30.0, func(h): heard.append([h.material, h.sound, snappedf(h.speed, 0.1)]))
	print("60 m/s at the 2 cm pane: at %s, %s m/s after; heard %s" % [r.pos, r.vel, heard])
	if (r.pos as Vector3).x > 8.0 - 0.01 - 0.11 + 0.003 or (r.vel as Vector3).x > -44.0 or (r.vel as Vector3).x < -46.0:
		fails.append("the shot at the pane: at %s, %s m/s (want before it, -45 m/s)" % [r.pos, r.vel])
	if heard.size() != 1 or heard[0][0] != "glass" or heard[0][1] != "hit":
		fails.append("the pane's knock: %s" % [heard])
	# The net takes the pace off; padding more than wood.
	var into_net := s.bounce(Vector3(0, 1, -7), Vector3(0, 0, -20), 0.11, 0.2)
	print("20 m/s into the net: %s m/s back" % (into_net.vel as Vector3).z)
	if (into_net.vel as Vector3).z < 0.0 or (into_net.vel as Vector3).z > 2.5:
		fails.append("the net gave back %s m/s of 20" % (into_net.vel as Vector3).z)
	# The crossbar: a ball up into it comes down.
	var bar := s.bounce(Vector3(0, 1.6, -8), Vector3(0, 15, 0), 0.11, 0.1)
	if (bar.vel as Vector3).y >= 0.0:
		fails.append("a ball up into the crossbar went on up: %s" % bar.vel)
	# A netball ring (0.2 m, 11 mm tube) at 3.05 m: a ball (0.11) dropped through its middle goes through; one onto the
	# tube comes off it.
	var ring := WsgSolidProps.new()
	ring.add_ring({"centre": Vector3(0, 3.05, 0), "radius": 0.2, "tube": 0.011})
	var through := ring.bounce(Vector3(0, 3.6, 0), Vector3(0, -6, 0), 0.11, 0.2)
	var onto := ring.bounce(Vector3(0.2, 3.6, 0), Vector3(0, -6, 0), 0.11, 0.2)
	print("a ring: dropped through the middle %s (%d hits); onto the tube %s, %s m/s" % [through.pos, through.hits.size(), onto.pos, onto.vel])
	if through.hits.size() != 0 or onto.hits.size() == 0 or (onto.vel as Vector3).y <= 0.0:
		fails.append("the ring: through the middle %d hits, onto the tube %s" % [through.hits.size(), onto.vel])
	# 3,000 random throws, up to 50 m/s, under gravity, 2 s each at 30 fps: never through a prop (the audit), never
	# left inside one.
	var audit := WsgPropAudit.new(s)
	var naive := WsgPropAudit.new(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bounces := 0
	var inside := 0
	for n in 3000:
		var p := Vector3(rng.randf_range(-12, 12), rng.randf_range(0.2, 2.5), rng.randf_range(-12, 12))
		if s.sweep(p, p, 0.11).hit:
			continue
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 0.6), rng.randf_range(-1, 1)).normalized() * rng.randf_range(5, 50)
		var q := p
		var w := v
		audit.ball_reset()
		naive.ball_reset()
		for f in 60:
			w.y -= 9.8 / 30.0
			v.y -= 9.8 / 30.0
			var b := s.bounce(p, v, 0.11, 1.0 / 30.0)      # (the floor is a prop: no clamp of the game's after it)
			p = b.pos
			v = b.vel
			bounces += (b.hits as Array).size()
			audit.ball(p, 0.11)
			if float(s.sweep(p, p, 0.11).get("depth", 0.0)) > 0.005:
				inside += 1
			q += w / 30.0
			if q.y < 0.11:
				q.y = 0.11
				w.y = absf(w.y) * 0.6
			naive.ball(q, 0.11)
	print("3,000 throws: %d bounces off props, %d steps through one (%d left inside); with no props in the way, the audit counts %d" % [bounces, audit.ball_tunnels, inside, naive.ball_tunnels])
	if audit.ball_tunnels > 0 or inside > 0:
		fails.append("balls went through props: %d (left inside %d): %s" % [audit.ball_tunnels, inside, audit.report().worst.slice(0, 3)])
	if naive.ball_tunnels == 0:
		fails.append("the audit missed balls going straight through props")


func _physics(s: WsgSolidProps) -> void:
	# The same props as Godot colliders, on the props layer, each material's bounce.
	var holder := Node3D.new()
	root.add_child(holder)
	var bodies := s.make_bodies(holder)
	var pane: StaticBody3D = null
	for b: StaticBody3D in bodies:
		if b.name.begins_with("Solid_pane"):
			pane = b
	print("make_bodies: %d colliders on layer bit %d" % [bodies.size(), bodies[0].collision_layer])
	if bodies.size() != s.props.size() or bodies[0].collision_layer != 1 << (WsgSolidProps.PROPS_LAYER - 1):
		fails.append("make_bodies made %d of %d, layer %d" % [bodies.size(), s.props.size(), bodies[0].collision_layer])
	if pane == null or absf(pane.physics_material_override.bounce - 0.75) > 0.001:
		fails.append("the pane's collider has not glass's bounce")
	holder.queue_free()


func _register() -> void:
	# A scene: a bench and a goal post, the ground (left: named), a painted line (left: flat), a banner opted out with
	# its reason, three chairs in a MultiMesh (three boxes).
	var sc := Node3D.new()
	root.add_child(sc)
	var meshes := [["bench", Vector3(3, 0.45, 0.4), Vector3(0, 0.225, 0)], ["goal post", Vector3(0.1, 2.0, 0.1), Vector3(5, 1, 0)],
		["ground", Vector3(40, 0.1, 20), Vector3(0, -0.05, 0)], ["centre line", Vector3(0.1, 0.01, 20), Vector3(0, 0.005, 0)],
		["sponsor banner", Vector3(6, 1, 0.05), Vector3(0, 4, 10)]]
	for m in meshes:
		var mi := MeshInstance3D.new()
		mi.name = m[0]
		var bm := BoxMesh.new()
		bm.size = m[1]
		mi.mesh = bm
		mi.position = m[2]
		sc.add_child(mi)
		if m[0] == "sponsor banner":
			mi.set_meta("wsg_solid", false)
			mi.set_meta("wsg_solid_reason", "hung 4 m up over the stand")
	var mm := MultiMeshInstance3D.new()
	mm.name = "chairs"
	mm.multimesh = MultiMesh.new()
	mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var cm := BoxMesh.new()
	cm.size = Vector3(0.45, 0.85, 0.45)
	mm.multimesh.mesh = cm
	mm.multimesh.instance_count = 3
	for k in 3:
		mm.multimesh.set_instance_transform(k, Transform3D(Basis(Vector3.UP, 0.3 * k), Vector3(-4 + k, 0.425, 2)))
	sc.add_child(mm)
	var s := WsgSolidProps.new()
	var n := s.register(sc)
	var mats := {}
	for p in s.props:
		mats[p.name] = p.material
	print("register: %d props %s; left out %s" % [n, mats, s.skipped])
	if n != 5 or mats.get("bench") != "wood" or mats.get("goal post") != "metal" or mats.get("chairs") != "plastic":
		fails.append("register found %d (want 5: bench, post, 3 chairs) %s" % [n, mats])
	if s.skipped.size() != 1 or s.skipped[0].reason != "hung 4 m up over the stand":
		fails.append("the opted-out banner's reason was not kept: %s" % [s.skipped])
	sc.queue_free()


func _cost(s: WsgSolidProps) -> void:
	# 38 bodies (two teams, officials, benches) moving among the props, each with move(), for 300 frames.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var pos := []
	var goal := []
	for i in 38:
		pos.append(Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)))
		goal.append(s.free_spot(Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)), R, H))
	for i in 38:
		pos[i] = s.free_spot(pos[i], R, H)
	var t0 := Time.get_ticks_usec()
	for f in 300:
		for i in 38:
			var want: Vector3 = goal[i] - pos[i]
			if want.length() < 0.3:
				goal[i] = s.free_spot(Vector3(rng.randf_range(-10, 10), 0, rng.randf_range(-10, 10)), R, H)
				continue
			var m := s.move(pos[i], want.normalized() * 6.0, 1.0 / 30.0, R, H, goal[i])
			pos[i] = m[0]
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 300.0
	print("38 bodies a frame among %d props: %.2f ms a frame (this computer; a phone some times that)" % [s.props.size(), ms])
	if ms > 3.0:
		fails.append("38 bodies cost %.2f ms a frame" % ms)
