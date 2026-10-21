class_name TouchControls
extends Control
## The match controls for a phone held sideways. Left thumb: a joystick wherever it lands on the left of the screen.
## Right thumb: three buttons that change with the play: SHOOT, PASS and SPRINT with the ball, TACKLE, SWITCH and
## SPRINT without it, the first the biggest. Several fingers at once; SPRINT is held. Left-handed (Settings) swaps
## the sides; Button size makes them Normal, Large or Extra large; Move buttons (Settings and the pause menu) lets you
## drag each one where your thumb wants it, kept in Game.settings.btn_places. Keys too: WASD or arrows, Space, J, K.

signal action(id: String)
signal moved

const JOY_R := 92.0
const KEYS := [KEY_SPACE, KEY_J, KEY_K]
const STICK_SIDE := 0.45          # the share of the screen's width where a touch is the joystick

var joystick := Vector2.ZERO
var ids: Array = []
var editing := false              # moving the buttons: a touch picks one up and drags it, nothing is pressed
var _joy_touch := -1
var _joy_base := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _flash := {}
var _pulse := 0.0
var _keys := {}
var _paras := {}
var _held := {}                   # button index -> touch index holding it
var _key_held := {}
var _drag := -1
var _drag_touch := -1
var _drag_at := Vector2.ZERO
var _drag_off := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func size_k() -> float:
	return [1.0, 1.22, 1.45][clampi(int(Game.settings.btn_size), 0, 2)]


func _left_handed() -> bool:
	return bool(Game.settings.left_handed)


func set_buttons(p_ids: Array) -> void:
	if p_ids == ids:
		return
	ids = p_ids.duplicate()
	_paras.clear()
	queue_redraw()


func flash(id: String) -> void:
	_flash[id] = 0.25
	queue_redraw()


func held(id: String) -> bool:
	var i := ids.find(id)
	if i < 0:
		return false
	return _held.has(i) or _key_held.get(i, false)


## The buttons' own places at this size: the first big in the corner, the others round it (right-handed; mirrored).
func default_places() -> Array:
	var s := size
	var k := size_k()
	var m := UI.safe_margins(self, 30.0)
	var corner := Vector2(s.x - m.z - 104.0 * k, s.y - m.w - 110.0 * k)
	return [corner, corner + Vector2(-186, 8) * k, corner + Vector2(-58, -184) * k]


func radii() -> Array:
	var k := size_k()
	return [86.0 * k, 64.0 * k, 58.0 * k]


## Where each button is now: [id, centre, radius]. Saved places are fractions of the screen; a dragged one is where
## the finger has it.
func _layout() -> Array:
	var places := default_places()
	var saved: Array = Game.settings.get("btn_places", [])
	var out := []
	var r := radii()
	for i in 3:
		var c: Vector2 = places[i]
		if saved.size() == 3 and saved[i] is Array and (saved[i] as Array).size() == 2:
			c = Vector2(float(saved[i][0]) * size.x, float(saved[i][1]) * size.y)
		elif _left_handed():
			c.x = size.x - c.x
		if editing and _drag == i:
			c = _drag_at
		c = _keep_in(c, r[i])
		out.append([ids[i] if i < ids.size() else "", c, r[i]])
	return out


## A button stays whole on the screen, clear of the cut-out's margin and off the top band (the scoreboard).
func _keep_in(c: Vector2, r: float) -> Vector2:
	var m := UI.safe_margins(self, 8.0)
	return Vector2(clampf(c.x, m.x + r, size.x - m.z - r), clampf(c.y, 150.0 + r, size.y - m.w - r))


func reset_places() -> void:
	Game.settings.btn_places = []
	Game.save_settings()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if editing:
		_edit_input(event)
		return
	var lay := _layout()
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var on_left := e.position.x < size.x * STICK_SIDE if not _left_handed() else e.position.x > size.x * (1.0 - STICK_SIDE)
		if e.pressed:
			for i in lay.size():
				var b: Array = lay[i]
				if String(b[0]) != "" and e.position.distance_to(b[1]) <= float(b[2]) * 1.12:
					_held[i] = e.index
					_fire(String(b[0]))
					get_viewport().set_input_as_handled()
					return
			if on_left and _joy_touch < 0 and e.position.y > 130.0:
				_joy_touch = e.index
				_joy_base = e.position
				_joy_knob = e.position
				joystick = Vector2.ZERO
				queue_redraw()
		else:
			for i in _held.keys():
				if int(_held[i]) == e.index:
					_held.erase(i)
			if e.index == _joy_touch:
				_joy_touch = -1
				joystick = Vector2.ZERO
				queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_touch:
			var v := d.position - _joy_base
			if v.length() > JOY_R:
				_joy_base += v.normalized() * (v.length() - JOY_R)   # the base follows a thumb that runs on
				v = v.normalized() * JOY_R
			_joy_knob = _joy_base + v
			joystick = v / JOY_R
			queue_redraw()
	elif event is InputEventKey and not event.echo:
		var ke := event as InputEventKey
		_keys[ke.physical_keycode] = ke.pressed
		var i := KEYS.find(ke.physical_keycode)
		if i >= 0:
			_key_held[i] = ke.pressed
			if ke.pressed and i < ids.size():
				_fire(String(ids[i]))
		_keys_to_joystick()


func _edit_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and _drag_touch < 0:
			var lay := _layout()
			for i in lay.size():
				if e.position.distance_to(lay[i][1]) <= float(lay[i][2]) * 1.1:
					_drag = i
					_drag_touch = e.index
					_drag_off = lay[i][1] - e.position
					_drag_at = lay[i][1]
					get_viewport().set_input_as_handled()
					return
		elif not e.pressed and e.index == _drag_touch:
			var lay := _layout()
			var saved := []
			for b in lay:
				saved.append([snappedf(b[1].x / size.x, 0.0001), snappedf(b[1].y / size.y, 0.0001)])
			Game.settings.btn_places = saved
			Game.save_settings()
			_drag = -1
			_drag_touch = -1
			moved.emit()
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _drag_touch:
		_drag_at = event.position + _drag_off
		queue_redraw()


