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
	if not r.get("settled", false):
		fails.append("the frames did not settle after a plain load: %s" % r)
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
	await _gone(ld)

	# A file that is not there: run() says so, the overlay goes, the buttons come back.
	var ld2 := WsgLoading.cover(menu, [start])
	ld2.request(["res://not/there.tscn"])
	var ran := [false]
	ld2.step("never", func(): ran[0] = true)
	var ok: bool = await ld2.run()
	await create_timer(0.4).timeout
	if ok or ran[0] or WsgLoading.busy() or start.disabled:
		fails.append("a missing file: ok %s, steps ran %s, still up %s, buttons off %s" % [ok, ran[0], WsgLoading.busy(), start.disabled])

	# Settle: the match's first frames stall (shader compiles, cold resources: 150 ms each here); the overlay stays
	# until 3 frames in a row come in under 50 ms, and no longer than settle_cap when they never do. A phone that is
	# slow every frame (70 ms, steady) settles at once.
	for case in [[5, 3.0, 150], [1000, 0.5, 150], [1000, 3.0, 70]]:
		var staller := Staller.new()
		staller.left = case[0]
		staller.ms = case[2]
		var l4 := WsgLoading.cover(menu)
		l4.settle_cap = case[1]
		l4.step("Swap", func(): screen.add_child(staller))
		await l4.run()
		var t_done := Time.get_ticks_msec()
		await l4.done()
		var r4 := l4.report
		print("settle (%d frames of %d ms, cap %.1f s): %s ms, settled %s, longest %s ms; the stalls ended at %d ms" % [case[0], case[2], case[1], r4.settle_ms, r4.settled, r4.settle_longest_frame_ms, staller.ended - t_done if staller.ended else -1])
		if case[0] < 100:
			if not r4.settled or staller.ended == 0 or Time.get_ticks_msec() < staller.ended:
				fails.append("the overlay did not wait for the slow frames to end: %s" % r4)
			if float(r4.settle_ms) < 3 * 150.0:
				fails.append("settled in %.0f ms over five 150 ms frames (one may fall in the load)" % r4.settle_ms)
		elif case[2] < 100:
			if not r4.settled or float(r4.settle_ms) > 6 * 70.0:
				fails.append("a steady 70 ms phone did not settle at once: %s" % r4)
		elif r4.settled or float(r4.settle_ms) > 1000.0:
			fails.append("frames that never settle: the overlay held %s ms (cap 0.5 s), settled %s" % [r4.settle_ms, r4.settled])
		staller.queue_free()
		await _gone(l4)

	# Warm-up: every look under a scene drawn once, a batch a frame, each batch inside the warm-up camera's view; looks
	# shared by many nodes counted once; layers, visibility ranges and the game's camera put back.
	var scene := _warm_scene()
	screen.add_child(scene)
	var game_cam: Camera3D = scene.get_node("GameCam")
	game_cam.make_current()
	var seen := {}
	var outside := []
	var before := {}
	for g in scene.find_children("*", "GeometryInstance3D", true, false):
		before[g] = [(g as GeometryInstance3D).layers, (g as GeometryInstance3D).visibility_range_begin, (g as GeometryInstance3D).visibility_range_end]
	var st: Dictionary = await WsgLoading.warm_scene(scene, func(_f: float):
		var cam := screen.get_camera_3d()
		for g in before:
			var gi := g as GeometryInstance3D
			if gi.layers != 0 and not seen.has(gi) and not String(gi.name) in ["OtherLayer", "Hidden"]:
				seen[gi] = true
				if cam == game_cam or not cam.is_position_in_frustum(gi.global_transform * gi.get_aabb().get_center()):
					outside.append(String(gi.name)))
	print("warm-up: %s; outside the camera's view when drawn: %s" % [st, outside])
	if int(st.nodes) != 12 or int(st.looks) != 9:
		fails.append("the warm-up found %d nodes and %d looks (12 and 9: four share a look, the hidden and other-layer ones are left)" % [st.nodes, st.looks])
	if seen.size() != 12:
		fails.append("%d of 12 nodes were drawn during the warm-up" % seen.size())
	if not outside.is_empty():
		fails.append("drawn outside the warm-up camera's view: %s" % outside)
	for g in before:
		var gi := g as GeometryInstance3D
		if [gi.layers, gi.visibility_range_begin, gi.visibility_range_end] != before[g]:
			fails.append("%s not put back: %s, was %s" % [gi.name, [gi.layers, gi.visibility_range_begin, gi.visibility_range_end], before[g]])
	await process_frame
	if screen.get_camera_3d() != game_cam or scene.find_children("*", "Camera3D", true, false).size() != 1:
		fails.append("the game's camera was not put back, or the warm-up's camera stayed")
	# And as a step: the overlay goes opaque for it, and its numbers are in the log line.
	# A node freed by the game during the warm-up (a prop swapped out, a body removed): the rest still warmed, put back.
	var scene2 := _warm_scene()
	screen.add_child(scene2)
	var victim := scene2.get_node("Own3")
	var st2: Dictionary = await WsgLoading.warm_scene(scene2, func(_f: float):
		if is_instance_valid(victim):
			victim.free())
	var restored := true
	for g in scene2.find_children("*", "GeometryInstance3D", true, false):
		if (g as GeometryInstance3D).layers == 0:
			restored = false
	print("warm-up with a node freed in it: %s, layers put back %s" % [st2, restored])
	if int(st2.get("looks", 0)) != 9 or not restored:
		fails.append("a node freed during the warm-up: %s, put back %s" % [st2, restored])
	scene2.queue_free()

	# 3D stays off from the first step to the warm-up, so a scene swapped in by an earlier step is not drawn whole.
	var l5 := WsgLoading.cover(menu)
	var off := []
	l5.step("Show", func(): off.append(screen.disable_3d))
	l5.warm(func():
		off.append(screen.disable_3d)
		return scene)
	await l5.run()
	if off != [true, true] or screen.disable_3d:
		fails.append("3D during the steps before the warm-up %s, after the run %s (off, then back on)" % [off, screen.disable_3d])
	await l5.done()
	if int(l5.report.get("warm", {}).get("looks", 0)) != 9:
		fails.append("ld.warm() did not report its looks: %s" % l5.report)
	scene.queue_free()
	await _gone(l5)

	# Prewarm: the menu starts the file; the tap's run() takes it as it is, without asking for it again.
	var pre := "res://addons/wsg_foundation/crowd/cards.png"
	WsgLoading.prewarm([pre])
	var t_pre := Time.get_ticks_msec()
	while ResourceLoader.load_threaded_get_status(pre) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() - t_pre < 10000:
		await process_frame
	var l6 := WsgLoading.cover(menu)
	l6.request([pre])
	await l6.run()
	if not l6.res(pre) is Texture2D or not (l6.report.prewarmed as Array).has(pre):
		fails.append("a prewarmed file: %s, report %s" % [l6.res(pre), l6.report])
	# A short load (a rematch) closes at once, without the fade.
	var r6 := l6.report
	var t_close := Time.get_ticks_msec()
	await l6.done()
	await process_frame
	if WsgLoading.busy() or is_instance_valid(l6):
		fails.append("a %s ms load did not close at once" % r6.total_ms)
	print("prewarmed load: %s ms in all (load %s ms), closed in %d ms" % [r6.total_ms, r6.load_ms, Time.get_ticks_msec() - t_close])

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
		await _gone(l3)
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
	await ld.done()
	result = {"ok": ok, "report": ld.report, "res": res}


