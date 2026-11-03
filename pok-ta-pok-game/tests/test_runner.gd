extends Node
## The test suite CI runs before building (headless):
##   godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
## The rules one by one (Rules, Court, Ball: docs/RULES.md numbers them); every screen opens in every language; every
## scrolling page scrolls when dragged on its text; the cup plays through to its champion and saves; simulated results
## are counts ulama can have; the crowd faces the court at every venue and level; an AI match plays to its end; and the
## movement audit: one writer per player, nothing jumps in a frame, strides match speed.
## Exits 1 on any failure.

const SCREENS := ["res://ui/main_menu.gd", "res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
	"res://ui/licences_screen.gd", "res://ui/help_screen.gd", "res://ui/privacy_screen.gd", "res://ui/buttons_screen.gd",
	"res://ui/cup_screen.gd"]

var failures := 0
var checks := 0
var only := false           # set by an owner note (tests/note_run.gd): no full run, it calls the measurements it needs
var log: Array = []          # every check made: [passed, what] (the owner notes read it)


func _ready() -> void:
	if only:
		return
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	get_tree().root.size = Vector2i(1280, 720)
	await frames(1)
	var keep: Dictionary = Game.settings.duplicate(true)
	# The matches here are not about drawing: they run as a build without the licensed clips does (CI's), in its time.
	# _foundation() turns the shared foundation on for its own.
	FoundationLink.off = true
	_rules_count()
	_rules_urria()
	_rules_rayas()
	_rules_classic()
	_rules_serve()
	_court()
	_ball()
	_plurals()
	_languages()
	await _screens()
	await _scroll_on_text()
	await _legal_pages()
	await _move_buttons()
	_cup()
	_sim()
	await _crowd_faces()
	await _stance()
	await _judges_stand()
	await _props_solid("village", "ulama")
	await _props_solid("festival", "ulama")
	await _props_solid("stone", "classic")
	await _props_solid("night", "classic")
	await _mocap()
	_sounds()
	_levels()
	await _yucatan()
	await _ring_replay()
	await _foundation()
	await _ai_plays("village", "ulama")
	await _ai_plays("stone", "classic")
	await _watch_ai()
	await _stick_camera("village", "ulama")
	await _stick_camera("stone", "classic")
	await _tv_camera("village", "ulama")
	await _tv_camera("stone", "classic")
	await _match_and_motion("village", "ulama")
	await _match_and_motion("stone", "classic")
	Game.settings = keep
	Game.delete_cup()
	print("test_runner: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	log.append([ok, what])
	if ok and OS.has_environment("TEST_VERBOSE"):
		print("ok: ", what)
	if not ok:
		failures += 1
		print("FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ---------------------------------------------------------------- the rules

## R1-R3: the count goes up and down; one side holds it; eight wins.
func _rules_count() -> void:
	var c := Rules.Count.new(Rules.ULAMA, "none")
	check(c.holder == -1 and c.of(0) == 0 and c.of(1) == 0, "R2: the count starts level")
	var r := Rules.award(c, 0)
	check(String(r.what) == "add" and c.holder == 0 and c.of(0) == 1, "R2: the first raya starts that side's count")
	Rules.award(c, 0)
	check(c.of(0) == 2 and c.of(1) == 0, "R2: a raya to the holder adds one")
	r = Rules.award(c, 1)
	check(String(r.what) == "cancel" and c.of(0) == 1 and c.of(1) == 0, "R3: a raya to the other side takes one off the holder's count")
	Rules.award(c, 1)
	check(c.holder == -1 and c.of(0) == 0 and c.of(1) == 0, "R3: down to level, both at nothing")
	Rules.award(c, 1)
	check(c.holder == 1 and c.of(1) == 1, "R3: from level, the next raya starts the other side's count")
	for i in 6:
		Rules.award(c, 1)
	check(c.of(1) == 7 and c.winner == -1, "R1: seven is not yet the game")
	r = Rules.award(c, 1)
	check(String(r.what) == "win" and c.winner == 1, "R1: the eighth raya wins")
	r = Rules.award(c, 0)
	check(String(r.what) == "over" and c.winner == 1, "R1: nothing counts once the game is won")
	check(Rules.TARGET == 8, "R1: the target is eight rayas")


## R4: urria.
func _rules_urria() -> void:
	var c := Rules.Count.new(Rules.ULAMA, "3_7")
	for i in 3:
		Rules.award(c, 0)
	check(c.in_urria(), "R4: on raya 3 the holder is in urria (3 and 7)")
	var r := Rules.award(c, 1)
	check(String(r.what) == "urria" and c.holder == -1 and c.of(0) == 0, "R4: a raya against a side in urria wipes out its whole count")
	c = Rules.Count.new(Rules.ULAMA, "3_7")
	for i in 4:
		Rules.award(c, 0)
	check(not c.in_urria(), "R4: raya 4 is not urria (3 and 7)")
	Rules.award(c, 1)
	check(c.of(0) == 3, "R4: out of urria, a raya against takes off only one")
	Rules.award(c, 1)
	check(c.holder == -1, "R4: back on 3, in urria, the next raya against wipes the count")
	c = Rules.Count.new(Rules.ULAMA, "3_5_7")
	for i in 5:
		Rules.award(c, 0)
	check(c.in_urria(), "R4: CONADE's urria includes raya 5")
	c = Rules.Count.new(Rules.ULAMA, "none")
	for i in 7:
		Rules.award(c, 0)
	Rules.award(c, 1)
	check(c.of(0) == 6, "R4: with urria off, nothing is wiped out")
	check(Rules.at_time(c) == 0, "R14: at time, the side holding the count wins")
	c = Rules.Count.new(Rules.ULAMA, "none")
	check(Rules.at_time(c) == -1, "R14: at time and level, no winner yet (the next raya wins)")


## R6, R8-R10: who wins a raya.
func _rules_rayas() -> void:
	check(Rules.dead_ball(-5.0, 1) == 1, "R8: the ball dying in team 0's half gives the raya to team 1")
	check(Rules.dead_ball(12.0, 1) == 0, "R8: the ball dying in team 1's half gives the raya to team 0")
	check(Rules.dead_ball(-3.0, 0) == 1, "R8: a strike that dies short of the analco, in the striker's own half, loses the raya")
	check(Rules.dead_ball(0.0, 0) == 1, "R8: on the analco itself, the side that struck it last loses")
	check(Rules.over_end(31.0) == 0 and Rules.over_end(-31.0) == 1, "R9: past an end line, the side whose end it is loses the raya")
	check(Rules.out_side(0) == 1 and Rules.out_side(1) == 0, "R10: out at the side, the raya goes against the side that struck it")
	check(Rules.body_touch(0) == 1 and Rules.body_touch(1) == 0, "R6: a touch anywhere but the hip, the raya to the other side")
	check(Rules.legal_strike("hip") and Rules.legal_strike("hip_low") and not Rules.legal_strike("hand") and not Rules.legal_strike("foot")
		and not Rules.legal_strike("knee") and not Rules.legal_strike("head"), "R5: the hip only")
	check(Rules.half_of(-0.5) == 0 and Rules.half_of(0.5) == 1, "R7: each side defends its own half of the analco")
	check(Rules.dir(0) > 0.0 and Rules.dir(1) < 0.0, "R7: team 0 drives toward +x, team 1 toward -x")
	check(Rules.SIDE_ULAMA == [4, 5] and Rules.default_side(Rules.ULAMA) == 5, "R7: four or five a side, five by default")


## R12-R16: the classic court.
func _rules_classic() -> void:
	var c := Rules.Count.new(Rules.CLASSIC)
	Rules.award(c, 0)
	Rules.award(c, 1)
	Rules.award(c, 0)
	check(c.of(0) == 2 and c.of(1) == 1, "R12: on the classic court, each side's points add up")
	for i in 6:
		Rules.award(c, 0)
	check(c.winner == 0 and c.of(0) == 8, "R12: points to eight")
	c = Rules.Count.new(Rules.CLASSIC)
	for i in 6:
		Rules.award(c, 1)
	var r := Rules.award_ring(c, 0)
	check(String(r.what) == "ring" and c.winner == 0 and c.ring, "R13: the ball through a ring wins outright, whatever the score")
	check(Rules.end_court(20.0) == 0 and Rules.end_court(-20.0) == 1, "R16: into an end court, the point to the side driving it there")
	var court := Court.new(Rules.CLASSIC)
	var ring: Vector3 = court.rings()[1]
	check(court.through_ring(ring + Vector3(-0.5, 0, 0), ring + Vector3(0.5, 0, 0), Ball.RADIUS) == 1, "R13: a ball along the alley through the ring's hole passes it")
	check(court.through_ring(ring + Vector3(-0.5, 0.35, 0), ring + Vector3(0.5, 0.35, 0), Ball.RADIUS) == 0, "R13: through the stone, not the hole, it does not")
	check(court.through_ring(ring + Vector3(-0.5, 1.2, 0), ring + Vector3(0.5, 1.2, 0), Ball.RADIUS) == 0, "R13: over the ring, it does not")
	check(Court.RING_IN * 2.0 < Ball.RADIUS * 4.2, "R13: the ring's hole is barely twice the ball's width (rare)")
	check(court.out_side(Vector3(0, Court.WALL_H + 0.5, Court.TALUD_Z + 0.5), Ball.RADIUS, false), "R15: over the top of a side wall is out")
	check(not court.out_side(Vector3(0, 2.0, 3.0), Ball.RADIUS, false), "R15: in the alley it is in")


## R11: the serve.
func _rules_serve() -> void:
	var c := Rules.Count.new(Rules.ULAMA)
	check(Rules.serve_kind(c) == "abajo", "R11: from level the serve is rolled (male abajo)")
	check(Rules.server(c) == 0, "R11: the first serve to the home side")
	Rules.award(c, 1)
	check(Rules.serve_kind(c) == "arriba", "R11: with a side holding the count the serve is thrown high (male arriba)")
	check(Rules.server(c) == 1, "R11: the side that won the last raya serves")
	check(Rules.serve_short(0) == 1, "R11: a serve short of the analco loses the raya")
	var cc := Rules.Count.new(Rules.CLASSIC)
	check(Rules.serve_kind(cc) == "bote", "R11: on the stone court the serve is bounced, to be played off the bounce")


func _court() -> void:
	var u := Court.new(Rules.ULAMA)
	check(is_equal_approx(u.half_l() * 2.0, 60.0) and is_equal_approx(Court.ULAMA_HALF_W * 2.0, 4.0), "R7: the taste is 60 m by 4 m")
	check(u.past_end(Vector3(30.3, 1.0, 0), Ball.RADIUS, false) == 1 and u.past_end(Vector3(-30.3, 0.1, 0), Ball.RADIUS, true) == -1, "R9: past the chivo at either end")
	check(u.past_end(Vector3(29.0, 1.0, 0), Ball.RADIUS, false) == 0, "R9: short of the chivo, in play")
	check(u.out_side(Vector3(5, Ball.RADIUS, 2.4), Ball.RADIUS, true), "R10: down beyond a side line is out")
	check(not u.out_side(Vector3(5, 1.5, 2.4), Ball.RADIUS, false), "R10: in the air over the line, not yet out")
	var c := Court.new(Rules.CLASSIC)
	check(c.floor_y(0, 0) == 0.0 and absf(c.floor_y(0, Court.TALUD_Z) - Court.TALUD_H) < 0.01, "R12: the talud rises from the alley's edge to the wall")
	var hit := c.contact(Vector3(0, 0.6, 5.2), Ball.RADIUS)
	check(not hit.is_empty() and String(hit[2]) == "talud" and (hit[0] as Vector3).y > 0.5 and (hit[0] as Vector3).z < 0.0, "R12: the ball meets the talud, its face sloping up and in")
	hit = c.contact(Vector3(3, 3.0, Court.TALUD_Z - 0.05), Ball.RADIUS)
	check(not hit.is_empty() and String(hit[2]) == "wall", "R12: above the talud, the wall")


## The ball: heavy, a low bounce on earth, a higher one on stone, rolling stops on earth.
func _ball() -> void:
	check(Ball.MASS >= 3.0 and Ball.MASS <= 4.0 and Ball.RADIUS * 2.0 < 0.2, "Ball: 3-4 kg and under 20 cm (docs/RULES.md)")
	var b := Ball.new()
	b.court = Court.new(Rules.ULAMA)
	b.floor_kind = "earth"
	b.pos = Vector3(0, 0.9, 0)
	b.vel = Vector3.ZERO
	var top := 0.0
	var bounced := false
	for i in 240:
		var ev := []
		b.pos = Ball.simulate(b, 1.0 / 120.0, b.court, "earth", ev)
		for e in ev:
			if e.kind == "bounce":
				bounced = true
		if bounced:
			top = maxf(top, b.pos.y - Ball.RADIUS)
	# A lively rubber ball (the owner, 0.6.3): off the earth from the hip to about knee height, not dead.
	check(bounced and top > 0.2 and top < 0.4, "Ball: dropped from the hip onto earth it comes back to %.2f m (rubber, a little deadened)" % top)
	b.court = Court.new(Rules.CLASSIC)
	b.pos = Vector3(0, 0.9, 0)
	b.vel = Vector3.ZERO
	b.grounded = false
	top = 0.0
	bounced = false
	for i in 240:
		var ev := []
		b.pos = Ball.simulate(b, 1.0 / 120.0, b.court, "stone", ev)
		for e in ev:
			if e.kind == "bounce":
				bounced = true
		if bounced:
			top = maxf(top, b.pos.y - Ball.RADIUS)
	check(top > 0.38 and top < 0.6, "Ball: on stone it bounces higher (%.2f m)" % top)
	b.court = Court.new(Rules.ULAMA)
	b.pos = Vector3(-10, Ball.RADIUS, 0)
	b.vel = Vector3(8, 0, 0)
	b.grounded = true
	var t := 0.0
	while Vector2(b.vel.x, b.vel.z).length() > Ball.DEAD_SPEED and t < 20.0:
		var ev := []
		b.pos = Ball.simulate(b, 1.0 / 120.0, b.court, "earth", ev)
		t += 1.0 / 120.0
	check(b.pos.x - (-10.0) > 12.0 and b.pos.x - (-10.0) < 30.0, "Ball: a low serve rolled at 8 m/s carries %.1f m on earth and stops" % (b.pos.x + 10.0))
	# Into the talud: it comes back off the slope.
	b.court = Court.new(Rules.CLASSIC)
	b.pos = Vector3(0, 0.5, 2.0)
	b.vel = Vector3(0, 0, 9)
	b.grounded = false
	var maxz := 0.0
	for i in 240:
		var ev := []
		b.pos = Ball.simulate(b, 1.0 / 120.0, b.court, "stone", ev)
		maxz = maxf(maxz, b.pos.z)
	check(maxz < Court.TALUD_Z and b.pos.z < maxz - 0.3, "Ball: off the talud and wall it comes back into the alley")
	b.free()


func _plurals() -> void:
	check(Plural.category("en", 1) == "one" and Plural.category("en", 2) == "other", "Plurals: English one and other")
	check(Plural.category("fr", 0) == "one" and Plural.category("fr", 1) == "one" and Plural.category("fr", 2) == "other", "Plurals: French counts 0 and 1 as one")
	check(Plural.category("es", 1) == "one" and Plural.category("es", 3) == "other", "Plurals: Spanish one and other")
	check(Plural.category("pt", 0) == "one" and Plural.category("pt", 2) == "other", "Plurals: Brazilian Portuguese counts 0 and 1 as one")


## Every language has every key, and its text has the placeholders the English has.
func _languages() -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/src/en.json"))
	var ph := RegEx.create_from_string("\\{[a-z_]+\\}")
	for pair in Game.LANGUAGES:
		var code: String = pair[0]
		if code == "en":
			continue
		var path := "res://i18n/src/%s.json" % code
		check(FileAccess.file_exists(path), "%s: a translation file" % code)
		if not FileAccess.file_exists(path):
			continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var missing := []
		var bad := []
		for k in en:
			if not d.has(k):
				missing.append(k)
				continue
			var a := []
			for m in ph.search_all(String(en[k])):
				a.append(m.get_string())
			for m in a:
				if not String(d[k]).contains(m):
					bad.append(k)
					break
		check(missing.is_empty(), "%s: every key translated (%d missing: %s)" % [code, missing.size(), str(missing.slice(0, 5))])
		check(bad.is_empty(), "%s: every placeholder kept (%s)" % [code, str(bad.slice(0, 5))])


# ---------------------------------------------------------------- screens

func _screens() -> void:
	Game.delete_cup()
	for pair in Game.LANGUAGES:
		Game.settings.language = pair[0]
		TranslationServer.set_locale(pair[0])
		Game._size_theme()
		check(tr("GAME_TITLE") != "GAME_TITLE", "%s: translations load" % pair[0])
		check(tr("BTN_HIP") != "BTN_HIP" and tr("BTN_HIP") != "", "%s: button labels" % pair[0])
		for path in SCREENS:
			var s := Game.show_screen(path)
			await frames(3)
			check(is_instance_valid(s) and s.get_child_count() > 0, "%s: %s builds" % [pair[0], path])
		Game.new_cup("ESC")
		var h := Game.show_screen("res://ui/cup_screen.gd")
		await frames(3)
		check(is_instance_valid(h) and h.get_child_count() > 0, "%s: the tournament under way builds" % pair[0])
		Game.delete_cup()
		var r := Game.show_screen("res://ui/result_screen.gd", {"result": fake_result()})
		await frames(3)
		check(is_instance_valid(r) and r.get_child_count() > 0, "%s: the result screen builds" % pair[0])
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()
	Game.goto_menu()
	await frames(2)


static func fake_result() -> Dictionary:
	var ts := {"rayas": 14, "dead": 7, "end": 3, "won_out": 2, "won_touch": 2, "ring": 0, "faults_touch": 1, "faults_out": 2,
		"strikes": 40, "dives": 12, "serves": 9}
	var ps := {"ESC_1": {"name": "J. Osuna", "team": 0, "role": "malero", "strikes": 9, "dives": 3, "rayas": 3, "faults": 1, "serves": 5},
		"LLA_1": {"name": "R. Lizárraga", "team": 1, "role": "malero", "strikes": 7, "dives": 2, "rayas": 2, "faults": 0, "serves": 4}}
	return {"config": {"mode": "quick", "stage": "Friendly", "venue": "village", "rules": "ulama"}, "home": "ESC", "away": "LLA",
		"rules": "ulama", "count": {"rules": "ulama", "holder": 0, "rayas": 8, "points": [0, 0], "winner": 0, "ring": false},
		"winner": 0, "user_team": 0, "tstats": [ts, ts.duplicate()], "pstats": ps, "log": [[0, "dead", 0, 1, 1.0, "add"]],
		"longest_rally": 9, "minutes": 12.0, "timed": false, "star": "ESC_1"}


## Move buttons lays out the match's own buttons, each with its word in every language (the words are drawn, not
## Labels, so the fit audit does not read them: the screen once showed another game's buttons as raw keys).
func _move_buttons() -> void:
	for pair in Game.LANGUAGES:
		TranslationServer.set_locale(pair[0])
		var s := Game.show_screen("res://ui/buttons_screen.gd")
		await frames(3)
		var tc: TouchControls = s.find_children("*", "TouchControls", true, false)[0]
		check(tc.ids == ["HIP", "DIVE"], "%s: Move buttons shows the match's buttons (%s)" % [pair[0], tc.ids])
		for id in tc.ids:
			check(tr("BTN_" + id) != "BTN_" + id, "%s: Move buttons' %s has its word" % [pair[0], id])
	TranslationServer.set_locale("en")
	Game.goto_menu()
	await frames(2)


## Settings > About opens Licences, Help and the Privacy policy inside the game (no browser, no link), in every language:
## each has its own text, with no key left untranslated and no name left unfilled, and Back returns to Settings.
func _legal_pages() -> void:
	var pages := {"LICENCES": ["licences_screen", 6000, ["CC0", "CC BY 4.0", "Gregor Quendel", "JC Sounds", "Poly Haven",
		"Kenney", "Carnegie Mellon", "Meshy", "Godot Engine", "Open Font License", "MoCap Online", "ActorCore"]],
		"HELP_SUPPORT": ["help_screen", 900, ["joshnason8@gmail.com"]],
		"PRIVACY_POLICY": ["privacy_screen", 900, ["joshnason8@gmail.com", "2026"]]}
	for pair in Game.LANGUAGES:
		TranslationServer.set_locale(pair[0])
		Game.settings.language = pair[0]
		for key in pages:
			var st := Game.show_screen("res://ui/settings_screen.gd")
			await frames(3)
			var btn := _button_named(st, tr(key))
			check(btn != null, "%s: Settings has %s" % [pair[0], key])
			if btn == null:
				continue
			btn.pressed.emit()
			await frames(4)
			var page: Node = Game.current
			var want: Array = pages[key]
			check(page != null and String(page.get_script().resource_path).ends_with(want[0] + ".gd"),
				"%s: %s opens in the game" % [pair[0], key])
			if page == null:
				continue
			check(_first_scroll(page) != null, "%s: %s scrolls" % [pair[0], key])
			var text := _all_text(page)
			check(text.length() >= int(want[1]), "%s: %s is not empty (%d characters)" % [pair[0], key, text.length()])
			for must in want[2]:
				check(text.contains(must), "%s: %s says %s" % [pair[0], key, must])
			var left := RegEx.create_from_string("\\b(HELP|PRIV|CTRL|RULES)_[A-Z_]+\\b|\\{[a-z]+\\}").search(text)
			check(left == null, "%s: %s has no untranslated key or unfilled name (%s)" % [pair[0], key, left.get_string() if left else ""])
			check(page.has_meta("back"), "%s: %s has a Back button" % [pair[0], key])
			if page.has_meta("back"):
				(page.get_meta("back") as Callable).call()
				await frames(3)
				check(String(Game.current.get_script().resource_path).ends_with("settings_screen.gd"),
					"%s: Back from %s goes to Settings" % [pair[0], key])
	TranslationServer.set_locale("en")
	Game.settings.language = "en"
	Game.goto_menu()
	await frames(2)


## The first button whose text is t.
func _button_named(n: Node, t: String) -> Button:
	if n is Button and (n as Button).text == t:
		return n
	for c in n.get_children():
		var f := _button_named(c, t)
		if f:
			return f
	return null


## Every word on a page.
func _all_text(n: Node) -> String:
	var s := ""
	if n is RichTextLabel:
		s = (n as RichTextLabel).get_parsed_text()
	elif n is Label:
		s = (n as Label).text
	elif n is Button:
		s = (n as Button).text
	for c in n.get_children():
		s += "\n" + _all_text(c)
	return s


## Each scrolling page scrolls when a drag starts on its words (Kabaddi's How to Play did not).
func _scroll_on_text() -> void:
	Game.new_cup("ESC")
	for path in ["res://ui/howto_screen.gd", "res://ui/licences_screen.gd", "res://ui/help_screen.gd", "res://ui/privacy_screen.gd",
			"res://ui/settings_screen.gd", "res://ui/quick_setup.gd", "res://ui/result_screen.gd", "res://ui/cup_screen.gd"]:
		var args := {"result": fake_result()} if path.ends_with("result_screen.gd") else {}
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
	Game.delete_cup()


func _first_scroll(n: Node) -> ScrollContainer:
	if n is ScrollContainer and (n as ScrollContainer).is_visible_in_tree():
		return n
	for c in n.get_children():
		var f := _first_scroll(c)
		if f:
			return f
	return null


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


# ---------------------------------------------------------------- the cup, simulated results

func _cup() -> void:
	for rules in [Rules.ULAMA, Rules.CLASSIC]:
		for team in ["ESC", "PIS", "COP"]:
			var c := Cup.create(team, rules)
			check(c.draw.size() == 4, "Cup (%s, %s): eight towns in four quarter-finals" % [rules, team])
			var towns := {}
			for pair in c.draw:
				towns[pair[0]] = true
				towns[pair[1]] = true
			check(towns.size() == 8 and towns.has(team), "Cup: eight different towns, yours among them")
			var guard := 0
			while not c.done() and guard < 10:
				guard += 1
				var f := c.next_fixture()
				if f.is_empty():
					c.play_others()
					continue
				check(f.home == team or f.away == team, "Cup: your next game is yours")
				check(DB.venue(String(f.venue)).rules == rules, "Cup: played on a court of its rules")
				var s := ResultSim.play(String(f.home), String(f.away), rules)
				c.record_user_result({"home": f.home, "away": f.away, "winner": s.winner, "count": s.count})
				var saved := Cup.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
				check(saved.round == c.round and saved.team == c.team and saved.draw.size() == c.draw.size(), "Cup: it saves and loads")
			check(c.done() and c.champion != "", "Cup (%s, %s): played to a champion (%s)" % [rules, team, c.champion])
			check(c.history.size() == 3, "Cup: three rounds")


func _sim() -> void:
	var wins := [0, 0]
	var lens := []
	for i in 60:
		var s := ResultSim.play("ESC", "LLA", Rules.ULAMA, 100 + i)
		wins[int(s.winner)] += 1
		lens.append(int(s.rayas))
		check(int(s.count.rayas) == 8 and int(s.count.holder) == int(s.winner), "Sim: a simulated ulama game ends on eight rayas")
	lens.sort()
	check(wins[0] > 5 and wins[1] > 5, "Sim: either town can win (%s)" % str(wins))
	check(int(lens[lens.size() / 2]) > 12, "Sim: the count swings: a median of %d rayas to reach eight" % int(lens[lens.size() / 2]))


# ---------------------------------------------------------------- the crowd

## Every spectator, at every venue and graphics level, faces the court: dot(facing, toward the centre) > 0.7 (five of
## the six earlier games shipped this wrong). And the shader draws them from behind when the camera is behind them.
## The ready stance is an athlete's (owner, A16 playtest: "like an A-pose"): the knees bent, the soles on the floor
## with the heels just up, the hands loose by the thighs rather than held out from the sides, at every crouch the
## players use. The pose is the game's on every level (Low draws it on the game's bodies, Medium and High on the rig).
func _stance() -> void:
	var b := Body.new({"kind": "ulama", "height": 1.8, "rigged": false})
	add_child(b)
	await get_tree().process_frame
	for low in [0.2, 0.5, 0.8]:
		b.apply(Moves.stance(0.7, low))
		var hips := b.bone_world("hips")
		var ankle_y := b.bone_world("foot_l").y
		var knee := b.bone_world("shin_l")
		var hand := b.bone_world("hand_l")
		var sh := b.bone_world("upperarm_l")
		check(absf(ankle_y - 0.04 - 0.13 * sin(deg_to_rad(7.0 + 4.0 * low))) < 0.03,
			"stance %.1f: the soles stay on the floor, heels up (ankle %.3f m)" % [low, ankle_y])
		check(knee.z > hips.z + 0.1 and hips.y < 0.92, "stance %.1f: the knees bent and forward, the hips down (%.2f m)" % [low, hips.y])
		check(absf(hand.x - sh.x) < 0.12 and hand.y < sh.y, "stance %.1f: the hands hang near the body, not out from the sides" % low)
	# Never still (owner, 0.6.3: "too rigid"), and still planted: over 20 s of waiting the hips shift and dip and the arms
	# stir, while the ankles stay within a few centimetres of where they stood.
	var ankles := []
	var hips_lo := INF
	var hips_hi := -INF
	var side_lo := INF
	var side_hi := -INF
	var hand_lo := INF
	var hand_hi := -INF
	var ank_y_lo := INF
	var ank_y_hi := -INF
	for i in 600:
		b.apply(Moves.stance(i / 30.0, 0.5))
		var hp := b.bone_world("hips")
		hips_lo = minf(hips_lo, hp.y)
		hips_hi = maxf(hips_hi, hp.y)
		side_lo = minf(side_lo, hp.x)
		side_hi = maxf(side_hi, hp.x)
		var hz := b.bone_world("hand_r").z
		hand_lo = minf(hand_lo, hz)
		hand_hi = maxf(hand_hi, hz)
		for sd in ["l", "r"]:
			var a := b.bone_world("foot_" + sd)
			ankles.append(Vector2(a.x, a.z))
			ank_y_lo = minf(ank_y_lo, a.y)
			ank_y_hi = maxf(ank_y_hi, a.y)
	var drift := 0.0
	for i in range(2, ankles.size()):
		drift = maxf(drift, (ankles[i] as Vector2).distance_to(ankles[i % 2]))
	check(hips_hi - hips_lo > 0.02 and side_hi - side_lo > 0.03 and hand_hi - hand_lo > 0.03,
		"stance: alive while he waits (the hips dip %.0f cm and shift %.0f cm, the hands stir %.0f cm)" % [(hips_hi - hips_lo) * 100.0, (side_hi - side_lo) * 100.0, (hand_hi - hand_lo) * 100.0])
	check(drift < 0.05 and ank_y_lo > 0.02 and ank_y_hi < 0.11, "stance: and his feet stay where they stand (%.1f cm at most, ankles %.2f-%.2f m up)" % [drift * 100.0, ank_y_lo, ank_y_hi])
	b.queue_free()


func _crowd_faces() -> void:
	var keep := int(Game.settings.graphics)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for id in DB.VENUE_ORDER:
			var v := Venue.new()
			add_child(v)
			v.build(id, Court.new(String(DB.venue(id).rules)))
			# Placed by the shared foundation (WsgCrowdVenue): each faces the court's nearest part (at most 50 degrees off
			# square to their row), the standing and the seated alike.
			var worst := 1.0
			var n := v.crowd.spots.size()
			var cv := Venue.crowd_venue(id)
			for i in n:
				var p: Vector3 = v.crowd.spots[i]
				var near := cv.nearest_play(p)
				var to := Vector3(near.x - p.x, 0, near.z - p.z).normalized()
				worst = minf(worst, (v.crowd.facings[i] as Vector3).dot(to))
				var t: Transform3D = v.crowd.xforms[i]
				var f := Vector3(t.basis.z.x, 0, t.basis.z.z).normalized()
				worst = minf(worst, f.dot(to))
			for i in v.crowd.seated:
				var p: Vector3 = v.crowd.placed.spots[i]
				var near := cv.nearest_play(p)
				var to := Vector3(near.x - p.x, 0, near.z - p.z).normalized()
				worst = minf(worst, (v.crowd.placed.facings[i] as Vector3).dot(to))
			var people := n + v.crowd.seated.size()
			# Wherever the play is along the court, the people in the side stands look into the court, never away.
			var away := 0
			for fx in [-v.court.half_l(), 0.0, v.court.half_l()]:
				for i in n:
					var p: Vector3 = v.crowd.spots[i]
					if absf(p.z) > 3.5 and absf(p.x) < v.court.half_l():
						var f := Crowd.facing_at(p, Vector3(fx, 0, 0))
						if f.z * signf(p.z) > -0.05:
							away += 1
			check(away == 0, "Crowd: at %s (graphics %d) the side stands watch the play wherever it is (%d look away)" % [id, g, away])
			check(people > 40, "Crowd: %s at graphics %d has people (%d)" % [id, g, people])
			# Nobody stands where a player can run (the owner: no one walks through anything).
			var in_play := 0
			var all_spots: Array = v.crowd.spots.duplicate()
			for i in v.crowd.seated:
				all_spots.append(v.crowd.placed.spots[i])
			for p in all_spots:
				var bnd: Array = v.court.bounds_at(Vector3(p.x, 0, p.z))
				if p.y < 0.5 and p.x > bnd[0] - 0.3 and p.x < bnd[1] + 0.3 and p.z > bnd[2] - 0.3 and p.z < bnd[3] + 0.3:
					in_play += 1
			check(in_play == 0, "Crowd: at %s (graphics %d) no one stands where the players run (%d do)" % [id, g, in_play])
			# Seated where there are seats (the village's benches, the festival's stand), on them as the shared audit
			# measures it: each at their seat's height, in front of it (never cut by it), facing the play.
			if id in ["village", "festival"]:
				var cards: WsgCrowdCards = v.crowd.cards
				var res: Dictionary = cards.audit(cv, v.crowd.placed) if cards else {}
				check(cards != null and v.crowd.seated.size() > 10 and (res.get("fails", ["no cards"]) as Array).is_empty(),
					"Crowd: at %s (graphics %d) %d sit on the seats, as the shared audit has it (%s)" % [id, g, v.crowd.seated.size(), str(res.get("fails", "no cards"))])
			check(worst > 0.6, "Crowd: everyone at %s (graphics %d) faces the court (worst %.2f)" % [id, g, worst])
			if n > 0:
				var p0: Vector3 = v.crowd.spots[0]
				var f0: Vector3 = v.crowd.facings[0]
				check(Crowd.seen_from_behind(p0, f0, p0 - f0 * 10.0 + Vector3(0, 5, 0)) and not Crowd.seen_from_behind(p0, f0, p0 + f0 * 10.0),
					"Crowd: drawn from behind from behind, from the front from the front (%s)" % id)
			v.queue_free()
			await frames(1)
	Game.settings.graphics = keep


## The judges stand on something, not in it: on the earth by the court; on the stone courts on the coping along the
## wall's top (its top 0.5 m over the wall), not sunk half a metre into it.
## The props round the court are solid (the owner: "a ball should also bounce off these items"; WsgSolidProps): every
## venue declares them; no player, judge or elder starts inside one; the ball struck hard at a bench, a stand or the
## coping comes back off it, never through, with a knock; and a ball in play that knocks into one is out.
func _props_solid(venue: String, rules: String) -> void:
	var keep_light := Mocap.light   # (a match sets it for its graphics level: put back for the tests after)
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "ESC" if rules == "ulama" else "PIS", "away": "LLA" if rules == "ulama" else "VAL", "venue": venue, "rules": rules,
		"user_team": -1, "seed": 3, "length": 0.0, "mode": "test", "difficulty": 1, "ritual": rules == "classic"}
	add_child(m)
	await frames(2)
	var solid: WsgSolidProps = m.venue.solid
	check(m.court.solid == solid and solid.props.size() >= 10, "%s: the props round the court are solid (%d)" % [venue, solid.props.size()])
	var inside := []
	var bodies: Array = m.all_players().duplicate()
	bodies.append_array(m.officials.judges)
	if m.ritual:
		bodies.append(m.ritual.elder)
	for b in bodies:
		var pen := solid.penetration((b as Node3D).global_position, Player.WALK_R)
		if float(pen[0]) > 0.02:
			inside.append(String(solid.props[int(pen[1])].name))
	check(inside.is_empty(), "%s: nobody stands in a prop %s" % [venue, str(inside)])
	# Struck at the props: a bench (village), the stands (festival), the coping (the stone courts).
	var shots := {"village": [Vector3(7.6, 0.25, 1.0), Vector3(0.0, 1.0, 14.0), 5.2 + 0.175],
		"festival": [Vector3(4.0, 0.6, -1.0), Vector3(0.0, 1.5, -16.0), -(Venue.STAND_Z0 + Venue.STAND_ROWS * Venue.STAND_TREAD)],
		"stone": [Vector3(3.0, 5.35, -2.0), Vector3(0.0, 1.0, -18.0), -Court.TALUD_Z],
		"night": [Vector3(3.0, 5.35, 2.0), Vector3(0.0, 1.0, 18.0), Court.TALUD_Z]}
	var sh: Array = shots[venue]
	var ball: Ball = m.ball
	m.phase = m.P.CALL   # (out of play: the ball runs on as it will)
	ball.launch(sh[0], sh[1], 0, null)
	var face: float = sh[2]
	var past := 0.0
	var knocked := false
	var back := false
	for i in 60:
		for e in ball.step(1.0 / 30.0):
			if e.kind == "knock":
				knocked = true
		past = maxf(past, (ball.pos.z - face) * signf(face))
		if ball.vel.z * signf(face) < -0.5 and knocked:
			back = true
	check(knocked and back and past <= 0.0,
		"%s: the ball struck at the %s comes back off it, never through (%.2f m past its face)" % [venue, "bench" if venue == "village" else ("stands" if venue == "festival" else "coping"), past])
	m.queue_free()
	await frames(2)
	if venue == "village":
		# In play: into a bench is out.
		var m2: Node = load("res://game/match.gd").new()
		m2.config = {"home": "ESC", "away": "LLA", "venue": "village", "rules": "ulama", "user_team": -1, "seed": 3, "length": 0.0, "mode": "test", "difficulty": 1, "ritual": false}
		add_child(m2)
		await frames(2)
		var g := 0
		while m2.phase != m2.P.LIVE and g < 30 * 20:
			await get_tree().process_frame
			g += 1
		m2.ball.launch(Vector3(7.6, 0.3, 1.0), Vector3(0.0, 0.8, 16.0), 0, null)
		for k in m2.all_players():
			(k as Player).global_position.x = -20.0   # nobody near it
		var rayas0: int = m2.log_rayas.size()
		g = 0
		while m2.log_rayas.size() == rayas0 and g < 60:
			await get_tree().process_frame
			g += 1
		check(m2.log_rayas.size() > rayas0 and String(m2.log_rayas[-1][1]) == "out", "village: a ball in play into a bench is out (%s)" % (str(m2.log_rayas[-1]) if m2.log_rayas.size() > rayas0 else "nothing called"))
		m2.queue_free()
		await frames(2)
	Mocap.light = keep_light


func _judges_stand() -> void:
	for rules in ["ulama", "classic"]:
		var c := Court.new(rules)
		var o := Officials.new()
		add_child(o)
		o.build(c)
		var ok := true
		for j in o.judges:
			var y: float = (j as Node3D).position.y
			if rules == "classic":
				ok = ok and is_equal_approx(y, Court.WALL_H + 0.5)
			else:
				ok = ok and is_equal_approx(y, 0.0) and absf((j as Node3D).position.z) > c.half_w_at(0.0) + 0.6
		check(ok and o.judges.size() == 2, "Judges (%s): standing on the ground or the coping, out of the play" % rules)
		o.queue_free()
		await frames(1)


# ---------------------------------------------------------------- the Yucatán stone courts

## The opening offering of copal: on the stone courts (not on ulama's), the elder visits every player, arms go up, it
## ends by itself or at SKIP, then the serve; the stone court's serve comes down past the analco and rises off the
## bounce to be played.
func _yucatan() -> void:
	var cfg := {"home": "PIS", "away": "VAL", "venue": "stone", "rules": "classic", "user_team": -1, "seed": 7, "length": 6.0,
		"mode": "test", "difficulty": 1, "ritual": true}
	var m: Node = load("res://game/match.gd").new()
	m.config = cfg
	add_child(m)
	await frames(2)
	check(m.in_ritual(), "Ritual: the stone court's game opens with the copal offering")
	var raised := {}
	var n := 0
	while m.in_ritual() and n < 30 * 40:
		await get_tree().process_frame
		n += 1
		for p in m.all_players():
			if (p as Player).offering > 0.9:
				raised[p] = true
	check(not m.in_ritual() and n < 30 * 40, "Ritual: it ends by itself (%.1f s)" % (n / 30.0))
	check(raised.size() == m.all_players().size(), "Ritual: every player raises his arms to the copal (%d of %d)" % [raised.size(), m.all_players().size()])
	var land_x := INF
	var serve_team := -1
	var off_bounce := false
	var touched := false
	n = 0
	while n < 30 * 20 and m.phase != m.P.CALL and not touched:
		var bounced_before: bool = m.serve_bounced
		await get_tree().process_frame
		n += 1
		if m.phase != m.P.LIVE:
			continue
		serve_team = m.serve_team
		if land_x == INF and m.serve_bounced:
			land_x = m.ball.pos.x
		if m.rally > 0:
			touched = true
			off_bounce = bounced_before or m.serve_bounced
	var d := Rules.dir(serve_team) if serve_team >= 0 else 1.0
	check(land_x != INF and land_x * d > 0.3 and land_x * d < 4.0,
		"Bote: the stone court's serve comes down just past the analco (%.1f m)" % (land_x * d if land_x != INF else -1.0))
	check(touched and off_bounce, "Bote: the receivers play it off the bounce, never on the full")
	m.queue_free()
	await frames(2)
	var m2: Node = load("res://game/match.gd").new()
	cfg.ritual = true
	m2.config = cfg.duplicate()
	add_child(m2)
	await frames(2)
	m2._on_action("SKIP")
	check(not m2.in_ritual(), "Ritual: SKIP passes it")
	m2.queue_free()
	await frames(2)
	var m3: Node = load("res://game/match.gd").new()
	m3.config = {"home": "ESC", "away": "LLA", "venue": "village", "rules": "ulama", "user_team": -1, "seed": 7, "length": 6.0,
		"mode": "test", "difficulty": 1, "ritual": true}
	add_child(m3)
	await frames(2)
	check(not m3.in_ritual(), "Ritual: none on ulama's village court (none is documented there)")
	m3.queue_free()
	await frames(2)


# ---------------------------------------------------------------- graphics levels

## Low loads exactly what it always has (the 512 surfaces, the 1024 bodies, the 2K skies, sixteen figures in the crowd,
## the short beds); Medium and High load their sharper files, and every one of those is in the build.
func _levels() -> void:
	var keep := int(Game.settings.graphics)
	var want := {Game.GFX_LOW: "_512.jpg", Game.GFX_MEDIUM: "_1k.jpg", Game.GFX_HIGH: "_2k.jpg"}
	for g in want:
		Game.settings.graphics = g
		for n in ["dry_ground_01", "brown_mud_dry", "plastered_wall", "sandstone_blocks", "broken_wall", "sparse_grass"]:
			var m := Geo.surface(n)
			check(m.albedo_texture != null and m.albedo_texture.resource_path.ends_with(n + "_albedo" + String(want[g])),
				"Levels: %s at graphics %d is the %s map (%s)" % [n, g, want[g], m.albedo_texture.resource_path if m.albedo_texture else "none"])
	Game.settings.graphics = Game.GFX_LOW
	check(not Crowd.hq_sheet() and not Sfx.hq(), "Levels: Low keeps its sixteen-figure crowd and its short beds")
	Game.settings.graphics = Game.GFX_HIGH
	check(Crowd.hq_sheet() and Sfx.hq(), "Levels: High has the 32-figure crowd and the long stereo beds")
	var missing := []
	for f in ["res://assets/people/court_ring.res", "res://assets/people/court_ring.jpg"]:
		if not ResourceLoader.exists(f):
			missing.append(f)
	for b in RiggedBody.BODIES:
		if not ResourceLoader.exists("res://assets/people/%s_2k.jpg" % b[0]):
			missing.append(b[0] + "_2k")
	for sky in ["qwantani_dusk_2_puresky", "kloofendal_48d_partly_cloudy_puresky", "kloppenheim_02_puresky", "qwantani_noon_puresky"]:
		if not ResourceLoader.exists("res://assets/env/sky/%s_sky_4k.jpg" % sky):
			missing.append(sky + "_4k")
	check(missing.is_empty(), "Levels: the Medium and High files are all in the build (missing %s)" % [missing])
	Game.settings.graphics = keep


# ---------------------------------------------------------------- sound

## Every recorded sound the game names is in the build and loads (docs/SOUNDS.md lists them), every court's
## surroundings name sounds that exist, and nothing plays while the match is paused.
func _sounds() -> void:
	Sfx._ensure()
	var names: Array = ["click", "ui_select", "crowd_loop", "crowd_cheer", "crowd_ooh", "crowd_groan", "applause", "clap", "menu_music",
		"amb_crickets", "amb_fire", "dog_bark"] + Sfx.HQ_SOUNDS
	for kind in Sfx.VARIANTS:
		for i in int(Sfx.VARIANTS[kind]):
			names.append("%s_%d" % [kind, i + 1])
	for kind in Sfx.VOICES:
		for i in int(Sfx.VOICES[kind]):
			names.append("%s_%d" % [kind, i + 1])
	var missing := []
	for n in names:
		var path := "res://assets/audio/%s.ogg" % n
		if not ResourceLoader.exists(path) or not (load(path) is AudioStream) or not (Sfx.streams.get(n) is AudioStream):
			missing.append(n)
	check(missing.is_empty(), "Sound: every recorded sound is in the build and loads (%d; missing %s)" % [names.size(), missing])
	var amb_ok := true
	for a: Array in Sfx.AMBIENCE.values() + Sfx.AMBIENCE_HQ.values():
		for i in [0, 2, 4]:
			var n := String(a[i])
			if n != "" and not Sfx.streams.has(n) and not Sfx.VARIANTS.has(n):
				amb_ok = false
	check(amb_ok, "Sound: every court's surroundings name sounds that exist")
	var keep := bool(Game.settings.sound)
	Game.settings.sound = true
	Sfx.pause(true)
	var before := 0
	for p in Sfx._pool:
		before += 1 if p.playing else 0
	Sfx.play("click")
	var after := 0
	for p in Sfx._pool:
		after += 1 if p.playing else 0
	Sfx.pause(false)
	Game.settings.sound = keep
	check(after == before, "Sound: nothing new plays while paused")


# ---------------------------------------------------------------- the ring

## The ring shot can be made (a perfect strike from a good spot goes in some of the time, never always), and the ball
## through the ring is replayed: on the bodies only (the players stay where they are), then the match ends.
func _ring_replay() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "ESC", "away": "LLA", "venue": "stone", "rules": "classic", "user_team": -1, "seed": 5, "length": 6.0, "mode": "test", "difficulty": 1}
	add_child(m)
	var p: Player = m.teams[0].players[0]
	check(m.ring_shot(p, Vector3(0, 0, 1)) == 0 or absf(p.global_position.x) >= m.RING_SHOT_X.x, "Ring: no ring shot from the middle")
	var made := 0
	for i in 40:
		p.action = Player.A.STRIKE
		p.action_ring = 1
		var spot := Vector3(-6, 0.7, 3.2)
		var pr = m._Probe.new()
		pr.pos = spot
		pr.vel = m._ring_launch(p, spot, 1.0)
		var ev := []
		for k in 500:
			pr.pos = Ball.simulate(pr, m.STEP, m.court, "stone", ev)
			if pr.grounded:
				break
		for e in ev:
			if e.kind == "ring":
				made += 1
				break
	p.action = Player.A.NONE
	p.action_ring = 0
	check(made > 2 and made < 38, "Ring: a perfect ring shot goes in sometimes, not always (%d of 40)" % made)
	var n := 0
	var turned := 0.0
	var last := NAN
	while m.phase != m.P.LIVE and n < 30 * 30:
		await get_tree().process_frame
		n += 1
		if m.server != null:
			if not is_nan(last):
				turned += absf(angle_difference(last, m.server.yaw))
			last = m.server.yaw
	check(turned < 4.0, "Serve: the server holding the ball does not spin on the spot (turned %.1f rad)" % turned)
	# A moment into play (a raya before it, a serve taken on the body say, and it waits for the next one).
	var into := 0
	n = 0
	while into < 20 and n < 30 * 60:
		await get_tree().process_frame
		n += 1
		into = into + 1 if m.phase == m.P.LIVE else 0
	m._award(0, "ring", false, null)
	var seen := false
	var still := true
	n = 0
	while m.phase != m.P.OVER and n < 30 * 40:
		var before := []
		for q in m.all_players():
			before.append((q as Player).global_position)
		var was_replay: bool = m.phase == m.P.REPLAY
		await get_tree().process_frame
		n += 1
		if m.phase == m.P.REPLAY:
			seen = true
		if was_replay and m.phase == m.P.REPLAY:
			seen = true
			var ps: Array = m.all_players()
			for k in ps.size():
				if (ps[k] as Player).global_position.distance_to(before[k]) > 0.0001:
					still = false
	check(seen, "Ring: the ball through the ring is replayed")
	check(still, "Ring: the replay moves the bodies only, not the players")
	check(m.phase == m.P.OVER and int(m.count.winner) == 0, "Ring: after the replay the match is over, won by the ring")
	m.queue_free()
	await frames(2)


