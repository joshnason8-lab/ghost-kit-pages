class_name UI
extends RefCounted
## Small builders shared by the menu screens: pages, cards, chips, labels that fit every language.


static func screen(owner: Control, with_backdrop := true) -> void:
	owner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.theme = Game.theme
	if with_backdrop:
		owner.add_child(Backdrop.new())


## A camera cut-out to pretend there is (tests/fit_audit: a 20:9 phone's punch-hole on the left in landscape), in
## canvas units; 0 on a real phone, where the display's safe area says where the cut-out is.
static var sim_cutout := 0.0


## Margins that keep content clear of the screen edges and any camera cut-out, in canvas
## units: x left, y top, z right, w bottom.
static func safe_margins(owner: Control, base := 40.0) -> Vector4:
	var m := Vector4(base, base * 0.6, base, base * 0.55)
	m.x += sim_cutout
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or not owner.is_inside_tree():
		return m
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0:
		return m
	var k := owner.get_viewport_rect().size.x / float(win.x)
	m.x += maxf(0.0, safe.position.x) * k
	m.z += maxf(0.0, screen.x - safe.end.x) * k
	return m


## A margin container filling the owner, inset by the safe margins.
static func frame(owner: Control, base := 40.0) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := safe_margins(owner, base)
	margin.add_theme_constant_override("margin_left", int(m.x))
	margin.add_theme_constant_override("margin_top", int(m.y))
	margin.add_theme_constant_override("margin_right", int(m.z))
	margin.add_theme_constant_override("margin_bottom", int(m.w))
	owner.add_child(margin)
	keep_on_screen(margin)
	return margin


## A safety net for every language and screen: when a page needs more room than the screen has (a row of Tamil
## buttons, a long word that cannot break), the whole page is drawn smaller, just enough to fit, rather than run off
## the edge. Never below 70%; at 100% where it fits, which is everywhere in English.
static func keep_on_screen(frame: Control) -> void:
	var st := {"room": Vector2.ZERO, "k": 1.0, "queued": false, "settling": true}
	var fit := func():
		st.queued = false
		if not is_instance_valid(frame) or not frame.is_inside_tree() or bool(st.settling):
			return
		var room := frame.get_parent_area_size()
		var need := frame.get_combined_minimum_size()
		if room.x <= 0.0 or room.y <= 0.0 or need.x <= 0.0 or need.y <= 0.0:
			return
		if room != st.room:
			st.room = room   # a new screen size (a phone unfolded): fit afresh
			st.k = 1.0
		# Only ever smaller while the screen keeps its size: words wrap less on a page drawn smaller (so wider), which
		# would let it grow again, and wrap more again, back and forth.
		var k := clampf(minf(minf(room.x / need.x, room.y / need.y), float(st.k)), 0.7, 1.0)
		if absf(frame.scale.x - k) < 0.004:
			return
		st.k = k
		frame.scale = Vector2(k, k)
		frame.offset_right = room.x / k - room.x
		frame.offset_bottom = room.y / k - room.y
	var queue := func():
		if not st.queued:
			st.queued = true
			fit.call_deferred()
	frame.minimum_size_changed.connect(queue)
	frame.resized.connect(queue)
	# Not before the page is laid out: until its wrapping text has its width, a paragraph measures a word a line, many
	# times the screen's height, and the page would stay at its smallest.
	var tree := Engine.get_main_loop() as SceneTree
	var settled := func():
		st.settling = false
		queue.call()
	tree.process_frame.connect(func(): tree.process_frame.connect(settled, CONNECT_ONE_SHOT), CONNECT_ONE_SHOT)


## Page body with safe margins and a header (round Back button, eyebrow and title), returns
## the VBox to fill. Extra header content goes in owner.get_meta("header_right").
static func page(owner: Control, title: String, back: Callable = Callable(), eyebrow := "") -> VBoxContainer:
	var margin := frame(owner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	if back.is_valid():
		owner.set_meta("back", back)   # the phone's back button does the same
		head.add_child(round_button("back", back))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -8)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	if eyebrow != "":
		tv.add_child(label(eyebrow.to_upper(), "EyebrowLabel", 15, Game.C_MAGNET))
	tv.add_child(label(title, "HeaderLabel", 46))
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(right)
	owner.set_meta("header_right", right)
	return v


## A round button with an icon, for Back and other header actions.
static func round_button(icon_kind: String, cb: Callable, px := 58.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.94)
	sb.set_corner_radius_all(int(px))
	sb.border_color = Color(Game.C_INK, 0.28)
	sb.set_border_width_all(2)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Game.C_PANEL_HI
	sbh.border_color = Game.C_MAGNET
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := Icon.make(icon_kind, px * 0.46)
	ic.custom_minimum_size = Vector2.ZERO
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := px * 0.27
	ic.offset_left = inset
	ic.offset_top = inset
	ic.offset_right = -inset
	ic.offset_bottom = -inset
	b.add_child(ic)
	b.pressed.connect(Sfx.click)
	b.pressed.connect(cb)
	return b


