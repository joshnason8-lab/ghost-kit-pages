extends Control
## Live player auction. Franchises bid lot by lot; your lot comes up partway through.

var career
var auction := {}
var state := {}
var rng := RandomNumberGenerator.new()
var _tick := 0.0
var _pause := 0.6
var _done := false
var _pending_start := false
var _lot_box: VBoxContainer
var _bid_l: Label
var _leader_l: Label
var _leader_sw: ColorRect
var _purses: GridContainer
var _queue: VBoxContainer
var _status: Label
var _buttons: HBoxContainer


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	career = Game.get_career()
	if career == null:
		Game.show_screen("res://ui/career_hub.gd")
		return
	rng.randomize()
	auction = career.build_auction()
	var v := UI.page(self, tr("AUCTION"), func(): Game.show_screen("res://ui/career_hub.gd"), tr("AUCTION_SEASON").format({"n": career.season}))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var card := UI.card()
	_lot_box = VBoxContainer.new()
	_lot_box.add_theme_constant_override("separation", 6)
	card.add_child(_lot_box)
	left.add_child(card)

	var bid_card := UI.card()
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 18)
	var bv := VBoxContainer.new()
	bv.add_child(UI.label(tr("CURRENT_BID").to_upper(), "EyebrowLabel"))
	_bid_l = UI.label("—", "TitleLabel", 72, Game.C_SAFFRON)
	bv.add_child(_bid_l)
	bh.add_child(bv)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(UI.label(tr("LEADING").to_upper(), "EyebrowLabel"))
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	_leader_sw = UI.swatch(Color(0, 0, 0, 0), Vector2(10, 40))
	_leader_l = UI.label("—", "HeaderLabel", 38)
	lrow.add_child(_leader_sw)
	lrow.add_child(_leader_l)
	lv.add_child(lrow)
	bh.add_child(lv)
	bid_card.add_child(bh)
	left.add_child(bid_card)
	_status = UI.wrap("", "SubLabel", 24)
	left.add_child(_status)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	_buttons.add_child(UI.button(tr("SKIP_TO_MY_LOT"), false, _skip_to_mine))
	_buttons.add_child(UI.button(tr("FINISH_AUCTION"), false, _finish_all))
	left.add_child(_buttons)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(430, 0)
	cols.add_child(right)
	right.add_child(UI.label(tr("PURSE_LEFT").to_upper(), "EyebrowLabel"))
	_purses = GridContainer.new()
	_purses.columns = 2
	_purses.add_theme_constant_override("h_separation", 22)
	_purses.add_theme_constant_override("v_separation", 4)
	right.add_child(_purses)
	right.add_child(UI.label(tr("UP_NEXT").to_upper(), "EyebrowLabel"))
	_queue = VBoxContainer.new()
	right.add_child(UI.scroll(_queue))
	_start_lot()


func _lot() -> Dictionary:
	return auction.lots[auction.index]


func _start_lot() -> void:
	if auction.index >= auction.lots.size():
		_complete()
		return
	var lot := _lot()
	state = {"price": float(lot.base), "leader": "", "salt": auction.index * 31 + career.season}
	_pause = 0.9
	for c in _lot_box.get_children():
		c.queue_free()
	var p: Dictionary = lot.player
	var eyebrow := tr("YOUR_LOT") if lot.mine else tr("ON_THE_BLOCK")
	_lot_box.add_child(UI.label(eyebrow.to_upper(), "EyebrowLabel", 0, Game.C_GOLD if lot.mine else Color(0, 0, 0, 0)))
	_lot_box.add_child(UI.label(String(p.name), "HeaderLabel", 48, Game.C_GOLD if lot.mine else Game.C_INK))
	var role_key: String = {"raider": "ROLE_RAIDER", "defender": "ROLE_DEFENDER", "allrounder": "ROLE_ALLROUNDER"}[p.role]
	_lot_box.add_child(UI.label("%s · %s %d · %s · %s %s" % [tr(role_key), tr("OVERALL"), int(lot.ovr), tr("CATEGORY").format({"c": lot.cat}), tr("BASE_PRICE"), Game.fmt_money(lot.base)], "MutedLabel", 19))
	_bid_l.text = Game.fmt_money(lot.base)
	_leader_l.text = "—"
	_leader_sw.color = Color(0, 0, 0, 0)
	_status.text = ""
	_refresh_side()


