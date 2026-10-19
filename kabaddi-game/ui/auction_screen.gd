extends Control
## The player auction, run like the real thing: auctioneer, paddles, going once and twice,
## bidding wars, record prices, Final Bid Match cards, and an accelerated round.
##
## Three panels across the screen: the player on the block (with his likeness turning on a
## stand), the bidding stage, and the franchises' purses. When the hammer falls on the last
## lot a summary of your squad slides in, with Continue always on screen.
##
## args.mode: "owner" (League Season: you bid for your franchise) or "career" (you are a lot).

const PURSE_MAX := 500.0
const CAT_COLORS := {"A": Color("ffd27a"), "B": Color("ff9a1f"), "C": Color("5aa9ff"), "D": Color("9db0c7"), "NYP": Color("4cd38a")}

var mode := "career"
var eng: AuctionEngine
var owner_obj   # Season or Career
var _pause := 0.0
var _between := false
var _done := false

# The block.
var _lot_pills: HBoxContainer
var _lot_name: Label
var _lot_meta: Label
var _ovr: Label
var _bars: VBoxContainer
var _sig: Label
var _extra: Label            # age, last season's points or a young player's potential
var _fit_row: HBoxContainer  # how well he fits your squad (League Season)
var _strengths: Label
var _bidders: HBoxContainer
var _portrait_root: Node3D
var _portrait: Athlete = null
var _portrait_sil: TextureRect
# The stage.
var _price: Label
var _leader_box: HBoxContainer
var _hammer: Label
var _record: Label
var _feed: VBoxContainer
var _bid_btn: Button
var _buttons: HBoxContainer
var _buttons2: HBoxContainer
var _max_l: Label
# The board.
var _team_tiles := {}
var _queue: VBoxContainer
var _lot_count: Label
var _purse_l: Label
var _needs_l: Label
var _fbm_panel: PanelContainer
var _t := 0.0


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
	if mode == "owner":
		eng.user_max = owner_obj.shortlist.duplicate()
		eng.auto_bid = bool(owner_obj.auto_bid)
	var back := func(): Game.show_screen("res://ui/season_hub.gd" if mode == "owner" else "res://ui/career_hub.gd")
	var yr: int = owner_obj.year if mode == "owner" else owner_obj.season
	var v := UI.page(self, tr("AUCTION"), back, tr("AUCTION_SEASON").format({"n": yr}))
	var head: HBoxContainer = get_meta("header_right")
	_lot_count = UI.label("", "SubLabel", 20, Game.C_MUTED)
	head.add_child(_lot_count)
	if mode == "owner":
		head.add_child(_needs_card())
		head.add_child(_purse_card())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	cols.add_child(_block_panel())
	cols.add_child(_stage_panel())
	cols.add_child(_board_panel())

	_build_fbm()
	_say(tr("AUC_WELCOME").format({"n": eng.lots.size()}))
	_open()


# ---------------------------------------------------------------- layout

func _panel(ratio: float) -> Array:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = ratio
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.92)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(1, 1, 1, 0.06)
	sb.set_border_width_all(1)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return [p, v, sb]


func _purse_card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.9)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(Game.C_GOLD, 0.45)
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(Crest.make(eng.user_team, 34))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	col.add_child(UI.label(tr("PURSE_LEFT").to_upper(), "EyebrowLabel", 13, Game.C_GOLD))
	_purse_l = UI.label("", "SubLabel", 22)
	col.add_child(_purse_l)
	h.add_child(col)
	return p


## What your squad still needs, beside the purse (League Season).
func _needs_card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.9)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(Game.C_SAFFRON, 0.35)
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	col.add_child(UI.label(tr("NEEDS").to_upper(), "EyebrowLabel", 13, Game.C_SAFFRON))
	_needs_l = UI.label("", "SubLabel", 17)
	_needs_l.custom_minimum_size = Vector2(250, 0)
	UI.fit(_needs_l, 2)
	col.add_child(_needs_l)
	p.add_child(col)
	return p


