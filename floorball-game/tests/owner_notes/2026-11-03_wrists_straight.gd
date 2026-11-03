extends WsgOwnerNote
## The owner, 2026-11-03 (Floorball 0.9.3-beta), with a picture of a golfer's grip.

const NOTE := {"id": "2026-11-03-wrists-straight", "game": "floorball", "date": "2026-11-03", "version": "0.9.3-beta",
	"words": "Grip is still bad. Look at this image, see how the wrists are straight and not looking almost broken?"}

const Lib := preload("res://tests/note_lib.gd")


## Over 40 seconds of AI play, every fist on the stick as drawn: the wrist straight - the hand (wrist to the middle
## knuckle) within 40 degrees of the forearm's line in 95% of frames, never over 70 (a wrist that looks broken).
func check() -> void:
	if not Lib.have_foundation():
		skip("no licensed clips here: the shared foundation's bodies are not drawn")
		return
	var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": 3, "period": 4.0})
	var bends := []
	await Lib.each_posed(tree, m, 60 * 40, func(p: Player, b: WsgBody):
		var sides: Array = [p.link.top]
		if float(p.link.get("_low_w")) >= 1.0:
			sides.append(p.link.low)
		for side: String in sides:
			var fore := b.bone_world(side + "ForeArm").origin
			var hand := b.bone_world(side + "Hand").origin
			var knuckle := b.bone_world(side + "HandMiddle1").origin
			bends.append(Lib.deg(hand - fore, knuckle - hand)))
	var p95 := Lib.pct(bends, 0.95)
	var top := Lib.pct(bends, 1.0)
	info("%d fists: the wrist bent %.0f degrees at the median, %.0f at 95%%, %.0f at most" % [bends.size(), Lib.pct(bends, 0.5), p95, top])
	expect(bends.size() > 1000, "too few fists seen (%d)" % bends.size())
	expect(p95 <= 40.0, "the wrists bent %.0f degrees in 1 frame in 20" % p95)
	expect(top <= 70.0, "a wrist bent %.0f degrees: looks broken" % top)
	await Lib.done(tree, m)
