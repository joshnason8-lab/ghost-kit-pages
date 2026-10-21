class_name UI
extends RefCounted
## Small builders shared by the menu screens.


static func screen(owner: Control, with_backdrop := true) -> void:
	owner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.theme = Game.theme
	if with_backdrop:
		owner.add_child(Backdrop.new())


## Margins that keep content clear of the screen edges and any camera cut-out, in canvas
## units: x left, y top, z right, w bottom.
static func safe_margins(owner: Control, base := 40.0) -> Vector4:
	var m := Vector4(base, base * 0.6, base, base * 0.55)
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
	var st := {"room": Vector2.ZERO, "k": 1.0, "queued": false}
	var fit := func():
		st.queued = false
		if not is_instance_valid(frame) or not frame.is_inside_tree():
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
	queue.call()


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
		tv.add_child(label(eyebrow.to_upper(), "EyebrowLabel", 15, Game.C_ACCENT))
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
	sb.bg_color = Color(Game.C_PANEL, 0.9)
	sb.set_corner_radius_all(int(px))
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Game.C_PANEL_HI
	sbh.border_color = Game.C_ACCENT
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


static var _poses := {}


## A pictogram of a pose (assets/ui/pose_*.png), white on transparent; tint with modulate.
static func pose(name: String) -> Texture2D:
	if not _poses.has(name):
		var path := "res://assets/ui/pose_%s.png" % name
		_poses[name] = load(path) if ResourceLoader.exists(path) else null
	return _poses[name]


static var _art := {}


## A figure for the menus, already in its colours (assets/ui/art_*.png, from tools/ui_art/import_art.py).
static func art(name: String) -> Texture2D:
	if not _art.has(name):
		var path := "res://assets/ui/art_%s.png" % name
		_art[name] = load(path) if ResourceLoader.exists(path) else null
	return _art[name]


## A big menu tile: accent colour, title, a line of description, a pose pictogram on the
## right and an arrow. tall tiles put the pictogram large behind the text. With figure (art()),
## that figure in its own colours is the tile's background instead: on the right of a small
## tile, the words kept clear of it on the left; across the lower part of a tall one. tag (a
## pill) sits beside the arrow, centred on it.
static func tile(title: String, desc: String, accent: Color, pose_name: String, cb: Callable, tall := false,
		figure := "", tag: Control = null) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.darkened(0.62).lerp(Game.C_PANEL, 0.35), 0.93)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(accent, 0.55)
	sb.border_width_left = 5
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(accent.darkened(0.5).lerp(Game.C_PANEL_HI, 0.3), 0.98)
	sbh.border_color = accent
	sbh.set_border_width_all(2)
	sbh.border_width_left = 6
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var fig := art(figure) if figure != "" else null
	var tex := pose(pose_name) if fig == null else null
	if fig:
		var bg := TextureRect.new()
		bg.texture = fig
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.modulate = Color(1, 1, 1, 0.92)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		if tall:
			bg.anchor_left = -0.03
			bg.anchor_right = 1.05
			bg.anchor_top = 0.27
			bg.anchor_bottom = 0.9
		else:
			bg.anchor_left = 0.53
			bg.anchor_right = 1.07
			bg.anchor_top = 0.04
			bg.anchor_bottom = 0.98
		b.add_child(bg)
	elif tex:
		var art_rect := TextureRect.new()
		art_rect.texture = tex
		art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_rect.modulate = Color(accent.lightened(0.3), 0.5 if tall else 0.38)
		art_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		art_rect.anchor_left = 0.42 if not tall else 0.15
		art_rect.anchor_top = 0.08 if not tall else 0.3
		art_rect.offset_right = -10
		art_rect.offset_bottom = 0
		b.add_child(art_rect)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 26
	v.offset_top = 16
	v.offset_right = -18
	v.offset_bottom = -14
	if fig and not tall:
		v.anchor_right = 0.53   # the words on the left, the figure on the right
		v.offset_right = 0
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := label(title, "HeaderLabel", 54 if tall else 40)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fit_line(t, 54 if tall else 40)
	v.add_child(t)
	var d := label(desc, "", 17, Color(Game.C_INK, 0.78))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.custom_minimum_size = Vector2(0, 0)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dw := MarginContainer.new()
	dw.add_theme_constant_override("margin_right", 0)
	dw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dw.add_child(d)
	v.add_child(dw)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	var go := HBoxContainer.new()
	go.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go.add_theme_constant_override("separation", 10)
	var dot = Icon.make("next", 26, accent.lightened(0.2))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.add_child(dot)
	if tag:
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		go.add_child(tag)
	v.add_child(go)
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


