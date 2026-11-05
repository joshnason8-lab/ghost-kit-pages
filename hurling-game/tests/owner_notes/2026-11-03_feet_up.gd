extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.21.0): "Regression: the feet are pointing upward again everywhere."

const NOTE := {"id": "2026-11-03-feet-up", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.21.0", "words": "Regression: the feet are pointing upward again everywhere."}
const Kit := preload("res://tests/note_kit.gd")

## Every body as drawn (players and officials) through 12 s of live play: feet at rest on the grass (heel down, the
## foot still) lie flat on it - "everywhere": 19 in 20 with the toe within 2.5 cm of the grass, the median within
## 1.5 cm. (A heel striking the grass, its toe coming down after it, is in every step; the most is reported, with
## what that man was doing.)
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "test", "seed": 6}, 2)
	var f := 0
	while m.phase != m.P.LIVE and f < 30 * 20:
		await Kit.frames(tree, 1)
		f += 1
	var st := {"rises": [], "worst": 0.0, "who": "", "bodies": {}, "prev": {}}
	var cbs := []
	for wb in Kit.bodies(m):
		var who: String = wb[0]
		var b0: WsgBody = wb[1]
		var k: float = b0.global_transform.basis.get_scale().y
		var ankle_rest: float = (b0.joints["LeftFoot"] as Vector3).y
		var toe_rest: float = (b0.joints["LeftToeBase"] as Vector3).y
		cbs.append([b0, Kit.watch(b0, func(b: WsgBody) -> void:
			st.bodies[who] = true
			var kk: float = b.global_transform.basis.get_scale().y
			var fe := WsgNoteChecks.feet(b)
			var prev: Array = st.prev.get(who, [])
			st.prev[who] = fe
			for side in 2:
				var a: Vector3 = fe[side * 2]
				var t: Vector3 = fe[side * 2 + 1]
				# (At rest: the toe still since the last frame it was drawn - not a heel striking the grass, its toe
				# coming down after it, as every step has for a moment.)
				var still := prev.size() == 4 and t.distance_to(prev[side * 2 + 1]) < 0.01
				if a.y - ankle_rest * kk < 0.015 and still:
					var rise := t.y - toe_rest * kk
					st.rises.append(rise)
					if rise > st.worst:
						st.worst = rise
						st.who = "%s (%s)" % [who, _doing(b)])])
	await Kit.frames(tree, 360)
	for c in cbs:
		Kit.unwatch(c[0], c[1])
	var r: Array = st.rises
	r.sort()
	var med: float = r[r.size() / 2] if not r.is_empty() else 0.0
	var p95: float = r[int(r.size() * 0.95)] if not r.is_empty() else 0.0
	info("%d bodies drawn, %d resting-foot frames: toe over the grass, median %.1f cm, 95%% within %.1f cm, most %.1f cm (%s)" % [st.bodies.size(), r.size(), med * 100.0, p95 * 100.0, st.worst * 100.0, st.who])
	expect(r.size() > 200, "only %d resting-foot frames seen" % r.size())
	expect(med <= 0.015, "planted feet point up: the toe %.1f cm over the grass on the median frame" % (med * 100.0))
	expect(p95 <= 0.025, "resting feet point up: 1 in 20 has its toe %.1f cm off the grass or more (the most: %.1f cm, %s)" % [p95 * 100.0, st.worst * 100.0, st.who])
	await Kit.done(tree, m)


static func _doing(b: WsgBody) -> String:
	var pl := b.get_parent().get_parent() as Player if b.get_parent() != null else null
	return "%s at %.1f m/s" % [pl.action if pl.action != "" else "running", Vector2(pl.vel.x, pl.vel.z).length()] if pl else "?"