# ---------------------------------------------------------------- recorded movement

## Every recorded clip loads, and a planted foot stays planted: the run played as a player plays it (moving at the
## clip's speed, stepping at the game's stride, at two heights), and the serve's toss standing still.
func _mocap() -> void:
	for name in Mocap.ALL:
		var c := Mocap.clip(name)
		check(not c.is_empty() and (c.frames as Array).size() >= 10 and is_equal_approx(float(c.fps), 30.0),
			"Mocap: %s loads (%d frames at 30 fps)" % [name, (c.get("frames", []) as Array).size()])
		check(Mocap.sample(name, 0.3).has("thigh_l"), "Mocap: %s samples to a pose" % name)
	var run := Mocap.clip(Mocap.RUN)
	for h in [1.8, 1.62]:
		var b := Body.new({"kind": "ulama", "height": h})
		add_child(b)
		var v := float(run.speed)
		var stride := Player.stride_at(v) * b.scale.x
		var slide := _foot_slide(b, func(t: float) -> Dictionary: return Mocap.run(t * v / (2.0 * stride)), v, float(run.duration) * 3.0)
		check(slide < MOCAP_SLIDE, "Mocap: the run's planted feet stay put (height %.2f, worst slide %.3f m)" % [h, slide])
		b.queue_free()
	var toss := Mocap.clip(Mocap.TOSS)
	var bt := Body.new({"kind": "ulama", "height": 1.8})
	add_child(bt)
	var s2 := _foot_slide(bt, func(t: float) -> Dictionary: return Mocap.sample(Mocap.TOSS, t), 0.0, float(toss.held))
	check(s2 < MOCAP_SLIDE, "Mocap: the serve's feet stay put through the toss (worst slide %.3f m)" % s2)
	check(Moves.SERVE_HIT * Moves.SERVE_T > 0.9 * float(toss.hit) and Moves.SERVE_HIT * Moves.SERVE_T < 1.1 * float(toss.hit),
		"Mocap: the serve's release is the recorded release")
	bt.queue_free()
	Mocap.light = true
	check(Mocap.run(0.37).has("hips_fwd"), "Mocap: Low graphics plays the nearest frame")
	Mocap.light = false
	await frames(1)


