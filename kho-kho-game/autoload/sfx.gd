extends Node
## Sound effects: recordings in res://assets/audio/ (docs/SOUNDS.md says where each comes from), and the whoosh and the
## crowd's fallback synthesised at startup. The umpires' and the timekeeper's whistles are real ones (whistle()), heard
## from where they stand. Drop an .ogg or .wav with the same name into assets/audio/ to
## replace any of them. A sound with takes (slap_1, slap_2 ...) plays one of them at random when asked for by its name.
## In a match: the crowd's murmur, the place's own sound (crickets, birds), footsteps where the players run (in 3D, on
## the ground's surface), and in the hall a little of its echo on all of it; a pause holds every one of them.
## They are made a sound at a time by the loading screen (build_step), so it can show its progress; anything that
## needs one before then makes the rest at once (_ensure).

const RATE := 22050
const VOICES := {"grunt": 3, "hup": 2}
const MUSIC_DB := -9.0
## Sounds with several takes, and how many.
const TAKES := {"slap": 2, "thud": 2, "step_earth": 4, "step_mat": 3, "crowd_cheer": 2, "applause": 3,
	"whistle_short": 3, "whistle_long": 3}
## Every recording the game loads from assets/audio/ (the test checks each is there).
const FILES := ["crowd_ooh", "crowd_groan", "clap", "menu_music", "drums_loop", "crowd_loop",
	"click", "amb_crickets", "amb_birds", "whistle_double", "whistle_final", "whistle_gym"]
const LOOPS := ["crowd_loop", "drums_loop", "menu_music", "amb_crickets", "amb_birds"]
## A place's own sound under the crowd: kind of ground -> [bed, its level (dB)].
const AMBIENCE := {"village": ["amb_crickets", -11.0], "school": ["amb_birds", -9.0], "stadium": ["amb_crickets", -18.0]}   # quieter since 0.10 (the owner)
const BUS := "Venue"   # the match's sounds; in the hall it carries the hall's echo

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
var _steps: Array[AudioStreamPlayer3D] = []
var _next_step := 0
var surface := "mud"          # the ground under the players' feet: "mud" (earth) or "mat"
var in_match := false         # a match being played (not the menu's backdrop): the field's own sounds are on
var indoor := false           # the hall: its long whistle is the one recorded in a gym, with its echo
var _whistles: Array[AudioStreamPlayer3D] = []
var _next_whistle := 0
var paused := false           # the match paused: what was playing is held, and nothing new starts on the field
var _todo := []
var _planned := false
var _built := false
var _total := 1


func _ready() -> void:
	AudioServer.add_bus()
	var b := AudioServer.bus_count - 1
	AudioServer.set_bus_name(b, BUS)
	AudioServer.set_bus_send(b, "Master")
	var verb := AudioEffectReverb.new()
	verb.room_size = 0.55
	verb.damping = 0.6
	verb.wet = 0.12
	verb.dry = 1.0
	AudioServer.add_bus_effect(b, verb)
	AudioServer.set_bus_effect_enabled(b, 0, false)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		add_child(p)
		_pool.append(p)
	for i in 6:
		var s3 := AudioStreamPlayer3D.new()
		s3.bus = BUS
		s3.unit_size = 6.0
		s3.max_distance = 45.0
		s3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(s3)
		_steps.append(s3)
	for i in 3:
		var w3 := AudioStreamPlayer3D.new()
		w3.bus = BUS
		w3.unit_size = 20.0   # a whistle carries across the ground
		w3.max_distance = 150.0
		w3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(w3)
		_whistles.append(w3)
	_crowd = AudioStreamPlayer.new()
	_crowd.volume_db = -60.0
	_crowd.bus = BUS
	add_child(_crowd)
	_drums = AudioStreamPlayer.new()
	_drums.volume_db = -60.0
	_drums.bus = BUS
	add_child(_drums)
	_amb = AudioStreamPlayer.new()
	_amb.bus = BUS
	add_child(_amb)
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
	sound = _take(sound)
	if not enabled() or not streams.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## One of a sound's takes, at random, if it has them.
func _take(sound: String) -> String:
	return "%s_%d" % [sound, 1 + randi() % int(TAKES[sound])] if TAKES.has(sound) else sound


## A sound from a place on the field, heard from the camera (a footstep, a dive landing).
func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	_ensure()
	sound = _take(sound)
	if not in_match or paused or not enabled() or not streams.has(sound):
		return
	var p := _steps[_next_step]
	_next_step = (_next_step + 1) % _steps.size()
	p.stream = streams[sound]
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## An official's whistle from where he stands: "short" (a pip: an out, a foul, the second of the timekeeper's start),
## "long" (a turn's start and end; in the hall the gym's take), "double" or "final" (short, short, long: the match is
## over). Its own players, so footsteps never cut it short; not in the menu's backdrop match.
func whistle(kind: String, pos: Vector3, volume_db := 0.0) -> void:
	_ensure()
	var sound := _take("whistle_gym" if kind == "long" and indoor else "whistle_" + kind)
	if not in_match or paused or not enabled() or not streams.has(sound):
		return
	var p := _whistles[_next_whistle]
	_next_whistle = (_next_whistle + 1) % _whistles.size()
	p.stream = streams[sound]
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.98, 1.02)
	p.play()


## A footstep at pos, on the ground's surface, louder the faster he runs.
func step(pos: Vector3, speed: float) -> void:
	play_at("step_mat" if surface == "mat" else "step_earth", pos, lerpf(-16.0, -6.0, clampf(speed / 7.0, 0.0, 1.0)), randf_range(0.92, 1.08))


## The place's own sound under the crowd, and in the hall its echo: kind is the ground's (Arena.kind); "" stops it.
func venue(kind: String, p_surface := "mud") -> void:
	_ensure()
	surface = p_surface
	in_match = kind != ""
	indoor = kind == "arena"
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(BUS), 0, kind == "arena")
	if kind == "" or not AMBIENCE.has(kind) or not enabled():
		_amb.stop()
		return
	var a: Array = AMBIENCE[kind]
	_amb.stream = streams.get(a[0])
	_amb.volume_db = float(a[1])
	if _amb.stream != null:
		_amb.play()


## A pause holds everything playing (and lets it carry on from there); a menu's music is not the match's.
func pause(on: bool) -> void:
	paused = on
	for p in _pool + [_crowd, _drums, _amb]:
		(p as AudioStreamPlayer).stream_paused = on
	for p in _steps + _whistles:
		p.stream_paused = on


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
	pause(false)
	in_match = false
	_crowd.stop()
	_drums.stop()
	_amb.stop()
	AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(BUS), 0, false)
	for p in _pool:
		p.stop()
	for p in _steps + _whistles:
		p.stop()


# ---------------------------------------------------------------- synthesis

func _plan() -> void:
	_planned = true
	# Made here unless a recording of the same name is in assets/audio/.
	_todo = [
		["whoosh", _whoosh],
		["crowd_loop", _crowd_loop],
		["click", func(): return _tone_env(0.035, func(t): return sin(TAU * 1500.0 * t) * 0.5, 0.001, 0.03)],
	]
	for k in FILES:
		if not (k in ["crowd_loop", "click"]):
			_todo.append([k, null])
	for kind in VOICES:
		for i in int(VOICES[kind]):
			_todo.append(["%s_%d" % [kind, i + 1], null])
	for kind in TAKES:
		for i in int(TAKES[kind]):
			_todo.append(["%s_%d" % [kind, i + 1], null])
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