func _tap(b: Control) -> void:
	var at := b.get_global_rect().get_center()
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		screen.push_input(ev)


func _gone(ld: WsgLoading) -> void:
	var t := Time.get_ticks_msec()
	while is_instance_valid(ld) and Time.get_ticks_msec() - t < 5000:
		await process_frame
	if is_instance_valid(ld):
		fails.append("an overlay did not go after done()")


## A test ground for the warm-up: 12 nodes in 9 looks (four boxes share a mesh and material), one far detail level
## (shown only from 40 m), a multimesh, particles, one hidden (not drawn, left) and one on a layer the camera does not
## see (left), spread over 60 m.
func _warm_scene() -> Node3D:
	var s := Node3D.new()
	var cam := Camera3D.new()
	cam.name = "GameCam"
	cam.cull_mask = 1
	cam.position = Vector3(0, 5, 30)
	s.add_child(cam)
	var box := BoxMesh.new()
	var shared := StandardMaterial3D.new()
	for i in 4:
		var m := MeshInstance3D.new()
		m.name = "Shared%d" % i
		m.mesh = box
		m.material_override = shared
		m.position = Vector3(-30 + i * 3, 0, 0)
		s.add_child(m)
	for i in 5:
		var m := MeshInstance3D.new()
		m.name = "Own%d" % i
		m.mesh = SphereMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if i % 2 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.material_override = mat
		m.position = Vector3(i * 6, 0, -20 + i * 8)
		s.add_child(m)
	(s.get_node("Own4") as GeometryInstance3D).visibility_range_begin = 40.0
	var mm := MultiMeshInstance3D.new()
	mm.name = "Crowd"
	mm.multimesh = MultiMesh.new()
	mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mm.multimesh.mesh = box
	mm.multimesh.instance_count = 10
	for i in 10:
		mm.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(i, 0, 25)))
	s.add_child(mm)
	var parts := CPUParticles3D.new()
	parts.name = "Sparks"
	parts.mesh = box
	parts.position = Vector3(25, 2, 10)
	s.add_child(parts)
	var other := MeshInstance3D.new()
	other.name = "OtherLayer"
	other.mesh = SphereMesh.new()
	other.layers = 2
	s.add_child(other)
	var hidden := MeshInstance3D.new()
	hidden.name = "Hidden"
	hidden.mesh = SphereMesh.new()
	hidden.visible = false
	s.add_child(hidden)
	# A nested one: drawn as its own look.
	var holder := Node3D.new()
	holder.position = Vector3(-10, 3, 15)
	s.add_child(holder)
	var nested := MeshInstance3D.new()
	nested.name = "Nested"
	nested.mesh = box
	nested.material_override = StandardMaterial3D.new()
	holder.add_child(nested)
	return s


## A node whose first LEFT frames each take MS ms (a match's first frames compiling shaders; or a slow phone).
class Staller extends Node:
	var left := 0
	var ms := 150
	var ended := 0

	func _process(_d: float) -> void:
		if left > 0:
			OS.delay_msec(ms)
			left -= 1
			if left == 0:
				ended = Time.get_ticks_msec()
