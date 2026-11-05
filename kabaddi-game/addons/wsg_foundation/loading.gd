class_name WsgLoading
extends CanvasLayer
## The loading overlay every game drops in front of its start buttons. The owner: "when you click start game there is
## a loading delay ... long enough on the slow phone that users might think the game has frozen."
##
## On the tap, in the same frame, the menu dims, "Loading..." and a bar appear with a spinner, and the start buttons go
## dead (a second tap can't start a second load). The heavy work waits until the overlay has been drawn. The match's
## files then load on a thread (ResourceLoader.load_threaded_request) and drive a real bar. The building that has to
## run on the main thread (instantiate, the venue, the crowd, the light) runs in steps, each followed by a drawn frame,
## and a long step can cut itself into slices with checkpoint(). The overlay times every main-thread slice and every
## frame, and prints the longest as one line a device lab can read (WSG_LOADING {json}). Aim: no slice over 250 ms on
## the slowest phone (the A16, Low).
##
##   func _on_start_pressed() -> void:
##       var ld := WsgLoading.cover(self, [start_button, watch_button], LOOK)
##       ld.request(["res://game/match.tscn"])            # threaded: resources only, never UI nodes made
##       ld.step("Match", func(): _match = ld.res("res://game/match.tscn").instantiate())
##       ld.step("Pitch", func(): _match.build_pitch())
##       ld.step("Crowd", _build_crowd)                  # may itself `await ld.checkpoint()` between chunks
##       ld.step("Show", func(): get_tree().root.add_child(_match))   # or the game's own swap, behind the overlay
##       ld.warm(func(): return _match)                 # every new look drawn once behind it, a few a frame
##       if not await ld.run():                          # draws first, loads, builds; false if a file failed
##           return                                      # (the overlay has gone and the buttons are live again)
##       await ld.done()                                 # stays until the frames settle, then fades out
##       _match.kick_off()                               # the clock starts on a smooth first visible frame
##
## On the GL Compatibility renderer every new material's shader compiles on the main thread the first time it is drawn
## (Sepak Takraw: 5.5 to 12 s tap to first frame with no shader cache, all of it in the first draw). warm() draws the
## scene's looks a batch a frame from a camera that sees each batch, behind the opaque overlay, so the compiles spread
## over frames and the bar moves; done() then holds the overlay until settle_frames frames in a row come in under
## settle_ms (the first frames after a load: Floorball's 0.3 to 1 s), up to settle_cap seconds. prewarm() starts the
## likely next match's files loading while the menu is up; a later run() picks them up where they are. A boot screen
## can call warm_scene() on a venue, a player and the crowd to compile their shaders before the menu.
##
## A lambda cannot set the caller's local variables (GDScript copies them): keep what a step makes in a member, or
## in a Dictionary the lambdas share. The overlay sits on the host's viewport, not in the menu, so it stays up across
## a scene swap until done(). The spinner turns in its shader (TIME): it needs no script work to keep moving.
## ADOPTING.md §5.14.

## The overlay is up, drawn, and the loads are about to start (the test's proof that it shows before the work).
signal load_started
## Fraction 0..1 of the whole load, and the step under way.
signal progressed(fraction: float, label: String)
## done() has faded it out (it frees itself after).
signal finished

## Above everything a game draws (its own UI tops out well below).
const LAYER := 120
## A main-thread slice longer than this many ms is reported (the owner's A16 on Low: about what reads as frozen).
const STALL_MS := 250.0

## The look (all optional): dim, text, bar, bar_back, spinner (Color); title (String, "Loading…"); logo (Texture2D);
## tips (Array of String, one shown at a time); tip_seconds (float, 4); font (Font); font_size (int, the short side /
## 24); show_spinner (bool, true); show_percent (bool, false).
var look := {}
## Of the bar, the share the threaded load fills (the rest is the steps, by their weights).
var load_share := 0.5
## A checkpoint() yields once this many ms of main-thread work have run since the last frame.
var slice_ms := 50.0
## The load's own name in the log line (the game's: "match", "practice").
var log_label := "load"
## Threaded loads use the loader's sub-threads (faster on many cores; off by default, as Godot's own default).
var use_sub_threads := false
## done() holds the overlay until this many frames in a row come in under settle_ms (0: no wait) ...
var settle_frames := 3
var settle_ms := 50.0
## ... or this many seconds have gone.
var settle_cap := 3.0
## A load (and settle) shorter than this many ms closes at once, without the fade (a rematch).
var quick_ms := 300.0

