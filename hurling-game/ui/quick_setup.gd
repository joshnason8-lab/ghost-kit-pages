extends Control
## Match setup, as a programme's team sheets: each county's fifteen printed in their lines (1; 2-3-4; 5-6-7; 8-9;
## 10-11-12; 13-14-15), names in Irish or English as the game is shown, the arrows to change county. Under them the
## venue, how long the match takes, the grade (the length of a half), how hard the other side is, and whether a draw
## goes to extra time. Watch a match: the same, both sides played by the computer.

var _home := "KIL"
var _away := "TIP"
var _venue := "county"     # the last one picked (Game.settings.venue)
var _watch := false
var _knockout := false
var _body: VBoxContainer
var _ids: Array = []


func setup(args: Dictionary) -> void:
	_watch = bool(args.get("watch", false))


func _ready() -> void:
	UI.screen(self)
	_venue = String(Game.settings.get("venue", "county"))
	_ids = DB.counties_ranked()
	var c = Game.get_champ()
	if c != null:
		_home = String(c.user)
	if _home == _away:
		_away = _ids[1] if _ids[0] == _home else _ids[0]
	var v := UI.page(self, tr("MENU_WATCH") if _watch else tr("MENU_QUICK"), func(): Game.goto_menu(), tr("SETUP_EYEBROW"))
	var play := UI.button(tr("THROW_IN"), true, _play)
	play.custom_minimum_size = Vector2(230, 64)
	(get_meta("header_right") as HBoxContainer).add_child(play)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(_body))
	_build()


func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	var sheets := HBoxContainer.new()
	sheets.add_theme_constant_override("separation", 16)
	_body.add_child(sheets)
	sheets.add_child(_sheet(0))
	sheets.add_child(_sheet(1))
	var opts: Array = UI.section(tr("MATCH_OPTIONS"), "whistle")
	_body.add_child(opts[0])
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 28)
	flow.add_theme_constant_override("v_separation", 14)
	opts[1].add_child(flow)
	var vids := ["parish", "county", "night", "stadium"]
	var vnames := []
	for id in vids:
		vnames.append(tr(String(DB.venue(id)[0])))
	flow.add_child(UI.field(tr("VENUE"), UI.chips(vnames, vids.find(_venue), func(i):
		_venue = vids[i]
		Game.settings.venue = _venue
		Game.save_settings())))
	var lens := []
	for n in Game.LENGTHS:
		lens.append(tr("MINUTES_N").format({"n": n}))
	flow.add_child(UI.field(tr("MATCH_LENGTH"), UI.chips(lens, int(Game.settings.length), func(i):
		Game.settings.length = i
		Game.save_settings())))
	flow.add_child(UI.field(tr("GRADE"), UI.chips([tr("GRADE_SENIOR"), tr("GRADE_CLUB")], int(Game.settings.grade), func(i):
		Game.settings.grade = i
		Game.save_settings())))
	flow.add_child(UI.field(tr("DRAWN_GAME"), UI.chips([tr("DRAW_STANDS"), tr("DRAW_EXTRA")], 1 if _knockout else 0, func(i):
		_knockout = i == 1)))
	if not _watch:
		opts[1].add_child(UI.difficulty_field(self))
	var note := UI.wrap(tr("LENGTH_NOTE"), "MutedLabel", 16)
	opts[1].add_child(note)


## A county's team sheet on programme paper.
func _sheet(k: int) -> Control:
	var id := _home if k == 0 else _away
	var t := DB.team(id)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.C_PAPER
	sb.set_corner_radius_all(4)
	sb.border_color = t.c1
	sb.border_width_top = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var role := tr("YOUR_TEAM") if k == 0 and not _watch else (tr("HOME") if k == 0 else (tr("OPPONENT") if not _watch else tr("AWAY")))
	var eb := UI.label(role.to_upper(), "EyebrowLabel", 14, Color(Game.C_PRINT, 0.65))
	UI.fit(eb, 1)
	v.add_child(eb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(_arrow("back", k, -1))
	var jersey := Colours.make(id, 46)
	head.add_child(jersey)
	var name := UI.label(DB.team_name(id), "HeaderLabel", 34, Game.C_PRINT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.shrink(name, 34, 0.6, 1)
	head.add_child(name)
	head.add_child(_arrow("next", k, 1))
	var rating := UI.label(tr("RATING") + " %d" % roundi(DB.team_rating(id)), "MutedLabel", 15, Color(Game.C_PRINT, 0.7))
	v.add_child(rating)
	var rule := ColorRect.new()
	rule.color = Color(Game.C_PRINT, 0.3)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	var sq := DB.starters(id)
	for line in [[1], [2, 3, 4], [5, 6, 7], [8, 9], [10, 11, 12], [13, 14, 15]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(row)
		for n in line:
			var pd: Dictionary = sq[n - 1]
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", -4)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_stretch_ratio = 1.0
			if line.size() == 1:
				cell.custom_minimum_size = Vector2(0, 0)
			var num := UI.label(str(n), "SubLabel", 15, t.c1.darkened(0.2) if t.c1.get_luminance() > 0.3 else t.c1.lightened(0.1))
			if t.c1.get_luminance() > 0.85:
				num.add_theme_color_override("font_color", t.c2)
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(num)
			var pn := UI.label(DB.player_name(pd, true), "", 15, Game.C_PRINT)
			pn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UI.fit(pn, 2)
			cell.add_child(pn)
			row.add_child(cell)
	return card


func _arrow(icon: String, k: int, step: int) -> Button:
	var b := UI.round_button(icon, func():
		var cur := _home if k == 0 else _away
		var other := _away if k == 0 else _home
		var i := _ids.find(cur)
		for n in _ids.size():
			i = (i + step + _ids.size()) % _ids.size()
			if _ids[i] != other:
				break
		if k == 0:
			_home = _ids[i]
		else:
			_away = _ids[i]
		_build(), 46)
	return b


func _play() -> void:
	Game.start_match({"home": _home, "away": _away, "venue": _venue, "mode": "watch" if _watch else "quick",
		"user_team": -1 if _watch else 0, "knockout": _knockout, "difficulty": int(Game.settings.difficulty),
		"grade": int(Game.settings.grade), "stage": tr("FRIENDLY") if not _knockout else tr("KNOCKOUT_GAME")})
