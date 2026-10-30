extends Node
## The test suite CI runs before building (headless):
##   godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
## The playing rules, one by one (Rules, Pitch): docs/RULES.md lists each with its number. Every screen opens in
## every language; every scrolling page scrolls when dragged on its text; the championship plays through to its
## champion and saves; the simulated results are scores hurling can have; an AI match plays to full time with a legal
## score; and the movement audit: one writer per player, nothing jumps in a frame, strides match speed.
## Exits 1 on any failure.

var failures := 0
var checks := 0


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	# Headless there is no window: give the screens a phone's shape.
	get_tree().root.size = Vector2i(1280, 720)
	await frames(1)
	var keep: Dictionary = Game.settings.duplicate(true)
	_rules_scores()
	_rules_time()
	_rules_carry()
	_rules_restarts()
	_rules_fouls()
	_rules_cards()
	_rules_shootout()
	_pitch()
	_sliotar()
	_plurals()
	await _screens()
	await _scroll_on_text()
	await _legal_pages()
	_championship()
	_sim_scores()
	_clock_lengths()
	_coach()
	await _subs()
	await _tactics()
	await _playtest_fixes()
	await _nets()
	await _scenery()
	await _hero_body()
	await _replay()
	await _match_and_motion()
	_sounds()
	_hd_textures()
	await _shadows()
	await _ultra()
	await _auto_pickup()
	await _aimed_shots()
	await _practice_frees()
	await _shootout_frees()
	await _goals_round()
	await _auto_graphics()
	await _champ_sim_resume()
	await _crowd_builds()
	_backpedal()
	Game.settings = keep
	Game.save_settings()
	Game.delete_champ()
	print("test_runner: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ---------------------------------------------------------------- the rules

func _rules_scores() -> void:
	check(Rules.total(2, 18) == 24, "Scores: 2-18 is 24")
	check(Rules.total(1, 0) == Rules.total(0, 3), "Scores: a goal is worth three points")
	check(Rules.fmt(2, 18) == "2-18" and Rules.fmt(0, 7) == "0-7", "Scores: written goals-points")
	check(Pitch.score_kind(Vector3(70, 1.0, 0)) == "goal", "Scores: under the bar between the posts is a goal")
	check(Pitch.score_kind(Vector3(70, 3.0, 2.0)) == "point", "Scores: over the bar between the posts is a point")
	check(Pitch.score_kind(Vector3(70, 3.0, 3.4)) == "", "Scores: outside the posts is wide")
	check(Pitch.score_kind(Vector3(70, 25.0, 1.0)) == "point", "Scores: high over the posts, inside their line, is a point")
	check(not Rules.score_counts("goal", "hand_pass"), "Scores: no goal from a hand-pass")
	check(Rules.score_counts("point", "hand_pass"), "Scores: a hand-passed point stands")
	check(not Rules.score_counts("point", "throw") and not Rules.score_counts("goal", "carry"), "Scores: nothing thrown or carried over the line")
	check(Rules.score_counts("goal", "strike") and Rules.score_counts("goal", "deflect") and Rules.score_counts("point", "65"), "Scores: struck, deflected, from a 65")
	check(Rules.shootout_counts("goal") and not Rules.shootout_counts("point"), "Shoot-out: only goals count")


func _rules_time() -> void:
	check(Rules.half_minutes(Rules.GRADE_SENIOR) == 35 and Rules.half_minutes(Rules.GRADE_CLUB) == 30, "Time: halves of 35 (senior county) and 30 (club)")
	check(Rules.half_time_minutes(Rules.GRADE_SENIOR) == 15 and Rules.half_time_minutes(Rules.GRADE_CLUB) == 10, "Time: half-time 15 and 10 minutes")
	check(Rules.EXTRA_HALF == 10, "Time: extra time is two halves of ten")
	check(Rules.subs_allowed(false) == 5 and Rules.subs_allowed(true) == 8, "Substitutes: five, three more in extra time")
	check(Rules.throw_in_players() == 2, "Throw-in: two from each side")


func _rules_carry() -> void:
	var c := Rules.Carry.new()
	check(Rules.take_in_hand(c) == "", "Carry: the first catch")
	check(Rules.carry_step(c, 4, 1.0) == "", "Carry: four steps in the hand")
	check(Rules.carry_step(c, 1, 0.2) == "FOUL_STEPS", "Carry: a fifth step is a foul")
	c = Rules.Carry.new()
	Rules.take_in_hand(c)
	check(Rules.carry_step(c, 0, Rules.MAX_HOLD_S + 0.1) == "FOUL_HOLD", "Carry: held longer than four steps take is a foul")
	c = Rules.Carry.new()
	Rules.take_in_hand(c)
	Rules.carry_step(c, 3, 0.5)
	Rules.to_hurley(c)
	check(Rules.carry_step(c, 40, 5.0) == "", "Carry: on the hurley, no limit")
	check(Rules.take_in_hand(c) == "", "Carry: back into the hand, the second catch")
	check(c.steps == 0, "Carry: the steps start again on the second catch")
	Rules.to_hurley(c)
	check(Rules.take_in_hand(c) == "FOUL_CATCH_3", "Carry: a third catch is a foul")
	Rules.release(c)
	check(c.catches == 0 and Rules.take_in_hand(c) == "", "Carry: played away, a new possession starts at one")
	check(not Rules.ground_lift_ok("hand") and Rules.ground_lift_ok("hurley") and Rules.ground_lift_ok("foot"), "Ground: lifted with the hurley or the foot, never the hand")
	check(Rules.hand_pass_ok(true) and not Rules.hand_pass_ok(false), "Hand-pass: struck, not thrown")
	check(not Rules.recatch_ok(false) and Rules.recatch_ok(true), "Recatch: only after playing it on the hurley")


func _rules_restarts() -> void:
	# Team 0 attacks +x (dir 1).
	var wide := Rules.over_end_line(Vector3(70, 2, 10), 0, 0, 1.0)
	check(String(wide.kind) == "puck_out" and int(wide.team) == 1, "Wide: a puck-out to the defenders")
	check(Pitch.in_small_rect(wide.spot, 1.0), "Puck-out: from the small rectangle")
	var s65 := Rules.over_end_line(Vector3(70, 1, -12), 1, 0, 1.0)
	check(String(s65.kind) == "65" and int(s65.team) == 0, "65: a defender put it over his own end line")
	check(is_equal_approx(Pitch.from_goal_line(s65.spot, 1.0), 65.0) and is_equal_approx(s65.spot.z, -12.0), "65: from the 65 m line opposite where it crossed")
	var sc := Rules.after_score(0, 1.0)
	check(String(sc.kind) == "puck_out" and int(sc.team) == 1 and Pitch.in_small_rect(sc.spot, 1.0), "After a score: a puck-out by the side scored against")
	var sl := Rules.over_side_line(Vector3(10, 1, 43), 1)
	check(String(sl.kind) == "sideline" and int(sl.team) == 0 and is_equal_approx(sl.spot.x, 10.0), "Sideline: to the other side, where it crossed")
	check(not Rules.restart_lift("sideline") and Rules.restart_lift("free") and Rules.restart_lift("65"), "Sideline cut off the ground; frees and 65s may be lifted")
	check(Rules.restart_from_hand("puck_out") and not Rules.restart_from_hand("free"), "Only the puck-out from the hand")
	# Positions.
	check(not Rules.position_ok("free", Vector3(0, 0, 0), 0, Vector3(5, 0, 5), 1, 1.0), "Free: an opponent 7 m away is too near")
	check(Rules.position_ok("free", Vector3(0, 0, 0), 0, Vector3(13.1, 0, 0), 1, 1.0), "Free: 13 m is far enough")
	check(Rules.position_ok("free", Vector3(0, 0, 0), 0, Vector3(1, 0, 0), 0, 1.0), "Free: teammates may stand near")
	check(not Rules.position_ok("puck_out", Vector3(-68, 0, 0), 0, Vector3(-55, 0, 0), 1, 1.0), "Puck-out: inside the 20 m line is not allowed")
	check(Rules.position_ok("puck_out", Vector3(-68, 0, 0), 0, Vector3(-49, 0, 0), 1, 1.0), "Puck-out: outside the 20 m line")
	check(Rules.position_ok("puck_out", Vector3(-68, 0, 0), 0, Vector3(-69, 0, 0), 0, 1.0, true), "Puck-out: the goalkeeper in his area")
	check(Rules.PUCK_OUT_TRAVEL == 13.0, "Puck-out: travels 13 m before the taker's side plays it")
	check(Rules.position_ok("penalty", Pitch.penalty_spot(1.0), 0, Vector3(70, 0, 0), 1, 1.0, true), "Penalty: one defender on the goal line")
	check(not Rules.position_ok("penalty", Pitch.penalty_spot(1.0), 0, Vector3(55, 0, 0), 1, 1.0), "Penalty: no one else inside the 20 m line")
	check(not Rules.position_ok("penalty", Pitch.penalty_spot(1.0), 0, Vector3(45, 0, 2), 0, 1.0), "Penalty: no one inside the arc")
	check(Rules.line_defenders("penalty") == 1 and Rules.line_defenders("free20") == 5, "Penalty one on the line, a 20 m free up to five")
	check(Rules.penalty_strike_ok(Pitch.penalty_spot(1.0) - Vector3(3, 0, 0), 1.0) and not Rules.penalty_strike_ok(Vector3(55, 0, 0), 1.0), "Penalty: struck on or outside the 20 m line")
	check(Rules.PENALTY_RUNUP == 7.0, "Penalty: placed up to 7 m back for a run-up")


func _rules_fouls() -> void:
	# Fouls by team 1 on team 0, which attacks +x.
	var f := Rules.free_for("FOUL_PUSH", Vector3(0, 0, 10), 0, 1.0)
	check(String(f.kind) == "free" and f.spot.distance_to(Vector3(0, 0, 10)) < 0.01, "Free: where the foul was")
	var p := Rules.free_for("FOUL_PULL_DOWN", Vector3(62, 0, 3), 0, 1.0)
	check(String(p.kind) == "penalty" and p.spot.distance_to(Pitch.penalty_spot(1.0)) < 0.01, "Aggressive foul in the large rectangle: a penalty")
	var t := Rules.free_for("FOUL_STEPS", Vector3(62, 0, 3), 0, 1.0)
	check(String(t.kind) == "free" and t.spot.distance_to(Pitch.penalty_spot(1.0)) < 0.01, "Technical foul in the large rectangle: a free from the centre of the 20 m line")
	var t20 := Rules.free_for("FOUL_PUSH", Vector3(58, 0, 20), 0, 1.0)
	check(String(t20.kind) == "free" and is_equal_approx(Pitch.from_goal_line(t20.spot, 1.0), 20.0) and is_equal_approx(t20.spot.z, 20.0), "Inside the 20 m line, outside the large rectangle: a free on the 20 m line opposite")
	var d := Rules.free_for("FOUL_TRIP", Vector3(54, 0, 8), 0, 1.0, true)
	check(String(d.kind) == "penalty", "A foul denying a goal chance inside the 20 m line: a penalty")
	var da := Rules.free_for("FOUL_TRIP", Vector3(40, 0, 0), 0, 1.0, true)
	check(String(da.kind) == "penalty", "... or inside the arc")
	var dout := Rules.free_for("FOUL_TRIP", Vector3(20, 0, 0), 0, 1.0, true)
	check(String(dout.kind) == "free", "... but not out the field")
	check(Rules.aggressive("FOUL_TRIP") and not Rules.aggressive("FOUL_STEPS"), "Aggressive and technical fouls apart")
	var ds := Rules.dissent_spot(Vector3(0, 0, 4), 1.0)
	check(is_equal_approx(ds.x, 30.0), "Dissent: the free moves on 30 m")
	check(is_equal_approx(Rules.dissent_spot(Vector3(40, 0, 0), 1.0).x, Pitch.HALF_L - 20.0), "Dissent: no nearer than the 20 m line")
	check(Rules.may_play_advantage("FOUL_STEPS", false, true), "Advantage: for a technical foul with space")
	check(not Rules.may_play_advantage("FOUL_PULL_DOWN", false, false), "Advantage: not for an aggressive foul on a man held up")
	check(Rules.may_play_advantage("FOUL_PULL_DOWN", true, false), "Advantage: for an aggressive foul with a goal chance")
	check(Rules.ADVANTAGE_S == 5.0, "Advantage: up to five seconds")
	check(Rules.FREE_DISTANCE == 13.0, "Opponents 13 m from a free")


func _rules_cards() -> void:
	check(Rules.card_for("FOUL_STRIKE", false, false, 0, 0, 0) == "red", "Striking an opponent: red")
	check(Rules.card_for("FOUL_PULL_DOWN", true, false, 0, 0, 0) == "yellow", "A cynical pull-down: yellow")
	check(Rules.card_for("FOUL_PULL_DOWN", true, false, 0, 1, 0) == "red", "A second yellow is a red")
	check(Rules.card_for("FOUL_TRIP", true, true, Rules.GRADE_SENIOR, 0, 0) == "black", "Denying a goal chance (senior county): black, the sin bin")
	check(Rules.card_for("FOUL_TRIP", true, true, Rules.GRADE_SENIOR, 1, 0) == "red", "A black after a yellow: red")
	check(Rules.card_for("FOUL_TRIP", true, true, Rules.GRADE_CLUB, 0, 0) == "yellow", "Club hurling has no black card")
	check(Rules.card_for("FOUL_STEPS", false, false, 0, 0, 0) == "", "A technical foul: no card")
	check(Rules.SIN_BIN_MIN == 10, "The sin bin: ten minutes")


func _rules_shootout() -> void:
	check(Rules.shootout_winner([3, 0], [3, 3]) == 0, "Shoot-out: 3-0 after three each cannot be caught")
	check(Rules.shootout_winner([3, 1], [3, 2]) == -1, "Shoot-out: 3-1 with three to come for one side goes on")
	check(Rules.shootout_winner([4, 4], [5, 5]) == -1, "Shoot-out: level after five each: sudden death")
	check(Rules.shootout_winner([5, 4], [6, 6]) == 0, "Shoot-out: sudden death decided in a round")
	check(Rules.shootout_winner([5, 5], [6, 5]) == -1, "Shoot-out: a round is finished first")


func _pitch() -> void:
	check(Pitch.LENGTH >= 130.0 and Pitch.LENGTH <= 145.0 and Pitch.WIDTH >= 80.0 and Pitch.WIDTH <= 90.0, "Pitch: 130-145 m by 80-90 m")
	check(Pitch.POST_GAP == 6.5 and Pitch.BAR_H == 2.5 and Pitch.POST_H >= 7.0, "Goals: posts 6.5 m apart, at least 7 m high, the bar at 2.5 m")
	check(Pitch.SMALL_W == 14.0 and Pitch.SMALL_D == 4.5 and Pitch.LARGE_W == 19.0 and Pitch.LARGE_D == 13.0, "Rectangles: 14 x 4.5 m and 19 x 13 m")
	check(Pitch.LINES == [13.0, 20.0, 45.0, 65.0], "Lines at 13, 20, 45 and 65 m")
	check(Pitch.ARC_R == 13.0, "The arc: 13 m from the centre of the 20 m line")
	check(Pitch.in_play(Vector3(Pitch.HALF_L, 0, 0)) and not Pitch.in_play(Vector3(Pitch.HALF_L + 0.2, 0, 0)), "A ball on the line is in play")
	check(Pitch.attack_dir(0, 1) == -Pitch.attack_dir(0, 2), "Ends change at half time")


func _sliotar() -> void:
	# A long puck-out carries about 80-100 m: struck at 40 m/s at 32 degrees.
	var v := Vector3(cos(deg_to_rad(32.0)), sin(deg_to_rad(32.0)), 0) * 40.0
	var land: Array = Sliotar.first_at_height(Vector3(0, 1, 0), v, 0.1)
	check(not land.is_empty() and land[1].x > 70.0 and land[1].x < 110.0, "Sliotar: a 40 m/s puck-out carries 70-110 m (%.0f)" % (land[1].x if not land.is_empty() else 0.0))
	var sol: Array = Sliotar.solve(Vector3(0, 1, 0), Vector3(40, 6, 0), 30.0)
	check(not sol.is_empty(), "Sliotar: a 40 m point at 30 m/s can be aimed")
	if not sol.is_empty():
		var at := Sliotar.predict(Vector3(0, 1, 0), sol[0], float(sol[1]))
		check(at.distance_to(Vector3(40, 6, 0)) < 1.2, "Sliotar: the aimed ball passes the target (%.2f m off)" % at.distance_to(Vector3(40, 6, 0)))


func _plurals() -> void:
	check(Plural.category("en", 1) == "one" and Plural.category("en", 5) == "other", "Plurals: English one/other")
	check(Plural.category("ga", 1) == "one" and Plural.category("ga", 2) == "two" and Plural.category("ga", 4) == "few"
		and Plural.category("ga", 8) == "many" and Plural.category("ga", 15) == "other", "Plurals: Irish one/two/few/many/other")


# ---------------------------------------------------------------- screens

const SCREENS := ["res://ui/main_menu.gd", "res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
	"res://ui/champ_screen.gd", "res://ui/licences_screen.gd", "res://ui/buttons_screen.gd", "res://ui/info_screen.gd"]


func _screens() -> void:
	Game.delete_champ()
	for pair in Game.LANGUAGES:
		Game.settings.language = pair[0]
		TranslationServer.set_locale(pair[0])
		Game._size_theme()
		check(tr("GAME_TITLE") != "GAME_TITLE", "%s: translations load" % pair[0])
		check(tr("BTN_STRIKE") != "BTN_STRIKE" and tr("BTN_STRIKE") != "", "%s: button labels" % pair[0])
		for path in SCREENS:
			var s := Game.show_screen(path)
			await frames(3)
			check(is_instance_valid(s) and s.get_child_count() > 0, "%s: %s builds" % [pair[0], path])
		Game.new_champ("KIL")
		var h := Game.show_screen("res://ui/champ_screen.gd")
		await frames(3)
		check(is_instance_valid(h) and h.get_child_count() > 0, "%s: the championship hub builds" % pair[0])
		Game.delete_champ()
		var r := Game.show_screen("res://ui/result_screen.gd", {"result": _fake_result()})
		await frames(3)
		check(is_instance_valid(r) and r.get_child_count() > 0, "%s: the result screen builds" % pair[0])
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()


func _fake_result() -> Dictionary:
	var ps := {}
	ps["KIL_14"] = {"goals": 1, "points": 3, "free_g": 0, "free_p": 2, "wides": 1, "team": 0, "num": 14}
	ps["TIP_11"] = {"goals": 0, "points": 6, "free_g": 0, "free_p": 5, "wides": 0, "team": 1, "num": 11}
	var ts := {"shots": 20, "wides": 6, "frees": 7, "s65": 2, "sidelines": 3, "puckouts": 14, "yellow": 1, "black": 0, "red": 0,
		"scores_play": 10, "scores_placed": 4}
	return {"config": {"mode": "quick", "stage": "Final"}, "home": "KIL", "away": "TIP", "score": [[2, 15], [1, 17]], "winner": 0,
		"user_team": 0, "pstats": ps, "tstats": [ts, ts.duplicate()], "events": [], "extra_time": true,
		"shootout": {}, "star": "KIL_14"}


## Settings' Licences, Help and Privacy policy: each a button in Settings opening a screen in the game (no browser, so
## offline), with its words in it, a scrolling box and Back to Settings; in both languages.
func _legal_pages() -> void:
	var musts := {
		"LICENCES": ["Permission is hereby granted", "Godot", "SIL Open Font License", "Gregor Quendel", "CC-BY 4.0", "Thimras",
			"Kenney", "charlesheffley009", "framptones", "freesound_community", "Pixabay Content License", "Poly Haven",
			"mocap.cs.cmu.edu", "NSF EIA-0196217", "Mixamo", "Meshy", "HD pack", "cotton_jersey", "concrete_wall_008"],
		"HELP_SUPPORT": ["joshnason8@gmail.com", "HD pack", "Low", "Medium", "High", "version"],
		"PRIVACY_POLICY": ["27 October 2026", "joshnason8@gmail.com", "no analytics, no advertising", "internet", "HD pack"],
	}
	for pair in Game.LANGUAGES:
		Game.settings.language = pair[0]
		TranslationServer.set_locale(pair[0])
		Game._size_theme()
		for key in musts:
			var set_s := Game.show_screen("res://ui/settings_screen.gd")
			await frames(3)
			var b := _button_with(set_s, tr(key))
			check(b != null, "%s: Settings has a %s button" % [pair[0], key])
			if b == null:
				continue
			b.pressed.emit()
			await frames(4)
			var s := Game.current
			var text := _all_text(s)
			check(s != set_s and text.length() > (20000 if key == "LICENCES" else 1200),
				"%s: %s opens a page in the game (%d characters)" % [pair[0], key, text.length()])
			check(_first_scroll(s) != null, "%s: %s scrolls" % [pair[0], key])
			if pair[0] == "en":
				var missing := []
				for m in musts[key]:
					if not text.contains(m):
						missing.append(m)
				check(missing.is_empty(), "%s says what it must (missing: %s)" % [key, ", ".join(missing)])
			check(s.has_meta("back"), "%s: %s has Back" % [pair[0], key])
			if s.has_meta("back"):
				(s.get_meta("back") as Callable).call()
				await frames(2)
				check(String(Game.current.get_script().resource_path).ends_with("settings_screen.gd"),
					"%s: Back from %s is Settings" % [pair[0], key])
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()


func _button_with(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var f := _button_with(c, text)
		if f:
			return f
	return null


func _all_text(n: Node) -> String:
	var t := ""
	if n is Label:
		t = (n as Label).text + "\n"
	elif n is RichTextLabel:
		t = (n as RichTextLabel).get_parsed_text() + "\n"
	for c in n.get_children():
		t += _all_text(c)
	return t


## Each scrolling page scrolls when a drag starts on its words (Kabaddi's How to Play did not).
func _scroll_on_text() -> void:
	Game.new_champ("KIL")
	for path in ["res://ui/howto_screen.gd", "res://ui/licences_screen.gd", "res://ui/settings_screen.gd", "res://ui/quick_setup.gd", "res://ui/result_screen.gd"]:
		var args := {"result": _fake_result()} if path.ends_with("result_screen.gd") else {}
		var s := Game.show_screen(path, args)
		await frames(4)
		var sc := _first_scroll(s)
		check(sc != null, "%s has a scrolling box" % path)
		if sc == null:
			continue
		var bar := sc.get_v_scroll_bar()
		if bar.max_value <= bar.page + 1.0:
			continue
		var lab := _first_label(sc, sc.get_global_rect())
		check(lab != null, "%s: text to drag on" % path)
		if lab == null:
			continue
		check(lab.mouse_filter != Control.MOUSE_FILTER_STOP, "%s: its text lets the touch through" % path)
		var from: Vector2 = lab.get_meta("drag_at")
		await _drag(from, from - Vector2(0, 200))
		check(sc.scroll_vertical > 20, "%s scrolls when dragged on its text (%d)" % [path, sc.scroll_vertical])
	Game.delete_champ()


func _first_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer and (n as ScrollContainer).is_visible_in_tree():
		return n
	for c in n.get_children():
		var f := _first_scroll(c)
		if f:
			return f
	return null


## A label or rich text in the lower part of the box, where a drag up has room.
func _first_label(n: Node, inside: Rect2) -> Control:
	if (n is Label or n is RichTextLabel) and (n as Control).is_visible_in_tree() and String(n.get("text")) != "":
		var r := (n as Control).get_global_rect()
		var band := Rect2(inside.position.x, inside.position.y + inside.size.y * 0.55, inside.size.x, inside.size.y * 0.4)
		if band.intersects(r):
			n.set_meta("drag_at", Vector2(r.get_center().x, clampf(r.get_center().y, band.position.y + 4, band.end.y - 4)))
			return n
	for c in n.get_children():
		var f := _first_label(c, inside)
		if f:
			return f
	return null


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(from, true)
	for i in 12:
		_move(from.lerp(to, float(i + 1) / 12.0))
		await frames(1)
	await frames(6)
	_mouse(to, false)
	await frames(2)


func _mouse(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = at
	e.global_position = at
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.pressed = down
	get_viewport().push_input(e)


func _move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e)


# ---------------------------------------------------------------- the championship, results

func _championship() -> void:
	for team in ["KIL", "LAO", "CLA", "WEX", "DOW"]:
		var c: Championship = Game.new_champ(team)
		var guard := 0
		while c.phase != "done" and guard < 40:
			guard += 1
			# As the hub does: a round without your county (its bye, or out) is played on to your next game.
			c.play_byes()
			var f := c.next_fixture()
			if f.is_empty():
				check(c.phase == "done", "%s: never stuck without a game (%s, round %d)" % [team, c.phase, c.round])
				break
			var r := Sim.play(String(f.home), String(f.away), null, bool(f.knockout))
			c.record_user_result({"home": f.home, "away": f.away, "score": r.score, "winner": r.winner, "extra_time": r.extra_time,
				"shootout": {"goals": r.pens} if not (r.pens as Array).is_empty() else {}})
		check(c.phase == "done" and c.champion != "", "%s: the championship reaches a champion (%s)" % [team, c.champion])
		for g in c.groups:
			for row in c.table(g):
				check(int(row.p) == 4, "%s: each county plays four group games (%s %d)" % [team, row.id, int(row.p)])
				check(int(row.pts) == int(row.w) * 2 + int(row.d), "%s: two points a win, one a draw" % team)
		for f in c.fixtures:
			if bool(f.knockout):
				check(int(f.winner) >= 0, "%s: every knock-out game has a winner" % team)
		var ko := 0
		for f in c.fixtures:
			if bool(f.knockout):
				ko += 1
		check(ko == (7 if c.tier == 1 else 3), "%s: the knock-out games (%d)" % [team, ko])
		Game.save_champ()
		Game.champ = null
		var back = Game.get_champ()
		check(back != null and back.champion == c.champion and back.fixtures.size() == c.fixtures.size(), "%s: it saves and loads" % team)
	Game.delete_champ()


func _sim_scores() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tot := 0
	var goals := 0
	for i in 200:
		var r := Sim.play("KIL", "COR", rng, i % 2 == 0)
		for k in 2:
			tot += Rules.total(r.score[k][0], r.score[k][1])
			goals += int(r.score[k][0])
		if i % 2 == 0:
			check(int(r.winner) >= 0, "Sim: a knock-out game has a winner")
	var avg := float(tot) / 400.0
	check(avg > 20.0 and avg < 34.0, "Sim: a side scores about 20-34 points' worth (%.1f)" % avg)
	check(float(goals) / 200.0 > 1.2 and float(goals) / 200.0 < 4.0, "Sim: about two or three goals a game (%.1f)" % (float(goals) / 200.0))


## The clock fitted to the match length: at the longest the ball live in real time (so the match scores as a real
## one, tests/score_check); shorter lengths faster, in proportion.
func _clock_lengths() -> void:
	var M: GDScript = load("res://game/match.gd")
	var full := 70.0 * 60.0
	check(M.live_clock_k(full, float(Game.LENGTHS[-1])) < 1.1, "Clock: at the longest length the ball is live at about real time")
	var last := 99.0
	for n in Game.LENGTHS:
		var k: float = M.live_clock_k(full, float(n))
		check(k >= 1.0 and k <= last, "Clock: %d min runs %.2fx, no faster than a shorter length" % [n, k])
		last = k
	check(M.live_clock_k(full, 8.0) > 3.0, "Clock: an 8-minute match runs the clock over 3x")
	# A real match has the ball in play about 38% of its time: what stoppages cost on the watch.
	check(is_equal_approx(M.LIVE_SHARE, 0.38), "Clock: the ball live 38% of the watch")
	check(float(M.STOP_COST.puck_out) >= 15.0 and float(M.STOP_COST.free) >= float(M.STOP_COST.puck_out), "Clock: a free costs more time than a puck-out")


## The coach's tips: each when it is needed, once.
func _coach() -> void:
	var none := {}
	check(Coach.pick({"taker": "puck_out"}, none) == "PUCK_OUT", "Coach: your puck-out")
	check(Coach.pick({"taker": "65"}, none) == "FREE", "Coach: your 65 is a free's tip")
	check(Coach.pick({"taker": "penalty"}, none) == "PENALTY", "Coach: your penalty")
	check(Coach.pick({"carrying": true, "in_hand": true, "buttons": ["STRIKE", "PASS", "SOLO"]}, none) == "IN_HAND", "Coach: the ball in your hand: the four steps")
	check(Coach.pick({"carrying": true, "in_hand": false, "buttons": ["STRIKE", "PASS", "HAND"], "goal_dist": 80.0}, none) == "ON_STICK", "Coach: on the hurley")
	check(Coach.pick({"carrying": true, "in_hand": false, "buttons": ["STRIKE", "PASS", "GOAL"], "goal_dist": 22.0}, none) == "GOAL", "Coach: close in, the goal")
	check(Coach.pick({"carrying": true, "goal_dist": 35.0}, {"ON_STICK": true}) == "SHOOT", "Coach: in range, the point")
	check(Coach.pick({"buttons": ["CATCH", "PULL", "SWITCH"]}, none) == "LOOSE", "Coach: the ball near you")
	check(Coach.pick({"buttons": ["TACKLE", "SWITCH"]}, {"MOVE": true}) == "TACKLE", "Coach: tackle")
	check(Coach.pick({"buttons": ["SWITCH"]}, none) == "MOVE", "Coach: first, how to run")
	check(Coach.pick({"buttons": ["SWITCH"], "ball_far": true, "live_s": 30.0}, {"MOVE": true}) == "SWITCH", "Coach: the ball far away: switch")
	check(Coach.pick({"buttons": ["SWITCH"], "ball_far": true, "live_s": 5.0}, {"MOVE": true}) == "", "Coach: not in the first seconds")
	var c := Coach.new()
	var st := {"buttons": ["SWITCH"]}
	check(c.step(0.1, st) == "MOVE", "Coach: a tip shows")
	check(c.step(0.1, st) == "", "Coach: one at a time")
	for i in 120:
		c.step(0.1, st)
	check(c.step(0.1, st) == "" and c.seen.has("MOVE"), "Coach: each tip once")
	check(c.event("STEPS") == "STEPS" and c.event("STEPS") == "", "Coach: the steps tip once, at once")
	for id in Coach.TIPS + ["STEPS", "INTRO"]:
		check(tr(Coach.text_key(id)) != Coach.text_key(id), "Coach: COACH_%s has words" % id)


## Substitutions: five, made at a break; not for a man sent off; the substitute takes the place in the shape.
func _subs() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "COR", "venue": "county", "user_team": 0, "seed": 4, "length": 8.0, "mode": "test"}
	m.set_meta("test", true)
	add_child(m)
	await frames(3)
	var t: Dictionary = m.teams[0]
	var off: Player = m.player_by_num(0, 11)
	var pd: Dictionary = t.bench[0]
	var bench_n: int = t.bench.size()
	check(m.subs_left(0) == 5, "Subs: five a match")
	# The substitutes sit in their dugouts (round five: "add players waiting on the bench").
	var mm: MultiMesh = m.bench._mmi[0].multimesh if m.bench._mmi[0] != null else null
	check(m.bench.seated[0].size() == bench_n and m.bench.seated[1].size() == m.teams[1].bench.size() and mm != null and mm.instance_count == bench_n, "Bench: the %d substitutes sitting in the dugout" % bench_n)
	check(m.ask_sub(off, pd), "Subs: one asked for")
	check(not m.ask_sub(off, t.bench[1]), "Subs: not the same man twice")
	check(m.subs_left(0) == 4, "Subs: the one asked for counts")
	off.fatigue = 0.8
	m._run_subs()
	check(off.data.id == pd.id and off.pos_num == 11 and off.num == int(pd.num), "Subs: the substitute takes the place in the shape (%s, wearing %d)" % [off.data.id, off.num])
	check(off.fatigue == 0.0 and off.came_on == 1, "Subs: fresh legs")
	check(t.bench.size() == bench_n - 1 and int(t.subs) == 1, "Subs: off the bench, one made")
	check(m.bench.seated[0].size() == bench_n - 1 and m.bench._mmi[0].multimesh.instance_count == bench_n - 1, "Bench: the substitute's seat empty")
	var walk: Player = m._leaving[0] if not m._leaving.is_empty() else null
	check(walk != null and walk.has_meta("seat") and absf((walk.get_meta("seat") as Vector3).z - Bench.SEAT_Z) < 1.5, "Bench: the man taken off walks to the dugout")
	m.bench.sit_down(0, walk.data if walk != null else {})
	check(m.bench.seated[0].size() == bench_n, "Bench: and sits down with the substitutes")
	var red: Player = m.player_by_num(0, 5)
	red.sent_off = true
	check(not m.sub_ok(red, t.bench[0]), "Subs: a man sent off is not replaced")
	red.sent_off = false
	for i in 4:
		m.ask_sub(m.player_by_num(0, 2 + i), t.bench[i])
	m._run_subs()
	check(m.subs_left(0) == 0 and not m.sub_ok(m.player_by_num(0, 13), t.bench[0]), "Subs: no sixth in normal time")
	m.half = 3
	check(m.subs_left(0) == 3, "Subs: three more in extra time")
	# The drop ring: a high ball coming down near your player is marked where it reaches hand height.
	var me: Player = m.player_by_num(0, 8)
	m.hud.set_active(me)
	m.ball.place(me.global_position)
	m.ball.global_position = me.global_position + Vector3(-25, 12, 0)
	m.ball.vel = Vector3(9, 4, 0)
	m.ball.state = Sliotar.FREE
	var drop: Vector3 = m.hud._drop_spot()
	var hit: Array = Sliotar.first_at_height(m.ball.global_position, m.ball.vel, m.CATCH_H)
	check(drop != Vector3.INF and not hit.is_empty() and Vector2(drop.x - hit[1].x, drop.z - hit[1].z).length() < 0.01, "Ball: a high ball is marked where it comes down")
	m.ball.global_position = me.global_position + Vector3(0, 1, 0)
	check(m.hud._drop_spot() == Vector3.INF, "Ball: no ring for a ball at hand height")
	# Switched to a man standing in the ring: CATCH and PULL up at once, and pressed early, kept till the ball comes
	# into reach (round five: "the buttons should come up quicker so you can plan what to do").
	m.phase = m.P.LIVE
	m.controls.visible = true
	m.carrier = null
	m.ball.global_position = me.global_position + Vector3(-25, 12, 0)
	var land := Sliotar.first_at_height(m.ball.global_position, m.ball.vel, m.CATCH_H)
	if not land.is_empty():
		me.position = Vector3(land[1].x + 1.5, 0.0, land[1].z)
	m.active = me
	m.hud.set_active(me)
	var ids: Array = m.user_buttons()
	check("CATCH" in ids and "PULL" in ids, "Buttons: CATCH and PULL as soon as you are switched to the man under a dropping ball (%s)" % [ids])
	m._on_action("CATCH")
	check(String(m._queued.get("id", "")) == "CATCH", "Buttons: CATCH pressed early waits for the ball")
	m._queued = {}
	# Tiredness: a sprint tires a man more than a walk, and a man with stamina less.
	var a := Player.new({"stamina": 90, "speed": 80}, 0, {})
	var b := Player.new({"stamina": 50, "speed": 80}, 0, {})
	for i in 300:
		a.want_vel = Vector3(8, 0, 0)
		b.want_vel = Vector3(8, 0, 0)
		a.integrate(1.0 / 30.0, 0.0)
		b.integrate(1.0 / 30.0, 0.0)
	check(a.fatigue > 0.0 and b.fatigue > a.fatigue * 1.2, "Tiredness: stamina tells (%.3f v %.3f)" % [a.fatigue, b.fatigue])
	check(a.top_speed() < Player.speed_of({"speed": 80}), "Tiredness: a tired man is slower")
	a.free()
	b.free()
	m.queue_free()
	await frames(2)


## Tactics: the sweeper sits in front of his full-back line marking no one; two inside sends the corner-forward out;
## the puck-out style changes how often it goes short.
func _tactics() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "COR", "venue": "county", "user_team": -1, "seed": 6, "length": 8.0, "mode": "test",
		"tactics": [{"sweeper": true, "two_ff": true, "puckout": 0}, {"sweeper": false, "two_ff": false, "puckout": 2}]}
	m.set_meta("test", true)
	add_child(m)
	await frames(3)
	m.ball.place(Vector3.ZERO)
	var t: TeamAI = m.ai[0]
	var sw: Player = m.player_by_num(0, 12)
	var from_own := func(p: Vector3, k: int) -> float: return Pitch.HALF_L + p.x * m.dir(k)
	var sx: float = from_own.call(t.home_spot(sw), 0)
	var fb: float = from_own.call(t.home_spot(m.player_by_num(0, 3)), 0)
	var hb: float = from_own.call(t.home_spot(m.player_by_num(0, 6)), 0)
	check(sx > fb and sx < hb and t.mark_of(sw) == null, "Tactics: the sweeper between his full-backs (%.0f m) and half-backs (%.0f m), at %.0f m, marking no one" % [fb, hb, sx])
	var out13: float = from_own.call(t.home_spot(m.player_by_num(0, 13)), 0)
	var in14: float = from_own.call(t.home_spot(m.player_by_num(0, 14)), 0)
	check(in14 - out13 > 15.0, "Tactics: two inside, the corner-forward out the field (%.0f m behind the full-forward)" % (in14 - out13))
	var u: TeamAI = m.ai[1]
	check(u.mark_of(m.player_by_num(1, 12)) != null and absf(from_own.call(u.home_spot(m.player_by_num(1, 13)), 1) - from_own.call(u.home_spot(m.player_by_num(1, 14)), 1)) < 6.0, "Tactics: without them, the lines as usual")
	var shorts := [0, 0]
	for k in 2:
		for i in 200:
			if String(m.ai[k].puck_out_choice(m.player_by_num(k, 1)).kind) == "short":
				shorts[k] += 1
	check(shorts[0] > shorts[1] * 2, "Tactics: short puck-outs go short more than long ones (%d v %d in 200)" % shorts)
	m.queue_free()
	await frames(2)


