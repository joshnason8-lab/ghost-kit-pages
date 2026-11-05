extends TakrawNote
## The owner, 2026-11-02, on the serve's throw (passed on by the mobile games lead with the World Cup broadcast): the
## thrower throws the ball to the server with ONE hand. The lead: the toss outside the body's torso, in one hand.

const NOTE := {"id": "2026-11-02-one-hand-toss", "game": "sepak-takraw", "date": "2026-11-02", "version": "0.14.1",
	"words": "notice it's ONE hand"}


## Every serve of a regu and a doubles match, men and women, on Low (the game's own bodies) and High (the shared
## foundation's, where its library is: its body.torso_capsule()), from the thrower's crouch to his letting go: the ball
## in his right hand and his left away from it, and the ball never inside his torso as drawn.
func check() -> void:
	for level in [Game.GFX_LOW, Game.GFX_HIGH]:
		for women in [false, true]:
			for ev in ["regu", "doubles"]:
				await _one(level, women, ev)
	await clean()


func _one(level: int, women: bool, ev: String) -> void:
	var m := make_match({"event": ev, "women": women, "seed": 4}, level)
	var tag := "%s %s %s" % [["Low", "Medium", "High"][level], "women" if women else "men", ev]
	var st := {"serves": 0, "held": 0, "torso": INF, "off_palm": 0.0, "left": INF, "was_toss": false, "drawn": 0}
	# On High, where the foundation draws him, the torso as drawn (read in `posed`: the bones final).
	var hooked := {}
	await play(m, 150.0, func(mm: Node):
		var th: Player = mm._thrower()
		var toss: bool = int(mm.state) == int(mm.S.TOSS)
		if toss and not st.was_toss:
			st.serves += 1
		st.was_toss = toss
		var holding: bool = th.carrying and (toss or (int(mm.state) == int(mm.S.SETUP) and th.toss_crouch))
		if not holding:
			return
		st.held += 1
		var bp: Vector3 = mm.ball.global_position
		var link: FoundationLink = th.body.link
		if link and link.body:
			var b: WsgBody = link.body
			if not hooked.has(b):
				hooked[b] = true
				b.posed.connect(func():
					if is_instance_valid(mm) and mm._thrower().body.link == link and mm._thrower().carrying:
						st.drawn += 1
						var cap := b.torso_capsule()
						st.torso = minf(st.torso, _to_capsule(mm.ball.global_position, cap) - Ball.RADIUS)
						# (His left palm as drawn: FoundationLink.palms, the palm's ball point.)
						if link.palms.has("l"):
							st.left = minf(st.left, mm.ball.global_position.distance_to(b.global_transform * (link.palms.l as Vector3))))
		else:
			var a: Vector3 = th.body.bone_world("hips")
			var n: Vector3 = th.body.bone_world("neck")
			st.torso = minf(st.torso, _to_capsule(bp, [a, n, 0.13]) - Ball.RADIUS)
			st.off_palm = maxf(st.off_palm, bp.distance_to(th.carry_point()))
			st.left = minf(st.left, bp.distance_to(th.body.bone_world("hand_l")))
		if st.serves >= 4 and not toss:
			mm.set_meta("note_done", true)   # (enough serves seen)
		, level == Game.GFX_HIGH)
	info("%s: %d serves, the ball held %d frames (%d drawn by the foundation); least from the torso %.3f m, left hand %.2f m at the nearest, %.3f m off the right palm at most" % [
		tag, st.serves, st.held, st.drawn, st.torso, st.left, st.off_palm])
	expect(st.serves >= 3 and st.held > 20, "%s: %d serves seen (the ball held %d frames)" % [tag, st.serves, st.held])
	expect(st.torso > 0.0, "%s: the ball goes %.3f m into the thrower's torso" % [tag, -st.torso])
	# (One hand: his left off the ball - the game's left hand bone 0.2 m from its centre, the drawn left palm 5 cm off
	# its surface.)
	var left_min := 0.12 if st.drawn > 0 else 0.2
	expect(st.left > left_min, "%s: his left hand comes %.2f m from the ball's centre (one hand: the right; at least %.2f)" % [tag, st.left, left_min])
	expect(st.off_palm < 0.01, "%s: the ball %.3f m off his right palm" % [tag, st.off_palm])
	m.queue_free()
	await frame()


## A point's distance from a capsule's axis [a, b, r], less r.
static func _to_capsule(p: Vector3, cap: Array) -> float:
	var a: Vector3 = cap[0]
	var ab: Vector3 = (cap[1] as Vector3) - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p.distance_to(a + ab * t) - float(cap[2])
