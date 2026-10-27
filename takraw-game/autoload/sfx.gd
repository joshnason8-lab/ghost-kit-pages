extends Node
## Sound effects: recordings (assets/audio/*.ogg, FILES; docs/SOUNDS.md says where each comes from and under what
## licence) and, where nothing recorded fits yet, sounds synthesised at startup (the review's buzzer, a whoosh). A recording with a synthesised sound's name replaces it. They are made ready a sound at a time by the
## loading screen (build_step), so it can show its progress; anything that needs one before then makes the rest at
## once (_ensure).
##
## The ball's sounds and the players' footsteps come from where they happen (play_at: heard from the camera); the
## crowd's murmur, its reactions, the place's own sound (ambience) and the music are all around. Pausing a match holds
## them all (pause); the Sound and Music switches in Settings turn them off.

const RATE := 22050
const VOICES := {"grunt": 3, "hup": 2}
const MUSIC_DB := -9.0
## Sounds recorded in more than one take: <name>, <name>_2 ... one picked at random each time.
const VARIANTS := {"kick": 3, "knee": 2, "bounce": 2, "step_court": 3, "step_sand": 3, "crowd_cheer": 3, "applause": 3,
	"whistle": 3, "whistle_long": 3}
## Every recorded sound the game plays (assets/audio/<name>.ogg).
const FILES := ["kick", "kick_2", "kick_3", "knee", "knee_2", "spike", "block", "bounce", "bounce_2", "bounce_sand", "net",
	"crowd_loop", "crowd_cheer", "crowd_cheer_2", "crowd_cheer_3", "crowd_rhythm", "crowd_ooh", "crowd_groan", "applause",
	"applause_2", "applause_3", "clap", "amb_beach", "amb_park",
	"amb_chatter", "step_court", "step_court_2", "step_court_3", "step_sand", "step_sand_2", "step_sand_3", "click",
	"menu_music", "drums_loop", "grunt_1", "grunt_2", "grunt_3", "hup_1", "hup_2", "whistle", "whistle_2", "whistle_3",
	"whistle_long", "whistle_long_2", "whistle_long_3", "whistle_double", "whistle_final", "whistle_gym"]
const LOOPS := ["crowd_loop", "drums_loop", "menu_music", "amb_beach", "amb_park", "amb_chatter"]

var streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd: AudioStreamPlayer
var _drums: AudioStreamPlayer
var _crowd_target := -60.0
var _drums_target := -60.0
var _music: AudioStreamPlayer
var _music_target := -80.0
var _amb: AudioStreamPlayer
var _amb_target := -60.0
var _pool3d: Array[AudioStreamPlayer3D] = []
var _next3d := 0
var _held: Array = []         # the players paused with the match
var _surface := "court"       # the floor's footsteps: "court", "sand", or "" (none: the home screen's match)
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
	_amb = AudioStreamPlayer.new()
	_amb.volume_db = -60.0
	add_child(_amb)
	for i in 12:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC
		p.unit_size = 16.0               # (about the camera's distance: as loud as before from there)
		p.max_db = 3.0
		p.panning_strength = 0.6         # to the side, not hard into one ear
		p.attenuation_filter_db = 0.0    # (no muffling with distance: the court is small)
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_pool3d.append(p)


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
	if _amb.playing:
		_amb.volume_db = move_toward(_amb.volume_db, _amb_target, 20.0 * delta)
	if _music.playing:
		_music.volume_db = move_toward(_music.volume_db, _music_target, (20.0 if _music_target > _music.volume_db else 30.0) * delta)
		if _music_target < -60.0 and _music.volume_db <= -60.0:
			_music.stop()


func enabled() -> bool:
	return bool(Game.settings.sound)


func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	_ensure()
	var key := _take(sound)
	if not enabled() or not streams.has(key):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	_start(p, streams[key], volume_db, pitch)