## The latest run's measurements: total_ms, load_ms, longest_frame_ms, longest_slice_ms, longest_slice, steps
## ({label: ms of main-thread work}), frames, failed (paths that did not load), prewarmed (paths the menu had
## started), warm ({nodes, looks, frames, ms}), and from done(): settle_ms, settled, settle_longest_frame_ms.
## done() prints it as the WSG_LOADING line.
var report := {}

static var _current: WsgLoading = null
static var _pre := {}            # path -> true: requested by prewarm(), not yet taken by a run()

var _buttons: Array = []
var _paths: PackedStringArray = PackedStringArray()
var _steps: Array = []          # [label, callable, weight]
var _res := {}
var _target := 0.0
var _shown := 0.0
var _label := ""
var _running := false
var _covered_frame := 0
var _t_last_frame := 0
var _t_resume := 0
var _longest_frame := 0.0
var _longest_slice := 0.0
var _longest_slice_label := ""
var _step_ms := {}
var _frames := 0
var _tip_i := 0
var _tip_t := 0.0
var _ok := false
var _closing := false
var _warm := {}
var _has_warm := false
var _3d_off := false

var _root: Control
var _dim: ColorRect
var _box: VBoxContainer
var _logo: TextureRect
var _title: Label
var _row: HBoxContainer
var _spinner: ColorRect
var _bar_back: ColorRect
var _bar: ColorRect
var _tip: Label


## Puts the overlay up over HOST's screen now (this frame's draw shows it) and turns BUTTONS off. If a load is
## already under way it is returned as it is (a second tap starts nothing).
static func cover(host: Node, buttons: Array = [], p_look: Dictionary = {}) -> WsgLoading:
	if is_instance_valid(_current):
		return _current
	var ld := WsgLoading.new()
	ld.look = p_look
	ld._buttons = buttons
	for b in buttons:
		if b is BaseButton:
			(b as BaseButton).disabled = true
	host.get_viewport().add_child(ld)
	_current = ld
	return ld


## True while an overlay is up (a game's own guard against a second start).
static func busy() -> bool:
	return is_instance_valid(_current)


## The overlay that is up, or null (for code deep in a build that wants to checkpoint()).
static func current() -> WsgLoading:
	return _current if is_instance_valid(_current) else null


## Files to load on the loader's thread (scenes, meshes, textures: resources, never nodes made there).
func request(paths: Array) -> void:
	for p in paths:
		_paths.append(String(p))


## A piece of main-thread work, run in order after the files have loaded, a frame drawn after each. WEIGHT: its share
## of the steps' part of the bar. A step may be a coroutine (it may `await checkpoint()`).
func step(label: String, work: Callable, weight := 1.0) -> void:
	_steps.append([label, work, maxf(weight, 0.0)])


## While the menu is up: starts PATHS loading on the loader's thread (the likely next match: the last venue, the
## players, the crowd), so a tap finds them loaded or part way. A run() that requests them takes them where they are.
## The menu keeps its frame rate (the loading is on another thread); no shader is compiled by this (warm_scene, from
## a boot screen, does that).
static func prewarm(paths: Array) -> void:
	for p in paths:
		var path := String(p)
		if _pre.has(path) or ResourceLoader.has_cached(path):
			continue
		if ResourceLoader.load_threaded_request(path) == OK:
			_pre[path] = true


