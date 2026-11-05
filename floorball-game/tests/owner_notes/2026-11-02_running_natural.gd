extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta); and, the same day through the lead: "running looks way worse...
## occasionally players are leaning and shaped weird".

const NOTE := {"id": "2026-11-02-running-natural", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "HOnestly the running looked better before the shared foundation we need to fix this to make it look natural."}

const Lib := preload("res://tests/note_lib.gd")


## Over 40 seconds of AI play, every skater running (over 3 m/s) as drawn: bent over the stick but not folded - the
## trunk (hips to neck) leant 5 to 45 degrees from upright in 95% of frames, never over 60 - never in a T- or A-pose,
## the elbows bent as a runner's (not locked straight: bent over 10 degrees on average), and the feet on the floor.
func check() -> void:
	if not Lib.have_foundation():
		skip("no licensed clips here: the shared foundation's bodies are not drawn")
		return
	var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": 3, "period": 4.0})
	var leans := []
	var poses := 0
	var elbows := []
	var sunk := [0.0]
	await Lib.each_posed(tree, m, 60 * 40, func(p: Player, b: WsgBody):
		if p.vel.length() < 3.0:
			return
		var hips := b.bone_world("Hips").origin
		var neck := b.bone_world("Neck").origin
		leans.append(Lib.deg(neck - hips, Vector3.UP))
		if WsgNoteChecks.t_or_a_pose(b) != "":
			poses += 1
		var arms: Dictionary = WsgNoteChecks.arms(b)
		elbows.append((float(arms.Left[1]) + float(arms.Right[1])) * 0.5)
		if p.link.floor_legs:
			sunk[0] = maxf(sunk[0], p.link.floor_legs.worst))
	var lo := Lib.pct(leans, 0.025)
	var hi := Lib.pct(leans, 0.975)
	var top := Lib.pct(leans, 1.0)
	var el := 0.0
	for e: float in elbows:
		el += e
	el /= maxf(1.0, elbows.size())
	info("%d running frames: lean %.0f to %.0f degrees (95%%), at most %.0f; elbows bent %.0f on average; %d T/A-poses; a foot under the floor by %.3f m at most" % [leans.size(), lo, hi, top, el, poses, sunk[0]])
	expect(leans.size() > 500, "too little running seen (%d frames)" % leans.size())
	expect(lo >= 5.0 and hi <= 45.0, "running, the trunk leant %.0f to %.0f degrees" % [lo, hi])
	expect(top <= 60.0, "a runner folded over %.0f degrees: shaped weird" % top)
	expect(poses == 0, "%d running frames in a T- or A-pose" % poses)
	expect(el >= 10.0, "the runners' arms locked straight (elbows %.0f degrees on average)" % el)
	expect(sunk[0] < 0.01, "a runner's foot %.3f m under the floor" % sunk[0])
	await Lib.done(tree, m)
