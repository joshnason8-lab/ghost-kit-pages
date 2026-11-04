extends WsgOwnerNote
## The owner, 2026-11-01 (Kho Kho Rush 0.11.0): "The dive needs better standing up from the dive... they are trying to tag the person. Typically with one arm extended"

const NOTE := {"id": "2026-11-01-dive-one-arm", "game": "kho-kho", "date": "2026-11-01", "version": "Kho Kho Rush 0.11.0", "words": "The dive needs better standing up from the dive... they are trying to tag the person. Typically with one arm extended"}
const KK := preload("res://tests/note_kk.gd")


## Dives at a runner to his left and right, near and far: the touch comes as the match makes it (Match.dive_touch_at),
## the arm on his side reaches his leg (the hand within 0.2 m), the other braces; up through a knee, the hips never
## dropping, and on his feet at the end.
func check() -> void:
	KK.prepare(tree)
	ModelBody.warm()
	var a := Athlete.new({"id": "a", "speed": 70}, 0)
	tree.root.add_child(a)
	var r := Athlete.new({"id": "r", "speed": 70}, 1)
	tree.root.add_child(r)
	for side: float in [-1.0, 1.0]:
		for dist: float in [1.9, 2.4, 2.8]:
			a.position = Vector3.ZERO
			a.yaw = PI * 0.5
			a.act = ""
			a.integrate(1.0 / 30.0)
			r.position = Vector3(dist, 0, -0.32 * side)   # (to one side, inside the dive's touch: Match.DIVE_TOUCH_R)
			await frame()
			a.vel = Vector3(5.6, 0, 0)
			a.dive_target = r
			a.do("dive", 0.5)
			var best := INF
			var arm := 0.0
			var dip := 0.0
			var last := -1.0
			var kneeled := false
			var touched := false
			for i in 75:
				a.integrate(1.0 / 30.0)
				await frame()
				if not touched and a.act == "dive" and a.act_t >= 0.08 and a.act_t <= 0.45:
					var h: Vector3 = KK.MatchScript.dive_touch_at(a)
					if Vector2(r.position.x - h.x, r.position.z - h.z).length() < KK.MatchScript.DIVE_TOUCH_R:
						touched = true
						a.lock_reach(r.global_position + Vector3(0, 0.18, 0))
				if touched and a.act in ["dive", "lie"] and a.body.dive_hand != Vector3.INF:
					best = minf(best, a.body.dive_hand.distance_to(r.global_position + Vector3(0, 0.18, 0)))
					arm = a.body.dive_arm
				kneeled = kneeled or a.body.dive_kneel > 0.9
				var dr: Vector2 = a.body.dive_drawn
				if a.act == "getup" and dr != Vector2.INF:
					if last >= 0.0:
						dip = maxf(dip, last - dr.x)
					last = dr.x
			var want_arm := 1.0 if side > 0.0 else -1.0
			var what := "runner %s at %.1f m" % ["left" if side > 0 else "right", dist]
			info("%s: hand %.2f m from his leg, arm %+.0f, hips dipped %.3f m getting up" % [what, best, arm, dip])
			expect(touched, "%s: the dive touched him" % what)
			expect(best < 0.2, "%s: the hand %.2f m from the runner's leg" % [what, best])
			expect(arm == want_arm, "%s: the far arm reached (%+.0f)" % [what, arm])
			expect(kneeled and dip < 0.02 and a.act == "", "%s: the get-up (knee %s, dip %.3f m, ends '%s')" % [what, kneeled, dip, a.act])
	a.queue_free()
	r.queue_free()
