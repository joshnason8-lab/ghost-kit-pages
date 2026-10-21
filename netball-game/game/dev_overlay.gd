class_name DevOverlay
extends CanvasLayer
## A developer's overlay for measuring a match on a phone, off unless Game.settings.dev is on (tap the version on the
## home screen seven times; the same again turns it off). It shows frame times over the last five seconds (median,
## 95th and 99th percentile, worst) with a graph of the last three, hitches (frames well over the usual) and what was
## happening at each, the graphics level and any change to it, draw calls, and the player you control: her speed as
## the camera sees it, what she is doing, and the last calls.
## Copy puts a summary of the match so far on the clipboard, to paste into a report. It reads the match and never
## changes it.

const WINDOW := 5.0        # s of frames the figures cover
const GRAPH := 180         # frames in the graph
const HITCH_TIMES := 2.0   # a hitch: a frame this many times the median ...
const HITCH_OVER := 8.0    # ... and at least this many ms over it
const CONTACT := ["call", "gain", "goal", "miss", "deflection", "advantage"]
const GFX_NAMES := ["Low", "Medium", "High"]

var m   # the Match
var _times := PackedFloat32Array()   # ms, the frames of the last WINDOW s ...
var _at := PackedFloat32Array()      # ... and when each was (s since the overlay began)
var _all := PackedFloat32Array()     # ms, every frame (the summary)
var _hitches := []                   # [s, ms, what was happening]
var _events := []                    # [s, kind]: contact events
var _gfx := []                       # [s, level]: the graphics level at the start and each change
var _t := 0.0
var _med := 0.0                      # ms, the median of the last WINDOW s (refreshed with the readout)
var _show_t := 0.0
var _who: Node3D = null              # the player whose speed is measured, and where he was last frame
var _who_pos := Vector3.ZERO
var _speed := 0.0
var _speed_jump := 0.0               # the largest change in his measured speed from one frame to the next (m/s), lately
var _panel: PanelContainer
var _text: Label
var _graph: Control
var _copy: Button


func _init(p_match) -> void:
	m = p_match
	layer = 90


func _ready() -> void:
	m.game_event.connect(_on_event)
	_gfx.append([0.0, int(Game.settings.graphics)])
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.62)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(12, 96)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(GRAPH * 2, 56)
	_graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.draw.connect(_draw_graph)
	col.add_child(_graph)
	_copy = Button.new()
	_copy.text = "Copy summary"
	_copy.add_theme_font_size_override("font_size", 14)
	_copy.focus_mode = Control.FOCUS_NONE
	_copy.pressed.connect(func():
		DisplayServer.clipboard_set(summary())
		_copy.text = "Copied"
		get_tree().create_timer(1.5).timeout.connect(func(): _copy.text = "Copy summary"))
	col.add_child(_copy)


func _process(delta: float) -> void:
	_t += delta
	var ms := delta * 1000.0
	# A hitch against the frames before it.
	if _med > 0.0:
		if ms > _med * HITCH_TIMES and ms > _med + HITCH_OVER:
			_hitches.append([_t, ms, _context()])
			if _hitches.size() > 200:
				_hitches.pop_front()
	_times.append(ms)
	_at.append(_t)
	_all.append(ms)
	while _at.size() > 0 and _at[0] < _t - WINDOW:
		_times.remove_at(0)
		_at.remove_at(0)
	if int(Game.settings.graphics) != int(_gfx[-1][1]):
		_gfx.append([_t, int(Game.settings.graphics)])
	_measure_player(delta)
	_show_t -= delta
	if _show_t <= 0.0:
		_show_t = 0.25
		if _times.size() >= 30:
			_med = _percentile(_times, 0.5)
		_text.text = _readout()
		_graph.queue_redraw()


## Who you control (or who has the ball): how fast the camera sees her go, and the largest jump in that
## lately (a jerk in her movement shows up as one, however smooth the frame rate).
func _measure_player(delta: float) -> void:
	var a = _player()
	if a != _who:
		_who = a
		_speed = 0.0
		if a:
			_who_pos = a.global_position
		return
	if a == null or delta <= 0.0:
		return
	var p: Vector3 = a.global_position
	var s := Vector2(p.x - _who_pos.x, p.z - _who_pos.z).length() / delta
	_who_pos = p
	_speed_jump = maxf(absf(s - _speed), _speed_jump * pow(0.5, delta / 0.5))
	_speed = s


func _player():
	if m.me:
		return m.me
	return m.holder


func _on_event(kind: String, _info: Dictionary) -> void:
	if kind in CONTACT:
		_events.append([_t, kind])
		if _events.size() > 8:
			_events.pop_front()


## What was happening at a frame: the match's phase, your player's state and the latest contact event, if recent.
func _context() -> String:
	var bits := [String(m.phase)]
	var a = _player()
	if a:
		bits.append("%s %s" % [a.pos, a.act])
	if not _events.is_empty() and _t - float(_events[-1][0]) < 0.3:
		bits.append("after " + String(_events[-1][1]))
	return ", ".join(bits)


