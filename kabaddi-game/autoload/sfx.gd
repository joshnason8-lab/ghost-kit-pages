extends Node
## The game's sounds: recordings in res://assets/audio/ (credited in docs/SOUNDS.md and the Licences screen), and the
## few with no recording synthesised at startup. Drop an .ogg or .wav with the same name into res://assets/audio/ to
## replace a synthesised one (for example assets/audio/buzzer.ogg).
## They are made a sound at a time by the loading screen (build_step), so it can show its progress; anything that
## needs one before then makes the rest at once (_ensure).

const RATE := 22050
const VOICES := {"grunt": 5, "oof": 3, "exhale": 2, "hup": 2}
# Recorded one-shots with variants (name_1, name_2...): play("thud") picks one.
const VARIED := {"whistle_short": 3, "whistle_long": 3, "thud": 3, "slap": 3, "step_mat": 3, "step_earth": 4, "step_sand": 4}
# Each ground's own sound under the crowd (assets/audio/amb_<ground>.ogg); the dome is indoors and has none.
const AMBIENCE := ["stadium", "village", "monsoon", "beach"]
const AMB_DB := -12.0
# The volume sliders' buses (Settings): the players' and officials' sounds, the crowd and the grounds, the music.
const BUSES := {"fx": "Effects", "crowd": "Crowd", "music": "Music"}
# Sounds that are the crowd's, on its bus.
const CROWD_SOUNDS := ["crowd_", "applause", "roar", "chant", "clap"]
const MUSIC_DB := -8.0             # the menus' music, faded in
const MUSIC_LOOP := 13.915         # s: where menu_music.ogg comes round to (tools/audio/make_menu_music.py)

var streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd: AudioStreamPlayer
var _drums: AudioStreamPlayer
var _crowd_target := -60.0
var _music: AudioStreamPlayer
var _music_target := -80.0
var _amb: AudioStreamPlayer
var _ui: AudioStreamPlayer               # the click, which still sounds in the pause menu
var _pool3d: Array[AudioStreamPlayer3D] = []
var _next3d := 0
var paused := false                      # a match is paused: nothing plays (pause)
var _todo := []          # the sounds still to make: [name, how to synthesise it or null] (build_step)
var _planned := false
var _built := false
var _total := 1


func _ready() -> void:
	for k in BUSES:
		if AudioServer.get_bus_index(BUSES[k]) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, BUSES[k])
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	# Footsteps and bodies hitting the mat, where they happen: louder near the camera, panned to their side.
	for i in 8:
		var p := AudioStreamPlayer3D.new()
		p.bus = BUSES.fx
		p.unit_size = 9.0
		p.max_db = 0.0
		p.attenuation_filter_cutoff_hz = 9000.0
		p.panning_strength = 0.6
		add_child(p)
		_pool3d.append(p)
	_crowd = _player(BUSES.crowd, -60.0)
	_drums = _player(BUSES.crowd, -14.0)
	_amb = _player(BUSES.crowd, AMB_DB)
	_music = _player(BUSES.music, -80.0)
	_ui = _player(BUSES.fx, -8.0)
	apply_volumes()


