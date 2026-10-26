extends Control
## The Nations Cup: pick your country; then the two pools' tables, your next match (play it or let it be played),
## the semi-finals, the bronze-medal match and the final; at the end the medals.


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var cup = Game.get_cup()
	if cup == null:
		_pick()
	else:
		_hub(cup)


func _pick() -> void:
	var v := UI.page(self, tr("MENU_CUP"), func(): Game.goto_menu(), tr("CUP_PICK"))
	v.add_child(UI.wrap(tr("CUP_ABOUT"), "MutedLabel", 18))
	var box := VBoxContainer.new()
	v.add_child(UI.scroll(box))
	box.add_child(UI.team_grid(self, DB.team_ids(), 3, func(id):
		Game.new_cup(id)
		Game.show_screen("res://ui/cup_screen.gd")))


func _hub(cup) -> void:
	var v := UI.page(self, tr("MENU_CUP"), func(): Game.goto_menu(), tr("STAGE_" + String(cup.stage).to_upper()))
	var right: HBoxContainer = get_meta("header_right")
	right.add_child(UI.button(tr("CUP_NEW"), false, func():
		Game.delete_cup()
		Game.show_screen("res://ui/cup_screen.gd")))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(body))
	if cup.stage == "done":
		body.add_child(_medals(cup))
	else:
		var nm: Dictionary = cup.next_user_match()
		var card := UI.card()
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		card.add_child(h)
		if nm.is_empty():
			h.add_child(UI.wrap(tr("CUP_OUT"), "SubLabel", 22))
			h.add_child(UI.button(tr("CUP_PLAY_ON"), true, func():
				cup.advance()
				Game.save_cup()
				Game.show_screen("res://ui/cup_screen.gd")))
		else:
			h.add_child(UI.badge(nm.home, Vector2(48, 32)))
			var mid := VBoxContainer.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid.add_child(UI.label(_stage_name(nm).to_upper(), "EyebrowLabel", 14, Game.C_ACCENT))
			mid.add_child(UI.fit(UI.label("%s %s %s" % [DB.team_name(nm.home), tr("VS"), DB.team_name(nm.away)], "SubLabel", 24), 2))
			h.add_child(mid)
			h.add_child(UI.badge(nm.away, Vector2(48, 32)))
			var bv := VBoxContainer.new()
			bv.add_child(UI.button(tr("PLAY"), true, func(): _play(cup, nm)))
			bv.add_child(UI.button(tr("SIMULATE"), false, func():
				cup.sim_next()
				Game.save_cup()
				Game.show_screen("res://ui/cup_screen.gd")))
			h.add_child(bv)
		body.add_child(card)
	if not cup.knockout.is_empty():
		var kc := UI.card()
		var kv := VBoxContainer.new()
		kv.add_theme_constant_override("separation", 8)
		kc.add_child(kv)
		kv.add_child(UI.label(tr("KNOCKOUT"), "SubLabel", 22))
		for k in cup.knockout:
			kv.add_child(_fixture(k, cup.user, tr("STAGE_" + String(k.stage).to_upper())))
		body.add_child(kc)
	var pools := HBoxContainer.new()
	pools.add_theme_constant_override("separation", 16)
	body.add_child(pools)
	for p in 2:
		var pc := UI.card()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 8)
		pc.add_child(pv)
		pv.add_child(UI.label(tr("POOL_N").format({"n": p + 1}), "SubLabel", 22))
		var rows := []
		for r in cup.pool_table(p):
			rows.append([r.id, int(r.p), int(r.w), int(r.d), int(r.l), "%d" % roundi(float(r.pct)) if int(r.p) > 0 else "–", int(r.pts)])
		pv.add_child(UI.standings([tr("COL_TEAM"), tr("COL_P"), tr("COL_W"), tr("COL_D"), tr("COL_L"), tr("COL_PCT"), tr("COL_PTS")], rows, cup.user, 2, 0, true))
		for f in cup.fixtures:
			if int(f.pool) == p and f.played:
				pv.add_child(_fixture(f, cup.user, ""))
		pools.add_child(pc)


func _stage_name(nm: Dictionary) -> String:
	var s := String(nm.stage)
	if s == "POOL_N":
		return tr("POOL_N").format({"n": int(nm.get("n", 1))})
	return tr("STAGE_" + s)


func _fixture(f: Dictionary, user: String, label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var mine: bool = f.home == user or f.away == user
	var col := Game.C_INK if mine else Game.C_MUTED
	if label != "":
		var l := UI.label(label, "EyebrowLabel", 13)
		l.custom_minimum_size = Vector2(150, 0)
		UI.fit(l, 2)
		h.add_child(l)
	h.add_child(UI.badge(f.home, Vector2(30, 20)))
	var a := UI.fit(UI.label(DB.team_name(f.home), "", 17, col), 2)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.custom_minimum_size = Vector2(80, 0)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(a)
	var mid := UI.label("%d – %d" % [f.score[0], f.score[1]] if f.played else tr("VS"), "SubLabel", 18, Game.C_ACCENT if mine else Game.C_INK)
	mid.custom_minimum_size = Vector2(76, 0)
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(mid)
	var b := UI.fit(UI.label(DB.team_name(f.away), "", 17, col), 2)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(80, 0)
	h.add_child(b)
	h.add_child(UI.badge(f.away, Vector2(30, 20)))
	return h


func _medals(cup) -> Control:
	var card := UI.card()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var won: bool = cup.medals.get("gold", "") == cup.user
	v.add_child(UI.label(tr("CUP_WON") if won else tr("CUP_OVER"), "TitleLabel", 52, Game.C_GOLD if won else Game.C_INK))
	for m in [["gold", Game.C_GOLD], ["silver", Color("c9ced6")], ["bronze", Color("d08a4e")]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		h.add_child(Icon.make("star", 26, m[1]))
		h.add_child(UI.label(tr("MEDAL_" + String(m[0]).to_upper()), "SubLabel", 20, m[1]))
		h.add_child(UI.badge(cup.medals.get(m[0], ""), Vector2(36, 24)))
		h.add_child(UI.label(DB.team_name(cup.medals.get(m[0], "")), "", 20))
		v.add_child(h)
	return card


func _play(cup, nm: Dictionary) -> void:
	Game.start_match({"home": nm.home, "away": nm.away, "venue": "arena", "quarter": Game.quarter_minutes(),
		"difficulty": int(Game.settings.difficulty), "mode": "cup", "card": true, "user_team": 0 if nm.home == cup.user else 1,
		"stage": _stage_name(nm), "need_winner": bool(nm.need_winner), "double_zone": false})