## What the browser playtest found (docs/PLAYTEST.md), each held to its fix.
func _playtest_fixes() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "TIP", "venue": "parish", "user_team": 0, "seed": 8, "length": 8.0, "mode": "test"}
	add_child(m)
	await frames(3)
	var keep: Dictionary = Game.settings.duplicate(true)
	# The coach's card never covers a button: every size, either hand, the most buttons there are.
	m.controls.set_buttons(["STRIKE", "PASS", "SOLO", "GOAL", "SWITCH"])
	var clear := true
	for lh in [false, true]:
		for size in 3:
			Game.settings.left_handed = lh
			Game.settings.btn_size = size
			m.hud.coach("SHOOT")
			await frames(2)
			var card: Rect2 = m.hud._coach.get_global_rect()
			for b in m.controls._layout():
				var c: Vector2 = b[1]
				var r: float = b[2]
				var near := Vector2(clampf(c.x, card.position.x, card.end.x), clampf(c.y, card.position.y, card.end.y))
				if near.distance_to(c) < r:
					clear = false
	check(clear, "Playtest: the coach's card clear of every button (each size, either hand)")
	Game.settings.left_handed = keep.left_handed
	Game.settings.btn_size = keep.btn_size
	# Your pass goes to the free man the way you point, not the marked one straight ahead.
	var me: Player = m.player_by_num(0, 6)
	var d: float = m.dir(0)
	for q in m.all_players():
		(q as Player).global_position = Vector3(0, 0, 60)    # everyone out of the way
	me.global_position = Vector3(0, 0, 0)
	var marked: Player = m.player_by_num(0, 11)
	var free: Player = m.player_by_num(0, 12)
	marked.global_position = Vector3(d * 30.0, 0, 0)
	free.global_position = Vector3(d * 26.0, 0, 14.0)
	m.player_by_num(1, 6).global_position = Vector3(d * 29.0, 0, 0.8)     # his marker, tight
	m.player_by_num(1, 7).global_position = Vector3(d * 15.0, 0, 0.3)     # and one in the lane
	var j: Vector2 = Vector2.ZERO
	for i in 64:
		var a := TAU * i / 64.0
		var cand := Vector2(cos(a), sin(a))
		if m._cam_dir(cand).dot(Vector3(d, 0, 0)) > 0.99:
			j = cand
	check(m._pass_option(me, j) == free, "Playtest: PASS toward goal finds the free man, not the marked one straight ahead")
	TouchControls.touch_seen = false
	var t := InputEventScreenTouch.new()
	t.position = Vector2(900, 300)
	t.pressed = true
	m.controls._input(t)
	t.pressed = false
	m.controls._input(t)
	check(TouchControls.touch_seen, "Playtest: no keyboard hints on the buttons once the screen is touched")
	TouchControls.touch_seen = false
	m.queue_free()
	await frames(2)
	# No floodlight mast between the television gantry and the field.
	var in_way := 0
	var brown := 0
	for id in DB.VENUES:
		var st := Stadium.new(String(id), [Color.WHITE, Color.BLACK])
		add_child(st)
		await frames(1)
		for p in st.mast_spots:
			if p.z > 0.0 and p.z < CameraRig.GANTRY_Z:
				in_way += 1
		var we: WorldEnvironment = st.find_children("*", "WorldEnvironment", true, false)[0]
		# A photographed sky (its horizon's own haze below the skyline), never the engine's default brown ground.
		var sm := we.environment.sky.sky_material
		if not (sm is PanoramaSkyMaterial and (sm as PanoramaSkyMaterial).panorama != null):
			brown += 1
		st.queue_free()
	check(in_way == 0, "Playtest: no floodlight mast in front of the camera (%d)" % in_way)
	check(brown == 0, "Playtest: past the fields, a real sky's horizon, not the sky's default brown (%d grounds)" % brown)
	# On a touch screen a button looks the same hovered as not (a finger leaves the emulated mouse where it lifts).
	var th: Theme = Game.theme.duplicate()
	Game.flatten_hover(th)
	check(th.get_stylebox("hover", "ChipButton") == th.get_stylebox("normal", "ChipButton") and th.get_stylebox("hover", "Button") == th.get_stylebox("normal", "Button"), "Playtest: no hover look on a touch screen")
	# Match setup remembers the ground.
	Game.settings.venue = "stadium"
	var q: Control = load("res://ui/quick_setup.gd").new()
	add_child(q)
	await frames(2)
	check(String(q._venue) == "stadium", "Playtest: match setup remembers the ground")
	q.queue_free()
	Game.settings = keep
	await frames(1)