## A step that draws every look under a node once, behind the opaque overlay, a batch a frame (warm_scene). WHAT: the
## node, or a Callable that returns it (when an earlier step makes it). It must be in the tree by then.
## A run with a warm step draws no 3D from its first step until the warm-up (the viewport's disable_3d), so a scene
## swapped in by an earlier step is not drawn whole, every shader at once, before the warm-up can hide it.
func warm(what: Variant, label := "Warming up", weight := 2.0) -> void:
	_has_warm = true
	step(label, func():
		if skip_warm:
			_set_3d(true)
			return
		var node: Node = (what as Callable).call() if what is Callable else what
		# A deferred swap (change_scene_to_node) puts it in the tree a frame later.
		for i in 3:
			if node != null and node.is_inside_tree():
				break
			await _frame()
		if node == null or not node.is_inside_tree():
			push_warning("WsgLoading.warm: the node is not in the tree; nothing warmed")
			_set_3d(true)
			return
		opaque()
		_warm = await WsgLoading.warm_scene(node, func(f: float):
			_t_resume = Time.get_ticks_usec()
			_step_fraction(f), max_batch_looks, func(): _set_3d(true)), weight)


## Off a phone only: a check that counts what a start builds and draws, not how smoothly it plays, skips warm-ups
## (the world check's tiers rule: Kabaddi's twelve starts spent 10-24 s each warming up, drawn in software on CI).
static var skip_warm := false


## The most looks a warm-up batch draws in one frame.
var max_batch_looks := 64


func _set_3d(on: bool) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	if not on and not vp.disable_3d:
		vp.disable_3d = true
		_3d_off = true
	elif on and _3d_off:
		vp.disable_3d = false
		_3d_off = false


## The dim goes fully opaque (nothing behind it shows: a warm-up's camera, the first frames of the match).
func opaque() -> void:
	if _dim:
		_dim.color.a = 1.0


## A loaded file (after the load part of run(), so in any step).
func res(path: String) -> Resource:
	return _res.get(path)


## Draws first, then loads the requested files on the thread, then runs the steps. True if every file loaded and
## every step ran; on a failure the overlay goes and the buttons come back.
func run() -> bool:
	if _running:
		return false
	_running = true
	var t0 := Time.get_ticks_usec()
	# The overlay must be on screen before any heavy work: this frame's draw and the next.
	await get_tree().process_frame
	await get_tree().process_frame
	_t_last_frame = Time.get_ticks_usec()
	_longest_frame = 0.0
	load_started.emit()
	var failed := PackedStringArray()
	var prewarmed := []
	for p in _paths:
		if _pre.has(p):
			prewarmed.append(p)
	var t_load := Time.get_ticks_usec()
	_t_resume = t_load
	if not _paths.is_empty():
		_set_label("")
		for p in _paths:
			if _pre.has(p):
				continue           # the menu's prewarm() has it on the way
			if ResourceLoader.load_threaded_request(p, "", use_sub_threads) != OK:
				failed.append(p)
		var waiting := true
		while waiting:
			waiting = false
			var sum := 0.0
			for p in _paths:
				if failed.has(p) or _res.has(p):
					sum += 1.0
					continue
				var prog := []
				var st := ResourceLoader.load_threaded_get_status(p, prog)
				if st == ResourceLoader.THREAD_LOAD_LOADED:
					_res[p] = ResourceLoader.load_threaded_get(p)
					_pre.erase(p)
					sum += 1.0
				elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					sum += float(prog[0]) if not prog.is_empty() else 0.0
					waiting = true
				else:
					_pre.erase(p)
					failed.append(p)
					sum += 1.0
			_set_target(load_share * sum / float(_paths.size()))
			await _frame()
	var load_ms := (Time.get_ticks_usec() - t_load) / 1000.0
	var ok := failed.is_empty()
	if ok:
		var total_w := 0.0
		for s in _steps:
			total_w += float(s[2])
		var base := load_share if not _paths.is_empty() else 0.0
		var done_w := 0.0
		if _has_warm:
			_set_3d(false)
		for s in _steps:
			_set_label(String(s[0]))
			_t_resume = Time.get_ticks_usec()
			await (s[1] as Callable).call()
			done_w += float(s[2])
			_set_target(base + (1.0 - base) * (done_w / total_w if total_w > 0.0 else 1.0))
			await _frame()
	_set_3d(true)
	# The bar's last bit is the settle (done()).
	_set_target((1.0 if settle_frames <= 0 else 0.96) if ok else _target)
	_ok = ok
	report = {
		"label": log_label,
		"total_ms": snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1),
		"load_ms": snappedf(load_ms, 0.1),
		"longest_frame_ms": snappedf(_longest_frame, 0.1),
		"longest_slice_ms": snappedf(_longest_slice, 0.1),
		"longest_slice": _longest_slice_label,
		"steps": _step_ms.duplicate(),
		"frames": _frames,
		"failed": Array(failed),
		"prewarmed": prewarmed,
		"warm": _warm,
	}
	if _longest_slice > STALL_MS:
		push_warning("WsgLoading: '%s' held the main thread %.0f ms (over %.0f): cut it with checkpoint()" % [_longest_slice_label, _longest_slice, STALL_MS])
	_running = false
	if not ok:
		push_error("WsgLoading: could not load %s" % ", ".join(failed))
		done()
	return ok


