extends Control
## The war room, before the auction: your squad after retentions and the places still to fill, every player on
## the auction list with how well he would fit (stars), his age, last season's points and his base price, a
## shortlist with the most you will pay for each, and what the other franchises have to spend and need.

const CAT_COLORS := {"A": Color("ffd27a"), "B": Color("ff9a1f"), "C": Color("5aa9ff"), "D": Color("9db0c7"), "NYP": Color("4cd38a")}

var season
var eng: AuctionEngine
var _list: VBoxContainer
var _filter := 0            # 0 all, 1 raiders, 2 all-rounders, 3 defenders, 4 shortlist
var _sl_count: Label


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	season = Game.get_season()
	if season == null:
		Game.goto_menu()
		return
	eng = season.make_auction()
	var v := UI.page(self, tr("WAR_ROOM"), func(): Game.show_screen("res://ui/season_hub.gd"), tr("AUCTION_SEASON").format({"n": season.year}))
	var head: HBoxContainer = get_meta("header_right")
	var ut: Dictionary = eng.teams[season.team]
	head.add_child(UI.pill(tr("PURSE_LEFT").to_upper() + "  " + Game.fmt_money(float(ut.purse)), Game.C_GOLD, true))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	cols.add_child(_squad_panel())
	cols.add_child(_list_panel())
	cols.add_child(_rivals_panel())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	var auto := Button.new()
	auto.text = tr("AUTO_BID")
	auto.theme_type_variation = "ChipButton"
	auto.toggle_mode = true
	auto.button_pressed = bool(season.auto_bid)
	auto.custom_minimum_size = Vector2(0, 52)
	auto.toggled.connect(func(on):
		season.auto_bid = on
		Game.save_season())
	foot.add_child(auto)
	var note := UI.label(tr("AUTO_BID_NOTE"), "MutedLabel", 15)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(note)
	var go := UI.button(tr("START_AUCTION"), true, func():
		Game.save_season()
		Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"}))
	go.custom_minimum_size = Vector2(340, 70)
	foot.add_child(go)
	v.add_child(foot)
	_fill_list()


func _panel(ratio: float) -> Array:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = ratio
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.92)
	sb.set_corner_radius_all(16)
	sb.border_color = Color(1, 1, 1, 0.06)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return [p, v]


