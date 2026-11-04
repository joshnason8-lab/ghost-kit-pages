extends SceneTree
## The audio foundation (WsgAudio): the crowd's layers follow the game's excitement and tension (the base layer the
## ground's size), a duck pulls the crowd down and lets it back, and the positional voices keep their limits - a
## kind's own, the tier's total, the lowest priority giving way and a quieter newcomer turned away.
##   godot --headless --path . --fixed-fps 30 -s tests/audio_test.gd

func _initialize() -> void:
	var fails := []
	var au := WsgAudio.new()
	root.add_child(au)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	await process_frame
	var tone := AudioStreamWAV.new()
	tone.format = AudioStreamWAV.FORMAT_16_BITS
	tone.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2 * 4)
	tone.data = data
	tone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	tone.loop_end = 22050 * 4
	au.crowd_layers({"murmur": {"stream": tone, "db": [-26.0, -12.0], "by": "base"},
		"applause": {"stream": tone, "db": [-40.0, -10.0], "by": "excite"},
		"tension": {"stream": tone, "db": [-45.0, -12.0], "by": "tension"}})
	au.base = 0.5
	WsgCrowd3D.set_excite(0.0)
	WsgCrowd3D.set_tension(0.0)
	for i in 60:
		await process_frame
	var quiet := [au._layers.murmur[0].volume_db, au._layers.applause[0].volume_db, au._layers.tension[0].volume_db]
	WsgCrowd3D.set_excite(1.0)
	WsgCrowd3D.set_tension(0.8)
	for i in 60:
		await process_frame
	var loud := [au._layers.murmur[0].volume_db, au._layers.applause[0].volume_db, au._layers.tension[0].volume_db]
	print("crowd layers (murmur, applause, tension) dB: calm %s, a score %s" % [quiet.map(func(x): return snappedf(x, 0.1)), loud.map(func(x): return snappedf(x, 0.1))])
	if not (loud[1] > quiet[1] + 15.0 and loud[2] > quiet[2] + 15.0 and absf(loud[0] - quiet[0]) < 1.0):
		fails.append("the layers did not follow the excitement and tension")
	WsgCrowd3D.set_excite(0.0)
	WsgCrowd3D.set_tension(0.0)
	# A duck: the crowd's bus down, then back.
	var ci := AudioServer.get_bus_index("WsgCrowd")
	au.duck(8.0, 0.3, 0.2)
	await process_frame
	await process_frame
	var ducked := AudioServer.get_bus_volume_db(ci)
	await create_timer(0.8).timeout
	await process_frame
	var back := AudioServer.get_bus_volume_db(ci)
	print("duck: crowd bus %.1f dB, then %.1f dB" % [ducked, back])
	if ducked > -7.5 or back < -0.5:
		fails.append("duck: %.1f then %.1f" % [ducked, back])
	# Voices: a kind's limit, the total, priority.
	var n := au._pool.size()
	au.kind_limits = {"step": 2}
	var steps := 0
	for i in 4:
		steps += 1 if au.play_at(tone, Vector3(i, 0, 0), 0.0, 1.0, "step", 0) else 0
	print("4 steps asked, limit 2: %d played" % steps)
	if steps != 2:
		fails.append("kind limit: %d steps" % steps)
	var filled := steps
	for i in n:
		filled += 1 if au.play_at(tone, Vector3(5 + i, 0, 0), 0.0, 1.0, "crowd_knock", 1) else 0
	print("pool of %d (the tier's): busy %d" % [n, au.busy()])
	var low_ok := au.play_at(tone, Vector3(200, 0, 0), 0.0, 1.0, "far_thing", 0)
	var high_ok := au.play_at(tone, Vector3(1, 0, 0), 0.0, 1.0, "strike", 5)
	print("all busy: a far priority-0 sound %s, a priority-5 strike %s" % ["played" if low_ok else "turned away", "played" if high_ok else "turned away"])
	if au.busy() != n or low_ok or not high_ok:
		fails.append("priority: busy %d of %d, low %s, high %s" % [au.busy(), n, low_ok, high_ok])
	# A key hit far off stays crisp: a two-tone ping (500 Hz and 4 kHz, equal) 50 m from the camera, mixed and caught
	# on the sfx bus. A "post" keeps its 4 kHz as loud as its 500 Hz; a step (ambience) loses its highs to distance.
	for p in au._pool:
		p.stop()
	var cap := AudioEffectCapture.new()
	var bus := AudioServer.get_bus_index("WsgSfx")
	AudioServer.add_bus_effect(bus, cap)
	var ping := _two_tone()
	await _listen(cap, 0.3)     # the mixer's first catch comes back empty
	var ratio := {}
	for kind in ["step", "post"]:
		au.play_at(ping, Vector3(0, 0, -50), 0.0, 1.0, kind, 1)
		await _listen(cap, 0.2)
		var buf := await _listen(cap, 0.5)
		for p in au._pool:
			p.stop()
		var hi := _goertzel(buf, 4000.0)
		var lo := _goertzel(buf, 500.0)
		ratio[kind] = 10.0 * log(maxf(hi, 1e-12) / maxf(lo, 1e-12)) / log(10.0)
	print("a ping 50 m off, 4 kHz against 500 Hz: a step %.1f dB, a post %.1f dB (the recording: 0)" % [ratio.step, ratio.post])
	if absf(ratio.post) > 3.0 or ratio.step > -6.0:
		fails.append("the highs at 50 m: a post %.1f dB (want about 0), a step %.1f dB (want dulled)" % [ratio.post, ratio.step])
	for f in fails:
		printerr("FAIL: ", f)
	print("AUDIO TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


## 1 s of 500 Hz and 4 kHz at equal strength, looping.
func _two_tone() -> AudioStreamWAV:
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
	return w


## What the bus played over SECS of real time (the mixer runs on the wall clock, not the test's fixed frames).
func _listen(cap: AudioEffectCapture, secs: float) -> PackedVector2Array:
	cap.clear_buffer()
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < secs * 1000.0:
		await process_frame
	return cap.get_buffer(cap.get_frames_available())


## The power at one frequency (Goertzel), left channel.
func _goertzel(buf: PackedVector2Array, hz: float) -> float:
	var k := 2.0 * cos(TAU * hz / AudioServer.get_mix_rate())
	var s1 := 0.0
	var s2 := 0.0
	for v in buf:
		var s0 := v.x + k * s1 - s2
		s2 = s1
		s1 = s0
	return (s1 * s1 + s2 * s2 - k * s1 * s2) / maxf(1.0, buf.size())
