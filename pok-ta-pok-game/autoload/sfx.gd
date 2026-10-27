extends Node
## Sound effects: some synthesised at startup (the slap of the rubber ball on a hip, the judges' drum), the rest
## recorded (assets/audio/, docs/SOUNDS.md lists every file's source and licence; tools/sound/process.py makes them).
## A file with a sound's name in res://assets/audio/ replaces the synthesised one; numbered variants (hip_body_1..3,
## step_earth_1..4 ...) are picked at random (play_var). Each court has its own surroundings (ambience): crickets at
## dusk and by night, the torches' fire, birds in the Yucatán forest, a dog in the village.
## They are made a sound at a time by the loading screen (build_step), so it can show its progress; anything that
## needs one before then makes the rest at once (_ensure).

const RATE := 22050
const VOICES := {"grunt": 3, "hup": 2}
## Recorded sounds in numbered variants: name -> how many.
const VARIANTS := {"hip_body": 3, "thud_earth": 3, "step_earth": 4, "step_stone": 4, "bird": 6}
## The bed and the occasional sounds of each kind of court: [bed loop or "", its dB, second bed or "", its dB,
## occasional sound ("" none), every so many seconds (min, max), its dB].
const AMBIENCE := {
	"village": ["amb_crickets", -20.0, "", 0.0, "dog_bark", Vector2(25.0, 60.0), -24.0],
	"festival": ["", 0.0, "", 0.0, "dog_bark", Vector2(40.0, 90.0), -26.0],
	"stone": ["amb_crickets", -30.0, "", 0.0, "bird", Vector2(3.0, 9.0), -18.0],
	"night": ["amb_crickets", -18.0, "amb_fire", -20.0, "", Vector2.ZERO, 0.0],
}
## Medium and High: long stereo recordings of the same places (Low keeps the short beds above).
const AMBIENCE_HQ := {
	"village": ["amb_village_hq", -17.0, "", 0.0, "dog_bark", Vector2(30.0, 70.0), -24.0],
	"festival": ["", 0.0, "", 0.0, "dog_bark", Vector2(40.0, 90.0), -26.0],
	"stone": ["amb_forest_hq", -17.0, "", 0.0, "bird", Vector2(8.0, 18.0), -20.0],
	"night": ["amb_night_hq", -17.0, "amb_torch_hq", -19.0, "", Vector2.ZERO, 0.0],
}
const HQ_SOUNDS := ["amb_village_hq", "amb_forest_hq", "amb_night_hq", "amb_torch_hq", "crowd_loop_hq", "crowd_cheer_2", "crowd_cheer_3",
	"applause_2"]
const MUSIC_DB := -9.0

var streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _crowd: AudioStreamPlayer
var _crowd_target := -60.0
var _music: AudioStreamPlayer
var _music_target := -80.0
var _amb: Array[AudioStreamPlayer] = []
var _amb_kind := ""
var _amb_next := 0.0
var _paused := false
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
	for i in 2:
		var a := AudioStreamPlayer.new()
		add_child(a)
		_amb.append(a)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -80.0
	# Cane flute, frame drum, slit drum and seed rattles: the game's own piece (tools/music/compose.py).
	var st: AudioStream = load("res://assets/audio/menu_music.ogg") if ResourceLoader.exists("res://assets/audio/menu_music.ogg") else null
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	_music.stream = st
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
	if _amb_kind != "" and not _paused:
		var a: Array = _amb_table()[_amb_kind]
		if String(a[4]) != "":
			_amb_next -= delta
			if _amb_next <= 0.0:
				var span: Vector2 = a[5]
				_amb_next = randf_range(span.x, span.y)
				if String(a[4]) in VARIANTS:
					play_var(String(a[4]), float(a[6]) + randf_range(-4.0, 0.0), randf_range(0.95, 1.05))
				else:
					play(String(a[4]), float(a[6]) + randf_range(-4.0, 0.0), randf_range(0.93, 1.05))
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
	if not enabled() or _paused or not streams.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## One of a sound's recorded variants, at random: play_var("step_earth").
func play_var(kind: String, volume_db := 0.0, pitch := 1.0) -> void:
	var n := int(VARIANTS.get(kind, 0))
	if n > 0:
		play("%s_%d" % [kind, 1 + randi() % n], volume_db, pitch)


## The court's surroundings (AMBIENCE: "village", "festival", "stone", "night"); "" stops them.
func ambience(kind: String) -> void:
	_ensure()
	_amb_kind = kind if AMBIENCE.has(kind) and enabled() else ""
	for p in _amb:
		p.stop()
	if _amb_kind == "":
		return
	var a: Array = _amb_table()[_amb_kind]
	for i in 2:
		var k := String(a[i * 2])
		if k != "" and streams.has(k):
			_amb[i].stream = streams[k]
			_amb[i].volume_db = float(a[i * 2 + 1])
			_amb[i].play()
	_amb_next = randf_range(2.0, 6.0)


## Medium and High hear the long recordings, when they are in the build.
func hq() -> bool:
	return int(Game.settings.graphics) >= Game.GFX_MEDIUM and streams.has("amb_forest_hq")


func _amb_table() -> Dictionary:
	return AMBIENCE_HQ if hq() else AMBIENCE


## Everything held still (the match paused): the beds, the crowd, the sounds in flight; nothing new plays.
func pause(on: bool) -> void:
	_paused = on
	_crowd.stream_paused = on
	for p in _amb:
		p.stream_paused = on
	for p in _pool:
		p.stream_paused = on


func select() -> void:
	play("ui_select", -10.0)


