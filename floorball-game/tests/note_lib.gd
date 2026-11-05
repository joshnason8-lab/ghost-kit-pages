extends RefCounted
## What Floorball's owner-note tests (tests/owner_notes/, WsgOwnerNote) share: a match made the game's own way and
## played until it is live, frames waited, the licensed data's presence. Not a note itself (it lives outside the notes'
## folder: tools/wsg/owner_notes.gd runs every script in there).

const MATCH := "res://game/match.gd"


## A holder for the game's screens (Game.main), once per run.
static func host(tree: SceneTree) -> Node:
	var h: Node = tree.root.get_node_or_null("NoteHost")
	if h == null:
		h = Node.new()
		h.name = "NoteHost"
		tree.root.add_child(h)
	Game.main = h
	Game.settings.sound = false
	return h


## A match from CONFIG (Match.config's keys), in the tree and played until it is live (or GUARD frames).
static func live_match(tree: SceneTree, config: Dictionary, guard := 1800) -> Node:
	var m: Node = (load(MATCH) as Script).new()
	m.config = config
	host(tree).add_child(m)
	var n := 0
	while String(m.phase) != "live" and n < guard:
		await tree.physics_frame
		n += 1
	return m


static func physics(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.physics_frame


static func frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame


static func done(tree: SceneTree, m: Node) -> void:
	if m and is_instance_valid(m):
		m.queue_free()
	await frames(tree, 2)


## The licensed clips and the shared foundation's bodies are here (CI fetches them; a fork's checkout has none).
static func have_foundation() -> bool:
	return FoundationLink.enabled()


## Calls FN(p: Player, body: WsgBody) for every skater on the rink each time the shared foundation's body is posed
## (its skeleton's final pose: read outside it, a skeleton gives back the pose before its modifiers), for N frames of
## play. Returns how many calls were made.
static func each_posed(tree: SceneTree, m: Node, n: int, fn: Callable) -> int:
	var count := [0]
	var hooks := []
	for t in 2:
		for p: Player in m.skaters(t):
			if p.link == null or p.link.body == null:
				continue
			var cb := func():
				if p.visible and p.on_rink:
					count[0] += 1
					fn.call(p, p.link.body)
			p.link.body.posed.connect(cb)
			hooks.append([p.link.body, cb])
	await physics(tree, n)
	for h in hooks:
		if is_instance_valid(h[0]) and (h[0] as Object).is_connected("posed", h[1]):
			(h[0] as Object).disconnect("posed", h[1])
	return count[0]


## The angle (degrees) between two directions.
static func deg(a: Vector3, b: Vector3) -> float:
	if a.length() < 1e-5 or b.length() < 1e-5:
		return 0.0
	return rad_to_deg(a.angle_to(b))


static func pct(values: Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	var v := values.duplicate()
	v.sort()
	return float(v[clampi(int(q * (v.size() - 1)), 0, v.size() - 1)])