## In a long step, between chunks of work: yields a frame (the bar and spinner drawn) once slice_ms of main-thread
## work have run since the last one; else returns at once. Always `await` it. FRACTION (0..1 within the step, optional)
## moves the bar inside the step's share.
func checkpoint(fraction := -1.0) -> void:
	if fraction >= 0.0 and _running:
		_step_fraction(fraction)
	if (Time.get_ticks_usec() - _t_resume) / 1000.0 >= slice_ms:
		await _frame()


## After a run that loaded: holds the overlay (opaque, the bar at its last step) until settle_frames frames in a row
## come in under settle_ms, or settle_cap seconds; prints the WSG_LOADING line; then fades out (at once if the whole
## load was under quick_ms) and frees it. The buttons that are still there come back on. Await it to start play on a
## smooth first frame (or wait for `finished`).
func done() -> void:
	if _closing:
		return
	_closing = true
	var settle := 0.0
	var settled := true
	var worst := 0.0
	if _ok and settle_frames > 0:
		opaque()
		var t0 := Time.get_ticks_usec()
		var prev := t0
		var good := 0
		var steady := INF
		var recent := []
		while good < settle_frames:
			if (Time.get_ticks_usec() - t0) / 1e6 > settle_cap:
				settled = false
				break
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			var gap := (now - prev) / 1000.0
			prev = now
			worst = maxf(worst, gap)
			# Under settle_ms; or, on a phone slower than that all the time, within 30% of its quickest frame here, up
			# to twice settle_ms (compile stalls are hundreds of ms: they never pass).
			steady = minf(steady, gap)
			good = good + 1 if gap < clampf(steady * 1.3, settle_ms, settle_ms * 2.0) else 0
			# Or slow but even: the last STABLE_FRAMES all within 20% of their middle one (a device that is simply
			# this slow - Netball's software renderer at 250-450 ms a frame - not one still compiling: compile stalls
			# come and go).
			recent.append(gap)
			if recent.size() > STABLE_FRAMES:
				recent.pop_front()
			if recent.size() == STABLE_FRAMES and _even(recent):
				break
		settle = (Time.get_ticks_usec() - t0) / 1000.0
		_set_target(1.0)
	if not report.is_empty():
		report["settle_ms"] = snappedf(settle, 0.1)
		report["settled"] = settled
		report["settle_longest_frame_ms"] = snappedf(worst, 0.1)
		print("WSG_LOADING ", JSON.stringify(report))
	if _current == self:
		_current = null
	for b in _buttons:
		if is_instance_valid(b) and b is BaseButton:
			(b as BaseButton).disabled = false
	if float(report.get("total_ms", 0.0)) + settle < quick_ms:
		visible = false
		await get_tree().process_frame
		finished.emit()
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		finished.emit()
		queue_free())


## done(): this many frames in a row within 20% of each other count as settled, however slow.
const STABLE_FRAMES := 6


