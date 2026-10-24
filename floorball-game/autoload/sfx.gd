extends Node
## Sound effects, most synthesised at startup so the game ships few audio files. Drop an .ogg or .wav with the same
## name into res://assets/audio/ to replace any of them (assets/audio/whistle.ogg, assets/audio/shot.ogg ...).
## They are made a sound at a time by the loading screen (build_step), so it can show its progress; anything that
## needs one before then makes the rest at once (_ensure).
##
## A floorball hall's sounds: the plastic ball's sharp "tick" off a composite blade, the hollow knock of the boards,
## the clack of stick on stick, the referees' whistles, the period horn and the drum are made here; the crowd (its
## murmur, cheers, applause), the footsteps on the hall floor and the menus' click are recordings (docs/SOUNDS.md).

const RATE := 22050
const VOICES := {"grunt": 2, "hup": 2, "step": 5}
const MUSIC_DB := -10.0

var streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _steps: Array[AudioStreamPlayer3D] = []   # footsteps, heard from where they are, in a pool of their own
var _next_step := 0
var _crowd: AudioStreamPlayer
var _drums: AudioStreamPlayer
var _chant: AudioStreamPlayer          # the crowd's rhythmic cheering, over the bed as an attack nears the goal
var _chant_target := -60.0
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
	for i in 4:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 4.0
		p.max_distance = 24.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_steps.append(p)
	_crowd = AudioStreamPlayer.new()
	_crowd.volume_db = -60.0
	add_child(_crowd)
	_drums = AudioStreamPlayer.new()
	_drums.volume_db = -60.0
	add_child(_drums)
	_chant = AudioStreamPlayer.new()
	_chant.volume_db = -60.0
	add_child(_chant)
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
	if _chant.playing:
		_chant.volume_db = move_toward(_chant.volume_db, _chant_target, 12.0 * delta)
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
	# A recording with takes (crowd_cheer, crowd_cheer_2, crowd_cheer_3): one of them, so a cheer is not always the same.
	if streams.has(sound + "_2"):
		var takes := [sound]
		for i in range(2, 6):
			if streams.has("%s_%d" % [sound, i]):
				takes.append("%s_%d" % [sound, i])
		sound = takes[randi() % takes.size()]
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.stream_paused = false   # a sound asked for in a pause (the pause menu's buttons) plays
	p.play()


func voice(kind: String, volume_db := -12.0, pitch := 1.0) -> void:
	var n := int(VOICES.get(kind, 0))
	if n > 0:
		play("%s_%d" % [kind, 1 + randi() % n], volume_db, pitch * randf_range(0.95, 1.05))


## A footstep on the hall floor at a place on the rink (heard from the camera, softer far away); louder when he runs.
func step(at: Vector3, speed: float) -> void:
	if not enabled() or not _built:
		return
	var p := _steps[_next_step]
	_next_step = (_next_step + 1) % _steps.size()
	p.stream = streams.get("step_%d" % (1 + randi() % int(VOICES.step)))
	p.global_position = at
	p.volume_db = lerpf(-14.0, -4.0, clampf(speed / 7.0, 0.0, 1.0))
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()


## The crowd reacting: "cheer", "ooh", "groan" or "applause".
func react(kind: String, volume_db := -6.0) -> void:
	play("crowd_" + kind if kind != "applause" else kind, volume_db, randf_range(0.96, 1.04))


func click() -> void:
	play("click", -8.0)


## Crowd bed: intensity 0..1; negative stops it. Near the top (an attack at the goal) the crowd's rhythmic cheering
## rises over it.
func crowd(intensity: float) -> void:
	_ensure()
	if intensity < 0.0 or not enabled():
		_crowd.stop()
		_chant.stop()
		return
	_crowd_target = lerpf(-28.0, -8.0, clampf(intensity, 0.0, 1.0))
	_chant_target = lerpf(-60.0, -13.0, smoothstep(0.55, 0.75, intensity))
	if not _crowd.playing:
		_crowd.volume_db = -40.0
		_crowd.play()
	if _chant.stream != null and not _chant.playing:
		_chant.volume_db = -60.0
		_chant.play()


