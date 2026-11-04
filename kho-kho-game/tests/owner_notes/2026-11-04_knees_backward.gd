extends WsgOwnerNote
## The lead's ruling, 2026-11-04, on the owner's report to Sepak Takraw (Takraw 0.15.27, with a screenshot) as relayed:
## "players' stances look like broken backwards knees; refs' knees are bent wrong too". No knee bends backward on any
## tier, for players or officials, outside named acrobatics. (Kho Kho Rush 0.12.15 had it on Low: the foot planter's
## knee pole was reversed on this rig - foundation e04af650 - and switched off under a kneeling chaser it still bent his
## knees back 25-28 cm.)

const NOTE := {"id": "2026-11-04-knees-backward", "game": "kho-kho", "date": "2026-11-04", "version": "Kho Kho Rush 0.12.15", "words": "The lead's ruling on the owner's Takraw 0.15.27 report, as relayed: \"players' stances look like broken backwards knees; refs' knees are bent wrong too\" - no knee bends backward on any tier, for players or officials, outside named acrobatics."}
const KK := preload("res://tests/note_kk.gd")
## Interim, named as such (the foundation, 2026-11-04): single swing-leg flicks the foundation is still tracing - a leg
## may show at most this many backward frames, no further back than this, until the trace lands. Anything more - a
## knee held backwards, or a kneeling chaser's - fails.
const STRAY_FRAMES := 8
const STRAY_CM := 12.0


## Every player and official drawn, on Low (the A16's level) and on High, in a quick match and in Watch AI, for 20 s of
## play each: no bent knee behind the line from his hip to his ankle (the foundation's knees rule: 1.5 cm bent, 4 cm back).
func check() -> void:
	for gfx in [Game.GFX_LOW, Game.GFX_HIGH]:
		for watch in [false, true]:
			var m: Node = await KK.play(tree, {"gfx": gfx, "user_team": -1 if watch else 0, "venue": "maidan", "seed": 11})
			var r: Array = await KK.knees(tree, m, 600)
			var where := "%s, %s" % ["Low" if gfx == Game.GFX_LOW else "High", "Watch AI" if watch else "quick match"]
			var strays := 0
			expect(int(r[0]) >= 30, "%s: only %d legs read" % [where, int(r[0])])
			for who in r[2]:
				var s: Dictionary = r[2][who]
				if int(s.back) == 0:
					continue
				if int(s.back) <= STRAY_FRAMES and float(s.worst) * 100.0 <= STRAY_CM:
					strays += 1
					continue
				fail("%s: %s: knee behind the hip-ankle line on %d of %d bent frames, %.0f cm at worst (act '%s')" % [where, who, s.back, s.bent, float(s.worst) * 100.0, s.act])
			info("%s: %d legs read, %d with a stray backward frame or two (interim allowance)" % [where, int(r[0]), strays])
			await KK.done(tree, m)
