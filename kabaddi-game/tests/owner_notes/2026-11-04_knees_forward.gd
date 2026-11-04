extends WsgOwnerNote
const NOTE := {"id": "2026-11-04-knees-forward", "game": "kabaddi", "date": "2026-11-04", "version": "0.14.24-beta",
	"words": "no backward knees on Low or High, outside named acrobatics (the lead's record: Low bodies bent knees 20-32 cm backwards until 0.14.23)"}
const U := preload("res://tests/owner_note_util.gd")

## Acrobatics that may fold a leg any way while they play (the foundation's knee_excuse: named moves only).
const EXCUSED := ["dive", "jump", "dubki", "held", "holding", "fallen", "rise"]
const SECONDS := 12.0
## High's legs on the move are the foundation's (its locomotor and planter): a jogging raider's knee went back 20 cm
## for 4 frames on 2026-11-04, with it to fix. Measured and said until its "knees" world rule is enforced; failed after.
const HIGH_FROM := "2026-11-06T12:00Z"


## An AI match on Low (the game's own bodies and the foundation's planter) and on High (the foundation's bodies): each
## frame, each drawn leg bent over 15 degrees whose knee lies more than 4 cm behind its hip-to-ankle line, forward the
## way the foot points. At most 0.5% of the bent knee-frames, none over 15 cm (the foundation's "knees" rule).
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
	var bent := 0
	var back := 0
	var worst := 0.0
	var worst_who := ""
	for i in int(SECONDS * 30.0):
		await U.frames(tree, 1)
		if not is_instance_valid(m):
			break
		if FoundationLink.frozen:
			continue   # (an instant replay: poses read live when first drawn - WsgSim skips them too)
		for a in m.find_children("*", "Athlete", true, false):
			if String(a.state) in EXCUSED:
				continue
			for leg in _legs(a):
				bent += 1
				var d: float = leg
				if d > 0.04:
					back += 1
					if d > worst:
						worst = d
						worst_who = "%s (%s)" % [String(a.data.get("id", "?")), String(a.state)]
	var at: String = ["Low", "Medium", "High"][gfx]
	expect(bent > 0, at + ": no bent knees measured (no legs drawn?)")
	var now := OS.get_environment("WSG_NOW") if OS.get_environment("WSG_NOW") != "" else Time.get_datetime_string_from_system(true).left(16) + "Z"
	if gfx != Game.GFX_LOW and now < HIGH_FROM:
		if back > int(bent * 0.005) or worst > 0.15:
			info(at + ": over the bounds - the foundation's to fix, failed from " + HIGH_FROM)
	else:
		expect(back <= int(bent * 0.005), at + ": %d of %d bent knee-frames backward (0.5%% at most)" % [back, bent])
		expect(worst <= 0.15, at + ": a knee %.0f cm behind its leg's line, %s (15 cm at most)" % [worst * 100.0, worst_who])
	info(at + ": %d of %d bent knee-frames backward, worst %.1f cm %s" % [back, bent, worst * 100.0, worst_who])
	m.queue_free()
	await U.frames(tree, 2)
	FoundationLink.off = true


## How far behind its hip-to-ankle line each bent knee lies (m; positive is backward), the legs as drawn: the
## foundation's body when it shows, else the game's own.
func _legs(a: Athlete) -> Array:
	var out := []
	if a.model == null:
		return out
	var link = a.model.get("link")
	if link != null and link.body != null and link.body.is_visible_in_tree():
		for s in ["Left", "Right"]:
			out.append_array(_one(link.body.bone_world(s + "UpLeg").origin, link.body.bone_world(s + "Leg").origin,
				link.body.bone_world(s + "Foot").origin, link.body.bone_world(s + "ToeBase").origin))
		return out
	var rig: RiggedBody = a.model.rig
	if rig == null or rig.skeleton == null or not rig.skeleton.is_visible_in_tree():
		return out
	var sk := rig.skeleton
	for s in ["l", "r"]:
		if not (rig._bone.has("thigh_" + s) and rig._bone.has("shin_" + s) and rig._bone.has("foot_" + s)):
			continue
		var w := func(n: String) -> Vector3: return sk.global_transform * sk.get_bone_global_pose(int(rig._bone[n + s])).origin
		var ank: Vector3 = w.call("foot_")
		# (Forward the way the toe points; a rig without a toe bone, the way he faces.)
		var toe: Vector3 = w.call("toe_") if rig._bone.has("toe_" + s) else ank + Vector3(a.facing.x, 0.0, a.facing.z) * 0.1
		out.append_array(_one(w.call("thigh_"), w.call("shin_"), ank, toe))
	return out


func _one(hip: Vector3, knee: Vector3, ank: Vector3, toe: Vector3) -> Array:
	if rad_to_deg((knee - hip).angle_to(ank - knee)) < 15.0:
		return []
	var fwd := Vector3(toe.x - ank.x, 0.0, toe.z - ank.z)
	if fwd.length() < 0.01:
		return []
	var line := ank - hip
	var t := clampf((knee - hip).dot(line) / maxf(line.length_squared(), 1e-6), 0.0, 1.0)
	return [-(knee - (hip + line * t)).dot(fwd.normalized())]
