extends RefCounted
## What Kabaddi's owner notes (tests/owner_notes) share: a host for the game's screens, a match started as a button does
## (built at once: no loading overlay), and waiting for its raid.


static func host(tree: SceneTree) -> Node:
	var h := tree.root.get_node_or_null("OwnerNotesHost")
	if h == null:
		h = Node.new()
		h.name = "OwnerNotesHost"
		tree.root.add_child(h)
	Game.main = h
	Game.settings.sound = false
	Game.loading_overlay = false
	FoundationLink.off = true
	return h


static func start(tree: SceneTree, cfg: Dictionary) -> Node:
	host(tree)
	var c := {"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "control": "all", "length": 0, "difficulty": 1}
	c.merge(cfg, true)
	Game.start_match(c)
	return Game.current


static func until_raid(tree: SceneTree, m: Node) -> void:
	var t_end := Time.get_ticks_msec() + 120000
	while is_instance_valid(m) and m.phase != "raid" and Time.get_ticks_msec() < t_end:
		await tree.process_frame


static func frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame
