extends TakrawNote
## The owner, 2026-10-26: "Have the flags in the crowds match the teams playing."

const NOTE := {"id": "2026-10-26-crowd-flags", "game": "sepak-takraw", "date": "2026-10-26", "version": "0.11.1",
	"words": "Have the flags in the crowds match the teams playing."}


## In a match between two countries and one between two clubs, the flags the crowd waves are the two sides' (a
## country's own flag; a club's colours), the home side's and the visitors'.
func check() -> void:
	for pair in [["THA", "MAS"], ["VIE", "INA"], [String(DB.league_clubs("MY")[0]), String(DB.league_clubs("MY")[1])]]:
		var m := make_match({"home": pair[0], "away": pair[1], "venue": "national"})
		await frame()
		var tex: Texture2D = Crowd._flag_material().get_shader_parameter("flags")
		var img := tex.get_image() if tex else null
		if not expect(img != null, "%s v %s: no flags in the crowd" % pair):
			continue
		var w := Crowd.FLAG_W
		var h := Crowd.FLAG_H
		var home: Image = Crowd.team_flag(pair[0]).duplicate()
		var away: Image = Crowd.team_flag(pair[1]).duplicate()
		for f in [home, away]:
			(f as Image).convert(Image.FORMAT_RGBA8)
			if (f as Image).get_size() != Vector2i(w, h):
				(f as Image).resize(w, h, Image.INTERPOLATE_LANCZOS)
		var same := 0
		var looked := 0
		for q in [Vector2i(w / 4, h / 4), Vector2i(w / 2, h / 2), Vector2i(3 * w / 4, 3 * h / 4)]:
			looked += 2
			same += 1 if _close(img.get_pixel(q.x, q.y), home.get_pixel(q.x, q.y)) else 0
			same += 1 if _close(img.get_pixel(w + q.x, q.y), away.get_pixel(q.x, q.y)) else 0
		info("%s v %s: the crowd's flags match the sides' at %d of %d points" % [pair[0], pair[1], same, looked])
		expect(same == looked, "%s v %s: the crowd's flags are not the two sides' (%d of %d points)" % [pair[0], pair[1], same, looked])
		m.queue_free()
		await frame()
	await clean()


static func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.12
