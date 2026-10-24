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
	Game.settings.dev = false   # as a player has it, whatever this machine's saved settings say
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
	# A label that runs out of room ends in "…" (UI.fit), and details wrap only between them (UI.bits), never cut
	# off mid-letter (clip_text) as they were on a 16:9 phone or a tablet.
	var clipped := paths.filter(func(p): return String(p).begins_with("res://ui/") and FileAccess.get_file_as_string(p).contains("clip_text = true"))
	check(clipped.is_empty(), "no menu label is cut off mid-letter %s" % str(clipped))
	check(UI.bits(["Raider · Age 24", "76 pts last season"]) == "Raider\u00a0· Age\u00a024\u00a0· 76\u00a0pts\u00a0last\u00a0season"
		and UI.bits(["1 raider, 2 covers"], ", ") == "1\u00a0raider, 2\u00a0covers", "details wrap only between them")
	var fl := UI.fit(UI.label("x"), 2)
	check(fl.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS and fl.max_lines_visible == 2
		and fl.autowrap_mode != TextServer.AUTOWRAP_OFF, "a label out of room takes two lines, then ends in an ellipsis")
	fl.free()
	await _languages()

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
	var purse_at_auction := {}
	for tid in oe.teams:
		purse_at_auction[tid] = float(oe.teams[tid].purse)
	var sold := 0
	for lot in oe.lots:
		if lot.status == "sold":
			sold += 1
	check(sold >= 15, "most lots sell (%d), record %s" % [sold, Game.fmt_money(oe.record)])
	# What each franchise spent at and after the auction (its buys, and the free agents it was topped up with to ten).
	var bought := {}
	for lot in oe.lots:
		if lot.status == "sold":
			bought[lot.sold_to] = float(bought.get(lot.sold_to, 0.0)) + float(lot.price)
	se.finish_auction(oe)
	var ledger_ok := true
	var filled := 0
	for tid in se.grades:
		var opening: float = float(purse_at_auction[tid]) + float(bought.get(tid, 0.0))
		if absf(opening - float(se.grades[tid].spent) - float(se.purses[tid])) > 0.01:
			ledger_ok = false
			print("      ledger %s: opening %.1f, spent %.1f, left %.1f" % [tid, opening, float(se.grades[tid].spent), float(se.purses[tid])])
		filled += int(se.grades[tid].get("free_agents", 0))
	check(ledger_ok, "every franchise's purse adds up: opening, less what it spent (free agents included), is what it has left (%d free agents)" % filled)
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

	# 6c. The news, the auction's war room and the season around the matches: retentions, the shortlist and auto-bid,
	# grades, the board's goal, line-ups, fitness, knocks, form, derbies, weekly awards, records, growth.
	Game.delete_season()
	var ns = Game.new_season("MUM")
	ns.seed_value = 777
	var keep_two: Array = ns.default_retained().slice(0, 2)
	ns.retained = keep_two
	ns.retain_done = true
	var neng: AuctionEngine = ns.make_auction()
	var keep_cost := 0.0
	for p in neng.teams.MUM.squad:
		keep_cost += Season.retain_cost(p)
	check(neng.teams.MUM.squad.size() == 2 and is_equal_approx(float(neng.teams.MUM.purse), snappedf(Season.PURSE - keep_cost, 0.5)),
		"retentions: you keep the two you chose, and your purse pays for them (%s)" % Game.fmt_money(float(neng.teams.MUM.purse)))
	check(neng.lots.size() == 34, "the auction still has 34 lots with your own retentions")
	var star_lot: Dictionary = neng.lots[0]
	neng.user_max = {String(star_lot.player.id): neng.can_spend("MUM")}
	neng.auto_bid = true
	check(neng.estimate(star_lot) >= float(star_lot.base) and neng.likely_bidders(star_lot).size() <= 3, "a lot's likely price (%s) and likely bidders %s" % [Game.fmt_money(neng.estimate(star_lot)), neng.likely_bidders(star_lot)])
	neng.resolve_until(func(l): return false)
	check(String(star_lot.sold_to) == "MUM", "auto-bid wins your shortlisted star up to your max (%s for %s)" % [String(star_lot.sold_to), Game.fmt_money(float(star_lot.price))])
	ns.finish_auction(neng)
	var graded := 0
	for id in ns.grades:
		if String(ns.grades[id].grade) in ["A+", "A", "B+", "B", "C+", "C", "D"]:
			graded += 1
	check(graded == 12, "every franchise's auction is graded (yours: %s, %s)" % [ns.grades.MUM.grade, ns.grades.MUM.note])
	check(String(ns.goal.get("key", "")) in Season.GOALS, "the board sets a goal: %s" % ns.goal.get("key", ""))
	var nkinds := {}
	for it in ns.news:
		nkinds[it.k] = true
	check(nkinds.has("AUC_RECORD") and nkinds.has("GOAL_SET"), "the auction and the board make the news: %s" % [nkinds.keys()])
	# Your seven: a bench_p player picked plays, and the match is set up with him.
	var bench_p: Dictionary = {}
	var best_7: Array = ns.best_seven("MUM")
	for p in ns.squads.MUM:
		if not best_7.has(p) and String(p.role) == "defender":
			bench_p = p
	var pick7: Array = []
	for p in best_7:
		pick7.append(String(p.id))
	if not bench_p.is_empty():
		pick7[6] = String(bench_p.id)
	ns.lineup = pick7
	var mine_7: Array = ns.seven("MUM")
	var ids_7 := []
	for p in mine_7:
		ids_7.append(String(p.id))
	check(ids_7 == pick7, "your seven is the one you picked")
	var nfix = ns.next_user_fixture()
	var ncfg: Dictionary = ns.match_config(nfix)
	check((ncfg.home_seven as Array).size() == 7 and ncfg.home_seven[6].id == pick7[6] and (ncfg.fitness as Dictionary).size() == 14,
		"the match gets your seven and everyone's fitness")
	# The match puts them on7 the mat, tired ones with less energy, and a final opens with the walk-out.
	var tired_id := String(pick7[0])
	ncfg.fitness[tired_id] = 0.6
	ncfg["walkout"] = true
	ncfg["autoplay"] = true
	ncfg["autoplay_no_report"] = true
	Game.start_match(ncfg)
	var nlm: Node = Game.current
	await frames(3)
	var on7 := []
	var tired_en := 1.0
	for a in nlm.teams[0].players:
		on7.append(a.pid())
		if a.pid() == tired_id:
			tired_en = a.energy
	check(on7 == pick7, "your picked seven take the mat")
	check(is_equal_approx(tired_en, 0.6), "a tired player starts the match with his fitness as energy (%.2f)" % tired_en)
	check(nlm.walkout and nlm.phase == "intro" and nlm.crowd_lift > 0.2 and absf(nlm.teams[0].players[0].position.x - 1.6) < 0.2,
		"the final opens with both teams lined up for the walk-out")
	Game.show_screen("res://ui/season_hub.gd")
	await frames(2)
	# A season of it.
	var gns := 0
	while ns.phase != "done" and gns < 80:
		gns += 1
		if ns.next_user_fixture() == null:
			ns._advance()
		else:
			ns.simulate_user_match()
	nkinds = {}
	var raw_news := []
	for it in ns.news:
		nkinds[it.k] = true
		var txt: String = News.text(it)
		if txt.begins_with("NEWS_") or txt.contains("{"):
			raw_news.append(txt)
	check(ns.news.size() >= 30 and nkinds.has("CHAMPIONS") and nkinds.has("ARJUNA"), "a season fills the news (%d stories): %s" % [ns.news.size(), nkinds.keys()])
	check(raw_news.is_empty(), "every story reads as a headline: %s" % [raw_news.slice(0, 3)])
	check(String(News.top_story(ns.news).get("k", "")) == "CHAMPIONS", "the champions are the front page after the final")
	check(not ns.week.is_empty() and not (ns.week.raider as Dictionary).is_empty(), "weekly awards: raider of the week %s" % ns.week.raider.get("name", "?"))
	check(ns.records.has("raid_match") and ns.records.has("raid_season") and ns.records.has("margin"), "the record book fills: %s" % [ns.records.keys()])
	var fits_ok := true
	for pid in ns.fitness:
		if float(ns.fitness[pid]) < 0.5 or float(ns.fitness[pid]) > 1.0:
			fits_ok = false
	var forms_ok := true
	for pid in ns.form:
		if (ns.form[pid] as Array).size() > 5:
			forms_ok = false
	check(fits_ok and forms_ok and not ns.form.is_empty(), "fitness stays 0.5 to 1 and form keeps the last five matches")
	check(nkinds.has("INJURY") or nkinds.has("KNOCK") or not ns.injuries.is_empty() or nkinds.has("RETURN"), "players pick up knocks")
	var hist_last: Dictionary = ns.history[-1]
	check(hist_last.has("goal_met") and not is_zero_approx(ns.purse_bonus), "the board's verdict moves next year's budget (%s, %s)" % [hist_last.goal_met, Game.fmt_money(ns.purse_bonus)])
	var derby_seen := false
	for f in ns.fixtures:
		if f.stage == "league" and ns.derby_of(f.home, f.away) != "" and (f.home == "MUM" or f.away == "MUM"):
			derby_seen = ns.derby_of(f.home, f.away) == "DERBY_MAHARASHTRA"
	check(derby_seen, "Mumbai play the Maharashtra Derby")
	check(not ns.all_time(3).is_empty(), "all-time scorers for the hall of fame")
	Game.save_season()
	Game.season = null
	var nsb = Game.get_season()
	check(nsb != null and nsb.news.size() == ns.news.size() and int(nsb.news_n[0]) == int(ns.news_n[0]) and nsb.records.size() == ns.records.size(),
		"the news and the record book are saved")
	# Next year: older players, the young improving, retentions to choose again.
	var vet_p: Dictionary = nsb.squads.MUM[0]
	var vet_age := Scout.age(vet_p)
	var young_better := 0
	var young_count := 0
	var before_ns := {}
	for id in nsb.squads:
		for p in nsb.squads[id]:
			before_ns[String(p.id)] = [Scout.age(p), DB.overall(p)]
	nsb.next_year()
	for id in nsb.squads:
		for p in nsb.squads[id]:
			var b: Array = before_ns.get(String(p.id), [])
			if not b.is_empty() and int(b[0]) <= 21:
				young_count += 1
				if DB.overall(p) >= int(b[1]):
					young_better += 1
	var vet_now: Dictionary = nsb.find_player(String(vet_p.id))
	check(vet_now.is_empty() or Scout.age(vet_now) == vet_age + 1, "players are a year older")
	check(young_count == 0 or young_better * 2 >= young_count, "young players improve (%d of %d)" % [young_better, young_count])
	check(nsb.phase == "auction" and not nsb.retain_done and str(News.latest(nsb.news, 3).map(func(i): return i.k)).contains("NEW_SEASON"), "a new season starts with retentions and the news of it")
	for scr in ["res://ui/season_hub.gd", "res://ui/retention_screen.gd", "res://ui/war_room.gd", "res://ui/hall_of_fame.gd"]:
		var scr_n := Game.show_screen(scr)
		await frames(3)
		check(is_instance_valid(scr_n) and Game.current == scr_n, "screen " + scr)
	Game.save_season()
	nsb.retained = nsb.default_retained()
	nsb.retain_done = true
	Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"})
	await frames(20)
	var aus_n: Node = Game.current
	aus_n._skip_to_target()
	await frames(2)
	aus_n._finish_all()
	await frames(5)
	check(aus_n._done and nsb.phase == "league" and not nsb.grades.is_empty(), "the auction screen finishes with grades for all")
	var mds := Game.show_screen("res://ui/match_day.gd")
	await frames(3)
	check(is_instance_valid(mds) and mds.picked.size() == 7, "match day opens with your seven")
	Game.show_screen("res://ui/main_menu.gd")
	await frames(3)
	check(not Game.current.find_children("*", "NewsTicker", true, false).is_empty(), "the home screen runs the news ticker")
	Game.delete_season()

	# 6d. Nations Cup: the squad of twelve and a captain, what you need, the awards, the underdog.
	Game.delete_cup()
	var ucup = Game.new_cup("KEN")
	check(not ucup.picked and ucup.pool().size() == 18, "a country's pool is eighteen: %d" % ucup.pool().size())
	var best_12: Array = ucup.best_squad()
	check(best_12.size() == 12 and Cup.squad_ok(best_12), "its best twelve make a squad")
	var short11 := best_12.slice(0, 11)
	check(not Cup.squad_ok(short11), "eleven do not")
	Game.show_screen("res://ui/cup_squad.gd")
	await frames(3)
	check(Game.current.get_script().resource_path.ends_with("cup_squad.gd"), "the squad picker opens")
	ucup.confirm_squad(best_12, String(best_12[1].id))
	check(ucup.picked and ucup.captain == String(best_12[1].id) and String(News.latest(ucup.news, 1)[0].k) == "CUP_CAPTAIN", "squad confirmed and the captain named")
	check(Cup.is_underdog("KEN") and not Cup.is_underdog("IND"), "Kenya are underdogs, India are not")
	var under_ok := true
	for cid in DB.country_ids:
		under_ok = under_ok and Cup.is_underdog(cid) == (DB.team_rating(DB.team(cid).squad) <= Cup.UNDERDOG)
	check(under_ok and Cup.is_underdog("BAN") == false and Cup.is_underdog("POL"),
		"the Underdog badge goes by the rating on the country's card, the one the challenge names")
	ucup.simulate_user_match()
	ucup.simulate_user_match()
	var fx_before: String = JSON.stringify(ucup.fixtures)
	var need_sc: Dictionary = ucup.scenario()
	check(String(need_sc.get("k", "")) in ["QUAL_THROUGH", "QUAL_OUT", "NEED_WIN", "NEED_WIN_BY", "NEED_TIE", "NEED_LOSS_BY", "NEED_HELP"],
		"what you need from the last group match: %s" % (News.text({"k": need_sc.get("k", ""), "v": 1, "a": need_sc.get("a", {})}) if not need_sc.is_empty() else "?"))
	check(JSON.stringify(ucup.fixtures) == fx_before, "working it out leaves the fixtures as they were")
	var need_news := false
	for it in ucup.news:
		if String(it.k).begins_with("NEED_") or String(it.k).begins_with("QUAL_"):
			need_news = true
	check(need_news, "and it is in the news")
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(3)
	ucup.sim_everything_left()
	check(ucup.stage == "done" and not ucup.awards.get("mvp", {}).is_empty() and not ucup.awards.get("raider", {}).is_empty(),
		"the Nations Cup names its Golden Raider (%s) and Player of the Tournament (%s)" % [ucup.awards.raider.get("name", "?"), ucup.awards.mvp.get("name", "?")])
	var cupk := {}
	for it in ucup.news:
		cupk[it.k] = true
	check(cupk.has("CUP_CHAMPIONS") and cupk.has("GOLDEN_RAIDER") and cupk.has("CUP_FINAL_SET"), "the cup makes the news: %s" % [cupk.keys()])
	check((ucup.bracket().semis as Array).size() == 2 and String(ucup.bracket().champion) == ucup.champion, "the bracket has the semi-finals and the champion")
	Game.save_cup()
	Game.cup = null
	check(Game.get_cup() != null and Game.get_cup().picked and Game.get_cup().awards.size() == 3, "the cup's squad and awards are saved")
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(3)
	Game.show_screen("res://ui/awards_screen.gd", {"awards": ucup.awards, "label": "Cup", "nsb": "res://ui/main_menu.gd", "mine": "KEN",
		"title": "CUP_AWARDS", "titles": {"mvp": "PLAYER_OF_TOURNAMENT", "raider": "GOLDEN_RAIDER", "defender": "BEST_DEFENDER"}})
	await frames(3)
	check(Game.current.get_script().resource_path.ends_with("awards_screen.gd"), "the tournament awards screen opens")
	Game.delete_cup()

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
			# Those sitting and those standing are drawn apart: on the beach, a few on chairs and the rest standing round.
			var people := 0
			for card in cards:
				people += (card as MultiMeshInstance3D).multimesh.instance_count
			check(people > 20, "the crowd is people from the sprite sheet: " + a.id)
		ar.queue_free()
	var sheet := Arena.crowd_sheet()
	check(not sheet.is_empty() and (sheet.info.people as Array).size() >= 8 and (sheet.info.frames as Array).size() == 8,
		"crowd sprite sheet: eight people in eight poses")

	# 7a. The scenery (game/scenery.gd): a photographed sky outdoors, its HDR light only on Medium and High; each kind of
	# tree, seat and building drawn in one go, cut-outs and cut-down models on Low; the stands one mesh; few draws; and
	# every spectator facing the court, on every level.
	var gfx_before := int(Game.settings.graphics)
	for gfx in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = gfx
		for id in ["dome", "stadium", "village", "monsoon", "beach"]:
			var ar := Arena.new()
			add_child(ar)
			ar.build(id, Color.RED, Color.BLUE, "TEST")
			await frames(1)
			var drawn := ar.find_children("*", "MultiMeshInstance3D", false, false).map(
				func(n): return String(n.multimesh.mesh.resource_path).get_file())
			var lvl := " (%s)" % ["Low", "Medium", "High"][gfx]
			if id != "dome":
				var sm: Material = ar.env.sky.sky_material
				check(sm is ShaderMaterial and sm.get_shader_parameter("panorama") is Texture2D
					and bool(sm.get_shader_parameter("use_light")) == (gfx >= Game.GFX_MEDIUM), id + ": a photographed sky" + lvl)
			var once := drawn.filter(func(p): return p != "").all(func(p): return drawn.count(p) == 1)
			check(once, id + ": each model drawn in one go" + lvl + " %s" % [drawn])
			if id in ["village", "monsoon", "beach"]:
				check(drawn.any(func(p): return p.ends_with("_card.res")) and not drawn.has("rain_tree_low.res")
					and drawn.has("monobloc_chair_low.res" if gfx == Game.GFX_LOW else "monobloc_chair.res"),
					id + ": trees as cut-outs, chairs cut down on Low" + lvl)
			if id == "stadium":
				check(drawn.has("city_apartments_low.res" if gfx == Game.GFX_LOW else "city_apartments.res"), "stadium: the city round it" + lvl)
			if id == "village":
				check(drawn.has("indian_village_temple_low.res" if gfx == Game.GFX_LOW else "indian_village_temple.res"), "village: the temple" + lvl)
			if id == "beach":
				check(drawn.has("jagannath_tower_low.res"), "beach: the Jagannath temple's tower across the bay" + lvl)
				var sea := ar.find_children("*", "MeshInstance3D", false, false).filter(
					func(n): return n.material_override is ShaderMaterial and n.material_override.get_shader_parameter("waves") is Texture2D)
				check(sea.size() == 2, "beach: the sea, near and far")
			if id in ["dome", "stadium", "monsoon"]:
				check(ar.shell.find_children("Stands", "MeshInstance3D", true, false).size() == 1, id + ": the stands are one mesh")
			var parts := ar.find_children("*", "GeometryInstance3D", true, false).filter(func(n): return n.visible).size()
			check(parts <= 60, id + ": %d things to draw%s (60 at most)" % [parts, lvl])
			# Each spectator's forward (their card's -z) points at the court's middle, and their card has their back
			# drawn for a camera behind them (as over the stand it looks over). Headless, as here, a MultiMesh keeps no
			# transforms, so from what the arena kept of each (Arena._crowd_cards), checked against the transforms
			# themselves where a renderer keeps them.
			var crowd := ar.find_children("*", "MultiMeshInstance3D", false, false).filter(
				func(n): return n.material_override is ShaderMaterial and n.material_override.get_shader_parameter("atlas") is Texture2D)
			var spectators := 0
			var facing := 0
			var backs := true
			for card in crowd:
				var m: ShaderMaterial = (card as MultiMeshInstance3D).material_override
				backs = backs and m.get_shader_parameter("atlas_back") is Texture2D \
					and m.get_shader_parameter("atlas_back") != m.get_shader_parameter("atlas")
				var mm: MultiMesh = (card as MultiMeshInstance3D).multimesh
				var faces: PackedVector3Array = card.get_meta("faces", PackedVector3Array())
				var kept := faces.size() == 2 * mm.instance_count
				var rendered := not mm.buffer.is_empty()   # a renderer keeps the transforms: what was kept must match them
				for i in mm.instance_count:
					spectators += 1
					if not kept:
						continue
					var feet := faces[2 * i]
					var fwd := faces[2 * i + 1]
					if rendered and (mm.get_instance_transform(i).origin.distance_to(feet) > 0.001
							or (-mm.get_instance_transform(i).basis.z.normalized()).distance_to(fwd) > 0.001):
						continue
					facing += int(Vector3(fwd.x, 0.0, fwd.z).normalized().dot(Vector3(-feet.x, 0.0, -feet.z).normalized()) > 0.7)
			check(spectators > 20 and facing == spectators and backs,
				id + ": every spectator faces the court (%d of %d), their backs drawn%s" % [facing, spectators, lvl])
			ar.queue_free()
			await frames(1)
	Game.settings.graphics = gfx_before

	# 7b. Shadows on every graphics level: the sun's own on Medium and High; on Low, where the sun casts none, each
	# body's drawn flat on the floor, from the start or once a slow phone's match lowers its graphics.
	var gfx_was := int(Game.settings.graphics)
	for gfx in [Game.GFX_LOW, Game.GFX_MEDIUM]:
		Game.settings.graphics = gfx
		Game.start_match({"home": "MUM", "away": "DEL", "arena": "village", "mode": "quick", "autoplay": true, "autoplay_no_report": true, "length": 0, "difficulty": 1})
		var shm: Node = Game.current
		await frames(2)
		var n: Array = _floor_shadowed(shm)
		check(shm.officials.find_children("*", "MeshInstance3D", false, false).any(
			func(mi): return mi.mesh != null and String(mi.mesh.resource_path).contains("scorers_table")), "village: the scorers' trestle table")
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
	# 8c. Clips from the CMU motion capture library (a BVH source, tools/mocap/fbx_to_clip.gd): each loads, and on the
	# game's own skeleton, played at its own speed, a foot on the floor holds (it slides about less than any upright
	# running clip's does, under 0.2 m/s). The crouched walks carry a crouched defender creeping forward and back, but
	# not one running in, whom a crouched clip could not keep up with.
	var cmu := []
	for f in DirAccess.get_files_at(MocapClip.DIR):
		var raw = JSON.parse_string(FileAccess.get_file_as_string(MocapClip.DIR.path_join(f))) if f.ends_with(".json") else null
		if raw is Dictionary and String(raw.get("source", "")).to_lower().ends_with(".bvh"):
			cmu.append(MocapClip.load_file(MocapClip.DIR.path_join(f)))
	check(cmu.size() >= 2, "the CMU clips are in the library (%d)" % cmu.size())
	for cm in cmu:
		var held: Vector2 = cm.foot_speed() if cm != null else Vector2(0.0, INF)
		check(cm != null and cm.version == 2 and cm.quats.size() >= 20 and cm.speed > 0.2 and held.y < 0.2,
			"CMU clip %s loads, and at its %.2f m/s a planted foot holds (slides %.2f m/s)" % [cm.name if cm else "?", cm.speed if cm else 0.0, held.y])
	var cr := Athlete.new()
	cr.setup(DB.team("DEL").squad[3], 1, Color.ORANGE, Color.WHITE, true)
	add_child(cr)
	cr.facing = Vector3(0, 0, -1)
	cr.set_state("ready", 1000.0)
	cr.set_process(false)
	var carried := {}
	for way in [["forward", Vector3(0, 0, -0.7)], ["back", Vector3(0, 0, 0.6)], ["running in", Vector3(0, 0, -3.2)]]:
		for f in 45:
			cr.lock_facing = true
			cr.face_toward(cr.position + Vector3(0, 0, -1), 1.0 / 30.0, 10.0)
			cr.drive(way[1], 1.0 / 30.0)
			cr._process(1.0 / 30.0)
			cr.model._process(1.0 / 30.0)
		carried[way[0]] = cr.model._move.name if cr.model._move != null and cr.model.move_weight > 0.3 else "none"
	check(carried.forward == "move_crouch_walk" and carried.back == "move_crouch_back"
		and not String(carried["running in"]).begins_with("move_crouch") and carried["running in"] != "none",
		"a crouched defender creeps forward and back on the CMU crouched walks, and runs in on an upright clip (%s)" % str(carried))
	cr.queue_free()

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
		# Below the knees nothing is in the team's colours (tools/rig/leg_skin.py): the kit map once had speckles of
		# trim and kit over the knees and shins of every body (a third of one body's lower legs, half another's).
		var legs := {}
		for b in RiggedBody.bodies():
			if String(b.kind) == "player":
				legs[String(b.file)] = snappedf(_leg_kit(String(b.file)) * 100.0, 0.01)
		check(not legs.is_empty() and legs.values().all(func(v): return v < 1.0),
			"bare legs: no team colour below the knees (%% of the triangles there, each body: %s)" % str(legs))
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
	# Who is who: the tags over the players' heads, and the names with the points.
	var tg: Array = rm.hud.tags.tags_now()
	var keyed: Array = tg.filter(func(e): return e.key)
	check(tg.size() == rm.on_mat(0).size() + rm.on_mat(1).size() and keyed.size() == 2
		and keyed.any(func(e): return e.a == rm.controlled and e.name == rm.controlled.tag_name())
		and keyed.any(func(e): return e.a == rm.raider and e.name == rm.raider.tag_name())
		and tg.filter(func(e): return not e.key).all(func(e): return e.name == ""),
		"tags: names over you and the raider, numbers over everyone else on the mat")
	check(tg.back().key, "... yours and the raider's drawn last, on top")
	Game.settings.tags = 1
	check(rm.hud.tags.tags_now().all(func(e): return e.name != ""), "tags: names over everyone")
	Game.settings.tags = 2
	check(rm.hud.tags.tags_now().is_empty(), "tags: off")
	Game.settings.tags = 0
	# A shout over the calls on the left is held back ("Tackle!" and "Shabash!" on top of each other).
	rm.hud.event("Tackle!", Game.C_GOOD)
	await frames(2)
	var c3: Camera3D = rm.cam.cam
	var calls: Rect2 = rm.hud.events_box.get_global_rect()
	check(rm.hud.over_calls(c3.project_position(calls.get_center(), 12.0))
		and not rm.hud.over_calls(c3.project_position(Vector2(calls.get_center().x + 700.0, 650.0), 12.0)),
		"a shout over the calls is held back, one clear of them is not")
	check(not bool(Game.settings.dev) and rm.get_children().all(func(c): return not (c is DevOverlay)),
		"no developer overlay in a player's match")
	var dov := DevOverlay.new(rm)
	rm.add_child(dov)
	await frames(45)
	check(dov._all.size() >= 44 and dov.summary().contains("frames over") and dov._readout().contains("graphics"),
		"developer overlay: frame times, graphics, a summary to copy")
	dov.queue_free()
	var tp: Vector3 = rm.controlled.tag_point()
	var waist: Vector3 = rm.controlled.model.anchor("waist")
	check(tp.y > waist.y + 0.6 and tp.y < 2.4 and Vector2(tp.x - waist.x, tp.z - waist.z).length() < 0.5,
		"a player's tag is just over his head, crouched in his stance too (%.2f m up, waist %.2f m)" % [tp.y, waist.y])
	var nm2 := Athlete.new()
	nm2.data = {"name": "Karthik Rao"}
	var nm1 := Athlete.new()
	nm1.data = {"name": "Pele"}
	check(nm2.tag_name() == "K. RAO" and nm1.tag_name() == "PELE", "a tag names him by initial and surname")
	nm2.free()
	nm1.free()
	var hs: Array = rm.on_mat(0).slice(0, 2)
	check(rm._points_line("return", 2, 0, []) == tr("EV_POINTS").format({"n": 2}) + "  " + rm.raider.tag_name()
		and rm._points_line("tackle", 0, 1, hs) == tr("EV_POINTS").format({"n": 1}) + "  %s & %s" % [hs[0].tag_name(), hs[1].tag_name()]
		and rm._points_line("time", 0, 1, []) == tr("EV_POINTS").format({"n": 1}),
		"the points go up with who scored them: the raider, his holders, no one for a time-out")
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
	# The phone buzzes for your side: your hold firmly, a team-mate's lightly. A hold made without a dive is a tackle
	# tried, in the box score.
	rm.haptics.clear()
	var mate: Athlete = rm.on_mat(0).filter(func(a): return a != rm.controlled)[0]
	var tries_were := int(rm.stats[mate.pid()].tries)
	rm._attach(rm.controlled, false, "leg_l")
	rm._attach(mate, false, "leg_r")
	check(rm.haptics == ["hold", "team_hold"], "your hold buzzes the phone, a team-mate's more lightly (%s)" % str(rm.haptics))
	check(int(rm.stats[mate.pid()].tries) == tries_were + 1, "a hold made without a dive counts as a tackle tried")
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
		check(rd == mm.controlled and mm.haptics.has("held"), "a hold on your raider buzzes the phone")
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
		check(mm.haptics.back() == "dash", "a dash on your raider buzzes the phone")
		check(mm.raid.dashed_by == dd and rd.dive_dir.x > 0.5, "dash pushes toward the near side line")
		check(mm.defend_hint() == "dash" or mm._line_gap() < 1.2, "dash is the hint near the line")
	mm.queue_free()
	await frames(3)
	Sfx.stop_all()

	# Frame rate: the battery saver plays at 30 frames a second; Smooth at 60 on a 60 or 120 Hz screen, half of a 144 Hz
	# one, and never unevenly (a 90 Hz screen runs at its own rate); Max as many as the screen shows.
	check(Game.smooth_cap(60) == 60 and Game.smooth_cap(120) == 60 and Game.smooth_cap(144) == 72 and Game.smooth_cap(90) == 0,
		"Smooth's frame rate divides the screen's evenly")
	check([60, 90, 120].all(func(hz): return Game.saver_cap(hz) == 30) and Game.saver_cap(144) == 36,
		"the battery saver's too: 30, or 36 on a 144 Hz screen")
	var fps_was := int(Game.settings.fps)
	Game.settings.fps = Game.FPS_SAVER
	Game.apply_frame_rate()
	var saver_cap := Engine.max_fps
	Game.settings.fps = Game.FPS_MAX
	Game.apply_frame_rate()
	check(saver_cap == Game.saver_cap(Game.screen_hz()) and Engine.max_fps == 0,
		"the battery saver plays at about 30 frames a second (%d here), Max at the screen's own rate" % saver_cap)
	Game.settings.fps = fps_was
	Game.apply_frame_rate()

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
	var buzzes := 0
	m.tree_exiting.connect(func(): pass)
	while not _match_done and n_frames < 30 * 60 * 12:
		await get_tree().process_frame
		n_frames += 1
		if is_instance_valid(m):
			buzzes = m.haptics.size()
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
		check(int(_match_result.mvp.get("number", 0)) > 0, "the player of the match carries his shirt number (#%d)" % int(_match_result.mvp.get("number", 0)))
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
		check(buzzes == 0, "a match the AI plays on its own (as behind the home screen) never buzzes the phone")
		# The box score: both sides' seven, adding up to the match.
		var box: Array = _match_result.get("box", [])
		var adds: bool = box.size() == 2 and box[0].size() == 7 and box[1].size() == 7
		var made := 0
		var empties := 0
		var top := 0
		for t in box.size():
			var rsum := 0
			for r in box[t]:
				rsum += int(r.raid)
				made += int(r.raids)
				empties += int(r.empty)
				top = maxi(top, int(r.raid) + int(r.tackle))
				adds = adds and int(r.raids_ok) <= int(r.raids) and int(r.empty) <= int(r.raids) - int(r.raids_ok) \
					and int(r.tackle) <= int(r.tries) and int(r.bonus) <= int(r.raid)
			adds = adds and rsum == int(_match_result.breakdown[t].raid)
		var logged: Array = _match_result.raid_log.filter(func(r): return r.kind != "late")
		var logged_empty: Array = _match_result.raid_log.filter(func(r): return r.kind == "return" and int(r.raid_pts) == 0 and not r.raider_out)
		check(adds and made == logged.size() and empties == logged_empty.size(),
			"the box score adds up: raid points, %d raids, %d empty, tackles within those tried" % [made, empties])
		check(int(_match_result.mvp.pts) == top, "the player of the match has the most points in the box score")
		await frames(3)
		var rs: Node = Game.current
		var tabs: Array = (rs.get_meta("header_right") as Node).find_children("*", "Button", true, false) \
			if rs.has_meta("header_right") else []
		check(tabs.size() == 2 and rs._summary.visible and not rs._box.visible, "the result screen opens on its summary, with a Box score tab")
		if tabs.size() == 2:
			(tabs[1] as Button).pressed.emit()
			await frames(2)
			var grids: Array = rs._box_body.find_children("*", "GridContainer", true, false)
			check(rs._box.visible and not rs._summary.visible and grids.size() == 1
				and grids[0].get_child_count() == grids[0].columns * 9, "the box score shows a side's seven, the headings and the side's line")
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

	await _buttons()

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
## Every language, where the Indian ones run long (tests/fit_audit goes through every screen): their letters in the
## game's fonts, the match's words in the game's theme, the buttons' words inside their circles, and the screens
## whose words ran off a 16:9 phone's screen in Tamil, Kannada or Telugu.
func _languages() -> void:
	var was := TranslationServer.get_locale()
	var keys: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://i18n/src/en.json"))
	var missing := []
	for lang in ["hi", "mr", "ta", "te", "kn", "bn", "pa"]:
		TranslationServer.set_locale(lang)
		for k in keys:
			var t := tr(k)
			for i in t.length():
				var c := t.unicode_at(i)
				if c > 0x7f and not c in [0xA0, 0x200C, 0x200D] and not Game.font_body.has_char(c):
					missing.append("%s %s U+%04X" % [lang, k, c])
	check(missing.is_empty(), "every language's letters are in the game's fonts %s" % str(missing.slice(0, 5)))
	var tc: TouchControls = TouchControls.new()
	var spilt := []
	for lang in Game.LANGUAGES.map(func(l): return l[0]):
		TranslationServer.set_locale(lang)
		for pair in [["BTN_CAMERA", 30.0], ["BTN_SKIP", 62.0], ["BTN_CANT", 78.0], ["BTN_TOUCH", 58.0], ["BTN_LEG", 50.0],
				["BTN_BREAK_FREE", 72.0], ["BTN_DODGE", 47.0], ["BTN_DUBKI", 42.0], ["BTN_JUMP", 46.0], ["BTN_ANKLE", 78.0],
				["BTN_THIGH", 58.0], ["BTN_WAIST", 50.0], ["BTN_DASH", 47.0], ["BTN_CHAIN", 42.0], ["BTN_UNCHAIN", 42.0], ["BTN_SWITCH", 46.0]]:
			# At every button size (Settings); camera and Break free grow half as much as the rest.
			for k in TouchControls.SIZE_K:
				var kk: float = 1.0 + (k - 1.0) * 0.5 if float(pair[1]) in [30.0, 72.0] else k
				var r: float = float(pair[1]) * kk
				var fit: Array = tc.fit_label(tr(pair[0]), Game.font_bold, TouchControls.font_size(pair[1], kk), r)
				if not TouchControls.inside(fit[1], Game.font_bold, fit[0], r):
					spilt.append("%s %s x%s" % [lang, pair[0], k])
	tc.free()
	check(spilt.is_empty(), "every button's words sit inside its circle, in every language and at every size %s" % str(spilt))
	# A wrapped label that ends in "…" kept the font's own line height and hid a taller script's last line.
	TranslationServer.set_locale("kn")
	var box := VBoxContainer.new()
	box.theme = Game.theme
	box.custom_minimum_size = Vector2(150, 0)
	add_child(box)
	var kl := UI.fit(UI.label("ಡಿಫೆಂಡರ್ (ಕವರ್) ವಯಸ್ಸು 28", "MutedLabel", 17), 2)
	box.add_child(kl)
	await frames(3)
	check(kl.get_line_count() >= 2 and kl.get_visible_line_count() == kl.get_line_count(), "a wrapped Kannada label shows every line (%d of %d)" % [kl.get_visible_line_count(), kl.get_line_count()])
	box.queue_free()
	# The screens that ran off a 16:9 phone's screen, now inside it.
	var size_was := get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)
	await frames(2)
	var off := []
	for lang in ["en", "ta", "kn", "te"]:
		TranslationServer.set_locale(lang)
		Game._size_theme()
		Game.delete_season()
		var se = Game.new_season("PAT")
		for screen in ["res://ui/settings_screen.gd", "res://ui/quick_setup.gd", "res://ui/retention_screen.gd", "res://ui/auction_screen.gd"]:
			var sc := Game.show_screen(screen, {"mode": "owner"})
			await frames(12)
			for t in _off_screen(sc):
				off.append("%s %s: %s" % [lang, screen.get_file(), t])
		se.retained = se.default_retained().slice(0, 4)
		se.retain_done = true
		var wr := Game.show_screen("res://ui/war_room.gd")
		await frames(12)
		for t in _off_screen(wr):
			off.append("%s war_room: %s" % [lang, t])
	check(off.is_empty(), "no words off a 16:9 phone's screen in English, Tamil, Kannada or Telugu %s" % str(off.slice(0, 6)))
	Game.delete_season()
	Game.goto_menu()
	get_tree().root.size = size_was
	TranslationServer.set_locale(was)
	Game._size_theme()
	await frames(2)
	# Settings > About: the privacy policy and help pages, and the licences (Godot's own and the fonts' ask to be shown).
	var st := Game.show_screen("res://ui/settings_screen.gd")
	await frames(3)
	var about := st.find_children("*", "Button", true, false).map(func(b): return String(b.text))
	check(about.has(tr("PRIVACY_POLICY")) and about.has(tr("HELP_SUPPORT")) and about.has(tr("LICENCES")),
		"Settings links to the privacy policy, help and the licences")
	var lic := Game.show_screen("res://ui/licences_screen.gd")
	await frames(3)
	var all := ""
	for rt in lic.find_children("*", "RichTextLabel", true, false):
		all += String(rt.text)
	check(all.contains("Godot Engine contributors") and all.contains("SIL Open Font License") and all.contains("FreeType"),
		"the licences screen shows Godot's licence, its parts' and the fonts'")
	check(all.contains("Motion capture data from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217."),
		"the licences screen credits the CMU motion capture database as it asks")
	# The match's words in the game's own fonts (a CanvasLayer does not pass the window's theme on).
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "control": "all", "length": 0,
		"difficulty": 1, "first_raider": 0, "passive": true})
	await frames(3)
	var hm: Node = Game.current
	hm.hud.event("Touch!", Game.C_GOLD)
	var ev: Label = hm.hud.events_box.get_child(hm.hud.events_box.get_child_count() - 1)
	check(hm.hud.root.theme == Game.theme and ev.get_theme_font("font") == Game.font_display, "the match's words are in the game's fonts")
	Game.goto_menu()
	await frames(2)


