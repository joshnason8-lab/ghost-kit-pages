extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta.

const NOTE := {"id": "2026-11-03-rigid-stance", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "Their stance is too rigid when not moving, it doesn't look natural with their hands out and not moving."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const HANDS_OUT := 0.35     # m: a hand this far in front of its shoulder is held out
const ALIVE := 1.0          # degrees: over two seconds standing, some bone turns at least this much (breathing, sway)


## Every player standing still in AI matches (under 0.2 m/s for two seconds or more, not holding the ball, not out of
## play, not in the middle of a catch, pass, shot, leap or cheer), on Low (the game's own bodies) and on Medium and
## High (the shared foundation's, with the licensed clips): she is never frozen (over each two seconds standing some bone of hers turns ALIVE degrees or more:
## breathing, her weight shifting, her head turning), never twitching (WsgNoteChecks.jitter: no bone jerking back the
## way it came), and her hands are not held out in front of her (both HANDS_OUT or more in front of her shoulders) in
## more than one standing frame in ten while the ball is more than 8 m from her and not coming to her.
func check() -> void:
	var h: Node = await Harness.make(tree)
	var clips := Harness.have_clips()
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		if g != Game.GFX_LOW and not clips:
			continue
		Game.settings.graphics = g
		FoundationLink.off = g == Game.GFX_LOW
		# (One venue: where they stand and how is the same in every venue, to the frame - measured.)
		await _match(h, g, "arena")
	if not clips:
		info("(no licensed clips here: the foundation's standing not measured)")
	await Harness.done(h)


func _match(h: Node, g: int, venue: String) -> void:
	var m: Match = h._study_match(91, {"venue": venue})
	await h._wait_live(m)
	var people: Array = m.players[0] + m.players[1]
	var now := {}       # the drawn body's state as its last pose left it: [quats, [left hand fwd, right hand fwd]]
	for q: Player in people:
		now[q] = []
		if q.link:
			q.link.body.posed.connect(func(): now[q] = _sample_wsg(q.link.body))
	var stint := {}
	var stints := 0
	var frozen := 0
	var frozen_who := ""
	var twitch := 0
	var twitch_who := ""
	var stand_frames := 0
	var out_frames := 0
	var out_who := ""
	for f in 900:
		await frame()
		if m.phase != "live" and m.phase != "setup":
			stint.clear()
			continue
		for q: Player in people:
			var drawn: bool = q.link != null and q.link.body.is_visible_in_tree()
			var s: Array = now[q] if drawn else _sample_toon(q)
			# (Standing in play: not in the middle of a catch, a pass, a shot, a leap or a cheer.)
			var standing: bool = q.vel.length() < 0.2 and not q.has_ball() and not q.away() and not s.is_empty() \
				and q.act in ["run", "ready", "mark", "post", "huddle"]
			if not standing:
				if stint.has(q):
					var st: Array = stint[q]
					if st.size() >= 60:
						stints += 1
						var r := _range(st)
						if r < ALIVE:
							frozen += 1
							frozen_who = "%s%d (%s, %.0f s still, %.2f deg)" % [q.pos, q.team, q.act, st.size() / 30.0, r]
						var j := _jitter(st.slice(15))    # (after half a second: not the blend out of her last move)
						if j[0] > 0:
							twitch += 1
							twitch_who = "%s%d (%s): %s" % [q.pos, q.team, q.act, j[1]]
					stint.erase(q)
				continue
			if not stint.has(q):
				stint[q] = []
			(stint[q] as Array).append(s[0])
			stand_frames += 1
			var ball := m.ball.court_pos()
			var coming: bool = m.pass_info.get("to") == q
			if ball.distance_to(q.p) > 8.0 and not coming and float(s[1][0]) > HANDS_OUT and float(s[1][1]) > HANDS_OUT:
				out_frames += 1
				out_who = "%s%d (%s), hands %.0f and %.0f cm in front" % [q.pos, q.team, q.act, float(s[1][0]) * 100.0, float(s[1][1]) * 100.0]
	# (The stints still going at the end count too.)
	for q in stint:
		var st: Array = stint[q]
		if st.size() >= 60:
			stints += 1
			var r := _range(st)
			if r < ALIVE:
				frozen += 1
				frozen_who = "%s%d (%s, %.0f s still, %.2f deg)" % [q.pos, q.team, q.act, st.size() / 30.0, r]
			var j := _jitter(st.slice(15))    # (after half a second: not the blend out of her last move)
			if j[0] > 0:
				twitch += 1
				twitch_who = "%s%d (%s): %s" % [q.pos, q.team, q.act, j[1]]
	var what := "%s, %s" % [["Low", "Medium", "High"][g], venue]
	var share := float(out_frames) / maxf(1.0, stand_frames)
	info("%s: %d standing stints of 2 s or more, %d frozen, %d twitching; hands held out in %.0f%% of %d standing frames%s" % [what,
		stints, frozen, twitch, share * 100.0, stand_frames, (" (" + out_who + ")") if out_frames > 0 else ""])
	expect(stints >= 1 and stand_frames >= 600, "%s: hardly anyone stood still (%d frames, %d stints of 2 s)" % [what, stand_frames, stints])
	expect(frozen == 0, "%s: %d of %d standing players frozen, not moving (%s)" % [what, frozen, stints, frozen_who])
	expect(twitch == 0, "%s: %d standing players twitch (%s)" % [what, twitch, twitch_who])
	expect(share <= 0.1, "%s: hands held out in front in %.0f%% of standing frames (%s)" % [what, share * 100.0, out_who])
	m.queue_free()
	await frame()
	await frame()


## The game's own body now: [each bone's turn, [left, right hand in front of its shoulder (m)]].
func _sample_toon(q: Player) -> Array:
	var b: ToonBody = q.body
	var sk := b.skeleton
	var quats := []
	for i in sk.get_bone_count():
		quats.append(sk.get_bone_global_pose(i).basis.get_rotation_quaternion())
	var fwd := b.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var hands := []
	for s in ["l", "r"]:
		hands.append((b.bone_world("hand_" + s) - b.bone_world("upperarm_" + s)).dot(fwd))
	return [quats, hands]


## The foundation's body as its pose leaves it.
static func _sample_wsg(b: WsgBody) -> Array:
	var fwd := b.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var hands := []
	for s in ["Left", "Right"]:
		hands.append((b.bone_world(s + "Hand").origin - b.bone_world(s + "Arm").origin).dot(fwd))
	return [WsgNoteChecks.pose(b), hands]


## The most any bone turned from where it was at the start of a stint (degrees).
static func _range(st: Array) -> float:
	var worst := 0.0
	var first: Array = st[0]
	for p: Array in st:
		for i in p.size():
			var a := rad_to_deg((first[i] as Quaternion).angle_to(p[i]))
			worst = maxf(worst, a)
	return worst


## Bones that jerk back the way they came (a turn over 1.5 degrees reversed the next frame), as WsgNoteChecks.jitter.
static func _jitter(st: Array) -> Array:
	var n := 0
	var where := ""
	for i in (st[0] as Array).size():
		var prev_axis := Vector3.ZERO
		var prev_ang := 0.0
		for f in range(1, st.size()):
			var dq := (st[f - 1][i] as Quaternion).inverse() * (st[f][i] as Quaternion)
			var ang := rad_to_deg(dq.get_angle())
			if ang > 180.0:
				ang = 360.0 - ang
			var axis := dq.get_axis() if ang > 0.01 else Vector3.ZERO
			if ang > 1.5 and prev_ang > 1.5 and axis.dot(prev_axis) < -0.5:
				n += 1
				where = "bone %d jerked %.1f deg back after %.1f, frame %d of %d" % [i, ang, prev_ang, f, st.size()]
			prev_axis = axis
			prev_ang = ang
	return [n, where]
