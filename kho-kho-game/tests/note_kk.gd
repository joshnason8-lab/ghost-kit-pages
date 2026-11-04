extends RefCounted
## Kho Kho's helpers for the owner's notes (tests/owner_notes/): a real match, or a chaser on his own, on Low (the
## A16's level), as the game builds them.

const MatchScript := preload("res://game/match.gd")


static func prepare(tree: SceneTree) -> void:
	Game.main = tree.root
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.graphics = Game.GFX_LOW
	Game.settings.lane_assist = true


## A match built whole, as a Start builds it, run until it is in play. cfg over a quick classic match you chase in.
static func play(tree: SceneTree, cfg := {}) -> Node:
	prepare(tree)
	# ("gfx": a graphics level other than Low, for the one match.)
	if cfg.has("gfx"):
		Game.settings.graphics = int(cfg.gfx)
		cfg = cfg.duplicate()
		cfg.erase("gfx")
	var m: Node = MatchScript.new()
	var c := {"home": "MAH", "away": "ODI", "venue": "school", "format": KhoRules.CLASSIC, "turn_len": 120.0, "user_team": 0,
		"seed": 7, "mode": "quick", "test": true, "chase_first": 0}
	c.merge(cfg, true)
	m.config = c
	tree.root.add_child(m)
	var guard := 0
	while m.phase != "play" and guard < 600:
		await tree.process_frame
		guard += 1
	return m


static func done(tree: SceneTree, m: Node) -> void:
	if is_instance_valid(m):
		m.queue_free()
	Engine.time_scale = 1.0
	await tree.process_frame
	await tree.process_frame


static func frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame


## Every drawn player's knees for n frames, by the foundation's knees rule (WsgNoteChecks.knees, read in
## skeleton_updated: forward from the hips, a leg bent past KNEE_BENT, backwards past KNEE_BACK): [legs seen, {leg:
## {"bent", "back", "run" (longest run of backward frames), "worst" (m), "act"}}]. Low: ModelBody's skeleton; Medium and
## High: the foundation's body.
static func knees(tree: SceneTree, m: Node, n: int) -> Array:
	var stats := {}
	var hooked := []
	for f in n:
		for a in m.find_children("*", "Athlete", true, false):
			var sk: Skeleton3D = null
			if a.link != null and a.link.body != null:
				sk = a.link.body.skeleton
			elif a.body != null:
				sk = a.body.skeleton
			if sk == null or hooked.has(sk):
				continue
			var legs: Array = WsgNoteChecks.leg_bones(sk)
			if legs.is_empty():
				continue
			hooked.append(sk)
			sk.skeleton_updated.connect(_knee_read.bind(a, sk, legs, stats))
		await tree.process_frame
	for sk in hooked:
		if is_instance_valid(sk):
			for c in sk.skeleton_updated.get_connections():
				if c.callable.get_method() == "_knee_read":
					sk.skeleton_updated.disconnect(c.callable)
	return [stats.size(), stats]


static func _knee_read(a: Node, sk: Skeleton3D, legs: Array, stats: Dictionary) -> void:
	if not is_instance_valid(a) or not sk.is_visible_in_tree():
		return
	var read: Array = WsgNoteChecks.knees(sk, legs)
	for i in read.size():
		var front := float(read[i][0])
		if float(read[i][1]) <= WsgNoteChecks.KNEE_BENT:
			continue
		var who := "%s %s" % [String(a.data.get("name", a.name)), "left" if i == 0 else "right"]
		var s: Dictionary = stats.get(who, {"bent": 0, "back": 0, "run": 0, "now": 0, "worst": 0.0, "act": ""})
		s.bent += 1
		if front < -WsgNoteChecks.KNEE_BACK:
			s.back += 1
			s.now += 1
			s.run = maxi(int(s.run), int(s.now))
			if -front > float(s.worst):
				s.worst = -front
				s.act = String(a.act)
		else:
			s.now = 0
		stats[who] = s
