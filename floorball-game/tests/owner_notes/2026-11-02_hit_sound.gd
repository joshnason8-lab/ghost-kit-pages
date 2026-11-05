extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta).

const NOTE := {"id": "2026-11-02-hit-sound", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "Need a better sound when the ball is hit this sounds like a nintendo sound."}


## Every sound of the ball off a stick (a shot, a pass, a touch, stick on stick), as the game makes it: a short dry
## crack, not a console's note - over in under a quarter of a second, and not a steady tone: a game console's beep (a
## square or sine wave) repeats itself almost exactly (its autocorrelation at its period 0.95 or more); a hollow
## ball's tock rings a few inharmonic modes for a few hundredths of a second (under 0.85). The measure is checked
## against a synthesised beep first: it must call that a beep.
func check() -> void:
	var rate := 44100
	var beep := PackedFloat32Array()
	for i in int(0.15 * rate):
		beep.append(0.6 if fmod(i * 880.0 / rate, 1.0) < 0.5 else -0.6)
	var b := _repeats(beep, rate)
	info("a console beep (an 880 Hz square, 0.15 s): it repeats itself %.2f" % b[0])
	expect(b[0] >= 0.85, "the measure does not catch a beep (%.2f)" % b[0])
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
		var r := _repeats(x, s.mix_rate)
		info("%-6s %.3f s long; the most it repeats itself %.2f (at %.1f ms)" % [kind, secs, r[0], r[1]])
		expect(secs < 0.25, "'%s' rings %.2f s: a note, not a crack" % [kind, secs])
		expect(r[0] < 0.85, "'%s' is a steady tone (it repeats itself %.2f at %.1f ms): a beep, not a crack" % [kind, r[0], r[1]])


## The most a sound repeats itself (normalised autocorrelation) over 0.3 to 12 ms lags, and at which lag (ms).
func _repeats(x: PackedFloat32Array, rate: int) -> Array:
	var n := x.size()
	var e0 := 0.0
	for v in x:
		e0 += v * v
	var best := 0.0
	var at := 0
	for lag in range(int(0.0003 * rate), int(0.012 * rate)):
		var c := 0.0
		for i in range(0, n - lag):
			c += x[i] * x[i + lag]
		var r := c / maxf(e0, 1e-9)
		if r > best:
			best = r
			at = lag
	return [best, at * 1000.0 / rate]
