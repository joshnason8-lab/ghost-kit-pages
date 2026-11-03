extends WsgOwnerNote
## The owner, 2026-11-02 (Kho Kho Rush 0.11.1): "The player is moving himself and dodging by himself when I'm supposed to be playing."

const NOTE := {"id": "2026-11-02-plays-himself", "game": "kho-kho", "date": "2026-11-02", "version": "Kho Kho Rush 0.11.1", "words": "The player is moving himself and dodging by himself when I'm supposed to be playing."}
const KK := preload("res://tests/note_kk.gd")


## Your defender, thumb off the stick, over 6 s of play at two grounds: he asks for no run and never dodges.
func check() -> void:
	for venue in ["school", "floodlit"]:
		var m: Node = await KK.play(tree, {"chase_first": 1, "venue": venue})
		m.controls.joystick = Vector2.ZERO
		var asked := 0.0
		var dodged := false
		for i in 180:
			await frame()
			if m.user_def:
				asked = maxf(asked, m.user_def.want.length())
				dodged = dodged or m.user_def.act == "dodge"
		expect(asked < 0.5 and not dodged, "%s: with no thumb on it he asked for %.1f m/s%s" % [venue, asked, ", and dodged" if dodged else ""])
		await KK.done(tree, m)
