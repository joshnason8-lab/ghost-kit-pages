extends Node
## Touch and mouse on the screens, which needs a window (Godot picks no controls under the pointer when headless):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/input_test.tscn
## A page of cards and buttons scrolls when dragged from a button and does not press it; a tap still presses one; a
## fling carries on. And every real page that scrolls scrolls when the drag starts on its words (Kabaddi's How to
## Play did not: its text took the touch). Exits 1 on any failure.

var failures := 0
var checks := 0


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	await _scrolling()
	await _real_pages()
	print("input_test: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scrolling() -> void:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var col := VBoxContainer.new()
	var hits := [0]
	for i in 30:
		var c := UI.card()
		c.add_child(UI.button("Button %d" % i, false, func(): hits[0] += 1))
		col.add_child(c)
	var sc := UI.scroll(col)
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(sc)
	await frames(3)
	await _drag(Vector2(400, 600), Vector2(400, 300))
	check(sc.scroll_vertical > 250, "a drag that starts on a button scrolls the page (%d)" % sc.scroll_vertical)
	check(hits[0] == 0, "a drag does not press the button it started on")
	var target: Button = col.get_child(int(sc.scroll_vertical / 70.0) + 3).get_child(0)
	await _tap(target.get_global_rect().get_center())
	check(hits[0] == 1, "a tap still presses a button in a scrolling page (%d)" % hits[0])
	var before := sc.scroll_vertical
	_mouse(Vector2(400, 600), true)
	for i in 4:
		_move(Vector2(400, 600 - 40 * (i + 1)))
		await frames(1)
	_mouse(Vector2(400, 440), false)
	var lifted := sc.scroll_vertical
	await frames(20)
	check(sc.scroll_vertical > lifted + 20, "a flick carries on (%d -> %d -> %d)" % [before, lifted, sc.scroll_vertical])
	page.queue_free()
	await frames(2)


## Every scrolling page: a drag that starts on a piece of text in it scrolls it.
func _real_pages() -> void:
	Game.settings.language = "en"
	Game.delete_cup()
	var pages := [["res://ui/howto_screen.gd", {"tab": 0}], ["res://ui/howto_screen.gd", {"tab": 1}], ["res://ui/howto_screen.gd", {"tab": 2}],
		["res://ui/settings_screen.gd", {}], ["res://ui/licences_screen.gd", {}], ["res://ui/quick_setup.gd", {}], ["res://ui/cup_screen.gd", {}]]
	for pg in pages:
		var s := Game.show_screen(pg[0], pg[1])
		await frames(6)
		var scrolls := _scrolls(s)
		check(not scrolls.is_empty(), "%s %s has a scrolling box" % pg)
		for sc: ScrollContainer in scrolls:
			if sc.get_v_scroll_bar().max_value <= sc.get_v_scroll_bar().page + 1.0:
				continue
			var at := _text_in(sc)
			check(at != Vector2.INF, "%s %s: there is text to drag on" % pg)
			if at == Vector2.INF:
				continue
			var r := sc.get_global_rect()
			var to := at - Vector2(0, r.size.y * 0.45)
			await _drag(at, to)
			var most := sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page
			check(sc.scroll_vertical >= minf(40.0, most) - 1.0, "%s %s scrolls when dragged on its text (%d of %d)" % [pg[0], pg[1], sc.scroll_vertical, most])


func _scrolls(n: Node) -> Array:
	var out := []
	if n is ScrollContainer and (n as ScrollContainer).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		out.append_array(_scrolls(c))
	return out


## A point on a label or rich text inside the box, in its lower half, so a drag up has room.
func _text_in(sc: ScrollContainer) -> Vector2:
	var r := sc.get_global_rect()
	for n in sc.find_children("*", "Control", true, false):
		if not (n is Label or n is RichTextLabel) or not n.is_visible_in_tree():
			continue
		var t: Control = n
		# The part of the text in the box's lower half (a long licence text fills the whole box).
		var lower := Rect2(r.position + Vector2(0, r.size.y * 0.55), Vector2(r.size.x, r.size.y * 0.45 - 10.0))
		var part := t.get_global_rect().intersection(lower)
		if part.size.x > 4.0 and part.size.y > 4.0:
			return Vector2(part.position.x + minf(20.0, part.size.x * 0.3), part.get_center().y)
	return Vector2.INF


func _drag(from: Vector2, to: Vector2) -> void:
	_move(from, false)
	_mouse(from, true)
	for i in 12:
		_move(from.lerp(to, float(i + 1) / 12.0))
		await frames(1)
	await frames(6)
	_mouse(to, false)
	await frames(2)


func _tap(at: Vector2) -> void:
	_move(at, false)
	_mouse(at, true)
	await frames(1)
	_mouse(at, false)
	await frames(2)


func _mouse(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = at
	e.global_position = at
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.pressed = down
	get_viewport().push_input(e)


func _move(at: Vector2, held := true) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(e)
