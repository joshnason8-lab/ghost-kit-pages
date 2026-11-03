extends WsgOwnerNote
## The owner, 2026-11-03, on 0.9.0-beta.

const NOTE := {"id": "2026-11-03-penalty-spacing", "game": "netball", "date": "2026-11-03", "version": "0.9.0-beta",
	"words": "During penalties or obstructions the defender is almost on top of the passer, change that if its not realistic."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const BESIDE := 1.2     # m between their middles: beside her, an arm's length and more off, not touching or crowding
const MARK := 0.9       # m: every other defender at least the obstruction distance from the thrower (R13)


## Every penalty pass awarded for contact or obstruction, all over the court, both ways (set up by hand: the defender
## right on the thrower, as the call finds her) and every one in AI matches in all three venues: from when the thrower
## has the ball on her spot to the release, the penalised player stands beside her (BESIDE or more between them, never
## in front of her toward the goal she attacks), and every other opponent is MARK or more from her.
func check() -> void:
	var h: Node = await Harness.make(tree)
	var seen := 0
	for venue in ["arena", "hall", "outdoor"]:
		var m: Match = h._study_match(101, {"venue": venue})
		await h._wait_live(m)
		# Set up by hand: a contact and an obstruction by each of the defenders, at spots all over the court.
		var cases := [["GK", "GS", Vector2(10.0, 2.0), "contact"], ["GD", "GA", Vector2(8.0, -4.0), "obstruction"],
			["WD", "WA", Vector2(3.0, 6.5), "obstruction"], ["C", "C", Vector2(-1.0, 0.0), "contact"],
			["WA", "WD", Vector2(-6.0, -6.0), "obstruction"], ["GS", "GK", Vector2(-12.0, 1.0), "contact"]]
		for c: Array in cases:
			for t in 2:
				var by: Player = m.player_at(1 - t, c[0])
				var on: Player = m.player_at(t, c[1])
				if by == null or on == null or by.away() or on.away():
					continue
				var guard := 0
				while m.phase != "live" and guard < 300:
					await frame()
					guard += 1
				var at := Vector2(float(c[2].x) * on.dir, c[2].y)
				m.pass_info = {}
				m.shot_info = {}
				m._release_holder()
				on.p = at
				on.vel = Vector2.ZERO
				on.target = at
				by.p = at + Vector2(-on.dir * 0.6, 0.15)
				by.vel = Vector2.ZERO
				by.target = by.p
				await frame()
				m._infringe(c[3], by, at)
				var r: Array = await _watch(m, "%s, set up: %s's %s on the %s, %s" % [venue, c[0], c[3], c[1], at])
				seen += int(r[0])
		# And every penalty in some minutes of AI play.
		for f in 2700:
			await frame()
			if m.phase == "setup" and m.restart.get("out") != null and m.phase_t < 0.05:
				var r: Array = await _watch(m, "%s, in play: %s" % [venue, m.restart.get("why", "")])
				seen += int(r[0])
		m.queue_free()
		await frame()
		await frame()
	info("%d penalty passes watched" % seen)
	expect(seen >= 20, "only %d penalty passes seen" % seen)
	await Harness.done(h)


## One penalty pass, from its award to the release: [1 if it was watched, the closest the penalised player came].
func _watch(m: Match, what: String) -> Array:
	var out: Player = null
	var taker: Player = null
	var closest := INF
	var front := false
	var crowd := INF
	var crowd_who := ""
	var on_spot := false
	for f in 240:
		if m.phase == "setup":
			out = m.restart.get("out")
			taker = m.restart.get("taker")
		if taker != null and out != null and is_instance_valid(taker) and is_instance_valid(out) and m.holder == taker and taker.stopped:
			on_spot = true
			var d := out.p.distance_to(taker.p)
			closest = minf(closest, d)
			var post := Court.goal_post(taker.dir)
			var u := (post - taker.p).normalized()
			var rel := out.p - taker.p
			if rel.dot(u) > 0.3 and absf(rel.cross(u)) < 0.6:
				front = true
			for q: Player in m.players[1 - taker.team]:
				if q != out and not q.away() and q.p.distance_to(taker.p) < crowd:
					crowd = q.p.distance_to(taker.p)
					crowd_who = q.pos
		if m.phase == "live" and on_spot and m.holder != taker:
			break
		await frame()
	if not on_spot:
		return [0, INF]
	info("%s: the penalised %s %.2f m from the thrower at closest%s; the nearest other opponent %.2f m (%s)" % [what,
		out.pos if out else "?", closest, ", in front of her" if front else "", crowd, crowd_who])
	expect(closest >= BESIDE, "%s: the penalised %s almost on top of the thrower (%.2f m between them)" % [what, out.pos if out else "?", closest])
	expect(not front, "%s: the penalised player stands in front of the thrower" % what)
	expect(crowd >= MARK, "%s: the %s %.2f m from the thrower of a penalty pass" % [what, crowd_who, crowd])
	return [1, closest]
