extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta.

const NOTE := {"id": "2026-11-03-net-sway", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "The net should move when the ball goes in, it's rope and should sway."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const Nets := preload("res://tests/owner_notes/lib/nets.gd")
## Pixels at 720 lines a goal must move the net on the screen, by camera: the broadcast camera's close shot of the
## post (its cut for a goal: the net about 11 m off) a sway you see at a glance on a phone; courtside (about 20 m off)
## half that. Behind the goal the camera looks at the far goal, 40 m off: measured, not held to a number.
const PX := {Game.CAM_TV: 8.0, Game.CAM_LOW: 4.0, Game.CAM_END: 0.0}


## In every venue, a goal swings the net it drops through and then it settles, the other net still, by the glow
## shader's own uniforms (test_runner _net_sway: 2 cm to Arena.NET_MAX at its foot, settled within 5 s); and the
## viewer sees it sway: on each camera setting (the broadcast camera, whose close shot of the post a goal brings;
## courtside; behind the goal) the net's foot and its cords move at least PX pixels at 720 lines on the screen.
func check() -> void:
	var h: Node = await Harness.make(tree)
	await h._net_sway()
	for venue in ["arena", "hall", "outdoor"]:
		for cam in [Game.CAM_TV, Game.CAM_LOW, Game.CAM_END]:
			var r: Dictionary = await Nets.shot(h, venue, cam, true)
			var what := "%s, a goal, %s camera" % [venue, ["TV", "Low", "End"][cam]]
			info("%s: the net moves %.1f cm, %.1f px on the screen (%s)" % [what, r.cm, r.px, r.camera])
			expect(r.seen, "%s: the net is not on the screen as the goal goes in" % what)
			expect(float(r.px) >= float(PX[cam]), "%s: the net moves %.1f px on the screen (%.1f cm), under %.0f: too little to see it sway" % [what,
				r.px, r.cm, PX[cam]])
	await Harness.into(self, h)
