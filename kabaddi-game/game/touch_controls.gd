class_name TouchControls
extends Control
## Multi-touch controls drawn and hit-tested by hand, because Godot's GUI only tracks one
## touch at a time. Left: a floating joystick. Right: context buttons. Anywhere else: drag to
## look. Keyboard works too: WASD/arrows. Raiding: J hand touch, K kick, L dodge, U dubki,
## I lion jump, Space cant. Defending: J ankle, K thigh, L waist, U dash, Space your usual
## tackle, G chain, Tab switch. C camera, Esc pause. Played from a keyboard, each button wears its key.
## The buttons are as big as the player likes them (Settings > Button size) and where the player puts them (Move buttons,
## in Settings and the pause menu, ButtonLayoutPanel): while editing, a touch drags a button instead of pressing it.

signal action(id: String)
signal tapped(pos: Vector2)   # a quick tap that was not on a button (to pick a defender)
signal moved                  # editing: a button was let go in its new place (saved in Game.settings.btn_places)

var context := "none"   # none, intro, raid, defend
var enabled := true
var watch_only := false   # watching the computer play (Match "watch"): only pause, camera and skip
var cant_mode := false  # raid with the tap-to-chant cant
var beat_k := 0.0       # 0 right after a beat .. 1 just before the next one
var chain_on := false
var read_hint := ""     # escape button to light up for the tackle coming in (easier levels)
var held := false       # the user's raider is held: Dodge becomes a big Break free, the touches he cannot make dim
var _flash := ""        # last cant tap result, for colour feedback
var _flash_t := 0.0
var _t := 0.0

var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look_id := -1
var _look_last := Vector2.ZERO
var _look_acc := Vector2.ZERO
var _pressed := {}       # button id -> time left lit
var _button_touch := {}  # touch index -> button id
var _touch_start := {}   # touch index -> [position, time], to tell taps from drags
var _cap_box: StyleBoxFlat
var _insets := Vector2.ZERO   # the screen's unsafe strips (a camera cut-out) at the left and right, in canvas units
var _fits := {}          # a button's words and size -> the font size and lines that sit inside its circle
var editing := false:    # moving the buttons: a touch picks one up and drags it, nothing is pressed
	set(v):
		editing = v
		_drag = -1
		_drag_touch = -1
		queue_redraw()
var _drag := -1          # editing: the place (PLACES) being dragged ...
var _drag_touch := -1    # ... by this touch ...
var _drag_at := Vector2.ZERO    # ... its middle where the finger has it ...
var _drag_off := Vector2.ZERO   # ... the finger's offset from the middle ...
var _drag_from := Vector2.ZERO  # ... and where it was picked up
var _places := []        # the six places' middles on this screen (places_now) ...
var _places_key := ""    # ... and what they were worked out for

## Each button shows its key: from the start in a computer's browser, after the first key press anywhere else,
## and off again with a finger's touch (not one the mouse makes).
static var keys_shown := OS.has_feature("web") and not (OS.has_feature("web_android") or OS.has_feature("web_ios"))

const STICK_R := 92.0
const STICK_SIDE := 0.45   # the share of the screen's width on the joystick's side: a touch there moves, no button goes
## The buttons' sizes in Settings (Normal, Large, Extra large). The spacing between them grows a little over half as
## much, so the biggest set still fits between the scoreboard's row and the bottom of a phone's screen.
const SIZE_K := [1.0, 1.2, 1.4]
## The six places on the right the match buttons sit in, as offsets from the first at the Normal size, for the right
## hand (the left hand's are mirrored). A raid button and a defence button share each place, Touch and Ankle in the
## first, under the thumb: the scoring moves and the grips nearest the thumb, the escapes and dash, chain and switch in
## an arc above them.
const PLACES := [Vector2(0, 0), Vector2(-185, 22), Vector2(-152, -128), Vector2(-15, -195), Vector2(100, -165),
	Vector2(-70, -330)]