func _block_panel() -> PanelContainer:
	var pv: Array = _panel(0.85)
	var v: VBoxContainer = pv[1]
	_lot_pills = HBoxContainer.new()
	_lot_pills.add_theme_constant_override("separation", 6)
	v.add_child(_lot_pills)
	# The player's likeness on a turning stand (a pictogram on Low graphics).
	var stand := Control.new()
	stand.custom_minimum_size = Vector2(0, 90)
	stand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(stand)
	if int(Game.settings.graphics) != Game.GFX_LOW:
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stand.add_child(svc)
		var sv := SubViewport.new()
		sv.own_world_3d = true
		sv.transparent_bg = true
		sv.msaa_3d = Viewport.MSAA_2X
		svc.add_child(sv)
		_build_stand(sv)
	else:
		_portrait_sil = TextureRect.new()
		_portrait_sil.texture = UI.pose("auction")
		_portrait_sil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_portrait_sil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_portrait_sil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_portrait_sil.modulate = Color(Game.C_GOLD, 0.5)
		stand.add_child(_portrait_sil)
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 12)
	var ncol := VBoxContainer.new()
	ncol.add_theme_constant_override("separation", -6)
	ncol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lot_name = UI.label("", "HeaderLabel", 32)
	_lot_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lot_meta = UI.label("", "MutedLabel", 17)
	ncol.add_child(_lot_name)
	ncol.add_child(_lot_meta)
	nrow.add_child(ncol)
	_ovr = UI.label("", "TitleLabel", 50, Game.C_GOLD)
	_ovr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nrow.add_child(_ovr)
	v.add_child(nrow)
	_extra = UI.label("", "MutedLabel", 15)
	_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_extra)
	_fit_row = HBoxContainer.new()
	_fit_row.add_theme_constant_override("separation", 4)
	v.add_child(_fit_row)
	_bars = VBoxContainer.new()
	_bars.add_theme_constant_override("separation", 2)
	v.add_child(_bars)
	_sig = UI.label("", "EyebrowLabel", 14, Game.C_GOLD)
	_sig.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_sig)
	_strengths = UI.label("", "", 15, Game.C_GOOD)
	_strengths.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_strengths)
	_bidders = HBoxContainer.new()
	_bidders.add_theme_constant_override("separation", 6)
	v.add_child(_bidders)
	return pv[0]


func _build_stand(sv: SubViewport) -> void:
	_portrait_root = Node3D.new()
	sv.add_child(_portrait_root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("8fa6c4")
	env.environment.ambient_light_energy = 1.0
	_portrait_root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-25), deg_to_rad(35), 0)
	key.light_energy = 1.5
	key.light_color = Color("fff0d8")
	_portrait_root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-10), deg_to_rad(200), 0)
	rim.light_energy = 1.4
	rim.light_color = Game.C_SAFFRON
	_portrait_root.add_child(rim)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.6
	cyl.bottom_radius = 0.66
	cyl.height = 0.08
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("21405f")
	mat.metallic = 0.4
	mat.roughness = 0.4
	disc.material_override = mat
	disc.position = Vector3(0, -0.04, 0)
	_portrait_root.add_child(disc)
	var cam := Camera3D.new()
	cam.fov = 30
	_portrait_root.add_child(cam)
	# Aimed by its transform: the stand is built before it is in the tree, where look_at() cannot work.
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.95, 0) - Vector3(0, 1.1, 3.3)), Vector3(0, 1.1, 3.3))


func _show_portrait(p: Dictionary, former: String) -> void:
	if _portrait_root == null:
		return
	if _portrait and is_instance_valid(_portrait):
		_portrait.queue_free()
	var kit := Color("3b4f6b")
	var trim := Game.C_INK
	if former != "" and not DB.team(former).is_empty():
		kit = DB.team(former).c1
		trim = DB.team(former).c2
	_portrait = Athlete.new()
	_portrait.setup(p, 0, kit, trim, true)
	_portrait_root.add_child(_portrait)
	_portrait.facing = Vector3(0, 0, 1)
	_portrait.lock_facing = true
	_portrait.set_state("idle")