## The supporters' drum, louder as an attack builds (0..1); negative stops it.
func drums(level: float) -> void:
	_ensure()
	if level < 0.0 or not enabled():
		_drums.stop()
		return
	_drums_target = lerpf(-26.0, -11.0, clampf(level, 0.0, 1.0))
	if not _drums.playing:
		_drums.volume_db = -40.0
		_drums.play()


func music(on: bool) -> void:
	_ensure()
	if on and enabled() and bool(Game.settings.get("music", true)) and _music.stream != null:
		_music_target = MUSIC_DB
		if not _music.playing:
			_music.volume_db = -30.0
			_music.play()
	else:
		_music_target = -80.0


## The match paused: every sound holds where it is (the crowd too) and goes on from there.
func set_paused(on: bool) -> void:
	for p in [_crowd, _chant, _drums]:
		(p as AudioStreamPlayer).stream_paused = on
	for p in _pool:
		p.stream_paused = on
	for p in _steps:
		p.stream_paused = on


func stop_all() -> void:
	_crowd.stop()
	_chant.stop()
	_drums.stop()
	for p in _pool:
		p.stop()
	for p in _steps:
		p.stop()


# ---------------------------------------------------------------- synthesis

func _plan() -> void:
	_planned = true
	_todo = _plan_list()
	_total = _todo.size()


## Every sound: [name, how to make it in code, or null for a recording only (assets/audio)]. A recording in
## assets/audio/ of the same name is used first (docs/SOUNDS.md).
func _plan_list() -> Array:
	var todo := [
		["whistle", _whistle],
		["whistle_long", func(): return _whistle(1.0)],
		["whistle_double", _whistle_double],
		["shot", func(): return _tick(1.0, 0.05, 0.9)],        # a slap or wrist shot: the hollow ball cracks off the blade
		["pass", func(): return _tick(0.8, 0.035, 0.45)],      # a pass: the same, softer
		["touch", func(): return _tick(0.65, 0.025, 0.2)],     # a dribble touch
		["board", _board],                                     # the ball against the boards
		["post", _post],                                       # off the goal frame
		["net", _net],
		["clack", func(): return _tick(0.45, 0.04, 0.6, 0.6)], # stick on stick
		["save", func(): return _thud(0.12)],                  # the ball into a goalkeeper's pads
		["click", func(): return _tone_env(0.035, func(t): return sin(TAU * 1500.0 * t) * 0.5, 0.001, 0.03)],
		["horn", _horn],
		["roar", _roar],
		["crowd_loop", _crowd_loop],
		["drums_loop", _drums_loop],
	]
	for k in ["crowd_cheer", "crowd_cheer_2", "crowd_cheer_3", "roar_2", "crowd_ooh", "crowd_groan", "applause",
			"applause_2", "clap", "chant_loop", "menu_music"]:
		todo.append([k, null])
	for kind in VOICES:
		for i in int(VOICES[kind]):
			todo.append(["%s_%d" % [kind, i + 1], null])
	return todo


func _finish() -> void:
	_built = true
	for k in ["crowd_loop", "drums_loop", "chant_loop", "menu_music"]:
		if streams.get(k) is AudioStreamOggVorbis:
			(streams[k] as AudioStreamOggVorbis).loop = true
	_crowd.stream = streams.get("crowd_loop")
	_chant.stream = streams.get("chant_loop")
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


## A pea-less referee's whistle (Fox-style): a bright tone near 3.1 kHz with a fast flutter.
func _whistle(dur := 0.45) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * (3150.0 + sin(TAU * 48.0 * t) * 120.0) / RATE
		var env := minf(1.0, t / 0.015) * clampf((dur - t) / 0.06, 0.0, 1.0)
		out[i] = (sin(phase) * 0.8 + sin(phase * 2.0) * 0.12) * (0.75 + 0.25 * sin(TAU * 48.0 * t)) * env * 0.42
	return _to_stream(out)