const PLACE_R := [78.0, 58.0, 50.0, 47.0, 42.0, 46.0]   # the biggest button each place holds, at the Normal size
const GAP := 10.0          # px kept between two buttons' edges
const TOP := 100.0         # px: the buttons stay below the scoreboard's row, and pause and camera


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap_box = StyleBoxFlat.new()
	_cap_box.bg_color = Color(0.03, 0.07, 0.12, 0.92)
	_cap_box.set_corner_radius_all(6)
	_cap_box.border_color = Color(1, 1, 1, 0.55)
	_cap_box.set_border_width_all(1)
	resized.connect(_read_insets)
	_read_insets.call_deferred()


## Held sideways, a phone's punch-hole camera sits at the left or right edge: the buttons keep clear of it.
func _read_insets() -> void:
	if not is_inside_tree():
		return
	var m := UI.safe_margins(self, 0.0)
	_insets = Vector2(m.x, m.z)
	queue_redraw()


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
	var ins := _insets
	var fx := func(x: float) -> float: return s.x - x - ins.y if not lh else x + ins.x
	var k := size_k()
	# Pause and camera, up in the corner and pressed seldom, grow half as much as the rest.
	var kc := 1.0 + (k - 1.0) * 0.5
	var rc := 30.0 * kc
	var list := [
		{"id": "pause", "label": "II", "pos": Vector2(fx.call(22 + rc), 22 + rc), "r": rc, "fs": font_size(30.0, kc),
			"col": Color(1, 1, 1, 0.16)},
		{"id": "camera", "label": tr("BTN_CAMERA"), "pos": Vector2(fx.call(50 + 3 * rc), 22 + rc), "r": rc,
			"fs": font_size(30.0, kc), "col": Color(1, 1, 1, 0.16), "small": true},
	]
	# A button in place i, r0 its radius at the Normal size.
	var at := places_now()
	var place := func(id: String, label: String, i: int, r0: float, col: Color, extra: Dictionary) -> Dictionary:
		var b := {"id": id, "label": label, "pos": at[i], "place": i, "r": r0 * k, "fs": font_size(r0, k), "col": col}
		b.merge(extra, true)
		return b
	match context:
		"intro":
			list.append(place.call("skip", tr("BTN_SKIP"), 0, 62.0, Color(Game.C_INK, 0.85), {}))
		"raid":
			# Scoring moves sit nearest the thumb; the escapes (dodge, dubki, lion jump)
			# make an arc above them.
			var esc := Color("3b4f6b")
			# Held, he cannot touch or kick: those dim, and Dodge, his way out, is Break free, big and glowing.
			var dim := 0.3 if held else 1.0
			if cant_mode:
				list.append(place.call("cant", tr("BTN_CANT"), 0, 78.0, Game.C_SAFFRON, {"pulse": true}))
				list.append(place.call("touch", tr("BTN_TOUCH"), 1, 58.0, Color(Game.C_GOLD, dim), {}))
				list.append(place.call("kick", tr("BTN_LEG"), 2, 50.0, Color(Game.C_GOLD.darkened(0.15), dim), {}))
			else:
				list.append(place.call("touch", tr("BTN_TOUCH"), 0, 76.0, Color(Game.C_SAFFRON, dim), {}))
				list.append(place.call("kick", tr("BTN_LEG"), 1, 56.0, Color(Game.C_GOLD, dim), {}))
			if held:
				# Break free, big already, grows half as much as the rest: it stays clear of Dubki beside it.
				var kb := 1.0 + (k - 1.0) * 0.5
				list.append(place.call("dodge", tr("BTN_BREAK_FREE"), 3, 72.0, Game.C_GOLD,
					{"r": 72.0 * kb, "fs": font_size(72.0, kb), "glow": true}))
			else:
				list.append(place.call("dodge", tr("BTN_DODGE"), 3, 47.0, Game.C_INK, {}))
			list.append(place.call("dubki", tr("BTN_DUBKI"), 4, 42.0, Game.C_GOLD if read_hint == "dubki" else esc,
				{"lit": read_hint == "dubki"}))
			list.append(place.call("jump", tr("BTN_JUMP"), 5, 46.0, Game.C_GOLD if read_hint == "jump" else esc,
				{"lit": read_hint == "jump"}))
		"defend":
			# The grips nearest the thumb; dash, chain and switch above them.
			var hint_col := func(id: String, base: Color) -> Color: return Game.C_GOLD if read_hint == id else base
			var grip := Game.C_MAGENTA.lightened(0.15)
			list.append(place.call("ankle", tr("BTN_ANKLE"), 0, 78.0, Game.C_MAGENTA, {}))
			list.append(place.call("thigh", tr("BTN_THIGH"), 1, 58.0, grip, {}))
			list.append(place.call("waist", tr("BTN_WAIST"), 2, 50.0, hint_col.call("waist", grip), {"lit": read_hint == "waist"}))
			list.append(place.call("dash", tr("BTN_DASH"), 3, 47.0, hint_col.call("dash", Color("6b3b5b")), {"lit": read_hint == "dash"}))
			list.append(place.call("chain", tr("BTN_UNCHAIN") if chain_on else tr("BTN_CHAIN"), 4, 42.0,
				Game.C_GOLD if chain_on else Color("3b4f6b"), {"lit": chain_on}))
			list.append(place.call("switch", tr("BTN_SWITCH"), 5, 46.0, Game.C_INK, {}))
	if watch_only:
		return list.filter(func(b): return b.id in ["pause", "camera", "skip"])
	return list


