class_name WsgAudio
extends Node
## A game's sound, mixed as a broadcast is: the crowd a bed of layers that follows the play, the knocks of the game
## where they happen, the important sounds clear over the rest, and the phone's buzz in the hand. The sounds are the
## game's own (the owner's recordings); this mixes them.
##   var au := WsgAudio.new(); add_child(au)
##   au.crowd_layers({"murmur": {"stream": loop, "db": [-26.0, -12.0], "by": "base"},
##                    "applause": {"stream": loop2, "db": [-40.0, -10.0], "by": "excite"},
##                    "tension": {"stream": loop3, "db": [-45.0, -12.0], "by": "tension"}})
##   au.base = 0.6                                # the ground's size (a full stadium 1, a parish field 0.3)
##   au.react([cheer, cheer_2, cheer_3], -4.0)    # a one-off on the crowd, never the same twice running
##   au.play_at(strike, ball_pos, -2.0, 1.0, "strike", 2)   # where it happened: kind's own limit, priority
##   au.duck(8.0, 0.8)                            # the crowd under a whistle or a replay's voice
##   au.haptic([[22, 0.55]])                      # ms and strength, gaps between; au.haptics_on is the setting
## The crowd's excitement and tension are the game's (WsgCrowd3D.set_excite / set_tension, which the 3D fans use
## too): one call moves the stand and its sound together. Buses (made if missing): WsgCrowd, WsgSfx, WsgVoice.

const BUSES := ["WsgCrowd", "WsgSfx", "WsgVoice"]

var base := 0.6
var haptics_on := true
## Per-kind limits at once (e.g. {"step": 4, "voice": 3}); the total is the tier's (WsgFoundation.voices()).
var kind_limits := {}
var _layers := {}            # name -> [player, [min_db, max_db], by]
var _excite := 0.0
var _tension := 0.0
var _pool: Array[AudioStreamPlayer3D] = []
var _meta := {}              # player -> [kind, priority, started msec]
var _ducks: Array = []       # [amount_db, until (the clock, s), release s]
var _clock := 0.0            # s of the game's time (ducks follow it, not the wall's)
var _last_react := {}
var _last_haptic := 0


func _ready() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for i in WsgFoundation.voices():
		var p := AudioStreamPlayer3D.new()
		p.bus = "WsgSfx"
		p.unit_size = 10.0
		p.max_distance = 140.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool.append(p)


## The crowd's bed: {name: {"stream": a looping stream, "db": [quiet, loud], "by": "base" | "excite" | "tension",
## optionally "pitch" and "from" (s into the stream: two layers of one recording, out of step) and "shape": "smooth"
## (the default: quiet until it matters) or "linear" (answering the smallest rise, as a swell should)}}.
func crowd_layers(spec: Dictionary) -> void:
	for n in _layers:
		(_layers[n][0] as AudioStreamPlayer).queue_free()
	_layers.clear()
	for n in spec:
		var p := AudioStreamPlayer.new()
		p.stream = spec[n].stream
		p.bus = "WsgCrowd"
		p.volume_db = -60.0
		p.pitch_scale = float(spec[n].get("pitch", 1.0))
		add_child(p)
		p.play(float(spec[n].get("from", 0.0)))
		_layers[n] = [p, spec[n].get("db", [-40.0, -10.0]), String(spec[n].get("by", "excite")), String(spec[n].get("shape", "smooth"))]


