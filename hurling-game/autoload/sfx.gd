extends Node
## Sound effects: recordings where a good one could be had (the crowd, birdsong, boots on grass, the knocks of the
## game: docs/SOUNDS.md, made by tools/audio/sounds.py), the rest synthesised at startup. An .ogg or .wav with a
## sound's name in res://assets/audio/ takes the place of the made one. The referee's whistle is recorded (Pixabay).
## They are made a sound at a time by the loading screen (build_step), so it can show its progress; anything that
## needs one before then makes the rest at once (_ensure).

const RATE := 22050
const VOICES := {"grunt": 3, "hup": 2, "step": 4}
## Sounds recorded more than once: play("roar") picks roar, roar_2 or roar_3, so a crowd never cheers twice alike.
const VARIANTS := {"crowd_cheer": 3, "roar": 3, "whistle": 3, "whistle_long": 3}
const MUSIC_DB := -9.0

var streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd: AudioStreamPlayer
var _crowd_target := -60.0
var _crowd_base := -60.0   # the bed's level for the ground (crowd())
var _swell := 0.0          # 0..1: the crowd rising as a score comes (crowd_swell())
var _music: AudioStreamPlayer
var _music_target := -80.0
var _amb: AudioStreamPlayer         # the ground's own sound under the crowd: birdsong
var _todo := []
var _planned := false
var _built := false
var _total := 1


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_crowd = AudioStreamPlayer.new()
	_crowd.volume_db = -60.0
	add_child(_crowd)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -80.0
	add_child(_music)
	_amb = AudioStreamPlayer.new()
	add_child(_amb)


## Make the next sound; false once they are all made.
func build_step() -> bool:
	if _built:
		return false
	if not _planned:
		_plan()
	if not _todo.is_empty():
		var item: Array = _todo.pop_front()
		var k: String = item[0]
		for ext in ["ogg", "wav", "mp3"]:
			var path := "res://assets/audio/%s.%s" % [k, ext]
			if ResourceLoader.exists(path):
				streams[k] = load(path)
				break
		if not streams.has(k) and item[1] != null:
			streams[k] = (item[1] as Callable).call()
		return true
	_finish()
	return false


func progress() -> float:
	if _built:
		return 1.0
	if not _planned:
		return 0.0
	return 1.0 - float(_todo.size()) / float(maxi(1, _total))


func _ensure() -> void:
	while build_step():
		pass


func _process(delta: float) -> void:
	if _crowd.playing:
		_crowd.volume_db = move_toward(_crowd.volume_db, _crowd_target, 30.0 * delta)
	if _music.playing:
		_music.volume_db = move_toward(_music.volume_db, _music_target, (20.0 if _music_target > _music.volume_db else 30.0) * delta)
		if _music_target < -60.0 and _music.volume_db <= -60.0:
			_music.stop()


func enabled() -> bool:
	return bool(Game.settings.sound)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	_ensure()
	if not enabled() or not streams.has(sound):
		return
	var n := int(VARIANTS.get(sound, 1))
	var pick := randi() % n
	var key := sound if pick == 0 or not streams.has("%s_%d" % [sound, pick + 1]) else "%s_%d" % [sound, pick + 1]
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = streams[key]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## A player's effort: voice("grunt") or "hup"; pitch gives each player his own voice.
func voice(kind: String, volume_db := -10.0, pitch := 1.0) -> void:
	var n := int(VOICES.get(kind, 0))
	if n > 0:
		play("%s_%d" % [kind, 1 + randi() % n], volume_db, pitch * randf_range(0.95, 1.05))


## The crowd reacting: "cheer", "ooh", "groan" or "applause".
func react(kind: String, volume_db := -6.0) -> void:
	play("crowd_" + kind if kind != "applause" else kind, volume_db, randf_range(0.96, 1.04))


func click() -> void:
	play("click", -8.0)


## Crowd bed: intensity 0..1; negative stops it.
func crowd(intensity: float) -> void:
	_ensure()
	if intensity < 0.0 or not enabled():
		_crowd.stop()
		_swell = 0.0
		return
	_crowd_base = lerpf(-26.0, -6.0, clampf(intensity, 0.0, 1.0))
	_crowd_target = _crowd_base + _swell * 9.0
	if not _crowd.playing:
		_crowd.volume_db = -40.0
		_crowd.play()


## The crowd rising with an attack: 0 as it was, 1 a shot in the air (up to 9 dB louder, never above -2 dB).
func crowd_swell(k: float) -> void:
	_swell = clampf(k, 0.0, 1.0)
	_crowd_target = minf(_crowd_base + _swell * 9.0, -2.0)


## Birdsong round the ground (on), or none.
func ambience(on: bool, volume_db := -14.0) -> void:
	_ensure()
	if on and enabled() and _amb.stream != null:
		_amb.volume_db = volume_db
		if not _amb.playing:
			_amb.play()
	else:
		_amb.stop()


## Everything in a match held while it is paused, and carried on after.
func pause_all(on: bool) -> void:
	_crowd.stream_paused = on
	_amb.stream_paused = on
	for p in _pool:
		p.stream_paused = on


## The menus' music: on in the menus, carrying on from one screen to the next; faded out for a match.
func music(on: bool) -> void:
	_ensure()
	if on and enabled() and bool(Game.settings.get("music", true)) and _music.stream != null:
		_music_target = MUSIC_DB
		if not _music.playing:
			_music.volume_db = -30.0
			_music.play()
	else:
		_music_target = -80.0


func stop_all() -> void:
	_crowd.stop()
	_amb.stop()
	for p in _pool:
		p.stop()


