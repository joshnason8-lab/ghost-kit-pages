extends WsgOwnerNote
const NOTE := {"id": "2026-11-04-knees-forward", "game": "kabaddi", "date": "2026-11-04", "version": "0.14.24-beta",
	"words": "no backward knees on Low or High, outside named acrobatics (the lead's record: Low bodies bent knees 20-32 cm backwards until 0.14.23)"}
const U := preload("res://tests/owner_note_util.gd")

## Acrobatics that may fold a leg any way while they play (the foundation's knee_excuse: named moves only).
const EXCUSED := ["dive", "jump", "dubki", "held", "holding", "fallen", "rise"]
const SECONDS := 12.0
## High's legs on the move are partly the foundation's (its locomotor and planter): measured and said until its "knees"
## world rule is enforced, failed after.
const HIGH_FROM := "2026-11-06T12:00Z"


## An AI match on Low (the game's own bodies and the foundation's planter) and on High (the foundation's bodies): each
## drawn leg, read as drawn (inside skeleton_updated) by the foundation's measure (WsgNoteChecks.knees: the body's
## forward from its hips, as the "knees" rule reads it - the lead, 2026-11-04), bent at least KNEE_BENT and more than
## KNEE_BACK behind its hip-to-ankle line is backward. At most 0.5% of the bent knee-frames, none over 15 cm. The
## umpires (OFFICIAL_1/2) and the seated scorers (OFFICIAL_5/6) must be among those measured.
func check() -> void:
	for gfx in [Game.GFX_LOW, Game.GFX_HIGH]:
		await _level(gfx)


func _level(gfx: int) -> void:
	U.host(tree)
	FoundationLink.off = false
	Game.settings.graphics = gfx
	WsgFoundation.tier = gfx
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "autoplay": true, "length": 0,
		"difficulty": 1, "seed": 7})
	var m: Node = Game.current
	await U.until_raid(tree, m)
	var st := {"on": true, "bent": 0, "back": 0, "worst": 0.0, "worst_who": "", "officials": {}}
	var hooked := []
	for a in m.find_children("*", "Athlete", true, false):
		var sk := _drawn(a)
		if sk == null:
			continue
		var legs := WsgNoteChecks.leg_bones(sk)
		if legs.is_empty():
			continue
		var who := String(a.data.get("id", ""))
		var cb := func():
			if not st.on or FoundationLink.frozen or not is_instance_valid(a) or String(a.state) in EXCUSED:
				return
			for k in WsgNoteChecks.knees(sk, legs):
				if float(k[1]) < WsgNoteChecks.KNEE_BENT:
					continue
				st.bent += 1
				var d := -float(k[0])
				if who.begins_with("OFFICIAL_"):
					if not st.officials.has(who):
						st.officials[who] = [0, 0]
					st.officials[who][0] += 1
					if d > WsgNoteChecks.KNEE_BACK:
						st.officials[who][1] += 1
				if d > WsgNoteChecks.KNEE_BACK:
					st.back += 1
					if d > float(st.worst):
						st.worst = d
						st.worst_who = "%s (%s)" % [who, String(a.state)]
		sk.skeleton_updated.connect(cb)
		hooked.append([sk, cb])
	await U.frames(tree, int(SECONDS * 30.0))
	st.on = false
	for h in hooked:
		if is_instance_valid(h[0]) and (h[0] as Skeleton3D).skeleton_updated.is_connected(h[1]):
			(h[0] as Skeleton3D).skeleton_updated.disconnect(h[1])
	var at: String = ["Low", "Medium", "High"][gfx]
	var bent: int = st.bent
	var back: int = st.back
	var worst: float = st.worst
	expect(bent > 0, at + ": no bent knees measured (no legs drawn?)")
	for o in ["OFFICIAL_1", "OFFICIAL_2", "OFFICIAL_5", "OFFICIAL_6"]:
		expect((st.officials as Dictionary).has(o), at + ": %s's knees not measured" % o)
	var said := []
	for o in st.officials:
		said.append("%s %d/%d" % [o, st.officials[o][1], st.officials[o][0]])
	info(at + ": officials backward/bent: " + ", ".join(said))
	var now := OS.get_environment("WSG_NOW") if OS.get_environment("WSG_NOW") != "" else Time.get_datetime_string_from_system(true).left(16) + "Z"
	if gfx != Game.GFX_LOW and now < HIGH_FROM:
		if back > int(bent * 0.005) or worst > 0.15:
			info(at + ": over the bounds - failed from " + HIGH_FROM)
	else:
		expect(back <= int(bent * 0.005), at + ": %d of %d bent knee-frames backward (0.5%% at most)" % [back, bent])
		expect(worst <= 0.15, at + ": a knee %.0f cm behind its leg's line, %s (15 cm at most)" % [worst * 100.0, st.worst_who])
	info(at + ": %d of %d bent knee-frames backward, worst %.1f cm %s" % [back, bent, worst * 100.0, st.worst_who])
	m.queue_free()
	await U.frames(tree, 2)
	FoundationLink.off = true


## The skeleton drawn for A: the foundation's body when it shows, else the game's own.
func _drawn(a: Athlete) -> Skeleton3D:
	if a.model == null:
		return null
	var link = a.model.get("link")
	if link != null and link.body != null and link.body.is_visible_in_tree():
		return link.body.skeleton
	if a.model.rig != null and a.model.rig.skeleton != null and a.model.rig.skeleton.is_visible_in_tree():
		return a.model.rig.skeleton
	return null
