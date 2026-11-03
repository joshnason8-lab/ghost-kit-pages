extends WsgOwnerNote
## The owner, 2026-11-03, on 0.9.0-beta (after the rope nets of 0.9.0).

const NOTE := {"id": "2026-11-03-net-still-not-moving", "game": "netball", "date": "2026-11-03", "version": "0.9.0-beta",
	"words": "Net still isn't moving when ball hits it."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const Nets := preload("res://tests/owner_notes/lib/nets.gd")
## Pixels at 720 lines the net must move on the screen: [a goal through it, a ball off the ring], by camera - the
## broadcast camera's close shot of the post (about 11 m off), courtside (about 20 m), behind the goal (it looks at the
## far goal, 40 m off: measured, not held to a number).
const PX := {Game.CAM_TV: [8.0, 4.0], Game.CAM_LOW: [4.0, 2.0], Game.CAM_END: [0.0, 0.0]}


## The ball hitting the net, as the viewer sees it, on every graphics level, in every venue, on every camera setting:
## a goal through it moves the net (its foot's swing and its cords' ripple) and a shot off the ring stirs it, by PX
## pixels or more on the screen at 720 lines; and it settles again (under 4 mm five seconds on).
func check() -> void:
	var h: Node = await Harness.make(tree)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		var lv: String = ["Low", "Medium", "High"][g]
		for venue in ["arena", "hall", "outdoor"]:
			for cam in [Game.CAM_TV, Game.CAM_LOW, Game.CAM_END]:
				for goal in [true, false]:
					# (Every level on the broadcast camera; the other cameras on Medium, the same nets on every level.)
					if g != Game.GFX_MEDIUM and cam != Game.CAM_TV:
						continue
					var r: Dictionary = await Nets.shot(h, venue, cam, goal, 40 + g)
					var what := "%s, %s, %s, %s camera" % [lv, venue, "a goal" if goal else "off the ring", ["TV", "Low", "End"][cam]]
					var need: float = PX[cam][0 if goal else 1]
					info("%s: %.1f cm, %.1f px on the screen (%s)" % [what, r.cm, r.px, r.camera])
					expect(r.moved, "%s: the net does not move at all" % what)
					expect(float(r.px) >= need, "%s: the net moves %.1f px on the screen (%.1f cm), under %.0f: it looks still" % [what, r.px, r.cm, need])
					expect(float(r.settle_mm) < 4.0, "%s: still swinging %.1f mm five seconds on" % [what, r.settle_mm])
	await Harness.done(h)
