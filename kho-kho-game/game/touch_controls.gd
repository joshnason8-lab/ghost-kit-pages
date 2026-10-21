class_name TouchControls
extends Control
## The match controls for a phone held sideways. Left thumb: a joystick wherever it lands on the left of the screen
## (it runs your active chaser, or your defender). Right thumb: the buttons for what you can do now, which change with
## it: KHO and DIVE when you chase, DODGE and SWITCH when you defend, POWER PLAY when a batch changes in the fast game.
## Several fingers at once. Left-handed (Settings) mirrors the sides. Button size: Normal, Large, Extra large. Move
## buttons (Settings, or the pause menu): in editing mode a finger drags a button where the thumb finds it, and the
## places are saved (as fractions of the screen, for the right-handed layout; mirrored for the left).
## Keys too: WASD or arrows, Space for the first button, J and K for the others.

signal action(id: String)

const JOY_R := 92.0
const KEYS := [KEY_SPACE, KEY_J, KEY_K]
const STICK_SIDE := 0.45     # the share of the screen's width the joystick takes
const TOP_CLEAR := 120.0     # px from the top kept for the scoreboard

var joystick := Vector2.ZERO
var ids: Array = []          # the buttons showing now
var editing := false         # Move buttons: drag them instead of pressing them
var enabled := true
var lit := ""                # a button to pulse (the kho you can give now)
var _joy_touch := -1
var _joy_base := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _flash := {}             # id -> time left lit
var _pulse := 0.0
var _keys := {}
var _paras := {}             # id|radius -> TextParagraph (its label, fitted to the circle)
var _drag := {}              # touch index -> button id being moved
var _held := {}              # id -> true while a finger is on it


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _k() -> float:
	return [1.0, 1.2, 1.4][clampi(int(Game.settings.btn_size), 0, 2)]


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
	return bool(_held.get(id, false))


## The places a button can have, by its slot: the first big in the corner, the others round it (right-handed, px).
func _default_place(slot: int, s: Vector2, k: float) -> Vector2:
	var m := UI.safe_margins(self, 30.0)
	var corner := Vector2(s.x - m.z - 104.0 * k, s.y - m.w - 104.0 * k)
	var places := [corner, corner + Vector2(-182, 8) * k, corner + Vector2(-40, -186) * k, corner + Vector2(-196, -160) * k]
	return places[clampi(slot, 0, 3)]


## Where each button is now: [id, centre, radius].
func layout() -> Array:
	var s := size
	var k := _k()
	var out := []
	var radii := [86.0 * k, 64.0 * k, 60.0 * k, 56.0 * k]
	var saved: Dictionary = Game.settings.btn_places
	for i in mini(ids.size(), 4):
		var id := String(ids[i])
		var c := _default_place(i, s, k)
		var key := "%d" % i
		if saved.has(key):
			var fr: Array = saved[key]
			c = Vector2(float(fr[0]) * s.x, float(fr[1]) * s.y)
		var r: float = radii[i]
		# Never off the screen, under a camera cut-out, over the scoreboard, or on the joystick's side.
		var m := UI.safe_margins(self, 12.0)
		c.x = clampf(c.x, s.x * STICK_SIDE + r, s.x - m.z - r)
		c.y = clampf(c.y, TOP_CLEAR + r, s.y - m.w - r)
		if _left_handed():
			c.x = s.x - c.x
		out.append([id, c, r])
	return out