func _stage_panel() -> PanelContainer:
	var pv: Array = _panel(1.15)
	var v: VBoxContainer = pv[1]
	v.add_child(UI.label(tr("CURRENT_BID").to_upper(), "EyebrowLabel", 15))
	_price = UI.label("—", "TitleLabel", 88, Game.C_SAFFRON)
	_price.pivot_offset = Vector2(0, 60)
	v.add_child(_price)
	v.add_child(UI.label(tr("LEADING").to_upper(), "EyebrowLabel", 15))
	_leader_box = HBoxContainer.new()
	_leader_box.add_theme_constant_override("separation", 12)
	_leader_box.custom_minimum_size = Vector2(0, 56)
	v.add_child(_leader_box)
	_hammer = UI.label("", "HeaderLabel", 38, Game.C_GOLD)
	_hammer.pivot_offset = Vector2(60, 30)
	v.add_child(_hammer)
	_record = UI.label("", "SubLabel", 19, Game.C_GOLD)
	_record.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_record.visible = false
	v.add_child(_record)
	_buttons2 = HBoxContainer.new()
	_buttons2.add_theme_constant_override("separation", 10)
	_max_l = UI.label("", "SubLabel", 17, Game.C_SAFFRON)
	_max_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_max_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.fit(_max_l)
	_buttons2.add_child(_max_l)
	v.add_child(_buttons2)
	# The auctioneer, newest line on top.
	var feed_card := PanelContainer.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(0, 0, 0, 0.22)
	fsb.set_corner_radius_all(12)
	fsb.content_margin_left = 14
	fsb.content_margin_right = 14
	fsb.content_margin_top = 8
	fsb.content_margin_bottom = 8
	feed_card.add_theme_stylebox_override("panel", fsb)
	feed_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 4)
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 8)
	fh.add_child(Icon.make("gavel", 20, Game.C_MUTED))
	fh.add_child(UI.label(tr("AUCTIONEER").to_upper(), "EyebrowLabel", 13))
	fv.add_child(fh)
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 2)
	_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Lines that do not fit are clipped rather than pushing the Bid button off screen.
	var fs := ScrollContainer.new()
	fs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	fs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	fs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fs.add_child(_feed)
	fv.add_child(fs)
	fv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_card.add_child(fv)
	feed_card.clip_contents = true
	v.add_child(feed_card)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	v.add_child(_buttons)
	_build_buttons()
	return pv[0]


func _board_panel() -> PanelContainer:
	var pv: Array = _panel(0.95)
	var v: VBoxContainer = pv[1]
	v.add_child(UI.label(tr("AUC_FRANCHISES").to_upper(), "EyebrowLabel", 15))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	for id in DB.league_ids:
		grid.add_child(_team_tile(id))
	v.add_child(grid)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	v.add_child(UI.label(tr("UP_NEXT").to_upper(), "EyebrowLabel", 14))
	_queue = VBoxContainer.new()
	_queue.add_theme_constant_override("separation", 0)
	v.add_child(_queue)
	if mode == "owner":
		var sim := UI.button(tr("AUC_SIM_REST"), false, _finish_all)
		sim.custom_minimum_size = Vector2(0, 50)
		sim.name = "SimRest"
		v.add_child(sim)
	return pv[0]


