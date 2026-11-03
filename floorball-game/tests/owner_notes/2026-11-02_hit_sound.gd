extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta).

const NOTE := {"id": "2026-11-02-hit-sound", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "Need a better sound when the ball is hit this sounds like a nintendo sound."}


## Every sound of the ball off a stick (a shot, a pass, a touch, stick on stick), as the game makes it: a short dry
## crack, not a note - over in under a quarter of a second, and with no pitch to it: a game console's beep is a
## periodic tone (its autocorrelation near 1 at its period); a real crack is noise and inharmonic modes dying in a few
## hundredths of a second (the autocorrelation, over 0.3 to 12 ms lags, under 0.6).
func check() -> void:
	for kind in ["shot", "pass", "touch", "clack"]:
		var s: AudioStreamWAV = Sfx.streams.get(kind)
		if s == null:
			fail("no '%s' sound" % kind)
			continue
		var n := s.data.size() / 2
		var x := PackedFloat32Array()
		x.resize(n)
		for i in n:
			x[i] = s.data.decode_s16(i * 2) / 32768.0
		var secs := float(n) / float(s.mix_rate)
		var e0 := 0.0
		for v in x:
			e0 += v * v
		var best := 0.0
		var at := 0
		var lo := int(0.0003 * s.mix_rate)
		var hi := int(0.012 * s.mix_rate)
		for lag in range(lo, hi):
			var c := 0.0
			for i in range(0, n - lag):
				c += x[i] * x[i + lag]
			var r := c / maxf(e0, 1e-9)
			if r > best:
				best = r
				at = lag
		info("%-6s %.3f s long; the most it repeats itself %.2f (at %.1f ms)" % [kind, secs, best, at * 1000.0 / s.mix_rate])
		expect(secs < 0.25, "'%s' rings %.2f s: a note, not a crack" % [kind, secs])
		expect(best < 0.6, "'%s' is a tone (it repeats itself %.2f at %.1f ms): a beep, not a crack" % [kind, best, at * 1000.0 / s.mix_rate])
