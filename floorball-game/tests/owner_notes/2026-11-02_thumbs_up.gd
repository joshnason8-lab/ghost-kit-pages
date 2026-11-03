extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta).

const NOTE := {"id": "2026-11-02-thumbs-up", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "Hand holding the stick is still awful. their thumbs should be up and the knuckles under the stick facing downward."}

const Lib := preload("res://tests/note_lib.gd")


## Over 40 seconds of AI play, every fist on the stick as drawn: the thumb up - its tip higher than the little finger's
## knuckle (the hand's far edge, under the shaft) - in 90% of frames, for the top and the lower hand.
func check() -> void:
	if not Lib.have_foundation():
		skip("no licensed clips here: the shared foundation's bodies are not drawn")
		return
	var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": 3, "period": 4.0})
	var up := {"top": [0, 0], "low": [0, 0]}
	await Lib.each_posed(tree, m, 60 * 40, func(p: Player, b: WsgBody):
		for which in ["top", "low"]:
			if which == "low" and float(p.link.get("_low_w")) < 1.0:
				continue
			var side: String = p.link.top if which == "top" else p.link.low
			var thumb := b.bone_world(side + "HandThumb3").origin
			var pinky := b.bone_world(side + "HandPinky1").origin
			up[which][1] += 1
			if thumb.y > pinky.y:
				up[which][0] += 1)
	for which in ["top", "low"]:
		var r: Array = up[which]
		info("%s hand: the thumb up in %d of %d frames" % [which, r[0], r[1]])
		expect(r[1] > 500 and r[0] >= r[1] * 0.9, "%s hand: the thumb up in only %d of %d frames" % [which, r[0], r[1]])
	await Lib.done(tree, m)