static func _even(gaps: Array) -> bool:
	var s := gaps.duplicate()
	s.sort()
	var mid: float = s[s.size() / 2]
	return float(s[0]) >= mid * 0.8 and float(s[-1]) <= mid * 1.2


## The overlay's own parts, for a game that wants to restyle further (the dim, the title, the bar, the tip).
func parts() -> Dictionary:
	return {"root": _root, "dim": _dim, "logo": _logo, "title": _title, "spinner": _spinner, "bar_back": _bar_back,
		"bar": _bar, "tip": _tip}


## The bar as shown (0..1).
func shown() -> float:
	return _shown


# ---------------------------------------------------------------- inside

func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_covered_frame = Engine.get_process_frames()
	_t_last_frame = Time.get_ticks_usec()
	var text: Color = look.get("text", Color(1, 1, 1, 0.95))
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP     # the menu under it takes no taps
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = look.get("dim", Color(0.03, 0.04, 0.06, 0.9))
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_box)
	_logo = TextureRect.new()
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.texture = look.get("logo")
	_logo.visible = _logo.texture != null
	_box.add_child(_logo)
	_row = HBoxContainer.new()
	var row := _row
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	_spinner = ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = _spinner_shader()
	mat.set_shader_parameter("color", look.get("spinner", look.get("bar", Color(1, 1, 1, 0.9))))
	_spinner.material = mat
	_spinner.visible = bool(look.get("show_spinner", true))
	_spinner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_spinner)
	_title = Label.new()
	_title.text = String(look.get("title", "Loading…"))
	_title.add_theme_color_override("font_color", text)
	if look.get("font") is Font:
		_title.add_theme_font_override("font", look.font)
	row.add_child(_title)
	_bar_back = ColorRect.new()
	_bar_back.color = look.get("bar_back", Color(1, 1, 1, 0.18))
	_bar_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_box.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = look.get("bar", Color(1, 1, 1, 0.9))
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.add_child(_bar)
	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.add_theme_color_override("font_color", Color(text, text.a * 0.75))
	if look.get("font") is Font:
		_tip.add_theme_font_override("font", look.font)
	var tips: Array = look.get("tips", [])
	_tip.visible = not tips.is_empty()
	if not tips.is_empty():
		_tip_i = randi() % tips.size()
		_tip.text = String(tips[_tip_i])
	_box.add_child(_tip)
	get_viewport().size_changed.connect(_fit)
	_fit()


## Sizes to the screen, portrait or landscape: everything from its short side.
func _fit() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := minf(vp.x, vp.y)
	var fs := int(look.get("font_size", maxi(14, int(s / 24.0))))
	_title.add_theme_font_size_override("font_size", fs)
	_tip.add_theme_font_size_override("font_size", maxi(12, int(fs * 0.72)))
	_spinner.custom_minimum_size = Vector2(fs, fs) * 1.1
	_box.add_theme_constant_override("separation", int(fs * 0.8))
	_row.add_theme_constant_override("separation", int(fs * 0.5))
	_logo.custom_minimum_size = Vector2(s * 0.5, s * 0.22)
	var w := minf(vp.x * 0.7, s * 0.9)
	_bar_back.custom_minimum_size = Vector2(w, maxf(4.0, fs * 0.3))
	_tip.custom_minimum_size = Vector2(minf(vp.x * 0.85, s * 1.2), 0)
	_draw_bar()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _running:
		_longest_frame = maxf(_longest_frame, (now - _t_last_frame) / 1000.0)
		_frames += 1
	_t_last_frame = now
	# The bar eases toward the work done (never back); the spinner turns in its shader.
	_shown = minf(_target, _shown + maxf(_target - _shown, 0.0) * minf(1.0, delta * 12.0) + delta * 0.05)
	_draw_bar()
	var tips: Array = look.get("tips", [])
	if tips.size() > 1:
		_tip_t += delta
		if _tip_t >= float(look.get("tip_seconds", 4.0)):
			_tip_t = 0.0
			_tip_i = (_tip_i + 1) % tips.size()
			_tip.text = String(tips[_tip_i])


