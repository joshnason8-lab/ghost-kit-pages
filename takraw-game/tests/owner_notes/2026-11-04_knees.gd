extends TakrawNote
## The owner, 2026-11-04 (on 0.15.27, with a screenshot of Low's players in their ready stance): "All that work and the
## players stances regressed to look like the have broken backwards knees ... Refs knees also bent wrong".

const NOTE := {"id": "2026-11-04-knees", "game": "sepak-takraw", "date": "2026-11-04", "version": "0.15.27",
	"words": "All that work and the players stances regressed to look like the have broken backwards knees. How does that happen its unacceptable. Refs knees also bent wrong"}

## The named acrobatics: the roll spike and the sunback kick turn the body over in the air (its left-right axis is no
## guide to the knee there).
const ACROBATICS := ["roll", "sunback"]
const BENT := 8.0          # degrees: a knee bent at least this much is read
const BACK := 15.0         # degrees the wrong way: a backward knee
const BACK_MAX := 30.0     # never further
const SHARE := 0.005       # of the bent-knee frames at most backward past BACK (a frame's flicker)
## High's walk between points (the foundation's locomotor on its own bodies): its swinging knee flicks backward for a
## frame or three, up to 40 degrees, 8 frames in the minute (2026-11-04, reported to the Foundation): read on its own,
## held to SHARE and to this until the Foundation's fix, then to BACK_MAX like the rest.
const BACK_MAX_WALK_HIGH := 45.0


## On Low (the game's own bodies, their feet planted by the shared planter) and on High (the foundation's bodies), a
## minute of a Watch-AI regu, every player, official and substitute as drawn (read in skeleton_updated): each knee's
## bend in the body's own front-to-back plane, about its left-right axis, while the thigh is below the hip. Backward
## past 15 degrees in at most 0.5% of the bent-knee frames, and never past 30 - outside the named acrobatics and the
## replays (those frames again). Before (0.15.27: the shared planter took the thigh's z for forward, and on this rig it
## points back): the players' knees backward in 89% of their bent frames, the officials' in 43%.
func check() -> void:
	for g in [Game.GFX_LOW, Game.GFX_HIGH]:
		var lvl: String = ["Low", "Medium", "High"][g]
		var m := make_match({"seed": 7}, g)
		await frame()
		var st := {}      # kind -> [bent-knee frames, backward past BACK, worst backward (degrees), where]
		var hooked := {}
		await play(m, 60.0, func(mm: Node):
			for b in mm._all_bodies():
				_hook(b as RealBody, mm, st, hooked), true)
		for kind in ["player", "official", "player walking between points"]:
			if kind == "player walking between points" and g == Game.GFX_LOW:
				continue   # (Low's walk is read with the rest of the players')
			var s: Array = st.get(kind, [0, 0, 0.0, ""])
			var most := BACK_MAX_WALK_HIGH if kind == "player walking between points" else BACK_MAX
			var who: String = {"player": "players'", "official": "officials'", "player walking between points": "players' (walking between points)"}[kind]
			info("%s: %s knees, %d bent-knee frames: %d backward past %.0f degrees, the worst %.0f%s" % [lvl, who,
				s[0], s[1], BACK, s[2], (" (%s)" % s[3]) if String(s[3]) != "" else ""])
			expect(int(s[0]) > 500, "%s: only %d bent-knee frames of %ss read" % [lvl, s[0], kind])
			expect(float(s[1]) <= SHARE * float(s[0]), "%s: %ss' knees bent backward past %.0f degrees in %d of %d frames (%.1f%% at most)" % [lvl, kind, BACK, s[1], s[0], 100.0 * SHARE])
			expect(float(s[2]) <= most, "%s: a %s's knee bent %.0f degrees backward (%s; %.0f at most)" % [lvl, kind, s[2], s[3], most])
		if st.has("bench"):
			var b: Array = st.bench
			info("%s: the substitutes' knees, %d bent-knee frames: %d backward past %.0f degrees, the worst %.0f" % [lvl, b[0], b[1], BACK, b[2]])
			expect(float(b[2]) <= BACK_MAX, "%s: a substitute's knee bent %.0f degrees backward" % [lvl, b[2]])
		m.queue_free()
		await frame()
	await clean()


## Reads RB's knees each time its drawn skeleton (the foundation's body under a link, else its own) is drawn.
func _hook(rb: RealBody, m: Node, st: Dictionary, hooked: Dictionary) -> void:
	if rb == null:
		return
	var wb: WsgBody = rb.link.body if rb.link != null else null
	var sk: Skeleton3D = wb.skeleton if wb != null else rb.skeleton
	if sk == null or hooked.has(sk):
		return
	hooked[sk] = true
	var pre := "" if wb != null else "mixamorig_"
	var ix := {}
	for n in ["LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]:
		ix[n] = sk.find_bone(pre + n)
	# (Forward, as the rig stands at rest: from the ankle to the toe.)
	var rest_fwd: Vector3 = sk.get_bone_global_rest(ix.LeftToeBase).origin - sk.get_bone_global_rest(ix.LeftFoot).origin
	var base := "player" if rb.get_parent() is Player else ("official" if (m.get("officials") as Array).has(rb) else "bench")
	sk.skeleton_updated.connect(func() -> void:
		if not sk.is_inside_tree() or not is_instance_valid(m) or int(m.state) == int(m.S.REPLAY):
			return
		var pl := rb.get_parent() as Player
		var mv := String(pl.move) if pl else ""
		if mv in ACROBATICS:
			return
		var kind := "player walking between points" if wb != null and pl and pl.stroll and mv == "" else base
		var f: Vector3 = sk.global_transform.basis * rest_fwd
		f.y = 0.0
		if f.length() < 1e-4:
			return
		var right := f.normalized().cross(Vector3.UP)
		for side in ["Left", "Right"]:
			var hip: Vector3 = sk.global_transform * sk.get_bone_global_pose(ix[side + "UpLeg"]).origin
			var knee: Vector3 = sk.global_transform * sk.get_bone_global_pose(ix[side + "Leg"]).origin
			var ank: Vector3 = sk.global_transform * sk.get_bone_global_pose(ix[side + "Foot"]).origin
			var t := (knee - hip).normalized()
			var s := (ank - knee).normalized()
			if rad_to_deg(t.angle_to(s)) < BENT:
				continue
			var row: Array = st.get(kind, [0, 0, 0.0, ""])
			row[0] += 1
			# (The bend in the front-to-back plane: forward is the shin swinging back under the thigh.)
			var tp := (t - right * t.dot(right)).normalized()
			var sp := (s - right * s.dot(right)).normalized()
			var flex := -rad_to_deg(atan2(tp.cross(sp).dot(right), tp.dot(sp)))
			if knee.y < hip.y and flex < -BACK:
				row[1] += 1
				if -flex > float(row[2]):
					row[2] = -flex
					row[3] = "%s knee, %s" % [side.to_lower(), mv if mv != "" else "no move"]
			st[kind] = row)
