class_name TouchControls
extends Control
## The match controls for a phone held sideways. Left thumb: a joystick wherever it lands on the left of the screen
## (to run your player, and to aim). Right thumb: the buttons for what he can do now, which change with it (STRIKE,
## GOAL, PASS, SOLO; CATCH, LIFT, PULL; TACKLE, BLOCK; at a restart LONG and SHORT ...), the first the biggest, and a
## small SWITCH above them to change your player. Several fingers at once. Left-handed (Settings) swaps the sides;
## Button size makes them bigger; Move buttons (Settings) lets you drag each where you want it, kept in settings.
## Keys too: WASD or arrows, Space for the first button, J, K and L for the others, Q to switch.

signal action(id: String)

const JOY_R := 92.0
const KEYS := [KEY_SPACE, KEY_J, KEY_K, KEY_L]

var joystick := Vector2.ZERO
var ids: Array = []          # the buttons showing now
var _joy_touch := -1
var _joy_base := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _flash := {}             # id -> time left lit
var _pulse := 0.0
var _keys := {}
var _paras := {}             # id -> TextParagraph (its label, fitted to the circle)
var edit := false            # Move buttons: drags move the buttons instead of pressing them
static var key_hints := true # the keyboard's keys beside the buttons on a computer (off for the store's pictures)
static var touch_seen := false   # a thumb has touched the screen: no keyboard here to hint at
var last_fired := ""             # the last button pressed (the playtest hook reads it)
var _drag_slot := -1
var _drag_touch := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _k() -> float:
	return [1.0, 1.2, 1.4][clampi(int(Game.settings.btn_size), 0, 2)]


func _left_handed() -> bool:
	return bool(Game.settings.left_handed)


func set_buttons(p_ids: Array) -> void:
	ids = p_ids.duplicate()
	_paras.clear()
	queue_redraw()


func flash(id: String) -> void:
	_flash[id] = 0.25
	queue_redraw()


## The default place of each slot, as a fraction of the screen from the corner: slot 0 the big one in the corner,
## 1 to its left, 2 above it, 3 above and left; 4 the small SWITCH.
func _default_slot(i: int) -> Vector2:
	var s := size
	var k := _k()
	var m := UI.safe_margins(self, 30.0)
	var corner := Vector2(s.x - m.z - 104.0 * k, s.y - m.w - 104.0 * k)
	var places := [corner, corner + Vector2(-182, 8) * k, corner + Vector2(-62, -176) * k, corner + Vector2(-200, -150) * k,
		corner + Vector2(10, -300) * k]
	return places[i]


func slot_pos(i: int) -> Vector2:
	var key := "slot%d" % i
	var saved: Dictionary = Game.settings.get("btn_pos", {})
	var c := _default_slot(i)
	if saved.has(key) and size.x > 0:
		var f: Array = saved[key]
		c = Vector2(float(f[0]) * size.x, float(f[1]) * size.y)
	if _left_handed():
		c.x = size.x - c.x
	return c


func slot_radius(i: int) -> float:
	var k := _k()
	return [86.0, 62.0, 62.0, 56.0, 46.0][i] * k


## Where each button showing is: [id, centre, radius].
func _layout() -> Array:
	var out := []
	var slot := 0
	for id in ids:
		if String(id) == "SWITCH":
			out.append([id, slot_pos(4), slot_radius(4)])
			continue
		if slot > 3:
			continue
		out.append([id, slot_pos(slot), slot_radius(slot)])
		slot += 1
	return out


## Move buttons: a drag on a slot moves it; let go and it is saved, as fractions of the screen.
func _edit_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			for i in 5:
				if e.position.distance_to(slot_pos(i)) <= slot_radius(i) * 1.1:
					_drag_slot = i
					_drag_touch = e.index
					get_viewport().set_input_as_handled()
					return
		elif e.index == _drag_touch:
			_drag_slot = -1
			_drag_touch = -1
			Game.save_settings()
	elif event is InputEventScreenDrag and _drag_slot >= 0:
		var d := event as InputEventScreenDrag
		if d.index != _drag_touch:
			return
		var r := slot_radius(_drag_slot)
		var p := Vector2(clampf(d.position.x, r, size.x - r), clampf(d.position.y, r + 90.0, size.y - r))
		if _left_handed():
			p.x = size.x - p.x
		var saved: Dictionary = Game.settings.get("btn_pos", {})
		saved["slot%d" % _drag_slot] = [p.x / size.x, p.y / size.y]
		Game.settings.btn_pos = saved
		queue_redraw()
		get_viewport().set_input_as_handled()