## How many lines text takes at width w, wrapped between words.
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
	return n


## Teams to pick from, filling the screen: crest, name, rating bar, and a tag (a pill) for any team in tags.
static func team_grid(owner: Control, ids: Array, columns: int, on_pick: Callable, tags := {}) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for id in ids:
		var t := DB.team(id)
		var c1: Color = t.c1
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 96)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(c1.darkened(0.72).lerp(Game.C_PANEL, 0.35), 0.95)
		sb.set_corner_radius_all(16)
		sb.border_color = Color(c1, 0.7)
		sb.border_width_bottom = 4
		var sbh: StyleBoxFlat = sb.duplicate()
		sbh.bg_color = Color(c1.darkened(0.55).lerp(Game.C_PANEL_HI, 0.3), 1.0)
		sbh.border_color = c1.lightened(0.2)
		sbh.set_border_width_all(2)
		sbh.border_width_bottom = 5
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 14
		h.offset_right = -14
		h.add_theme_constant_override("separation", 14)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cr := Crest.make(id, 58)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cr)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The name has the card's width to itself, and wraps between its words, never inside one ("Argent-ina" with a
		# tag beside it on a 16:9 phone).
		var nm := label(DB.team_name(id), "SubLabel", 21)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD
		col.add_child(nm)
		# Under it, a tag and a franchise's state (a country's rating is on the bar).
		if tags.has(id):
			var tag: Control = tags[id]
			tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			col.add_child(tag)
		if t.kind != "country":
			col.add_child(label(owner.tr(String(t.home)), "MutedLabel", 15))
		var rating := DB.team_rating(id)
		var bar := stat_bar(owner.tr("RATING"), rating, c1.lightened(0.25))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(bar)
		h.add_child(col)
		b.add_child(h)
		# As tall as its lines need (a long name over two lines, the town, the rating).
		var grow := func():
			b.custom_minimum_size.y = maxf(96.0, h.get_combined_minimum_size().y + 16.0)
		h.minimum_size_changed.connect(grow)
		grow.call()
		var pick: String = id
		b.pressed.connect(func():
			Sfx.click()
			on_pick.call(pick))
		grid.add_child(b)
	return grid


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


