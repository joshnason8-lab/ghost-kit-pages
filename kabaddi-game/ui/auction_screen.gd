extends Control
## The player auction, run like the real thing: auctioneer, paddles, going once and twice,
## bidding wars, record prices, Final Bid Match cards, and an accelerated round.
##
## args.mode: "owner" (League Season: you bid for your franchise) or "career" (you are a lot).

var mode := "career"
var eng: AuctionEngine
var owner_obj   # Season or Career
var _pause := 0.0
var _between := false
var _done := false

var _lot_cat: Label
var _lot_name: Label
var _lot_meta: Label
var _lot_tags: HBoxContainer
var _price: Label
var _leader: Label
var _leader_sw: ColorRect
var _hammer: Label
var _feed: VBoxContainer
var _teams_box: GridContainer
var _team_rows := {}
var _buttons: HBoxContainer
var _bid_btn: Button
var _record: Label
var _fbm_panel: PanelContainer
var _queue: Label


func setup(args: Dictionary) -> void:
	mode = String(args.get("mode", "career"))


func _ready() -> void:
	UI.screen(self)
	if mode == "owner":
		owner_obj = Game.get_season()
	else:
		owner_obj = Game.get_career()
	if owner_obj == null:
		Game.goto_menu()
		return
	eng = owner_obj.make_auction()
	var back := func(): Game.show_screen("res://ui/season_hub.gd" if mode == "owner" else "res://ui/career_hub.gd")
	var yr: int = owner_obj.year if mode == "owner" else owner_obj.season
	var v := UI.page(self, tr("AUCTION"), back, tr("AUCTION_SEASON").format({"n": yr}))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	# Left: the block.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var card := UI.card()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	card.add_child(cv)
	_lot_cat = UI.label("", "EyebrowLabel", 16, Game.C_GOLD)
	_lot_name = UI.label("", "HeaderLabel", 48)
	_lot_meta = UI.label("", "MutedLabel", 19)
	_lot_tags = HBoxContainer.new()
	_lot_tags.add_theme_constant_override("separation", 8)
	cv.add_child(_lot_cat)
	cv.add_child(_lot_name)
	cv.add_child(_lot_meta)
	cv.add_child(_lot_tags)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 22)
	var pv := VBoxContainer.new()
	pv.add_child(UI.label(tr("CURRENT_BID").to_upper(), "EyebrowLabel"))
	_price = UI.label("—", "TitleLabel", 78, Game.C_SAFFRON)
	pv.add_child(_price)
	ph.add_child(pv)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(UI.label(tr("LEADING").to_upper(), "EyebrowLabel"))
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 10)
	_leader_sw = UI.swatch(Color(0, 0, 0, 0), Vector2(10, 42))
	_leader = UI.label("—", "HeaderLabel", 36)
	lr.add_child(_leader_sw)
	lr.add_child(_leader)
	lv.add_child(lr)
	_hammer = UI.label("", "SubLabel", 26, Game.C_GOLD)
	lv.add_child(_hammer)
	ph.add_child(lv)
	cv.add_child(ph)
	left.add_child(card)
	_record = UI.label("", "SubLabel", 22, Game.C_GOLD)
	_record.visible = false
	left.add_child(_record)
	left.add_child(UI.label(tr("AUCTIONEER").to_upper(), "EyebrowLabel"))
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 2)
	left.add_child(_feed)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	left.add_child(_buttons)
	_build_buttons()

	# Right: the franchise tables.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(440, 0)
	cols.add_child(right)
	right.add_child(UI.label("%s · %s · FBM" % [tr("PURSE_LEFT"), tr("SQUAD")], "EyebrowLabel"))
	_teams_box = GridContainer.new()
	_teams_box.columns = 4
	_teams_box.add_theme_constant_override("h_separation", 14)
	_teams_box.add_theme_constant_override("v_separation", 3)
	for id in DB.league_ids:
		var sw := UI.swatch(DB.team(id).c1, Vector2(8, 24))
		var nm := UI.label(id, "SubLabel" if id == eng.user_team else "", 18, Game.C_SAFFRON if id == eng.user_team else Game.C_INK)
		var purse := UI.label("", "", 18, Game.C_MUTED)
		var sq := UI.label("", "", 16, Game.C_MUTED)
		_teams_box.add_child(sw)
		_teams_box.add_child(nm)
		_teams_box.add_child(purse)
		_teams_box.add_child(sq)
		_team_rows[id] = [sw, nm, purse, sq]
	right.add_child(_teams_box)
	right.add_child(UI.label(tr("UP_NEXT").to_upper(), "EyebrowLabel"))
	_queue = UI.wrap("", "MutedLabel", 16)
	right.add_child(_queue)

	_build_fbm()
	_say(tr("AUC_WELCOME").format({"n": eng.lots.size()}))
	_open()


