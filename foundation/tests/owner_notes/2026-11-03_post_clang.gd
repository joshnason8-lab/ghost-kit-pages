extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.22 (reported twice)): "the post clang can't be heard"

const NOTE := {"id": "2026-11-03-post-clang", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.22 (reported twice)", "words": "the post clang can't be heard"}

## A ping off the post 50 m from the camera keeps its highs (4 kHz as loud as its 500 Hz, within 3 dB) - the clang,
## not a thud; every key hit's kind is crisp at a distance.
func check() -> void:
	var au := WsgAudio.new()
	tree.root.add_child(au)
	var cam := Camera3D.new()
	tree.root.add_child(cam)
	cam.current = true
	await frame()
	for f in WsgNoteChecks.bright(au, ["post", "bar", "crossbar", "net", "whistle", "hit", "strike", "tag", "ball"]):
		fail(f)
	var cap := AudioEffectCapture.new()
	var bus := AudioServer.get_bus_index("WsgSfx")
	AudioServer.add_bus_effect(bus, cap)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 44100
	var d := PackedByteArray()
	d.resize(44100 * 2)
	for i in 44100:
		var t := float(i) / 44100.0
		d.encode_s16(i * 2, int((sin(TAU * 500.0 * t) + sin(TAU * 4000.0 * t)) * 9000.0))
	w.data = d
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = 44100
	await _listen(cap, 0.3)
	au.play_at(w, Vector3(0, 0, -50), 0.0, 1.0, "post", 1)
	await _listen(cap, 0.2)
	var buf := await _listen(cap, 0.5)
	var ratio := 10.0 * log(maxf(_power(buf, 4000.0), 1e-12) / maxf(_power(buf, 500.0), 1e-12)) / log(10.0)
	info("the post's ping 50 m off: its 4 kHz %+.1f dB against its 500 Hz (the recording: 0)" % ratio)
	expect(absf(ratio) <= 3.0, "the post's ping 50 m off loses its highs (%+.1f dB): a thud" % ratio)
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	au.queue_free()
	cam.queue_free()


func _listen(cap: AudioEffectCapture, secs: float) -> PackedVector2Array:
	cap.clear_buffer()
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < secs * 1000.0:
		await frame()
	return cap.get_buffer(cap.get_frames_available())


func _power(buf: PackedVector2Array, hz: float) -> float:
	var k := 2.0 * cos(TAU * hz / AudioServer.get_mix_rate())
	var s1 := 0.0
	var s2 := 0.0
	for v in buf:
		var s0 := v.x + k * s1 - s2
		s2 = s1
		s1 = s0
	return (s1 * s1 + s2 * s2 - k * s1 * s2) / maxf(1.0, buf.size())