## The layout of a "pick" page: the choices in a column on the left, a big panel on the right (its title, chips beside
## it, and a scrolling grid under them) filling the rest of the screen. Returns [left column, right panel's head row,
## right panel's body].
static func pick_layout(v: VBoxContainer, title: String) -> Array:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.custom_minimum_size = Vector2(400, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.62
	cols.add_child(left)
	var panel := card()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	panel.add_child(pv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	pv.add_child(head)
	var t := label(title.to_upper(), "EyebrowLabel", 18, Game.C_ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(t)
	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(body)
	return [left, head, body]


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
		h.add_child(Icon.make(icon_kind, 26, Game.C_ACCENT))
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
	p.add_child(label(text, "EyebrowLabel", 14, Game.C_ON_ACCENT if filled else col.lightened(0.2)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A labelled rating bar (0..100).
static func stat_bar(name: String, value: float, col := Game.C_ACCENT) -> HBoxContainer:
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
	var keys := ["DIFF_EASY", "DIFF_NORMAL", "DIFF_PRO", "DIFF_LEGEND"]
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


## A team's badge: the flag for a country, colour bars for a franchise.
static func badge(id: String, size := Vector2(30, 20)) -> Control:
	var t := DB.team(id)
	if not t.is_empty() and t.kind == "country":
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


## Team picker built on OptionButton with colour icons.
static func team_picker(ids: Array, selected: String, on_pick: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(320, 58)
	o.fit_to_longest_item = false
	for i in ids.size():
		var t := DB.team(ids[i])
		var icon: Texture2D
		if t.kind == "country":
			icon = Flags.texture(ids[i], 42, 28)
		else:
			var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
			img.fill(t.c1)
			icon = ImageTexture.create_from_image(img)
		o.add_icon_item(icon, DB.team_name(ids[i]), i)
		if ids[i] == selected:
			o.select(i)
	o.item_selected.connect(func(i): on_pick.call(ids[i]))
	return o


## Standings table: rows of {id, p, w, l, sd, pd, pts} (played, won, lost, set difference, point difference, table
## points). compact: smaller rows, for two tables on one screen.
static func table(owner: Control, rows: Array, highlight: String, compact := false, cut := 0) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 1 if compact else 6)
	var fs := 18 if compact else 20
	var heads := ["#", owner.tr("COL_TEAM"), owner.tr("COL_P"), owner.tr("COL_W"), owner.tr("COL_L"), owner.tr("COL_SD"), owner.tr("COL_PD"), owner.tr("COL_PTS")]
	for h in heads:
		g.add_child(label(h, "EyebrowLabel"))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var hl: bool = r.id == highlight
		var col := Game.C_ACCENT if hl else Game.C_INK
		# The places that go through (cut: the top so many) get a gold number.
		g.add_child(label(str(i + 1), "", fs, Game.C_GOLD if i < cut else Game.C_MUTED))
		var nm := HBoxContainer.new()
		nm.add_theme_constant_override("separation", 8)
		nm.add_child(Crest.make(r.id, 22 if compact else 26))
		var name_l := fit(label(DB.team_name(r.id), "SubLabel" if hl else "", fs, col))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.custom_minimum_size = Vector2(120, 0)
		nm.add_child(name_l)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(nm)
		for k in ["p", "w", "l"]:
			g.add_child(label(str(int(r[k])), "", fs, col))
		for k in ["sd", "pd"]:
			var d := int(r[k])
			g.add_child(label(("+" if d > 0 else "") + str(d), "", fs, col))
		g.add_child(label(str(int(r.pts)), "SubLabel", fs, col))
	return g


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
		var col := Game.C_ACCENT if hl else Game.C_INK
		var place_col := Game.C_GOLD if i < gold else (Game.C_DANGER if i >= rows.size() - red else Game.C_MUTED)
		g.add_child(label(str(i + 1), "", fs, place_col))
		var nm := HBoxContainer.new()
		nm.add_theme_constant_override("separation", 8)
		nm.add_child(Crest.make(id, 22 if compact else 26))
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


## One fixture line, in sets: "Bangkok 2 – 1 Selangor", or "Bangkok vs Selangor".
static func fixture_line(owner: Control, f: Dictionary, highlight: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var mine: bool = f.home == highlight or f.away == highlight
	var col := Game.C_INK if mine else Game.C_MUTED
	h.add_child(Crest.make(f.home, 30))
	var a := fit(label(DB.team_name(f.home), "", 18, col), 2)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.custom_minimum_size = Vector2(90, 0)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(a)
	var mid := label("%d – %d" % [f.sets[0], f.sets[1]] if f.played else owner.tr("VS"), "SubLabel", 19, Game.C_ACCENT if mine else Game.C_INK)
	mid.custom_minimum_size = Vector2(70, 0)
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(mid)
	var b := fit(label(DB.team_name(f.away), "", 18, col), 2)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(90, 0)
	h.add_child(b)
	h.add_child(Crest.make(f.away, 30))
	return h