## A sound from a place on the court (the ball, a player's feet), heard from the camera: to its side as it is, quieter
## the further off.
func play_at(sound: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	_ensure()
	var key := _take(sound)
	if not enabled() or not streams.has(key):
		return
	var p := _pool3d[_next3d]
	_next3d = (_next3d + 1) % _pool3d.size()
	p.global_position = at
	_start(p, streams[key], volume_db, pitch)


func _start(p: Node, stream: AudioStream, volume_db: float, pitch: float) -> void:
	_held.erase(p)
	p.stream_paused = false
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## One of a sound's takes (VARIANTS).
func _take(sound: String) -> String:
	var n := int(VARIANTS.get(sound, 1))
	var k := randi() % n if n > 1 else 0
	return sound if k == 0 else "%s_%d" % [sound, k + 1]


## The ball on the floor: on the court, or on sand.
func bounce(at: Vector3, volume_db := -2.0) -> void:
	play_at("bounce_sand" if _surface == "sand" else "bounce", at, volume_db, randf_range(0.95, 1.05))


## What the players' feet are on: "court", "sand", or "" for no footsteps.
func surface(kind: String) -> void:
	_surface = kind


## A footstep at a player's feet, louder the faster he runs.
func step(at: Vector3, speed: float) -> void:
	if _surface != "":
		play_at("step_" + _surface, at, lerpf(-26.0, -14.0, clampf(speed / 6.0, 0.0, 1.0)), randf_range(0.92, 1.08))


## The place's own sound under everything (the sea, the birds, a market's chatter), volume_db; "" stops it.
func ambience(name: String, volume_db := -10.0) -> void:
	_ensure()
	if name == "" or not enabled() or not streams.has(name):
		_amb.stop()
		return
	_amb_target = volume_db
	if _amb.stream != streams[name] or not _amb.playing:
		_amb.stream = streams[name]
		_amb.volume_db = -40.0
		_amb.play()


## The match paused: every sound held where it is (and carried on from there after).
func pause(on: bool) -> void:
	if on:
		for p in _players():
			if p.playing and not p.stream_paused:
				p.stream_paused = true
				_held.append(p)
	else:
		for p in _held:
			p.stream_paused = false
		_held.clear()


## A player's effort: voice("grunt") or "hup"; pitch gives each player his own voice.
func voice(kind: String, volume_db := -10.0, pitch := 1.0) -> void:
	var n := int(VOICES.get(kind, 0))
	if n > 0:
		play("%s_%d" % [kind, 1 + randi() % n], volume_db, pitch * randf_range(0.95, 1.05))


## The crowd reacting: "cheer", "ooh", "groan", "applause" or "rhythm" (clapping in time).
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
	_held.clear()
	_crowd.stop()
	_drums.stop()
	_amb.stop()
	for p in _players():
		p.stream_paused = false
		p.stop()


## Every player of sounds (not the music's).
func _players() -> Array:
	var all := []
	all.append_array(_pool)
	all.append_array(_pool3d)
	all.append_array([_crowd, _drums, _amb])
	return all


# ---------------------------------------------------------------- synthesis

func _plan() -> void:
	_planned = true
	_todo = [
		["whistle", _whistle],
		["whistle_long", func(): return _whistle(1.1)],
		["kick", func(): return _tock(1.0, 0.09)],          # an instep or inside kick: the ball's hollow "tok"
		["knee", func(): return _tock(0.7, 0.07)],          # a thigh, chest or head touch: duller
		["spike", _spike],
		["block", _block],
		["bounce", func(): return _tock(0.55, 0.12, 0.6)],  # the ball landing on the floor
		["net", _net],
		["whoosh", _whoosh],
		["click", func(): return _tone_env(0.035, func(t): return sin(TAU * 1500.0 * t) * 0.5, 0.001, 0.03)],
		["buzzer", func(): return _tone_env(0.8, func(t): return signf(sin(TAU * 196.0 * t)) * 0.3 + sin(TAU * 392.0 * t) * 0.15, 0.01, 0.1)],
		["roar", _roar],
		["crowd_loop", _crowd_loop],
	]
	var made := _todo.map(func(item): return item[0])
	for k in FILES:
		if not k in made:
			_todo.append([k, null])
	_total = _todo.size()


func _finish() -> void:
	_built = true
	for k in LOOPS:
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


func _spike() -> AudioStreamWAV:
	var dur := 0.35
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := randf_range(-1.0, 1.0)
		var crack := (w - prev) * exp(-t * 70.0)
		prev = w
		var body := sin(TAU * 700.0 * t) * 0.6 * exp(-t * 30.0) + sin(TAU * lerpf(200.0, 60.0, minf(1.0, t / 0.08)) * t) * 0.7 * exp(-t * 18.0)
		out[i] = clampf((crack * 0.9 + body) * 0.85, -1.0, 1.0)
	return _to_stream(out)


func _block() -> AudioStreamWAV:
	var dur := 0.3
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.2)
		out[i] = (sin(TAU * lerpf(110.0, 45.0, t / dur) * t) * 0.8 + lp * 0.5 * exp(-t * 40.0) + sin(TAU * 600.0 * t) * 0.3 * exp(-t * 50.0)) * exp(-t * 12.0)
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
