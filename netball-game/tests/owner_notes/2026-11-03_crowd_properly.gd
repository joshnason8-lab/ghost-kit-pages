extends WsgOwnerNote
## The owner (relayed by the lead to every game), 2026-11-03.

const NOTE := {"id": "2026-11-03-crowd-properly", "game": "netball", "date": "2026-11-03", "version": "0.9.0-beta (every game)",
	"words": "Look at all maps/arenas that have different standing/sitting and make sure the crowd is sitting properly (body not standing awkwardly inside the seat), watching the game properly, facing the right direction, standing properly."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## Every venue the game registers (game/crowd_venues.gd: the arena on Medium/High and on Low, the sports hall, the
## park court), its crowd built at Medium's and High's quality and audited fan by fan by the shared foundation
## (WsgCrowdVenue.audit, every fan: the seat of the trousers on the seat, soles on the floor, nothing into a seat,
## seat back, step or barrier, each body facing the play's nearest part within 35 degrees, nobody backwards; seated and
## standing frames, getting up where they sit), and as Low's cards (WsgCrowdCards.audit); then in real matches on Low
## and High in all three venues (test_runner _crowd_facing): every spectator as drawn faces the court, sits on a seat
## or stands on the ground, and only those right by a camera are left out. And they watch the game: each 3D fan's
## head turns to the ball as it moves from end to end.
func check() -> void:
	var reg: GDScript = load("res://game/crowd_venues.gd")
	var sv := SubViewport.new()
	sv.size = Vector2i(64, 64)
	sv.own_world_3d = true
	tree.root.add_child(sv)
	for quality in [1, 2]:
		for entry in reg.venues():
			var name: String = entry.name
			var venue: WsgCrowdVenue = entry.venue
			var crowd := WsgCrowd3D.new()
			sv.add_child(crowd)
			crowd.build_venue(venue, quality, venue.play_centre, 1.0, 7)
			var res := WsgCrowdVenue.audit(crowd, venue, 0)
			var cards := WsgCrowdCards.new()
			sv.add_child(cards)
			cards.build(crowd.placed, PackedInt32Array(), 7)
			var low: Dictionary = cards.audit(venue, crowd.placed)
			var what := "%s (quality %d)" % [name, quality]
			var worst := []
			for s in res.sections:
				var r: Dictionary = res.sections[s]
				worst.append("%s: %d fans, inside %.3f m, facing <= %.0f deg, backwards %d" % [s, r.fans, r.inside, r.facing, r.backwards])
			info("%s: %d fans audited; %s" % [what, res.fans, "; ".join(worst)])
			expect(int(res.fans) > 0, "%s: no fans to audit" % what)
			for f in res.fails:
				fail("%s: %s" % [what, f])
			for f in low.fails:
				fail("%s, Low cards: %s" % [what, f])
			crowd.queue_free()
			cards.queue_free()
			await frame()
	sv.queue_free()
	var h: Node = await Harness.make(tree)
	await h._crowd_facing()
	# Watching the game: the 3D fans' look (the crowd shader's "ball") follows the match's ball through play.
	Game.settings.graphics = Game.GFX_MEDIUM
	for venue in ["arena", "hall", "outdoor"]:
		var m: Match = h._study_match(5, {"venue": venue})
		await h._wait_live(m)
		var crowds := m.find_children("*", "Crowd", true, false)
		var off := 0.0
		var n := 0
		var lo := INF
		var hi := -INF
		for f in 600:
			await frame()
			for c: Crowd in crowds:
				if c.people == null or c.people.materials.is_empty():
					continue
				var looked: Vector3 = c.people.materials[0].get_shader_parameter("ball")
				var b := m.ball.global_position
				off += Vector2(looked.x - b.x, looked.z - b.z).length()
				n += 1
				lo = minf(lo, looked.x)
				hi = maxf(hi, looked.x)
		var mean := off / maxf(1.0, n)
		info("%s (Medium): the fans' look %.1f m from the ball on average, over %.0f m of the court" % [venue, mean, hi - lo])
		expect(n > 0 and mean < 3.0 and hi - lo > 5.0, "%s (Medium): the fans do not follow the ball (%.1f m off it on average, their look over %.0f m; %d samples)" % [venue,
			mean, hi - lo, n])
		m.queue_free()
		await frame()
	await Harness.into(self, h)
