extends Control
## The town tournament. With none under way: pick the game (ulama or the classic court) and your town, and the eight
## are drawn. Under way: the draw, round by round (quarter-finals, semi-finals, the final), your next game and the
## button to play it; when it is over, the champion. Start again asks twice.

var _rules := Rules.ULAMA
var _team := ""
var _body: VBoxContainer


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	_rules = String(Game.settings.get("mode", Rules.ULAMA))
	var v := UI.page(self, tr("MENU_CUP"), func(): Game.goto_menu(), tr("CUP_EYEBROW"))
	set_meta("page", v)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	v.add_child(UI.scroll(_body))
	_fill()


func _fill() -> void:
	for c in _body.get_children():
		c.queue_free()
	var right: HBoxContainer = get_meta("header_right")
	for c in right.get_children():
		c.queue_free()
	var cup = Game.get_cup()
	if cup == null:
		_pick(right)
	else:
		_hub(cup, right)


func _pick(right: HBoxContainer) -> void:
	var ids: Array = DB.teams_for(_rules)
	if _team == "" or not (_team in ids):
		_team = ids[0]
	var go := UI.button(tr("CUP_START"), true, func():
		Game.settings.mode = _rules
		Game.save_settings()
		Game.cup = Cup.create(_team, _rules)
		Game.save_cup()
		_fill())
	go.custom_minimum_size = Vector2(220, 64)
	right.add_child(go)
	_body.add_child(UI.wrap(tr("CUP_INTRO"), "MutedLabel", 18))
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 12)
	_body.add_child(kinds)
	for r in [Rules.ULAMA, Rules.CLASSIC]:
		kinds.add_child(UI.option_card(tr("RULES_NAME_" + r.to_upper()), tr("CUP_KIND_" + r.to_upper()), null, r == _rules, func():
			_rules = r
			_team = ""
			_fill()))
	var sec: Array = UI.section(tr("YOUR_TOWN"), "flag")
	_body.add_child(sec[0])
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	sec[1].add_child(flow)
	for id in ids.slice(0, 8):
		var b := Button.new()
		b.theme_type_variation = "ChipButton"
		b.toggle_mode = true
		b.button_pressed = id == _team
		b.text = DB.team_name(id)
		b.custom_minimum_size = Vector2(0, 50)
		var tid: String = id
		b.pressed.connect(func():
			Sfx.click()
			_team = tid
			_fill())
		flow.add_child(b)


func _hub(cup: Cup, right: HBoxContainer) -> void:
	var nxt := cup.next_fixture()
	if not nxt.is_empty():
		var play := UI.button(tr("PLAY_NEXT"), true, func(): _play(cup, nxt))
		play.custom_minimum_size = Vector2(220, 64)
		right.add_child(play)
	var again := UI.button(tr("START_AGAIN"), false)
	again.pressed.connect(func():
		if again.has_meta("sure"):
			Game.delete_cup()
			_fill()
		else:
			again.set_meta("sure", true)
			again.text = tr("START_AGAIN_SURE"))
	right.add_child(again)
	var head := UI.label("", "HeaderLabel", 32, Game.C_GOLD)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.fit(head, 2)
	if cup.done():
		head.text = tr("CUP_CHAMPION").format({"team": DB.team_name(cup.champion)})
	elif cup.out:
		head.text = tr("CUP_OUT")
	else:
		head.text = tr("CUP_NEXT").format({"stage": tr(String(nxt.get("stage", cup.stage_key()))), "team": DB.team_name(String(nxt.away if nxt.home == cup.team else nxt.home))})
	_body.add_child(head)
	_body.add_child(UI.label(UI.bits([tr("RULES_NAME_" + cup.rules.to_upper()), DB.team_name(cup.team)]), "MutedLabel", 17))
	var rounds: Array = cup.history.duplicate()
	if not cup.draw.is_empty():
		rounds.append(cup.draw)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	_body.add_child(cols)
	for i in rounds.size():
		var sec: Array = UI.section(tr(Cup.STAGES[mini(i, 2)]), "trophy")
		sec[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(sec[0])
		for pair in rounds[i]:
			sec[1].add_child(UI.fixture_line(self, pair, cup.team))


func _play(cup: Cup, f: Dictionary) -> void:
	var user := 0 if f.home == cup.team else 1
	var n := int(Game.settings.get("side_" + cup.rules, Rules.default_side(cup.rules)))
	Game.start_match({"home": f.home, "away": f.away, "venue": f.venue, "rules": cup.rules, "side": n, "mode": "cup",
		"user_team": user, "difficulty": mini(2, int(Game.settings.difficulty) + (1 if cup.round >= 2 else 0)),
		"urria": String(Game.settings.get("urria", "3_7")), "length": Game.LENGTHS[int(Game.settings.length)], "stage": tr(String(f.stage))})