func reset_positions() -> void:
	Game.settings.btn_pos = {}
	Game.save_settings()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if edit:
		_edit_input(event)
		return
	var half := size.x * 0.45
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if not touch_seen:
			touch_seen = true
			queue_redraw()
		var on_left := e.position.x < half if not _left_handed() else e.position.x > size.x - half
		if e.pressed:
			for b in _layout():
				if e.position.distance_to(b[1]) <= float(b[2]) * 1.12:
					_fire(String(b[0]))
					get_viewport().set_input_as_handled()
					return
			if on_left and _joy_touch < 0 and e.position.y > 110.0:
				_joy_touch = e.index
				_joy_base = e.position
				_joy_knob = e.position
				joystick = Vector2.ZERO
				queue_redraw()
		elif e.index == _joy_touch:
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
		if ke.pressed:
			var i := KEYS.find(ke.physical_keycode)
			var shown: Array = ids.filter(func(x): return String(x) != "SWITCH")
			if i >= 0 and i < shown.size():
				_fire(String(shown[i]))
			elif ke.physical_keycode == KEY_Q and "SWITCH" in ids:
				_fire("SWITCH")
			elif ke.physical_keycode == KEY_ESCAPE:
				Game.go_back()
		_keys_to_joystick()


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
	last_fired = id
	flash(id)
	action.emit(id)


func _process(delta: float) -> void:
	_pulse += delta
	var lit := false
	for id in _flash.keys():
		_flash[id] = float(_flash[id]) - delta
		if float(_flash[id]) <= 0.0:
			_flash.erase(id)
		lit = true
	if lit or not ids.is_empty():
		queue_redraw()


func _draw() -> void:
	# The joystick: where the thumb is, or faintly where it would be.
	var m := UI.safe_margins(self, 30.0)
	var rest := Vector2(m.x + 130.0, size.y - m.w - 130.0)
	if _left_handed():
		rest.x = size.x - rest.x
	var base := _joy_base if _joy_touch >= 0 else rest
	var knob := _joy_knob if _joy_touch >= 0 else rest
	draw_arc(base, JOY_R, 0, TAU, 48, Color(Game.C_INK, 0.28 if _joy_touch >= 0 else 0.12), 3.0, true)
	draw_circle(knob, 34.0, Color(Game.C_INK, 0.7 if _joy_touch >= 0 else 0.18))
	# The buttons.
	for i in _layout().size():
		var b: Array = _layout()[i]
		var id := String(b[0])
		var c: Vector2 = b[1]
		var r: float = b[2]
		var primary := i == 0
		var lit := _flash.has(id)
		var col := Game.C_SAFFRON if primary else Color(Game.C_PANEL, 0.9)
		if id in ["TACKLE", "BLOCK"] and primary:
			col = Game.C_TEAL
		if id == "SWITCH":
			col = Color(Game.C_PANEL, 0.75)
			primary = false
		if lit:
			col = col.lightened(0.3)
		if primary:
			var pr := r + 8.0 + 6.0 * (0.5 + 0.5 * sin(_pulse * 7.0))
			draw_arc(c, pr, 0, TAU, 64, Color(col, 0.35), 4.0, true)
		draw_circle(c, r, col)
		draw_arc(c, r, 0, TAU, 64, Color(0.02, 0.05, 0.09, 0.8) if primary else Color(1, 1, 1, 0.22), 3.0, true)
		var ink := Color("1d1307") if primary else Game.C_INK
		_draw_label(id, c, r, ink, primary)
		# The key that presses it, on a computer.
		if not OS.has_feature("mobile") and key_hints and not touch_seen and i < 4:
			var kc: String = "Q" if id == "SWITCH" else ["␣", "J", "K", "L"][mini(i, 3)]
			draw_string(Game.font_bold, c + Vector2(r * 0.55, r * 0.95), kc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Game.C_INK, 0.6))


## The button's word, as big as fits: shrunk to fit the circle's width, then over two lines if it must (shaped and
## broken properly for Thai, Khmer or Burmese, which have no spaces between words).
func _draw_label(id: String, c: Vector2, r: float, ink: Color, primary: bool) -> void:
	var key := "%s|%d" % [id, int(r)]
	if not _paras.has(key):
		var text := tr("BTN_" + id)
		var w := r * 1.62
		var fs := int((40.0 if primary else 28.0) * Game.text_k() * (r / (86.0 if primary else 62.0)))
		var font: Font = Game.font_display if Game.text_k() >= 0.99 else Game.font_bold
		var para := TextParagraph.new()
		while fs > 12:
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
				# Two lines only once one line would be too small to read.
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
		var key := "%s|%d" % [String(b[0]), int(b[2])]
		if _paras.has(key):
			var p: TextParagraph = _paras[key]
			var widest := 0.0
			for li in p.get_line_count():
				widest = maxf(widest, p.get_line_width(li))
			out.append({"id": b[0], "w": widest, "room": float(b[2]) * 1.62, "lines": p.get_line_count()})
	return out