## How big the buttons are drawn (Settings > Button size).
static func size_k() -> float:
	return SIZE_K[clampi(int(Game.settings.get("btn_size", 0)), 0, SIZE_K.size() - 1)]


## The size a button's words start at (fit_label may take them smaller to fit): by its radius at the Normal size, r0,
## and as much bigger as the button (k).
static func font_size(r0: float, k := 1.0) -> int:
	return Game.ts(roundi((22 if r0 > 70 else (17 if r0 > 40 else 14)) * k))


## The six places' middles on this screen: where the player put them (Move buttons) or the size's own, kept on the
## screen, off the joystick's side and apart. While one is dragged, it is where the finger has it and the rest make way.
func places_now() -> Array:
	var s := get_viewport_rect().size
	var saved: Array = Game.settings.get("btn_places", [])
	var key := str([s, _insets, size_k(), Game.settings.left_handed, saved, _drag, _drag_at])
	if key != _places_key:
		_places_key = key
		_places = layout(s, _insets, size_k(), Game.settings.left_handed, saved, _drag, _drag_at)
	return _places


## The six places' middles on a screen of size s (ins: its unsafe strips at the left and right) for buttons k times
## their Normal size. saved: the places the player put them in, each [from the side, from the bottom] in px (to_saved),
## or [] for the size's own. A dragged one (drag, its middle at at) stays where the finger has it; the rest make way.
static func layout(s: Vector2, ins: Vector2, k: float, lh: bool, saved: Array, drag := -1, at := Vector2.ZERO) -> Array:
	var g := 1.0 + (k - 1.0) * 0.6
	# The first place, from the bottom right corner: as near the side as the Dubki/Chain place lets it, and lower down
	# for the bigger sizes so that the Lion jump/Switch place stays under the scoreboard's row.
	var first := Vector2(8.0 + 100.0 * g + 42.0 * k, 150.0 - 25.0 * (k - 1.0))
	var own := is_layout(saved)
	var p := []
	var r := []
	for i in PLACES.size():
		var e: Vector2 = Vector2(float(saved[i][0]), float(saved[i][1])) if own else first - PLACES[i] * g
		p.append(Vector2(s.x - ins.y - e.x if not lh else ins.x + e.x, s.y - e.y))
		r.append(PLACE_R[i] * k)
	if drag >= 0 and drag < p.size():
		p[drag] = at
	return settle(p, r, room(s, ins, lh), drag)


## The places' middles p as saved: each [from the side, from the bottom] in px, the side the thumb's (the right, or
## the left for the left hand), so a layout keeps to the thumb when the hand changes.
static func to_saved(p: Array, s: Vector2, ins: Vector2, lh: bool) -> Array:
	var out := []
	for q in p:
		out.append([snappedf(s.x - ins.y - q.x if not lh else q.x - ins.x, 0.1), snappedf(s.y - q.y, 0.1)])
	return out


## Whether saved is a layout to_saved made: six places, two numbers each.
static func is_layout(saved) -> bool:
	if not saved is Array or saved.size() != PLACES.size():
		return false
	for e in saved:
		if not e is Array or e.size() != 2 or not (e[0] is float or e[0] is int) or not (e[1] is float or e[1] is int):
			return false
	return true


