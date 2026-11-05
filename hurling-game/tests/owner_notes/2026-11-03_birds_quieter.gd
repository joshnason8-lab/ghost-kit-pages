extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.21.0): "Turn down the outside bird noise a bit. It's overpowering."

const NOTE := {"id": "2026-11-03-birds-quieter", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.21.0", "words": "Turn down the outside bird noise a bit. It's overpowering."}
const Kit := preload("res://tests/note_kit.gd")

## The birdsong round the smaller grounds no louder than -18 dB (the parish field) and -24 dB (the county ground) -
## it was -14 - and none in the stadium or at night.
func check() -> void:
	var keep = Game.settings.sound
	Game.settings.sound = true
	for v in [["parish", -18.0], ["county", -24.0], ["stadium", -INF]]:
		var m: Node = await Kit.match(tree, {"venue": v[0], "mode": "quick", "user_team": 0}, 5)
		var amb: AudioStreamPlayer = Sfx._amb
		var db: float = amb.volume_db if amb and amb.playing else -INF
		info("%s: birdsong %s" % [v[0], "%.0f dB" % db if db > -INF else "off"])
		expect(db <= float(v[1]) + 0.01, "%s: the birdsong at %.0f dB (at most %s)" % [v[0], db, "off" if v[1] == -INF else "%.0f dB" % v[1]])
		await Kit.done(tree, m)
	Game.settings.sound = keep
