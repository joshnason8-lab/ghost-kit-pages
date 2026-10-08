extends Node
## Headless smoke test. Run:
##   godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
## Exits with code 0 if every check passed.

var failures: Array[String] = []
var _match_done := false
var _match_result := {}


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	await _run()


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures.append(what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _scripts(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_scripts(dir.path_join(sub), out)


func _run() -> void:
	# 1. Every script compiles.
	var paths := []
	for dir in ["res://autoload", "res://game", "res://ui"]:
		_scripts(dir, paths)
	for p in paths:
		var s: Script = load(p)
		check(s != null and s.can_instantiate(), "compiles " + p)

	# 2. Data.
	check(DB.league_ids.size() == 12, "12 league teams")
	check(DB.country_ids.size() == 12, "12 countries")
	# Move ratings and tendencies: every player has them, and they vary.
	var sigs := {}
	var styles := {}
	for id in DB.league_ids:
		for p in DB.team(id).squad:
			sigs[DB.signature(p)] = sigs.get(DB.signature(p), 0) + 1
			styles[DB.def_signature(p)] = styles.get(DB.def_signature(p), 0) + 1
	print("      signature moves %s, signature tackles %s" % [str(sigs), str(styles)])
	check(sigs.size() == DB.MOVES.size(), "every move is someone's signature")
	check(styles.size() == DB.STYLES.size(), "every defensive skill is someone's signature")
	check(DB.HOLDS.has(DB.style(DB.team("MUM").squad[6])), "default tackle is a hold")
	var p0: Dictionary = DB.team("MUM").squad[0].duplicate(true)
	p0.erase("moves")
	check(DB.moves(p0) == DB.team("MUM").squad[0].moves, "move ratings are stable for a player")
	for id in DB.teams:
		check(DB.starting_seven(DB.team(id).squad).size() == 7, "starting seven for " + id)

	# 3. Translations load for every language.
	for pair in Game.LANGUAGES:
		TranslationServer.set_locale(pair[0])
		var t := tr("MENU_CAREER")
		check(t != "MENU_CAREER" and t != "", "translation %s: %s" % [pair[0], t])
	TranslationServer.set_locale("en")

	# 4. Screens open.
	for scr in ["res://ui/main_menu.gd", "res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd", "res://ui/cup_screen.gd", "res://ui/career_hub.gd", "res://ui/create_player.gd"]:
		var n := Game.show_screen(scr)
		await frames(3)
		check(is_instance_valid(n), "screen " + scr)

	# 5. Nations Cup plays out.
	Game.delete_cup()
	var cup = Game.new_cup("IND")
	check(cup.fixtures.size() == 12, "cup has 12 group fixtures")
	cup.sim_everything_left()
	check(cup.stage == "done" and cup.champion != "", "cup produces a champion: " + String(cup.champion))
	Game.save_cup()
	Game.cup = null
	check(Game.get_cup() != null and Game.get_cup().champion == cup.champion, "cup save round-trips")
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(3)
	Game.delete_cup()

	# 6. Career: auction, a full season, next season.
	Game.delete_career()
	var c = Game.new_career({"name": "Test Raider", "state": "STATE_HARYANA", "role": "raider", "skin": 2, "hair": 0, "build": 1})
	var eng: AuctionEngine = c.make_auction()
	check(eng.lots.size() == 25, "career auction has 25 lots")
	eng.resolve_all(false)
	var mine_found := false
	for lot in eng.lots:
		if lot.mine:
			mine_found = true
	check(mine_found, "your lot is in the auction")
	c.finish_auction(eng)
	check(c.team != "" and c.phase == "season", "career signed with " + String(c.team))
	check(c.fixtures.size() == 66, "league has 66 fixtures")
	var guard2 := 0
	while c.phase != "over" and guard2 < 40:
		guard2 += 1
		if c.next_user_fixture() == null:
			c._advance()
		else:
			c.simulate_user_match()
	check(c.phase == "over", "season completes (champion %s)" % c.champion())
	check(c.skill_points > 0, "skill points earned: %d" % c.skill_points)
	check(c.train("speed"), "training spends a point")
	Game.save_career()
	Game.career = null
	check(Game.get_career() != null and Game.get_career().season == 1, "career save round-trips")
	Game.get_career().next_season()
	check(Game.get_career().phase == "auction", "next season starts at auction")
	Game.show_screen("res://ui/career_hub.gd")
	await frames(3)
	Game.show_screen("res://ui/auction_screen.gd", {"mode": "career"})
	await frames(30)
	Game.delete_career()

	# 6b. League Season: owner auction with paddles and FBM, league, playoffs, champion.
	Game.delete_season()
	var se = Game.new_season("PAT")
	var oe: AuctionEngine = se.make_auction()
	check(oe.lots.size() == 34, "owner auction has 34 lots")
	check(oe.lots[0].cat == "A" and oe.lots[-1].cat == "NYP", "lots run A first, young players last")
	# The user bids on the first lot, then lets the rest play out.
	oe.open_lot()
	var first_bid := oe.place_bid("PAT")
	check(not first_bid.is_empty() and oe.leader == "PAT", "you can raise the paddle")
	var spent0: float = oe.teams.PAT.purse
	var guard3 := 0
	while oe.stage != "done" and guard3 < 400:
		guard3 += 1
		if oe.stage == "fbm_offer":
			oe.answer_fbm(false)
			break
		oe.step(0.5)
	check(oe.current().status in ["sold", "unsold"], "first lot hammered: %s" % String(oe.current().sold_to))
	oe.next_lot()
	oe.resolve_all(false)
	var sold := 0
	for lot in oe.lots:
		if lot.status == "sold":
			sold += 1
	check(sold >= 15, "most lots sell (%d), record %s" % [sold, Game.fmt_money(oe.record)])
	se.finish_auction(oe)
	var ok_sizes := true
	for id in se.squads:
		if se.squads[id].size() < 10 or se.squads[id].size() > 12:
			ok_sizes = false
	check(ok_sizes, "every franchise ends with 10-12 players")
	check(se.phase == "league" and se.fixtures.size() == 66, "league fixtures made")
	var guard4 := 0
	while se.phase != "done" and guard4 < 60:
		guard4 += 1
		if se.next_user_fixture() == null:
			se._advance()
		else:
			se.simulate_user_match()
	var stages := {}
	for f in se.fixtures:
		stages[f.stage] = stages.get(f.stage, 0) + 1
	check(se.phase == "done" and se.champion != "", "season champion: %s" % se.champion)
	check(stages.get("eliminator", 0) == 2 and stages.get("semi", 0) == 2 and stages.get("final", 0) == 1, "playoffs: 2 eliminators, 2 semis, final")
	Game.save_season()
	Game.season = null
	check(Game.get_season() != null and Game.get_season().champion == se.champion, "season save round-trips")
	Game.show_screen("res://ui/season_hub.gd")
	await frames(3)
	Game.show_screen("res://ui/trophy_screen.gd", {"team": "PAT", "title": "TEST", "back": "res://ui/main_menu.gd"})
	await frames(10)
	Game.get_season().next_year()
	Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"})
	await frames(40)
	Game.delete_season()
	Game.show_screen("res://ui/tutorial_menu.gd")
	await frames(3)
	check(Flags.texture("IND").get_width() == 60, "flags render")

	# 7. Every ground builds.
	for a in DB.ARENAS:
		var ar := Arena.new()
		add_child(ar)
		ar.build(a.id, Color.RED, Color.BLUE, "TEST")
		await frames(2)
		check(ar.get_child_count() > 5, "arena builds: " + a.id)
		ar.queue_free()

	# 8. Captured motion clips load and play on an athlete.
	var clip := MocapClip.load_file("res://tests/fixtures/walk_clip.json")
	check(clip != null and clip.frames.size() > 10, "mocap clip loads")
	if clip:
		var smp := clip.sample(1.3, true)
		check(smp.has("hip_l") and smp.has("knee_r") and smp.has("height"), "mocap clip samples joints")
		var a := Athlete.new()
		a.setup(DB.team("MUM").squad[0], 0, Color.TEAL, Color.WHITE, false)
		add_child(a)
		a.model.play_clip(clip, true)
		await frames(20)
		check(a.model.clip_weight > 0.5, "athlete plays mocap clip")
		a.queue_free()

	# 8a. Realistic rigged body follows the placeholder skeleton.
	if RiggedBody.available():
		Game.settings.models = 1
		var ra := Athlete.new()
		ra.setup(DB.team("MUM").squad[0], 0, Color.TEAL, Color.WHITE, true)
		add_child(ra)
		check(ra.model.rig != null and ra.model.rig.skeleton.get_bone_count() == 17, "rigged body built with 17 bones")
		ra.set_state("dubki", 1000.0)
		ra.st_t = 500.0
		await frames(20)
		var q: Quaternion = ra.model.rig.skeleton.get_bone_pose_rotation(ra.model.rig._bone["thigh_l"])
		check(not q.is_equal_approx(Quaternion.IDENTITY), "rigged body bends with the pose")
		ra.queue_free()

	# 8b. Cant, chain, reactions: drive a user match by hand.
	Game.start_match({"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "control": "all", "length": 0, "difficulty": 1, "first_raider": 0, "autoplay_no_report": true})
	var um: Node = Game.current
	var g5 := 0
	while um.phase != "raid" and g5 < 600:
		await get_tree().process_frame
		g5 += 1
	check(um.raid.cant_tap, "your raid uses the tap cant")
	# Walk into their half without chanting: breath drains and the cant is lost.
	var g6 := 0
	while um.phase == "raid" and g6 < 30 * 25:
		um.raider.position.z = move_toward(um.raider.position.z, -1.5, 0.05)
		await get_tree().process_frame
		g6 += 1
	check(um.raid_log.size() > 0 and um.raid_log[-1].kind == "cant", "silent raider loses the cant (%s)" % (um.raid_log[-1].kind if um.raid_log.size() > 0 else "none"))
	# Next raid is the CPU's: link a chain.
	var g7 := 0
	while not (um.phase == "raid" and um.raiding == 1) and g7 < 900:
		await get_tree().process_frame
		g7 += 1
	if um.controlled:
		um._toggle_chain(um.controlled)
		check(um.controlled.chain_partner != null, "chain links your defender to a team-mate")
		await frames(10)
		um._toggle_chain(um.controlled)
		check(um.controlled.chain_partner == null, "chain unlinks")
	um.queue_free()
	await frames(3)

	# 8c. Tutorial lesson starts and shows its objective.
	Game.start_match(Tutorial.match_config("cant"))
	await frames(260)
	var tm: Node = Game.current
	check(tm.tutorial != null and tm.hud.objective.visible, "tutorial lesson runs")
	tm.tutorial_event.emit("cant")
	await frames(2)
	Sfx.stop_all()

	# 8d. Raid moves: dubki under linked hands, lion jump over an ankle dive, back kick.
	Game.start_match(Tutorial.match_config("dubki"))
	var mm: Node = Game.current
	var g8 := 0
	while mm.phase != "raid" and g8 < 900:
		await get_tree().process_frame
		g8 += 1
	check(mm.phase == "raid", "move lesson reaches a raid")
	if mm.phase == "raid":
		mm.set_process(false)
		mm.rng.seed = 7
		var ids := []
		mm.controls.set_context("raid")
		for b in mm.controls._buttons():
			ids.append(b.id)
		check(ids.has("dubki") and ids.has("jump") and ids.has("kick"), "raid buttons include Kick, Dubki and Lion jump")
		var rd: Athlete = mm.raider
		var defs: Array = mm.defenders()
		var d0: Athlete = defs[0]
		var d1: Athlete = defs[1]
		var opp: int = 1 - mm.raiding
		for d in defs:
			mm._unchain(d)
			d.set_state("ready")
			d.position = mm.pos_in(opp, 4.0 * (defs.find(d) - 3), 6.0)
		d0.position = mm.pos_in(opp, -0.5, 2.5)
		d1.position = mm.pos_in(opp, 0.5, 2.5)
		mm._link(d0, d1)
		rd.moves["dubki"] = 99
		rd.moves["lion"] = 99
		rd.position = mm.pos_in(opp, 0.0, 2.5)
		rd.set_state("dubki", mm.DUBKI_TIME)
		mm.raid.cross_cd = 0.0
		mm._check_chain_cross()
		check(mm.raid.moves.has("dubki"), "dubki ducks under linked hands")
		# Without the dubki, linked hands catch or come apart.
		mm.config.passive = false
		mm.raid.cross_cd = 0.0
		rd.set_state("raid")
		mm._check_chain_cross()
		check(d0.chain_partner == null, "running into a chain gets you caught or breaks it")
		for h in mm.raid.holders.duplicate():
			mm._release(h, false)
		# Lion jump over a dive at the ankles.
		d0.tackle_kind = "ankle"
		d0.position = rd.position + Vector3(0.3, 0, 0)
		d0.set_state("dive", mm.DIVE_TIME)
		rd.set_state("jump", mm.JUMP_TIME)
		rd.st_t = mm.JUMP_TIME * 0.4
		mm._check_contacts(mm.defenders())
		check(d0.state == "recover" and mm.raid.holders.is_empty(), "lion jump clears an ankle dive")
		check(mm.raid.moves.has("lion"), "lion jump is counted")
		# Back kick at a defender behind.
		rd.set_state("raid")
		rd.cooldown = 0.0
		rd.facing = Vector3(0, 0, -mm.side(mm.raiding))
		d1.touched = false
		d1.set_state("ready")
		d1.position = rd.position - rd.facing * 1.2
		mm.raid.touch_hit = false
		mm._raider_kick()
		check(rd.state == "backkick", "Kick at a defender behind is a back kick")
		rd.st_t = mm.BACKKICK_TIME * 0.45
		mm._check_contacts(mm.defenders())
		check(d1.touched and mm.raid.moves.has("backkick"), "back kick touches him")
		# Waist hold plucks a jumping raider out of the air.
		rd.st_t = 99.0
		rd.set_state("jump", mm.JUMP_TIME)
		rd.st_t = mm.JUMP_TIME * 0.4
		var dw: Athlete = defs[2]
		dw.tackle_kind = "waist"
		dw.dmoves["waist"] = 95
		dw.position = rd.position + Vector3(0.3, 0, 0)
		dw.set_state("dive", mm.DIVE_TIME)
		var caught := 0
		for k in 20:
			for h in mm.raid.holders.duplicate():
				mm._release(h, false)
			dw.position = rd.position + Vector3(0.3, 0, 0)
			dw.set_state("dive", mm.DIVE_TIME)
			rd.set_state("jump", mm.JUMP_TIME)
			rd.st_t = mm.JUMP_TIME * 0.4
			mm._check_contacts(mm.defenders())
			if mm.raid.holders.has(dw):
				caught += 1
		check(caught >= 12, "waist hold catches a lion jump most of the time (%d/20)" % caught)
		for h in mm.raid.holders.duplicate():
			mm._release(h, false)
		# Dash near the side line shoves him out (no struggle yet, so the lobby is out).
		mm.raid.struggle = false
		rd.set_state("raid")
		rd.position = mm.pos_in(opp, 4.3 * mm.side(opp), 2.5)
		rd.position.x = 4.3
		var dd: Athlete = defs[3]
		dd.position = rd.position + Vector3(-0.5, 0, 0)
		dd.dmoves["dash"] = 95
		dd.cooldown = 0.0
		dd.set_state("ready")
		mm._defender_tackle(dd, "dash")
		mm._check_contacts(mm.defenders())
		check(rd.state == "shoved", "dash shoves the raider")
		check(mm.raid.dashed_by == dd and rd.dive_dir.x > 0.5, "dash pushes toward the near side line")
		check(mm.defend_hint() == "dash" or mm._line_gap() < 1.2, "dash is the hint near the line")
	mm.queue_free()
	await frames(3)
	Sfx.stop_all()

	# 9. A full AI-vs-AI match, quick length, knockout rules.
	var m: Node = null
	Game.start_match({"home": "MUM", "away": "DEL", "arena": "village", "mode": "quick", "autoplay": true, "length": 0, "difficulty": 1, "knockout": true})
	m = Game.current
	m.finished.connect(func(r):
		_match_done = true
		_match_result = r)
	var n_frames := 0
	var raids := 0
	var last_phase := ""
	var counted := {}
	m.tree_exiting.connect(func(): pass)
	while not _match_done and n_frames < 30 * 60 * 12:
		await get_tree().process_frame
		n_frames += 1
		if is_instance_valid(m) and m.phase != last_phase:
			last_phase = m.phase
			if last_phase == "raid":
				raids += 1
	check(_match_done, "match finishes (%d raids, %d frames)" % [raids, n_frames])
	if _match_done:
		var s: Array = _match_result.score
		print("      score %d - %d, breakdown %s" % [s[0], s[1], str(_match_result.breakdown)])
		check(s[0] + s[1] > 5, "match produces points")
		check(s[0] != s[1], "knockout match has a winner")
		var kinds := {}
		var tot_t := 0.0
		for r in _match_result.raid_log:
			var k: String = r.kind
			if k == "return":
				k = "success" if r.raid_pts > 0 else ("empty" if not r.raider_out else "out_" + ("baulk/dod"))
			kinds[k] = kinds.get(k, 0) + 1
			tot_t += float(r.t)
		print("      raid outcomes %s, avg raid %.1fs" % [str(kinds), tot_t / maxf(1, _match_result.raid_log.size())])
		var used := {}
		for r in _match_result.raid_log:
			for mv in r.get("moves", []):
				used[mv] = used.get(mv, 0) + 1
		var cc := 0
		for r in _match_result.raid_log:
			if r.get("chain_caught", false):
				cc += 1
		print("      moves landed %s, tried %s, caught crossing a chain %d" % [str(used), str(_match_result.get("move_tries", {})), cc])
		check(used.size() >= 3, "raiders land a mix of moves (%d kinds)" % used.size())
	await frames(5)

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("%d FAILED:" % failures.size())
		for f in failures:
			print("  - " + f)
		get_tree().quit(1)