## A player's effort: voice("grunt") or "hup"; pitch gives each player his own voice.
func voice(kind: String, volume_db := -10.0, pitch := 1.0) -> void:
	var n := int(VOICES.get(kind, 0))
	if n > 0:
		play("%s_%d" % [kind, 1 + randi() % n], volume_db, pitch * randf_range(0.95, 1.05))


## The crowd reacting: "cheer", "ooh", "groan" or "applause".
func react(kind: String, volume_db := -6.0) -> void:
	var k := "crowd_" + kind if kind != "applause" else kind
	if hq():
		# More than one cheer and applause on Medium and High, so a match's big moments do not all sound alike.
		if kind == "cheer":
			k = ["crowd_cheer", "crowd_cheer_2", "crowd_cheer_3"][randi() % 3]
		elif kind == "applause":
			k = ["applause", "applause_2"][randi() % 2]
	play(k, volume_db, randf_range(0.96, 1.04))


func click() -> void:
	play("click", -8.0)


## Crowd bed: intensity 0..1; negative stops it.
func crowd(intensity: float) -> void:
	_ensure()
	if intensity < 0.0 or not enabled():
		_crowd.stop()
		return
	_crowd_target = lerpf(-26.0, -6.0, clampf(intensity, 0.0, 1.0))
	var bed: AudioStream = streams.get("crowd_loop_hq" if hq() and streams.has("crowd_loop_hq") else "crowd_loop")
	if _crowd.stream != bed:
		_crowd.stop()
		_crowd.stream = bed
	if not _crowd.playing:
		_crowd.volume_db = -40.0
		_crowd.play()


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
	ambience("")
	for p in _pool:
		p.stop()


# ---------------------------------------------------------------- synthesis

func _plan() -> void:
	_planned = true
	_todo = [
		["hip", _hip],                                      # the heavy rubber ball meeting a leather-clad hip
		["thud", func(): return _thud(0.07)],               # down on packed earth
		["thud_stone", func(): return _thud_stone()],       # on plastered stone
		["throw", func(): return _swish(0.22)],             # the serve leaving the hand
		["call", func(): return _drum()],                   # the judges' call
		["conch", func(): return _conch()],                 # the conch shell before the copal offering (Ritual)
		["click", func(): return _tone_env(0.035, func(t): return sin(TAU * 1500.0 * t) * 0.5, 0.001, 0.03)],
		["roar", _roar],
		["crowd_loop", _crowd_loop],
	]
	for k in ["crowd_cheer", "crowd_ooh", "crowd_groan", "applause", "clap", "menu_music", "ui_select", "amb_crickets", "amb_fire",
			"dog_bark"] + HQ_SOUNDS:
		_todo.append([k, null])
	for kind in VARIANTS:
		for i in int(VARIANTS[kind]):
			_todo.append(["%s_%d" % [kind, i + 1], null])
	for kind in VOICES:
		for i in int(VOICES[kind]):
			_todo.append(["%s_%d" % [kind, i + 1], null])
	_total = _todo.size()


func _finish() -> void:
	_built = true
	for k in ["crowd_loop", "menu_music", "amb_crickets", "amb_fire", "amb_village_hq", "amb_forest_hq", "amb_night_hq", "amb_torch_hq",
			"crowd_loop_hq"]:
		if streams.get(k) is AudioStreamOggVorbis:
			(streams[k] as AudioStreamOggVorbis).loop = true
	_crowd.stream = streams.get("crowd_loop")
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


## The hip strike: a deep, dull smack (a 3.6 kg rubber ball on leather and flesh), with a short low boom under it.
func _hip() -> AudioStreamWAV:
	var dur := 0.32
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.35)
		var smack := lp * exp(-t * 90.0)
		var boom := sin(TAU * lerpf(150.0, 62.0, minf(1.0, t / 0.08)) * t) * exp(-t * 18.0)
		out[i] = clampf((smack * 0.9 + boom * 0.9) * 0.85, -1.0, 1.0)
	return _to_stream(out)


## The ball on stone: shorter and brighter than on earth.
func _thud_stone() -> AudioStreamWAV:
	var dur := 0.2
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.5)
		out[i] = (sin(TAU * lerpf(230.0, 110.0, t / dur) * t) * 0.6 + lp * 0.5 * exp(-t * 120.0)) * exp(-t * 26.0) * 0.8
	return _to_stream(out)


## Air past an arm: filtered noise rising and falling.
func _swish(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.12 + 0.3 * t / dur)
		out[i] = lp * sin(PI * t / dur) * 0.5
	return _to_stream(out)


## A conch shell blown: a breathy horn, rising into its note, held, falling away.
func _conch() -> AudioStreamWAV:
	var dur := 2.4
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 196.0 * (0.94 + 0.06 * minf(1.0, t / 0.35)) * (1.0 - 0.03 * maxf(0.0, t - 1.9))
		ph += TAU * f / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.08)
		var tone := sin(ph) + 0.45 * sin(2.0 * ph) + 0.25 * sin(3.0 * ph) + 0.1 * sin(4.0 * ph)
		var env := minf(1.0, t / 0.3) * clampf((dur - t) / 0.6, 0.0, 1.0) * (1.0 + 0.04 * sin(TAU * 4.5 * t))
		out[i] = (tone * 0.32 + lp * 0.25) * env * 0.6
	return _to_stream(out)


## A low hand drum, struck once.
func _drum() -> AudioStreamWAV:
	var dur := 0.6
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.3)
		out[i] = (sin(TAU * lerpf(110.0, 82.0, minf(1.0, t / 0.2)) * t) * exp(-t * 7.0) + lp * exp(-t * 60.0) * 0.4) * 0.8
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
