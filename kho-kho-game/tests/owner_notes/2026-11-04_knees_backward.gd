extends WsgOwnerNote
## The owner, 2026-11-04, on Sepak Takraw 0.15.27 (a screenshot of Low players in their ready stance), verbatim as Takraw
## holds it: "All that work and the players stances regressed to look like the have broken backwards knees. How does that
## happen its unacceptable." "Refs knees also bent wrong" - filed for Kho Kho by the lead's ruling (no knee bends backward
## on any tier, for players or officials, outside named acrobatics): Kho Kho Rush 0.12.15 had it on Low - the foot
## planter's knee pole was reversed on this rig (foundation e04af650), and switched off under a kneeling chaser it still
## bent his knees back 25-28 cm.

const NOTE := {"id": "2026-11-04-knees-backward", "game": "kho-kho", "date": "2026-11-04", "version": "Sepak Takraw 0.15.27", "words": "All that work and the players stances regressed to look like the have broken backwards knees. How does that happen its unacceptable. Refs knees also bent wrong"}
const KK := preload("res://tests/note_kk.gd")
## The lead's thresholds (2026-11-04, the foundation's "knees" rule): a leg fails on more than 2 backward frames in a
## row, on more than 0.5% of its bent frames, or on any frame more than 15 cm back. Fewer, shorter strays (the planter's
## step flick, foundation #82) are "knee_strays", put off until 2026-11-13 12:00 - reported, not failed, till then.
const RUN_MAX := 2
const SHARE_MAX := 0.005
const BACK_MAX_CM := 15.0
const STRAYS_UNTIL := "2026-11-13T12:00Z"
const HIGH_UNTIL := "2026-11-06T12:00Z"
const HIGH_WHY := "High WsgBody knees under trace, foundation"


## Every player and official drawn, on Low (the A16's level) and on High, in a quick match and in Watch AI, for 20 s of
## play each, by the foundation's knees measure (WsgNoteChecks.knees: forward from the hips, 1.5 cm bent, 4 cm back).
func check() -> void:
	for gfx in [Game.GFX_LOW, Game.GFX_HIGH]:
		for watch in [false, true]:
			var m: Node = await KK.play(tree, {"gfx": gfx, "user_team": -1 if watch else 0, "venue": "maidan", "seed": 11})
			var r: Array = await KK.knees(tree, m, 600)
			var where := "%s, %s" % ["Low" if gfx == Game.GFX_LOW else "High", "Watch AI" if watch else "quick match"]
			var strays := 0
			expect(int(r[0]) >= 30, "%s: only %d legs read" % [where, int(r[0])])
			for who in r[1]:
				var s: Dictionary = r[1][who]
				if int(s.back) == 0:
					continue
				var msg := "%s: %s: knee behind the hip-ankle line on %d of %d bent frames (%d in a row), %.1f cm at worst (act '%s')" % [where, who, s.back, s.bent, s.run, float(s.worst) * 100.0, s.act]
				var broken: bool = int(s.run) > RUN_MAX or float(s.back) / maxf(1.0, float(s.bent)) > SHARE_MAX or float(s.worst) * 100.0 > BACK_MAX_CM
				if gfx == Game.GFX_HIGH and _now() < HIGH_UNTIL:
					info("DEFERRED (%s, until %s): %s" % [HIGH_WHY, HIGH_UNTIL, msg])
				elif broken:
					fail(msg)
				elif _now() < STRAYS_UNTIL:
					strays += 1
					info("DEFERRED (knee_strays, the planter's step flick, foundation #82, until %s): %s" % [STRAYS_UNTIL, msg])
				else:
					fail(msg)
			info("%s: %d legs read, %d with a stray" % [where, int(r[0]), strays])
			await KK.done(tree, m)


func _now() -> String:
	return OS.get_environment("WSG_NOW") if OS.get_environment("WSG_NOW") != "" else Time.get_datetime_string_from_system(true).left(16) + "Z"
