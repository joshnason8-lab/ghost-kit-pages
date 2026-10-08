extends Node
## Sound effects synthesised at startup, so the game ships without audio files.
## Drop an .ogg or .wav with the same name into res://assets/audio/ to replace any of them
## (for example assets/audio/whistle.ogg or assets/audio/crowd_loop.ogg).

const RATE := 22050
const VOICES := {"grunt": 5, "oof": 3, "exhale": 2, "hup": 2}

var streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd: AudioStreamPlayer
var _drums: AudioStreamPlayer
var _crowd_target := -60.0


func _ready() -> void:
	_build()
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_crowd = AudioStreamPlayer.new()
	_crowd.stream = streams.crowd_loop
	_crowd.volume_db = -60.0
	add_child(_crowd)
	_drums = AudioStreamPlayer.new()
	_drums.stream = streams.dhol_loop
	_drums.volume_db = -14.0
	add_child(_drums)


func _process(delta: float) -> void:
	if _crowd.playing:
		_crowd.volume_db = move_toward(_crowd.volume_db, _crowd_target, 30.0 * delta)


func enabled() -> bool:
	return bool(Game.settings.sound)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not enabled() or not streams.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## A player shouting, e.g. yell("pakad"). Slight pitch variation per call.
func yell(word: String, volume_db := -4.0) -> void:
	play("yell_" + word, volume_db, randf_range(0.92, 1.12))


## One "kabaddi!" from the raider's chant.
func chant_word(volume_db := -6.0) -> void:
	play("chant_word_%d" % (1 + randi() % 2), volume_db, randf_range(0.95, 1.08))


## A player's effort, impact or breath: voice("grunt"), "oof", "exhale" or "hup". Pitch
## gives each player his own voice.
func voice(kind: String, volume_db := -8.0, pitch := 1.0) -> void:
	var n := int(VOICES.get(kind, 0))
	if n > 0:
		play("%s_%d" % [kind, 1 + randi() % n], volume_db, pitch * randf_range(0.95, 1.05))


## The crowd reacting: "cheer", "ooh", "groan" or "applause".
func react(kind: String, volume_db := -6.0) -> void:
	play("crowd_" + kind if kind != "applause" else kind, volume_db, randf_range(0.96, 1.04))


func click() -> void:
	play("click", -8.0)


## Crowd bed: intensity 0..1. Pass a negative value to stop.
func crowd(intensity: float) -> void:
	if intensity < 0.0 or not enabled():
		_crowd.stop()
		return
	_crowd_target = lerpf(-24.0, -5.0, clampf(intensity, 0.0, 1.0))
	if not _crowd.playing:
		_crowd.volume_db = -40.0
		_crowd.play()


func drums(on: bool) -> void:
	if on and enabled():
		if not _drums.playing:
			_drums.play()
	else:
		_drums.stop()


func stop_all() -> void:
	_crowd.stop()
	_drums.stop()
	for p in _pool:
		p.stop()


# ---------------------------------------------------------------- synthesis

func _build() -> void:
	streams.whistle = _whistle()
	streams.buzzer = _tone_env(0.9, func(t): return signf(sin(TAU * 196.0 * t)) * 0.35 + sin(TAU * 392.0 * t) * 0.15, 0.01, 0.1)
	streams.thud = _thud()
	streams.slap = _slap()
	streams.whoosh = _whoosh()
	streams.click = _tone_env(0.035, func(t): return sin(TAU * 1500.0 * t) * 0.5, 0.001, 0.03)
	streams.gavel = _gavel()
	streams.roar = _roar()
	streams.crowd_loop = _crowd_loop()
	streams.dhol_loop = _dhol_loop()
	streams.bid = _tone_env(0.08, func(t): return sin(TAU * 880.0 * t) * 0.4 + sin(TAU * 1320.0 * t) * 0.2, 0.002, 0.07)
	# Recorded voices that have no synthesised stand-in: chants and players shouting.
	for k in ["chant_raider", "crowd_chant", "chant_word_1", "chant_word_2", "yell_aaja", "yell_pakad",
			"yell_shabash", "yell_chal", "yell_haan", "yell_nahi", "yell_touch",
			"crowd_cheer", "crowd_ooh", "crowd_groan", "applause", "clap"]:
		streams[k] = null
	# Players' efforts and breaths (see tools/audio/make_sounds.py).
	for kind in VOICES:
		for i in int(VOICES[kind]):
			streams["%s_%d" % [kind, i + 1]] = null
	for k in streams.keys():
		for ext in ["ogg", "wav", "mp3"]:
			var path := "res://assets/audio/%s.%s" % [k, ext]
			if ResourceLoader.exists(path):
				streams[k] = load(path)
				break
	for k in streams.keys():
		if streams[k] == null:
			streams.erase(k)
	for k in ["crowd_loop", "dhol_loop"]:
		if streams.get(k) is AudioStreamOggVorbis:
			(streams[k] as AudioStreamOggVorbis).loop = true