## Where the buttons may go on a screen of size s: below the scoreboard's row, inside the screen's safe strips and off
## the joystick's side.
static func room(s: Vector2, ins: Vector2, lh: bool) -> Rect2:
	var x0 := s.x * STICK_SIDE if not lh else ins.x + 6.0
	var x1 := s.x - ins.y - 6.0 if not lh else s.x * (1.0 - STICK_SIDE)
	return Rect2(x0, TOP, x1 - x0, s.y - 6.0 - TOP)


## Moves circles (middles p, radii r) apart where they come closer than GAP and into room. A pinned one stays put and
## the others make way, as long as they can; then all give a little.
static func settle(p: Array, r: Array, rm: Rect2, pinned := -1) -> Array:
	var out := p.duplicate()
	for it in 24:
		var moved_any := false
		for i in out.size():
			for j in range(i + 1, out.size()):
				var d: Vector2 = out[j] - out[i]
				var need: float = r[i] + r[j] + GAP
				var l := d.length()
				if l >= need - 0.01:
					continue
				var wi := 0.5   # the share of the move that is i's
				if it < 16 and i == pinned:
					wi = 0.0
				elif it < 16 and j == pinned:
					wi = 1.0
				var n := d / l if l > 0.001 else Vector2.ZERO
				if l <= 0.001:
					# One right on top of the other: the one that gives way goes towards the middle of the room.
					var inward: Vector2 = rm.get_center() - (out[j] if wi == 0.0 else out[i])
					n = inward.normalized() if inward.length() > 0.001 else Vector2.DOWN
					if wi != 0.0:
						n = -n
				out[i] -= n * (need - l) * wi
				out[j] += n * (need - l) * (1.0 - wi)
				moved_any = true
		for i in out.size():
			var lo: Vector2 = rm.position + Vector2(r[i], r[i])
			var hi: Vector2 = rm.end - Vector2(r[i], r[i])
			var q := Vector2(clampf(out[i].x, lo.x, maxf(lo.x, hi.x)), clampf(out[i].y, lo.y, maxf(lo.y, hi.y)))
			if q.distance_to(out[i]) > 0.01:
				out[i] = q
				moved_any = true
		if not moved_any:
			break
	return out


## The button a touch is on: within a finger's width of its edge, the nearest one (a big Break free next to Dubki
## does not take a press meant for Dubki).
func _hit(p: Vector2) -> String:
	var best := ""
	var bd := INF
	for b in _buttons():
		var d := p.distance_to(b.pos) - float(b.r)
		if d <= 14.0 and d < bd:
			bd = d
			best = String(b.id)
	return best


