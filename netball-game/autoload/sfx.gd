extends Node
## Sound effects: recordings in res://assets/audio/ (credited in docs/SOUNDS.md and the Licences screen; made by
## tools/audio/make_sounds.py), with a few synthesised at startup. A file in res://assets/audio/ with a sound's name
## replaces its synthesised version (assets/audio/whistle.ogg ...); without the file, the synthesised one plays.
## They are made a sound at a time by the loading screen (build_step), so it can show its progress; anything that
## needs one before then makes the rest at once (_ensure).

const RATE := 22050
const VOICES := {}
const MUSIC_DB := -9.0
## Sounds recorded more than once: play("catch") picks one of catch_1..catch_3 at random.
const VARIANTS := {"catch": 3, "bounce_floor": 2, "bounce_court": 2, "step_floor": 4, "step_court": 4, "squeak": 3,
	"whistle_short": 3, "whistle_long": 3}
## Recorded only (nothing synthesised stands in for them).
const FILES := ["whistle_double", "whistle_final", "whistle_gym", "crowd_cheer", "crowd_cheer_small", "crowd_ooh", "crowd_groan", "applause", "applause_hall",
	"applause_small", "clap", "menu_music", "amb_arena", "amb_hall", "amb_outdoor"]
const LOOPS := ["crowd_loop", "drums_loop", "menu_music", "amb_arena", "amb_hall", "amb_outdoor"]
## The umpire's whistle (recorded: docs/SOUNDS.md), by kind: a short pip (an infringement, a restart), a long blast
## (the centre pass after a goal, the end of a quarter), a double pip (a stoppage: an injury, a time-out), the final
## whistle (short, short, long). In a hall the long blast is the take recorded in a gym, with its echo.
const WHISTLES := {"short": "whistle_short", "long": "whistle_long", "double": "whistle_double", "final": "whistle_final"}
## The recordings are about 4.5 dB quieter than the synthesised whistle they replace (the loudest 100 ms): this lifts
## them back to where it was; from the umpire (3D, some 15-25 m from the camera) a little more again.
const WHISTLE_DB := 4.5
const WHISTLE_3D_DB := 3.0
## Medium and High (Game.hd()): the venues' beds as long stereo loops and more takes of each reaction, from
## assets/audio/hd/ (tools/audio/make_sounds_hd.py); Low plays the set above, as before. Takes beyond the first.
const HD_TAKES := {"crowd_cheer": 4, "crowd_cheer_small": 3, "applause": 3, "applause_hall": 2, "crowd_ooh": 2,
	"crowd_groan": 2}
const HD_DIR := "res://assets/audio/hd/"
## Sounds on court come from where they happen, through this many speakers at most (the oldest gives way).
const VOICES_3D := 8

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
var _venue := "arena"
var _pool3d: Array[AudioStreamPlayer3D] = []
var _next3d := 0
var _hd_loaded := false
var _rng := RandomNumberGenerator.new()   # the whistle's and the extra takes' picks
var asked := {}                      # sound -> times asked for (sound on or off): the tests see what a match plays


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
	asked[sound] = int(asked.get(sound, 0)) + 1
	_play(_pick(sound), volume_db, pitch)


func _play(sound: String, volume_db: float, pitch: float) -> void:
	if not enabled() or not streams.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.stream_paused = false
	p.play()