func _build_buttons() -> void:
	for c in _buttons.get_children():
		c.queue_free()
	if _done:
		_buttons.add_child(UI.button(tr("CONTINUE"), true, _leave))
		return
	if mode == "owner":
		_bid_btn = UI.button(tr("AUC_BID"), true, _user_bid)
		_bid_btn.custom_minimum_size = Vector2(300, 70)
		_buttons.add_child(_bid_btn)
		_buttons.add_child(UI.button(tr("AUC_SIM_REST"), false, _finish_all))
	else:
		_buttons.add_child(UI.button(tr("SKIP_TO_MY_LOT"), false, _skip_to_mine))
		_buttons.add_child(UI.button(tr("FINISH_AUCTION"), false, _finish_all))


func _build_fbm() -> void:
	_fbm_panel = PanelContainer.new()
	_fbm_panel.theme_type_variation = "CardPanel"
	_fbm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_fbm_panel.custom_minimum_size = Vector2(560, 0)
	_fbm_panel.position = Vector2(-280, -120)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_fbm_panel.add_child(v)
	var t := UI.label(tr("AUC_FBM_TITLE"), "HeaderLabel", 40, Game.C_GOLD)
	v.add_child(t)
	var body := UI.wrap("", "", 20)
	body.name = "Body"
	v.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UI.button(tr("AUC_FBM_USE"), true, func(): _answer_fbm(true)))
	row.add_child(UI.button(tr("AUC_FBM_PASS"), false, func(): _answer_fbm(false)))
	v.add_child(row)
	_fbm_panel.visible = false
	add_child(_fbm_panel)