const MOCAP_SLIDE := 0.03    # metres a planted foot may slip
const MOCAP_DOWN := 0.012    # a heel or toe this close to the ground is planted (higher, it is lifting off)


## The worst slip of a planted foot: the body moved at speed along +Z and posed by pose_at(t) every thirtieth of a
## second; a foot is planted while its heel or toe is on the ground (MOCAP_DOWN), and from then that point is held to
## where it was.
func _foot_slide(b: Body, pose_at: Callable, speed: float, length: float) -> float:
	var worst := 0.0
	var start := {}
	var t := 0.0
	var k := b.scale.x
	while t <= length + 0.001:
		b.position = Vector3(0, 0, speed * t)
		b.apply(pose_at.call(t))
		for side in ["l", "r"]:
			var i := b.bone("foot_" + side)
			var g := b.skeleton.global_transform * b.skeleton.get_bone_global_pose(i)
			var heel := g.origin
			var toe := g * Vector3(0, -0.025, 0.14)
			var hh := heel.y - 0.04 * k
			var th := toe.y - 0.015 * k
			if minf(hh, th) < MOCAP_DOWN * k:
				var pt := heel if hh <= th else toe
				var key: String = String(side) + ("h" if hh <= th else "t")
				if not start.has(side) or start[side][0] != key:
					start[side] = [key, pt]
				var s0: Vector3 = start[side][1]
				var d := Vector2(pt.x - s0.x, pt.z - s0.z).length()
				worst = maxf(worst, d)
			else:
				start.erase(side)
		t += 1.0 / 30.0
	return worst