func _process(delta: float) -> void:
	# The crowd follows the game's excitement: up in half a second, down over a few (as the fans do).
	var want := WsgCrowd3D.target_excitement()
	_excite = lerpf(_excite, want, 1.0 - exp(-delta * (5.0 if want > _excite else 0.8)))
	_tension = lerpf(_tension, WsgCrowd3D.tension(), 1.0 - exp(-delta * 2.0))
	for n in _layers:
		var l: Array = _layers[n]
		var x: float = {"base": base, "excite": _excite, "tension": _tension}.get(l[2], _excite)
		var db := lerpf(l[1][0], l[1][1], smoothstep(0.0, 1.0, x) if l[3] == "smooth" else clampf(x, 0.0, 1.0))
		var p: AudioStreamPlayer = l[0]
		p.volume_db = move_toward(p.volume_db, db, 24.0 * delta)
	# Ducks: the deepest one now, eased back when it ends.
	_clock += delta
	var depth := 0.0
	var keep := []
	for d in _ducks:
		var left := float(d[1]) - _clock
		var k := 1.0 if left > 0.0 else clampf(1.0 + left / float(d[2]), 0.0, 1.0)
		depth = maxf(depth, float(d[0]) * k)
		if k > 0.0:
			keep.append(d)
	_ducks = keep
	var ci := AudioServer.get_bus_index("WsgCrowd")
	if ci >= 0:
		AudioServer.set_bus_volume_db(ci, -depth)


## A one-off from the crowd (a cheer, an "ooh"): one of the takes given, not the one played last.
func react(takes: Array, volume_db := -6.0, pitch_spread := 0.04) -> void:
	if takes.is_empty():
		return
	var key := str(takes[0])
	var i := randi() % takes.size()
	if takes.size() > 1 and i == int(_last_react.get(key, -1)):
		i = (i + 1) % takes.size()
	_last_react[key] = i
	var p := AudioStreamPlayer.new()
	p.stream = takes[i]
	p.bus = "WsgCrowd"
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_spread, 1.0 + pitch_spread)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## A sound where it happened (heard from the camera). kind: its own limit (kind_limits); priority: who gives way
## when every voice is busy - the lowest, then the farthest, then the oldest; a sound that would lose to all of them
## is not played. Returns whether it plays.
func play_at(stream: AudioStream, pos: Vector3, volume_db := 0.0, pitch := 1.0, kind := "sfx", priority := 1) -> bool:
	if stream == null:
		return false
	var cam := get_viewport().get_camera_3d()
	var ear := cam.global_position if cam else Vector3.ZERO
	var same := 0
	var free_p: AudioStreamPlayer3D = null
	var worst: AudioStreamPlayer3D = null
	var worst_key := []
	for p in _pool:
		if not p.playing:
			free_p = p if free_p == null else free_p
			continue
		var m: Array = _meta.get(p, ["", 0, 0])
		if m[0] == kind:
			same += 1
		var key := [int(m[1]), -p.global_position.distance_to(ear), -int(m[2])]
		if worst == null or key < worst_key:
			worst = p
			worst_key = key
	if kind_limits.has(kind) and same >= int(kind_limits[kind]):
		return false
	var p := free_p
	if p == null:
		if worst == null or [priority, -pos.distance_to(ear), 0] < worst_key:
			return false
		p = worst
	p.stop()
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	_meta[p] = [kind, priority, Time.get_ticks_msec()]
	return true


## The crowd dropped by amount_db for secs, then eased back over release s (under a whistle, a replay's voice);
## several at once: the deepest wins.
func duck(amount_db: float, secs: float, release := 0.4) -> void:
	_ducks.append([amount_db, _clock + secs, release])


## The phone's buzz: [[ms, strength 0-1], gap ms, [ms, strength], ...]. Off when haptics_on is (the player's
## setting); never two within 60 ms (a burst of them reads as one long rattle).
func haptic(pattern: Array) -> void:
	if not haptics_on or not OS.has_feature("mobile") or Time.get_ticks_msec() - _last_haptic < 60:
		return
	_last_haptic = Time.get_ticks_msec()
	for step in pattern:
		if step is Array:
			Input.vibrate_handheld(int(step[0]), float(step[1]))
			await get_tree().create_timer(float(step[0]) / 1000.0).timeout
		else:
			await get_tree().create_timer(float(step) / 1000.0).timeout


## Everything held (the game paused) or carried on.
func pause(on: bool) -> void:
	for n in _layers:
		(_layers[n][0] as AudioStreamPlayer).stream_paused = on
	for p in _pool:
		p.stream_paused = on


## Voices busy now (for a test or a debug overlay).
func busy() -> int:
	var n := 0
	for p in _pool:
		n += 1 if p.playing else 0
	return n