## Over the end line the ball flies on into a net and drops (round three: it used to stop dead in the air).
func _nets() -> void:
	var b := Sliotar.new()
	add_child(b)
	await frames(1)
	b.backstop = Vector3(9.0, 24.0, 14.0)
	# A wide, high and hard: it reaches the ball-stop net and no further.
	b.place(Vector3(Pitch.HALF_L - 30.0, 0, 15.0))
	b.global_position = Vector3(Pitch.HALF_L - 30.0, 1.0, 15.0)
	b.launch(Vector3(32.0, 9.0, 3.0), null, "strike")
	for i in 240:
		b.step(1.0 / 60.0)
		if b.global_position.x > Pitch.HALF_L and b.state == Sliotar.FREE:
			b.state = Sliotar.OUT
	check(b.global_position.x <= Pitch.HALF_L + 9.05 and b.global_position.x > Pitch.HALF_L + 5.0 and b.global_position.y < 0.5, "Nets: a wide flies on into the ball-stop net and drops (%.1f m behind, %.1f m up)" % [b.global_position.x - Pitch.HALF_L, b.global_position.y])
	# A goal: it stops in the goal's net.
	b.place(Vector3(Pitch.HALF_L - 12.0, 0, 0))
	b.global_position = Vector3(Pitch.HALF_L - 12.0, 0.8, 0.5)
	b.launch(Vector3(34.0, 0.6, 0.0), null, "strike")
	for i in 180:
		b.step(1.0 / 60.0)
		if b.global_position.x > Pitch.HALF_L and b.state == Sliotar.FREE:
			b.state = Sliotar.OUT
	check(b.global_position.x <= Pitch.HALF_L + Pitch.NET_DEPTH + 0.05 and b.global_position.x > Pitch.HALF_L, "Nets: a goal stays in the net (%.2f m behind the line)" % (b.global_position.x - Pitch.HALF_L))
	b.queue_free()
	await frames(1)