# ---------------------------------------------------------------- a match

## The computer plays the hip game (owner, 0.6.3: "the AI is dumb and barely hits the ball after the serve"; "it is
## rolling the ball on the serve, it should set up for bouncing"): every serve comes down and bounces up off the
## ground, never rolled along it; through two minutes of an AI match the ball is met with the hip standing far more
## often than dived for on the ground, and rallies go on.
const SERVE_TOSS_MIN := 1.6   # the serve goes up at least this high (m; the owner, 0.6.8: "toss the ball up higher")


func _ai_plays(venue: String, rules: String) -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "ESC" if rules == "ulama" else "PIS", "away": "LLA" if rules == "ulama" else "VAL", "venue": venue, "rules": rules,
		"user_team": -1, "seed": 21, "length": 0.0, "mode": "test", "difficulty": 1, "ritual": false}
	add_child(m)
	await frames(2)
	var serves := 0
	var rolled := 0
	var low_bounce := 0
	var flight := -1
	var watch := false
	var first_top := 0.0
	var landed := false
	var rallies := []
	var tossed := []           # each serve's highest point before it first comes down (m)
	for f in 30 * 120:
		await get_tree().process_frame
		if m.phase == m.P.OVER:
			break
		if m.ball_flight != flight:
			if watch and landed:
				if first_top < 0.4:
					low_bounce += 1
			flight = m.ball_flight
			watch = m.rally == 0 and m.phase == m.P.LIVE
			if watch:
				serves += 1
				tossed.append(0.0)
			first_top = 0.0
			landed = false
		if watch and not m.ball.held:
			var y: float = m.ball.pos.y - Ball.RADIUS
			if not landed:
				tossed[-1] = maxf(float(tossed[-1]), y)
			if not landed and y < 0.02:
				landed = true
				if m.ball.grounded:
					rolled += 1
			elif landed:
				# How high it would rise off that bounce (a receiver may take it on the way up).
				first_top = maxf(first_top, y + maxf(0.0, float(m.ball.vel.y)) ** 2 / (2.0 * Ball.GRAVITY))
	var st: int = int(m.tstats[0].get("strikes", 0)) + int(m.tstats[1].get("strikes", 0))
	var dv: int = int(m.tstats[0].get("dives", 0)) + int(m.tstats[1].get("dives", 0))
	var rayas: int = m.log_rayas.size()
	check(serves >= 3 and rolled == 0 and low_bounce <= serves / 4,
		"%s: the serve bounces up off the ground, never rolled (%d serves, %d rolled, %d bounced under 0.4 m)" % [venue, serves, rolled, low_bounce])
	var low_toss := tossed.filter(func(h): return float(h) < SERVE_TOSS_MIN)
	check(not tossed.is_empty() and low_toss.is_empty(), "%s: the serve is tossed up high (lowest %.1f m, highest %.1f m)" % [venue,
		float(tossed.min()) if not tossed.is_empty() else 0.0, float(tossed.max()) if not tossed.is_empty() else 0.0])
	check(st > dv * 1.5 and st >= 20, "%s: the computer meets the ball with the hip, not on the ground (%d strikes, %d dives in 2 min)" % [venue, st, dv])
	check(float(m.top_strike) <= Player.STRIKE_MAX_UP + 0.001,
		"%s: and at the hip, never the belly or chest (highest %.2f m over the hip)" % [venue, float(m.top_strike)])
	var why := {}
	for r in m.log_rayas:
		why[r[1]] = int(why.get(r[1], 0)) + 1
	check(float(st + dv) / maxf(1.0, rayas) >= 3.0, "%s: and the rallies go on (%.1f touches a raya over %d rayas %s, longest %d)" % [venue, (st + dv) / maxf(1.0, rayas), rayas, str(why), m.longest_rally])
	m.queue_free()
	await frames(2)