func _draw_bar() -> void:
	if _bar == null:
		return
	_bar.size = Vector2(_bar_back.custom_minimum_size.x * clampf(_shown, 0.0, 1.0), _bar_back.custom_minimum_size.y)
	if bool(look.get("show_percent", false)):
		_title.text = "%s %d%%" % [String(look.get("title", "Loading…")), roundi(_shown * 100.0)]


## Ends a main-thread slice: times it, then waits for the next frame.
func _frame() -> void:
	var ms := (Time.get_ticks_usec() - _t_resume) / 1000.0
	var key := _label if _label != "" else "(loading files)"
	_step_ms[key] = snappedf(float(_step_ms.get(key, 0.0)) + ms, 0.1)
	if ms > _longest_slice:
		_longest_slice = ms
		_longest_slice_label = key
	await get_tree().process_frame
	_t_resume = Time.get_ticks_usec()


func _set_label(l: String) -> void:
	_label = l
	progressed.emit(_target, _label)


func _set_target(f: float) -> void:
	_target = maxf(_target, clampf(f, 0.0, 1.0))
	progressed.emit(_target, _label)


## Within the step under way, FRACTION of its share.
func _step_fraction(fraction: float) -> void:
	var total_w := 0.0
	var before := 0.0
	var mine := 0.0
	var found := false
	for s in _steps:
		total_w += float(s[2])
		if String(s[0]) == _label and not found:
			mine = float(s[2])
			found = true
		elif not found:
			before += float(s[2])
	if not found or total_w <= 0.0:
		return
	var base := load_share if not _paths.is_empty() else 0.0
	_set_target(base + (1.0 - base) * (before + mine * clampf(fraction, 0.0, 1.0)) / total_w)


## Draws every look under ROOT (each mesh and its materials, by kind: mesh, multimesh, particles) once, a batch a
## frame, from a camera of its own aimed at the batch, everything else hidden (render layers 0) and visibility ranges
## off, so on the GL Compatibility renderer each new shader compiles in a frame of its own (or a few together) instead
## of all in the match's first frame. Batches double after three quick frames in a row (under 40 ms, or 1.5 times the
## quickest frame so far) and drop to one look after a slow one. HIDDEN is called once everything is hidden. Puts every layer, range and the game's camera back. AFTER_FRAME(fraction 0..1) is called after each frame.
## Returns {nodes, looks, frames, ms}. Behind an opaque overlay (WsgLoading.warm does this), or from a boot screen.
static func warm_scene(root: Node, after_frame: Callable = Callable(), max_batch := 64, hidden: Callable = Callable()) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var vp := root.get_viewport()
	var game_cam := vp.get_camera_3d()
	var mask: int = game_cam.cull_mask if game_cam else 0xFFFFF
	var geoms: Array = []
	var all: Array = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		all.append(root)
	for n in all:
		var g := n as GeometryInstance3D
		if g.is_visible_in_tree() and (g.layers & mask) != 0:
			geoms.append(g)
	var groups := {}
	for g in geoms:
		var k := _look_key(g)
		if not groups.has(k):
			groups[k] = []
		(groups[k] as Array).append(g)
	var saved := {}
	for g in geoms:
		saved[g] = [g.layers, g.visibility_range_begin, g.visibility_range_end]
		g.layers = 0
		g.visibility_range_begin = 0.0
		g.visibility_range_end = 0.0
	if hidden.is_valid():
		hidden.call()
	var cam := Camera3D.new()
	cam.top_level = true
	cam.cull_mask = mask
	if game_cam:
		cam.fov = game_cam.fov
		cam.environment = game_cam.environment
		cam.attributes = game_cam.attributes
	root.add_child(cam)
	cam.make_current()
	var keys := groups.keys()
	var i := 0
	var n := 1
	var frames := 0
	var quickest := INF
	var quick_run := 0
	while i < keys.size():
		var box := AABB()
		var first := true
		for k in keys.slice(i, i + n):
			# (Untyped: a node the game frees during the warm-up is skipped, not an error - Hurling 0.23.)
			for g in groups[k]:
				if not is_instance_valid(g) or not (g as GeometryInstance3D).is_inside_tree():
					continue
				var gi := g as GeometryInstance3D
				gi.layers = int(saved[g][0])
				var b: AABB = gi.global_transform * gi.get_aabb()
				box = b if first else box.merge(b)
				first = false
		i = mini(i + n, keys.size())
		if not first:
			_aim(cam, box)
		var tf := Time.get_ticks_usec()
		await root.get_tree().process_frame
		frames += 1
		# After three frames in a row with no new shader (about the phone's own frame time), twice as many a frame (the
		# looks are shared or cached); after a compile, one (two compiles in one frame make a frame twice as long).
		var ms := (Time.get_ticks_usec() - tf) / 1000.0
		quickest = minf(quickest, ms)
		quick_run = quick_run + 1 if ms < maxf(40.0, quickest * 1.5) else 0
		if quick_run == 0:
			n = 1
		elif quick_run >= 3:
			n = mini(n * 2, max_batch)
		if after_frame.is_valid():
			after_frame.call(float(i) / float(keys.size()))
	for g in saved:
		if is_instance_valid(g):
			(g as GeometryInstance3D).layers = int(saved[g][0])
			(g as GeometryInstance3D).visibility_range_begin = float(saved[g][1])
			(g as GeometryInstance3D).visibility_range_end = float(saved[g][2])
	cam.queue_free()
	if is_instance_valid(game_cam):
		game_cam.make_current()
	return {"nodes": geoms.size(), "looks": keys.size(), "frames": frames,
		"ms": snappedf((Time.get_ticks_usec() - t0) / 1000.0, 0.1)}