# ---------------------------------------------------------------- the grounds' surrounds

## Every ground dressed from the shared assets: trees and hedgerows round it, the parish field's village and lough,
## the towns round the county ground and the stadium; nothing of it on the field or in the camera's foreground; a
## real sky; one draw call a kind of thing, so the surrounds stay a dozen draws at most.
func _scenery() -> void:
	var keep := int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_LOW
	for v in ["parish", "county", "stadium", "night"]:
		var st := Stadium.new(v)
		add_child(st)
		await frames(1)
		var sc: Scenery = st.scenery
		var trees := sc.count("oak_tree_card") + sc.count("broadleaf_tree_dark_card")
		check(trees >= 20 and sc.count("small_broadleaf_card") >= 100, "Scenery %s: trees (%d) and hedgerows (%d bushes)" % [v, trees, sc.count("small_broadleaf_card")])
		if v == "parish":
			check(_count_prefix(sc, "house_cottage") >= 3 and sc.count("mossy_rocks_low") > 0 and sc.count("painted_bench_low") > 0, "Scenery parish: the village, the stone wall, the subs' benches")
			var through := 0
			for name in ["small_broadleaf_card", "grass_wispy_card", "grass_clumps_card", "fern_card"]:
				for t: Transform3D in sc.placed(name):
					if Stadium.VILLAGE.has_point(Vector2(t.origin.x, t.origin.z)):
						through += 1
			check(through == 0, "Scenery parish: no hedgerow through the village's houses (%d)" % through)
		else:
			check(_count_prefix(sc, "house_row") >= 8 and sc.count("street_lamp_tall_low") > 0, "Scenery %s: the town's terraced rows and street lamps" % v)
		var bad := 0
		for name in sc.names():
			for t: Transform3D in sc.placed(name):
				var o := t.origin
				var on_field := absf(o.x) < Pitch.HALF_L + 1.0 and absf(o.z) < Pitch.HALF_W + 1.0
				var foreground := o.z > Pitch.HALF_W + 3.0 and o.z < CameraRig.GANTRY_Z and absf(o.x) < Pitch.HALF_L
				if on_field or foreground:
					bad += 1
					if bad < 4:
						print("  ", v, " ", name, " at ", o)
		check(bad == 0, "Scenery %s: nothing on the field or in front of the camera (%d)" % [v, bad])
		# One a kind: the parish field the most (its village and hedgerows, and since 0.5.0 the floodlights).
		check(sc.get_child_count() <= 13, "Scenery %s: %d draw calls" % [v, sc.get_child_count()])
		if v != "parish":
			check(sc.count("floodlight") >= 4, "Scenery %s: the floodlights (%d)" % [v, sc.count("floodlight")])
		# The crowd faces the play: every spectator toward the centre of the field; from the television gantry (behind
		# the near stand) the near stand is seen from behind, the far one from the front (round four: "the crowd to the
		# near side is looking the wrong direction").
		var cr: Crowd = st.crowd
		check(cr.material_override is ShaderMaterial and (cr.material_override as ShaderMaterial).get_shader_parameter("mask") != null and Crowd.sheet().get_width() == Crowd.FIG_W * Crowd.FIGS * 2, "Crowd %s: the rendered fans and their shirt mask" % v)
		var wrong := 0
		var near_back := 0
		var near := 0
		var far_front := 0
		var far := 0
		var gantry := Vector3(0.0, CameraRig.GANTRY_H, CameraRig.GANTRY_Z)
		for i in cr.spots.size():
			var sp: Vector3 = cr.spots[i]
			var f: Vector3 = cr.facings[i]
			if f.dot(Vector3(-sp.x, 0.0, -sp.z).normalized()) <= 0.7:
				wrong += 1
			# Opposite the gantry (people further along face the centre at an angle, so a camera at halfway is in front).
			if sp.z > Pitch.HALF_W and absf(sp.x) < 20.0:
				near += 1
				near_back += 1 if Crowd.seen_from_behind(sp, f, gantry) else 0
			elif sp.z < -Pitch.HALF_W and absf(sp.x) < 20.0:
				far += 1
				far_front += 0 if Crowd.seen_from_behind(sp, f, gantry) else 1
		check(cr.spots.size() > 0 and wrong == 0, "Crowd %s: all %d face the field (%d do not)" % [v, cr.spots.size(), wrong])
		check(near > 0 and near_back == near and far_front == far, "Crowd %s: from the gantry the near side's %d seen from behind, the far side's %d from the front" % [v, near, far])
		var we: WorldEnvironment = st.find_children("*", "WorldEnvironment", false, false)[0]
		check(we.environment.sky.sky_material is PanoramaSkyMaterial, "Scenery %s: a real sky (%s)" % [v, st.sky_name()])
		st.queue_free()
		await frames(1)
	Game.settings.graphics = keep


# ---------------------------------------------------------------- the owner's model, its clips, the replay

