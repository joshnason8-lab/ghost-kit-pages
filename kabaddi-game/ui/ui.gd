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
	return margin


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
		tv.add_child(label(eyebrow.to_upper(), "EyebrowLabel", 15, Game.C_SAFFRON))
	tv.add_child(label(title, "HeaderLabel", 46))
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	right.alignment = BoxContainer.ALIGNMENT_END
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
	sbh.border_color = Game.C_SAFFRON
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


## A big menu tile: accent colour, title, a line of description, a pose pictogram on the
## right and an arrow. tall tiles put the pictogram large behind the text.
static func tile(title: String, desc: String, accent: Color, pose_name: String, cb: Callable, tall := false) -> Button:
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
	var tex := pose(pose_name)
	if tex:
		var art := TextureRect.new()
		art.texture = tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.modulate = Color(accent.lightened(0.3), 0.5 if tall else 0.38)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.anchor_left = 0.42 if not tall else 0.15
		art.anchor_top = 0.08 if not tall else 0.3
		art.offset_right = -10
		art.offset_bottom = 0
		b.add_child(art)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 26
	v.offset_top = 16
	v.offset_right = -18
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var t := label(title, "HeaderLabel", 54 if tall else 40)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var dot = Icon.make("next", 26, accent.lightened(0.2))
	go.add_child(dot)
	v.add_child(go)
	b.pressed.connect(Sfx.click)
	b.pressed.connect(cb)
	return b


## Teams to pick from, filling the screen: crest, name, rating bar.
static func team_grid(owner: Control, ids: Array, columns: int, on_pick: Callable) -> GridContainer:
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
		var nm := label(DB.team_name(id), "SubLabel", 21)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(nm)
		var rating := DB.team_rating(t.squad)
		var sub := owner.tr(String(t.state)) if t.kind != "country" else owner.tr("RATING") + " %d" % rating
		col.add_child(label(sub, "MutedLabel", 15))
		var bar := stat_bar(owner.tr("RATING"), rating, c1.lightened(0.25))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(bar)
		h.add_child(col)
		b.add_child(h)
		var pick: String = id
		b.pressed.connect(func():
			Sfx.click()
			on_pick.call(pick))
		grid.add_child(b)
	return grid


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
		h.add_child(Icon.make(icon_kind, 26, Game.C_SAFFRON))
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
	p.add_child(label(text, "EyebrowLabel", 14, Color("1d1307") if filled else col.lightened(0.2)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## A labelled rating bar (0..100).
static func stat_bar(name: String, value: float, col := Game.C_SAFFRON) -> HBoxContainer:
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
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


static func wrap(text: String, variation := "", size := 0) -> Label:
	var l := label(text, variation, size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


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


static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
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


## Standings table: rows of {id, p, w, d, l, pd, pts}.
static func table(owner: Control, rows: Array, highlight: String) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 6)
	var heads := ["#", owner.tr("COL_TEAM"), owner.tr("COL_P"), owner.tr("COL_W"), owner.tr("COL_D"), owner.tr("COL_L"), owner.tr("COL_PD"), owner.tr("COL_PTS")]
	for h in heads:
		g.add_child(label(h, "EyebrowLabel"))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var hl: bool = r.id == highlight
		var col := Game.C_SAFFRON if hl else Game.C_INK
		g.add_child(label(str(i + 1), "", 20, Game.C_MUTED))
		var nm := HBoxContainer.new()
		nm.add_theme_constant_override("separation", 8)
		nm.add_child(Crest.make(r.id, 26))
		var name_l := label(DB.team_name(r.id), "SubLabel" if hl else "", 20, col)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_child(name_l)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(nm)
		for k in ["p", "w", "d", "l"]:
			g.add_child(label(str(int(r[k])), "", 20, col))
		var pd := int(r.pd)
		g.add_child(label(("+" if pd > 0 else "") + str(pd), "", 20, col))
		g.add_child(label(str(int(r.pts)), "SubLabel", 20, col))
	return g


## One fixture line: "MUM 34 - 29 DEL" or "MUM vs DEL".
static func fixture_line(owner: Control, f: Dictionary, highlight: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var mine: bool = f.home == highlight or f.away == highlight
	var col := Game.C_INK if mine else Game.C_MUTED
	h.add_child(Crest.make(f.home, 30))
	var a := label(DB.team_name(f.home), "", 19, col)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(a)
	var mid := label("%d – %d" % [f.score[0], f.score[1]] if f.played else owner.tr("VS"), "SubLabel", 19, Game.C_SAFFRON if mine else Game.C_INK)
	mid.custom_minimum_size = Vector2(90, 0)
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(mid)
	var b := label(DB.team_name(f.away), "", 19, col)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(b)
	h.add_child(Crest.make(f.away, 30))
	return h
