extends WsgOwnerNote
## The owner (relayed by the lead), 2026-11-02 (Hurling 0.18.0): "put pants on the refs"

const NOTE := {"id": "2026-11-02-pants-on-refs", "game": "hurling", "date": "2026-11-02", "version": "Hurling 0.18.0", "words": "put pants on the refs"}
const Kit := preload("res://tests/note_kit.gd")

## The referee and the linesmen in full-length trousers (the hurlers' model in the officials' long kit), the umpires
## in their white coats: none drawn in shorts and bare legs.
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "test"}, 10)
	var n := 0
	for p in m.officials.people:
		var o := p as Player
		if o.link == null:
			fail("%s is not drawn on the shared model" % o.role)
			continue
		var kit: Dictionary = o.link._official_kit()
		n += 1
		if o.role in ["referee", "linesman"]:
			expect(bool(kit.get("long_kit", false)), "the %s in shorts (no long kit)" % o.role)
	info("%d officials checked" % n)
	expect(n >= 3, "only %d officials" % n)
	await Kit.done(tree, m)