## The stick is the screen's, whatever the camera (owner: "switching to a camera angle that is not alongside the
## court, the joystick movement is all wrong"): on the court-side, high and end cameras, pushing the stick up, right,
## down or left sends your player up, right, down or left on the screen (within 10 degrees), the way he is told to go
## and the way he then runs.
func _stick_camera(venue: String, rules: String) -> void:
	var keep_cam := int(Game.settings.camera)
	var keep_ctl := int(Game.settings.get("control", 0))
	Game.settings.control = 1     # one player: the stick stays on the same man
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "ESC" if rules == "ulama" else "PIS", "away": "LLA" if rules == "ulama" else "VAL", "venue": venue, "rules": rules,
		"user_team": 0, "seed": 3, "length": 0.0, "mode": "quick", "difficulty": 0, "ritual": false}
	add_child(m)
	await frames(2)
	var guard := 0
	while m.phase != m.P.LIVE and guard < 30 * 30:
		if m.phase == m.P.SERVE and m.serve_team == 0:
			m._on_action("SERVE")
		await get_tree().process_frame
		guard += 1
	var names := {Game.CAM_TV: "court-side", Game.CAM_HIGH: "high", Game.CAM_END: "end"}
	var dirs := [[Vector2(0, -1), "up"], [Vector2(1, 0), "right"], [Vector2(0, 1), "down"], [Vector2(-1, 0), "left"]]
	for mode in [Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END]:
		Game.settings.camera = mode
		m.cam.mode = mode
		m.cam.snap(m)
		await frames(10)
		var worst_aim := 0.0
		var worst_run := 0.0
		var runs := 0
		for d in dirs:
			var want: Vector2 = d[0]
			# In play (a raya sends it back to the serve, where the stick does not move him).
			guard = 0
			while m.phase != m.P.LIVE and guard < 30 * 30:
				if m.phase == m.P.SERVE and m.serve_team == 0:
					m._on_action("SERVE")
				await get_tree().process_frame
				guard += 1
			var pl: Player = m.user_player
			# On his own half, mid-court across and 5 m or more from the analco so no wall or line slows him (he eases to
			# stop at them, which bends his run), where this camera shows him.
			var c0: Camera3D = m.cam.camera
			var spot := Vector3(-Rules.dir(0) * 6.0, 0, 0)
			for k in 12:
				var x := -Rules.dir(0) * (5.0 + k * 2.0)
				var q := Vector3(x, 0, 0)
				if absf(x) < m.court.half_l() - 3.0 and not c0.is_position_behind(q) \
						and c0.get_viewport().get_visible_rect().grow(-80.0).has_point(c0.unproject_position(q)):
					spot = q
					break
			pl.global_position = spot
			pl.vel = Vector3.ZERO
			m.hud.touch.joystick = want
			await frames(12)
			var c: Camera3D = m.cam.camera
			var at := pl.global_position
			var s0 := c.unproject_position(at)
			var aim := c.unproject_position(at + pl.want_dir) - s0
			worst_aim = maxf(worst_aim, absf(rad_to_deg(aim.angle_to(want))))
			if Vector2(pl.vel.x, pl.vel.z).length() > 0.8:
				var run := c.unproject_position(at + pl.vel * 0.2) - s0
				worst_run = maxf(worst_run, absf(rad_to_deg(run.angle_to(want))))
				runs += 1
			m.hud.touch.joystick = Vector2.ZERO
			await frames(4)
		check(worst_aim <= 10.0, "%s, %s camera: the stick's up, right, down and left are the screen's (worst %.1f degrees off)" % [venue, names[mode], worst_aim])
		check(runs >= 3 and worst_run <= 10.0, "%s, %s camera: and he runs that way on the screen (%d runs, worst %.1f degrees off)" % [venue, names[mode], runs, worst_run])
	# A cut to another camera mid-run: the way he runs turns over about 0.2 s, not at once.
	m.cam.mode = Game.CAM_END
	m.cam.snap(m)
	m.hud.touch.joystick = Vector2(0, -1)
	await frames(15)
	var before: Vector3 = m.user_player.want_dir
	m.cam.mode = Game.CAM_TV
	m.cam.snap(m)
	var steps := []
	var last := before
	for i in 9:
		await frames(1)
		steps.append(rad_to_deg(last.angle_to(m.user_player.want_dir)))
		last = m.user_player.want_dir
	var total := rad_to_deg(before.angle_to(last))
	check(total > 45.0 and float(steps.max()) < total * 0.75 and float(steps.back()) < 2.0,
		"%s: a cut to another camera mid-run turns his way over a few frames (%.0f degrees: %s)" % [venue, total, str(steps.map(func(x): return snappedf(x, 1.0)))])
	m.hud.touch.joystick = Vector2.ZERO
	m.queue_free()
	await frames(2)
	Game.settings.camera = keep_cam
	Game.settings.control = keep_ctl


