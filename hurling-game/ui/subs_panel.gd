class_name SubsPanel
extends Control
## Your substitutions, from the pause menu: your fifteen on the pitch with how tired each is, the bench beside them.
## Tap a man on the pitch, then the one to bring on; the change is made at the next break in play (match.gd
## ask_sub). Five a match, three more in extra time; a man sent off or in the sin bin cannot be replaced. Below, who
## makes your changes: the manager (by himself, as the computer's side does) or you.

var m: Node
var _pick: Player = null
var _body: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.03, 1.0)     # opaque: the pause menu is behind it
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sm := UI.safe_margins(self, 28.0)
	margin.add_theme_constant_override("margin_left", int(sm.x))
	margin.add_theme_constant_override("margin_right", int(sm.z))
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	margin.add_child(_body)
	_build()


func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	var k: int = m.user_team
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	head.add_child(UI.round_button("back", func(): close(), 56))
	var title := UI.label(tr("SUBS"), "HeaderLabel", 40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.shrink(title, 40, 0.6, 1)
	head.add_child(title)
	var left: int = m.subs_left(k)
	var count := UI.label(Plural.word("SUBS_LEFT", left) if left > 0 else tr("SUBS_NONE"), "SubLabel", 22, Game.C_GOLD)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count)
	_body.add_child(head)
	var note := UI.wrap(tr("SUBS_PICK") if _pick == null else tr("SUBS_PICKED").format({"name": DB.player_name(_pick.data, true)}), "MutedLabel", 18)
	_body.add_child(note)
	for q in m.subs_waiting(k):
		var due := UI.wrap(tr("SUBS_DUE").format({"on": DB.player_name(q.pd, true), "off": DB.player_name((q.off as Player).data, true)}), "SubLabel", 18)
		due.add_theme_color_override("font_color", Game.C_GOLD)
		_body.add_child(due)
	# The two lists side by side, scrolled together.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	var on := VBoxContainer.new()
	on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	on.add_theme_constant_override("separation", 6)
	var bench := VBoxContainer.new()
	bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bench.add_theme_constant_override("separation", 6)
	cols.add_child(on)
	cols.add_child(bench)
	on.add_child(UI.label(tr("SUBS_ON_PITCH").to_upper(), "EyebrowLabel", 16, Game.C_MUTED))
	bench.add_child(UI.label(tr("SUBS_BENCH").to_upper(), "EyebrowLabel", 16, Game.C_MUTED))
	var players: Array = m.teams[k].players.duplicate()
	players.sort_custom(func(a, b): return (a as Player).pos_num < (b as Player).pos_num)
	for pl in players:
		on.add_child(_pitch_row(pl))
	for pd in m.teams[k].bench:
		bench.add_child(_bench_row(pd))
	var s := UI.scroll(cols)
	_body.add_child(s)
	var auto := UI.field(tr("SUBS_AUTO"), UI.chips_row([tr("SUBS_AUTO_ON"), tr("SUBS_AUTO_OFF")], 0 if bool(Game.settings.get("auto_subs", true)) else 1, func(i):
		Game.settings.auto_subs = i == 0
		Game.save_settings()))
	_body.add_child(auto)


func _pitch_row(pl: Player) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 54)
	b.toggle_mode = true
	b.button_pressed = pl == _pick
	var can := pl.on_pitch() and pl.visible
	b.disabled = not can or m.subs_left(m.user_team) <= 0
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var n := UI.label(str(pl.num), "SubLabel", 20, Game.C_GOLD)
	n.custom_minimum_size.x = 32
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(n)
	var name_text := DB.player_name(pl.data, true)
	if not can:
		name_text += "  ·  " + tr("SUBS_OFF_FIELD")
	var nl := UI.label(name_text, "SubLabel", 20)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(nl, 1)
	h.add_child(nl)
	h.add_child(_legs_bar(pl.freshness()))
	b.pressed.connect(func():
		_pick = pl if _pick != pl else null
		Sfx.click()
		_build.call_deferred())
	return b


func _bench_row(pd: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 54)
	b.disabled = _pick == null or not m.sub_ok(_pick, pd)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var n := UI.label(str(pd.num), "SubLabel", 20, Game.C_GOLD)
	n.custom_minimum_size.x = 32
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(n)
	var nl := UI.label(DB.player_name(pd, true), "SubLabel", 20)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(nl, 1)
	h.add_child(nl)
	var line := UI.label(tr(["LINE_GK", "LINE_FB", "LINE_HB", "LINE_MF", "LINE_HF", "LINE_FF"][clampi(int(pd.line), 0, 5)]), "MutedLabel", 16)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(line)
	b.pressed.connect(func():
		if _pick != null and m.ask_sub(_pick, pd):
			_pick = null
			Sfx.click()
			_build.call_deferred())
	return b


## How much he has left: a bar, green when fresh, gold, then red when spent.
func _legs_bar(fresh: float) -> Control:
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.12)
	back.custom_minimum_size = Vector2(90, 10)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = Color("4caf50") if fresh > 0.66 else (Game.C_GOLD if fresh > 0.4 else Color("d9534f"))
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2.ZERO
	fill.size = Vector2(90.0 * clampf(fresh, 0.05, 1.0), 10)
	back.add_child(fill)
	return back


func close() -> void:
	queue_free()
