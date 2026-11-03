extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta.

const NOTE := {"id": "2026-11-03-advantage-move-away", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "When there is contact and advantage have the defending player move out of the way."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## Advantage played on a contact against a shooter (test_runner _advantage_clear: the GK on the GS in front of the post,
## the GD on the GA out wide): the defender who made it steps clear, past 1.5 m within 1.5 s, and never between the
## shooter and the post; once the ball has gone she plays on. And the same in every venue, on both sides of the court,
## from either end, for a contact and for an obstruction played as advantage: the defender clear of the shooter (1.5 m
## within 1.5 s) and out of her line to the post.
func check() -> void:
	var h: Node = await Harness.make(tree)
	await h._advantage_clear()
	for venue in ["arena", "hall", "outdoor"]:
		var m: Match = h._study_match(38, {"venue": venue})
		await h._wait_live(m)
		var guard := 0
		while (m.holder == null or m.phase != "live") and guard < 600:
			await frame()
			guard += 1
		for t in 2:
			for case: Array in [["contact", 2.6, 1.6], ["obstruction", 3.2, -1.8], ["contact", 1.8, -0.6]]:
				var gs: Player = m.player_at(t, "GS")
				var gk: Player = m.player_at(1 - t, "GK")
				var post := Court.goal_post(gs.dir)
				m.pass_info = {}
				m.shot_info = {}
				m._release_holder()
				gs.p = post + Vector2(-gs.dir * float(case[1]), float(case[2]))
				gs.vel = Vector2.ZERO
				gs.target = gs.p
				m._give(gs)
				m.ai._decide[gs] = 99.0
				var u := (post - gs.p).normalized()
				gk.p = gs.p + u * 0.7
				gk.vel = Vector2.ZERO
				gk.target = gk.p
				await frame()
				m.hold_t = 0.0
				m._advantage(case[0], gk)
				var when := -1.0
				var between := false
				for f in 60:
					await frame()
					m.hold_t = 0.0
					if when < 0.0 and gk.p.distance_to(gs.p) > 1.5:
						when = (f + 1) / 30.0
					if f >= 45:
						var rel := gk.p - gs.p
						var along := rel.dot(u)
						between = between or (along > 0.0 and along < gs.p.distance_to(post) and absf(rel.cross(u)) < 1.0)
				var what := "%s, team %d's GS %.1f m out, %s played as advantage" % [venue, t, float(case[1]), case[0]]
				info("%s: the GK past 1.5 m in %.2f s, %.1f m off after 2 s" % [what, when, gk.p.distance_to(gs.p)])
				expect(when > 0.0 and when <= 1.5, "%s: the GK does not move out of the way (%.1f m off after 2 s)" % [what, gk.p.distance_to(gs.p)])
				expect(not between, "%s: the GK stays between the shooter and the post" % what)
				m.ai._decide.erase(gs)
		m.queue_free()
		await frame()
		await frame()
	await Harness.into(self, h)
