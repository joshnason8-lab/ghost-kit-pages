extends Control
## Free-taking practice, before it starts: your county (its free-taker takes them), the ground, how it works and your
## best score so far. Start goes to game/practice.gd.

var _team := "KIL"         # the county last practised with (Game.settings.practice_team)
var _venue := "county"
var _ids: Array = []
var _body: VBoxContainer


func _ready() -> void:
	UI.screen(self)
	_ids = DB.counties_ranked()
	_team = String(Game.settings.get("practice_team", ""))
	if not _team in _ids:
		var c = Game.get_champ()
		_team = String(c.user) if c != null else "KIL"
	_venue = String(Game.settings.get("venue", "county"))
	var v := UI.page(self, tr("MENU_PRACTICE"), func(): Game.goto_menu(), tr("PRACTICE_EYEBROW"))
	var go := UI.button(tr("PRACTICE_START"), true, _start)
	go.custom_minimum_size = Vector2(230, 64)
	(get_meta("header_right") as HBoxContainer).add_child(go)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(_body))
	_build()


func _build() -> void:
	for c in _body.get_children():
		c.queue_free()
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	_body.add_child(cols)
	cols.add_child(_county_card())
	cols.add_child(_how_card())
	var opts: Array = UI.section(tr("VENUE"), "whistle")
	_body.add_child(opts[0])
	var vids := ["parish", "county", "night", "stadium"]
	var vnames := []
	for id in vids:
		vnames.append(tr(String(DB.venue(id)[0])))
	opts[1].add_child(UI.chips(vnames, vids.find(_venue), func(i):
		_venue = vids[i]
		Game.settings.venue = _venue
		Game.save_settings()))


## Your county: its colours and name with arrows to change it, and the man who takes the frees.
func _county_card() -> Control:
	var t := DB.team(_team)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.C_PAPER
	sb.set_corner_radius_all(4)
	sb.border_color = t.c1
	sb.border_width_top = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(UI.label(tr("YOUR_TEAM").to_upper(), "EyebrowLabel", 14, Color(Game.C_PRINT, 0.65)))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(UI.round_button("back", func(): _step(-1), 46))
	head.add_child(Colours.make(_team, 46))
	var name := UI.label(DB.team_name(_team), "HeaderLabel", 34, Game.C_PRINT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.shrink(name, 34, 0.6, 1)
	head.add_child(name)
	head.add_child(UI.round_button("next", func(): _step(1), 46))
	var taker := DB.free_taker(_team)
	var who := UI.label(tr("PRACTICE_TAKER").format({"name": DB.player_name(taker, false), "num": int(taker.num)}),
		"", 18, Game.C_PRINT)
	UI.fit(who, 2)
	v.add_child(who)
	var stat := UI.stat_bar(tr("PRACTICE_FREES_STAT"), float(taker.get("free", 70)), t.c1 if t.c1.get_luminance() < 0.8 else t.c2)
	for l in stat.find_children("*", "Label", false, false):
		(l as Label).add_theme_color_override("font_color", Color(Game.C_PRINT, 0.8))
	v.add_child(stat)
	return card


## How it works, and the best score so far.
func _how_card() -> Control:
	var card := UI.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	v.add_child(UI.label(tr("PRACTICE_HOW_TITLE").to_upper(), "EyebrowLabel", 16, Game.C_SAFFRON))
	var how := UI.wrap(tr("PRACTICE_HOW"), "", 18)
	v.add_child(how)
	var best := int(Game.settings.get("practice_best", -1))
	var b := UI.label(tr("PRACTICE_BEST_WAS").format({"n": best}) if best >= 0 else tr("PRACTICE_NO_BEST"), "SubLabel", 22,
		Game.C_GOLD)
	UI.fit(b, 2)
	v.add_child(b)
	# The practice draws on High; the HD pack's hurler is the one to see up close, if the phone can have it.
	if Ultra.capable() and Ultra.renderer_ready() and not Ultra.mount_now():
		v.add_child(UI.wrap(tr("PRACTICE_HD_HINT"), "MutedLabel", 16))
	return card


func _step(d: int) -> void:
	var i := _ids.find(_team)
	_team = _ids[(i + d + _ids.size()) % _ids.size()]
	Game.settings.practice_team = _team
	Game.save_settings()
	_build()


## The other side, for its goalkeeper: the strongest county whose colours are not like yours.
static func sparring(id: String) -> String:
	for o in DB.counties_ranked():
		if o != id and not DB.colours_clash(id, o):
			return o
	return "TIP" if id != "TIP" else "KIL"


func _start() -> void:
	Game.settings.practice_team = _team
	Game.save_settings()
	Game.start_match({"home": _team, "away": sparring(_team), "venue": _venue, "mode": "practice", "user_team": 0,
		"difficulty": int(Game.settings.difficulty), "grade": int(Game.settings.grade)})
