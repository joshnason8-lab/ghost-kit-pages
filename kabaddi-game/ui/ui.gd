class_name UI
extends RefCounted
## Small builders shared by the menu screens.


static func screen(owner: Control, with_backdrop := true) -> void:
	owner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.theme = Game.theme
	if with_backdrop:
		var bg := TextureRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.texture = _backdrop()
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		owner.add_child(bg)


static var _bd: Texture2D = null


static func _backdrop() -> Texture2D:
	if _bd:
		return _bd
	var g := Gradient.new()
	g.set_color(0, Color("17324f"))
	g.set_color(1, Game.C_BG)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.3, 0.2)
	t.fill_to = Vector2(1.1, 1.0)
	t.width = 256
	t.height = 256
	_bd = t
	return t


## Page body with safe margins, returns the VBox to fill.
static func page(owner: Control, title: String, back: Callable = Callable(), eyebrow := "") -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	owner.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	if back.is_valid():
		owner.set_meta("back", back)   # the phone's back button does the same
		var b := button("‹  " + owner.tr("BACK"))
		b.custom_minimum_size = Vector2(130, 56)
		b.pressed.connect(back)
		head.add_child(b)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -6)
	head.add_child(tv)
	if eyebrow != "":
		tv.add_child(label(eyebrow.to_upper(), "EyebrowLabel"))
	tv.add_child(label(title, "HeaderLabel"))
	return v


static func label(text: String, variation := "", size := 0, color := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
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


## A row of mutually exclusive chips. on_pick receives the chosen index.
static func chips(labels: Array, selected: int, on_pick: Callable) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
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
	return row


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
		nm.add_child(badge(r.id, Vector2(30, 20)) if DB.team(r.id).kind == "country" else swatch(DB.team(r.id).c1, Vector2(6, 24)))
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
	h.add_child(badge(f.home, Vector2(30, 20)) if DB.team(f.home).kind == "country" else swatch(DB.team(f.home).c1, Vector2(5, 22)))
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
	h.add_child(badge(f.away, Vector2(30, 20)) if DB.team(f.away).kind == "country" else swatch(DB.team(f.away).c1, Vector2(5, 22)))
	return h
