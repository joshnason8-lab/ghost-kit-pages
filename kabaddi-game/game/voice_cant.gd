class_name VoiceCant
extends Node
## The cant, said out loud. Listens to the microphone and tells the match whether the raider
## is still chanting: "kabaddi, kabaddi, kabaddi..." is a run of voiced syllables, so the
## chant is alive while there has been voice in the last moment or so.
##
## It does not try to recognise the word: a phone's mic in a noisy room makes that
## unreliable, and the rule only needs the chant to keep going. The noise floor is learnt
## while you are not chanting, so a fan or the game's own crowd does not count as voice.

const BUS := "VoiceCant"
const VOICE_RATIO := 3.0     # this many times the noise floor counts as voice
const MIN_LEVEL := 0.012     # and never quieter than this (RMS, full scale = 1)

var ok := false              # the mic is open and delivering sound
var level := 0.0             # smoothed loudness, 0..1
var noise := 0.008           # learnt noise floor
var voiced := false
var _last_voice := -1e9      # seconds, on this node's clock
var _clock := 0.0
var _heard := 0.0            # seconds of voice heard so far, to tell a working mic from silence
var _player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _fake := -1.0            # tests: a level to use instead of the mic


## Ask the phone for the microphone. Returns true if it is already granted.
static func request_permission() -> bool:
	if OS.get_name() == "Android":
		return OS.request_permission("android.permission.RECORD_AUDIO")
	return true


## Whether this build can listen at all.
static func supported() -> bool:
	return bool(ProjectSettings.get_setting("audio/driver/enable_input", false)) and DisplayServer.get_name() != "headless"


func start() -> void:
	if _player:
		return
	if not supported():
		return
	var idx := AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.25
		AudioServer.add_bus_effect(idx, _capture)
		# Listen, but never play the mic back through the speaker.
		AudioServer.set_bus_volume_db(idx, -80.0)
	else:
		_capture = AudioServer.get_bus_effect(idx, 0) as AudioEffectCapture
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = BUS
	add_child(_player)
	_player.play()


func stop() -> void:
	if _player:
		_player.stop()
		_player.queue_free()
		_player = null


## Tests and the menu demo: pretend the mic hears this level (negative: back to the mic).
func fake_level(v: float) -> void:
	_fake = v
	ok = v >= 0.0 or ok


func _process(delta: float) -> void:
	_clock += delta
	var rms := 0.0
	if _fake >= 0.0:
		rms = _fake
	elif _capture:
		var n := _capture.get_frames_available()
		if n > 0:
			var buf := _capture.get_buffer(n)
			var sum := 0.0
			for f in buf:
				var s := (f.x + f.y) * 0.5
				sum += s * s
			rms = sqrt(sum / float(n))
			ok = true
	else:
		return
	level = lerpf(level, clampf(rms * 6.0, 0.0, 1.0), clampf(delta * 18.0, 0.0, 1.0))
	voiced = rms > maxf(noise * VOICE_RATIO, MIN_LEVEL)
	if voiced:
		_last_voice = _clock
		_heard += delta
	else:
		# The floor follows quiet quickly and loud slowly, so chanting does not raise it.
		noise = lerpf(noise, rms, clampf(delta * (4.0 if rms < noise else 0.15), 0.0, 1.0))


## Seconds since the last voiced moment.
func silence() -> float:
	return _clock - _last_voice


## Something has been heard since the mic opened (so a dead mic is not mistaken for a
## raider who stopped chanting).
func has_heard() -> bool:
	return _heard > 0.15