## The owner's player model as baked for phones (tools/player): small enough, on the game's seventeen bones; the
## Mixamo clips in step with the game: the sprint's left thigh forward at the stride's phase pi/2, the swing's bas
## coming past the striker the way he faces at the moment of contact.
func _hero_body() -> void:
	var hi: ArrayMesh = load("res://assets/player/hero_hi.res")
	var lo: ArrayMesh = load("res://assets/player/hero_lo.res")
	var tris_hi := hi.surface_get_array_index_len(0) / 3
	var tris_lo := lo.surface_get_array_index_len(0) / 3
	check(tris_hi <= 6500 and tris_lo <= 2000, "Player model: %d triangles (%d on Low)" % [tris_hi, tris_lo])
	var tex: Texture2D = load("res://assets/player/hero_albedo.jpg")
	check(tex.get_width() <= 1024 and tex.get_height() <= 1024, "Player model: its texture at most 1024 square")
	var pl := Player.new({"num": 9, "line": 4, "speed": 70}, 0, {"jersey": Color("c8202f"), "trim": Color.WHITE, "kind": "player"})
	add_child(pl)
	await frames(1)
	check(pl.body is HeroBody and pl.body.skeleton.get_bone_count() == ToonBody.BONES.size(), "A hurler is drawn with the owner's model, on the game's bones")
	var ref := Player.new({}, -1, {"kind": "referee"}, "referee")
	add_child(ref)
	await frames(1)
	check(ref.body is PersonBody and (ref.body as PersonBody).who == "referee", "A referee is drawn with the referee's model")
	var ump := Player.new({}, -1, {"kind": "umpire"}, "umpire")
	add_child(ump)
	await frames(1)
	check(ump.body is PersonBody and (ump.body as PersonBody).who == "umpire", "An umpire is drawn with the umpire's model, in his white coat")
	ump.queue_free()
	# The sprint: at full speed, phase pi/2, the left thigh swung forward and the right back.
	pl.vel = Vector3(0, 0, 7.5)
	pl._ph = PI * 0.5
	var p: Dictionary = pl._pose(0.0)
	var lt := HeroBody.turn(p.thigh_l) * Vector3.DOWN
	var rt := HeroBody.turn(p.thigh_r) * Vector3.DOWN
	check(lt.z > 0.25 and rt.z < lt.z, "The sprint clip: the left thigh forward at the stride's phase pi/2 (%.2f, the right %.2f)" % [lt.z, rt.z])
	# The gaits from motion capture (the CMU walk and jog, the Mixamo sprint): loaded, and moving at each one's own
	# speed the foot on the ground stays put (the stride's length is the recording's), within 0.35 m/s (tools/mocap).
	for g in Player.GAITS:
		check(HeroBody.data().clips.has(g[0]) and HeroBody.data().clips[g[0]].frames.size() > 10, "The %s clip loads" % g[0])
	# On Low and on High (with the HD pack's clips where it has them), whatever level this machine picked.
	var level = Game.settings.graphics
	for lv in [Game.GFX_LOW, Game.GFX_HIGH]:
		Game.settings.graphics = lv
		for g in [["CMU_Walk", 1.3], ["CMU_Jog", 2.6]]:
			var slide := _foot_slide(float(g[1]))
			check(slide < 0.35, "The %s clip (graphics %d): the planted foot slides %.2f m/s at %.2f m/s" % [g[0], lv, slide, g[1]])
		# And at a run and flat out, the steps longer than the clip's own: the foot held where it lands (Player
		# _plant_feet; it slid 1.6 m/s at 7 m/s, 3 at 8.5, before 0.17.0: the owner saw the players "floating").
		for sp in [4.0, 7.0, 8.4]:
			var slide := _foot_slide(sp)
			check(slide < 0.3, "The run (graphics %d): the planted foot slides %.2f m/s at %.1f m/s" % [lv, slide, sp])
		check(7.0 / Player.stride_at(7.0) < 3.8 and 4.0 / Player.stride_at(4.0) < 3.1,
			"The run: a footballer's steps, %.1f a second at 4 m/s, %.1f at 7 (not a whirl)" % [4.0 / Player.stride_at(4.0), 7.0 / Player.stride_at(7.0)])
	Game.settings.graphics = level
	# The swings: at the contact time the bas comes past him going the way he faces (where the ball goes), within
	# his reach, below the shoulder.
	pl.vel = Vector3.ZERO
	pl.yaw = 0.0
	pl.body.rotation.y = 0.0
	for a in ["strike", "ground", "pull"]:
		pl.play(a)
		var at := []
		for dt in [-0.02, 0.0, 0.02]:
			pl.action_t = pl.contact_time(a) + dt
			pl.body.apply(pl._pose(0.0))     # the clip itself (High's blend into it is checked below)
			at.append(pl.body.bas_world() - pl.global_position)
		var mv: Vector3 = at[2] - at[0]
		var bas: Vector3 = at[1]
		var ok := mv.z > absf(mv.x) and bas.z > -0.5 and Vector2(bas.x, bas.z).length() < 1.9 and bas.y < 1.7 * Player.DRAW_SCALE
		check(ok, "The %s clip: the bas comes past him going forward at contact (at %.2f across, %.2f forward, %.2f up; moving %.2f across, %.2f forward)" % [a, bas.x, bas.z, bas.y, mv.x, mv.z])
	# High's blend from one move into the next: under way just after the change, done FADE seconds on (the body then
	# as the move's own pose).
	var keep_g = Game.settings.graphics
	Game.settings.graphics = Game.GFX_HIGH
	if Ultra.lit():
		pl.play("strike")
		pl.action_t = 0.1
		pl._crossfade(pl._pose(0.0), 0.0)
		pl.play("ground")
		pl.action_t = pl.contact_time("ground")
		var raw: Dictionary = pl._pose(0.0)
		var mid: Dictionary = pl._crossfade(raw.duplicate(), 1.0 / 30.0)
		var t := 1.0 / 30.0
		var done := {}
		while t < Player.FADE + 0.1:
			t += 1.0 / 30.0
			done = pl._crossfade(raw.duplicate(), t)
		var off_mid: float = HeroBody.turn(mid.thigh_r).angle_to(HeroBody.turn(raw.thigh_r))
		var off_done: float = HeroBody.turn(done.thigh_r).angle_to(HeroBody.turn(raw.thigh_r))
		check(off_done < 0.01 and pl._fade == 0.0, "High: the blend into the next move is done after %.2f s (%.3f rad off at the end, %.3f a frame in)" % [Player.FADE, off_done, off_mid])
	Game.settings.graphics = keep_g
	pl.queue_free()
	ref.queue_free()
	await frames(1)


## How fast the foot on the ground moves (m/s, along the ground) for a man running straight at sp m/s, over two
## seconds: the median over the frames when the lower foot is within 12 mm of the lowest a foot gets (on the ground;
## the median, so a foot coming down at the end of its swing does not count).
func _foot_slide(sp: float) -> float:
	var pl := Player.new({"num": 9, "line": 4, "speed": 99, "accel": 99}, 0, {"jersey": Color.RED, "trim": Color.WHITE, "kind": "player"})
	add_child(pl)
	pl.vel = Vector3(0, 0, sp)
	pl.yaw = 0.0
	var sk: Skeleton3D = pl.body.skeleton
	var feet := [sk.find_bone("foot_l"), sk.find_bone("foot_r")]
	var rows := []
	var dt := 1.0 / 30.0
	for f in 90:
		pl.position += Vector3(0, 0, sp * dt)
		pl.vel = Vector3(0, 0, sp)
		pl._ph += sp / Player.stride_at(sp, pl.body.scale.x) * PI * dt
		pl.body.rotation.y = 0.0
		pl.body.apply(pl._pose(f * dt))
		pl._plant_feet(f * dt)
		var at := []
		for b in feet:
			at.append(sk.global_transform * sk.get_bone_global_pose(b).origin)
		rows.append(at)
	var low := INF
	for r in rows:
		low = minf(low, minf(r[0].y, r[1].y))
	var speeds := []
	for f in range(1, rows.size()):
		for k in 2:
			var a: Vector3 = rows[f - 1][k]
			var b: Vector3 = rows[f][k]
			if b.y < low + 0.002 and b.y <= rows[f][1 - k].y:
				speeds.append(Vector2(b.x - a.x, b.z - a.z).length() / dt)
	pl.free()
	speeds.sort()
	return speeds[speeds.size() / 2] if not speeds.is_empty() else INF


## A wide shown again: from its own camera, the HUD's tag and tap-to-skip up, the controls hidden; at its end (or a
## tap) everyone and the ball back where they were, the match camera and the controls back.
func _replay() -> void:
	Game.settings.coach = false
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "WEX", "venue": "county", "user_team": 0, "seed": 3, "length": 4.0, "mode": "test"}
	m.set_meta("test", true)
	add_child(m)
	await frames(200)
	var before := {}
	for pl in m.all_players():
		before[pl] = (pl as Player).position
	var ball0: Vector3 = m.ball.global_position
	m.replay.start(m.now - 1.0, 1.0, Vector3(Pitch.HALF_L, 2.0, 9.0))
	check(m.replay.playing and not m.controls.visible and m.hud._replay != null and not m.cam.camera.current, "Replay: its own camera, the tag and tap-to-skip, no controls")
	var n := 0
	var moved := false
	while m.replay.playing and n < 400:
		await frames(1)
		n += 1
		if n == 20:
			for pl in m.all_players():
				moved = moved or (pl as Player).position.distance_to(before[pl]) > 0.3
	check(n > 60 and n < 300 and moved, "Replay: plays the last seconds again (%d frames)" % n)
	var back := true
	for pl in m.all_players():
		back = back and (pl as Player).position.distance_to(before[pl]) < 0.001
	check(back and m.ball.global_position.distance_to(ball0) < 0.001, "Replay: everyone and the ball back where they were")
	check(m.controls.visible and m.hud._replay == null and m.cam.camera.current, "Replay: the match camera and the controls back")
	m.replay.start(m.now - 1.0, -1.0, Vector3(-Pitch.HALF_L, 2.0, -9.0))
	await frames(5)
	m.replay.stop()
	check(not m.replay.playing and m.controls.visible, "Replay: a tap skips it")
	# Every score shown again (round five: "I'm not seeing replays after scores").
	m._score(0, "point", {})
	n = 0
	while not m.replay.playing and n < 90:
		await frames(1)
		n += 1
	check(m.replay.playing, "Replay: a score shown again (%d frames after)" % n)
	m.replay.stop()
	var rim: Array = m.ball.find_children("*", "MeshInstance3D", true, false).filter(func(x): return x.mesh is TorusMesh)
	check(rim.size() == 1, "Sliotar: its rim (the stitched band)")
	m.queue_free()
	await frames(2)
	# Watching a match (no side yours): nothing kept for a replay, the scoreboard still running.
	var w: Node = load("res://game/match.gd").new()
	w.config = {"home": "KIL", "away": "WEX", "venue": "county", "user_team": -1, "seed": 3, "length": 4.0, "mode": "test"}
	add_child(w)
	await frames(30)
	check(w.replay._buf.is_empty() and w.hud._half.text != "", "Watching a match: no replay kept, the scoreboard ticking")
	w.queue_free()
	await frames(2)