## Watch AI (the main menu's, owner's A16 notes): two towns played by the computer, on the broadcast camera whatever
## camera the player's own matches use, the score on the board, replays, pause and quit, and 1x / 2x: at 2x the
## match's clock runs twice as fast for the same frames, the ball's flight stepped just as at 1x.
func _watch_ai() -> void:
	var keep := int(Game.settings.camera)
	Game.settings.camera = Game.CAM_END
	var menu_has := false
	var mm: Node = (load("res://ui/main_menu.gd") as Script).new()
	add_child(mm)
	await frames(2)
	for b in mm.find_children("*", "Button", true, false):
		for l in (b as Node).find_children("*", "Label", true, false):
			if (l as Label).text == tr("MENU_WATCH"):
				menu_has = true
	mm.queue_free()
	check(menu_has, "Watch AI: on the main menu")
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "PIS", "away": "VAL", "venue": "stone", "rules": "classic", "user_team": -1, "seed": 6,
		"length": 0.0, "mode": "watch", "difficulty": 2, "ritual": false}
	add_child(m)
	await frames(2)
	check(m.watching() and m.cam.mode == Game.CAM_TV, "Watch AI: the broadcast camera, not the player's own (end) camera")
	await frames(2)
	check(m.hud != null and m.hud.speed_button != null and not m.hud.touch.stick and (m.hud.touch.ids as Array).is_empty(),
		"Watch AI: a speed button, no controls (no joystick, no buttons)")
	check(m.hud != null and m.hud.score_line() != "", "Watch AI: the score on the board")
	var guard := 0
	while m.phase != m.P.LIVE and guard < 30 * 20:
		await get_tree().process_frame
		guard += 1
	var c0: float = m.clock
	await frames(60)
	var one: float = m.clock - c0
	m.hud.speed_button.pressed.emit()
	check(int(m.speed) == 2 and m.hud.speed_button.text == tr("SPEED_2"), "Watch AI: the button turns it to 2x")
	guard = 0
	while m.phase != m.P.LIVE and guard < 30 * 30:
		await get_tree().process_frame
		guard += 1
	c0 = m.clock
	await frames(60)
	var two: float = m.clock - c0
	check(two > one * 1.6, "Watch AI: 2x plays twice as fast (%.2f s of play in 60 frames, %.2f at 1x)" % [two, one])
	m.set_paused(true)
	c0 = m.clock
	await frames(20)
	check(is_equal_approx(float(m.clock), c0) and m.hud._pause != null, "Watch AI: pause stops it and shows the menu (resume, quit)")
	m.set_paused(false)
	# A raya through the ring, at 2x: it is replayed, as in a match (the ring's at every level; the other big moments'
	# on Medium and High, which these tests do not draw).
	guard = 0
	var into := 0
	while into < 20 and guard < 30 * 60:
		await get_tree().process_frame
		guard += 1
		into = into + 1 if m.phase == m.P.LIVE else 0
	m._award(0, "ring", false, null)
	guard = 0
	while (m.replays as Array).is_empty() and guard < 30 * 20:
		await get_tree().process_frame
		guard += 1
	check(not (m.replays as Array).is_empty(), "Watch AI: replays of the rayas, as in a match")
	m.hud.speed_button.pressed.emit()
	check(int(m.speed) == 1 and m.hud.speed_button.text == tr("SPEED_1"), "Watch AI: and back to 1x")
	m.queue_free()
	await frames(2)
	# The copal can be passed when watching too (the owner, 0.6.8): a SKIP button while it burns, and it works.
	var mr: Node = load("res://game/match.gd").new()
	mr.config = {"home": "PIS", "away": "VAL", "venue": "stone", "rules": "classic", "user_team": -1, "seed": 6,
		"length": 0.0, "mode": "watch", "difficulty": 2, "ritual": true}
	add_child(mr)
	await frames(3)
	var tc: TouchControls = mr.hud.touch
	check(mr.in_ritual() and tc.is_visible_in_tree() and tc.ids == ["SKIP"], "Watch AI: a SKIP button over the copal")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	tc._input(key)
	await frames(2)
	check(not mr.in_ritual(), "Watch AI: SKIP passes the copal")
	check((tc.ids as Array).is_empty(), "Watch AI: and the button goes with it")
	mr.queue_free()
	await frames(2)
	Game.settings.camera = keep


## The court-side camera keeps the play in the picture (owner, A16 playtest: "you can't see the whole game"): through
## an AI match, on a 20:9 phone, 16:9 and a 4:3 tablet, the ball and the players near it are on the screen, and on the
## stone court the near edge of the alley shows over the near wall.
func _tv_camera(venue: String, rules: String) -> void:
	var keep := int(Game.settings.camera)
	Game.settings.camera = Game.CAM_TV
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "ESC" if rules == "ulama" else "PIS", "away": "LLA" if rules == "ulama" else "VAL", "venue": venue, "rules": rules,
		"user_team": -1, "seed": 4, "length": 3.0, "mode": "test", "difficulty": 2, "ritual": false}
	add_child(m)
	await frames(2)
	var cam: CameraRig = m.cam
	var seen := {}
	var total := {}
	var ball_out := {}
	var hidden_edge := 0
	for f in 30 * 40:
		await get_tree().process_frame
		if m.phase == m.P.OVER:
			break
		if f % 20 != 0 or m.phase == m.P.REPLAY:
			continue
		for a in [2.17, 1.78, 1.33]:
			cam.aspect_override = a
			cam.snap(m)
			var c := cam.camera
			var inv := c.global_transform.affine_inverse()
			var tv := tan(deg_to_rad(c.fov) * 0.5)
			var th: float = tv * a
			var inside := func(p: Vector3, slack: float) -> bool:
				var q := inv * p
				return q.z < -0.1 and absf(q.x / -q.z) <= th * slack and absf(q.y / -q.z) <= tv * slack
			if not inside.call(m.ball.pos, 1.0):
				ball_out[a] = int(ball_out.get(a, 0)) + 1
			for p in m.all_players():
				var pp: Vector3 = (p as Player).global_position + Vector3(0, 0.9, 0)
				if absf(pp.x - float(m.ball.pos.x)) < CameraRig.NEAR:
					total[a] = int(total.get(a, 0)) + 1
					if inside.call(pp, 1.0):
						seen[a] = int(seen.get(a, 0)) + 1
			if m.court.classic():
				var cp := c.global_position
				var edge := Vector3(cp.x, 0.0, Court.ALLEY_HALF_W)
				var y_at_wall := cp.y + (edge.y - cp.y) * (cp.z - Court.TALUD_Z) / (cp.z - edge.z)
				if y_at_wall < Court.WALL_H:
					hidden_edge += 1
	cam.aspect_override = 0.0
	for a in [2.17, 1.78, 1.33]:
		var share := float(seen.get(a, 0)) / maxf(1.0, float(total.get(a, 0)))
		check(int(ball_out.get(a, 0)) == 0, "%s camera, %.2f:1 screen: the ball always in the picture (out %d times)" % [venue, a, int(ball_out.get(a, 0))])
		check(share >= 0.97, "%s camera, %.2f:1 screen: the players near the ball in the picture (%.0f%%)" % [venue, a, share * 100.0])
	if rules == "classic":
		check(hidden_edge == 0, "stone camera: the alley's near edge shows over the near wall")
	m.queue_free()
	await frames(2)
	Game.settings.camera = keep


func _match_and_motion(venue: String, rules: String) -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "ESC" if rules == "ulama" else "PIS", "away": "LLA" if rules == "ulama" else "VAL", "venue": venue, "rules": rules,
		"user_team": -1, "seed": 9, "length": 3.0, "mode": "test", "difficulty": 2}
	var buzzes := Game.haptic_calls
	add_child(m)
	await frames(2)
	var last := {}
	var lastv := {}
	var worst_jump := 0.0
	var worst_acc := 0.0
	var dist := 0.0
	var steps := 0
	var probe: Player = m.teams[0].players[1]
	var guard := 0
	var strikes := 0
	var writes_ok := true
	var pframes := 0
	var blocked := 0
	while m.phase != m.P.OVER and guard < 30 * 60 * 12:
		await get_tree().process_frame
		guard += 1
		var dt := 1.0 / 30.0
		for p in m.all_players():
			var pl: Player = p
			var pos := pl.global_position
			if pl.written != Vector3.INF and not pos.is_equal_approx(pl.written):
				writes_ok = false
			if last.has(pl):
				var d: float = pos.distance_to(last[pl])
				worst_jump = maxf(worst_jump, d / (dt * pl.max_speed * 1.25))
				var dv: float = (pl.vel - (lastv[pl] as Vector3)).length()
				pframes += 1
				if pl.blocked:
					blocked += 1
				else:
					worst_acc = maxf(worst_acc, dv / (dt * maxf(Player.ACCEL, Player.DECEL) * 1.6))
			if pl == probe and last.has(pl):
				dist += pos.distance_to(last[pl])
			last[pl] = pos
			lastv[pl] = pl.vel
		steps += probe.steps_taken
		probe.steps_taken = 0
	var r: Dictionary = m.result()
	strikes = int(r.tstats[0].strikes) + int(r.tstats[1].strikes) + int(r.tstats[0].dives) + int(r.tstats[1].dives)
	check(m.phase == m.P.OVER, "Match (%s): an AI match reaches its end (%d frames)" % [rules, guard])
	check(int(r.winner) >= 0, "Match (%s): it has a winner (%s)" % [rules, JSON.stringify(r.count)])
	check(r.log.size() >= 3, "Match (%s): rayas are called (%d)" % [rules, r.log.size()])
	check(strikes >= r.log.size(), "Match (%s): the ball is struck back and forth (%d strikes and dives for %d rayas)" % [rules, strikes, r.log.size()])
	check(worst_jump <= 1.0, "Motion (%s): no player moves faster than he can run in a frame (worst %.2f of the limit)" % [rules, worst_jump])
	check(blocked * 200 < pframes, "Motion (%s): players seldom run into a line or wall (%d of %d frames)" % [rules, blocked, pframes])
	check(worst_acc <= 1.0, "Motion (%s): speed changes no faster than a player accelerates (worst %.2f of the limit)" % [rules, worst_acc])
	var stride := dist / maxf(1.0, float(steps))
	check(steps > 20 and stride > 0.6 and stride < 2.3, "Motion (%s): strides match the ground covered (%.2f m a step, %d steps)" % [rules, stride, steps])
	check(writes_ok, "Motion: one writer of position")
	check(Game.haptic_calls == buzzes, "Haptics: a match only the computer plays never buzzes the phone")
	m.queue_free()
	await frames(2)


# ---------------------------------------------------------------- the shared foundation (FoundationLink)

