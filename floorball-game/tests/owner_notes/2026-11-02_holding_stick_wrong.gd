extends WsgOwnerNote
## The owner, 2026-11-02, through the lead (Floorball 0.9.1-beta).

const NOTE := {"id": "2026-11-02-holding-stick-wrong", "game": "floorball", "date": "2026-11-02", "version": "0.9.1-beta",
	"words": "holding stick wrong"}

const Lib := preload("res://tests/note_lib.gd")


## Over 40 seconds of AI play, every skater as drawn: the top fist on the shaft (its grip within 3 cm of the shaft's
## line) in every frame, the lower fist in 95% of the frames it holds the stick (one-handed on a sprint it is off by
## design), at Medium and Low.
func check() -> void:
	if not Lib.have_foundation():
		skip("no licensed clips here: the shared foundation's bodies are not drawn")
		return
	var keep: int = Game.settings.graphics
	for gfx in [Game.GFX_MEDIUM, Game.GFX_LOW]:
		Game.settings.graphics = gfx
		var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": 3, "period": 4.0})
		var top := [0, 0]
		var low := [0, 0]
		for t in 2:
			for p: Player in m.skaters(t):
				if p.link:
					p.link.measure = true
		var n := await Lib.each_posed(tree, m, 60 * 40, func(p: Player, _b: WsgBody):
			var lf: Dictionary = p.link.last_fists
			if lf.has(p.link.top):
				top[1] += 1
				if float(lf[p.link.top]) <= 0.03:
					top[0] += 1
			if lf.has(p.link.low):
				low[1] += 1
				if float(lf[p.link.low]) <= 0.03:
					low[0] += 1)
		info("graphics %d: %d posed frames; top fist on the shaft %d/%d, lower %d/%d" % [gfx, n, top[0], top[1], low[0], low[1]])
		expect(top[1] > 1000 and top[0] == top[1], "graphics %d: the top fist off the shaft in %d of %d frames" % [gfx, top[1] - top[0], top[1]])
		expect(low[1] > 1000 and low[0] >= low[1] * 0.95, "graphics %d: the lower fist off the shaft in %d of %d frames" % [gfx, low[1] - low[0], low[1]])
		await Lib.done(tree, m)
	Game.settings.graphics = keep