## Low loads exactly the textures it always has; Medium and High the sharper ones beside them (2K grass, the
## player's 2048 texture and 1024 kit mask, the officials' 1024 ones, the crowd's 24-figure sheet).
func _hd_textures() -> void:
	var keep := int(Game.settings.graphics)
	var files := ["res://assets/env/ground/grass_ground_albedo_1k.jpg", "res://assets/env/ground/grass_ground_normal_1k.jpg",
		"res://assets/env/ground/sparse_grass_albedo_1k.jpg", "res://assets/env/ground/withered_grass_albedo_1k.jpg",
		"res://assets/env/ground/leafy_grass_albedo_1k.jpg", "res://assets/player/hero_albedo.jpg",
		"res://assets/player/hero_mask.png", "res://assets/crowd/sheet.png", "res://assets/crowd/mask.png"]
	Game.settings.graphics = Game.GFX_LOW
	var low := files.filter(func(f): return Game.hd(f) != f)
	check(low.is_empty(), "Low: the same textures as before (%s)" % [low])
	for g in [Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		var bad := []
		for f in files:
			var h := Game.hd(f)
			var a: Texture2D = load(f)
			var b: Texture2D = load(h) if h != f else null
			if b == null or b.get_width() < a.get_width() * 2:
				bad.append(f.get_file())
		check(bad.is_empty(), "Graphics %d: each texture has one twice as sharp (%s)" % [g, bad])
	# The officials: Low's lighter models with their 512 textures; Medium and High (no HD pack) the whole Meshy models
	# and textures twice as sharp.
	Ultra.removed = true     # (as a phone without the HD pack has it: the pack's files are in the project here)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for who in ["referee", "umpire"]:
			var pb := PersonBody.new({"kind": who, "model": who})
			add_child(pb)
			var tex: Texture2D = pb.mesh_instance.material_override.get_shader_parameter("albedo")
			var tris: int = pb.mesh_instance.mesh.surface_get_array_index_len(0) / 3
			var ok: bool = (tris < 5000 and tex.get_width() == 512) if g == Game.GFX_LOW else (tris > 8000 and tex.get_width() == 1024)
			check(ok, "Graphics %d: the %s, %d triangles, a %d texture" % [g, who, tris, tex.get_width()])
			pb.free()
	Game.settings.graphics = Game.GFX_HIGH
	check(Crowd.material().get_shader_parameter("figs") == float(Crowd.FIGS_HD) and Crowd.sheet().get_width() == 128 * Crowd.FIGS_HD, "Crowd on High: the 24 figures")
	Ultra.removed = false
	Game.settings.graphics = keep


## Every man's shadow on the grass on Medium (one draw call), from his feet away from the sun; none on Low; on High
## with Vulkan the sun's own shadows instead (cast on the lit grass).
func _shadows() -> void:
	var keep := int(Game.settings.graphics)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		var m: Node = load("res://game/match.gd").new()
		m.config = {"home": "KIL", "away": "TIP", "venue": "stadium", "user_team": -1, "seed": 5, "length": 8.0, "mode": "test"}
		m.set_meta("test", true)
		add_child(m)
		await frames(5)
		if g == Game.GFX_LOW:
			check(m.shadows == null, "Shadows: none on Low")
		elif g == Game.GFX_HIGH and Ultra.lit():
			var sun: DirectionalLight3D = m.stadium.find_children("*", "DirectionalLight3D", true, false)[0]
			check(m.shadows == null and sun.shadow_enabled, "Shadows on High (Vulkan): the sun's own")
		else:
			var sh: PlayerShadows = m.shadows
			var n := 0
			for pl in m.all_players() + m.officials.people:
				n += 1 if (pl as Player).visible else 0
			var ok := sh != null and sh.multimesh.visible_instance_count == n
			# (Headless, the renderer keeps no instance transforms to read back: the direction they are laid along.)
			var away: bool = ok and sh._dir.dot(Vector3(-m.stadium.to_sun.x, 0, -m.stadium.to_sun.z).normalized()) > 0.99 \
				and sh._len > 0.6
			check(ok and away, "Shadows on %s: one for each of the %d men, all away from the sun" % ["Medium" if g == 1 else "High", n])
		m.queue_free()
		await frames(2)
	Game.settings.graphics = keep


## The renderer and High (game/ultra.gd): High and the HD pack offered on a strong phone (a computer here); High's
## extras only on High and Vulkan; the fallback to GL written for the next start and said once in Settings; the HD
## pack's screen and its check.
func _ultra() -> void:
	var keep := int(Game.settings.graphics)
	check(Ultra._model_number("adreno (tm) 740", "adreno") == 740 and Ultra._model_number("mali-g710 mc10", "mali-g") == 710
		and Ultra._model_number("mali-g78", "mali-g") == 78 and Ultra._model_number("powervr", "adreno") == 0, "Graphics: GPU model numbers read")
	check(Ultra.capable() and Game.detect_graphics() == Game.GFX_HIGH, "Graphics: High and the HD pack offered on a computer")
	check(not Ultra.weak_vulkan("Adreno (TM) 740") and not Ultra.weak_vulkan("Mali-G52 MC2"), "Graphics: a computer never sent to GL")
	# Only the game itself (main.gd) marks a start on Vulkan: a test or a tool leaves no flag, so the next start is not
	# taken for a crash and sent to GL.
	check(not FileAccess.file_exists(Ultra.BOOT_FLAG) and not FileAccess.file_exists(Ultra.OVERRIDE), "Graphics: no start flag or override from a test run")
	# High's extras need Vulkan; Low and Medium have none of them.
	Game.settings.graphics = Game.GFX_MEDIUM
	check(not Ultra.lit() and not Ultra.active(), "Graphics: Medium, none of High's extras")
	Game.settings.graphics = Game.GFX_HIGH
	check(Ultra.lit() == Ultra.renderer_ready(), "Graphics: High's lighting on Vulkan (%s)" % RenderingServer.get_current_rendering_method())
	# The fallback to GL Compatibility: written for the next start, and taken back.
	Ultra.use_gl(true)
	var cfg := ConfigFile.new()
	check(cfg.load(Ultra.OVERRIDE) == OK and cfg.get_value("rendering", "renderer/rendering_method.mobile", "") == "gl_compatibility",
		"Graphics: the fallback writes the GL renderer for the next start")
	Ultra.use_gl(false)
	check(not FileAccess.file_exists(Ultra.OVERRIDE), "Graphics: and takes it back")
	# A start on Vulkan that never reached the home screen: GL from the next start, said once in Settings.
	if Ultra.renderer_ready():
		var flag := FileAccess.open(Ultra.BOOT_FLAG, FileAccess.WRITE)
		flag.store_string("x")
		flag.close()
		Ultra.boot()
		check(Ultra.fell_back == "crash" and FileAccess.file_exists(Ultra.OVERRIDE), "Graphics: a failed start on Vulkan, GL from the next")
		Ultra.use_gl(false)
	else:
		Ultra.fell_back = "crash"
	var s := Game.show_screen("res://ui/settings_screen.gd")
	await frames(3)
	check(_find_text(s, tr("VULKAN_BACK_crash")) and Ultra.fell_back == "", "Graphics: Settings says so, once")
	check(_find_text(s, tr("GFX_HIGH")) and _find_text(s, tr("HD_OPEN")), "Graphics: Low, Medium, High, and the HD pack")
	var u := Game.show_screen("res://ui/hd_pack_screen.gd")
	if u._dl != null:
		u._dl.cancel()
	await frames(3)
	check(is_instance_valid(u) and _find_text(u, tr("HD_INTRO")), "Graphics: the HD pack screen")
	# The pack: whole by its manifest's size, checked by its SHA-256 (a finished download goes straight to the check).
	Ultra.remove_pack()
	check(not Ultra.pack_ready(), "Ultra: no pack")
	DirAccess.make_dir_recursive_absolute(Ultra.DIR)
	var body := "hurling".repeat(1000).to_utf8_buffer()
	var sha := body.hex_encode()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(body)
	sha = ctx.finish().hex_encode()
	for want in ["0".repeat(64), sha]:
		var f := FileAccess.open(Ultra.pack_path() + ".part", FileAccess.WRITE)
		f.store_buffer(body)
		f.close()
		var dl := Ultra.new()
		add_child(dl)
		dl.use(Ultra.pack_name(), body.size(), want, Ultra.pack_path())
		var got := []
		dl.finished.connect(func(ok, why): got.append([ok, why]))
		dl.download()
		for i in 20:
			if not got.is_empty():
				break
			await frames(1)
		check(got == ([[false, "corrupt"]] if want != sha else [[true, ""]]), "HD pack: a pack %s its check (%s)" % ["failing" if want != sha else "passing", got])
		dl.queue_free()
	var man := FileAccess.open(Ultra.DIR + Ultra.manifest_name(), FileAccess.WRITE)
	man.store_string(JSON.stringify({"pack": Ultra.PACK, "size": body.size(), "sha256": sha}))
	man.close()
	check(Ultra.pack_ready(), "Ultra: the pack, whole")
	Ultra.remove_pack()
	check(not Ultra.pack_ready() and not FileAccess.file_exists(Ultra.pack_path()), "Ultra: the pack removed")
	# The vertex-coloured structure lit per vertex below High; per pixel on High with Vulkan.
	Game.settings.graphics = Game.GFX_MEDIUM
	var med := Geo.material()
	Game.settings.graphics = Game.GFX_HIGH
	var hi := Geo.material()
	check(med.shading_mode == BaseMaterial3D.SHADING_MODE_PER_VERTEX and (hi.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL) == Ultra.lit(),
		"Graphics: Medium lit per vertex, High per pixel on Vulkan")
	Game.settings.graphics = keep
	Game.show_screen("res://ui/main_menu.gd")
	await frames(2)


## With help with the ball on, your player picks up a ball he runs onto by himself (the owner found the LIFT button
## too quick to hit); with it off, he waits for the button.
func _auto_pickup() -> void:
	var keep := int(Game.settings.get("assist", 1))
	for assist in [1, 0]:
		Game.settings.assist = assist
		var m: Node = load("res://game/match.gd").new()
		m.config = {"home": "KIL", "away": "TIP", "venue": "parish", "user_team": 0, "seed": 8, "length": 8.0, "mode": "test"}
		add_child(m)
		await frames(5)
		for q in m.all_players():
			(q as Player).global_position = Vector3(0, 0, 60)
		var me: Player = m.player_by_num(0, 10)
		me.global_position = Vector3.ZERO
		m._set_active(me)
		m.carrier = null
		m.phase = m.P.LIVE
		m.ball.state = Sliotar.FREE
		m.ball.holder = null
		m.ball.vel = Vector3.ZERO
		m.ball.global_position = Vector3(0.9, 0.04, 0)
		m.ball.last_touch = null
		await frames(45)
		var got: bool = m.carrier == me
		check(got == (assist == 1), "Auto pick-up: help %s, ball on the ground at his feet, %s (got: %s)" % [
			"on" if assist == 1 else "off", "lifted by himself" if assist == 1 else "left for the button", got])
		m.queue_free()
		await frames(2)
	Game.settings.assist = keep


## Your free at the posts, a 65 and a penalty, aimed by timing (game/placed_aim.gd): STRIKE (or GOAL) brings the low
## camera and the SHOOT button; SHOOT stops the target, and the sliotar goes there: over the bar between the posts a
## point, out past an upright a wide, under the bar a shot at goal. The target hurries through the goal and lingers
## between the posts.
func _aimed_shots() -> void:
	check(PlacedAim.zone(Vector3(0, 5.0, 0)) == "point" and PlacedAim.zone(Vector3(0, 1.0, 1.0)) == "goal"
		and PlacedAim.zone(Vector3(0, 4.0, 5.0)) == "wide", "Aimed shots: over the bar a point, under it a goal, outside the posts wide")
	for c in [["free", PI * 0.5, "point"], ["free", 0.0, "wide"], ["65", PI * 0.5, "point"], ["penalty", PI * 1.5, "goal"]]:
		var m: Node = load("res://game/match.gd").new()
		m.config = {"home": "KIL", "away": "TIP", "venue": "county", "user_team": 0, "seed": 11, "length": 8.0, "mode": "test"}
		add_child(m)
		await frames(5)
		var d: float = m.dir(0)
		var dist := 30.0 if c[0] == "free" else (65.0 if c[0] == "65" else 20.0)
		var spot := Vector3((Pitch.HALF_L - dist) * d, 0, 0)
		m._award({"kind": c[0], "team": 0, "spot": spot}, 0.1)
		var f := 0
		while not (m.phase == m.P.SET and m.taker != null) and f < 30 * 30:
			await frames(1)
			f += 1
		m._set_active(m.taker)
		var before: Array = m.score[0].duplicate()
		var wides: int = m.tstats[0].wides
		m._on_action("GOAL" if c[0] == "penalty" else "STRIKE")
		await frames(2)
		var aiming: bool = m.placed_aim != null and m.user_buttons() == ["SHOOT"] and m.placed_aim.camera.current
		check(aiming, "Aimed %s: STRIKE brings the low camera and SHOOT (%s)" % [c[0], m.user_buttons()])
		if not aiming:
			m.queue_free()
			await frames(2)
			continue
		m.placed_aim.angle = c[1]
		m.placed_aim._place()
		var at: Vector3 = m.placed_aim.target()
		m._on_action("SHOOT")
		var barred: bool = m.placed_aim.stopped and not m.placed_aim.fired and m.user_buttons() == ["SHOOT"]
		m.placed_aim.bar_x = 0.0
		m._on_action("SHOOT")
		check(barred and m.placed_aim.fired, "Aimed %s: the first SHOOT stops the target and starts the bar, the second strikes" % c[0])
		f = 0
		while f < 30 * 8 and (m.placed_aim != null or m.phase == m.P.LIVE):
			await frames(1)
			f += 1
		var shot: Dictionary = m.ball.get_meta("shot", {})
		var got := "point" if m.score[0][1] > before[1] else ("goal" if m.score[0][0] > before[0] else ("wide" if m.tstats[0].wides > wides else "?"))
		var ok: bool = got == c[2] or (c[2] == "goal" and bool(shot.get("goal", false)))   # (a shot at goal may be saved)
		check(ok and m.placed_aim == null and m.cam.camera.current, "Aimed %s, the target stopped %s (%.1f up, %.1f across): %s; back to the match camera" % [
			c[0], c[2], at.y, absf(at.z), got])
		m.queue_free()
		await frames(2)
	# The bar: in the green the sliotar goes where the target stopped; off either end, well wide that side.
	var b := PlacedAim.new()
	add_child(b)
	var brng := RandomNumberGenerator.new()
	b.setup(Vector3(Pitch.HALF_L - 40.0, 0, 0), Vector3(Pitch.HALF_L - 41.0, 0, 0), 1.0, 0.7, brng)
	var mid := Vector3(Pitch.HALF_L, 5.5, 0.0)
	var r_end: Vector3 = b.strike_point(mid, 1.0)
	var l_end: Vector3 = b.strike_point(mid, -1.0)
	var edge: Vector3 = b.strike_point(mid, PlacedAim.GREEN - 0.01)
	check(b.strike_point(mid, 0.0) == mid and edge == mid and PlacedAim.zone(r_end) == "wide" and PlacedAim.zone(l_end) == "wide"
		and signf(r_end.z) == -signf(l_end.z) and absf(r_end.z - mid.z) > 6.0,
		"Aimed shots: the bar's green keeps the target's spot; off its ends the sliotar goes %.1f m to one side, %.1f m to the other" % [r_end.z, l_end.z])
	# Screen right is the taker's right: from behind him at +x, looking at the goal at +x, his right is +z.
	check(r_end.z > 0.0, "Aimed shots: off the bar's right end, wide on the right of the screen (%.1f)" % r_end.z)
	b.queue_free()
	# Speed: through the goal faster than between the posts.
	var a := PlacedAim.new()
	add_child(a)
	var rng := RandomNumberGenerator.new()
	a.setup(Vector3(Pitch.HALF_L - 30.0, 0, 0), Vector3(Pitch.HALF_L - 30.9, 0, 0), 1.0, 0.7, rng)
	var steps := {"goal": 0, "point": 0, "wide": 0}
	a.angle = 0.0
	for i in 3000:
		a._process(1.0 / 300.0)
		steps[PlacedAim.zone(a.target())] += 1
	a.queue_free()
	check(steps.point > steps.goal * 2, "Aimed shots: the target lingers between the posts (%d steps) and hurries through the goal (%d)" % [steps.point, steps.goal])


## Free-taking practice (game/practice.gd): ten frees, each aimed by timing and struck off the bar; a goal into the
## net (no goalkeeper), a point over the bar flying on to land, a miss off the bar's end or outside the posts; the
## taker alone on the pitch, swinging every time, under the practice's own low camera throughout; High graphics while
## it lasts and the player's own after; the score kept as the best; the pause menu without substitutions or tactics.
func _practice_frees() -> void:
	var kept := int(Game.settings.get("practice_best", -1))
	var kept_gfx := int(Game.settings.graphics)
	Game.settings.practice_best = -1
	Game.settings.graphics = Game.GFX_LOW
	var m: Node = load("res://game/practice.gd").new()
	m.config = {"home": "KIL", "away": "TIP", "venue": "county", "user_team": 0, "seed": 7, "mode": "practice"}
	m.set_meta("test", true)
	add_child(m)
	await frames(5)
	var on_pitch := true
	for sp in m.practice.spots:
		on_pitch = on_pitch and Pitch.in_play(sp) and Pitch.from_goal_line(sp, m.dir(0)) >= 18.0
	check(m.phase == m.P.SHOOTOUT and m.taker == m.active and String(m.taker.data.id) == String(DB.free_taker("KIL").id)
		and (m.practice.spots as Array).size() == m.FREES and on_pitch and not m.hud._bug.visible,
		"Practice: the county's free-taker over the ball, ten spots on the pitch, the practice panel for the scorebug")
	var seen := 0
	for q in m.all_players():
		seen += 1 if (q as Player).visible else 0
	check(seen == 1 and m.taker.visible and not m.keeper_of(1).visible and not m.officials.referee.visible,
		"Practice: the taker alone on the pitch (%d players seen), no goalkeeper, no referee" % seen)
	check(int(Game.settings.graphics) == Game.GFX_HIGH and m.get_viewport().get_camera_3d() == m.view,
		"Practice: High graphics while it lasts, and its own low camera")
	# A goal first (low in the middle of the net), seven between the posts over the bar with the bar in the green,
	# one off the bar's right end, one outside the posts.
	var aimed := 0
	var swung := 0
	var own_cam := true
	var net_ok := false
	var landed := 0
	for i in m.FREES:
		var f := 0
		while m.placed_aim == null and f < 30 * 12:
			await frames(1)
			own_cam = own_cam and m.get_viewport().get_camera_3d() == m.view
			f += 1
		if m.placed_aim == null or m.user_buttons() != ["SHOOT"]:
			break
		aimed += 1
		m.placed_aim.angle = PI * 1.5 if i == 0 else (PI * 0.5 if i < 9 else 0.0)
		m.placed_aim._place()
		var ch: String = m.placed_aim.challenge
		var want_ch := String(m.CHALLENGES.get(i, "-"))
		check(ch == want_ch or (want_ch == "" and ch in ["left", "right"]) or (want_ch == "-" and ch == ""),
			"Practice: free %d's challenge (%s)" % [i + 1, ch])
		m._on_action("SHOOT")
		# The challenges: the target stopped a little off the post named (it snaps onto it).
		if ch != "":
			var gx: float = m.placed_aim.goal_x
			var pz: float = (Pitch.POST_GAP * 0.5 + Pitch.POST_W * 0.5) * m.placed_aim._right_sign()
			m.placed_aim._aim_at = Vector3(gx, 4.0, (-pz if ch == "left" else pz) * 0.94)
		m.placed_aim.bar_x = 1.0 if i == 7 else 0.0
		m._on_action("SHOOT")
		f = 0
		var struck := false
		while String(m.practice.state) != "done" and String(m.practice.state) != "over" and f < 30 * 12:
			await frames(1)
			struck = struck or (m.taker.action in ["strike", "free_strike"] and m.taker.visible_on_screen)
			own_cam = own_cam and m.get_viewport().get_camera_3d() == m.view
			f += 1
		swung += 1 if struck else 0
		# The sliotar flies on after the result and comes down (the goal's into the net), not held in the air.
		var at_result: Vector3 = m.ball.global_position
		f = 0
		while String(m.practice.state) == "done" and f < 45:
			await frames(1)
			own_cam = own_cam and m.get_viewport().get_camera_3d() == m.view
			f += 1
		var after: Vector3 = m.ball.global_position
		if i == 0:
			net_ok = absf(after.x) > Pitch.HALF_L and absf(after.x) < Pitch.HALF_L + Pitch.NET_DEPTH + 0.3 and absf(after.z) < Pitch.POST_GAP * 0.5 + 0.3 and after.y < 1.0
		elif i in [1, 3, 4, 6] and after.distance_to(at_result) > 2.0 and after.y < 3.0:
			landed += 1
		f = 0
		while m.placed_aim != null and f < 30 * 6:
			await frames(1)
			f += 1
	var f2 := 0
	while String(m.practice.state) != "over" and f2 < 30 * 8:
		await frames(1)
		f2 += 1
	var marks: Array = m.practice.marks
	var pts := marks.count("P") + marks.count("G") * 3 + marks.count("C") * 2
	check(aimed == m.FREES and marks.size() == m.FREES and String(m.practice.state) == "over" and int(m.practice.points) == pts,
		"Practice: ten frees aimed and taken, the score adds up (%s, %d)" % [marks, int(m.practice.points)])
	check(String(marks[0]) == "G" and net_ok, "Practice: a shot low in the middle of the goal is a goal, the sliotar in the net (%s)" % [marks])
	var plain := [String(marks[1]), String(marks[3]), String(marks[4]), String(marks[6])]
	check(plain.count("P") >= 3 and String(marks[7]) != "P" and String(marks[9]) != "P",
		"Practice: aimed between the posts over the bar with the bar in the green, points; off the bar's end or outside the posts, none (%s)" % [marks])
	check(String(marks[2]) == "C" and String(marks[5]) == "C" and String(marks[8]) == "C",
		"Practice: the post challenges, the left post, the right post and either hit, double points each (%s)" % [marks])
	check(swung == m.FREES and own_cam, "Practice: the taker swings at every free (%d of %d), the practice's camera throughout" % [swung, m.FREES])
	check(landed >= 3, "Practice: after a point the sliotar flies on and comes down behind the goal (%d of 4)" % landed)
	check(int(Game.settings.practice_best) == int(m.practice.points) and m.hud._card != null,
		"Practice: the score kept as the best, the card with Go again at the end")
	m.set_paused(true)
	var labels := []
	for bt in m.hud._pause.find_children("*", "Button", true, false):
		labels.append((bt as Button).text)
	check(not tr("TACTICS") in labels and not tr("SIM_TO_END") in labels and tr("PRACTICE_RESTART") in labels and tr("PRACTICE_QUIT") in labels,
		"Practice: the pause menu has Start again and Leave, no tactics or substitutions (%s)" % [labels])
	m.set_paused(false)
	m.queue_free()
	await frames(2)
	check(int(Game.settings.graphics) == Game.GFX_LOW, "Practice: the player's own graphics back after it (%d)" % int(Game.settings.graphics))
	Game.settings.practice_best = kept
	Game.settings.graphics = kept_gfx


## The extra-time shoot-out taken as practice's frees are: every taker in his stance over the ball at once, the low
## camera behind him; yours aimed by timing (the target, then the bar), theirs lifted and struck by themselves; it runs
## to a winner.
func _shootout_frees() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "TIP", "venue": "county", "user_team": 0, "seed": 5, "length": 8.0, "mode": "champ",
		"knockout": true}
	add_child(m)
	await frames(5)
	m._begin_shootout()
	await frames(2)
	var stances := 0
	var cams := 0
	var takes := 0
	var yours := 0
	var lifted := 0
	var f := 0
	var last := -1
	while m.phase != m.P.OVER and f < 30 * 120:
		var n: int = int(m.shootout.taken[0]) + int(m.shootout.taken[1])
		if n != last and String(m.shootout.state) == "ready":
			last = n
			takes += 1
			stances += 1 if m.taker.action == "free_set" and m.taker.global_position.distance_to(m.free_stand(m.restart.spot, m.taker.team)) < 0.05 else 0
			cams += 1 if m.get_viewport().get_camera_3d() == m._pen_view else 0
		if m.placed_aim != null and not m.placed_aim.stopped and m.user_buttons() == ["SHOOT"]:
			yours += 1
			m.placed_aim.angle = PI * 1.5
			m.placed_aim._place()
			m._on_action("SHOOT")
			m.placed_aim.bar_x = 0.0
			m._on_action("SHOOT")
		if m.taker.action == "free_strike" and m.taker.action_t < 0.05:
			lifted += 1
		await frames(1)
		f += 1
	check(m.phase == m.P.OVER and int(m.shootout.goals[0]) != int(m.shootout.goals[1]),
		"Shoot-out: runs to a winner (%s after %s)" % [m.shootout.goals, m.shootout.taken])
	check(takes >= 6 and stances == takes and cams == takes,
		"Shoot-out: each taker in his stance over the ball at once, the camera low behind him (%d, %d of %d)" % [stances, cams, takes])
	check(yours >= 3 and yours == int(m.shootout.taken[0]),
		"Shoot-out: your penalties aimed by timing, every one (%d of %d)" % [yours, int(m.shootout.taken[0])])
	check(lifted >= takes - 1, "Shoot-out: every penalty lifted and struck as a free is (%d of %d)" % [lifted, takes])
	check(m.get_viewport().get_camera_3d() == m.cam.camera, "Shoot-out: the match camera back at the end")
	m.queue_free()
	await frames(2)