func _team_tile(id: String) -> PanelContainer:
	var mine := id == eng.user_team
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.18) if not mine else Color(Game.C_SAFFRON, 0.16)
	sb.set_corner_radius_all(10)
	sb.border_color = Game.C_SAFFRON if mine else Color(0, 0, 0, 0)
	sb.set_border_width_all(1 if mine else 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(Crest.make(id, 26))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	var code := UI.label(id, "SubLabel", 16, Game.C_SAFFRON if mine else Game.C_INK)
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(code)
	var purse := UI.label("", "", 15, Game.C_MUTED)
	top.add_child(purse)
	col.add_child(top)
	var bar := ProgressBar.new()
	bar.max_value = PURSE_MAX
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = DB.team(id).c1.lightened(0.2)
	fill.set_corner_radius_all(99)
	bar.add_theme_stylebox_override("fill", fill)
	col.add_child(bar)
	var sq := UI.label("", "MutedLabel", 13)
	col.add_child(sq)
	h.add_child(col)
	_team_tiles[id] = {"panel": p, "purse": purse, "bar": bar, "squad": sq}
	return p


func _build_buttons() -> void:
	for c in _buttons.get_children():
		c.queue_free()
	for c in _buttons2.get_children():
		if c != _max_l:
			c.queue_free()
	_bid_btn = null
	if _done:
		return
	if mode == "owner":
		_bid_btn = UI.button(tr("AUC_BID"), true, _user_bid)
		_bid_btn.custom_minimum_size = Vector2(0, 74)
		_bid_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_buttons.add_child(_bid_btn)
		var nxt := UI.button(tr("NEXT_TARGET"), false, _skip_to_target)
		nxt.custom_minimum_size = Vector2(0, 74)
		nxt.disabled = eng.user_max.is_empty()
		_buttons.add_child(nxt)
		var auto := Button.new()
		auto.text = tr("AUTO_BID_SHORT")
		auto.theme_type_variation = "ChipButton"
		auto.toggle_mode = true
		auto.button_pressed = eng.auto_bid
		auto.custom_minimum_size = Vector2(0, 46)
		auto.toggled.connect(func(on):
			eng.auto_bid = on
			owner_obj.auto_bid = on
			_refresh())
		_buttons2.add_child(auto)
	else:
		_buttons.add_child(UI.button(tr("SKIP_TO_MY_LOT"), false, _skip_to_mine))
		_buttons.add_child(UI.button(tr("FINISH_AUCTION"), false, _finish_all))


func _build_fbm() -> void:
	_fbm_panel = PanelContainer.new()
	_fbm_panel.theme_type_variation = "CardPanel"
	_fbm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_fbm_panel.custom_minimum_size = Vector2(600, 0)
	_fbm_panel.position = Vector2(-300, -130)
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


# ---------------------------------------------------------------- the auction

func _say(text: String, color := Game.C_INK) -> void:
	var l := UI.label(text, "", 17, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feed.add_child(l)
	_feed.move_child(l, 0)
	while _feed.get_child_count() > 4:
		var last := _feed.get_child(_feed.get_child_count() - 1)
		_feed.remove_child(last)
		last.queue_free()
	for i in _feed.get_child_count():
		(_feed.get_child(i) as Label).modulate.a = 1.0 - i * 0.2


func _set_leader(team: String) -> void:
	for c in _leader_box.get_children():
		c.queue_free()
	if team == "":
		_leader_box.add_child(UI.label("—", "HeaderLabel", 36, Game.C_MUTED))
		return
	_leader_box.add_child(Crest.make(team, 52))
	var nm := UI.label(DB.team_name(team), "HeaderLabel", 36, Game.C_SAFFRON if team == eng.user_team else Game.C_INK)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_leader_box.add_child(nm)


func _open() -> void:
	if eng.finished():
		_complete()
		return
	var ev := eng.open_lot()
	var lot: Dictionary = ev.lot
	var p: Dictionary = lot.player
	var role_key: String = {"raider": "ROLE_RAIDER", "defender": "ROLE_DEFENDER", "allrounder": "ROLE_ALLROUNDER"}[p.role]
	for c in _lot_pills.get_children():
		c.queue_free()
	var cat := String(lot.cat)
	var cat_txt: String = tr("AUC_NYP") if cat == "NYP" else tr("CATEGORY").format({"c": cat})
	_lot_pills.add_child(UI.pill(cat_txt.to_upper(), CAT_COLORS.get(cat, Game.C_MUTED), true))
	if int(lot["round"]) == 2:
		_lot_pills.add_child(UI.pill(tr("AUC_ACCEL_SHORT").to_upper(), Game.C_MAGENTA))
	if lot.mine:
		_lot_pills.add_child(UI.pill(tr("YOUR_LOT").to_upper(), Game.C_GOLD))
	_lot_name.text = String(p.name)
	_lot_name.add_theme_color_override("font_color", Game.C_GOLD if lot.mine else Game.C_INK)
	var meta := "%s · %s %s" % [tr(role_key), tr("BASE_PRICE"), Game.fmt_money(lot.base)]
	if String(lot.former) != "":
		meta += " · " + tr("AUC_FORMER").format({"team": String(lot.former)})
	_lot_meta.text = meta
	_ovr.text = str(int(lot.ovr))
	for c in _bars.get_children():
		c.queue_free()
	var a: Dictionary = p.attrs
	var raid_v := (float(a.agility) + float(a.reach) + float(a.speed)) / 3.0
	_bars.add_child(UI.stat_bar(tr("STAT_RAID"), raid_v, Game.C_SAFFRON))
	_bars.add_child(UI.stat_bar(tr("ATTR_TACKLE"), float(a.tackle), Game.C_MAGENTA.lightened(0.15)))
	_bars.add_child(UI.stat_bar(tr("ATTR_SPEED"), float(a.speed), Color("5aa9ff")))
	_bars.add_child(UI.stat_bar(tr("ATTR_STAMINA"), float(a.stamina), Game.C_GOOD))
	_sig.text = DB.moves_line(p)
	_strengths.text = ", ".join(Scout.strengths(p))
	var bits := [tr("AGE_N").format({"n": Scout.age(p)}), Scout.slot_name(p)]
	if mode == "owner":
		var ls: Dictionary = owner_obj.last_stats.get(String(p.id), {})
		if not ls.is_empty():
			bits.append(tr("PTS_LAST_SEASON").format({"n": int(ls.raid) + int(ls.tackle)}))
		elif cat == "NYP":
			var pot := Scout.potential(p)
			bits.append(tr("NYP_POTENTIAL_" + ("HIGH" if pot >= 0.75 else ("FAIR" if pot >= 0.5 else "LOW"))))
	_extra.text = " · ".join(bits)
	for c in _fit_row.get_children():
		c.queue_free()
	for c in _bidders.get_children():
		c.queue_free()
	if mode == "owner":
		var fit := Scout.fit(p, eng.teams[eng.user_team].squad)
		_fit_row.add_child(UI.label(tr("FIT").to_upper(), "EyebrowLabel", 13, Game.C_MUTED))
		for i in 3:
			_fit_row.add_child(Icon.make("star", 18, Game.C_GOLD if i < fit else Color(1, 1, 1, 0.14)))
		var pid := String(p.id)
		if eng.user_max.has(pid):
			_fit_row.add_child(UI.pill(tr("ON_YOUR_LIST").to_upper(), Game.C_SAFFRON, true))
		var keen: Array = eng.likely_bidders(lot)
		if not keen.is_empty():
			_bidders.add_child(UI.label(tr("LIKELY_BIDDERS").to_upper(), "EyebrowLabel", 13, Game.C_MUTED))
			for id in keen:
				_bidders.add_child(Crest.make(String(id), 26))
	_show_portrait(p, String(lot.former))
	_price.text = Game.fmt_money(lot.base)
	_set_leader("")
	_hammer.text = ""
	_say(tr("AUC_OPEN").format({"name": p.name, "price": Game.fmt_money(lot.base)}), Game.C_MUTED)
	_refresh()


func _refresh() -> void:
	for id in _team_tiles:
		var t: Dictionary = eng.teams[id]
		var tile: Dictionary = _team_tiles[id]
		(tile.purse as Label).text = Game.fmt_money(t.purse)
		(tile.bar as ProgressBar).value = float(t.purse)
		(tile.squad as Label).text = "%d/%d · FBM %d" % [t.squad.size(), AuctionEngine.SQUAD_MAX, int(t.fbm)]
	if _purse_l and eng.teams.has(eng.user_team):
		var ut: Dictionary = eng.teams[eng.user_team]
		_purse_l.text = "%s · %d/%d" % [Game.fmt_money(ut.purse), ut.squad.size(), AuctionEngine.SQUAD_MAX]
		if _needs_l:
			_needs_l.text = UI.bits([Scout.needs_text(Scout.needs(ut.squad))], ", ")
	if _max_l and not eng.finished():
		var mx := float(eng.user_max.get(String(eng.current().player.get("id", "")), -1.0))
		_max_l.visible = mx > 0.0
		if mx > 0.0:
			_max_l.text = tr("YOUR_MAX_LINE").format({"price": Game.fmt_money(mx)})
	_lot_count.text = tr("AUC_LOT_OF").format({"n": mini(eng.index + 1, eng.lots.size()), "of": eng.lots.size()})
	for c in _queue.get_children():
		c.queue_free()
	for i in range(eng.index + 1, mini(eng.index + 4, eng.lots.size())):
		var l: Dictionary = eng.lots[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UI.pill(String(l.cat), CAT_COLORS.get(String(l.cat), Game.C_MUTED)))
		if eng.user_max.has(String(l.player.get("id", ""))):
			row.add_child(Icon.make("star", 16, Game.C_SAFFRON))
		row.add_child(UI.label(String(l.player.name), "", 15))
		row.add_child(UI.label(str(int(l.ovr)), "MutedLabel", 15))
		_queue.add_child(row)
	if _bid_btn and is_instance_valid(_bid_btn):
		var can := eng.can_bid(eng.user_team)
		_bid_btn.disabled = not can or _between
		_bid_btn.text = tr("AUC_BID") + "  " + Game.fmt_money(eng.next_price())


func _process(delta: float) -> void:
	_t += delta
	if _portrait and is_instance_valid(_portrait):
		_portrait.rotation.y = PI + sin(_t * 0.6) * 0.5
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


func _pop(c: Control, scale := 1.12) -> void:
	c.scale = Vector2(scale, scale)
	var tw := create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _handle(ev: Dictionary) -> void:
	match String(ev.type):
		"bid":
			_price.text = Game.fmt_money(ev.price)
			_pop(_price)
			_set_leader(ev.team)
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
			_hammer.add_theme_color_override("font_color", Game.C_GOLD)
			_pop(_hammer, 1.2)
		"twice":
			_hammer.text = tr("AUC_TWICE")
			_hammer.add_theme_color_override("font_color", Game.C_SAFFRON)
			_pop(_hammer, 1.25)
		"fbm_offer":
			var body: Label = _fbm_panel.find_child("Body", true, false)
			body.text = tr("AUC_FBM_BODY").format({"name": eng.current().player.name, "price": Game.fmt_money(ev.price), "team": DB.team_name(eng.leader)})
			_fbm_panel.visible = true
		"fbm":
			_say(tr("AUC_FBM_USED").format({"team": DB.team_name(ev.team)}), Game.C_GOLD)
			Sfx.play("roar", -10.0)
		"sold":
			_hammer.text = tr("AUC_SOLD")
			_hammer.add_theme_color_override("font_color", Game.C_GOOD)
			_pop(_hammer, 1.5)
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
			if mode == "owner" and eng.user_max.has(String(lot.player.get("id", ""))):
				if ev.team == eng.user_team:
					_say(tr("TARGET_SIGNED").format({"name": lot.player.name}), Game.C_SAFFRON)
				else:
					_say(tr("TARGET_LOST").format({"name": lot.player.name, "team": DB.team_name(ev.team)}), Game.C_MUTED)
			_pause = 1.8 if not lot.mine else 3.0
			_between = true
		"unsold":
			_hammer.text = tr("UNSOLD")
			_hammer.add_theme_color_override("font_color", Game.C_MUTED)
			_say(tr("AUC_UNSOLD_LINE").format({"name": ev.lot.player.name}), Game.C_MUTED)
			_pause = 1.2
			_between = true


func _flash_team(id: String) -> void:
	var tile: Dictionary = _team_tiles.get(id, {})
	if tile.is_empty():
		return
	var p: Control = tile.panel
	p.modulate = Color(1.8, 1.8, 1.8)
	var tw := create_tween()
	tw.tween_property(p, "modulate", Color.WHITE, 0.5)


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


## On to the next player on your shortlist, the auction played out instantly until then (your auto-bids in).
func _skip_to_target() -> void:
	var cur := eng.current()
	if not cur.is_empty() and cur.status == "open":
		# Finish the lot on the block first.
		var guard := 0
		while eng.stage != "done" and guard < 400:
			guard += 1
			if eng.stage == "fbm_offer":
				eng.answer_fbm(eng.auto_bid and float(eng.user_max.get(String(cur.player.get("id", "")), -1.0)) >= eng.price)
				break
			eng.step(0.5)
		eng.next_lot()
	var wanted: Dictionary = eng.user_max
	eng.resolve_until(func(l): return wanted.has(String(l.player.get("id", ""))) and eng.teams[eng.user_team].squad.size() < AuctionEngine.SQUAD_MAX)
	_between = false
	_pause = 0.0
	if eng.finished():
		_complete()
	else:
		_say(tr("SKIPPED_TO_TARGET"), Game.C_SAFFRON)
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
	_build_buttons()
	_refresh()
	_show_summary()


## The hammer has fallen on the last lot: your squad, the top buy, and Continue, which
## always stays on screen.
func _show_summary() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var m := UI.safe_margins(self, 60)
	var p := PanelContainer.new()
	p.theme_type_variation = "CardPanel"
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = m.x + 40
	p.offset_right = -m.z - 40
	p.offset_top = 36
	p.offset_bottom = -30
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var team_id: String = owner_obj.team if mode == "owner" else String(owner_obj.team)
	if team_id != "":
		head.add_child(Crest.make(team_id, 64))
	var hc := VBoxContainer.new()
	hc.add_theme_constant_override("separation", -6)
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_child(UI.label(tr("AUC_CLOSED").to_upper(), "EyebrowLabel", 16, Game.C_GOLD))
	if mode == "owner":
		hc.add_child(UI.label(tr("AUC_YOUR_SQUAD"), "HeaderLabel", 44))

	else:
		hc.add_child(UI.label(tr("YOU_SOLD").format({"team": DB.team_name(owner_obj.team), "price": Game.fmt_money(owner_obj.price)}), "HeaderLabel", 36))
	head.add_child(hc)
	if mode == "owner":
		var mine: Dictionary = owner_obj.grades.get(owner_obj.team, {})
		if not mine.is_empty():
			var gb := VBoxContainer.new()
			gb.add_theme_constant_override("separation", -10)
			gb.add_child(UI.label(tr("YOUR_GRADE").to_upper(), "EyebrowLabel", 13, Game.C_GOLD))
			gb.add_child(UI.label(String(mine.grade), "TitleLabel", 64, Game.C_GOLD))
			head.add_child(gb)
	if eng.record > 0.0:
		var rec := UI.label(tr("AUC_TOP_BUY").format({"name": eng.record_holder, "price": Game.fmt_money(eng.record)}), "SubLabel", 18, Game.C_GOLD)
		rec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rec.custom_minimum_size = Vector2(320, 0)
		head.add_child(rec)
	if mode == "owner":
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 18)
		cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(cols)
		var sq: Array = owner_obj.squads[owner_obj.team]
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		var sorted := sq.duplicate()
		sorted.sort_custom(func(a, b): return DB.overall(a) > DB.overall(b))
		for pl in sorted:
			grid.add_child(_squad_chip(pl))
		var gs := UI.scroll(grid)
		gs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gs.size_flags_stretch_ratio = 1.1
		cols.add_child(gs)
		cols.add_child(_grades())
	else:
		var sp := Control.new()
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(sp)
	var go := UI.button(tr("CONTINUE"), true, _leave)
	go.custom_minimum_size = Vector2(360, 72)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(go)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.3)


