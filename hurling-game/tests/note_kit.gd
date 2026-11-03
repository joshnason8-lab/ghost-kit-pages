extends RefCounted
## What Hurling's owner notes (tests/owner_notes/, the shared foundation's WsgOwnerNote) share: a match or a practice
## started as the game starts one, frames run, and the measures more than one note takes (the hurley against the
## trunk, the drawn bodies).


static func frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame


## A match (mode "test" unless config says) added to the tree and run N frames. Free it with done().
static func match(tree: SceneTree, config: Dictionary, n := 10, practice := false) -> Node:
	var cfg := {"home": "KIL", "away": "TIP", "venue": "county", "user_team": -1, "seed": 5, "length": 4.0, "mode": "test"}
	cfg.merge(config, true)
	var m: Node = load("res://game/practice.gd" if practice or String(cfg.mode) == "practice" else "res://game/match.gd").new()
	m.config = cfg
	m.set_meta("test", true)
	tree.root.add_child(m)
	await frames(tree, n)
	return m


static func done(tree: SceneTree, m: Node) -> void:
	if is_instance_valid(m):
		m.queue_free()
	if Game.has_meta("practice_gfx"):
		Game.remove_meta("practice_gfx")
	await frames(tree, 3)


## Every drawn body of a match: [who, the shared foundation's WsgBody] (players, officials).
static func bodies(m: Node) -> Array:
	var out := []
	for p in m.all_players() + m.officials.people:
		var pl := p as Player
		if pl.visible and pl.link and pl.link.body:
			out.append(["%s %d" % [pl.role if pl.role != "" else "team %d" % pl.team, pl.num], pl.link.body])
	return out


## How far the hurley, as drawn, stays off the trunk (m; negative: into it): its shaft and bas (from a hand's breadth
## past the top hand) against the body's torso capsule (WsgBody.torso_capsule). Read it in posed (watch()).
static func stick_clearance(link: FoundationLink) -> float:
	if link == null or link.stick == null or not link.stick.visible or link.stick.mesh == null:
		return INF
	var ab := link.stick.mesh.get_aabb()
	var ax := ab.get_longest_axis_index()
	var c := ab.get_center()
	var half := Vector3.ZERO
	half[ax] = ab.size[ax] * 0.5
	var xf := link.stick.global_transform
	var s0: Vector3 = xf * (c - half)
	var s1: Vector3 = xf * (c + half)
	# (From a hand's breadth past the top hand to the bas: the handle in the fists is held against the body.)
	var hand := link.body.bone_world("RightHand").origin
	if s0.distance_to(hand) > s1.distance_to(hand):
		var sw := s0
		s0 = s1
		s1 = sw
	var along := (s1 - s0).normalized()
	s0 = hand + along * 0.2
	var cap := link.body.torso_capsule()
	var pts := Geometry3D.get_closest_points_between_segments(s0, s1, cap[0], cap[1])
	var thick := 0.0
	for i in 3:
		if i != ax:
			thick = maxf(thick, ab.size[i] * 0.5 * xf.basis.get_scale()[i])
	return (pts[0] as Vector3).distance_to(pts[1]) - float(cap[2]) - minf(thick, 0.03)


## F(body) called each time BODY is posed, with its final pose readable (bone_world): the skeleton's modifiers' result
## is only there while it emits posed - after, the bones read as the motion clip left them, before the game's own moves,
## the planted feet and the hands on the hurley. Returns the connection, for unwatch().
static func watch(body: WsgBody, f: Callable) -> Callable:
	var cb := func() -> void: f.call(body)
	body.posed.connect(cb)
	return cb


static func unwatch(body: WsgBody, cb: Callable) -> void:
	if is_instance_valid(body) and body.posed.is_connected(cb):
		body.posed.disconnect(cb)


## A hinge's bend, signed (the foundation's rig_test's): positive the right way.
static func bend(body: WsgBody, a: String, b: String, c: String, axis_local: Vector3) -> float:
	var ga := body.bone_world(a)
	var u := (body.bone_world(b).origin - ga.origin).normalized()
	var f := (body.bone_world(c).origin - body.bone_world(b).origin).normalized()
	return rad_to_deg(u.signed_angle_to(f, (ga.basis * axis_local).normalized()))