func _player(bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = db
	add_child(p)
	return p


## The volume sliders (Settings: vol_fx, vol_crowd, vol_music, 0..100) on their buses.
func apply_volumes() -> void:
	for k in BUSES:
		var v := clampf(float(Game.settings.get("vol_" + k, 100)) / 100.0, 0.0, 1.0)
		var i := AudioServer.get_bus_index(BUSES[k])
		AudioServer.set_bus_mute(i, v <= 0.0)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


## Make the next sound; false once they are all made. progress() says how far along.
func build_step() -> bool:
	if _built:
		return false
	if not _planned:
		_plan()
	if not _todo.is_empty():
		var item: Array = _todo.pop_front()
		var k: String = item[0]
		# A recorded file wins, and then nothing is synthesised for it (the crowd's loop was made, at length, only to
		# be thrown away for its file).
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


## 0..1: how many of the sounds are made.
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
	sound = _variant(sound)
	if not enabled() or paused or not streams.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = BUSES.crowd if CROWD_SOUNDS.any(func(c): return sound.begins_with(c)) else BUSES.fx
	p.play()


## The same, from a point on the ground (a tackle, a body hitting the mat).
func play_at(sound: String, at: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	_ensure()
	sound = _variant(sound)
	if not enabled() or paused or not streams.has(sound):
		return
	var p := _pool3d[_next3d]
	_next3d = (_next3d + 1) % _pool3d.size()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.global_position = at
	p.play()


## A footstep on the ground's surface ("mat", "earth" or "sand"), at the foot; harder the faster he goes.
func step(surface: String, at: Vector3, speed: float) -> void:
	play_at("step_" + surface, at, lerpf(-22.0, -9.0, clampf(speed / 6.0, 0.0, 1.0)), randf_range(0.9, 1.1))


func _variant(sound: String) -> String:
	var n := int(VARIED.get(sound, 0))
	return "%s_%d" % [sound, 1 + randi() % n] if n > 0 else sound


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
	_ensure()
	if enabled() and streams.has("click"):
		_ui.stream = streams.click
		_ui.play()


## The referee's whistle, from where he stands: "short" (a foul, a restart), "long" (a raid, a point, the end of a
## half), "double" (a time-out) or "final" (full time). Indoors (the dome) a long blast is the take in a hall.
func whistle(kind: String, at: Vector3, indoor := false, volume_db := -2.0) -> void:
	var k := "whistle_gym" if kind == "long" and indoor else "whistle_" + kind
	play_at(k, at, volume_db, randf_range(0.98, 1.02))


## The ground's own sound under the crowd (AMBIENCE: the rain, the sea, birds, crickets); "" or the dome for none.
func ambience(ground: String) -> void:
	_ensure()
	var s: AudioStream = streams.get("amb_" + ground) if ground in AMBIENCE else null
	if s == null or not enabled():
		_amb.stop()
		return
	if _amb.stream != s or not _amb.playing:
		_amb.stream = s
		_amb.play()


## A match paused: everything it was playing holds where it is, and nothing new starts, until it goes on.
func pause(p: bool) -> void:
	paused = p
	for pl in [_crowd, _drums, _amb]:
		(pl as AudioStreamPlayer).stream_paused = p
	for pl in _pool:
		pl.stream_paused = p
	for pl in _pool3d:
		pl.stream_paused = p


## Crowd bed: intensity 0..1. Pass a negative value to stop.
func crowd(intensity: float) -> void:
	_ensure()
	if intensity < 0.0 or not enabled():
		_crowd.stop()
		return
	_crowd_target = lerpf(-24.0, -5.0, clampf(intensity, 0.0, 1.0))
	if not _crowd.playing:
		_crowd.volume_db = -40.0
		_crowd.play()


## The menus' music ("Indian" by LNPLUSMUSIC, Pixabay): on in the menus, carrying on from one screen to the next
## (the opening once, then the middle minute round and round); faded out for a match, or with sound or music off.
func music(on: bool) -> void:
	_ensure()
	if on and enabled() and bool(Game.settings.get("music", true)) and _music.stream != null:
		_music_target = MUSIC_DB
		if not _music.playing:
			_music.volume_db = -30.0
			_music.play()
	else:
		_music_target = -80.0


func drums(on: bool) -> void:
	_ensure()
	if on and enabled():
		if not _drums.playing:
			_drums.play()
	else:
		_drums.stop()


func stop_all() -> void:
	pause(false)
	_crowd.stop()
	_drums.stop()
	_amb.stop()
	for p in _pool:
		p.stop()
	for p in _pool3d:
		p.stop()


# ---------------------------------------------------------------- synthesis

# Every recording the game plays besides VARIED and VOICES (tests/test_runner checks each one is there and loads).
const RECORDED := ["chant_raider", "crowd_chant", "chant_word_1", "chant_word_2", "yell_aaja", "yell_pakad",
		"yell_shabash", "yell_chal", "yell_haan", "yell_nahi", "yell_touch", "crowd_cheer", "crowd_ooh", "crowd_groan",
		"applause", "clap", "menu_music", "whistle_double", "whistle_final", "whistle_gym", "amb_stadium", "amb_village", "amb_monsoon", "amb_beach"]


func _plan() -> void:
	_planned = true
	_todo = [
		["buzzer", func(): return _tone_env(0.9, func(t): return signf(sin(TAU * 196.0 * t)) * 0.35 + sin(TAU * 392.0 * t) * 0.15, 0.01, 0.1)],
		["whoosh", _whoosh],
		["click", func(): return _tone_env(0.035, func(t): return sin(TAU * 1500.0 * t) * 0.5, 0.001, 0.03)],
		["gavel", _gavel],
		["roar", _roar],
		["crowd_loop", _crowd_loop],
		["dhol_loop", _dhol_loop],
		["bid", func(): return _tone_env(0.08, func(t): return sin(TAU * 880.0 * t) * 0.4 + sin(TAU * 1320.0 * t) * 0.2, 0.002, 0.07)],
	]
	# Recordings with no synthesised stand-in: chants, players shouting, the crowd, the grounds, footsteps, bodies.
	for k in RECORDED:
		_todo.append([k, null])
	for k in VARIED:
		for i in int(VARIED[k]):
			_todo.append(["%s_%d" % [k, i + 1], null])
	# Players' efforts and breaths (see tools/audio/make_sounds.py).
	for kind in VOICES:
		for i in int(VOICES[kind]):
			_todo.append(["%s_%d" % [kind, i + 1], null])
	_total = _todo.size()


func _finish() -> void:
	_built = true
	for k in ["crowd_loop", "dhol_loop", "menu_music"] + AMBIENCE.map(func(g): return "amb_" + g):
		if streams.get(k) is AudioStreamOggVorbis:
			(streams[k] as AudioStreamOggVorbis).loop = true
	if streams.get("menu_music") is AudioStreamOggVorbis:
		(streams.menu_music as AudioStreamOggVorbis).loop_offset = MUSIC_LOOP
	_crowd.stream = streams.get("crowd_loop")
	_drums.stream = streams.get("dhol_loop")
	_music.stream = streams.get("menu_music")


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