# ---------------------------------------------------------------- synthesis

func _plan() -> void:
	_planned = true
	_todo = [
		["whistle", _whistle],
		["whistle_long", func(): return _whistle(1.1)],
		["whistle_final", func(): return _whistle(1.8)],
		["whistle_double", func(): return _whistle(0.9)],
		["strike", _strike],                                # ash on leather: the crack of a full strike
		["tap", func(): return _wood(1.6, 0.03, 0.25)],     # the sliotar hopped on the bas
		["clash", func(): return _wood(0.9, 0.09, 0.8)],    # hurleys meeting
		["catch", func(): return _slap()],                  # leather into the palm
		["shoulder", func(): return _thud(0.1)],            # a shoulder charge
		["post", func(): return _wood(0.55, 0.16, 0.6)],    # off the upright
		["save", func(): return _wood(0.75, 0.06, 0.9)],
		["bounce", func(): return _thud(0.06)],             # on the grass
		["click", func(): return _tone_env(0.035, func(t): return sin(TAU * 1500.0 * t) * 0.5, 0.001, 0.03)],
		["roar", _roar],
		["crowd_loop", _crowd_loop],
	]
	for k in ["crowd_cheer", "crowd_ooh", "crowd_groan", "applause", "clap", "menu_music", "birds_loop"]:
		_todo.append([k, null])
	for kind in VOICES:
		for i in int(VOICES[kind]):
			_todo.append(["%s_%d" % [kind, i + 1], null])
	for k in VARIANTS:
		for i in range(1, int(VARIANTS[k])):
			_todo.append(["%s_%d" % [k, i + 1], null])
	_total = _todo.size()


func _finish() -> void:
	_built = true
	for k in ["crowd_loop", "menu_music", "birds_loop"]:
		if streams.get(k) is AudioStreamOggVorbis:
			(streams[k] as AudioStreamOggVorbis).loop = true
	_crowd.stream = streams.get("crowd_loop")
	_music.stream = streams.get("menu_music")
	_amb.stream = streams.get("birds_loop")


func _to_stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
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
		out[i] = float(f.call(t)) * minf(1.0, t / attack) * clampf((dur - t) / release, 0.0, 1.0)
	return _to_stream(out)


func _whistle(dur := 0.5) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (2900.0 + sin(TAU * 34.0 * t) * 180.0) / RATE
		var env := minf(1.0, t / 0.02) * clampf((dur - t) / 0.08, 0.0, 1.0)
		out[i] = sin(phase) * (0.65 + 0.35 * sin(TAU * 34.0 * t)) * env * 0.45
	return _to_stream(out)


## A full strike: the hurley's bas meets the leather with a hard, dry crack and a short woody ring.
func _strike() -> AudioStreamWAV:
	# Ash on leather, fitted to strikes measured in a broadcast of the 2026 championship (sideline cuts and a free,
	# close to the microphone): a crack, gone in 3 ms (12 dB down), its energy at 4-8 kHz and under 500 Hz with
	# little between; here a short burst of noise filtered to 3-8 kHz, the ash's brief ring at 650 Hz and a low thump.
	var dur := 0.2
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var w0 := 0.0
	var d1 := 0.0
	var d2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := randf_range(-1.0, 1.0)
		var d := w - w0
		w0 = w
		var crack := (d * 0.25 + d1 * 0.5 + d2 * 0.25) * exp(-t * 500.0) * 2.5
		d2 = d1
		d1 = d
		var body := sin(TAU * 650.0 * t) * exp(-t * 400.0) * 0.3
		var knock := sin(TAU * lerpf(300.0, 160.0, minf(1.0, t / 0.02)) * t) * exp(-t * 250.0) * 0.15
		out[i] = clampf((crack + body + knock) * 0.8, -1.0, 1.0)
	return _to_stream(out)


## Wood on wood or leather on wood: pitch scales the ring, ring its length, hit the noise of the knock.
func _wood(pitch: float, ring: float, hit: float) -> AudioStreamWAV:
	var dur := ring * 4.0 + 0.03
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.4)
		var body := sin(TAU * 900.0 * pitch * t) * 0.45 + sin(TAU * 1900.0 * pitch * t) * 0.2 + sin(TAU * 420.0 * pitch * t) * 0.3
		out[i] = (body * exp(-t / ring * 2.5) + lp * hit * exp(-t * 140.0)) * 0.75
	return _to_stream(out)


func _slap() -> AudioStreamWAV:
	var dur := 0.12
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.55)
		out[i] = (lp * exp(-t * 70.0) + sin(TAU * 260.0 * t) * 0.4 * exp(-t * 45.0)) * 0.8
	return _to_stream(out)


func _thud(ring: float) -> AudioStreamWAV:
	var dur := ring * 4.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.15)
		out[i] = (sin(TAU * lerpf(140.0, 70.0, t / dur) * t) * 0.7 + lp * 0.4) * exp(-t / ring * 2.0) * 0.7
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
		out[i] = (a * 0.8 + b * 1.4) * minf(1.0, t / 0.25) * clampf((dur - t) / 1.4, 0.0, 1.0) * 0.7
	return _to_stream(out)


func _crowd_loop() -> AudioStreamWAV:
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
		out[i] = (a * 0.6 + b * 1.2) * (0.75 + 0.25 * sin(TAU * t / dur * 2.0)) * 0.6
	var fade := int(0.3 * RATE)
	for i in fade:
		var w := float(i) / fade
		out[i] = out[i] * w + out[n - fade + i] * (1.0 - w)
	return _to_stream(out.slice(0, n - fade), true)