func _fire(id: String) -> void:
	_pressed[id] = 0.15
	action.emit(id)


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if editing:
		_edit(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not keys_shown:
			keys_shown = true
			queue_redraw()
		match event.keycode:
			KEY_J:
				_fire("ankle" if context == "defend" else "touch")
			KEY_K:
				_fire("thigh" if context == "defend" else "kick")
			KEY_SPACE:
				if context == "defend":
					_fire("tackle")
				elif context == "intro":
					_fire("skip")
				else:
					_fire("cant" if cant_mode else "dodge")
			KEY_L:
				_fire("waist" if context == "defend" else "dodge")
			KEY_U:
				_fire("dash" if context == "defend" else "dubki")
			KEY_I:
				_fire("jump")
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
		if event.pressed and keys_shown and event.device != InputEvent.DEVICE_ID_EMULATION:
			keys_shown = false
		if event.pressed:
			_touch_start[event.index] = [event.position, Time.get_ticks_msec()]
		elif _touch_start.has(event.index) and not _button_touch.has(event.index):
			var st: Array = _touch_start[event.index]
			if (event.position - st[0]).length() < 22.0 and Time.get_ticks_msec() - int(st[1]) < 350:
				tapped.emit(event.position)
		if not event.pressed:
			_touch_start.erase(event.index)
		if event.pressed:
			var id := _hit(event.position)
			if id != "":
				_button_touch[event.index] = id
				_fire(id)
				get_viewport().set_input_as_handled()
				return
			var in_stick_zone: bool = (event.position.x < s.x * STICK_SIDE) if not lh else (event.position.x > s.x * (1.0 - STICK_SIDE))
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


## Moving the buttons: a touch on one picks it up, it follows the finger (the others making way) and stays where it is
## let go, the six places saved.
func _edit(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		# (The same finger down again: its lift was lost, as when the app was left mid-drag. A fresh pick-up.)
		if event.pressed and (_drag_touch == -1 or event.index == _drag_touch):
			_drag = -1
			_drag_touch = -1
			var id := _hit(event.position)
			for b in _buttons():
				if b.id == id and b.has("place"):
					_drag = int(b.place)
					_drag_touch = event.index
					_drag_off = b.pos - event.position
					_drag_at = b.pos
					_drag_from = b.pos
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
		elif not event.pressed and event.index == _drag_touch:
			# A touch that did not move it keeps the layout as it was (the size's own stays the size's own).
			if _drag_at.distance_to(_drag_from) > 4.0:
				Game.settings.btn_places = to_saved(places_now(), get_viewport_rect().size, _insets, Game.settings.left_handed)
				Game.save_settings()
			_drag = -1
			_drag_touch = -1
			get_viewport().set_input_as_handled()
			queue_redraw()
			moved.emit()
	elif event is InputEventScreenDrag and event.index == _drag_touch:
		_drag_at = event.position + _drag_off
		get_viewport().set_input_as_handled()
		queue_redraw()


## Back to the size's own places.
func reset_places() -> void:
	Game.settings.btn_places = []
	Game.save_settings()
	queue_redraw()


func flash(kind: String) -> void:
	_flash = kind
	_flash_t = 0.18
	queue_redraw()


func _process(delta: float) -> void:
	_flash_t = maxf(0.0, _flash_t - delta)
	_t += delta
	if (cant_mode or held) and context == "raid":
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
	if editing and _drag >= 0:
		# Where a button can go: dashed round the room, while one is moved.
		var rm := room(get_viewport_rect().size, _insets, Game.settings.left_handed)
		var corners := [rm.position, Vector2(rm.end.x, rm.position.y), rm.end, Vector2(rm.position.x, rm.end.y)]
		for i in 4:
			draw_dashed_line(corners[i], corners[(i + 1) % 4], Color(1, 1, 1, 0.4), 2.0, 12.0)
	for b in _buttons():
		var pos: Vector2 = b.pos
		var r: float = b.r
		var col: Color = b.col
		var picked: bool = editing and int(b.get("place", -1)) == _drag and _drag >= 0
		var lit: bool = _pressed.has(b.id) or bool(b.get("lit", false)) or picked
		var fill := Color(col, 0.92 if lit else (0.78 if col.a > 0.5 else col.a))
		if b.get("pulse", false):
			# Cant: a ring closes in on the button; tap as it lands.
			var k := clampf(beat_k, 0.0, 1.0)
			draw_arc(pos, r * (1.0 + 0.75 * (1.0 - k)), 0, TAU, 48, Color(Game.C_SAFFRON, 0.25 + 0.7 * k), 4.0, true)
			if _flash_t > 0.0:
				var fc: Color = {"perfect": Game.C_GOLD, "good": Game.C_INK, "off": Game.C_DANGER, "fast": Game.C_DANGER}.get(_flash, Game.C_INK)
				fill = fc
		if b.get("glow", false):
			var g := 0.5 + 0.5 * sin(_t * 7.0)
			draw_arc(pos, r * (1.1 + 0.12 * g), 0, TAU, 48, Color(Game.C_GOLD, 0.3 + 0.5 * g), 5.0, true)
		if b.id in ["pause", "camera"]:
			fill = Color(0.03, 0.07, 0.12, 0.55 if not lit else 0.85)
		draw_circle(pos, r, fill)
		draw_arc(pos, r, 0, TAU, 48, Color(1, 1, 1, 0.35 if not lit else 0.9), 2.0, true)
		if picked:
			draw_arc(pos, r + 7.0, 0, TAU, 48, Color(Game.C_INK, 0.8), 3.0, true)
		if keys_shown and not editing:
			_key_cap(pos + Vector2(0, -r), _key_of(String(b.id)))
		var dark = col.get_luminance() > 0.55 and b.id not in ["pause", "camera"]
		var tc := Color("1d1307") if dark else Game.C_INK
		var size: int = b.fs
		if b.id == "pause":
			var u := r / 30.0
			draw_rect(Rect2(pos + Vector2(-9, -11) * u, Vector2(6, 22) * u), Game.C_INK)
			draw_rect(Rect2(pos + Vector2(3, -11) * u, Vector2(6, 22) * u), Game.C_INK)
			continue
		var text: String = b.label
		var w := r * 1.8
		var fit: Array = fit_label(text, font, size, r)
		size = fit[0]
		var lines: PackedStringArray = fit[1]
		var lh := size * 1.1
		var y0 := pos.y - (lines.size() - 1) * lh * 0.5 + size * 0.35
		for i in lines.size():
			draw_string(font, Vector2(pos.x - w * 0.5, y0 + i * lh), lines[i], HORIZONTAL_ALIGNMENT_CENTER, w, size, tc)
	if _stick_id != -1:
		draw_circle(_stick_origin, STICK_R, Color(1, 1, 1, 0.07))
		draw_arc(_stick_origin, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.3), 2.0, true)
		draw_circle(_stick_origin + _stick_vec * STICK_R, 38, Color(Game.C_INK, 0.85))
	elif context in ["raid", "defend"] and not editing:
		# Hint where the stick lives.
		var s := get_viewport_rect().size
		var hx := 170.0 + _insets.x if not Game.settings.left_handed else s.x - 170.0 - _insets.y
		var c := Vector2(hx, s.y - 160)
		draw_arc(c, STICK_R, 0, TAU, 48, Color(1, 1, 1, 0.12), 2.0, true)
		draw_circle(c, 30, Color(1, 1, 1, 0.08))
		if keys_shown:
			_key_cap(c, "WASD")


## The font size, from size down to two thirds of it, and the lines at which a button's words sit inside its circle
## of radius r: the words of Tamil, Telugu or Kannada can run half as long again as the English ones.
func fit_label(text: String, font: Font, size: int, r: float) -> Array:
	var key := "%s|%d|%d" % [text, size, int(r)]
	if _fits.has(key):
		return _fits[key]
	var fs := size
	var lines := _wrap(text, font, fs, r * 1.8)
	while fs > roundi(size * 0.66) and not inside(lines, font, fs, r):
		fs -= 1
		lines = _wrap(text, font, fs, r * 1.8)
	_fits[key] = [fs, lines]
	return _fits[key]


## Whether lines drawn at font size fs, centred as _draw centres them, keep inside a circle of radius r.
static func inside(lines: PackedStringArray, font: Font, fs: int, r: float) -> bool:
	var lh := fs * 1.1
	var edge := r - 3.0
	for i in lines.size():
		var base := -(lines.size() - 1) * lh * 0.5 + fs * 0.35 + i * lh
		var top := base - font.get_ascent(fs) * 0.8
		var bottom := base + font.get_descent(fs) * 0.6
		var half := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
		var room := minf(sqrt(maxf(edge * edge - top * top, 0.0)), sqrt(maxf(edge * edge - bottom * bottom, 0.0)))
		if half > room + 0.5:
			return false
	return true


## The key that does a button's job, as it is printed on the keyboard.
func _key_of(id: String) -> String:
	match id:
		"pause":
			return "P"
		"camera":
			return "C"
		"skip", "cant":
			return "Space"
		"touch", "ankle":
			return "J"
		"kick", "thigh":
			return "K"
		"dodge":
			return "L" if cant_mode else "Space"
		"waist":
			return "L"
		"dubki", "dash":
			return "U"
		"jump":
			return "I"
		"chain":
			return "G"
		"switch":
			return "Tab"
	return ""


## A key's name in a small dark cap, centred on a point (a button's top edge).
func _key_cap(at: Vector2, key: String) -> void:
	if key == "":
		return
	var font: Font = Game.font_bold
	var fs := 14
	var w := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var rect := Rect2(at - Vector2(w * 0.5, 11), Vector2(w, 22))
	draw_style_box(_cap_box, rect)
	draw_string(font, Vector2(rect.position.x, at.y + fs * 0.36), key, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Game.C_INK)


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