func _say(text: String, color := Game.C_INK) -> void:
	var l := UI.label(text, "", 19, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed.add_child(l)
	_feed.move_child(l, 0)
	while _feed.get_child_count() > 5:
		var last := _feed.get_child(_feed.get_child_count() - 1)
		_feed.remove_child(last)
		last.queue_free()
	for i in _feed.get_child_count():
		(_feed.get_child(i) as Label).modulate.a = 1.0 - i * 0.17


func _open() -> void:
	if eng.finished():
		_complete()
		return
	var ev := eng.open_lot()
	var lot: Dictionary = ev.lot
	var p: Dictionary = lot.player
	var role_key: String = {"raider": "ROLE_RAIDER", "defender": "ROLE_DEFENDER", "allrounder": "ROLE_ALLROUNDER"}[p.role]
	var cat_txt: String = tr("AUC_NYP") if lot.cat == "NYP" else tr("CATEGORY").format({"c": lot.cat})
	if int(lot["round"]) == 2:
		cat_txt += " · " + tr("AUC_ACCEL_SHORT")
	_lot_cat.text = ((tr("YOUR_LOT") + " · ") if lot.mine else "") + cat_txt.to_upper()
	_lot_name.text = String(p.name)
	_lot_name.add_theme_color_override("font_color", Game.C_GOLD if lot.mine else Game.C_INK)
	_lot_meta.text = "%s · %s %d · %s %s" % [tr(role_key), tr("OVERALL"), int(lot.ovr), tr("BASE_PRICE"), Game.fmt_money(lot.base)]
	for c in _lot_tags.get_children():
		c.queue_free()
	_lot_tags.add_child(UI.label(DB.moves_line(p), "EyebrowLabel", 15, Game.C_GOLD))
	if String(lot.former) != "":
		_lot_tags.add_child(UI.label(tr("AUC_FORMER").format({"team": String(lot.former)}), "EyebrowLabel", 15, DB.team(lot.former).c1.lightened(0.3)))
	_price.text = Game.fmt_money(lot.base)
	_leader.text = "—"
	_leader_sw.color = Color(0, 0, 0, 0)
	_hammer.text = ""
	_say(tr("AUC_OPEN").format({"name": p.name, "price": Game.fmt_money(lot.base)}), Game.C_MUTED)
	_refresh()


func _refresh() -> void:
	for id in _team_rows:
		var t: Dictionary = eng.teams[id]
		_team_rows[id][2].text = Game.fmt_money(t.purse)
		_team_rows[id][3].text = "%d/%d · %d" % [t.squad.size(), AuctionEngine.SQUAD_MAX, int(t.fbm)]
	var nxt := []
	for i in range(eng.index + 1, mini(eng.index + 7, eng.lots.size())):
		var l: Dictionary = eng.lots[i]
		nxt.append("%s (%s, %d)" % [l.player.name, l.cat, int(l.ovr)])
	_queue.text = "\n".join(nxt)
	if _bid_btn and is_instance_valid(_bid_btn):
		var can := eng.can_bid(eng.user_team)
		_bid_btn.disabled = not can or _between
		_bid_btn.text = tr("AUC_BID") + "  " + Game.fmt_money(eng.next_price())


func _process(delta: float) -> void:
	if eng == null or _done or _fbm_panel.visible:
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0 and _between:
			_between = false
			var ev := eng.next_lot()
			if ev.get("type", "") == "accelerated":
				_say(tr("AUC_ACCEL").format({"n": ev.count}), Game.C_GOLD)
				_pause = 1.6
				_between = true
				return
			_open()
		return
	for ev in eng.step(delta):
		_handle(ev)
	_refresh()


func _handle(ev: Dictionary) -> void:
	match String(ev.type):
		"bid":
			_price.text = Game.fmt_money(ev.price)
			_leader.text = DB.team_name(ev.team)
			_leader_sw.color = DB.team(ev.team).c1
			_hammer.text = ""
			_flash_team(ev.team)
			Sfx.play("bid", -9.0, randf_range(0.95, 1.15))
			if ev.has("war"):
				_say(tr("AUC_WAR").format({"a": ev.war[0], "b": ev.war[1]}), Game.C_MAGENTA.lightened(0.3))
				Sfx.play("roar", -16.0)
			elif randf() < 0.3:
				_say(tr("AUC_BID_LINE").format({"team": DB.team_name(ev.team), "price": Game.fmt_money(ev.price)}))
		"once":
			_hammer.text = tr("AUC_ONCE")
		"twice":
			_hammer.text = tr("AUC_TWICE")
		"fbm_offer":
			var body: Label = _fbm_panel.find_child("Body", true, false)
			body.text = tr("AUC_FBM_BODY").format({"name": eng.current().player.name, "price": Game.fmt_money(ev.price), "team": DB.team_name(eng.leader)})
			_fbm_panel.visible = true
		"fbm":
			_say(tr("AUC_FBM_USED").format({"team": DB.team_name(ev.team)}), Game.C_GOLD)
			Sfx.play("roar", -10.0)
		"sold":
			_hammer.text = tr("AUC_SOLD")
			Sfx.play("gavel", 0.0)
			var lot: Dictionary = ev.lot
			_say(tr("SOLD_TO").format({"team": DB.team_name(ev.team)}) + " · " + Game.fmt_money(ev.price), Game.C_GOOD)
			if ev.get("record", false):
				_record.text = tr("AUC_RECORD").format({"name": lot.player.name, "price": Game.fmt_money(ev.price)})
				_record.visible = true
				Sfx.play("roar", -6.0)
			if lot.mine:
				_say(tr("YOU_SOLD").format({"team": DB.team_name(ev.team), "price": Game.fmt_money(ev.price)}), Game.C_GOLD)
				Sfx.play("roar", -4.0)
			if ev.team == eng.user_team:
				Sfx.play("roar", -8.0)
			_pause = 1.8 if not lot.mine else 3.0
			_between = true
		"unsold":
			_hammer.text = tr("UNSOLD")
			_say(tr("AUC_UNSOLD_LINE").format({"name": ev.lot.player.name}), Game.C_MUTED)
			_pause = 1.2
			_between = true


func _flash_team(id: String) -> void:
	var row: Array = _team_rows.get(id, [])
	if row.is_empty():
		return
	var nm: Label = row[1]
	nm.modulate = Color(2, 2, 2)
	var tw := create_tween()
	tw.tween_property(nm, "modulate", Color.WHITE, 0.5)


func _user_bid() -> void:
	var ev := eng.place_bid(eng.user_team)
	if not ev.is_empty():
		_handle(ev)
		_refresh()


func _answer_fbm(use: bool) -> void:
	_fbm_panel.visible = false
	for ev in eng.answer_fbm(use):
		_handle(ev)


func _skip_to_mine() -> void:
	eng.resolve_all(true)
	_between = false
	_pause = 0.0
	_open()


func _finish_all() -> void:
	eng.resolve_all(false)
	_complete()


func _complete() -> void:
	if _done:
		return
	_done = true
	owner_obj.finish_auction(eng)
	if mode == "owner":
		Game.save_season()
	else:
		Game.save_career()
	_lot_cat.text = tr("AUC_CLOSED").to_upper()
	if mode == "career":
		var c = owner_obj
		_lot_name.text = DB.team_name(c.team)
		_lot_meta.text = tr("YOU_SOLD").format({"team": DB.team_name(c.team), "price": Game.fmt_money(c.price)})
	else:
		var s = owner_obj
		var sq: Array = s.squads[s.team]
		_lot_name.text = "%s · %d" % [tr("SQUAD"), sq.size()]
		var names := []
		for p in sq:
			names.append("%s (%d)" % [p.name, DB.overall(p)])
		_lot_meta.text = ", ".join(names)
		_lot_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if eng.record > 0.0:
		_record.text = tr("AUC_TOP_BUY").format({"name": eng.record_holder, "price": Game.fmt_money(eng.record)})
		_record.visible = true
	_build_buttons()
	_refresh()


func _leave() -> void:
	Game.show_screen("res://ui/season_hub.gd" if mode == "owner" else "res://ui/career_hub.gd")