## Two short blasts: a goal, or the end of a delayed penalty's advantage.
func _whistle_double() -> AudioStreamWAV:
	var a: AudioStreamWAV = _whistle(0.18)
	var gap := PackedByteArray()
	gap.resize(int(0.09 * RATE) * 2)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = a.data + gap + a.data
	return s


## The floorball's crack: a hollow plastic sphere with 26 holes struck by a stiff blade. Very short and bright, with a
## hint of the hollow body. bright scales the pitch; ring how long it sounds; hard how much of it is the crack.
func _tick(bright: float, ring: float, hard: float, wood := 0.0) -> AudioStreamWAV:
	var dur := ring * 4.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := randf_range(-1.0, 1.0)
		var crack := (w - prev) * exp(-t * 260.0) * hard
		prev = w
		var body := sin(TAU * 1900.0 * bright * t) * 0.45 * exp(-t / ring * 3.0) + sin(TAU * 3700.0 * bright * t) * 0.2 * exp(-t / ring * 5.0)
		var knock := sin(TAU * 520.0 * t) * wood * exp(-t * 60.0)
		out[i] = clampf((crack + body + knock) * 0.85, -1.0, 1.0)
	return _to_stream(out)


## The ball into the boards: a hollow knock of the plastic panel and a little rattle.
func _board() -> AudioStreamWAV:
	var dur := 0.32
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.25)
		out[i] = (sin(TAU * lerpf(240.0, 150.0, t / dur) * t) * 0.7 * exp(-t * 22.0) + lp * 0.35 * exp(-t * 35.0)
			+ sin(TAU * 1800.0 * t) * 0.15 * exp(-t * 120.0)) * 0.9
	return _to_stream(out)


func _post() -> AudioStreamWAV:
	return _tone_env(0.6, func(t): return (sin(TAU * 1240.0 * t) * 0.5 + sin(TAU * 2960.0 * t) * 0.25) * exp(-t * 7.0), 0.001, 0.1)


func _net() -> AudioStreamWAV:
	var dur := 0.4
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.6)
		out[i] = lp * exp(-t * 10.0) * 0.5
	return _to_stream(out)


func _thud(dur: float) -> AudioStreamWAV:
	var n := int(dur * 2.0 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.15)
		out[i] = (sin(TAU * lerpf(160.0, 70.0, minf(1.0, t / 0.06)) * t) * 0.8 + lp * 0.4) * exp(-t / dur * 3.0)
	return _to_stream(out)


## The period horn: a loud, slightly rough two-tone buzz.
func _horn() -> AudioStreamWAV:
	return _tone_env(1.4, func(t): return signf(sin(TAU * 233.0 * t)) * 0.22 + sin(TAU * 466.0 * t) * 0.18 + sin(TAU * 349.0 * t) * 0.14, 0.02, 0.15)


func _roar() -> AudioStreamWAV:
	var dur := 2.6
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := float(i) / RATE
		a = lerpf(a, randf_range(-1.0, 1.0), 0.09)
		b = lerpf(b, randf_range(-1.0, 1.0), 0.02)
		out[i] = (a * 0.8 + b * 1.4) * minf(1.0, t / 0.2) * clampf((dur - t) / 1.4, 0.0, 1.0) * 0.7
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


## A supporters' bass drum: the steady boom-boom, boom of a hall's end, at 120 a minute.
func _drums_loop() -> AudioStreamWAV:
	var beat := 0.5
	var pattern := [0.0, 0.5, 1.5, 2.0, 2.5, 3.5]
	var dur := 4.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for at in pattern:
		var start := int(at * beat * 2.0 * RATE / 2.0)
		for i in int(0.35 * RATE):
			var j := start + i
			if j >= n:
				break
			var t := float(i) / RATE
			out[j] += sin(TAU * lerpf(95.0, 55.0, minf(1.0, t / 0.12)) * t) * exp(-t * 9.0) * 0.8
	return _to_stream(out, true)
