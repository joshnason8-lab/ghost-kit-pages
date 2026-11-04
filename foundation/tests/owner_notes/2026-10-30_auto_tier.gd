extends WsgOwnerNote
## The owner, 2026-10-30 (Hurling 0.18 on the A16): "Graphics were set to high and lower graphics by itself was set on but the graphics didnt lower even though there was a lot of stuttering."

const NOTE := {"id": "2026-10-30-auto-tier", "game": "hurling", "date": "2026-10-30", "version": "Hurling 0.18 on the A16", "words": "Graphics were set to high and lower graphics by itself was set on but the graphics didnt lower even though there was a lot of stuttering."}

## Stuttering at 60 fps (a 120 ms hitch every half second): the auto tier steps the graphics down within 6 seconds;
## a steady 30 fps phone (capped) is left alone.
func check() -> void:
	var at := WsgAutoTier.new(60)
	var t := 0.0
	var down_at := -1.0
	while t < 12.0:
		var dt := 0.120 if fmod(t, 0.5) < 1.0 / 60.0 else 1.0 / 60.0
		t += dt
		if at.feed(dt):
			down_at = t
			break
	info("stuttering: stepped down after %.1f s" % down_at if down_at > 0.0 else "stuttering: never stepped down")
	expect(down_at > 0.0 and down_at <= 6.0, "the graphics did not lower by themselves while stuttering")
	var steady := WsgAutoTier.new(30)
	var t2 := 0.0
	var wrongly := false
	while t2 < 12.0:
		t2 += 1.0 / 30.0
		wrongly = wrongly or steady.feed(1.0 / 30.0)
	expect(not wrongly, "a steady 30 fps phone was stepped down")
