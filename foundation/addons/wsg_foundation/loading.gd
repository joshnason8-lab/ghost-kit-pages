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
##       if not await ld.run():                          # draws first, loads, builds; false if a file failed
##           return                                      # (the overlay has gone and the buttons are live again)
##       get_tree().root.add_child(_match)               # or the game's own swap
##       ld.done()                                       # fades out
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

## The latest run's measurements: total_ms, load_ms, longest_frame_ms, longest_slice_ms, longest_slice, steps
## ({label: ms of main-thread work}), frames, failed (paths that did not load).
var report := {}

static var _current: WsgLoading = null

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
	var t_load := Time.get_ticks_usec()
	_t_resume = t_load
	if not _paths.is_empty():
		_set_label("")
		for p in _paths:
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
					sum += 1.0
				elif st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					sum += float(prog[0]) if not prog.is_empty() else 0.0
					waiting = true
				else:
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
		for s in _steps:
			_set_label(String(s[0]))
			_t_resume = Time.get_ticks_usec()
			await (s[1] as Callable).call()
			done_w += float(s[2])
			_set_target(base + (1.0 - base) * (done_w / total_w if total_w > 0.0 else 1.0))
			await _frame()
	_set_target(1.0 if ok else _target)
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
	}
	print("WSG_LOADING ", JSON.stringify(report))
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


## Fades the overlay out and frees it; the buttons that are still there come back on.
func done() -> void:
	if _current == self:
		_current = null
	for b in _buttons:
		if is_instance_valid(b) and b is BaseButton:
			(b as BaseButton).disabled = false
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		finished.emit()
		queue_free())


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