## Your squad after retentions, and the gaps.
func _squad_panel() -> PanelContainer:
	var pv := _panel(0.8)
	var v: VBoxContainer = pv[1]
	var sq: Array = eng.teams[season.team].squad
	v.add_child(UI.label(tr("YOUR_RETAINED").format({"n": sq.size()}).to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	for p in sq:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var ov := UI.label(str(DB.overall(p)), "SubLabel", 17, Game.C_GOLD)
		ov.custom_minimum_size = Vector2(28, 0)
		h.add_child(ov)
		var nm := UI.label(String(p.name), "", 16)
		UI.fit(nm)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(UI.label(Scout.slot_name(p), "MutedLabel", 14))
		list.add_child(h)
	if sq.is_empty():
		list.add_child(UI.label(tr("NO_RETENTIONS"), "MutedLabel", 15))
	v.add_child(list)
	var n := Scout.needs(sq)
	v.add_child(UI.label(tr("NEEDS").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
	var nt := UI.label(Scout.needs_text(n), "SubLabel", 17, Game.C_SAFFRON)
	nt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nt)
	var have := {"raider": 0, "allrounder": 0, "corner": 0, "cover": 0}
	for p in sq:
		have[Scout.slot(p)] += 1
	for s in Scout.SLOTS:
		v.add_child(UI.stat_bar(tr(Scout.SLOT_KEYS[s] + "_PL"), 100.0 * have[s] / float(Scout.SHAPE[s]), Game.C_GOOD if have[s] >= int(Scout.SHAPE[s]) else Game.C_SAFFRON))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	var how := UI.label(tr("WAR_ROOM_HOW"), "MutedLabel", 14)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(how)
	return pv[0]


## The auction list: every lot in the order it comes up.
func _list_panel() -> PanelContainer:
	var pv := _panel(1.6)
	var v: VBoxContainer = pv[1]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.add_child(UI.label(tr("AUCTION_LIST").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
	_sl_count = UI.label("", "MutedLabel", 14)
	_sl_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_sl_count)
	v.add_child(top)
	v.add_child(UI.chips_row([tr("FILTER_ALL"), tr("ROLE_RAIDER"), tr("ROLE_ALLROUNDER"), tr("ROLE_DEFENDER"), tr("SHORTLIST")], _filter, func(i):
		_filter = i
		_fill_list()))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	v.add_child(UI.scroll(_list))
	return pv[0]


func _fill_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var sq: Array = eng.teams[season.team].squad
	var shown := 0
	for l in eng.lots:
		var p: Dictionary = l.player
		var pid := String(p.id)
		var role := String(p.role)
		if (_filter == 1 and role != "raider") or (_filter == 2 and role != "allrounder") or (_filter == 3 and role != "defender") \
				or (_filter == 4 and not season.shortlist.has(pid)):
			continue
		_list.add_child(_lot_row(l, sq))
		shown += 1
	if shown == 0:
		_list.add_child(UI.label(tr("SHORTLIST_EMPTY") if _filter == 4 else "—", "MutedLabel", 16))
	_sl_count.text = tr("SHORTLIST_N").format({"n": season.shortlist.size()})


func _lot_row(l: Dictionary, sq: Array) -> PanelContainer:
	var p: Dictionary = l.player
	var pid := String(p.id)
	var on: bool = season.shortlist.has(pid)
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_SAFFRON, 0.12) if on else Color(0, 0, 0, 0.2)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(Game.C_SAFFRON, 0.7) if on else Color(0, 0, 0, 0)
	sb.set_border_width_all(1 if on else 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var cat := String(l.cat)
	var pill := UI.pill(cat, CAT_COLORS.get(cat, Game.C_MUTED), true)
	pill.custom_minimum_size = Vector2(40, 0)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pill)
	# His rating, and under it how well he fits (leaving the row's width to what is known about him).
	var badge := VBoxContainer.new()
	badge.add_theme_constant_override("separation", -2)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ov := UI.label(str(int(l.ovr)), "HeaderLabel", 28, Game.C_GOLD)
	ov.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(ov)
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 0)
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	var fit := Scout.fit(p, sq)
	for i in 3:
		stars.add_child(Icon.make("star", 12, Game.C_GOLD if i < fit else Color(1, 1, 1, 0.14)))
	badge.add_child(stars)
	h.add_child(badge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(String(p.name), "SubLabel", 16)
	UI.fit(nm)
	col.add_child(nm)
	var bits := [PlayerCard.line(p)]
	var ls: Dictionary = season.last_stats.get(pid, {})
	if not ls.is_empty():
		bits.append(tr("PTS_LAST_SEASON").format({"n": int(ls.raid) + int(ls.tackle)}))
	elif cat == "NYP":
		bits.append(tr("NYP_POTENTIAL_" + _pot_word(p)))
	if String(l.former) != "":
		bits.append(String(l.former))
	bits.append(tr("LIKELY_PRICE").format({"price": Game.fmt_money(snappedf(eng.estimate(l), 1.0))}))
	# Wrapped anywhere (the row is narrow), but never starting a line with a separator.
	var info := UI.label(" · ".join(bits).replace(" · ", "\u00a0· "), "MutedLabel", 13)
	UI.fit(info, 2)
	col.add_child(info)
	var st := Scout.strengths(p)
	if not st.is_empty():
		var sl := UI.label(UI.bits(st, ", "), "", 13, Color(Game.C_GOOD, 0.9))
		UI.fit(sl, 2)
		col.add_child(sl)
	h.add_child(col)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.custom_minimum_size = Vector2(136, 0)
	if on:
		var step := HBoxContainer.new()
		step.add_theme_constant_override("separation", 4)
		step.alignment = BoxContainer.ALIGNMENT_END
		var mx := float(season.shortlist[pid])
		step.add_child(_small("–", func(): _set_max(pid, maxf(float(l.base), mx - AuctionEngine.increment(mx - 1.0)))))
		var ml := UI.label(Game.fmt_money(mx), "SubLabel", 15, Game.C_SAFFRON)
		ml.custom_minimum_size = Vector2(58, 0)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		step.add_child(ml)
		step.add_child(_small("+", func(): _set_max(pid, mx + AuctionEngine.increment(mx))))
		right.add_child(step)
		var mlab := UI.label(tr("YOUR_MAX"), "EyebrowLabel", 11, Game.C_MUTED)
		mlab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(mlab)
	else:
		var bl := UI.label(Game.fmt_money(float(l.base)), "SubLabel", 15)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(bl)
		var blab := UI.label(tr("BASE_PRICE"), "EyebrowLabel", 11, Game.C_MUTED)
		blab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		right.add_child(blab)
	h.add_child(right)
	var pin := Button.new()
	pin.custom_minimum_size = Vector2(42, 48)
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pin.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	pin.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	pin.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	pin.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ic := Icon.make("star", 30, Game.C_SAFFRON if on else Color(1, 1, 1, 0.3))
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 6
	ic.offset_top = 9
	ic.offset_right = -6
	ic.offset_bottom = -9
	pin.add_child(ic)
	pin.pressed.connect(Sfx.click)
	pin.pressed.connect(func(): _pin(l))
	h.add_child(pin)
	return row


func _pot_word(p: Dictionary) -> String:
	var pot := Scout.potential(p)
	return "HIGH" if pot >= 0.75 else ("FAIR" if pot >= 0.5 else "LOW")


func _small(text: String, cb: Callable) -> Button:
	var b := UI.button(text, false, cb)
	b.custom_minimum_size = Vector2(36, 40)
	return b


## On or off the shortlist. On, his price starts at what he is worth on the open market, rounded up.
func _pin(l: Dictionary) -> void:
	var pid := String(l.player.id)
	if season.shortlist.has(pid):
		season.shortlist.erase(pid)
	else:
		# What it will likely take, rounded up, as far as you can afford.
		var want := ceilf((eng.estimate(l) + 1.0) / 5.0) * 5.0
		season.shortlist[pid] = clampf(want, float(l.base), maxf(float(l.base), eng.can_spend(season.team)))
	Game.save_season()
	_fill_list()


func _set_max(pid: String, v: float) -> void:
	season.shortlist[pid] = snappedf(v, 0.5)
	Game.save_season()
	_fill_list()


## What the other franchises have to spend, how many they have, and what they need.
func _rivals_panel() -> PanelContainer:
	var pv := _panel(0.85)
	var v: VBoxContainer = pv[1]
	v.add_child(UI.label(tr("RIVALS").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	var ids: Array = DB.league_ids.duplicate()
	ids.erase(season.team)
	ids.sort_custom(func(a, b): return float(eng.teams[a].purse) > float(eng.teams[b].purse))
	for id in ids:
		var t: Dictionary = eng.teams[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var cr := Crest.make(id, 28)
		cr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(cr)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var top := HBoxContainer.new()
		var nm := UI.label(id, "SubLabel", 15)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nm)
		top.add_child(UI.label("%s · %d" % [Game.fmt_money(float(t.purse)), t.squad.size()], "", 13, Game.C_GOLD))
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(10, 0)   # clear of the scroll bar
		top.add_child(pad)
		col.add_child(top)
		var need := UI.label(Scout.needs_text(Scout.needs(t.squad)), "MutedLabel", 12)
		need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(need)
		row.add_child(col)
		list.add_child(row)
	v.add_child(UI.scroll(list))
	return pv[0]