## Every franchise's auction, marked: the grade, and why.
func _grades() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.label(tr("AUCTION_GRADES").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	var g: Dictionary = owner_obj.grades
	var ids: Array = g.keys()
	ids.sort_custom(func(a, b): return int(g[a].rank) < int(g[b].rank))
	for id in ids:
		var r: Dictionary = g[id]
		var mine: bool = id == owner_obj.team
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(Crest.make(String(id), 28))
		var letter := UI.label(String(r.grade), "HeaderLabel", 30, Game.C_GOLD if String(r.grade).begins_with("A") else (Game.C_INK if String(r.grade).begins_with("B") else Game.C_MAGENTA))
		letter.custom_minimum_size = Vector2(44, 0)
		row.add_child(letter)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label(DB.team_name(String(id)), "SubLabel", 15, Game.C_SAFFRON if mine else Game.C_INK))
		# What it spent is all that left its purse after the retentions: the free agents it was topped up with too.
		var spent := "%s %s" % [tr("SPENT"), Game.fmt_money(float(r.spent))]
		if int(r.get("free_agents", 0)) > 0:
			spent += " " + tr("SPENT_FREE_AGENTS").format({"n": int(r.free_agents), "price": Game.fmt_money(owner_obj.FREE_AGENT_PRICE)})
		var line := UI.label("%s · %s · %s %d" % [tr(String(r.note)), spent, tr("RATING"), int(r.rating)], "MutedLabel", 13)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(line)
		row.add_child(col)
		list.add_child(row)
	v.add_child(UI.scroll(list))
	return v


func _squad_chip(pl: Dictionary) -> PanelContainer:
	var c := PanelContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.22)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	c.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	c.add_child(h)
	var ov := UI.label(str(DB.overall(pl)), "HeaderLabel", 32, Game.C_GOLD)
	ov.custom_minimum_size = Vector2(44, 0)
	h.add_child(ov)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.add_child(UI.label(String(pl.name), "SubLabel", 17))
	var role_key: String = {"raider": "ROLE_RAIDER", "defender": "ROLE_DEFENDER", "allrounder": "ROLE_ALLROUNDER"}.get(String(pl.role), "ROLE_RAIDER")
	col.add_child(UI.label(tr(role_key), "MutedLabel", 14))
	h.add_child(col)
	return c


func _leave() -> void:
	Game.show_screen("res://ui/season_hub.gd" if mode == "owner" else "res://ui/career_hub.gd")
