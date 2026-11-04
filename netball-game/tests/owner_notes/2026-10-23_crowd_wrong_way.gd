extends WsgOwnerNote
## The owner (relayed by the lead), 2026-10-23, on 0.4.1-beta: the stand seen from behind by the courtside camera
## showed faces looking away from play. (Back-filled from docs/PROGRESS.md, "Crowd facing (0.4.2)".)

const NOTE := {"id": "2026-10-23-crowd-wrong-way", "game": "netball", "date": "2026-10-23", "version": "0.4.1-beta",
	"words": "the near side's crowd looked the wrong way"}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## In every venue, on every graphics level, from every camera setting (broadcast, courtside, behind either goal: each
## stand seen from in front, from the side and from behind): every spectator as drawn faces the play - their body
## (3D, Medium and High) or their card (Low, its back drawn when the camera is behind it) turned within 60 degrees of
## the court's middle; and every 3D fan seen from behind shows the back of their head, a card seen from behind its back
## view (WsgCrowdCards' back sheet is there). Then test_runner _crowd_facing (Low and High).
func check() -> void:
	var h: Node = await Harness.make(tree)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for venue in ["arena", "hall", "outdoor"]:
			for cam in [Game.CAM_TV, Game.CAM_LOW, Game.CAM_END]:
				Game.settings.camera = cam
				var m: Match = h._study_match(3, {"venue": venue, "home": "ENG", "away": "WAL"})
				for i in 4:
					await frame()
				var eye := h.get_viewport().get_camera_3d().global_position if h.get_viewport().get_camera_3d() else Vector3(0, 9, 20)
				var n := 0
				var bad := 0
				var worst := 0.0
				var behind := 0
				var no_back := 0
				for c: Crowd in m.find_children("*", "Crowd", true, false):
					var has_back: bool = c.cards == null or c.cards._back != null
					for e: Array in c.everyone():
						var xf: Transform3D = e[0]
						var f: Vector3 = e[1]
						var mid := Vector2(-xf.origin.x, -xf.origin.z).normalized()
						var d := Vector2(f.x, f.z).normalized()
						var off := rad_to_deg(acos(clampf(d.dot(mid), -1.0, 1.0)))
						worst = maxf(worst, off)
						n += 1
						if off > 60.0:
							bad += 1
						# Seen from behind (the camera on the far side of them from the play).
						var to_cam := Vector2(eye.x - xf.origin.x, eye.z - xf.origin.z).normalized()
						if to_cam.dot(d) < 0.0:
							behind += 1
							if e[2] and not has_back:
								no_back += 1
				var what := "%s, %s, %s camera" % [["Low", "Medium", "High"][g], venue, ["TV", "Low", "End"][cam]]
				info("%s: %d spectators, %d seen from behind; each %.0f deg off the court's middle at most" % [what, n, behind, worst])
				expect(n > 0, "%s: no crowd" % what)
				expect(bad == 0, "%s: %d of %d spectators face the wrong way (up to %.0f deg off the play)" % [what, bad, n, worst])
				expect(no_back == 0, "%s: %d cards seen from behind with no back view (faces looking away)" % [what, no_back])
				m.queue_free()
				await frame()
				await frame()
	await h._crowd_facing()
	await Harness.into(self, h)
