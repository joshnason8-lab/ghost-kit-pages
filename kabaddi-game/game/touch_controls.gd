class_name TouchControls
extends Control
## Multi-touch controls drawn and hit-tested by hand, because Godot's GUI only tracks one
## touch at a time. Left: a floating joystick. Right: context buttons. Anywhere else: drag to
## look. Keyboard works too: WASD/arrows, J hand touch, K toe touch, Space dodge or tackle,
## Tab switch, C camera, Esc pause.

signal action(id: String)

var context := "none"   # none, intro, raid, defend
var enabled := true
var cant_mode := false  # raid with the tap-to-chant cant
var beat_k := 0.0       # 0 right after a beat .. 1 just before the next one
var chain_on := false
var _flash := ""        # last cant tap result, for colour feedback
var _flash_t := 0.0

var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _look_acc := Vector2.ZERO
var _pressed := {}       # button id -> time left lit
var _button_touch := {}  # touch index -> button id

const STICK_R := 92.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func move_vec() -> Vector2:
	var v := _stick_vec
	var k := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		k.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		k.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		k.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		k.y += 1
	if k != Vector2.ZERO:
		v = k.normalized()
	return v


func take_look() -> Vector2:
	var l := _look_acc
	_look_acc = Vector2.ZERO
	return l


func _buttons() -> Array:
	var s := get_viewport_rect().size
	var lh: bool = Game.settings.left_handed
	var fx := func(x: float) -> float: return s.x - x if not lh else x
	var list := [
		{"id": "pause", "label": "II", "pos": Vector2(fx.call(52), 52), "r": 30.0, "col": Color(1, 1, 1, 0.16)},
		{"id": "camera", "label": tr("BTN_CAMERA"), "pos": Vector2(fx.call(140), 52), "r": 30.0, "col": Color(1, 1, 1, 0.16), "small": true},
	]
	var main := Vector2(fx.call(150), s.y - 150)
	match context:
		"intro":
			list.append({"id": "skip", "label": tr("BTN_SKIP"), "pos": main, "r": 62.0, "col": Color(Game.C_INK, 0.85)})
		"raid":
			var dx := -1.0 if not lh else 1.0
			if cant_mode:
				list.append({"id": "cant", "label": tr("BTN_CANT"), "pos": main, "r": 80.0, "col": Game.C_SAFFRON, "pulse": true})
				list.append({"id": "touch", "label": tr("BTN_TOUCH"), "pos": main + Vector2(185 * dx, 20), "r": 60.0, "col": Game.C_GOLD})
				list.append({"id": "kick", "label": tr("BTN_KICK"), "pos": main + Vector2(150 * dx, -150), "r": 52.0, "col": Game.C_GOLD.darkened(0.15)})
				list.append({"id": "dodge", "label": tr("BTN_DODGE"), "pos": main + Vector2(-10 * dx, -195), "r": 52.0, "col": Game.C_INK})
			else:
				list.append({"id": "touch", "label": tr("BTN_TOUCH"), "pos": main, "r": 78.0, "col": Game.C_SAFFRON})
				list.append({"id": "kick", "label": tr("BTN_KICK"), "pos": main + Vector2(170 * dx, 50), "r": 58.0, "col": Game.C_GOLD})
				list.append({"id": "dodge", "label": tr("BTN_DODGE"), "pos": main + Vector2(40 * dx, -170), "r": 58.0, "col": Game.C_INK})
		"defend":
			var dx2 := -1.0 if not lh else 1.0
			list.append({"id": "tackle", "label": tr("BTN_TACKLE"), "pos": main, "r": 82.0, "col": Game.C_MAGENTA})
			list.append({"id": "switch", "label": tr("BTN_SWITCH"), "pos": main + Vector2(60 * dx2, -175), "r": 54.0, "col": Game.C_INK})
			list.append({"id": "chain", "label": tr("BTN_UNCHAIN") if chain_on else tr("BTN_CHAIN"), "pos": main + Vector2(190 * dx2, 10), "r": 58.0,
				"col": Game.C_GOLD if chain_on else Color(Game.C_INK, 0.6), "lit": chain_on})
	return list


func _hit(p: Vector2) -> String:
	for b in _buttons():
		if p.distance_to(b.pos) <= float(b.r) + 14.0:
			return String(b.id)
	return ""