## Keeps a title on one line where it can: the font shrinks, to 72% of size at most, when the
## words would wrap. If they wrap anyway the lines sit close (the display font leaves a wide gap
## between lines).
static func _fit_line(l: Label, size: int) -> void:
	l.add_theme_constant_override("line_spacing", -roundi(size * 0.22))
	shrink(l, size, 0.72)


## Words made for English in a space made for English: in Tamil, Telugu or Kannada the same words can run half as
## long again. The label's font shrinks, to min_k of size at most, until its text takes no more than lines lines of
## the label's width; past that it wraps as it is set to (and a label with max_lines_visible ends in "…"). It fits
## again whenever the label changes size, and on refit(l) after its text changes.
static func shrink(l: Label, size: int, min_k := 0.75, lines := 1) -> Label:
	if size > 0:
		size = Game.ts(size)
		l.add_theme_font_size_override("font_size", size)
	var state := {"size": size, "key": ""}   # size 0: the label's own, read when it is first fitted
	var fit := func():
		if not is_instance_valid(l):
			return
		var w := l.size.x
		if w <= 0.0 or l.text == "" or not l.is_inside_tree():
			return
		var key := "%s|%d" % [l.text, int(w)]
		if key == state.key:
			return
		state.key = key
		if int(state.size) <= 0:
			state.size = l.get_theme_font_size("font_size")
		var top: int = state.size
		var font := l.get_theme_font("font")
		var text := l.text.to_upper() if l.uppercase else l.text
		var fs := top
		while fs > roundi(top * min_k) and lines_at(font, text, w, fs) > lines:
			fs -= 1
		if l.get_theme_font_size("font_size") != fs:
			l.add_theme_font_size_override("font_size", fs)
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.max_lines_visible > 0:
			# Godot sizes a wrapped label that ends in "…" by the font's own line height, but a line of Kannada,
			# Telugu or Gurmukhi stands taller than that, and the label then hid its last line: room for the lines
			# as they are set.
			var tp := TextParagraph.new()
			tp.add_string(text, font, fs)
			tp.width = w
			tp.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
			var n := mini(tp.get_line_count(), l.max_lines_visible)
			var h := 0.0
			for i in n:
				h += tp.get_line_size(i).y
			h = ceilf(h + maxi(n - 1, 0) * l.get_theme_constant("line_spacing"))
			if absf(l.custom_minimum_size.y - h) > 0.5:
				l.custom_minimum_size.y = h
	l.set_meta("fit", fit)
	l.resized.connect(fit)
	# Its text can change after it is laid out (a price, a team's needs): it fits again when it redraws, once.
	l.draw.connect(func():
		if not state.get("queued", false):
			state.queued = true
			(func():
				state.queued = false
				fit.call()).call_deferred())
	return l


## Fits a label set up with shrink() to its new text.
static func refit(l: Label) -> void:
	if l.has_meta("fit"):
		(l.get_meta("fit") as Callable).call()


## How many lines text takes at width w, wrapped between words (a word too wide for the line counts one more).
static func lines_at(font: Font, text: String, w: float, fs: int) -> int:
	var n := 0
	for para in text.split("\n"):
		if font.get_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			n += 1
			continue
		var tp := TextParagraph.new()
		tp.add_string(para, font, fs)
		tp.width = w
		tp.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
		n += tp.get_line_count()
		# A word wider than the line is broken in the middle when it is shown: count the line it runs on to.
		for i in tp.get_line_count():
			if tp.get_line_width(i) > w + 0.5:
				n += 1
	return n