## Round a goal, not through it: a goalkeeper behind his net (where a ball went wide) going out to the front of it,
## and a man running for a ball in the net, each the long way round the posts; nobody stays inside a goal; a
## goalkeeper's way never over the lines.
func _goals_round() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "TIP", "venue": "county", "user_team": -1, "seed": 2, "length": 8.0, "mode": "test"}
	add_child(m)
	await frames(5)
	var k: Player = m.keeper_of(0)
	var s: float = -m.dir(0)                    # his own end
	var cases := [[Vector3((Pitch.HALF_L + 4.0) * s, 0, 0.5), Vector3((Pitch.HALF_L - 3.0) * s, 0, 0.0)],
		[Vector3((Pitch.HALF_L - 6.0) * s, 0, -1.0), Vector3((Pitch.HALF_L + 1.0) * s, 0, 0.3)],
		[Vector3((Pitch.HALF_L + 1.0) * s, 0, 8.0), Vector3((Pitch.HALF_L + 1.0) * s, 0, -8.0)]]
	var inside := 0
	var arrived := 0
	var over := 0
	for c in cases:
		k.global_position = c[0]
		k.vel = Vector3.ZERO
		for f in 30 * 8:
			m._steer(k, c[1], 6.0)
			k.integrate(1.0 / 30.0, 0.0)
			m._out_of_goals(k)
			var q := Vector2(k.global_position.x, k.global_position.z)
			if m.goal_box(s, 0.0).has_point(q):
				inside += 1
		var want: Vector3 = m._keep_out(c[1], k)
		arrived += 1 if k.global_position.distance_to(want) < 1.0 else 0
		over += 1 if absf(want.x) > Pitch.HALF_L else 0
	check(inside == 0 and arrived == cases.size(), "Goals: round the posts and the net, never through (%d frames inside; %d of %d got there)" % [inside, arrived, cases.size()])
	check(over == 0, "Goals: a goalkeeper's way stays inside the lines (%d over)" % over)
	m.queue_free()
	await frames(2)


## The championship as the owner asked: your own game simulated (and every game left), a match left for the menu
## carried on from where it was, and the rest of a match simulated to full time.
func _champ_sim_resume() -> void:
	var c: Championship = Championship.create("KIL")
	c.play_byes()
	var f := c.next_fixture()
	var r := c.sim_user()
	check(not r.is_empty() and bool(f.played) and int(r.winner) in [-1, 0, 1], "Championship: your game simulated (%s)" % [r.get("score")])
	c.sim_rest()
	check(c.user_out() or c.phase == "done", "Championship: simulate the rest runs to the end or till you are out (%s)" % c.phase)
	# Carry on: the score, the minute, who is on and their cards, through a save and a load.
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "TIP", "venue": "county", "user_team": 0, "seed": 4, "length": 8.0, "mode": "champ",
		"knockout": true}
	m.set_meta("test", true)
	add_child(m)
	await frames(4)
	m.score = [[1, 9], [0, 11]]
	m.half = 2
	m.clock = 600.0
	var booked: Player = m.teams[1].players[5]
	booked.yellows = 1
	var gone: Player = m.teams[0].players[10]
	var sub_pd: Dictionary = m.teams[0].bench[0]
	gone.take_over(sub_pd, m._look(0, sub_pd, false))
	m.teams[0].bench.erase(sub_pd)
	m.teams[0].subs = 1
	var snap: Dictionary = JSON.parse_string(JSON.stringify(m.snapshot()))
	m.queue_free()
	await frames(2)
	var cfg: Dictionary = (snap.config as Dictionary).duplicate(true)
	cfg.resume = snap
	var m2: Node = load("res://game/match.gd").new()
	m2.config = cfg
	m2.set_meta("test", true)
	add_child(m2)
	await frames(4)
	var same: bool = m2.score == [[1, 9], [0, 11]] and int(m2.half) == 2 and is_equal_approx(float(m2.clock), 600.0) \
		and int(m2.teams[1].players[5].yellows) == 1 and String(m2.teams[0].players[10].data.id) == String(sub_pd.id) \
		and int(m2.teams[0].subs) == 1 and not (sub_pd in m2.teams[0].bench)
	check(same, "Carry on: score, half, clock, a booking and a substitution as they were left")
	# Simulate to the end: level in a knock-out game, so a winner after extra time or penalties; never fewer scores.
	m2.score = [[1, 10], [0, 13]]
	var box0: Array = [int(m2.tstats[0].scores_play) + int(m2.tstats[0].scores_placed),
		int(m2.tstats[1].scores_play) + int(m2.tstats[1].scores_placed)]
	m2.sim_to_end()
	var t0: Array = m2.score
	var box_ok: bool = true
	for k in 2:
		var more: int = int(t0[k][0]) + int(t0[k][1]) - (11 if k == 0 else 13)
		var box1: int = int(m2.tstats[k].scores_play) + int(m2.tstats[k].scores_placed)
		box_ok = box_ok and box1 - int(box0[k]) == more and int(m2.tstats[k].shots) >= box1
	check(box_ok, "Simulate to the end: the box score counts the simulated scores")
	check(m2.phase == m2.P.OVER and Rules.total(t0[0][0], t0[0][1]) >= 13 and Rules.total(t0[1][0], t0[1][1]) >= 13,
		"Simulate to the end: full time, scores only added (%s)" % [t0])
	var tot := [Rules.total(t0[0][0], t0[0][1]), Rules.total(t0[1][0], t0[1][1])]
	check(tot[0] != tot[1] or not m2.shootout.is_empty(), "Simulate to the end: a knock-out game has a winner")
	m2.queue_free()
	await frames(2)
	Game.clear_suspended()