func _readout() -> String:
	var lines := []
	if _times.size() > 0:
		lines.append("frame %.1f ms  med %.1f  p95 %.1f  p99 %.1f  worst %.1f" % [_times[-1], _percentile(_times, 0.5),
			_percentile(_times, 0.95), _percentile(_times, 0.99), _percentile(_times, 1.0)])
	var recent := 0
	for h in _hitches:
		if float(h[0]) > _t - 60.0:
			recent += 1
	lines.append("fps %d  hitches %d in the last min (%d in all)  cpu %.1f ms" % [Engine.get_frames_per_second(), recent,
		_hitches.size(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	var changes := ""
	for i in range(1, _gfx.size()):
		changes += "  -> %s at %s" % [GFX_NAMES[int(_gfx[i][1])], _clock(float(_gfx[i][0]))]
	lines.append("graphics %s%s%s  draws %d  objects %d  tris %dk" % [GFX_NAMES[int(_gfx[0][1])], changes,
		" (auto)" if bool(Game.settings.get("auto_gfx", true)) else "",
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
	var a = _player()
	if a:
		lines.append("%s %s: %.2f m/s (jump %.2f)  %s %.2fs  writes/frame %d" % [a.pos, a.surname(), _speed, _speed_jump, a.act, a.act_t, a.moves])
	var ev := []
	for e in _events.slice(-4):
		ev.append("%s %s" % [_clock(float(e[0])), e[1]])
	lines.append("events: " + (", ".join(ev) if not ev.is_empty() else "-"))
	if not _hitches.is_empty():
		var h: Array = _hitches[-1]
		lines.append("last hitch %.0f ms at %s: %s" % [h[1], _clock(float(h[0])), h[2]])
	return "\n".join(lines)


## The match so far, for a report: the phone, the screen, the graphics, frame times over every frame, and the worst
## frames with what was happening at each.
func summary() -> String:
	var out := []
	out.append("Centre Pass Netball %s, developer overlay" % String(ProjectSettings.get_setting("application/config/version", "")))
	out.append("Device: %s, %s %s, GPU %s (%s)" % [OS.get_model_name(), OS.get_name(), OS.get_version(),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	out.append("Screen %s at %.0f Hz, window %s, graphics %s%s" % [str(DisplayServer.screen_get_size()),
		DisplayServer.screen_get_refresh_rate(), str(m.get_viewport().get_visible_rect().size),
		GFX_NAMES[int(_gfx[0][1])], " (auto)" if bool(Game.settings.get("auto_gfx", true)) else ""])
	# A screen at 90 or 120 Hz shows a frame that missed its slot for 1.5 or 2 slots of 60 Hz: the frame times say
	# whether the game keeps the screen's own rate, half of it, or neither (the uneven case is the one that judders).
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz > 0.0:
		out.append("One screen refresh: %.1f ms" % (1000.0 / hz))
	var cap := Game.frame_cap()
	out.append("Frame rate: %s" % (("capped at %d a second" % cap) if cap > 0 else "the screen's own") +
		(" (battery saver)" if int(Game.settings.get("fps", Game.FPS_SMOOTH)) == Game.FPS_SAVER else ""))
	for i in range(1, _gfx.size()):
		out.append("Graphics changed to %s at %s" % [GFX_NAMES[int(_gfx[i][1])], _clock(float(_gfx[i][0]))])
	if _all.size() > 0:
		out.append("%d frames over %s: median %.1f ms, p95 %.1f, p99 %.1f, worst %.1f; %d hitches (%.1f a minute)" % [
			_all.size(), _clock(_t), _percentile(_all, 0.5), _percentile(_all, 0.95), _percentile(_all, 0.99),
			_percentile(_all, 1.0), _hitches.size(), _hitches.size() / maxf(_t / 60.0, 0.001)])
	var worst := _hitches.duplicate()
	worst.sort_custom(func(x, y): return float(x[1]) > float(y[1]))
	for h in worst.slice(0, 8):
		out.append("  %.0f ms at %s: %s" % [h[1], _clock(float(h[0])), h[2]])
	return "\n".join(out)


func _draw_graph() -> void:
	var h := _graph.size.y
	var k := h / 50.0   # px a ms: 50 ms to the top
	for ms in [16.7, 33.3]:
		_graph.draw_line(Vector2(0, h - ms * k), Vector2(_graph.size.x, h - ms * k), Color(1, 1, 1, 0.25), 1.0)
	var n := mini(_times.size(), GRAPH)
	var med := _percentile(_times, 0.5) if n > 0 else 0.0
	for i in n:
		var ms: float = _times[_times.size() - n + i]
		var c := Color(0.4, 0.9, 0.4) if ms < med * 1.5 else (Color(1.0, 0.8, 0.2) if ms < med * HITCH_TIMES else Color(1.0, 0.3, 0.3))
		var x := (GRAPH - n + i) * 2.0
		_graph.draw_rect(Rect2(x, h - minf(ms, 50.0) * k, 1.5, minf(ms, 50.0) * k), c)


static func _percentile(v: PackedFloat32Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return s[clampi(int(round(q * (s.size() - 1))), 0, s.size() - 1)]


static func _clock(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]
