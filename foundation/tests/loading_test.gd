extends SceneTree
## WsgLoading: a tap on a menu's start button puts the overlay up in the same frame, turns the buttons off and keeps
## the heavy work back until it has been drawn; a second tap starts nothing; the bar runs forward only, to the end;
## the files come off the loader's thread; a long step cut by checkpoint() never holds the main thread for long, and
## one that is not cut is caught in the log line; a missing file brings the menu back; the overlay fits a portrait and
## a landscape screen.
##   godot --headless --path . -s tests/loading_test.gd
## (Timings here are this computer's, not a phone's: a game reads its own WSG_LOADING line on the A16.)

const FILES := ["res://tests/character/hero_hi.res", "res://tests/character/hero_lo.res", "res://tests/media/crowd_video.tscn"]

var fails := []
var starts := 0
var at_cover := {}
var at_start := {}
var bar := []
var made := {}
var result := {}


var screen: SubViewport


func _initialize() -> void:
	# The menu on a phone-sized screen of its own (a headless run's window is 64 px).
	screen = SubViewport.new()
	screen.size = Vector2i(1280, 720)
	root.add_child(screen)
	var menu := Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(menu)
	var start := Button.new()
	start.text = "Start"
	start.position = Vector2(100, 100)
	start.size = Vector2(240, 90)
	menu.add_child(start)
	var watch := Button.new()
	watch.text = "Watch"
	watch.position = Vector2(100, 220)
	watch.size = Vector2(240, 90)
	menu.add_child(watch)
	start.pressed.connect(_on_start.bind(menu, [start, watch]))
	await process_frame
	await process_frame

	# The tap, as a finger's (pressed and released on the button).
	_tap(start)
	if starts != 1:
		fails.append("the tap did not start the load")
	# A second tap while it loads: the button is off and the overlay takes the touch.
	await process_frame
	_tap(start)
	_tap(watch)
	var deadline := Time.get_ticks_msec() + 20000
	while result.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if result.is_empty():
		printerr("FAIL: the load never finished (starts %d, at the tap %s, at the start %s)" % [starts, at_cover, at_start])
		print("LOADING TEST: FAIL (hung)")
		quit(1)
		return
	if starts != 1:
		fails.append("a second tap started a second load (%d starts)" % starts)
	if not at_cover.get("in_tree", false) or not at_cover.get("visible", false):
		fails.append("the overlay was not up in the tap's own frame: %s" % at_cover)
	if not at_cover.get("buttons_off", false):
		fails.append("the start buttons were still on after the tap")
	if at_start.is_empty():
		fails.append("the load never signalled its start")
	else:
		print("at the tap: %s; when the load started: %s" % [at_cover, at_start])
		if int(at_start.frames) < 2 or not at_start.visible:
			fails.append("the load started before the overlay had been drawn (%d frames after the tap)" % int(at_start.frames))
		if made.get("scene_before_start", false):
			fails.append("a step ran before the load started")
	var r: Dictionary = result.report
	if not result.ok:
		fails.append("the load failed: %s" % r)
	for p in FILES:
		if not result.res.get(p) is Resource:
			fails.append("%s did not load" % p)
	if not made.get("scene_ok", false):
		fails.append("the scene step did not instantiate the loaded scene")
	for i in range(1, bar.size()):
		if float(bar[i]) < float(bar[i - 1]) - 1e-6:
			fails.append("the bar went back (%.3f after %.3f)" % [bar[i], bar[i - 1]])
			break
	if bar.is_empty() or absf(float(bar[-1]) - 1.0) > 1e-4:
		fails.append("the bar did not reach the end")
	print("longest main-thread slice %.1f ms (%s), longest frame %.1f ms, %d frames, %.0f ms in all" % [r.longest_slice_ms, r.longest_slice, r.longest_frame_ms, r.frames, r.total_ms])
	if float(r.longest_slice_ms) > 120.0:
		fails.append("a sliced step held the main thread %.0f ms (cut every 50 ms of 20 ms chunks: at most about 70)" % r.longest_slice_ms)
	if float(r.steps.get("Crowd", 0.0)) < 590.0:
		fails.append("the crowd step's time was not all counted (%.0f ms of 600)" % float(r.steps.get("Crowd", 0.0)))
	await process_frame
	await create_timer(0.4).timeout
	if WsgLoading.busy():
		fails.append("the overlay was still up after done()")
	if start.disabled:
		fails.append("done() did not turn the buttons back on")

	# A step that is not cut: its stall is in the log line, by name.
	var ld := WsgLoading.cover(menu)
	ld.step("Unsliced", func(): OS.delay_msec(300))
	await ld.run()
	print("unsliced: %s" % ld.report)
	if float(ld.report.longest_slice_ms) < 290.0 or String(ld.report.longest_slice) != "Unsliced":
		fails.append("a 300 ms step was not reported as the longest slice: %s" % ld.report)
	ld.done()
	await ld.finished

	# A file that is not there: run() says so, the overlay goes, the buttons come back.
	var ld2 := WsgLoading.cover(menu, [start])
	ld2.request(["res://not/there.tscn"])
	var ran := [false]
	ld2.step("never", func(): ran[0] = true)
	var ok: bool = await ld2.run()
	await create_timer(0.4).timeout
	if ok or ran[0] or WsgLoading.busy() or start.disabled:
		fails.append("a missing file: ok %s, steps ran %s, still up %s, buttons off %s" % [ok, ran[0], WsgLoading.busy(), start.disabled])

	# Portrait and landscape: the title, bar and tip on the screen, the bar a good part of its width.
	for size in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(480, 854)]:
		var sv := SubViewport.new()
		sv.size = size
		root.add_child(sv)
		var host := Control.new()
		sv.add_child(host)
		var l3 := WsgLoading.cover(host, [], {"tips": ["Hold the button to charge a shot, release to strike.", "A short tip."], "title": "Loading…"})
		await process_frame
		await process_frame
		var parts := l3.parts()
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		for k in ["title", "bar_back", "tip", "spinner"]:
			var c: Control = parts[k]
			if not screen.encloses(c.get_global_rect()) or c.get_global_rect().size.x < 1.0:
				fails.append("%s at %s: the %s is off the screen or empty (%s)" % [size, size, k, c.get_global_rect()])
		var bw: float = (parts.bar_back as Control).get_global_rect().size.x
		if bw < size.x * 0.5 or bw > size.x * 0.95:
			fails.append("%s: the bar is %.0f px wide" % [size, bw])
		print("%s: title %s, bar %s, tip %s" % [size, (parts.title as Control).get_global_rect(), (parts.bar_back as Control).get_global_rect(), (parts.tip as Control).get_global_rect()])
		l3.done()
		await l3.finished
		sv.queue_free()

	for f in fails:
		printerr("FAIL: ", f)
	print("LOADING TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


func _on_start(menu: Control, buttons: Array) -> void:
	starts += 1
	var f0 := Engine.get_process_frames()
	var ld := WsgLoading.cover(menu, buttons, {"tips": ["Tip one.", "Tip two."]})
	at_cover = {"in_tree": ld.is_inside_tree(), "visible": ld.visible and (ld.parts().root as Control).visible,
		"buttons_off": buttons.all(func(b): return (b as BaseButton).disabled)}
	ld.load_started.connect(func():
		at_start = {"frames": Engine.get_process_frames() - f0, "visible": ld.visible and ld.is_inside_tree(),
			"buttons_off": buttons.all(func(b): return (b as BaseButton).disabled)})
	ld.progressed.connect(func(f: float, _l: String): bar.append(f))
	ld.request(FILES)
	ld.step("Scene", func():
		made["scene_before_start"] = at_start.is_empty()
		made["scene"] = (ld.res(FILES[2]) as PackedScene).instantiate())
	ld.step("Crowd", func():
		for i in 30:
			OS.delay_msec(20)
			await ld.checkpoint((i + 1) / 30.0), 3.0)
	ld.step("Light", func(): OS.delay_msec(30))
	var ok := await ld.run()
	var res := {}
	for p in FILES:
		res[p] = ld.res(p)
	made["scene_ok"] = made.get("scene") is Node
	if made.scene_ok:
		(made.scene as Node).free()
	result = {"ok": ok, "report": ld.report, "res": res}
	ld.done()


func _tap(b: Control) -> void:
	var at := b.get_global_rect().get_center()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		screen.push_input(ev)