## Visible words of a screen that reach past the screen's edge (a scrolling list may run on; a ticker runs past).
func _off_screen(root: Node) -> Array:
	var vp := get_viewport().get_visible_rect().grow(2.0)
	var out := []
	for n in root.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or not (c is Label or c is Button) or String(c.get("text")) == "":
			continue
		var x := c.get_parent()
		var skip := false
		while x:
			if x is ScrollContainer or (x.get_script() and String(x.get_script().resource_path).ends_with("news_ticker.gd")):
				skip = true
				break
			x = x.get_parent()
		if skip:
			continue
		var r: Rect2 = c.get_global_transform() * Rect2(Vector2.ZERO, c.size)
		if not vp.encloses(r):
			out.append(String(c.text).left(30))
	return out


func _floor_shadowed(m: Node) -> Array:
	var bodies := 0
	var flat := 0
	for h in m.find_children("*", "Node3D", true, false):
		if h is HumanModel:
			bodies += 1
			if h.rig != null and h.rig.material.next_pass == m.arena.floor_shadow and (h._blob == null or not h._blob.visible):
				flat += 1
	return [flat, bodies]


## The share of the triangles below a body's knees whose kit map marks them as kit or trim, at their middles.
func _leg_kit(file: String) -> float:
	var d: Dictionary = RiggedBody._load(file)
	var img: Image = (d.kit as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var arr: Array = (d.mesh as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var names: Array = d.bones.map(func(b): return String(b.name))
	var lower: Array = ["shin_l", "shin_r", "foot_l", "foot_r"].map(func(n): return names.find(n))
	var knee := minf(float(d.bones[names.find("shin_l")].head[1]), float(d.bones[names.find("shin_r")].head[1]))
	var low := PackedByteArray()
	low.resize(v.size())
	for i in v.size():
		var top := 0
		for k in 4:
			if bw[i * 4 + k] > bw[i * 4 + top]:
				top = k
		low[i] = 1 if lower.has(bi[i * 4 + top]) and v[i].y < knee - 0.04 else 0
	var n := 0
	var marked := 0
	for t in idx.size() / 3:
		var a := idx[t * 3]
		var b := idx[t * 3 + 1]
		var c := idx[t * 3 + 2]
		if low[a] == 0 or low[b] == 0 or low[c] == 0:
			continue
		var u: Vector2 = (uv[a] + uv[b] + uv[c]) / 3.0
		var px := img.get_pixel(clampi(int(u.x * img.get_width()), 0, img.get_width() - 1), clampi(int(u.y * img.get_height()), 0, img.get_height() - 1))
		n += 1
		if px.r + px.g > 0.5:
			marked += 1
	return float(marked) / maxf(n, 1)


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


## 11. The match buttons' sizes and places (Settings > Button size, Move buttons): every size's own places on every phone's
## shape, apart and on the screen; Normal where the buttons always were; a dragged button stays where it is let go and
## the others make way; a layout kept, and mirrored for the left hand; Move buttons from Settings and the pause menu.
func _buttons() -> void:
	var size_was := int(Game.settings.btn_size)
	var places_was: Array = Game.settings.btn_places
	var lh_was: bool = Game.settings.left_handed
	var s := Vector2(1280, 720)
	var old := [Vector2(0, 0), Vector2(-185, 22), Vector2(-152, -128), Vector2(-15, -195), Vector2(100, -165), Vector2(-70, -330)]
	var p0: Array = TouchControls.layout(s, Vector2.ZERO, 1.0, false, [])
	var same := true
	for i in 6:
		same = same and (p0[i] as Vector2).distance_to(s - Vector2(150, 150) + old[i]) < 0.01
	check(same, "Normal keeps the buttons where they always were")
	var bad := []
	for k in TouchControls.SIZE_K:
		var kb: float = 1.0 + (k - 1.0) * 0.5
		for shape in [Vector2(1280, 720), Vector2(1560, 720), Vector2(1690, 720), Vector2(1280, 960), Vector2(1280, 1067)]:
			for lh in [false, true]:
				var ins := Vector2(40, 0) if lh else Vector2(0, 40)   # a camera cut-out on the thumb's side
				var p: Array = TouchControls.layout(shape, ins, k, lh, [])
				var rm := TouchControls.room(shape, ins, lh)
				for i in 6:
					var r: float = TouchControls.PLACE_R[i] * k
					if not rm.grow(0.01).encloses(Rect2(p[i] - Vector2(r, r), Vector2(2 * r, 2 * r))):
						bad.append("%s %s %s: place %d off the room" % [k, shape, lh, i])
					for j in range(i + 1, 6):
						if (p[i] as Vector2).distance_to(p[j]) < r + TouchControls.PLACE_R[j] * k + TouchControls.GAP - 0.01:
							bad.append("%s %s %s: places %d and %d too close" % [k, shape, lh, i, j])
				if (p[3] as Vector2).distance_to(p[4]) < 72.0 * kb + 42.0 * k:
					bad.append("%s %s %s: Break free over Dubki" % [k, shape, lh])
	check(bad.is_empty(), "every button size fits every phone's shape, either hand: apart, and under the scoreboard's row %s"
		% str(bad.slice(0, 4)))
	# Dubki dragged right onto Lion jump: it stays where it is let go, and Lion jump makes way.
	var p1: Array = TouchControls.layout(s, Vector2.ZERO, 1.0, false, [], 4, p0[5])
	var apart := true
	for i in 6:
		for j in range(i + 1, 6):
			apart = apart and (p1[i] as Vector2).distance_to(p1[j]) >= TouchControls.PLACE_R[i] + TouchControls.PLACE_R[j] + TouchControls.GAP - 0.5
	check((p1[4] as Vector2).distance_to(p0[5]) < 0.5 and (p1[5] as Vector2).distance_to(p0[5]) > 50.0 and apart,
		"a button dragged onto another stays where it is let go, and the other makes way")
	var saved := TouchControls.to_saved(p1, s, Vector2.ZERO, false)
	var back: Array = TouchControls.layout(s, Vector2.ZERO, 1.0, false, saved)
	var mirrored: Array = TouchControls.layout(s, Vector2.ZERO, 1.0, true, saved)
	var kept := TouchControls.is_layout(saved) and not TouchControls.is_layout([[1, 2]])
	for i in 6:
		kept = kept and (back[i] as Vector2).distance_to(p1[i]) < 0.2 \
			and (mirrored[i] as Vector2).distance_to(Vector2(s.x - p1[i].x, p1[i].y)) < 0.2
	check(kept, "a layout is kept as it was moved, and mirrored for the left hand")

	# By touch, as on the phone: Dubki picked up, dragged and let go stays there (saved); out of Move buttons a touch
	# there presses it; Reset puts it back.
	Game.settings.left_handed = false
	Game.settings.btn_size = 0
	Game.settings.btn_places = []
	var tc := TouchControls.new()
	add_child(tc)
	tc.set_context("raid")
	tc.editing = true
	var dubki_at := func() -> Vector2: return tc._buttons().filter(func(b): return b.id == "dubki")[0].pos
	var was: Vector2 = dubki_at.call()
	var to := Vector2(tc.get_viewport_rect().size.x * 0.6, 420)
	tc._input(_touch(0, was, true))
	tc._input(_drag(0, was.lerp(to, 0.5)))
	tc._input(_drag(0, to))
	tc._input(_touch(0, to, false))
	var moved_to: Vector2 = dubki_at.call()
	var pressed := []
	tc.action.connect(func(id): pressed.append(id))
	tc.editing = false
	tc._input(_touch(1, to, true))
	tc._input(_touch(1, to, false))
	check(moved_to.distance_to(to) < 1.0 and TouchControls.is_layout(Game.settings.btn_places) and pressed == ["dubki"],
		"a button dragged in Move buttons stays where it is let go, saved, and a touch there presses it %s" % str(pressed))
	tc.reset_places()
	check((Game.settings.btn_places as Array).is_empty() and (dubki_at.call() as Vector2).distance_to(was) < 0.01,
		"Reset puts the buttons back")
	Game.settings.btn_size = 2
	var big: Dictionary = tc._buttons().filter(func(b): return b.id == "touch")[0]
	check(is_equal_approx(float(big.r), 76.0 * 1.4) and int(big.fs) == TouchControls.font_size(76.0, 1.4)
		and int(big.fs) > TouchControls.font_size(76.0), "Extra large draws the buttons and their words 1.4 times as big")
	Game.settings.btn_size = 0
	tc.queue_free()

	# Move buttons from the pause menu: the match stays paused behind, its buttons come back to be dragged, and the
	# phone's back button returns to the pause menu.
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "control": "all", "length": 0,
		"difficulty": 1, "first_raider": 0})
	var m: Node = Game.current
	var g := 0
	while m.phase != "raid" and g < 900:
		await get_tree().process_frame
		g += 1
	m.set_paused(true)
	m.hud._move_buttons()
	await frames(2)
	var opened: bool = m.hud.layout_panel != null and m.controls.editing and m.controls.visible and not m.hud.pause_panel.visible
	m.on_back()
	await frames(2)
	check(opened and m.hud.layout_panel == null and m.paused and m.hud.pause_panel.visible and not m.controls.editing
		and not m.controls.visible, "Move buttons opens from the pause menu over the paused match, and back returns to it")
	m.queue_free()
	await frames(3)
	Sfx.stop_all()
	# And from Settings, over a match the AI plays; Done goes back to Settings.
	Game.show_screen("res://ui/settings_screen.gd")
	await frames(3)
	var move: Array = Game.current.find_children("*", "Button", true, false).filter(func(b): return b.text == tr("MOVE_BUTTONS"))
	if not move.is_empty():
		move[0].pressed.emit()
	await frames(5)
	var ed: Node = Game.current
	var on_editor: bool = String(ed.get_script().resource_path).ends_with("button_layout.gd") and ed.controls.editing
	if on_editor:
		ed.panel.finish()
	await frames(3)
	check(on_editor and String(Game.current.get_script().resource_path).ends_with("settings_screen.gd"),
		"Move buttons opens from Settings, and Done goes back")
	Game.settings.btn_size = size_was
	Game.settings.btn_places = places_was
	Game.settings.left_handed = lh_was
	Game.save_settings()


func _touch(i: int, at: Vector2, down: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = at
	e.pressed = down
	return e


func _drag(i: int, at: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = at
	return e
