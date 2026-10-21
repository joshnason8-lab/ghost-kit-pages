class_name DragScroll
extends ScrollContainer
## A scroll box for a thumb: drag anywhere on it, on its cards and buttons too, and fling it. (Godot's own only drags
## from the box's bare background: cards and buttons take the touch first, so on a page of cards it hardly scrolls.)
## A press that turns into a drag is taken back from the button it began on, so scrolling never taps anything.

const SLOP := 10.0          # px a finger moves before a press becomes a drag
const FRICTION := 5.0       # how quickly a fling slows (per second)
const WHEEL_STEP := 70.0

var _down := false
var _dragging := false
var _from := Vector2.ZERO
var _last_y := 0.0
var _last_us := 0
var _vel := 0.0             # the scroll's speed in its own px per second, for the fling
var _pos := 0.0
var _quiet := false         # while the cancelling release goes to the button


func _ready() -> void:
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	scroll_deadzone = 100000   # its own touch drag off: this one does it, from anywhere on it


func _max() -> float:
	var bar := get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


func _k() -> float:
	return maxf(0.01, get_global_transform().get_scale().y)


func _set_pos(p: float) -> void:
	_pos = clampf(p, 0.0, _max())
	get_v_scroll_bar().value = _pos


## Is the point on this box, with nothing drawn over it there (a dialog, the language picker)?
func _hits(at: Vector2) -> bool:
	if not is_visible_in_tree() or not get_global_rect().has_point(at):
		return false
	var over := get_viewport().gui_get_hovered_control()
	# Words and pictures in the box take no touch (mouse_filter IGNORE): under them the hovered control can be the
	# page behind the box, which is fine; a dialog drawn over the box is not.
	return over == null or over == self or is_ancestor_of(over) or over.is_ancestor_of(self)


func _input(event: InputEvent) -> void:
	if _quiet:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed and _max() > 0.0 and _hits(mb.position):
				_vel = 0.0
				_set_pos(get_v_scroll_bar().value + WHEEL_STEP * mb.factor * (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0))
				get_viewport().set_input_as_handled()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = get_global_rect().has_point(mb.position) and is_visible_in_tree()
			_dragging = false
			_from = mb.position
			_last_y = mb.position.y
			_last_us = Time.get_ticks_usec()
			if _down:
				_vel = 0.0   # a touch stops a fling
				_pos = get_v_scroll_bar().value
		else:
			if _dragging:
				get_viewport().set_input_as_handled()
				var idle := float(Time.get_ticks_usec() - _last_us) / 1e6
				if idle > 0.08:
					_vel = 0.0   # the finger stopped before it let go: no fling
			_down = false
			_dragging = false
	elif event is InputEventMouseMotion and _down:
		var mm := event as InputEventMouseMotion
		if not _dragging:
			if absf(mm.position.y - _from.y) < SLOP or _max() <= 0.0:
				return
			if not _hits(_from):
				_down = false
				return
			_dragging = true
			_cancel_press()
			_last_y = mm.position.y
			_last_us = Time.get_ticks_usec()
		var dy := (mm.position.y - _last_y) / _k()
		var now_us := Time.get_ticks_usec()
		var dt := maxf(0.004, float(now_us - _last_us) / 1e6)
		_set_pos(_pos - dy)
		_vel = lerpf(_vel, -dy / dt, 0.5)
		_last_y = mm.position.y
		_last_us = now_us
		get_viewport().set_input_as_handled()


## The press under the finger is let go somewhere off the screen, so the button it began on does not fire.
func _cancel_press() -> void:
	_quiet = true
	var away := Vector2(-100000, -100000)
	var mm := InputEventMouseMotion.new()
	mm.position = away
	mm.global_position = away
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(mm, true)
	var up := InputEventMouseButton.new()
	up.position = away
	up.global_position = away
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	get_viewport().push_input(up, true)
	_quiet = false


func _process(delta: float) -> void:
	if _dragging or absf(_vel) < 15.0:
		return
	var before := _pos
	_set_pos(_pos + _vel * delta)
	_vel *= exp(-FRICTION * delta)
	if is_equal_approx(before, _pos):
		_vel = 0.0   # at the end