## The phone decides its first level: the owner's Galaxy A16 (Mali-G57 MC2 on the Helio G99 and Dimensity 6300,
## Mali-G68 MP2 on the Exynos 1330, 4 to 8 GB) and the other small GPUs start on Low; Low draws exactly what the beta
## draws, with or without the foundation in the build; on Medium and High (with the licensed clips) every player and
## judge is drawn by the foundation, where the game has him, his hip at the ball when it meets it, his gear on him,
## his planted feet still, the server not turning on the spot; replays are the ring's first, one a raya at most, and a
## tap passes them; and lowered to Low mid-match the game's own bodies come back.
func _foundation() -> void:
	var keep_g := int(Game.settings.graphics)
	for gpu in ["Mali-G57 MC2", "Mali-G68 MP2", "ARM Mali-G57", "Mali-G52 MC2", "PowerVR Rogue GE8320", "Adreno (TM) 610", "Adreno (TM) 506"]:
		for ram in [4.0, 6.0, 8.0]:
			check(Game.graphics_for(gpu, ram) == Game.GFX_LOW, "Phones: %s with %.0f GB starts on Low" % [gpu, ram])
	check(Game.graphics_for("Adreno (TM) 740", 8.0) == Game.GFX_MEDIUM and Game.graphics_for("Adreno (TM) 740", 3.5) == Game.GFX_LOW,
		"Phones: a big GPU starts on Medium, on Low under 4.5 GB")
	var have := WsgClips.available()
	# (Headless frames run at the test's fixed 30 a second: the game's own auto graphics would take a level off six
	# seconds into each match.)
	var keep_auto: bool = bool(Game.settings.get("auto_gfx", true))
	Game.settings.auto_gfx = false
	# Low: the same things drawn with the foundation in the build as without it (the beta's Low).
	Game.settings.graphics = Game.GFX_LOW
	FoundationLink.off = false
	await _drawn_list("village", "ulama")     # (the crowd's sheet made for Low first: a few frames)
	var with_f: Array = await _drawn_list("village", "ulama")
	var links := _link_count()
	FoundationLink.off = true
	var without: Array = await _drawn_list("village", "ulama")
	check(links == 0, "Foundation: Low links no body (%d)" % links)
	if with_f != without:
		for x in with_f:
			if not x in without:
				print("  only with the foundation: ", x)
		for x in without:
			if not x in with_f:
				print("  only without it: ", x)
	check(with_f.size() > 20 and with_f == without, "Foundation: Low draws the same %d things with the foundation in the build as without it" % with_f.size())
	await _toon_low(have)
	FoundationLink.off = false
	for g in [Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		await _foundation_match(g, have)
	await _foundation_lowered(have)
	await _replay_rules(have)
	await _step_down(have)
	FoundationLink.off = true
	Game.settings.graphics = keep_g
	Game.settings.auto_gfx = keep_auto


var _fm: Node


func _new_match(venue: String, rules: String, seed_: int, mode := "test", user := -1) -> Node:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "ESC" if rules == "ulama" else "PIS", "away": "LLA" if rules == "ulama" else "VAL", "venue": venue, "rules": rules,
		"user_team": user, "seed": seed_, "length": 3.0, "mode": mode, "difficulty": 2}
	add_child(m)
	_fm = m
	return m


func _link_count() -> int:
	var n := 0
	if is_instance_valid(_fm):
		for b in _fm._all_bodies():
			if (b as Body).link:
				n += 1
	return n


## Everything a seeded match draws after two seconds: each visible thing's kind, mesh, material and place.
func _drawn_list(venue: String, rules: String) -> Array:
	var m := _new_match(venue, rules, 4)
	await frames(60)
	var out := []
	for n in m.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var mesh_desc := ""
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			var me := (gi as MeshInstance3D).mesh
			mesh_desc = "%s %d %s" % [me.resource_path.get_file(), me.get_surface_count(), str(me.get_aabb().size.snapped(Vector3.ONE * 0.001))]
			if me.resource_path.contains("assets/people/player_"):
				mesh_desc = "a player's body"     # (which of the three a player wears is picked by chance in any build)
		var mat := gi.material_override
		var o := gi.global_position.snapped(Vector3.ONE * 0.001)
		out.append("%s|%s|%s|%s|%d" % [gi.get_class(), mesh_desc, mat.get_class() if mat else "-", str(o), gi.cast_shadow])
	out.sort()
	m.queue_free()
	await frames(2)
	return out


## Low (owner, 0.6.3: "this does not seem like it has the shared foundation", on the A16 that runs Low): the shared
## foundation's motion capture drives the game's own bodies (WsgToonDriver): every player has it, a player running
## somewhere is drawn by the capture, his strike, dive and serve by the game, and the match plays exactly as without it
## (the same rayas at the same moments, everyone in the same place). Without the licensed clips nobody has it.
func _toon_low(have: bool) -> void:
	var keep_g := int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_LOW
	WsgToonDriver.off = false
	FoundationLink.off = false
	var m := _new_match("village", "ulama", 9)
	await frames(2)
	var drivers := 0
	var captured := 0
	var own_on_action := true
	var n := 0
	while n < 30 * 40 and m.phase != m.P.OVER:
		await frames(1)
		n += 1
		drivers = 0
		for p in m.all_players():
			var pl: Player = p
			if pl.toon == null:
				continue
			drivers += 1
			if pl.vel.length() > 2.0 and pl.action == Player.A.NONE and pl.toon.override("thigh_l") < 0.01:
				captured += 1
			# (A celebration or a shrug is set by the match after the players are posed: drawn the next frame.)
			if (pl.action in [Player.A.STRIKE, Player.A.DIVE, Player.A.SERVE] or pl.holding) and pl.toon.override("hips") < 0.999:
				own_on_action = false
	var players: int = m.all_players().size()
	var played: Array = [m.log_rayas.duplicate(true), _places(m)]
	m.queue_free()
	await frames(2)
	if not have:
		check(drivers == 0, "Foundation (Low): without the licensed clips no body is driven by the capture (%d)" % drivers)
		Game.settings.graphics = keep_g
		return
	check(drivers == players, "Foundation (Low): every player's own body is driven by the motion capture (%d of %d)" % [drivers, players])
	check(captured > 100, "Foundation (Low): running, he is drawn by the capture (%d player-frames)" % captured)
	check(own_on_action, "Foundation (Low): striking, diving, serving, holding the ball, by the game's own pose at once")
	FoundationLink.off = true
	var m2 := _new_match("village", "ulama", 9)
	await frames(2)
	var n2 := 0
	while n2 < n and m2.phase != m2.P.OVER:
		await frames(1)
		n2 += 1
	check(m2.log_rayas == played[0] and _places(m2) == played[1],
		"Foundation (Low): the match plays exactly as without the capture (%d rayas)" % m2.log_rayas.size())
	m2.queue_free()
	await frames(2)
	FoundationLink.off = false
	Game.settings.graphics = keep_g


## A Medium or High match with the foundation: everyone linked, and what each drawn body does measured.
func _foundation_match(g: int, have: bool) -> void:
	var m := _new_match("village", "ulama", 9)
	await frames(2)
	var bodies: Array = m._all_bodies()
	var linked := _link_count()
	if not have:
		check(linked == 0, "Foundation (graphics %d): without the licensed clips nobody is linked, the game draws its own" % g)
		m.queue_free()
		await frames(2)
		return
	check(linked == bodies.size(), "Foundation (graphics %d): every player and judge is drawn by the foundation (%d of %d)" % [g, linked, bodies.size()])
	for b in bodies:
		var l: FoundationLink = (b as Body).link
		if l:
			l.measure = true
	var worst_place := 0.0
	var worst_hip := 0.0
	var hits := 0
	var worst_gear := 0.0
	var gear_off_game := 0.0
	var worst_slide := 0.0
	var slide_why := ""
	var slide_all := []
	var slides := 0
	var feet := {}
	var turned := 0.0
	var last_yaw := NAN
	var game_turned := 0.0
	var serve_turn := 0.0          # this serve's turning so far (he turns once to face across: a spin is far more)
	var serve_game_turn := 0.0
	var last_game_yaw := 0.0
	var modes := {}
	var n := 0
	while n < 30 * (60 if g == Game.GFX_MEDIUM else 30) and m.phase != m.P.OVER:
		await frames(1)
		if m.phase == m.P.REPLAY:
			feet.clear()
			continue
		n += 1
		for p in m.all_players():
			var pl: Player = p
			var l: FoundationLink = pl.body.link
			if l == null or int(l.last.get("frame", -9)) < Engine.get_process_frames() - 1:
				continue
			modes[l.mode] = int(modes.get(l.mode, 0)) + 1
			var hips: Vector3 = l.last.Hips
			worst_place = maxf(worst_place, Vector2(hips.x - pl.global_position.x, hips.z - pl.global_position.z).length())
			if pl.action in [Player.A.STRIKE, Player.A.DIVE] and pl.hit_done and not pl.has_meta("fv_hit"):
				pl.set_meta("fv_hit", true)
				hits += 1
				worst_hip = maxf(worst_hip, l.hip_gap(pl.action_side))
			elif pl.action == Player.A.NONE and pl.has_meta("fv_hit"):
				pl.remove_meta("fv_hit")
			var gp: Vector3 = l.last.get("gear:hips", Vector3.INF)
			if gp.is_finite():
				worst_gear = maxf(worst_gear, gp.distance_to(hips))
				if l.mode == "move" and float(l.last.pw) <= 0.0:
					gear_off_game = maxf(gear_off_game, gp.distance_to(pl.body.bone_world("hips")))
			# A planted foot under the motion capture: still from one pose to the next.
			for fi in 2:
				var k: String = "%s%d" % [pl.name, fi]
				var at: Vector3 = l.loco.planter.ankle_world[fi]
				var planted: bool = l.mode == "move" and float(l.last.w) <= 0.0 and float(l.last.pw) <= 0.0 \
					and float(l.loco.planter.contact[fi]) > 0.5 \
					and at.y < pl.global_position.y + (l.body.joints["LeftFoot"] as Vector3).y * pl.body.scale.x + 0.04
				if planted and feet.has(k):
					# (Per frame: a far player is posed every second frame.)
					var gap := maxf(1.0, float(int(l.last.frame) - int(feet[k][1])))
					var sl := Vector2(at.x - feet[k][0].x, at.z - feet[k][0].z).length() / gap
					if sl > worst_slide:
						slide_why = "%s state %d speed %.2f gap %d frame %d" % [pl.name, l.loco.state, pl.vel.length(), gap, n]
					worst_slide = maxf(worst_slide, sl)
					slide_all.append(sl * 30.0 * 100.0)
					slides += 1
				if planted:
					feet[k] = [at, int(l.last.frame)]
				else:
					feet.erase(k)
		if m.phase == m.P.SERVE and m.ball.held and m.server and m.server.body.link:
			var y: float = m.server.body.link.body.global_transform.basis.get_euler().y
			if not is_nan(last_yaw):
				serve_turn += absf(angle_difference(last_yaw, y))
				serve_game_turn += absf(angle_difference(last_game_yaw, m.server.yaw))
				turned = maxf(turned, serve_turn)
				game_turned = maxf(game_turned, serve_game_turn)
			last_yaw = y
			last_game_yaw = m.server.yaw
		else:
			last_yaw = NAN
			serve_turn = 0.0
			serve_game_turn = 0.0
	check(worst_place < 0.4, "Foundation (graphics %d): the drawn bodies are where their players are (worst %.2f m off)" % [g, worst_place])
	check(hits >= 3 and worst_hip < 0.05, "Foundation (graphics %d): at contact the drawn hip is where the game's hip meets the ball (%d strikes and dives, worst %.3f m)" % [g, hits, worst_hip])
	check(worst_gear > 0.0 and worst_gear < 0.2, "Foundation (graphics %d): the faja and chimali stay on the drawn hips (worst %.3f m from them)" % [g, worst_gear])
	check(int(modes.get("move", 0)) > 0 and gear_off_game > 0.02, "Foundation (graphics %d): under the motion capture the gear follows the drawn body, not the game's (%.3f m apart)" % [g, gear_off_game])
	# (The foundation's own measure, tests/loco_test there: a planted foot's slide on average under 8 cm/s; and never
	# 5 cm in a frame - a foot drawn after a body that outran its leg, the game's players speeding up and stopping
	# harder than the capture's runners (Sepak Takraw's walkers kept under 3). The 90th percentile is reported.)
	slide_all.sort()
	var mean_s: float = slide_all.reduce(func(x, y): return x + y, 0.0) / maxf(1.0, slide_all.size())
	var p90: float = slide_all[int(slide_all.size() * 0.9)] if not slide_all.is_empty() else 0.0
	check(slides > 50 and mean_s < 8.0 and worst_slide < 0.05,
		"Foundation (graphics %d): planted feet under the motion capture do not slide (%d poses: %.1f cm/s on average, %.1f at the 90th percentile; worst %.3f m a frame: %s)" % [g, slides, mean_s, p90, worst_slide, slide_why])
	check(turned < 4.0, "Foundation (graphics %d): the server holding the ball does not spin on the spot (drawn: turned %.1f rad at most in a serve; the game's %.1f)" % [g, turned, game_turned])
	var seen := {}
	var once := true
	var others := 0
	var gap_ok := true
	var last_c := -INF
	for r in m.replays:
		if seen.has(r[0]):
			once = false
		seen[r[0]] = true
		check(String(r[1]) in m.REPLAY_PRIORITY, "Foundation: a replay shows a moment of the list (%s)" % r[1])
		if String(r[1]) != "ring":
			others += 1
			gap_ok = gap_ok and float(r[2]) - last_c >= m.REPLAY_GAP
			last_c = float(r[2])
	check(once and others <= m.OTHER_REPLAYS and gap_ok, "Foundation (graphics %d): one replay a raya at most, three besides the ring's, 90 s apart (%s)" % [g, m.replays])
	var played: Array = [m.log_rayas.duplicate(true), _places(m)]
	var shown: int = m.replays.size()
	m.queue_free()
	await frames(2)
	if g == Game.GFX_MEDIUM:
		# The same match without the foundation, for as many frames of play: the same rayas at the same moments, the
		# players in the same places (the drawn bodies and their replays change nothing the game does).
		FoundationLink.off = true
		var m2 := _new_match("village", "ulama", 9)
		await frames(2)
		var n2 := 0
		while n2 < n and m2.phase != m2.P.OVER:
			await frames(1)
			if m2.phase != m2.P.REPLAY:
				n2 += 1
		check(m2.log_rayas == played[0] and _places(m2) == played[1],
			"Foundation: the match plays exactly as without the foundation, %d replays and all (%d rayas: %s against %s)" % [shown, m2.log_rayas.size(), played[0].slice(-2), m2.log_rayas.slice(-2)])
		m2.queue_free()
		await frames(2)
		FoundationLink.off = false