func _keys_to_joystick() -> void:
	if _joy_touch >= 0:
		return
	var v := Vector2.ZERO
	if _keys.get(KEY_A, false) or _keys.get(KEY_LEFT, false):
		v.x -= 1
	if _keys.get(KEY_D, false) or _keys.get(KEY_RIGHT, false):
		v.x += 1
	if _keys.get(KEY_W, false) or _keys.get(KEY_UP, false):
		v.y -= 1
	if _keys.get(KEY_S, false) or _keys.get(KEY_DOWN, false):
		v.y += 1
	joystick = v.normalized() if v.length() > 0 else Vector2.ZERO


func _fire(id: String) -> void:
	flash(id)
	action.emit(id)


func _process(delta: float) -> void:
	_pulse += delta
	for id in _flash.keys():
		_flash[id] = float(_flash[id]) - delta
		if float(_flash[id]) <= 0.0:
			_flash.erase(id)
	queue_redraw()


func _draw() -> void:
	var m := UI.safe_margins(self, 30.0)
	if not editing:
		var rest := Vector2(m.x + 130.0, size.y - m.w - 130.0)
		if _left_handed():
			rest.x = size.x - rest.x
		var base := _joy_base if _joy_touch >= 0 else rest
		var knob := _joy_knob if _joy_touch >= 0 else rest
		draw_arc(base, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.32 if _joy_touch >= 0 else 0.14), 3.0, true)
		draw_circle(knob, 34.0, Color(1, 1, 1, 0.7 if _joy_touch >= 0 else 0.2))
	else:
		var room := Rect2(Vector2(m.x, 150.0), size - Vector2(m.x + m.z, 150.0 + m.w))
		draw_rect(room, Color(1, 1, 1, 0.5), false, 2.0)
	var lay := _layout()
	for i in lay.size():
		var b: Array = lay[i]
		var id := String(b[0])
		if id == "" and not editing:
			continue
		var c: Vector2 = b[1]
		var r: float = b[2]
		var primary := i == 0
		var lit := _flash.has(id) or _held.has(i)
		# Magnets on the whiteboard: an orange one for the main action, white ones for the rest.
		var col := Game.C_MAGNET if primary else Color(0.97, 0.97, 0.96, 0.92)
		if id == "SPRINT":
			col = Color(Game.C_BLUE, 0.92)
		if lit:
			col = col.lightened(0.25)
		if primary and not editing:
			var pr := r + 8.0 + 6.0 * (0.5 + 0.5 * sin(_pulse * 6.0))
			draw_arc(c, pr, 0, TAU, 64, Color(col, 0.35), 4.0, true)
		draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.25))
		draw_circle(c, r, col)
		draw_arc(c, r, 0, TAU, 64, Color(0.1, 0.12, 0.15, 0.55), 3.0, true)
		var ink := Color("1d1307") if primary else (Color.WHITE if id == "SPRINT" else Game.C_INK)
		if id != "":
			_draw_label(id, c, r, ink, primary)
		if not OS.has_feature("mobile") and i < 3 and not editing:
			var kc: String = ["␣", "J", "K"][i]
			draw_string(Game.font_bold, c + Vector2(r * 0.55, r * 0.95), kc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))


## The button's word, as big as fits: shrunk to the circle's width, then over two lines if it must.
func _draw_label(id: String, c: Vector2, r: float, ink: Color, primary: bool) -> void:
	var key := "%s|%d|%s" % [id, int(r), TranslationServer.get_locale()]
	if not _paras.has(key):
		var text := tr("BTN_" + id)
		var w := r * 1.62
		var fs := int((40.0 if primary else 28.0) * Game.text_k() * (r / (86.0 if primary else 64.0)))
		var font: Font = Game.font_bold
		var para := TextParagraph.new()
		while fs > 11:
			para = TextParagraph.new()
			para.add_string(text, font, fs)
			para.width = w
			para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
			para.alignment = HORIZONTAL_ALIGNMENT_CENTER
			var lines := para.get_line_count()
			var widest := 0.0
			for li in lines:
				widest = maxf(widest, para.get_line_width(li))
			if lines <= 2 and widest <= w and para.get_size().y <= r * 1.5:
				if lines == 1 or fs <= int(26.0 * Game.text_k()):
					break
				var one := TextParagraph.new()
				one.add_string(text, font, fs)
				if one.get_line_width(0) <= w:
					break
			fs -= 1
		_paras[key] = para
	var p: TextParagraph = _paras[key]
	var sz := p.get_size()
	p.draw(get_canvas_item(), c - Vector2(p.width * 0.5, sz.y * 0.5), ink)


## For the tests: each button's label, its width and its circle's.
func label_fits() -> Array:
	var out := []
	for b in _layout():
		var key := "%s|%d|%s" % [String(b[0]), int(b[2]), TranslationServer.get_locale()]
		if _paras.has(key):
			var p: TextParagraph = _paras[key]
			var widest := 0.0
			for li in p.get_line_count():
				widest = maxf(widest, p.get_line_width(li))
			out.append({"id": b[0], "w": widest, "room": float(b[2]) * 1.62, "lines": p.get_line_count()})
	return out


## For the tests: the buttons' rectangles, to check they are on the screen and clear of each other.
func button_rects() -> Array:
	var out := []
	for b in _layout():
		var r: float = b[2]
		out.append(Rect2(b[1] - Vector2(r, r), Vector2(r, r) * 2.0))
	return out