## What makes a node's draw need its own shaders: its kind, its mesh and every material on it.
static func _look_key(g: GeometryInstance3D) -> String:
	var k := g.get_class()
	var mesh: Mesh = null
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		mesh = mi.mesh
		for si in mi.get_surface_override_material_count():
			k += ",s%d" % _id(mi.get_surface_override_material(si))
	elif g is MultiMeshInstance3D:
		var mm := (g as MultiMeshInstance3D).multimesh
		mesh = mm.mesh if mm else null
	elif g is GPUParticles3D:
		var gp := g as GPUParticles3D
		mesh = gp.draw_pass_1
		k += ",p%d" % _id(gp.process_material)
	elif g is CPUParticles3D:
		mesh = (g as CPUParticles3D).mesh
	k += ",m%d,o%d,v%d" % [_id(mesh), _id(g.material_override), _id(g.material_overlay)]
	if mesh:
		for si in mesh.get_surface_count():
			k += ",%d" % _id(mesh.surface_get_material(si))
	return k


static func _id(o: Object) -> int:
	return o.get_instance_id() if o else 0


## The camera back from BOX along a fixed diagonal, far enough to see all of it.
static func _aim(cam: Camera3D, box: AABB) -> void:
	var c := box.get_center()
	var r := maxf(box.size.length() * 0.5, 0.25)
	var dist := r / sin(deg_to_rad(cam.fov * 0.5)) * 1.1
	var dir := Vector3(0.35, 0.45, 1.0).normalized()
	cam.near = maxf(0.02, (dist - r) * 0.5)
	cam.far = dist + r * 2.0 + 10.0
	cam.global_transform = Transform3D(Basis.IDENTITY, c + dir * dist).looking_at(c, Vector3.UP)


static var _shader: Shader = null

static func _spinner_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """shader_type canvas_item;
// A ring with a fading tail, turned by TIME: it keeps turning with no script work.
uniform vec4 color : source_color = vec4(1.0);
uniform float thickness = 0.2;
uniform float turns_per_second = 1.1;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = fract(atan(p.y, p.x) / 6.2831853 + TIME * turns_per_second);
	float ring = (1.0 - smoothstep(0.92, 1.0, r)) * smoothstep(0.92 - thickness, 1.0 - thickness, r);
	COLOR = vec4(color.rgb, color.a * ring * smoothstep(0.0, 0.85, a));
}
"""
	return _shader
