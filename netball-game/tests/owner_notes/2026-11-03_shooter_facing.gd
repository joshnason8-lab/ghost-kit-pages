extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta.

const NOTE := {"id": "2026-11-03-shooter-facing", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "There are times when a player is shooting that the woman is facing the wrong direction and not at the hoop."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## Every shot in AI matches in the arena and the sports hall, on Low (the game's own bodies) and on Medium (the shared
## foundation's, with the licensed clips): the shooter's body as drawn faces the post from her set to the release,
## within 20 degrees, at least three shots each (test_runner _shots_and_hands). And every shot the AI takes from
## anywhere in either circle, both ends: set up there by hand, she squares up to the post (within 20 degrees) before
## the ball leaves her hands.
func check() -> void:
	var h: Node = await Harness.make(tree)
	# Shots from all over each circle, at both ends, on Low.
	Game.settings.graphics = Game.GFX_LOW
	var m: Match = h._study_match(71)
	await h._wait_live(m)
	var worst := 0.0
	var worst_at := ""
	var n := 0
	var measured := [0]
	for t in 2:
		for spot: Vector2 in [Vector2(-4.5, 0.0), Vector2(-3.0, 3.2), Vector2(-3.0, -3.2), Vector2(-1.2, 4.3), Vector2(-1.2, -4.3), Vector2(-1.0, 0.0), Vector2(-2.2, 1.5)]:
			var gs: Player = m.player_at(t, "GS")
			var post := Court.goal_post(gs.dir)
			m.pass_info = {}
			m.shot_info = {}
			m._release_holder()
			gs.p = post + Vector2(spot.x * gs.dir, spot.y)
			gs.vel = Vector2.ZERO
			gs.target = gs.p
			# She turns as she would have caught it: facing her own half.
			gs.facing = atan2(-gs.dir, 0.0)
			m._give(gs)
			m.ai._decide[gs] = 99.0
			m.shoot()
			var seen := 0.0
			for f in 40:
				await frame()
				if gs.act == "shoot" and gs.has_ball() and gs.act_t >= 0.25:
					var bz: Vector3 = gs.body.global_transform.basis.z
					var err := absf(rad_to_deg(angle_difference(atan2(bz.x, bz.z), atan2(post.x - gs.p.x, post.y - gs.p.y))))
					seen = maxf(seen, err)
					measured[0] += 1
				if not gs.has_ball():
					break
			n += 1
			if seen > worst:
				worst = seen
				worst_at = "team %d, %s from the post" % [t, spot]
			m.ai._decide.erase(gs)
			for f in 20:
				await frame()
	info("shots set up all over both circles: %d, the shooter %.0f deg off the post at most (%s)" % [n, worst, worst_at])
	expect(int(measured[0]) >= 100, "the shots set up were hardly seen (%d frames)" % measured[0])
	expect(worst <= 20.0, "a shooter %.0f deg off the post as she shoots (%s)" % [worst, worst_at])
	m.queue_free()
	await frame()
	# Every shot in AI matches (its hands checks are the hands note's).
	await h._shots_and_hands()
	await Harness.into_only(self, h, ["faces the post"])