## Every player's place, to the millimetre.
func _places(m: Node) -> Array:
	var out := []
	for p in m.all_players():
		out.append((p as Player).global_position.snapped(Vector3.ONE * 0.001))
	return out


## Lowered to Low mid-match (WsgAutoTier's step): the game's own bodies are drawn again as Low draws them.
func _foundation_lowered(have: bool) -> void:
	Game.settings.graphics = Game.GFX_MEDIUM
	var m := _new_match("stone", "classic", 5)
	for b in m._all_bodies():
		if (b as Body).link:
			(b as Body).link.measure = true
	var pad := 0.0
	var wrap := 0.0
	var parts := 0
	for i in 90:
		await frames(1)
		for p in m.all_players():
			var l: FoundationLink = (p as Player).body.link
			if l and l.last.has("gear:shin_r"):
				parts += 1
				pad = maxf(pad, (l.last["gear:shin_r"] as Vector3).distance_to(l.last["RightLeg@"].origin))
				wrap = maxf(wrap, (l.last["gear:forearm_r"] as Vector3).distance_to(l.last.RightHand))
	check(not have or (parts > 100 and pad < 0.08 and wrap < 0.06),
		"Foundation: the classic court's knee pad and wrist wrap stay on the drawn knee and wrist (%d poses, %.3f and %.3f m)" % [parts, pad, wrap])
	var before := _link_count()
	var was_linked: Array = m._all_bodies().filter(func(b): return (b as Body).link != null)
	m.lower_graphics()
	await frames(5)
	var ok := true
	for b in m._all_bodies():
		var bd: Body = b
		if not bd in was_linked:
			# (Never drawn by the foundation - a build without the licensed clips: as the beta lowers it, unchanged.)
			ok = ok and bd.rigged != null and bd.mesh_instance.visible
			continue
		if bd.link != null or not bd.mesh_instance.visible or bd.rigged == null or not bd.rigged.file.begins_with(String(bd.look.get("model", "?"))):
			ok = false
		elif bd.rigged.material.get_shader_parameter("albedo_tex").resource_path.ends_with("_2k.jpg"):
			ok = false
	check(int(Game.settings.graphics) == Game.GFX_LOW and m.wsg_replay == null and _link_count() == 0 and ok,
		"Foundation: lowered to Low mid-match, the game's own bodies are back as Low draws them (%d were linked)" % before)
	check(not have or before == m._all_bodies().size(), "Foundation: the stone court's bodies were all linked on Medium (%d)" % before)
	m.queue_free()
	await frames(2)


## Replays: which moment a raya earns, most wanted first (the ring before all; the rest only where the foundation
## draws); and a tap anywhere passes one.
func _replay_rules(have: bool) -> void:
	Game.settings.graphics = Game.GFX_MEDIUM
	var m := _new_match("stone", "classic", 5)
	await frames(30)
	m._rec_t = 10.0
	m.clock = 200.0
	m.limit_s = 0.0      # (no time limit: the last-raya rule is checked below)
	var dive_won := [["strike", 8.0, Vector3.ZERO, 1], ["dive", 8.5, Vector3.ZERO, 0]]
	var other := func(k: String) -> String: return k if have else ""
	m._rally_events = dive_won
	m.rally = 9
	check(m.replay_kind("ring", "add", 0) == "ring", "Replays: the ring is always replayed")
	check(m.replay_kind("dead", "win", 0) == other.call("win"), "Replays: the raya that wins the match first (%s)" % m.replay_kind("dead", "win", 0))
	check(m.replay_kind("dead", "urria", 0) == other.call("urria"), "Replays: then a raya that wipes a count in urria (%s)" % m.replay_kind("dead", "urria", 0))
	check(m.replay_kind("dead", "add", 0) == other.call("dive"), "Replays: then a raya won off a dive save (%s)" % m.replay_kind("dead", "add", 0))
	check(m.replay_kind("dead", "add", 1) == other.call("rally"), "Replays: or after a rally of 8 strikes (%s)" % m.replay_kind("dead", "add", 1))
	m.rally = 3
	m._rally_events = [["dive", 8.5, Vector3.ZERO, 1], ["strike", 9.5, Vector3.ZERO, 0]]
	check(m.replay_kind("dead", "add", 1) == "" and m.replay_kind("out", "add", 0, true) == "" and m.replay_kind("end", "cancel", 0) == "",
		"Replays: never a plain dead ball, out or fault")
	m.rally = 9
	check(m.replay_kind("touch", "add", 1, true) == "", "Replays: a fault after a long rally earns none")
	# Spacing and the cap (the ring exempt from both).
	m._others_shown = 1
	m._last_replay_clock = 150.0
	m._rally_events = dive_won
	check(m.replay_kind("dead", "add", 0) == "" and m.replay_kind("dead", "win", 0) == "" and m.replay_kind("ring", "add", 0) == "ring",
		"Replays: at least 90 s of play between them, the ring exempt")
	m._last_replay_clock = 100.0
	check(m.replay_kind("dead", "add", 0) == other.call("dive"), "Replays: after 90 s of play another may come")
	m._others_shown = 3
	check(m.replay_kind("dead", "win", 0) == "" and m.replay_kind("ring", "add", 0) == "ring", "Replays: at most three a match besides the ring's")
	# The last raya before the result (time up): only the one that wins the match.
	m._others_shown = 0
	m._last_replay_clock = -INF
	m.limit_s = 180.0
	check(m.replay_kind("dead", "add", 0) == "" and m.replay_kind("dead", "win", 0) == other.call("win"),
		"Replays: none in the last raya before the result, unless it wins the match")
	m.queue_free()
	await frames(2)
	# A tap passes the ring's replay (Low: the beta's replay, the same rule).
	Game.settings.graphics = Game.GFX_LOW
	Game.start_match({"home": "PIS", "away": "VAL", "venue": "stone", "rules": "classic", "user_team": 0, "seed": 5,
		"mode": "quick", "length": 3.0, "difficulty": 1})
	var q: Node = Game.current
	var n := 0
	var into := 0
	while n < 30 * 60 and into < 20:
		await frames(1)
		n += 1
		into = into + 1 if q.phase == q.P.LIVE else 0
		if q.phase == q.P.SERVE and "SERVE" in q.hud.touch.ids and n % 30 == 0:
			q.hud.touch._fire("SERVE")
	q._award(0, "ring", false, null)
	n = 0
	while n < 30 * 10 and q.phase != q.P.REPLAY:
		await frames(1)
		n += 1
	var was: bool = q.phase == q.P.REPLAY
	await frames(10)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = Vector2(900, 300)
	tap.global_position = tap.position
	tap.pressed = true
	Input.parse_input_event(tap)
	await frames(2)
	var up := tap.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await frames(3)
	var gone: bool = not is_instance_valid(q) or q.phase != q.P.REPLAY
	check(was and gone, "Replays: a tap anywhere passes the replay (replaying %s, passed %s)" % [was, gone])
	Game.goto_menu()
	await frames(3)


## The automatic step-down when a match runs slow (slow frames fed by hand): from Medium the game's own first-seconds
## check takes it to Low and the game's own bodies come back; from High that check takes it to Medium (still drawn by
## the foundation, no shadows) and WsgAutoTier then to Low, the game's bodies back; Low stays exactly as it is.
func _step_down(have: bool) -> void:
	Game.settings.auto_gfx = true
	var keep_fps: int = int(Game.settings.fps)
	Game.settings.fps = Game.FPS_SMOOTH
	for start in [Game.GFX_MEDIUM, Game.GFX_HIGH, Game.GFX_LOW]:
		Game.settings.graphics = start
		var m := _new_match("village", "ulama", 9)
		m.auto_headless = true
		var n := 0
		while m.phase == m.P.INTRO and n < 300:
			await frames(1)
			n += 1
		var before: Array = await _drawn_now(m) if start == Game.GFX_LOW else []
		var linked := _link_count()
		var steps := []
		var shown_off := true
		for i in 20 * 30:      # 30 s of frames at 20 a second
			var g0 := int(Game.settings.graphics)
			m._check_frame_rate(0.05, 0.05)
			if int(Game.settings.graphics) != g0:
				steps.append([snappedf(i * 0.05, 0.05), int(Game.settings.graphics)])
				if int(Game.settings.graphics) == Game.GFX_MEDIUM:
					for b in m._all_bodies():
						var l: FoundationLink = (b as Body).link
						if l and l.body.mesh_instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
							shown_off = false
		await frames(3)
		var back := true
		for b in m._all_bodies():
			var bd: Body = b
			back = back and bd.link == null and bd.rigged != null and bd.mesh_instance.visible
		match start:
			Game.GFX_MEDIUM:
				check(steps.size() == 1 and steps[0][1] == Game.GFX_LOW and back and m.wsg_replay == null,
					"Auto graphics: a slow match on Medium steps down to Low at once (%s), the game's own bodies back (%d were linked)" % [steps, linked])
			Game.GFX_HIGH:
				check(steps.size() == 2 and steps[0][1] == Game.GFX_MEDIUM and steps[1][1] == Game.GFX_LOW and back and shown_off,
					"Auto graphics: a slow match on High steps to Medium (the game's check, no shadows on the drawn bodies) and on to Low (WsgAutoTier), the game's own bodies back (%s, %d were linked)" % [steps, linked])
			Game.GFX_LOW:
				var after: Array = await _drawn_now(m)
				check(steps.is_empty() and int(Game.settings.graphics) == Game.GFX_LOW and linked == 0 and after.size() == before.size(),
					"Auto graphics: Low stays as it is (%d things drawn before and after)" % after.size())
		check(not have or start == Game.GFX_LOW or linked == m._all_bodies().size(), "Auto graphics: everyone was linked on graphics %d first" % start)
		m.queue_free()
		await frames(2)
	Game.settings.fps = keep_fps
	Game.settings.auto_gfx = false


func _drawn_now(m: Node) -> Array:
	await frames(1)
	var out := []
	for n in m.find_children("*", "GeometryInstance3D", true, false):
		if (n as GeometryInstance3D).is_visible_in_tree():
			out.append(n.get_class())
	return out