func _fire(id: String) -> void:
	_pressed[id] = 0.15
	action.emit(id)


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_J:
				_fire("touch")
			KEY_K:
				_fire("kick")
			KEY_SPACE:
				if context == "defend":
					_fire("tackle")
				elif context == "intro":
					_fire("skip")
				else:
					_fire("cant" if cant_mode else "dodge")
			KEY_L:
				_fire("tackle" if context == "defend" else "dodge")
			KEY_G:
				_fire("chain")
			KEY_TAB, KEY_Q:
				_fire("switch")
			KEY_C:
				_fire("camera")
			KEY_ESCAPE, KEY_P:
				_fire("pause")
		return
	var s := get_viewport_rect().size
	var lh: bool = Game.settings.left_handed
	if event is InputEventScreenTouch:
		if event.pressed:
			var id := _hit(event.position)
			if id != "":
				_button_touch[event.index] = id
				_fire(id)
				get_viewport().set_input_as_handled()
				return
			var in_stick_zone: bool = (event.position.x < s.x * 0.45) if not lh else (event.position.x > s.x * 0.55)
			if in_stick_zone and event.position.y > s.y * 0.22 and _stick_id == -1 and context in ["raid", "defend"]:
				_stick_id = event.index
				_stick_origin = event.position
				_stick_vec = Vector2.ZERO
			elif _look_id == -1:
				_look_id = event.index
				_look_last = event.position
		else:
			if event.index == _stick_id:
				_stick_id = -1
				_stick_vec = Vector2.ZERO
			if event.index == _look_id:
				_look_id = -1
			_button_touch.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _stick_id:
			var d: Vector2 = event.position - _stick_origin
			if d.length() > STICK_R * 1.6:
				# Let the base follow a thumb that wanders.
				_stick_origin = event.position - d.normalized() * STICK_R * 1.6
				d = event.position - _stick_origin
			_stick_vec = (d / STICK_R).limit_length(1.0)
			if _stick_vec.length() < 0.12:
				_stick_vec = Vector2.ZERO
			queue_redraw()
		elif event.index == _look_id:
			_look_acc += event.position - _look_last
			_look_last = event.position


func flash(kind: String) -> void:
	_flash = kind
	_flash_t = 0.18
	queue_redraw()


func _process(delta: float) -> void:
	_flash_t = maxf(0.0, _flash_t - delta)
	if cant_mode and context == "raid":
		queue_redraw()
	var lit := false
	for k in _pressed.keys():
		_pressed[k] -= delta
		if _pressed[k] <= 0.0:
			_pressed.erase(k)
		lit = true
	if lit:
		queue_redraw()
	if context not in ["raid", "defend"] and _stick_id != -1:
		_stick_id = -1
		_stick_vec = Vector2.ZERO
		queue_redraw()


func set_context(c: String) -> void:
	if c != context:
		context = c
		queue_redraw()


func _draw() -> void:
	var font: Font = Game.font_bold
	for b in _buttons():
		var pos: Vector2 = b.pos
		var r: float = b.r
		var col: Color = b.col
		var lit: bool = _pressed.has(b.id) or bool(b.get("lit", false))
		var fill := Color(col, 0.92 if lit else (0.78 if col.a > 0.5 else col.a))
		if b.get("pulse", false):
			# Cant: a ring closes in on the button; tap as it lands.
			var k := clampf(beat_k, 0.0, 1.0)
			draw_arc(pos, r * (1.0 + 0.75 * (1.0 - k)), 0, TAU, 48, Color(Game.C_SAFFRON, 0.25 + 0.7 * k), 4.0, true)
			if _flash_t > 0.0:
				var fc: Color = {"perfect": Game.C_GOLD, "good": Game.C_INK, "off": Game.C_DANGER, "fast": Game.C_DANGER}.get(_flash, Game.C_INK)
				fill = fc
		if b.id in ["pause", "camera"]:
			fill = Color(0.03, 0.07, 0.12, 0.55 if not lit else 0.85)
		draw_circle(pos, r, fill)
		draw_arc(pos, r, 0, TAU, 48, Color(1, 1, 1, 0.35 if not lit else 0.9), 2.0, true)
		var dark = col.get_luminance() > 0.55 and b.id not in ["pause", "camera"]
		var tc := Color("1d1307") if dark else Game.C_INK
		var size := 22 if r > 70 else (17 if r > 40 else 14)
		if b.id == "pause":
			draw_rect(Rect2(pos + Vector2(-9, -11), Vector2(6, 22)), Game.C_INK)
			draw_rect(Rect2(pos + Vector2(3, -11), Vector2(6, 22)), Game.C_INK)
			continue
		var text: String = b.label
		var w := r * 1.8
		var lines := _wrap(text, font, size, w)
		var lh := size * 1.1
		var y0 := pos.y - (lines.size() - 1) * lh * 0.5 + size * 0.35
		for i in lines.size():
			draw_string(font, Vector2(pos.x - w * 0.5, y0 + i * lh), lines[i], HORIZONTAL_ALIGNMENT_CENTER, w, size, tc)
	if _stick_id != -1:
		draw_circle(_stick_origin, STICK_R, Color(1, 1, 1, 0.07))
		draw_arc(_stick_origin, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.3), 2.0, true)
		draw_circle(_stick_origin + _stick_vec * STICK_R, 38, Color(Game.C_INK, 0.85))
	elif context in ["raid", "defend"]:
		# Hint where the stick lives.
		var s := get_viewport_rect().size
		var hx := 170.0 if not Game.settings.left_handed else s.x - 170.0
		var c := Vector2(hx, s.y - 160)
		draw_arc(c, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.12), 2.0, true)
		draw_circle(c, 30, Color(1, 1, 1, 0.08))


func _wrap(text: String, font: Font, size: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
		out.append(text)
		return out
	var words := text.split(" ")
	var line := ""
	for wd in words:
		var trial := wd if line == "" else line + " " + wd
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = wd
		else:
			line = trial
	if line != "":
		out.append(line)
	return out