func _refresh_side() -> void:
	for c in _purses.get_children():
		c.queue_free()
	for id in DB.league_ids:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(UI.swatch(DB.team(id).c1, Vector2(6, 22)))
		h.add_child(UI.label(id, "", 18))
		_purses.add_child(h)
		var l := UI.label(Game.fmt_money(auction.purses[id]), "", 18, Game.C_MUTED)
		_purses.add_child(l)
	for c in _queue.get_children():
		c.queue_free()
	for i in range(auction.index + 1, mini(auction.index + 9, auction.lots.size())):
		var lot: Dictionary = auction.lots[i]
		var t := UI.label("%s · %d · %s" % [lot.player.name, int(lot.ovr), lot.cat], "", 18, Game.C_GOLD if lot.mine else Game.C_MUTED)
		_queue.add_child(t)


func _process(delta: float) -> void:
	if _done or auction.is_empty() or auction.index >= auction.lots.size():
		return
	if _pause > 0.0:
		_pause -= delta
		return
	if _pending_start:
		_pending_start = false
		_start_lot()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.32 if not _lot().mine else 0.5
	var lot := _lot()
	if Career.bid_step(lot, auction.purses, state, rng):
		_bid_l.text = Game.fmt_money(state.price)
		_leader_l.text = DB.team_name(state.leader)
		_leader_sw.color = DB.team(state.leader).c1
		Sfx.play("bid", -10.0, 1.0 + rng.randf() * 0.2)
	else:
		_settle(lot)
		_show_settled(lot)
		auction.index += 1
		if lot.mine:
			_complete()
			return
		_pause = 1.5
		_pending_start = true


func _settle(lot: Dictionary) -> void:
	if state.leader != "":
		lot.sold_to = state.leader
		lot.price = state.price
		auction.purses[state.leader] = float(auction.purses[state.leader]) - float(state.price)


func _show_settled(lot: Dictionary) -> void:
	if lot.sold_to != "":
		_status.text = tr("SOLD_TO").format({"team": DB.team_name(lot.sold_to)}) + " · " + Game.fmt_money(lot.price)
		_status.add_theme_color_override("font_color", Game.C_GOOD)
		Sfx.play("gavel", -2.0)
	else:
		_status.text = tr("UNSOLD")
		_status.add_theme_color_override("font_color", Game.C_MUTED)


func _resolve_instant(lot: Dictionary) -> void:
	state = {"price": float(lot.base), "leader": "", "salt": auction.index * 31 + career.season}
	var guard := 0
	while Career.bid_step(lot, auction.purses, state, rng) and guard < 200:
		guard += 1
	_settle(lot)


func _skip_to_mine() -> void:
	while auction.index < auction.lots.size() and not _lot().mine:
		_resolve_instant(_lot())
		auction.index += 1
	_tick = 0.0
	_start_lot()


func _finish_all() -> void:
	while auction.index < auction.lots.size():
		var lot := _lot()
		_resolve_instant(lot)
		auction.index += 1
		if lot.mine:
			break
	_done = true
	_complete()


func _complete() -> void:
	_done = true
	# Any lots after yours resolve off-screen.
	while auction.index < auction.lots.size():
		_resolve_instant(_lot())
		auction.index += 1
	career.finish_auction(auction)
	Game.save_career()
	var mine := {}
	for lot in auction.lots:
		if lot.mine:
			mine = lot
	for c in _buttons.get_children():
		c.queue_free()
	if mine.sold_to != "":
		_status.text = tr("YOU_SOLD").format({"team": DB.team_name(career.team), "price": Game.fmt_money(career.price)})
		_status.add_theme_color_override("font_color", Game.C_GOLD)
		Sfx.play("roar", -8.0)
	else:
		_status.text = tr("YOU_UNSOLD").format({"team": DB.team_name(career.team)})
	_buttons.add_child(UI.button(tr("CONTINUE"), true, func(): Game.show_screen("res://ui/career_hub.gd")))