func _to_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


func _tone_env(dur: float, f: Callable, attack: float, release: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / attack) * clampf((dur - t) / release, 0.0, 1.0)
		out[i] = float(f.call(t)) * env
	return _to_stream(out)


func _whistle() -> AudioStreamWAV:
	# Pea whistle: a bright tone warbled by the pea.
	var dur := 0.55
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq := 2900.0 + sin(TAU * 34.0 * t) * 180.0
		phase += TAU * freq / RATE
		var trill := 0.65 + 0.35 * sin(TAU * 34.0 * t)
		var env := minf(1.0, t / 0.02) * clampf((dur - t) / 0.08, 0.0, 1.0)
		out[i] = sin(phase) * trill * env * 0.45
	return _to_stream(out)


func _thud() -> AudioStreamWAV:
	var dur := 0.35
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq := lerpf(95.0, 38.0, t / dur)
		phase += TAU * freq / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.15)
		var env := exp(-t * 11.0)
		out[i] = (sin(phase) * 0.8 + lp * 0.6 * exp(-t * 30.0)) * env
	return _to_stream(out)


func _slap() -> AudioStreamWAV:
	var dur := 0.09
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := randf_range(-1.0, 1.0)
		var hp := w - prev
		prev = w
		out[i] = hp * exp(-t * 60.0) * 0.6
	return _to_stream(out)


func _whoosh() -> AudioStreamWAV:
	var dur := 0.3
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := 0.04 + 0.25 * sin(PI * t / dur)
		lp = lerpf(lp, randf_range(-1.0, 1.0), k)
		out[i] = lp * sin(PI * t / dur) * 0.7
	return _to_stream(out)


func _gavel() -> AudioStreamWAV:
	var dur := 0.25
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = (sin(TAU * 620.0 * t) * 0.5 + sin(TAU * 310.0 * t) * 0.4 + sin(TAU * 1240.0 * t) * 0.15) * exp(-t * 28.0)
	return _to_stream(out)


func _roar() -> AudioStreamWAV:
	var dur := 2.4
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := float(i) / RATE
		a = lerpf(a, randf_range(-1.0, 1.0), 0.09)
		b = lerpf(b, randf_range(-1.0, 1.0), 0.02)
		var env := minf(1.0, t / 0.25) * clampf((dur - t) / 1.4, 0.0, 1.0)
		out[i] = (a * 0.8 + b * 1.4) * env * 0.7
	return _to_stream(out)


func _crowd_loop() -> AudioStreamWAV:
	# Murmur: layered low-passed noise with slow swells. Crossfaded ends so the loop is seamless.
	var dur := 4.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := float(i) / RATE
		a = lerpf(a, randf_range(-1.0, 1.0), 0.07)
		b = lerpf(b, randf_range(-1.0, 1.0), 0.015)
		var swell := 0.75 + 0.25 * sin(TAU * t / dur * 2.0)
		out[i] = (a * 0.6 + b * 1.2) * swell * 0.6
	var fade := int(0.3 * RATE)
	for i in fade:
		var w := float(i) / fade
		out[i] = out[i] * w + out[n - fade + i] * (1.0 - w)
	return _to_stream(out.slice(0, n - fade), true)


func _dhol_loop() -> AudioStreamWAV:
	# Bhangra-style dhol: heavy "dagga" on the beat, sharp "tilli" on the off-beats. 100 bpm.
	var beat := 0.6
	var dur := beat * 4.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var hits := [[0.0, "dagga"], [0.45, "tilli"], [0.6, "dagga"], [0.9, "tilli"], [1.2, "dagga"], [1.65, "tilli"], [1.8, "dagga"], [2.1, "tilli"], [2.25, "tilli"]]
	for h in hits:
		var start := int(float(h[0]) * RATE)
		var phase := 0.0
		for j in int(0.35 * RATE):
			var i := start + j
			if i >= n:
				break
			var t := float(j) / RATE
			if h[1] == "dagga":
				phase += TAU * lerpf(120.0, 55.0, minf(1.0, t / 0.2)) / RATE
				out[i] += sin(phase) * exp(-t * 9.0) * 0.7
			else:
				out[i] += (sin(TAU * 520.0 * t) * 0.3 + randf_range(-0.3, 0.3)) * exp(-t * 40.0)
	return _to_stream(out, true)
