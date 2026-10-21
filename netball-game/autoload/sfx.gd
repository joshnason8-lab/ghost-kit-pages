extends Node
## Sound effects, most synthesised at startup so the game ships few audio files. Drop an .ogg or .wav with the same
## name into res://assets/audio/ to replace any of them (assets/audio/whistle.ogg, assets/audio/kick.ogg ...).
## They are made a sound at a time by the loading screen (build_step), so it can show its progress; anything that
## needs one before then makes the rest at once (_ensure).

const RATE := 22050
const VOICES := {}
const MUSIC_DB := -9.0

var streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd: AudioStreamPlayer
var _drums: AudioStreamPlayer
var _crowd_target := -60.0
var _drums_target := -60.0
var _music: AudioStreamPlayer
var _music_target := -80.0
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
	_drums = AudioStreamPlayer.new()
	_drums.volume_db = -60.0
	add_child(_drums)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -80.0
	add_child(_music)


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
	if _drums.playing:
		_drums.volume_db = move_toward(_drums.volume_db, _drums_target, 20.0 * delta)
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
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = streams[sound]
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
		return
	_crowd_target = lerpf(-26.0, -6.0, clampf(intensity, 0.0, 1.0))
	if not _crowd.playing:
		_crowd.volume_db = -40.0
		_crowd.play()


## The crowd's drums, louder as the rally builds (0..1); negative stops them.
func drums(level: float) -> void:
	_ensure()
	if level < 0.0 or not enabled():
		_drums.stop()
		return
	_drums_target = lerpf(-24.0, -9.0, clampf(level, 0.0, 1.0))
	if not _drums.playing:
		_drums.volume_db = -40.0
		_drums.play()


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
	_drums.stop()
	for p in _pool:
		p.stop()


# ---------------------------------------------------------------- synthesis

func _plan() -> void:
	_planned = true
	_todo = [
		["whistle", _whistle],
		["whistle_long", func(): return _whistle(1.1)],
		["pass", _slap],                                     # the ball slapped into two hands: a pass or a catch
		["bounce", func(): return _tock(0.45, 0.1, 0.7)],   # a bounce pass on the floor
		["rim", _rim],                                       # the ball off the steel ring
		["swish", _net],                                     # through the net
		["click", func(): return _tone_env(0.035, func(t): return sin(TAU * 1500.0 * t) * 0.5, 0.001, 0.03)],
		["buzzer", func(): return _tone_env(0.8, func(t): return signf(sin(TAU * 196.0 * t)) * 0.3 + sin(TAU * 392.0 * t) * 0.15, 0.01, 0.1)],
		["roar", _roar],
		["crowd_loop", _crowd_loop],
	]
	for k in ["crowd_cheer", "crowd_ooh", "crowd_groan", "applause", "clap", "menu_music"]:
		_todo.append([k, null])
	_total = _todo.size()


func _finish() -> void:
	_built = true
	for k in ["crowd_loop", "drums_loop", "menu_music"]:
		if streams.get(k) is AudioStreamOggVorbis:
			(streams[k] as AudioStreamOggVorbis).loop = true
	_crowd.stream = streams.get("crowd_loop")
	_drums.stream = streams.get("drums_loop")
	_music.stream = streams.get("menu_music")


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


## The synthetic takraw ball is a hollow woven sphere: struck, it gives a short, bright, slightly ringing "tok".
## bright scales the pitch; ring how long it sounds; air how much of the thump is the foot rather than the ball.
func _tock(bright: float, ring: float, air := 0.3) -> AudioStreamWAV:
	var dur := ring * 3.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.35)
		var body := sin(TAU * 820.0 * bright * t) * 0.55 + sin(TAU * 1730.0 * bright * t) * 0.25
		var thump := sin(TAU * lerpf(160.0, 70.0, minf(1.0, t / 0.05)) * t) * air
		out[i] = (body * exp(-t / ring * 2.2) + thump * exp(-t * 35.0) + lp * 0.35 * exp(-t * 120.0)) * 0.8
	return _to_stream(out)


## A netball caught or passed: a leather-and-rubber ball slapped into two palms, a dull smack with a short thud.
func _slap() -> AudioStreamWAV:
	var dur := 0.16
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.55)
		out[i] = (lp * exp(-t * 60.0) * 0.8 + sin(TAU * lerpf(220.0, 120.0, t / dur) * t) * exp(-t * 40.0) * 0.6) * 0.8
	return _to_stream(out)


## The ball off the ring: a short metallic clang.
func _rim() -> AudioStreamWAV:
	var dur := 0.6
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var ring := sin(TAU * 1180.0 * t) * 0.4 + sin(TAU * 2630.0 * t) * 0.25 + sin(TAU * 3910.0 * t) * 0.12
		var thud := sin(TAU * 140.0 * t) * exp(-t * 30.0) * 0.5
		out[i] = (ring * exp(-t * 7.0) + thud) * 0.7
	return _to_stream(out)


func _net() -> AudioStreamWAV:
	var dur := 0.45
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.5)
		out[i] = lp * exp(-t * 9.0) * (0.6 + 0.4 * sin(TAU * 23.0 * t)) * 0.6
	return _to_stream(out)


func _whoosh() -> AudioStreamWAV:
	var dur := 0.3
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.04 + 0.25 * sin(PI * t / dur))
		out[i] = lp * sin(PI * t / dur) * 0.7
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
