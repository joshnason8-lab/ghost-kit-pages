extends Control
## After a match: who won and how (by points, by an innings, on the minimum chase), the score by turn, and the box
## score of each side: its chasers' outs, dives and khos, its defenders' time on the field and best run; the player of
## the match. Then on: play again, back to the championship, or home.

var result := {}


func setup(args: Dictionary) -> void:
	result = args.get("result", {})


func _ready() -> void:
	UI.screen(self)
	var cfg: Dictionary = result.get("config", {})
	var teams: Array = result.get("teams", [String(cfg.get("home", "")), String(cfg.get("away", ""))])
	var sc: Array = result.get("score", [0, 0])
	var w := int(result.get("winner", -1))
	var title := tr("RESULT_TIE") if w < 0 else tr("RESULT_WON").format({"team": DB.team_name(teams[w])})
	var v := UI.page(self, title, Callable(), String(cfg.get("stage", "")))
	var right: HBoxContainer = get_meta("header_right")
	var next := _next_button(cfg)
	right.add_child(next)
	set_meta("back", func(): next.pressed.emit())
	var user := int(cfg.get("user_team", -1))
	Sfx.react("cheer" if (w == user and user >= 0) else "applause", -6.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(body))
	# The score, and how it was won.
	var top := UI.card()
	body.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 10)
	top.add_child(tv)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in 2:
		var cr := Crest.make(teams[k], 48)
		var nm := UI.fit(UI.label(DB.team_name(teams[k]), "SubLabel", 24, Game.C_GOLD if k == w else Game.C_INK), 2)
		nm.custom_minimum_size = Vector2(170, 0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if k == 0 else HORIZONTAL_ALIGNMENT_LEFT
		var pts := UI.label(str(int(sc[k])), "ScoreLabel", 0, Game.C_SAFFRON)
		pts.add_theme_font_size_override("font_size", 56)
		if k == 0:
			row.add_child(cr)
			row.add_child(nm)
			row.add_child(pts)
			row.add_child(UI.label("–", "HeaderLabel", 40, Game.C_MUTED))
		else:
			row.add_child(pts)
			row.add_child(nm)
			row.add_child(cr)
	tv.add_child(row)
	var how := UI.label(_how(), "MutedLabel", 18)
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(how, 2)
	tv.add_child(how)
	tv.add_child(MatchHud.score_by_turn(_turns_view()))
	# The box score, a card a side.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	body.add_child(cols)
	var best := _player_of_match()
	for k in 2:
		cols.add_child(_box(k, teams[k], best))
	if best != "":
		var st: Dictionary = result.stats[best]
		var pom := UI.label(tr("PLAYER_OF_MATCH") + ": " + UI.bits(["#%d %s" % [int(st.num), String(st.name)], DB.team_name(teams[int(st.side)])]), "SubLabel", 20, Game.C_GOLD)
		UI.fit(pom, 2)
		body.add_child(pom)


func _how() -> String:
	var sc: Array = result.score
	var w := int(result.get("winner", -1))
	if w < 0:
		return ""
	if bool(result.get("min_chase", false)):
		return tr("RESULT_MIN_CHASE")
	var margin := absi(int(sc[0]) - int(sc[1]))
	var turns: Array = result.get("turns", [])
	if bool(result.get("follow_on", false)) and turns.size() == 3:
		return tr("RESULT_BY_INNINGS").format({"n": margin})
	return tr("RESULT_BY").format({"n": margin})


## What score_by_turn reads, from the result.
func _turns_view() -> Object:
	var o := TurnsView.new()
	o.turns_log = result.get("turns", [])
	o.teams = result.get("teams", ["", ""])
	o.score = result.get("score", [0, 0])
	return o


class TurnsView extends RefCounted:
	var turns_log: Array = []
	var teams: Array = []
	var score: Array = []


func _player_of_match() -> String:
	var best := ""
	var bv := -1.0
	for id in result.get("stats", {}):
		var st: Dictionary = result.stats[id]
		var val := float(st.outs) * 3.0 + float(st.dives) * 0.5 + float(st.khos) * 0.05 + float(st.def_time) / 30.0
		if int(st.side) == int(result.get("winner", 0)):
			val *= 1.2
		if val > bv:
			bv = val
			best = String(id)
	return best


func _box(side: int, team: String, best: String) -> PanelContainer:
	var card := UI.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var t := UI.label(DB.team_name(team), "SubLabel", 22, Game.C_SAFFRON)
	UI.fit(t)
	v.add_child(t)
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 4)
	for h in [tr("COL_PLAYER"), tr("COL_OUTS"), tr("COL_DIVES"), tr("COL_KHOS"), tr("COL_TIME"), tr("COL_BEST")]:
		var hl := UI.label(h, "EyebrowLabel", 13, Game.C_MUTED)
		UI.fit(hl)
		g.add_child(hl)
	var rows: Array = []
	for id in result.get("stats", {}):
		var st: Dictionary = result.stats[id]
		if int(st.side) == side:
			rows.append([id, st])
	rows.sort_custom(func(a, b): return int(a[1].num) < int(b[1].num))
	for r in rows:
		var st: Dictionary = r[1]
		var col := Game.C_GOLD if String(r[0]) == best else Game.C_INK
		var nm := UI.label("%d %s" % [int(st.num), String(st.name)], "", 16, col)
		nm.custom_minimum_size = Vector2(150, 0)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.fit(nm)
		g.add_child(nm)
		g.add_child(UI.label(str(int(st.outs)), "", 16, col))
		g.add_child(UI.label(str(int(st.dives) + int(st.pole_dives)), "", 16, col))
		g.add_child(UI.label(str(int(st.khos)), "", 16, col))
		g.add_child(UI.label(_mmss(float(st.def_time)), "", 16, col))
		g.add_child(UI.label(_mmss(maxf(float(st.best_run), float(st.run))), "", 16, col))
	v.add_child(g)
	return card


static func _mmss(t: float) -> String:
	var s := int(t)
	return "%d:%02d" % [s / 60, s % 60]


func _next_button(cfg: Dictionary) -> Button:
	if String(cfg.get("mode", "quick")) == "cup":
		return UI.button(tr("TO_CUP"), true, func(): Game.show_screen("res://ui/cup_screen.gd"))
	var row_b := UI.button(tr("TO_MENU"), true, func(): Game.goto_menu())
	return row_b