## A big choice card (a league, a tournament): an emblem, a name and a line or two about it; the chosen one lit gold.
static func option_card(title: String, desc: String, emblem: Control, chosen: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 92)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL_HI if chosen else Game.C_PANEL, 0.95)
	sb.set_corner_radius_all(16)
	sb.border_color = Game.C_GOLD if chosen else Color(1, 1, 1, 0.1)
	sb.set_border_width_all(3 if chosen else 1)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Game.C_PANEL_HI
	sbh.border_color = Game.C_GOLD if chosen else Color(Game.C_GOLD, 0.5)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 16)
	for k in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(k, 10)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	if emblem:
		emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(emblem)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := label(title, "SubLabel", 24, Game.C_GOLD if chosen else Game.C_INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	if desc != "":
		col.add_child(UI.wrap(desc, "MutedLabel", 16))
	h.add_child(col)
	b.add_child(m)
	# The card is as tall as its words need.
	var grow := func():
		b.custom_minimum_size.y = maxf(92.0, m.get_combined_minimum_size().y)
	m.minimum_size_changed.connect(grow)
	b.pressed.connect(func():
		Sfx.click()
		cb.call())
	return b


## A titled card for grouping options, with an optional icon.
static func section(title: String, icon_kind := "") -> Array:
	var c := card()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	if icon_kind != "":
		h.add_child(Icon.make(icon_kind, 26, Game.C_MAGNET))
	h.add_child(label(title, "SubLabel", 24))
	v.add_child(h)
	return [c, v]


## A small rounded tag.
static func pill(text: String, col: Color, filled := false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col if filled else Color(col, 0.16)
	sb.set_corner_radius_all(99)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, "EyebrowLabel", 14, Game.C_ON_ACCENT if filled else col.lightened(0.25)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A labelled rating bar (0..100).
static func stat_bar(name: String, value: float, col := Game.C_MAGNET) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := label(name, "MutedLabel", 15)
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(99)
	bar.add_theme_stylebox_override("fill", fill)
	h.add_child(bar)
	var n := label(str(int(value)), "SubLabel", 15)
	n.custom_minimum_size = Vector2(34, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(n)
	return h


static func label(text: String, variation := "", size := 0, color := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	# Text here is already translated; an upper-cased word that matches a key ("GRAPHICS")
	# must not be translated back.
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", Game.ts(size))
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


static func wrap(text: String, variation := "", size := 0) -> Label:
	var l := label(text, variation, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A label that may run out of room (a name, the details under it): it takes up to LINES lines, wrapping at words,
## and ends in "…" rather than being cut off mid-letter.
static func fit(l: Label, lines := 1) -> Label:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if lines > 1:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Tamil, Telugu, Kannada and Bengali say it in longer words: one more line before the "…".
		if Game.long_words():
			lines += 1
		l.max_lines_visible = lines
	# A little smaller (to 85%) before anything is cut.
	shrink(l, 0, 0.85, lines)
	return l


## Details for under a name, "Striker · Age 24 · 31 kills", that wrap only between them: never inside
## one, and with the separator kept at the end of the line it ends.
static func bits(parts: Array, sep := " · ") -> String:
	var out := PackedStringArray()
	for p in parts:
		for b in String(p).split(sep, false):
			out.append(b.replace(" ", "\u00a0"))
	return (("\u00a0" + sep.lstrip(" ")) if sep.begins_with(" ") else sep).join(out)


static func button(text: String, primary := false, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	if primary:
		b.theme_type_variation = "PrimaryButton"
		b.custom_minimum_size = Vector2(0, 66)
	if cb.is_valid():
		b.pressed.connect(cb)
	b.pressed.connect(Sfx.click)
	return b


## A row of mutually exclusive chips that wraps. on_pick receives the chosen index.
static func chips(labels: Array, selected: int, on_pick: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	_fill_chips(row, labels, selected, on_pick)
	return row


## The same, on one line that never wraps (for short choices in a crowded row).
static func chips_row(labels: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_fill_chips(row, labels, selected, on_pick)
	return row


static func _fill_chips(row: Container, labels: Array, selected: int, on_pick: Callable) -> void:
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := Button.new()
		b.text = String(labels[i])
		b.theme_type_variation = "ChipButton"
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == selected
		b.custom_minimum_size = Vector2(0, 50)
		var idx := i
		b.pressed.connect(func():
			Sfx.click()
			on_pick.call(idx))
		row.add_child(b)


static func field(title: String, content: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(label(title.to_upper(), "EyebrowLabel"))
	v.add_child(content)
	return v


static func card(variation := "CardPanel") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


## A box that scrolls its content up and down, dragged from anywhere on it (DragScroll).
static func scroll(content: Control) -> ScrollContainer:
	var s := DragScroll.new()
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


static func swatch(c: Color, size := Vector2(14, 34)) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.custom_minimum_size = size
	return r


## Difficulty chips with a line explaining what each level changes.
static func difficulty_field(owner: Control) -> VBoxContainer:
	var keys := ["DIFF_ROOKIE", "DIFF_CLUB", "DIFF_ELITE", "DIFF_WORLD"]
	var desc := label(owner.tr(keys[int(Game.settings.difficulty)] + "_DESC"), "MutedLabel", 17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var names := []
	for k in keys:
		names.append(owner.tr(k))
	var box := field(owner.tr("DIFFICULTY"), chips(names, int(Game.settings.difficulty), func(i):
		Game.settings.difficulty = i
		Game.save_settings()
		desc.text = owner.tr(keys[i] + "_DESC")))
	box.add_child(desc)
	return box


## A team's badge: its country's flag, or for one of the club season's invented clubs its crest (ui/crest.gd: no
## real club's crest, store/PLAY_STORE.md).
static func badge(id: String, size := Vector2(30, 20)) -> Control:
	if DB.is_club(id):
		return Crest.make(id, size)
	var t := DB.team(id)
	if not t.is_empty():
		var tr_ := TextureRect.new()
		tr_.texture = Flags.texture(id, int(size.x * 2), int(size.y * 2))
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr_.custom_minimum_size = size
		tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr_
	var c := swatch(t.c1 if not t.is_empty() else Color.GRAY, Vector2(maxf(6, size.x * 0.25), size.y))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A table of any shape: headers, then rows of [team id, cell, cell ...]; the first `gold` places numbered in gold
## (they go through), the last `red` in red (they go down).
static func standings(headers: Array, rows: Array, highlight: String, gold := 0, red := 0, compact := false) -> GridContainer:
	var g := GridContainer.new()
	g.columns = headers.size() + 1
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 1 if compact else 5)
	var fs := 17 if compact else 20
	g.add_child(label("#", "EyebrowLabel"))
	for h in headers:
		g.add_child(label(String(h), "EyebrowLabel"))
	for i in rows.size():
		var r: Array = rows[i]
		var id := String(r[0])
		var hl := id == highlight
		var col := Game.C_MAGNET if hl else Game.C_INK
		var place_col := Game.C_GOLD if i < gold else (Game.C_DANGER if i >= rows.size() - red else Game.C_MUTED)
		g.add_child(label(str(i + 1), "", fs, place_col))
		var nm := HBoxContainer.new()
		nm.add_theme_constant_override("separation", 8)
		nm.add_child(badge(id, Vector2(30, 20)))
		var name_l := fit(label(DB.team_name(id), "SubLabel" if hl else "", fs, col))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.custom_minimum_size = Vector2(120, 0)
		nm.add_child(name_l)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(nm)
		for c in range(1, r.size()):
			g.add_child(label(str(r[c]), "SubLabel" if c == r.size() - 1 else "", fs, col))
	return g


static func signed(n: int) -> String:
	return ("+" if n > 0 else "") + str(n)



## A menu tile: a dark card with a thin edge, a short rule of its colour at the left, the title in the heading face,
## a line of description under it. The menus' big choices are these.
static func note(title: String, desc: String, accent: Color, cb: Callable, big := false) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 84 if not big else 104)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.94)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(Game.C_FRAME, 1.0)
	sb.set_border_width_all(1)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(Game.C_PANEL_HI, 0.97)
	sbh.border_color = Color(Game.C_INK, 0.45)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# The rule: a short line of the tile's colour down its left edge.
	var rule := ColorRect.new()
	rule.color = accent.lerp(Game.C_PANEL, 0.25)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rule.offset_left = 0
	rule.offset_right = 3
	rule.offset_top = 14
	rule.offset_bottom = -14
	b.add_child(rule)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", 22)
	m.add_theme_constant_override("margin_right", 16)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	m.add_child(v)
	var t := label(title, "HeaderLabel", 28 if big else 24, Game.C_INK)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fit_line(t, 28 if big else 24)
	v.add_child(t)
	if desc != "":
		var d := UI.wrap(desc, "MutedLabel", 16)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(d)
	var grow := func():
		b.custom_minimum_size.y = maxf(84.0 if not big else 104.0, m.get_combined_minimum_size().y)
	m.minimum_size_changed.connect(grow)
	b.pressed.connect(Sfx.click)
	b.pressed.connect(cb)
	return b


## A dark outline round light text, for words over the rink or the hall.
static func outline(l: Label, w := 8) -> void:
	l.add_theme_constant_override("outline_size", w)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.85))


## A block of formatted text for a reading page (licences, help, privacy): wraps, takes no touch (a drag on the words
## reaches the page's scroll box).
static func rich(bb: String) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_override("normal_font", Game.font_body)
	rt.add_theme_font_override("bold_font", Game.font_bold)
	rt.add_theme_font_size_override("normal_font_size", Game.ts(16))
	rt.add_theme_font_size_override("bold_font_size", Game.ts(19))
	rt.add_theme_color_override("default_color", Color(Game.C_INK, 0.92))
	rt.text = bb
	return rt


## Text written wrapped in the source as running text: a single line break is a space, a blank line a new paragraph,
## a line that is all a heading ([b]...[/b]) stays on a line of its own, and a line starting "- " starts a new one.
static func flow(text: String) -> String:
	var out := ""
	var prev := ""
	for line in text.strip_edges().split("\n"):
		if line.strip_edges() == "":
			out += "\n\n"
		elif out == "" or out.ends_with("\n"):
			out += line
		elif (prev.begins_with("[b]") and prev.ends_with("[/b]")) or line.begins_with("- "):
			out += "\n" + line
		else:
			out += " " + line
		prev = line.strip_edges()
	return out
