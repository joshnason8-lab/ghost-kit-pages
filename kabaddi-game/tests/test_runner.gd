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
	# How to Play scrolls from a drag anywhere on its page: nothing on it takes the touch for itself (its lines of
	# text did, so a drag that started on the words did not move the page).
	var how := Game.show_screen("res://ui/howto_screen.gd")
	await frames(3)
	var stops := []
	for sc in how.find_children("*", "ScrollContainer", true, false):
		for c in sc.get_child(0).find_children("*", "Control", true, false):
			if (c as Control).is_visible_in_tree() and (c as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
				stops.append(c.get_class())
	check(stops.is_empty(), "how to play: a drag on the page reaches its scroll box %s" % [stops])

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
		check(ar.shell != null and ar.shell.get_child_count() > 3 and ar.get_child_count() > 3, "arena builds: " + a.id)
		# Its fixed parts come with their baked lighting (tools/bake_lighting), the bake's own lights and sky taken out.
		check(ar.baked and ar.shell.find_child("LightmapGI", false, false) != null
			and ar.shell.find_children("*", "Light3D", false, false).is_empty(), "arena has its baked lighting: " + a.id)
		if not Arena.crowd_sheet().is_empty():
			var cards := ar.find_children("*", "MultiMeshInstance3D", false, false).filter(
				func(n): return n.material_override is ShaderMaterial and n.material_override.get_shader_parameter("atlas") is Texture2D)
			check(not cards.is_empty() and cards[0].multimesh.instance_count > 20, "the crowd is people from the sprite sheet: " + a.id)
		ar.queue_free()
	var sheet := Arena.crowd_sheet()
	check(not sheet.is_empty() and (sheet.info.people as Array).size() >= 8 and (sheet.info.frames as Array).size() == 8,
		"crowd sprite sheet: eight people in eight poses")

	# 7b. Shadows on every graphics level: the sun's own on Medium and High; on Low, where the sun casts none, each
	# body's drawn flat on the floor, from the start or once a slow phone's match lowers its graphics.
	var gfx_was := int(Game.settings.graphics)
	for gfx in [Game.GFX_LOW, Game.GFX_MEDIUM]:
		Game.settings.graphics = gfx
		Game.start_match({"home": "MUM", "away": "DEL", "arena": "village", "mode": "quick", "autoplay": true, "autoplay_no_report": true, "length": 0, "difficulty": 1})
		var shm: Node = Game.current
		await frames(2)
		var n: Array = _floor_shadowed(shm)
		if gfx == Game.GFX_LOW:
			check(not shm.arena.sun.shadow_enabled and n[0] == n[1] and n[1] >= 21, "Low: every body has its own shadow on the floor (%d of %d)" % n)
		else:
			check(shm.arena.sun.shadow_enabled and n[0] == 0, "Medium: the sun casts the shadows")
			shm.lower_graphics()
			n = _floor_shadowed(shm)
			check(not shm.arena.sun.shadow_enabled and n[0] == n[1], "lowered to Low in a match: every body's own shadow takes over (%d of %d)" % n)
		shm.queue_free()
		await frames(3)
	Game.settings.graphics = gfx_was
	Game.save_settings()

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
	# 8b. Captured running carries a moving player.
	if not MocapClip.moves().is_empty():
		var run: MocapClip = MocapClip.moves()[0]
		check(run.version == 2 and run.speed > 0.5 and run.quats.size() > 5, "captured running clips load: " + run.name)
		var ra := Athlete.new()
		ra.setup(DB.team("MUM").squad[1], 0, Color.TEAL, Color.WHITE, true)
		add_child(ra)
		ra.facing = Vector3(0, 0, -1)
		ra.set_state("idle", 1000.0)
		ra.set_process(false)
		# The legs follow how far he really moves (Athlete._track_motion), so he has to move.
		for f in 30:
			ra.drive(ra.facing * 4.5, 1.0 / 30.0)
			ra._process(1.0 / 30.0)
			ra.model._process(1.0 / 30.0)
		check(ra.model.move_weight > 0.9, "a running player is carried by the captured run (%.2f)" % ra.model.move_weight)
		ra.queue_free()

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
		# Held by one leg and standing on the other, his standing leg caught in the frame the hold on the first lets go of
		# it: nothing left to stand on was taken as an endless sink, and the body sank through the floor for the rest of
		# the raid (or went to NaN). He stands on the leg let go of, at his height.
		var rig: RiggedBody = ra.model.rig
		ra.set_state("idle", 1000.0)
		await frames(10)
		rig.foot_goal["l"] = [ra.model.anchor("foot_l"), 1.0]
		await frames(15)
		var stood: float = ra.model.anchor("waist").y
		rig.foot_goal.erase("l")
		rig.foot_goal["r"] = [ra.model.anchor("foot_r"), 1.0]
		var moved := 0.0
		for i in 15:
			await get_tree().process_frame
			var w: Vector3 = ra.model.anchor("waist")
			moved = maxf(moved, absf(w.y - stood)) if w.is_finite() and is_finite(rig._sunk) else INF
		var freed: float = ra.model.anchor("foot_l").y
		check(moved < 0.06 and freed < 0.15, "held by the leg he stands on as the other is let go of, he stays on his feet (middle moved %.2f m, the freed ankle %.2f m up)" % [moved, freed])
		rig.foot_goal.clear()
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
		# Lion jump over a dive at the ankles. An ankle dive grips only with its hands on his legs (checked
		# on the bodies as drawn), so the diver is laid out with his hands at the raider's feet first.
		d0.tackle_kind = "ankle"
		d0.position = rd.position + Vector3(1.0, 0, 0)
		d0.facing = Vector3(-1, 0, 0)
		d0.set_state("dive", 9.0)
		rd.set_state("jump", 9.0)
		await frames(6)
		var reach: Vector3 = (d0.model.anchor("hand_l") + d0.model.anchor("hand_r")) * 0.5 - d0.position
		d0.position = rd.position - Vector3(reach.x, 0, reach.z)
		await frames(3)
		d0.st_len = mm.DIVE_TIME
		d0.st_t = mm.DIVE_TIME * 0.6
		rd.st_len = mm.JUMP_TIME
		rd.st_t = mm.JUMP_TIME * 0.4
		mm._check_contacts(mm.defenders())
		check(d0.state == "recover" and mm.raid.holders.is_empty(), "lion jump clears an ankle dive")
		check(mm.raid.moves.has("lion"), "lion jump is counted")
		# Back kick at a defender behind. The touch is the foot on him, as drawn, the match steering it out to him
		# (Match._aim_limb) frame by frame: from within a leg's reach it touches him, and from further off it falls
		# short and gives nothing (kicks were given from 2 m, the foot nowhere near him).
		d0.position = mm.pos_in(opp, -3.5, 6.0)   # the lion jump's diver, out of the way
		for far in [false, true]:
			rd.set_state("raid")
			rd.cooldown = 0.0
			rd.facing = Vector3(0, 0, -mm.side(mm.raiding))
			d1.touched = false
			d1.set_state("ready")
			d1.cooldown = 5.0   # standing his ground (no pulling back out of reach)
			d1.position = rd.position - rd.facing * (1.7 if far else 0.85)
			d1.facing = rd.facing
			mm.raid.touch_hit = false
			mm.raid.moves.erase("backkick")
			await frames(3)
			mm._raider_kick()
			check(rd.state == "backkick", "Kick at a defender behind is a back kick" + (" (from 1.7 m)" if far else ""))
			var kf := 0
			while rd.state == "backkick" and rd.st_t < rd.st_len and kf < 40:
				mm._aim_limb()
				await get_tree().process_frame
				mm._check_contacts(mm.defenders())
				kf += 1
			if far:
				check(not d1.touched and not mm.raid.moves.has("backkick"), "a back kick from 1.7 m falls short: no touch")
			else:
				check(d1.touched and mm.raid.moves.has("backkick"), "back kick touches him")
		rd.set_state("raid")
		mm._aim_limb()   # the leg let go (the match is not running to do it)
		# Waist hold plucks a jumping raider out of the air.
		rd.st_t = 99.0
		rd.set_state("jump", mm.JUMP_TIME)
		rd.st_t = mm.JUMP_TIME * 0.4
		# Contact is checked on the bodies as drawn, so the diver is laid out with his hands at the raider's
		# middle first.
		var dw: Athlete = defs[2]
		dw.tackle_kind = "waist"
		dw.dmoves["waist"] = 95
		dw.position = rd.position + Vector3(1.0, 0, 0)
		dw.facing = Vector3(-1, 0, 0)
		dw.set_state("dive", 9.0)
		rd.set_state("jump", 9.0)
		await frames(6)
		var wr: Vector3 = (dw.model.anchor("hand_l") + dw.model.anchor("hand_r")) * 0.5 - dw.position
		var wt: Vector3 = rd.model.anchor("waist") - rd.position
		var dw_at: Vector3 = rd.position + Vector3(wt.x - wr.x, 0, wt.z - wr.z)
		dw.position = dw_at
		await frames(3)
		var caught := 0
		for k in 20:
			for h in mm.raid.holders.duplicate():
				mm._release(h, false)
			dw.position = dw_at
			dw.set_state("dive", mm.DIVE_TIME)
			dw.st_t = mm.DIVE_TIME * 0.6
			rd.set_state("jump", mm.JUMP_TIME)
			rd.st_t = mm.JUMP_TIME * 0.4
			mm._check_contacts(mm.defenders())
			if mm.raid.holders.has(dw):
				caught += 1
		check(caught >= 12, "waist hold catches a lion jump most of the time (%d/20)" % caught)
		for h in mm.raid.holders.duplicate():
			mm._release(h, false)
		# Break free (the Dodge button while he is held) makes the escape that suits the hold: out of an ankle hold,
		# which a sidestep cannot slip, a lion jump.
		rd.st_t = 99.0
		rd.set_state("raid")
		dw.tackle_kind = "ankle"
		dw.position = rd.position + Vector3(1.2, 0, 0)
		mm._attach(dw, false, "leg_l")
		rd.cooldown = 0.0
		mm._break_free()
		check(mm.raid.holders.has(dw) and rd.state == "jump", "Break free out of an ankle hold is a lion jump")
		for h in mm.raid.holders.duplicate():
			mm._release(h, false)
		rd.st_t = 99.0
		rd.set_state("raid")
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

	# 10. After a touch the defence goes for him: a hand touch, then straight for home past the line either side of the
	# man touched (as a player raids), the AI defending, twelve times. Before, a raider running home with the point was
	# mostly let go: 20 defenders went for him in the twelve, and 12 who had him within a dive's reach never did (now
	# 28 and 5).
	var went_n := 0
	var missed_n := 0
	for sd in 12:
		var res: Array = await _touch_and_run(100 + sd)
		went_n += int(res[0])
		missed_n += int(res[1])
	check(went_n >= 24 and missed_n <= 7, "after a touch the defence goes for him (%d went in 12 runs home; %d had him in reach and never went)"
		% [went_n, missed_n])

	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
		get_tree().quit(0)
	else:
		print("%d FAILED:" % failures.size())
		for f in failures:
			print("  - " + f)
		get_tree().quit(1)


## How many bodies in match m have their own shadow on the floor (Arena.floor_shadow), and how many bodies there are.
func _floor_shadowed(m: Node) -> Array:
	var bodies := 0
	var flat := 0
	for h in m.find_children("*", "Node3D", true, false):
		if h is HumanModel:
			bodies += 1
			if h.rig != null and h.rig.material.next_pass == m.arena.floor_shadow and (h._blob == null or not h._blob.visible):
				flat += 1
	return [flat, bodies]


## A hand touch, then straight for home past the line either side of the man touched, the AI defending (lab mode):
## how many defenders went for him (a wind-up or a dive) before he was held or home, and how many had him within a
## dive's reach (1.8 m) for 0.2 s, free to go, and never went.
func _touch_and_run(sd: int) -> Array:
	seed(sd)
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true,
		"autoplay_no_report": true, "length": 0, "difficulty": 1, "players": [7, 4], "first_raider": 0, "lab": true,
		"raid_rule": 0}
	add_child(m)
	m.rng.seed = sd
	while m.phase != "raid":
		await get_tree().process_frame
	var r: Athlete = m.raider
	var defs: Array = m.defenders()
	var home := Vector3(0, 0, m.side(m.raiding))
	r.position = m.pos_in(1, 0.0, 3.9)
	r.facing = -home
	# The one he touches in front of him, the line either side of him, one deeper.
	var places := [[0.6, 4.85], [-0.7, 4.9], [1.9, 4.8], [0.2, 6.2]]
	for i in defs.size():
		defs[i].position = m.pos_in(1, places[i][0], places[i][1])
		defs[i].facing = home
	m.lab_move = Vector3(0.2, 0, 0)
	m.lab_force = {"hold": true, "ai_defence": true}
	var dt := 1.0 / 30.0
	var t := 0.0
	var touched := false
	var held := false
	var went := {}
	var near := {}
	while t < 8.0:
		if not touched and t >= 0.4:
			touched = true
			defs[0].cooldown = maxf(defs[0].cooldown, 0.5)   # he stands his ground for the touch ...
			m._raider_touch(false)
			m.lab_move = home   # ... and the raider goes straight for home
		if touched and t >= 0.6 and t < 0.65:
			defs[0].cooldown = 0.0   # ... then he is free to go
		await get_tree().process_frame
		t += dt
		if m.phase != "raid":
			break
		held = held or not (m.raid.holders as Array).is_empty()
		if touched and not held:
			for i in defs.size():
				var a: Athlete = defs[i]
				if not is_instance_valid(a):
					continue
				if a.state in ["telegraph", "dive"]:
					went[i] = true
				elif a.state == "ready" and a.position.distance_to(r.position) < 1.8:
					near[i] = float(near.get(i, 0.0)) + dt
	var missed := 0
	for i in near:
		if float(near[i]) >= 0.2 and not went.has(i):
			missed += 1
	m.queue_free()
	await get_tree().process_frame
	return [went.size(), missed]
