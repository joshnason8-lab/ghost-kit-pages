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
	check(not c.awards.get("mvp", {}).is_empty() and int(c.awards.mvp.raid) + int(c.awards.mvp.tackle) > 20, "career season names an Arjuna Award winner: %s" % c.awards.get("mvp", {}).get("name", "?"))
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
	var aw: Dictionary = se.awards
	check(not aw.get("mvp", {}).is_empty() and not aw.get("raider", {}).is_empty() and not aw.get("defender", {}).is_empty(), "season awards: Arjuna Award %s (%s), best raider %s, best defender %s" % [aw.mvp.name, aw.mvp.team, aw.raider.name, aw.defender.name])
	Game.show_screen("res://ui/awards_screen.gd", {"awards": aw, "label": "Season 1", "back": "res://ui/main_menu.gd", "mine": se.team})
	await frames(5)
	check(Game.current != null and Game.current.get_script().resource_path.ends_with("awards_screen.gd"), "awards screen opens")
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
		if not Arena.crowd_sheet().is_empty():
			var cards := ar.find_children("*", "MultiMeshInstance3D", false, false).filter(
				func(n): return n.material_override is ShaderMaterial and n.material_override.get_shader_parameter("atlas") is Texture2D)
			check(not cards.is_empty() and cards[0].multimesh.instance_count > 20, "the crowd is people from the sprite sheet: " + a.id)
		ar.queue_free()
	var sheet := Arena.crowd_sheet()
	check(not sheet.is_empty() and (sheet.info.people as Array).size() >= 8 and (sheet.info.frames as Array).size() == 8,
		"crowd sprite sheet: eight people in eight poses")

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
		check(ra.model.rig != null and ra.model.rig.skeleton.get_bone_count() >= 17, "rigged body built with its bones")
		var rmat: ShaderMaterial = ra.model.rig.material
		check(rmat.get_shader_parameter("albedo_tex") is Texture2D and rmat.get_shader_parameter("kit_tex") is Texture2D,
			"the realistic body wears its texture, with the kit map for team colours")
		var sr: Vector3 = rmat.get_shader_parameter("skin_ratio")
		check(sr.x > 0.0 and sr.x < 3.0 and sr.z > 0.0, "skin tone ratio is sane: %s" % sr)
		ra.set_state("dubki", 1000.0)
		ra.st_t = 500.0
		await frames(20)
		var q: Quaternion = ra.model.rig.skeleton.get_bone_pose_rotation(ra.model.rig._bone["thigh_l"])
		check(not q.is_equal_approx(Quaternion.IDENTITY), "rigged body bends with the pose")
		if ra.model.rig._bone.has("fingers_r"):
			var fb: int = ra.model.rig._bone["fingers_r"]
			ra.set_state("idle", 1000.0)
			await frames(30)
			var relaxed: float = ra.model.rig.skeleton.get_bone_pose_rotation(fb).get_angle()
			ra.set_state("holding", 1000.0)
			await frames(30)
			var grip: float = ra.model.rig.skeleton.get_bone_pose_rotation(fb).get_angle()
			check(relaxed > 0.2 and grip > relaxed * 1.6, "fingers rest curled and grip in a hold (%.2f, %.2f)" % [relaxed, grip])
		ra.queue_free()

	# 8b. Cant, chain, reactions: drive a user match by hand.
	# Breath (the default cant): moves and sprinting cost breath.
	Game.start_match({"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "control": "all", "length": 0, "difficulty": 1, "first_raider": 0, "autoplay_no_report": true, "raid_rule": 2})
	var bm: Node = Game.current
	var gb := 0
	while bm.phase != "raid" and gb < 600:
		await get_tree().process_frame
		gb += 1
	check(not bm.raid.cant_tap, "Breath mode needs no tapping")
	var before_breath: float = float(bm.raid.t)
	bm._spend_breath("lion")
	check(float(bm.raid.t) < before_breath - 1.0, "a lion jump costs breath")
	bm.queue_free()
	await frames(3)
	# Tap: the old way, every move counts as a beat.
	Game.start_match({"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "control": "all", "length": 0, "difficulty": 1, "first_raider": 0, "autoplay_no_report": true, "raid_rule": 1})
	var um: Node = Game.current
	var g5 := 0
	while um.phase != "raid" and g5 < 600:
		await get_tree().process_frame
		g5 += 1
	check(um.raid.cant_tap, "your raid uses the tap cant")
	var um_air: float = float(um.raid.air_max)
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

	# 8b2. Pro raid rule: a 30-second clock and no cant.
	Game.start_match({"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "control": "all", "length": 0, "difficulty": 1, "first_raider": 0, "autoplay_no_report": true, "raid_rule": 0})
	var pm: Node = Game.current
	var g9 := 0
	while pm.phase != "raid" and g9 < 600:
		await get_tree().process_frame
		g9 += 1
	check(not pm.raid.cant_tap and absf(float(pm.raid.t) - 30.0) < 1.0 and pm.hud.raid_clock_l.visible, "30-second clock rule: clock shown, no cant")
	pm.queue_free()
	await frames(3)
	# Traditional: the raid lasts one breath, longer for fitter raiders.
	check(um_air > 14.0 and um_air < 33.0, "cant rule: one breath of %.0fs" % um_air)

	# 8b3. Knockout rules: tie-breaker, golden raid, airborne bonus.
	Game.start_match({"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true, "autoplay_no_report": true, "length": 0, "difficulty": 1, "knockout": true})
	var km: Node = Game.current
	var g10 := 0
	while km.phase != "raid" and g10 < 600:
		await get_tree().process_frame
		g10 += 1
	km.set_process(false)
	# Airborne bonus: a leg stretched over the bonus line, the other foot still short of it.
	var kr: Athlete = km.raider
	kr.position = km.pos_in(1 - km.raiding, 0.0, 4.2)
	kr.facing = Vector3(0, 0, -km.side(km.raiding))
	kr.set_state("kick", 1.0)
	kr.st_t = 0.5
	km.raid.holders = []
	km._check_lines()
	check(km.raid.bonus, "airborne bonus: a stretched leg over the bonus line counts")
	km._end_raid("return")
	km.half = 2
	km.clock = 0.0
	km.teams[0].score = 20
	km.teams[1].score = 20
	km._next_raid()
	check(km.tiebreak and km.on_mat(0).size() == 7 and km.on_mat(1).size() == 7, "drawn knockout goes to a tie-breaker with all seven back")
	var first_tb: Athlete = km.raider
	km._end_raid("return")
	km._next_raid()
	km._end_raid("return")
	km._next_raid()
	check(km.raider != first_tb and km.tb_raids[km.raiding] == 2, "tie-breaker raiders are all different")
	km.tb_raids = [5, 5]
	km._end_raid("return")
	km._next_raid()
	check(km.golden and not km.tiebreak, "still level after five raids each: golden raid")
	km.teams[km.raiding].score += 1
	km._end_raid("return")
	km._next_raid()
	check(km.phase == "fulltime", "the first score in the golden raid wins")
	km.queue_free()
	await frames(3)

	# 8b4. Energy and time outs.
	Game.start_match({"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true, "autoplay_no_report": true, "length": 0, "difficulty": 1})
	var tmm: Node = Game.current
	var g11 := 0
	while tmm.phase != "raid" and g11 < 600:
		await get_tree().process_frame
		g11 += 1
	for a in tmm.on_mat(1):
		a.energy = 0.45
	tmm._end_raid("return")
	tmm._next_raid()
	check(tmm.phase == "timeout" and int(tmm.teams[1].timeouts) == 1, "a tired AI side calls a time out")
	var before: float = tmm.team_energy(1)
	var g12 := 0
	while tmm.phase == "timeout" and g12 < 400:
		await get_tree().process_frame
		g12 += 1
	check(tmm.team_energy(1) > before + 0.1 and tmm.phase == "setup", "the time out restores energy and play resumes")
	check(tmm.request_timeout(), "you can call a time out")
	tmm.queue_free()
	await frames(3)

	# 8b5. Cards, the 5-second rule, Super 10, choosing your defender.
	Game.start_match({"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "control": "all", "length": 0, "difficulty": 1, "first_raider": 1})
	var rm: Node = Game.current
	var g13 := 0
	while rm.phase != "setup" and g13 < 600:
		await get_tree().process_frame
		g13 += 1
	var first_d: Athlete = rm.controlled
	check(first_d != null and first_d.team == 0, "you defend first")
	rm._on_action("switch")
	var second_d: Athlete = rm.controlled
	rm._on_action("switch")
	check(second_d != first_d and rm.controlled != second_d and rm.controlled.team == 0, "Switch cycles through your defenders")
	var pick: Athlete = rm.on_mat(0).filter(func(a): return a != rm.controlled)[0]
	await frames(2)
	rm._on_tap(rm.cam.cam.unproject_position(pick.global_position + Vector3(0, 0.9, 0)))
	check(rm.controlled == pick, "tapping a defender takes him over")
	while rm.phase != "raid" and g13 < 900:
		await get_tree().process_frame
		g13 += 1
	var rough: Athlete = rm.on_mat(0)[0]
	var away_before: int = rm.teams[1].score
	rm._post_messages = []
	rm._card(rough)
	check(rough.cards == 1 and rough.on_mat and rm.teams[1].score == away_before, "a first offence is a green card")
	rm._card(rough)
	check(not rough.on_mat and rough.suspended >= 0.0 and rm.teams[1].score == away_before + 1, "a second is a yellow card: off, and a point to the other side")
	rm.clock = rough.suspended - 1.0
	rm._end_suspensions()
	check(rough.on_mat and rough.suspended < 0.0, "back on after two minutes")
	rm.stats[rm.raider.pid()].raid = 10
	rm._post_messages = []
	rm._milestones()
	check(rm.raider.has_meta("super10"), "ten raid points is a Super 10")
	Game.go_back()
	check(rm.paused, "the phone's back button pauses a match")
	Game.go_back()
	check(not rm.paused, "... and resumes it")
	rm.queue_free()
	await frames(3)
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(2)
	Game.go_back()
	await frames(2)
	check(String(Game.current.get_script().resource_path).ends_with("main_menu.gd"), "back from a screen returns to the menu")
	# The language button on the main menu, and following the phone.
	var menu: Node = Game.current
	menu._open_language()
	await frames(2)
	check(is_instance_valid(menu._picker), "the menu opens the language picker")
	Game.go_back()
	await frames(2)
	check(Game.current == menu and not is_instance_valid(menu._picker), "back closes the language picker, not the game")
	menu._open_language()
	await frames(2)
	(menu._picker.find_children("*", "Button", true, false)[3] as Button).pressed.emit()   # ✕, phone, English, Hindi
	await frames(3)
	check(Game.settings.language == "hi" and TranslationServer.get_locale() == "hi", "picking Hindi on the menu switches to it")
	check(not is_instance_valid(menu._picker) and Game.current == menu, "the picker closes and the menu stays")
	Game.set_language("")
	check(Game.language() == Game.phone_language() and TranslationServer.get_locale() == Game.phone_language(), "Phone language follows the phone")
	Game._write_json(Game.SETTINGS_PATH, {"language": Game.phone_language(), "rules_v": 2, "raid_rule": int(Game.settings.raid_rule)})
	Game.load_settings()
	check(Game.settings.language == "" and int(Game.settings.lang_v) == 2, "an old save's first-run language goes back to following the phone")
	Game.save_settings()
	Game.start_match({"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "control": "all", "length": 0, "difficulty": 1, "first_raider": 0})
	var lm: Node = Game.current
	var g14 := 0
	while lm.phase != "raid" and g14 < 600:
		await get_tree().process_frame
		g14 += 1
	var def_before: int = lm.teams[1].score
	await frames(int(lm.START_LIMIT * 60) + 30)
	check(lm.raid_log.size() > 0 and String(lm.raid_log[0].kind) == "late" and lm.teams[1].score == def_before + 1, "a raider who does not go within 5 seconds gives away a point")
	lm.queue_free()
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
