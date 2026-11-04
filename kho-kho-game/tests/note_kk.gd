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


## The foundation's knees rule (WsgNoteChecks.KNEE_BENT / KNEE_BACK, enforced 2026-11-06 12:00): a leg is bent when its
## knee is over 1.5 cm off the hip-ankle line, and a bent knee over 4 cm behind it is backwards.
const KNEE_BENT := 0.015
const KNEE_BACK := 0.04


## Every drawn player's knees for n frames: [legs seen, problems, stats] - a problem is a leg whose knee, bent (over
## KNEE_BENT off the line from his hip to his ankle), stood more than KNEE_BACK behind that line (behind: against the way he
## faces - the game's body's +Z, not the way his toe points: a swinging leg's foot, folded up behind, points back), with
## how often and how far. Read as drawn: in the skeleton's skeleton_updated, after its modifiers (the foot planter's
## legs) - outside it Godot reports the bones without them. Low: ModelBody's skeleton; Medium and High: the
## foundation's body. mixamorig_ names or the plain ones.
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
			hooked.append(sk)
			sk.skeleton_updated.connect(_knee_read.bind(a, sk, stats))
		await tree.process_frame
	for sk in hooked:
		if is_instance_valid(sk):
			for c in sk.skeleton_updated.get_connections():
				if c.callable.get_method() == "_knee_read":
					sk.skeleton_updated.disconnect(c.callable)
	var problems := []
	for who in stats:
		var s: Dictionary = stats[who]
		if int(s.back) > 0:
			problems.append("%s: knee behind the hip-ankle line on %d of %d bent frames, %.0f cm at worst (act '%s')" % [who, s.back, s.bent, float(s.worst) * 100.0, s.act])
	return [stats.size(), problems, stats]


static func _knee_read(a: Node, sk: Skeleton3D, stats: Dictionary) -> void:
	if not is_instance_valid(a) or not sk.is_visible_in_tree():
		return
	var face: Vector3 = a.body.global_transform.basis.z
	var fwd := Vector3(face.x, 0.0, face.z)
	if fwd.length() < 0.001:
		return
	fwd = fwd.normalized()
	for side in ["Left", "Right"]:
		var ix := []
		for b in ["UpLeg", "Leg", "Foot"]:
			var i := sk.find_bone("mixamorig_" + side + b)
			ix.append(i if i >= 0 else sk.find_bone(side + b))
		if ix.has(-1):
			continue
		var X := sk.global_transform
		var H: Vector3 = X * sk.get_bone_global_pose(ix[0]).origin
		var K: Vector3 = X * sk.get_bone_global_pose(ix[1]).origin
		var A: Vector3 = X * sk.get_bone_global_pose(ix[2]).origin
		var axis := (A - H).normalized()
		var off := (K - H) - axis * (K - H).dot(axis)
		if off.length() <= KNEE_BENT:
			continue
		var d := off.dot(fwd)
		var who := "%s %s" % [String(a.data.get("name", a.name)), side.to_lower()]
		var s: Dictionary = stats.get(who, {"bent": 0, "back": 0, "worst": 0.0, "act": ""})
		s.bent += 1
		if d < -KNEE_BACK:
			s.back += 1
			if -d > float(s.worst):
				s.worst = -d
				s.act = String(a.act)
		stats[who] = s
