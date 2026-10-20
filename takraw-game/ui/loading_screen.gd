extends CanvasLayer
## The first screen: the game's name and a bar that fills as the game gets ready (the sounds made, the crowd's figures
## and the ball drawn, the players' looks built, the home screen and the match behind it set up and drawn), a piece at
## a time so the bar moves. It fades off the home screen once that runs smoothly. main.gd starts it.

const SLICE_MS := 30
const SMOOTH_MS := 70.0
const SMOOTH_FRAMES := 3
const WARM_MAX := 6.0
const FADE := 0.35
const SHARE := [["sounds", 0.3], ["art", 0.12], ["menu", 0.18], ["warm", 0.4]]

var times := {}
var _bar: ProgressBar
var _root: Control
var _slice_start := 0


func _ready() -> void:
	layer = 100
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.theme = Game.theme
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Game.C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icon/icon_192.png") if ResourceLoader.exists("res://assets/icon/icon_192.png") else null
	icon.custom_minimum_size = Vector2(120, 120)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	var title := UI.label(tr("GAME_TITLE"), "TitleLabel", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.custom_minimum_size = Vector2(420, 14)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_bar)
	var note := UI.label(tr("LOADING"), "MutedLabel", 20)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(note)


func run() -> void:
	Game.loading = true
	await get_tree().process_frame
	_slice_start = Time.get_ticks_msec()
	var done := 0.0
	var t0 := Time.get_ticks_msec()
	while Sfx.build_step():
		await _progress(done + _share("sounds") * Sfx.progress())
	done += _share("sounds")
	t0 = _took("sounds", t0)
	Crowd.sheet()
	Ball.texture()
	Arena._net_texture()
	ToonBody.material(int(Game.settings.graphics) > Game.GFX_LOW)
	done += _share("art")
	await _progress(done, true)
	t0 = _took("art", t0)
	Game.goto_menu()
	done += _share("menu")
	await _progress(done, true)
	t0 = _took("menu", t0)
	var warm := 0.0
	var smooth := 0
	var last := Time.get_ticks_usec()
	while smooth < SMOOTH_FRAMES and warm < WARM_MAX:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := float(now - last) / 1000.0
		last = now
		warm += ms / 1000.0
		smooth = smooth + 1 if ms <= SMOOTH_MS else 0
		_bar.value = done + _share("warm") * clampf(maxf(warm / WARM_MAX, float(smooth) / SMOOTH_FRAMES), 0.0, 1.0)
	_took("warm", t0)
	_bar.value = 1.0
	print("Loaded (ms): %s" % times)
	Game.loading = false
	Game.loaded.emit()
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE)
	await tw.finished
	queue_free()


func _share(part: String) -> float:
	for s in SHARE:
		if s[0] == part:
			return float(s[1])
	return 0.0


func _progress(p: float, now := false) -> void:
	_bar.value = p
	if now or Time.get_ticks_msec() - _slice_start >= SLICE_MS:
		await get_tree().process_frame
		_slice_start = Time.get_ticks_msec()


func _took(part: String, since: int) -> int:
	var t := Time.get_ticks_msec()
	times[part] = t - since
	return t
