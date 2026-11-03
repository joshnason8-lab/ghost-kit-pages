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