## Puts the buttons back where they started (Move buttons: Reset).
func reset_places() -> void:
	Game.settings.btn_places = {}
	Game.save_settings()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not enabled:
		return
	var half := size.x * STICK_SIDE
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var on_left := e.position.x < half if not _left_handed() else e.position.x > size.x - half
		if e.pressed:
			for i in layout().size():
				var b: Array = layout()[i]
				if e.position.distance_to(b[1]) <= float(b[2]) * 1.12:
					if editing:
						_drag[e.index] = i
					else:
						_held[String(b[0])] = true
						_fire(String(b[0]))
					get_viewport().set_input_as_handled()
					return
			if on_left and _joy_touch < 0 and e.position.y > TOP_CLEAR and not editing:
				_joy_touch = e.index
				_joy_base = e.position
				_joy_knob = e.position
				joystick = Vector2.ZERO
				queue_redraw()
		else:
			if _drag.has(e.index):
				_drag.erase(e.index)
				Game.save_settings()
			for id in _held.keys():
				_held.erase(id)
			if e.index == _joy_touch:
				_joy_touch = -1
				joystick = Vector2.ZERO
				queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _drag.has(d.index):
			var slot: int = _drag[d.index]
			var p := d.position
			if _left_handed():
				p.x = size.x - p.x
			Game.settings.btn_places["%d" % slot] = [clampf(p.x / size.x, 0.0, 1.0), clampf(p.y / size.y, 0.0, 1.0)]
			queue_redraw()
		elif d.index == _joy_touch:
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
		if i >= 0 and i < ids.size():
			_held[String(ids[i])] = ke.pressed
			if ke.pressed:
				_fire(String(ids[i]))
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
	flash(id)
	action.emit(id)


func _process(delta: float) -> void:
	_pulse += delta
	var any := false
	for id in _flash.keys():
		_flash[id] = float(_flash[id]) - delta
		if float(_flash[id]) <= 0.0:
			_flash.erase(id)
		any = true
	if any or lit != "" or editing:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	# The joystick: where the thumb is, or faintly where it would be.
	var m := UI.safe_margins(self, 30.0)
	var rest := Vector2(m.x + 130.0, size.y - m.w - 130.0)
	if _left_handed():
		rest.x = size.x - rest.x
	var base := _joy_base if _joy_touch >= 0 else rest
	var knob := _joy_knob if _joy_touch >= 0 else rest
	if not editing:
		draw_arc(base, JOY_R, 0, TAU, 48, Color(Game.C_INK, 0.28 if _joy_touch >= 0 else 0.12), 3.0, true)
		draw_circle(knob, 34.0, Color(Game.C_INK, 0.7 if _joy_touch >= 0 else 0.18))
	var lay := layout()
	for i in lay.size():
		var b: Array = lay[i]
		var id := String(b[0])
		var c: Vector2 = b[1]
		var r: float = b[2]
		var primary := i == 0
		var col := Game.C_SAFFRON if primary else Color(Game.C_PANEL, 0.88)
		if id == "POWERPLAY":
			col = Game.C_TEAL
		if _flash.has(id):
			col = col.lightened(0.3)
		if id == lit or editing:
			var pr := r + 8.0 + 6.0 * (0.5 + 0.5 * sin(_pulse * 7.0))
			draw_arc(c, pr, 0, TAU, 64, Color(Game.C_GOLD if not editing else Game.C_INK, 0.5), 4.0, true)
		draw_circle(c, r, col)
		draw_arc(c, r, 0, TAU, 64, Color(0.05, 0.03, 0.02, 0.8) if primary else Color(1, 1, 1, 0.22), 3.0, true)
		var ink := Color("1d1307") if primary else Game.C_INK
		_draw_label(id, c, r, ink, primary)
		if not OS.has_feature("mobile") and i < 3 and not editing:
			var kc: String = ["␣", "J", "K"][i]
			draw_string(Game.font_bold, c + Vector2(r * 0.55, r * 0.95), kc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Game.C_INK, 0.6))


## The button's word, as big as fits: shrunk to the circle's width, then over two lines if it must, shaped properly
## for each script (TextParagraph).
func _draw_label(id: String, c: Vector2, r: float, ink: Color, primary: bool) -> void:
	var key := "%s|%d" % [id, int(r)]
	if not _paras.has(key):
		var text := tr("BTN_" + id)
		var w := r * 1.56
		var fs := int((40.0 if primary else 28.0) * Game.text_k() * (r / (86.0 if primary else 64.0)))
		var font: Font = Game.font_display if TranslationServer.get_locale().left(2) in ["en", "hi", "mr", "ne"] else Game.font_bold
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
	for b in layout():
		var key := "%s|%d" % [String(b[0]), int(b[2])]
		if _paras.has(key):
			var p: TextParagraph = _paras[key]
			var widest := 0.0
			for li in p.get_line_count():
				widest = maxf(widest, p.get_line_width(li))
			out.append({"id": b[0], "w": widest, "room": float(b[2]) * 1.56, "lines": p.get_line_count(), "h": p.get_size().y, "r": b[2]})
	return out
