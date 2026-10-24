class_name TouchControls
extends Control
## The match controls for a phone held sideways. Left thumb: a joystick wherever it lands on the left of the screen
## (to aim, or to run your player with the assist off). Right thumb: the buttons for the touch coming, which change
## with it (SERVE and HORSE KICK, KICK, SET, SPIKE, FEINT, BLOCK ...), the first the biggest. Several fingers at once.
## Left-handed (Settings) swaps the sides. Keys too: WASD or arrows, Space for the first button, J and K for the others.

signal action(id: String)

const JOY_R := 92.0
const KEYS := [KEY_SPACE, KEY_J, KEY_K]

var joystick := Vector2.ZERO
var ids: Array = []          # the buttons showing now
var _joy_touch := -1
var _joy_base := Vector2.ZERO
var _joy_knob := Vector2.ZERO
var _flash := {}             # id -> time left lit
var _pulse := 0.0
var _keys := {}
var _paras := {}             # id -> TextParagraph (its label, fitted to the circle)


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


## Where each button is: the first big in the corner, the others round it.
func _layout() -> Array:
	var s := size
	var k := _k()
	var out := []
	var m := UI.safe_margins(self, 30.0)
	var corner := Vector2(s.x - m.z - 104.0 * k, s.y - m.w - 104.0 * k)
	var places := [corner, corner + Vector2(-178, 6) * k, corner + Vector2(-60, -170) * k, corner + Vector2(-190, -150) * k]
	var radii := [86.0 * k, 60.0 * k, 60.0 * k, 54.0 * k]
	for i in mini(ids.size(), 4):
		var c: Vector2 = places[i]
		if _left_handed():
			c.x = s.x - c.x
		out.append([ids[i], c, radii[i]])
	return out


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var half := size.x * 0.45
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var on_left := e.position.x < half if not _left_handed() else e.position.x > size.x - half
		if e.pressed:
			var hit := _hit(e.position)
			if hit != "":
				_fire(hit)
				get_viewport().set_input_as_handled()
				return
			if e.index == _joy_touch:
				_joy_touch = -1   # the same finger again: its lift was lost (the app was left mid-touch)
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
			if i >= 0 and i < ids.size():
				_fire(String(ids[i]))
		_keys_to_joystick()


## The button a press is for: of those within reach (their circle and 14 px round it), the one whose edge is nearest,
## so a big button does not take presses meant for the small one beside it.
func _hit(at: Vector2) -> String:
	var best := ""
	var best_d := 14.0
	for b in _layout():
		var d := at.distance_to(b[1]) - float(b[2])
		if d <= best_d:
			best_d = d
			best = String(b[0])
	return best


## Leaving the app mid-touch loses the lift: the joystick lets go rather than run on.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_joy_touch = -1
		joystick = Vector2.ZERO
		_keys.clear()
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
		if id == "BLOCK":
			col = Game.C_TEAL
		if lit:
			col = col.lightened(0.3)
		if primary:
			var pr := r + 8.0 + 6.0 * (0.5 + 0.5 * sin(_pulse * 7.0))
			draw_arc(c, pr, 0, TAU, 64, Color(col, 0.35), 4.0, true)
		draw_circle(c, r, col)
		draw_arc(c, r, 0, TAU, 64, Color(0.02, 0.05, 0.09, 0.8) if primary else Color(1, 1, 1, 0.22), 3.0, true)
		var ink := Color("1d1307") if primary or id == "BLOCK" else Game.C_INK
		_draw_label(id, c, r, ink, primary)
		# The key that presses it, on a computer.
		if not OS.has_feature("mobile") and i < 3:
			var kc: String = ["␣", "J", "K"][i]
			draw_string(Game.font_bold, c + Vector2(r * 0.55, r * 0.95), kc, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Game.C_INK, 0.6))


## The button's word, as big as fits: shrunk to fit the circle's width, then over two lines if it must (shaped and
## broken properly for Thai, Khmer or Burmese, which have no spaces between words).
func _draw_label(id: String, c: Vector2, r: float, ink: Color, primary: bool) -> void:
	var key := "%s|%d" % [id, int(r)]
	if not _paras.has(key):
		var text := tr("BTN_" + id)
		var w := r * 1.62
		var fs := int((44.0 if primary else 30.0) * Game.text_k() * (r / (86.0 if primary else 60.0)))
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
				if lines == 1 or fs <= int(30.0 * Game.text_k()):
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
