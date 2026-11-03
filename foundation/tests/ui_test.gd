extends SceneTree
## The common UI (owner-approved item 8): the credits screen built a little a frame (never a long frame, every section
## there, the High pack's credits read); WsgHaptics' patterns and the setting; the Settings screen (a tier, a volume,
## haptics, the joystick - applied, saved, read back); the spectator's Skip over a moment (a tap skips too); tutorial
## prompts (shown when their moment comes, gone when done, never again; Skip tips); Watch AI's setup; the game's theme.
##   godot --headless --path . -s tests/ui_test.gd

var fails := []


func _initialize() -> void:
	await process_frame
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	root.add_child(sv)
	var theme := WsgBroadcastTheme.new()
	theme.accent = Color(0.1, 0.8, 0.3)
	DirAccess.remove_absolute(WsgSettings.PATH)
	WsgSettings.load_all()
	# 1. Credits: a little a frame; every section; the pack's.
	var pj := "user://ui_test_pack.json"
	var f := FileAccess.open(pj, FileAccess.WRITE)
	f.store_string(JSON.stringify({"url": "x", "credits": [{"title": "Skies", "body": "Poly Haven (CC0)"}]}))
	f.close()
	var packs := WsgCredits.pack_sections(pj)
	_expect(packs.size() == 1 and str(packs[0].title).contains("Skies"), "the High pack's credits were not read: %s" % [packs])
	var game := [{"title": "Sounds", "body": "Crowd: kenney.nl (CC0)\n\nWhistle: opengameart.org (CC BY 3.0)"}]
	var cr := WsgCredits.new(theme, game)
	var t0 := Time.get_ticks_msec()
	sv.add_child(cr)
	var frames := 0
	while not cr.done and frames < 3000:
		await process_frame
		frames += 1
	var text := ""
	for l in cr.find_children("*", "Label", true, false):
		text += (l as Label).text + "\n"
	print("credits: %d paragraphs in %d frames (%d ms), the longest frame of building %.1f ms" % [cr.built_paragraphs, frames, Time.get_ticks_msec() - t0, cr.longest_ms])
	_expect(cr.done, "the credits never finished building")
	_expect(frames >= 2, "the credits were built in one frame (not a little a frame)")
	_expect(cr.longest_ms < 50.0, "a frame of the credits' build took %.0f ms" % cr.longest_ms)
	for want in ["kenney.nl", "Godot Engine", "Third-party components", "MIT"]:
		_expect(text.contains(want), "the credits lack '%s'" % want)
	cr.queue_free()
	# 2. Haptics.
	var got := []
	WsgHaptics.sink = func(ms: int, s: float): got.append([ms, s])
	WsgHaptics.enabled = true
	await WsgHaptics.play("bonus")
	_expect(got == [[25, 0.6], [25, 0.6]], "the bonus point is not a quick double pulse: %s" % [got])
	got.clear()
	await _ms(80)
	WsgHaptics.enabled = false
	await WsgHaptics.play("score")
	_expect(got.is_empty(), "haptics off still buzzed")
	WsgHaptics.enabled = true
	await WsgHaptics.play("no such moment")
	_expect(got.is_empty(), "an unknown moment buzzed")
	print("haptics: bonus a double pulse, off silent")
	# (A lambda left in a static var outlives this script at exit: Godot's heap was corrupted on quit.)
	WsgHaptics.sink = Callable()
	# 3. Settings.
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	var ss := WsgSettings.screen(theme, {"buses": ["Music"]})
	var applied := []
	ss.applied.connect(func(k, v): applied.append([k, v]))
	sv.add_child(ss)
	await process_frame
	(ss.controls.graphics[2] as Button).pressed.emit()
	(ss.controls["volume_Music"] as HSlider).value = 0.5
	(ss.controls.haptics as CheckButton).button_pressed = false
	(ss.controls.joystick_side as Button).pressed.emit()
	await process_frame
	_expect(WsgFoundation.tier == 2, "Graphics High did not set the tier")
	_expect(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.5)) < 0.1, "the Music slider did not set its bus")
	_expect(not WsgHaptics.enabled, "Vibration off did not turn haptics off")
	WsgSettings.values = {}
	WsgSettings.load_all()
	_expect(int(WsgSettings.get_value("graphics")) == 2 and not bool(WsgSettings.get_value("haptics")) and WsgSettings.get_value("joystick_side") == "right", "the settings were not saved: %s" % [WsgSettings.values])
	var title: Label = ss.find_children("*", "Label", true, false)[0]
	_expect(title.get_theme_color("font_color") == theme.accent, "the screen does not wear the game's theme")
	print("settings: applied %s; read back %s" % [applied.map(func(a): return a[0]), WsgSettings.values])
	ss.queue_free()
	WsgHaptics.enabled = true
	# 4. The spectator's Skip.
	var world := Node3D.new()
	sv.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 10, 20)
	var spec := WsgSpectator.new()
	world.add_child(spec)
	spec.cooldown = 0.3
	spec.start(cam)
	spec.make_overlay(theme)
	await process_frame
	var scorer := Node3D.new()
	world.add_child(scorer)
	var started := spec.moment("score", {"replay": false, "target": scorer, "crowd_at": Vector3(0, 3, -20)})
	await process_frame
	var layer := spec.find_child("SpectatorSkip", true, false) as CanvasLayer
	_expect(started and spec.in_moment and layer != null and layer.visible, "no Skip button over a moment (started %s, in moment %s, layer %s, visible %s)" % [started, spec.in_moment, layer != null, layer.visible if layer else false])
	spec.skip_button().pressed.emit()
	await process_frame
	_expect(not spec.in_moment and not layer.visible, "Skip did not end the moment")
	await _ms(spec.cooldown * 1000.0 + 200)
	spec.moment("score", {"replay": false, "target": scorer, "crowd_at": Vector3(0, 3, -20)})
	await process_frame
	_expect(spec.in_moment, "the second moment did not run (the tap is untested)")
	if spec.in_moment:
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		spec._unhandled_input(tap)
		_expect(not spec.in_moment, "a tap did not skip the moment")
	print("spectator: Skip shown over a moment, pressed: ended; a tap skips")
	spec.stop()
	world.queue_free()
	# 5. Tutorial prompts.
	var flags := {"started": false, "moved": false}
	var tips := WsgTutorial.new(theme)
	tips.add("move", "Drag to run", func(): return flags.started, func(): return flags.moved)
	sv.add_child(tips)
	await process_frame
	_expect(tips.current == "", "a tip shown before its moment")
	flags.started = true
	await process_frame
	_expect(tips.current == "move", "the tip did not show when its moment came")
	flags.moved = true
	await process_frame
	_expect(tips.current == "" and WsgTutorial.seen("move"), "the tip did not go once done")
	var tips2 := WsgTutorial.new(theme)
	tips2.add("move", "Drag to run", func(): return true)
	sv.add_child(tips2)
	await process_frame
	_expect(tips2.current == "", "a seen tip came back")
	WsgTutorial.reset()
	await process_frame
	_expect(tips2.current == "move", "reset() did not bring the tips back")
	(tips2.find_child("SkipTips", true, false) as Button).pressed.emit()
	await process_frame
	_expect(tips2.current == "" and bool(WsgSettings.get_value("tutorial_off")), "Skip tips did not turn them off")
	print("tutorial: shown at its moment, gone when done, never again; Skip tips off")
	tips.queue_free()
	tips2.queue_free()
	WsgTutorial.reset()
	# 6. Watch AI.
	var entry := WsgWatchSetup.entry_button(theme)
	_expect(entry.text != "", "no Watch AI entry")
	var w := WsgWatchSetup.new(theme, ["Mumbai", "Pune", "Delhi"], ["Dome", "Village"])
	sv.add_child(w)
	var picked := []
	w.watch.connect(func(h, a, v): picked.append([h, a, v]))
	w.away.select(2)
	w.venue.select(1)
	w.go.pressed.emit()
	_expect(picked == [[0, 2, 1]], "Watch did not start the picked match: %s" % [picked])
	print("watch AI: entry, picked home 0 away 2 venue 1")
	w.queue_free()
	entry.free()
	DirAccess.remove_absolute(WsgSettings.PATH)
	DirAccess.remove_absolute(pj)
	print("UI TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		printerr(msg)


func _ms(ms: int) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < ms:
		await process_frame
