class_name NewsTicker
extends PanelContainer
## The news: a strip of headlines running right to left (newest first) under a NEWS tag, and the two bigger ways a
## story is told, the front page (the round's biggest story, as a card) and breaking news (a story that has to be
## seen, over the screen until it is dismissed).

const SPEED := 72.0   # pixels a second

var items: Array = []
var _clip: Control
var _row: HBoxContainer
var _x := 0.0


static func make(stories: Array) -> NewsTicker:
	var t := NewsTicker.new()
	t.items = stories
	return t


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.09, 0.86)
	sb.set_corner_radius_all(12)
	sb.border_color = Color(Game.C_SAFFRON, 0.4)
	sb.set_border_width_all(1)
	sb.content_margin_left = 6
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(0, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	var tag := UI.pill(tr("NEWS").to_upper(), Game.C_SAFFRON, true)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tag)
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_clip)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 30)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_row)
	for it in items:
		_row.add_child(_item(it))
	_x = 24.0


func _item(it: Dictionary) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := int(it.get("p", 1)) >= 3
	var dot := UI.label("●", "", 13, Game.C_MAGENTA if big else Game.C_GOLD)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(dot)
	hb.add_child(UI.label(News.text(it), "SubLabel" if int(it.get("p", 1)) >= 2 else "", 19, Game.C_INK))
	var w := News.when_text(it)
	if w != "":
		var wl := UI.label(w, "MutedLabel", 15)
		wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(wl)
	return hb


func _process(delta: float) -> void:
	if _row == null or _clip.size.x <= 0.0:
		return
	var w := _row.get_combined_minimum_size().x
	_x -= SPEED * delta
	if _x < -w:
		_x = _clip.size.x   # round again, from the right
	_row.size = _row.get_combined_minimum_size()
	_row.position = Vector2(_x, (_clip.size.y - _row.size.y) * 0.5)


## The front page: the story as a headline card, with the teams' crests. small: a slimmer card for a crowded screen.
static func front_page(item: Dictionary, small := false) -> PanelContainer:
	var p := PanelContainer.new()
	var big := int(item.get("p", 1)) >= 3
	var accent := Game.C_MAGENTA if big else Game.C_GOLD
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.06, 0.1, 0.9)
	sb.set_corner_radius_all(16)
	sb.border_color = accent
	sb.border_width_left = 6
	sb.content_margin_left = 18
	sb.content_margin_right = 16
	sb.content_margin_top = 8 if small else 10
	sb.content_margin_bottom = 8 if small else 12
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UI.pill(TranslationServer.translate("BREAKING" if big else "FRONT_PAGE").to_upper(), accent, true))
	var w := News.when_text(item)
	if w != "":
		var wl := UI.label(w, "MutedLabel", 15)
		wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(wl)
	v.add_child(top)
	var head := UI.label(News.text(item), "HeaderLabel", 26 if small else 34)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_constant_override("line_spacing", -8)
	v.add_child(head)
	var teams: Array = item.get("t", [])
	for id in teams.slice(0, 2):
		if not DB.team(String(id)).is_empty():
			var c := Crest.make(String(id), 40 if small else 54)
			c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(c)
	return p


## Breaking news over the screen: the stories (up to three, the newest first) and Continue, which closes it and
## calls on_close.
static func breaking(owner: Control, stories: Array, on_close: Callable) -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	owner.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("101c2b")
	sb.set_corner_radius_all(18)
	sb.border_color = Game.C_MAGENTA
	sb.set_border_width_all(2)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(820, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	# The red band across the top.
	var band := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Game.C_MAGENTA
	bsb.corner_radius_top_left = 16
	bsb.corner_radius_top_right = 16
	bsb.content_margin_left = 22
	bsb.content_margin_right = 22
	bsb.content_margin_top = 6
	bsb.content_margin_bottom = 6
	band.add_theme_stylebox_override("panel", bsb)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 12)
	band.add_child(bh)
	var live := UI.label("●", "", 22, Color.WHITE)
	bh.add_child(live)
	bh.add_child(UI.label(TranslationServer.translate("BREAKING_NEWS").to_upper(), "HeaderLabel", 34, Color.WHITE))
	v.add_child(band)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	var bm := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		bm.add_theme_constant_override(side, 24)
	bm.add_child(body)
	v.add_child(bm)
	var shown := stories.duplicate()
	shown.reverse()
	shown = shown.slice(0, 3)
	for i in shown.size():
		var it: Dictionary = shown[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var w := News.when_text(it)
		if w != "":
			col.add_child(UI.label(w.to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
		var hl := UI.label(News.text(it), "HeaderLabel" if i == 0 else "SubLabel", 36 if i == 0 else 22)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.add_theme_constant_override("line_spacing", -8)
		col.add_child(hl)
		row.add_child(col)
		if i == 0:
			for id in (it.get("t", []) as Array).slice(0, 2):
				if not DB.team(String(id)).is_empty():
					var c := Crest.make(String(id), 62)
					c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					row.add_child(c)
		body.add_child(row)
	var go := UI.button(TranslationServer.translate("CONTINUE"), true, func():
		layer.queue_free()
		on_close.call())
	go.custom_minimum_size = Vector2(300, 66)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	body.add_child(go)
	# In with a jolt, and the live dot blinking.
	card.pivot_offset = Vector2(410, 120)
	card.scale = Vector2(1.08, 1.08)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var blink := live.create_tween().set_loops()
	blink.tween_property(live, "modulate:a", 0.2, 0.45)
	blink.tween_property(live, "modulate:a", 1.0, 0.45)
	Sfx.play("whoosh", -6.0)
