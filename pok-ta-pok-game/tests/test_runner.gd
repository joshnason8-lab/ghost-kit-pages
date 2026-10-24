extends Node
## The test suite CI runs before building (headless):
##   godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
## The rules one by one (Rules, Court, Ball: docs/RULES.md numbers them); every screen opens in every language; every
## scrolling page scrolls when dragged on its text; the cup plays through to its champion and saves; simulated results
## are counts ulama can have; the crowd faces the court at every venue and level; an AI match plays to its end; and the
## movement audit: one writer per player, nothing jumps in a frame, strides match speed.
## Exits 1 on any failure.

const SCREENS := ["res://ui/main_menu.gd", "res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
	"res://ui/licences_screen.gd", "res://ui/buttons_screen.gd", "res://ui/cup_screen.gd"]

var failures := 0
var checks := 0


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	get_tree().root.size = Vector2i(1280, 720)
	await frames(1)
	var keep: Dictionary = Game.settings.duplicate(true)
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
	_cup()
	_sim()
	await _crowd_faces()
	await _match_and_motion("village", "ulama")
	await _match_and_motion("stone", "classic")
	Game.settings = keep
	Game.delete_cup()
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
	check(bounced and top > 0.06 and top < 0.25, "Ball: dropped from the hip onto earth it comes back only %.2f m" % top)
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
	check(top > 0.2 and top < 0.45, "Ball: on stone it bounces higher (%.2f m)" % top)
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


## Each scrolling page scrolls when a drag starts on its words (Kabaddi's How to Play did not).
func _scroll_on_text() -> void:
	Game.new_cup("ESC")
	for path in ["res://ui/howto_screen.gd", "res://ui/licences_screen.gd", "res://ui/settings_screen.gd", "res://ui/quick_setup.gd",
			"res://ui/result_screen.gd", "res://ui/cup_screen.gd"]:
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
				var s := Sim.play(String(f.home), String(f.away), rules)
				c.record_user_result({"home": f.home, "away": f.away, "winner": s.winner, "count": s.count})
				var saved := Cup.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
				check(saved.round == c.round and saved.team == c.team and saved.draw.size() == c.draw.size(), "Cup: it saves and loads")
			check(c.done() and c.champion != "", "Cup (%s, %s): played to a champion (%s)" % [rules, team, c.champion])
			check(c.history.size() == 3, "Cup: three rounds")


func _sim() -> void:
	var wins := [0, 0]
	var lens := []
	for i in 60:
		var s := Sim.play("ESC", "LLA", Rules.ULAMA, 100 + i)
		wins[int(s.winner)] += 1
		lens.append(int(s.rayas))
		check(int(s.count.rayas) == 8 and int(s.count.holder) == int(s.winner), "Sim: a simulated ulama game ends on eight rayas")
	lens.sort()
	check(wins[0] > 5 and wins[1] > 5, "Sim: either town can win (%s)" % str(wins))
	check(int(lens[lens.size() / 2]) > 12, "Sim: the count swings: a median of %d rayas to reach eight" % int(lens[lens.size() / 2]))


# ---------------------------------------------------------------- the crowd

## Every spectator, at every venue and graphics level, faces the court: dot(facing, toward the centre) > 0.7 (five of
## the six earlier games shipped this wrong). And the shader draws them from behind when the camera is behind them.
func _crowd_faces() -> void:
	var keep := int(Game.settings.graphics)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for id in DB.VENUE_ORDER:
			var v := Venue.new()
			add_child(v)
			v.build(id, Court.new(String(DB.venue(id).rules)))
			var worst := 1.0
			var n := v.crowd.spots.size()
			for i in n:
				var p: Vector3 = v.crowd.spots[i]
				var to := Vector3(-p.x, 0, -p.z).normalized()
				worst = minf(worst, (v.crowd.facings[i] as Vector3).dot(to))
				var t: Transform3D = v.crowd.xforms[i]
				var f := Vector3(t.basis.z.x, 0, t.basis.z.z).normalized()
				worst = minf(worst, f.dot(to))
			check(n > 40, "Crowd: %s at graphics %d has people (%d)" % [id, g, n])
			check(worst > 0.7, "Crowd: everyone at %s (graphics %d) faces the court (worst %.2f)" % [id, g, worst])
			if n > 0:
				var p0: Vector3 = v.crowd.spots[0]
				var f0: Vector3 = v.crowd.facings[0]
				check(Crowd.seen_from_behind(p0, f0, p0 - f0 * 10.0 + Vector3(0, 5, 0)) and not Crowd.seen_from_behind(p0, f0, p0 + f0 * 10.0),
					"Crowd: drawn from behind from behind, from the front from the front (%s)" % id)
			v.queue_free()
			await frames(1)
	Game.settings.graphics = keep


# ---------------------------------------------------------------- a match

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