## The crowd senses a score coming: up as a man runs at the posts with the ball, down again when he is far out.
func _crowd_builds() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "TIP", "venue": "stadium", "user_team": 0, "seed": 8, "length": 8.0, "mode": "test"}
	m.set_meta("test", true)
	add_child(m)
	await frames(5)
	for q in m.all_players():
		(q as Player).global_position = Vector3(0, 0, 60)
	var me: Player = m.player_by_num(0, 14)
	m.phase = m.P.LIVE
	me.global_position = Vector3(m.dir(0) * (Pitch.HALF_L - 18.0), 0, 0)
	m._gain(me, "lift")
	await frames(60)
	var near: float = m._hype
	me.global_position = Vector3(-m.dir(0) * 30.0, 0, 0)
	await frames(90)
	var far: float = m._hype
	check(near > 0.6 and far < 0.15, "Crowd: rises as a man nears the posts with the ball (%.2f), falls back far out (%.2f)" % [near, far])
	m.queue_free()
	await frames(2)


## A man moving away from where he looks: slowly, he backpedals (still facing, his stride run backward); faster
## than a backpedal, he turns and runs.
func _backpedal() -> void:
	for sp in [2.0, 6.0]:
		var p := Player.new({"num": 5, "line": 3, "speed": 70}, 0, {"jersey": Color.RED, "kind": "player"})
		add_child(p)
		p.yaw = 0.0                                 # facing +z
		p.face_to = Vector3(0, 0, 50)
		p.want_vel = Vector3(0, 0, -sp)
		p.vel = p.want_vel
		var ph0: float = p._ph
		for i in 60:
			p.integrate(1.0 / 60.0, i / 60.0)
		var faces := p.forward().dot(Vector3(0, 0, 1))
		if sp < Player.BACKPEDAL:
			check(faces > 0.9 and p._ph < ph0, "Backpedal at %.0f m/s: still facing, the stride backward" % sp)
		else:
			check(faces < -0.9 and p._ph > ph0, "Away at %.0f m/s: turned round, running forward" % sp)
		p.queue_free()


func _count_prefix(sc: Scenery, prefix: String) -> int:
	var n := 0
	for name in sc.names():
		if String(name).begins_with(prefix):
			n += sc.count(name)
	return n


func _find_text(n: Node, text: String) -> bool:
	if (n is Label or n is Button) and n.text.contains(text):
		return true
	for c in n.get_children():
		if _find_text(c, text):
			return true
	return false


## Every sound the game plays is there and loads: each file in assets/audio, and every name Sfx makes or loads
## (docs/SOUNDS.md lists where each recording came from).
func _sounds() -> void:
	var files := 0
	var bad := []
	for f in DirAccess.get_files_at("res://assets/audio"):
		if f.ends_with(".ogg"):
			files += 1
			var st: AudioStream = load("res://assets/audio/" + f)
			if st == null or st.get_length() <= 0.0:
				bad.append(f)
	check(files >= 36 and bad.is_empty(), "Sounds: the %d files in assets/audio load (%s)" % [files, bad])
	Sfx._ensure()
	var names := ["whistle", "whistle_long", "whistle_final", "whistle_double", "strike", "tap", "clash", "catch", "shoulder", "post", "save", "bounce",
		"click", "roar", "crowd_loop", "crowd_cheer", "crowd_ooh", "crowd_groan", "applause", "clap", "menu_music",
		"birds_loop"]
	for kind in Sfx.VOICES:
		for i in int(Sfx.VOICES[kind]):
			names.append("%s_%d" % [kind, i + 1])
	for k in Sfx.VARIANTS:
		for i in range(1, int(Sfx.VARIANTS[k])):
			names.append("%s_%d" % [k, i + 1])
	var missing := names.filter(func(n): return not (Sfx.streams.get(n) is AudioStream))
	check(missing.is_empty(), "Sounds: every sound the game plays is there (%s missing)" % [missing])
	check(Sfx.streams.whistle is AudioStreamOggVorbis and Sfx.streams.whistle_long_3 is AudioStreamOggVorbis and Sfx.streams.whistle_final is AudioStreamOggVorbis, "Sounds: the referee's whistle is the recorded one, three takes of each")
	check(Sfx.streams.crowd_loop is AudioStreamOggVorbis and (Sfx.streams.crowd_loop as AudioStreamOggVorbis).loop and (Sfx.streams.birds_loop as AudioStreamOggVorbis).loop, "Sounds: the crowd's murmur and the birdsong loop")


# ---------------------------------------------------------------- a match, and the movement audit

## An AI match at the shortest length plays to full time with a legal score; every frame, no player moves further
## than his top speed allows (nothing snaps), his speed changes no faster than his acceleration, and his strides
## (counted steps) match how far he ran.
func _match_and_motion() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "CLA", "away": "GAL", "venue": "parish", "user_team": -1, "seed": 9, "length": 4.0, "mode": "test"}
	add_child(m)
	await frames(2)
	var last := {}
	var lastv := {}
	var worst_jump := 0.0
	var worst_acc := 0.0
	var dist := 0.0
	var steps := 0
	var probe: Player = m.player_by_num(0, 8)
	var came := {}
	var guard := 0
	while m.phase != m.P.OVER and guard < 30 * 60 * 14:
		await get_tree().process_frame
		guard += 1
		var dt := 1.0 / 30.0
		for p in m.all_players():
			var pl: Player = p
			if not pl.visible:
				continue
			var pos := pl.global_position
			if came.get(pl, 0) != pl.came_on:
				# A substitute has taken this place: he comes on from the line.
				came[pl] = pl.came_on
				last.erase(pl)
			if last.has(pl) and m.phase != m.P.HALF_TIME and m.phase != m.P.INTRO:
				var d: float = pos.distance_to(last[pl])
				worst_jump = maxf(worst_jump, d / (dt * pl.max_speed * 1.25))
				var dv: float = (pl.vel - (lastv[pl] as Vector3)).length()
				worst_acc = maxf(worst_acc, dv / (dt * maxf(Player.ACCEL, Player.DECEL) * 1.6))
			if pl == probe and last.has(pl):
				dist += pos.distance_to(last[pl])
			last[pl] = pos
			lastv[pl] = pl.vel
		steps += probe.steps_taken
		probe.steps_taken = 0
	check(m.phase == m.P.OVER, "Match: an AI match reaches full time (%d frames)" % guard)
	var s: Array = m.score
	check(int(s[0][0]) >= 0 and int(s[0][1]) >= 0 and int(s[0][0]) + int(s[0][1]) + int(s[1][0]) + int(s[1][1]) > 0, "Match: there are scores (%s v %s)" % [Rules.fmt(s[0][0], s[0][1]), Rules.fmt(s[1][0], s[1][1])])
	check(worst_jump <= 1.0, "Motion: no player moves faster than his top speed in a frame (worst %.2f of the limit)" % worst_jump)
	check(worst_acc <= 1.0, "Motion: speed changes no faster than a player accelerates (worst %.2f of the limit)" % worst_acc)
	var stride := dist / maxf(1.0, float(steps))
	check(steps > 50 and stride > 0.6 and stride < 2.3, "Motion: strides match the ground covered (%.2f m a step, %d steps)" % [stride, steps])
	for k in 2:
		check(int(m.teams[k].subs) <= Rules.subs_allowed(false), "Subs: the manager makes no more than five (%d)" % int(m.teams[k].subs))
	check(int(m.teams[0].subs) + int(m.teams[1].subs) > 0, "Subs: the managers bring on fresh legs in the second half")
	m.queue_free()
	await frames(2)


## The auto graphics level (the owner's Galaxy A16 stuttered on High and nothing dropped): smooth frames never lower
## it; a match that hitches steps High -> Medium -> Low, each within about five seconds, the whole level applied at
## once; then no lower. The phone decides the level until the player chooses one.
func _auto_graphics() -> void:
	var a := AutoGfx.new()
	var t := 0.0
	var fired := false
	while t < 20.0:
		fired = fired or a.feed(1.0 / 60.0)
		t += 1.0 / 60.0
	check(not fired, "Auto graphics: 20 s of smooth frames, no change")
	a = AutoGfx.new(30)
	t = 0.0
	while t < 20.0:
		fired = fired or a.feed(1.0 / 30.0)
		t += 1.0 / 30.0
	check(not fired, "Auto graphics: Battery saver's 30 a second is not a stutter")
	var keep_g = Game.settings.graphics
	var keep_auto = Game.settings.auto_gfx
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.auto_gfx = true
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "KIL", "away": "WEX", "venue": "county", "user_team": 0, "seed": 3, "length": 4.0, "mode": "test"}
	m.set_meta("test", true)
	add_child(m)
	await frames(60)
	var crowd0: int = m.stadium.crowd.multimesh.instance_count
	var sun_shadow0: bool = m.stadium._sun.shadow_enabled
	# About 45 frames a second, with a stall of a tenth of a second every twentieth frame (some two a second).
	var steps := []
	var n := 0
	t = 0.0
	while t < 16.0:
		n += 1
		var d := 0.11 if n % 20 == 0 else 0.02
		var before := int(Game.settings.graphics)
		m.watch_frames(d)
		t += d
		if int(Game.settings.graphics) != before:
			steps.append([int(Game.settings.graphics), snappedf(t, 0.1)])
	check(steps.size() == 2 and steps[0][0] == Game.GFX_MEDIUM and steps[1][0] == Game.GFX_LOW and float(steps[0][1]) <= 5.5
		and float(steps[1][1]) - float(steps[0][1]) <= 5.5, "Auto graphics: a hitching match steps High -> Medium -> Low within ~5 s each, then stays (%s)" % [steps])
	await frames(2)
	check(m.stadium.crowd.multimesh.instance_count < crowd0 and not m.stadium._sun.shadow_enabled and m.shadows == null
		and is_instance_valid(m.stadium._we), "Auto graphics: the whole level applied at once (crowd %d -> %d, the sun's shadows %s -> off, the men's shadows gone, the sky made again)" % [crowd0, m.stadium.crowd.multimesh.instance_count, sun_shadow0])
	m.queue_free()
	await frames(2)
	# The phone decides until the player chooses: an install over an older beta (no gfx_detect) is decided again once,
	# a level the player chose stays; a Mali-G57/G68-class phone starts on Low.
	var keep_c = Game.settings.gfx_chosen
	var keep_d = Game.settings.gfx_detect
	Game.settings.graphics = Game.GFX_LOW
	Game.settings.gfx_chosen = false
	Game.settings.gfx_detect = 0
	var redo := Game.decide_graphics()
	var again := Game.decide_graphics()
	check(redo and not again and int(Game.settings.graphics) == Game.detect_graphics() and int(Game.settings.gfx_detect) == Game.GFX_DETECT,
		"Auto graphics: an older install's level decided again for the phone, once")
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.gfx_chosen = true
	Game.settings.gfx_detect = 0
	check(not Game.decide_graphics() and int(Game.settings.graphics) == Game.GFX_HIGH, "Auto graphics: a level the player chose stays")
	var weak := true
	for c in [["Mali-G68 MC4", "", 6.0], ["Mali-G57 MC2", "", 8.0], ["Adreno (TM) 740", "MT6789V/CD", 8.0], ["Vulkan GPU", "s5e8535", 6.0], ["Vulkan GPU", "MT6835", 8.0]]:
		weak = weak and Game.graphics_for(c[0], c[1], c[2]) == Game.GFX_LOW
	check(weak, "Auto graphics: Mali-G57/G68-class phones (Helio G99, Exynos 1330, Dimensity 6300) start on Low")
	Game.settings.graphics = keep_g
	Game.settings.auto_gfx = keep_auto
	Game.settings.gfx_chosen = keep_c
	Game.settings.gfx_detect = keep_d