## A sound from a place on court, heard from the camera (attach_3d gives a match its speakers); without them it
## plays as play() does.
func play_at(sound: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if _pool3d.is_empty() or not is_instance_valid(_pool3d[0]):
		_pool3d.clear()
		play(sound, volume_db, pitch)
		return
	_ensure()
	asked[sound] = int(asked.get(sound, 0)) + 1
	_play_at(_pick(sound), at, volume_db, pitch)


func _play_at(sound: String, at: Vector3, volume_db: float, pitch: float) -> void:
	if not enabled() or not streams.has(sound):
		return
	if _pool3d.is_empty() or not is_instance_valid(_pool3d[0]):
		_play(sound, volume_db, pitch)
		return
	var p := _pool3d[_next3d]
	_next3d = (_next3d + 1) % _pool3d.size()
	p.stream = streams[sound]
	p.global_position = at
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.stream_paused = false
	p.play()


## Gives a match (its 3D world) the speakers play_at uses; they go with it.
func attach_3d(parent: Node3D) -> void:
	_pool3d.clear()
	_next3d = 0
	for i in VOICES_3D:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 14.0
		p.max_distance = 90.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		parent.add_child(p)
		_pool3d.append(p)


func _pick(sound: String) -> String:
	var n := int(VARIANTS.get(sound, 0))
	return "%s_%d" % [sound, 1 + randi() % n] if n > 0 else sound


## The venue: which crowd and surroundings the bed plays ("arena", "hall", "outdoor"), and the crowd's size.
func venue(kind: String) -> void:
	_ensure()
	_venue = kind
	var s := bed(kind)
	if _crowd.stream != s:
		var was := _crowd.playing
		_crowd.stop()
		_crowd.stream = s
		if was:
			_crowd.play()


## Holds every sound where it is (the pause menu), or lets them carry on.
func pause(on: bool) -> void:
	var all: Array[Node] = []
	all.append_array(_pool)
	all.append_array(_pool3d.filter(func(p): return is_instance_valid(p)))
	all.append_array([_crowd, _drums])
	for p in all:
		# Paused: those sounding hold; resumed: all carry on (a held player still reads as not playing).
		if not on:
			p.set("stream_paused", false)
		elif p.get("playing"):
			p.set("stream_paused", true)


## A player's effort: voice("grunt") or "hup"; pitch gives each player his own voice.
func voice(kind: String, volume_db := -10.0, pitch := 1.0) -> void:
	var n := int(VOICES.get(kind, 0))
	if n > 0:
		play("%s_%d" % [kind, 1 + randi() % n], volume_db, pitch * randf_range(0.95, 1.05))


## The crowd reacting: "cheer", "ooh", "groan" or "applause", the venue's own where it has one: the arena's big
## crowd, a hall's smaller one (applause echoing), a park court's few, quieter still.
func react(kind: String, volume_db := -6.0) -> void:
	var base := kind if kind == "applause" else "crowd_" + kind
	var key := base
	if _venue == "hall":
		key = base + ("_hall" if streams.has(base + "_hall") else "_small")
	elif _venue == "outdoor":
		key = base + "_small"
		volume_db -= 3.0
	if not streams.has(key):
		key = base
	# Medium and High: one of the takes, Low's own among them.
	if Game.hd() and HD_TAKES.has(key):
		_ensure()
		_load_hd()
		asked[key] = int(asked.get(key, 0)) + 1
		var n := _rng.randi() % (int(HD_TAKES[key]) + 1)
		var take := "hd/%s_%d" % [key, n + 1]
		_play(take if n > 0 and streams.has(take) else key, volume_db, randf_range(0.96, 1.04))
		return
	play(key, volume_db, randf_range(0.96, 1.04))


## The umpire's whistle of a kind (WHISTLES) from where she stands (at), a take at random; in a hall the long blast
## is the gym's. Counted as "whistle" in asked.
func whistle(kind: String, at: Vector3, volume_db := -6.0) -> void:
	_ensure()
	asked["whistle"] = int(asked.get("whistle", 0)) + 1
	# (Takes picked by a generator of its own: the match's draws from the global one are left as they were.)
	var key: String = WHISTLES.get(kind, "whistle_short")
	if kind == "long" and _venue == "hall" and streams.has("whistle_gym"):
		key = "whistle_gym"
	elif VARIANTS.has(key):
		key = "%s_%d" % [key, 1 + _rng.randi() % int(VARIANTS[key])]
	var in_3d := not _pool3d.is_empty() and is_instance_valid(_pool3d[0])
	_play_at(key, at, volume_db + WHISTLE_DB + (WHISTLE_3D_DB if in_3d else 0.0), _rng.randf_range(0.98, 1.02))


## The venue's bed: on Medium and High its long loop (assets/audio/hd/), else the Low one.
func bed(kind: String) -> AudioStream:
	if Game.hd():
		_load_hd()
		if streams.has("hd/amb_%s_long" % kind):
			return streams["hd/amb_%s_long" % kind]
	return streams.get("amb_" + kind, streams.get("crowd_loop"))


## The Medium and High sounds, loaded the first time a match on those levels wants them (Low never loads them).
func _load_hd() -> void:
	if _hd_loaded:
		return
	_hd_loaded = true
	for v in ["arena", "hall", "outdoor"]:
		var path := HD_DIR + "amb_%s_long.ogg" % v
		if ResourceLoader.exists(path):
			var s: AudioStreamOggVorbis = load(path)
			s.loop = true
			streams["hd/amb_%s_long" % v] = s
	for k in HD_TAKES:
		for i in int(HD_TAKES[k]):
			var path := HD_DIR + "%s_%d.ogg" % [k, i + 2]
			if ResourceLoader.exists(path):
				streams["hd/%s_%d" % [k, i + 2]] = load(path)


func click() -> void:
	play("click", -8.0)


## The venue's bed (its crowd and surroundings, venue()): intensity 0..1; negative stops it.
func crowd(intensity: float) -> void:
	_ensure()
	if intensity < 0.0 or not enabled():
		_crowd.stop()
		return
	_crowd_target = lerpf(-18.0, 0.0, clampf(intensity, 0.0, 1.0))
	if not _crowd.playing and not _crowd.stream_paused:
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
		p.stream_paused = false
	for p in _pool3d:
		if is_instance_valid(p):
			p.stop()
	_crowd.stream_paused = false
	_drums.stream_paused = false


# ---------------------------------------------------------------- synthesis

func _plan() -> void:
	_planned = true
	_todo = [
		["pass", _slap],                                     # the ball pushed away on a pass (catch_* is the catch)
		["bounce", func(): return _tock(0.45, 0.1, 0.7)],   # a bounce pass on the floor
		["rim", _rim],                                       # the ball off the steel ring
		["swish", _net],                                     # through the net
		["click", func(): return _tone_env(0.035, func(t): return sin(TAU * 1500.0 * t) * 0.5, 0.001, 0.03)],
		["buzzer", func(): return _tone_env(0.8, func(t): return signf(sin(TAU * 196.0 * t)) * 0.3 + sin(TAU * 392.0 * t) * 0.15, 0.01, 0.1)],
		["roar", _roar],
		["crowd_loop", _crowd_loop],
	]
	for k in FILES:
		_todo.append([k, null])
	for k in VARIANTS:
		for i in int(VARIANTS[k]):
			_todo.append(["%s_%d" % [k, i + 1], null])
	_total = _todo.size()


func _finish() -> void:
	_built = true
	for k in LOOPS:
		if streams.get(k) is AudioStreamOggVorbis:
			(streams[k] as AudioStreamOggVorbis).loop = true
	_crowd.stream = bed(_venue)
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
