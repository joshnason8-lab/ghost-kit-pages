extends Node
## The smoke test CI runs before building: each law in KhoRules checked against its rule (docs/RULES.md); every screen
## opens in every language; a championship of each kind plays through to its champion; AI matches in both rule books
## finish with scores the laws allow; the motion of every player stays smooth. Headless:
##   godot --headless --path . --fixed-fps 30 res://tests/test_runner.tscn
## Exits 1 on any failure.

var failures := 0
var checks := 0


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var keep: Dictionary = Game.settings.duplicate(true)
	_rules()
	_sim()
	await _screens()
	_cups()
	await _matches()
	await _your_controls()
	await _bodies()
	await _owner_round()
	await _grounds()
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


# ---------------------------------------------------------------- the laws

func _rules() -> void:
	var cf := KhoRules.field(KhoRules.CLASSIC)
	var ff := KhoRules.field(KhoRules.FAST)
	# The field.
	check(cf.length == 27.0 and cf.width == 16.0, "classic field 27 x 16 m")
	check(ff.length == 22.0 and ff.width == 16.0, "fast field 22 x 16 m")
	check(cf.squares == 8 and ff.squares == 6, "eight squares classic, six fast")
	check(is_equal_approx(cf.lane_w, 0.30), "central lane 30 cm")
	check(is_equal_approx(cf.cross_w, 0.35) and is_equal_approx(ff.cross_w, 0.40), "cross lanes 35 cm (classic), 40 cm (fast)")
	var xs: Array = cf.square_x
	check(absf((xs[1] - xs[0]) - (2.30 + 0.35)) < 0.001, "cross lanes 2.30 m apart")
	check(absf((xs[0] - cf.cross_w * 0.5) - (-cf.pole_gap * 0.5 + 2.55)) < 0.001, "first cross lane 2.55 m from the pole")
	check(absf((xs[7] + cf.cross_w * 0.5) - (cf.pole_gap * 0.5 - 2.55)) < 0.001, "last cross lane 2.55 m from the other pole (24 m between poles)")
	var fx: Array = ff.square_x
	check(absf((fx[5] + ff.cross_w * 0.5) - (ff.pole_gap * 0.5 - 2.55)) < 0.001, "fast: six cross lanes fit 19 m between the poles")
	check(absf(cf.length * 0.5 - cf.pole_gap * 0.5 - cf.free_zone) < 0.001, "free zones 1.5 m")
	check(cf.pole_h >= 1.20 and cf.pole_h <= 1.25, "poles 120-125 cm")
	check(KhoRules.square_face(0) != KhoRules.square_face(1) and KhoRules.square_face(0) == KhoRules.square_face(2), "seated chasers face alternate ways")
	# Direction: the active chaser takes his direction and may not turn back.
	var c := KhoRules.Chase.new()
	c.reset_at(xs[3], 1)
	var p := Vector3(xs[3], 0, 0.6)
	check(KhoRules.step_chase(cf, c, p, Vector3(4, 0, 0), 0.03) == "" and c.dir == 1, "he takes his direction with his first run")
	check(KhoRules.step_chase(cf, c, p + Vector3(1, 0, 0), Vector3(3, 0, 1.5), 0.03) == "", "sideways along his shoulder line is no foul")
	check(KhoRules.step_chase(cf, c, p + Vector3(1.2, 0, 0), Vector3(-2.0, 0, 0), 0.03) == KhoRules.FOUL_TURN, "turning back is a foul")
	check(not KhoRules.touch_counts(cf, c, p, p + Vector3(0.3, 0, 0.2)), "a defender touched during a foul is not out")
	for i in 40:
		KhoRules.step_chase(cf, c, p + Vector3(1.0 + i * 0.1, 0, 0), Vector3(3.5, 0, 0), 0.03)
	check(c.foul == KhoRules.FOUL_TURN, "running his proper way again does not end the foul")
	KhoRules.step_chase(cf, c, Vector3(cf.pole_gap * 0.5 + 0.4, 0, 0.5), Vector3(3, 0, 0), 0.03)
	check(c.foul == "", "the free zone puts it right")
	c.reset_at(xs[3], 1)
	check(c.foul == "", "and so does a kho: the new chaser starts clean")
	check(KhoRules.touch_counts(cf, Chase_new_clean(cf), p, p + Vector3(0.3, 0, 0.2)), "a touch counts once the foul is put right")
	# The lane: he may not cross it between the poles.
	var c2 := KhoRules.Chase.new()
	c2.reset_at(0.0, 1)
	c2.dir = 1
	check(KhoRules.step_chase(cf, c2, Vector3(1, 0, -0.5), Vector3(1, 0, -2), 0.03) == KhoRules.FOUL_LANE, "crossing the central lane is a foul")
	check(not KhoRules.touch_counts(cf, c2, Vector3(1, 0, 0.6), Vector3(1.3, 0, -0.9)), "he may not touch a defender across the lane")
	# The free zone: round the pole, either way, either side.
	var c3 := KhoRules.Chase.new()
	c3.reset_at(0.0, 1)
	c3.dir = 1
	var pz := Vector3(cf.pole_gap * 0.5 + 0.5, 0, -0.5)
	check(KhoRules.in_free_zone(cf, pz), "behind the pole is the free zone")
	check(KhoRules.step_chase(cf, c3, pz, Vector3(-2, 0, -3), 0.03) == "", "in the free zone he may go any way")
	check(c3.dir == -1 and c3.half == -1, "round the pole he comes out the other way, on the other side")
	var out_p := Vector3(cf.pole_gap * 0.5 - 0.3, 0, -0.05)
	check(KhoRules.step_chase(cf, c3, out_p, Vector3(-2, 0, 3), 0.03) == "", "coming out of the free zone on the lane line is no foul")
	KhoRules.step_chase(cf, c3, out_p + Vector3(-0.3, 0, 0.6), Vector3(-2, 0, 2), 0.03)
	check(c3.half == 1, "his side is the one he takes once clear of the lane")
	check(KhoRules.step_chase(cf, c3, out_p + Vector3(-0.6, 0, -0.6), Vector3(-2, 0, -3), 0.03) == KhoRules.FOUL_LANE, "then crossing back is a foul")
	# The wazir: free of the direction rule, not of the lane.
	var c4 := KhoRules.Chase.new()
	c4.reset_at(0.0, 1, true)
	c4.dir = 1
	check(KhoRules.step_chase(ff, c4, Vector3(1, 0, 1), Vector3(-4, 0, 0), 0.03) == "", "the wazir may turn back")
	check(KhoRules.step_chase(ff, c4, Vector3(1, 0, -0.5), Vector3(0, 0, -3), 0.03) == KhoRules.FOUL_LANE, "the wazir may not cross the lane")
	# The kho: from behind, before passing the cross lane, within reach.
	var c5 := KhoRules.Chase.new()
	c5.reset_at(xs[0], 1)
	c5.dir = 1
	var face := KhoRules.square_face(4)   # the side that seated chaser faces
	var behind := Vector3(xs[4] - 0.3, 0, -float(face) * 0.55)
	c5.half = -face
	check(KhoRules.kho_check(cf, c5, behind, xs[4], face) == "ok", "a kho from behind, before his cross lane")
	check(KhoRules.kho_check(cf, c5, Vector3(xs[4] - 0.3, 0, float(face) * 0.55), xs[4], face) == "front", "no kho from in front of him")
	check(KhoRules.kho_check(cf, c5, Vector3(xs[4] + 0.5, 0, -float(face) * 0.55), xs[4], face) == "late", "past his cross lane it is a late kho")
	check(KhoRules.kho_check(cf, c5, Vector3(xs[4] - 2.0, 0, -float(face) * 0.55), xs[4], face) == "far", "out of reach is no kho")
	# Outs and limits.
	check(KhoRules.out_of_limits(cf, Vector3(0, 0, 8.2)), "past the side line is out of the limits")
	check(not KhoRules.out_of_limits(cf, Vector3(0, 0, 7.99)), "on the line is in")
	check(not KhoRules.out_of_limits(cf, Vector3(13.4, 0, 0)), "the free zone is inside the limits")
	check(KhoRules.out_of_limits(cf, Vector3(13.6, 0, 0)), "past the end line is out")
	# Scoring.
	check(KhoRules.points_for_out(KhoRules.CLASSIC) == 1 and KhoRules.points_for_out(KhoRules.FAST) == 2, "1 point an out classic, 2 fast")
	check(KhoRules.dream_points(KhoRules.FAST, 179.0) == 0 and KhoRules.dream_points(KhoRules.FAST, 180.0) == 1, "a dream run point at three minutes")
	check(KhoRules.dream_points(KhoRules.FAST, 209.0) == 1 and KhoRules.dream_points(KhoRules.FAST, 210.0) == 2 and KhoRules.dream_points(KhoRules.FAST, 245.0) == 3, "another every 30 s")
	check(KhoRules.dream_points(KhoRules.CLASSIC, 400.0) == 0, "no dream runs in the classic game")
	check(KhoRules.real_turn(KhoRules.CLASSIC) == 540.0 and KhoRules.real_turn(KhoRules.FAST) == 420.0, "turns of 9 and 7 minutes")
	# Batches.
	var order := ["a", "b", "c", "d", "e", "f", "g", "h", "i"]
	check(KhoRules.batch(order, 0) == ["a", "b", "c"] and KhoRules.batch(order, 2) == ["g", "h", "i"], "batches of three in order")
	check(KhoRules.batch(order, 3) == ["a", "b", "c"], "after the last batch the order starts again")
	check(KhoRules.late_entry(KhoRules.CLASSIC, 2.0, 1) and not KhoRules.late_entry(KhoRules.CLASSIC, 20.0, 0), "classic: late if a kho is given before they are in")
	check(KhoRules.late_entry(KhoRules.FAST, 31.0, 0) and not KhoRules.late_entry(KhoRules.FAST, 29.0, 3), "fast: 30 seconds to come on")
	# Turns, the follow-on, the end.
	check(KhoRules.chase_order(0) == [0, 1, 0, 1], "turns alternate")
	check(KhoRules.chase_order(1, true) == [1, 0, 0, 1], "the follow-on: the side behind chases twice running")
	check(KhoRules.follow_on_lead(KhoRules.CLASSIC, 540.0) == 9, "the follow-on at 9 points")
	check(KhoRules.can_follow_on(KhoRules.CLASSIC, 540.0, 0, [14, 5]) and not KhoRules.can_follow_on(KhoRules.CLASSIC, 540.0, 0, [13, 5]), "a lead of 9 or more")
	check(not KhoRules.can_follow_on(KhoRules.FAST, 420.0, 0, [40, 2]), "no follow-on in the fast game")
	check(KhoRules.over_after(2, [0, 1, 1, 0], [20, 15]), "after the follow-on, still behind: over without the last chase")
	check(not KhoRules.over_after(2, [0, 1, 1, 0], [20, 22]), "after the follow-on, ahead: the last chase is played")
	check(not KhoRules.over_after(2, [0, 1, 0, 1], [20, 5]), "without it, all four turns")
	check(KhoRules.winner([10, 10]) == -1 and KhoRules.winner([11, 10]) == 0, "the winner by points; a tie")
	check(KhoRules.min_chase_winner([42.0, 55.0]) == 0 and KhoRules.min_chase_winner([-1.0, 80.0]) == 1, "minimum chase: the quicker first out wins")
	check(KhoRules.min_chase_winner([30.0, 30.0]) == -1, "minimum chase level: another")


static func Chase_new_clean(_f: Dictionary) -> KhoRules.Chase:
	var c := KhoRules.Chase.new()
	c.reset_at(0.0, 1)
	return c


func _sim() -> void:
	# Equal sides get about 1.3 outs a minute: a 9-minute classic turn about 12, as the 2026 finals had.
	var total := 0
	var n := 200
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		total += int(Sim.turn(rng, KhoRules.CLASSIC, 540.0, 80.0, 80.0)[0])
	var mean := float(total) / n
	check(mean > 10.0 and mean < 13.5, "equal sides: %.1f outs a 9-minute turn" % mean)
	var r := Sim.play("IND", "JPN", KhoRules.FAST, 420.0, false, false, 3)
	check(int(r.score[0]) > int(r.score[1]), "the stronger side wins by far (%s)" % str(r.score))
	var ko := Sim.play("MAH", "MAH", KhoRules.CLASSIC, 540.0, false, true, 9)
	check(int(ko.winner) >= 0, "a knockout match always has a winner")


# ---------------------------------------------------------------- the screens

func _screens() -> void:
	var screens := ["res://ui/main_menu.gd", "res://ui/match_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
		"res://ui/records_screen.gd", "res://ui/cup_screen.gd", "res://ui/licences_screen.gd", "res://ui/help_screen.gd",
		"res://ui/privacy_screen.gd"]
	for pair in Game.LANGUAGES:
		Game.settings.language = pair[0]
		TranslationServer.set_locale(pair[0])
		Game._size_theme()
		check(tr("GAME_TITLE") != "GAME_TITLE", "%s: translations load" % pair[0])
		check(tr("BTN_KHO") != "BTN_KHO" and tr("BTN_KHO") != "", "%s: button labels" % pair[0])
		for path in screens:
			var s := Game.show_screen(path)
			await frames(3)
			check(is_instance_valid(s) and s.get_child_count() > 0, "%s: %s builds" % [pair[0], path])
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()
	await _legal_pages()
	# The home screen's menu: one row of six buttons, all on the screen, none over another (the owner's 0.3 ask).
	var home := Game.show_screen("res://ui/main_menu.gd")
	await frames(4)
	var row: HBoxContainer = home._row
	check(row.get_child_count() == 6, "home: six menu buttons in one row")
	var ys := {}
	var vis := get_viewport().get_visible_rect()
	var inside := true
	for b in row.get_children():
		var rr := (b as Control).get_global_rect()
		ys[roundi(rr.position.y)] = true
		inside = inside and vis.encloses(rr)
	check(ys.size() == 1 and inside, "home: the buttons in line and on the screen")
	var coin = preload("res://ui/match_setup.gd").Coin
	check(coin.currency("hi") == "₹" and coin.currency("ne") == "रू" and coin.currency("bn") == "৳" and coin.currency("si") == "රු",
		"the toss coin's tails is the value in the player's currency")
	# Labels on scrolling pages pass the touch to the scroll box (the How to Play lesson from Kabaddi Raid).
	for path in ["res://ui/howto_screen.gd", "res://ui/licences_screen.gd", "res://ui/settings_screen.gd", "res://ui/match_setup.gd",
			"res://ui/records_screen.gd", "res://ui/cup_screen.gd", "res://ui/help_screen.gd", "res://ui/privacy_screen.gd"]:
		var s := Game.show_screen(path)
		await frames(3)
		var bad := 0
		for sc in s.find_children("*", "ScrollContainer", true, false):
			for n in (sc as Node).find_children("*", "Control", true, false):
				if (n is Label or n is RichTextLabel) and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
					bad += 1
		check(bad == 0, "%s: no text in a scrolling page takes the touch (%d do)" % [path, bad])


# ---------------------------------------------------------------- the players' bodies

## The owner's model: the lighter mesh on Low and the fuller one above it, each in its side's kit; every clip there;
## seated chasers kneel, the active chaser runs his run, at a rate that keeps his feet with the ground.
## The owner's round after 0.9 (docs/PROGRESS.md, round ten): the dive lands and he gets up; the pole turn swings him
## round the pole and out faster; the camera changes at once, from a button by pause; difficulty in Quick match and
## the championships; the crowd turns to follow the play.
func _owner_round() -> void:
	# A dive: down flat, then up on his feet and running again, never left leaning in the air.
	var a := Athlete.new({"id": "t", "speed": 80}, 0)
	add_child(a)
	await frames(1)
	a.vel = Vector3(5.6, 0, 0)
	a.do("dive", 0.5)
	var flat := 0.0
	var acts := {}
	for i in 75:
		a.integrate(1.0 / 30.0)
		flat = maxf(flat, a.body.rotation.x)
		acts[a.act] = true
	check(flat > 1.3 and acts.has("lie") and acts.has("getup") and a.act == "" and absf(a.body.rotation.x) < 0.01,
		"a dive: down flat (%.2f rad), on the ground, up again (now '%s')" % [flat, a.act])
	# The pole turn: round the pole on its circle, out the far side at speed.
	a.position = Vector3(11.45, 0, 0)
	a.vel = Vector3(5.0, 0, 0)
	a.pole_swing(Vector3(12, 0, 0), 0.55, 0.55, PI, PI * 2.4, 5.0, 6.0)
	var off := 0.0
	var out_v := Vector3.ZERO
	var last := a.position
	var jump := 0.0
	for i in 30:
		a.integrate(1.0 / 30.0)
		jump = maxf(jump, (a.position - last).length() * 30.0)
		last = a.position
		if a.act == "pole_turn":
			off = maxf(off, absf((a.position - Vector3(12, 0, 0)).length() - 0.55))
		elif out_v == Vector3.ZERO:
			out_v = a.vel
	check(off < 0.05 and out_v.length() > 5.5 and out_v.x < 0.0 and jump < 7.5,
		"pole turn: on the circle (off by %.2f m), out back down the field at %.1f m/s, never faster than %.1f m/s" % [off, out_v.length(), jump])
	a.queue_free()
	# A match: the camera button beside pause; each tap a different view at once.
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "MAH", "away": "ODI", "venue": "school", "format": KhoRules.CLASSIC, "turn_len": 60.0,
		"user_team": 0, "seed": 2, "mode": "quick", "chase_first": 0, "test": true}
	add_child(m)
	await frames(30)
	check(m.hud and m.hud._cam_btn and m.hud._cam_btn.visible, "a camera button beside pause")
	var seen := {}
	for k in 3:
		seen[m.cam.global_position.snapped(Vector3(0.5, 0.5, 0.5))] = true
		m.hud._cam_btn.pressed.emit()
	check(seen.size() == 3, "three camera views, each different (%d)" % seen.size())
	await frames(20)
	check(Crowd.watch_target != Vector3.INF, "the crowd follows the play")
	m.queue_free()
	await frames(2)
	check(Crowd.watch_target == Vector3.INF, "and stops when the match ends")
	# Difficulty where you pick a match or a championship.
	Game.delete_cup()
	for path in ["res://ui/match_setup.gd", "res://ui/cup_screen.gd"]:
		var sc := Game.show_screen(path)
		await frames(3)
		var found := false
		for l in sc.find_children("*", "Label", true, false):
			found = found or (l as Label).text == tr("DIFFICULTY").to_upper() or (l as Label).text == tr("DIFFICULTY")
		check(found, "%s: the difficulty to choose" % path)


func _bodies() -> void:
	ModelBody.warm()
	for c in ModelBody.CLIPS:
		check(ResourceLoader.exists("res://assets/models/anims/%s.res" % c), "the %s clip is there" % c)
	for g in [Game.GFX_LOW, Game.GFX_HIGH]:
		var b := ModelBody.new({"jersey": Color("e63946"), "shorts": Color("1d3557"), "skin": Color("8d5a3b")}, g == Game.GFX_LOW)
		add_child(b)
		await frames(2)
		var meshes := []
		for mi in b.find_children("*", "MeshInstance3D", true, false):
			if not mi.is_queued_for_deletion():
				meshes.append(String(mi.name))
		check(meshes == (["player_lod1"] if g == Game.GFX_LOW else ["player_lod0"]), "graphics %d: the body draws %s" % [g, str(meshes)])
		var mat := (b.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).material_override as ShaderMaterial
		check(mat != null and mat.get_shader_parameter("albedo_tex") != null and Color(mat.get_shader_parameter("shirt")).is_equal_approx(Color("e63946")),
			"graphics %d: the kit's shirt is the side's colour, on the model's texture" % g)
		b.queue_free()
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "MAH", "away": "ODI", "venue": "maidan", "format": KhoRules.CLASSIC, "turn_len": 60.0, "user_team": -1,
		"seed": 12, "mode": "quick", "test": true}
	add_child(m)
	var kneel := 0
	var ran := false
	for k in 240:
		await frames(1)
		if m.phase != "play" or m.active == null:
			continue
		kneel = 0
		for a in m.squares:
			if a != m.active and a.act == "sit" and a.body.clip in ["kneel_down", "kneel"]:
				kneel += 1
		var spd: float = m.active.vel.length()
		if m.active.act == "" and spd > 4.0 and m.active.body.clip == "run":
			ran = ran or absf(m.active.body.anim.speed_scale - ModelBody.rate_for("run", spd)) < 0.01
	check(kneel >= m.squares.size() - 2, "seated chasers kneel (%d of %d)" % [kneel, m.squares.size()])
	check(ran, "the active chaser runs his run, at the rate his speed asks")
	m.queue_free()
	await frames(2)
	await _mocap()
	_sounds()


## Every recording the game asks for (docs/SOUNDS.md) is in assets/audio/ and loads as a sound; the beds loop; every
## sound the game plays by name is there once they are made; a pause holds the match's sounds.
func _sounds() -> void:
	var names: Array = Sfx.FILES.duplicate()
	for kind in Sfx.VOICES:
		for i in int(Sfx.VOICES[kind]):
			names.append("%s_%d" % [kind, i + 1])
	for kind in Sfx.TAKES:
		for i in int(Sfx.TAKES[kind]):
			names.append("%s_%d" % [kind, i + 1])
	var missing := []
	for n in names:
		var path := "res://assets/audio/%s.ogg" % n
		if not (ResourceLoader.exists(path) and load(path) is AudioStream):
			missing.append(n)
	check(missing.is_empty(), "every recording is there and loads (%d; missing %s)" % [names.size(), str(missing)])
	Sfx._ensure()
	var not_looping := []
	for k in Sfx.LOOPS:
		if not (Sfx.streams.get(k) is AudioStreamOggVorbis and (Sfx.streams[k] as AudioStreamOggVorbis).loop):
			not_looping.append(k)
	check(not_looping.is_empty(), "the beds and the music loop (%s)" % str(not_looping))
	var unmade := []
	for k in ["whistle_long", "whistle_short", "whistle_final", "whistle_double", "whistle_gym", "whoosh", "slap", "thud",
			"step_earth", "step_mat", "click"]:
		if not Sfx.streams.has(Sfx._take(k)):
			unmade.append(k)
	for kind in Sfx.AMBIENCE:
		if not Sfx.streams.has(Sfx.AMBIENCE[kind][0]):
			unmade.append(kind)
	check(unmade.is_empty(), "every sound the game plays by name is made (%s)" % str(unmade))
	Sfx._amb.stream = Sfx.streams["amb_crickets"]
	Sfx._amb.play()
	Sfx.pause(true)
	var held := Sfx._amb.stream_paused and Sfx.paused
	Sfx.pause(false)
	check(held and Sfx._amb.playing and not Sfx._amb.stream_paused, "a pause holds the match's sounds, and lets them go")
	Sfx.stop_all()


## The clips from the CMU motion capture library (docs/MODELS.md): each loads, carries its root (its travel over the
## ground, taken out of it), and through it no planted toe slides more than SLIDE_M; the dodge cuts the way it goes.
const SLIDE_M := 0.03

func _mocap() -> void:
	for c in ["dodge", "idle"]:
		var a: Animation = load("res://assets/models/anims/%s.res" % c)
		check(a != null and a.length > 0.3 and a.has_meta("root") and a.has_meta("fps"), "the %s clip loads, with its root" % c)
		if a == null or not a.has_meta("root"):
			continue
		var b := ModelBody.new({}, false)
		add_child(b)
		await frames(1)
		var root: PackedVector3Array = a.get_meta("root")
		var fps := float(a.get_meta("fps"))
		var toes := [b.skeleton.find_bone("mixamorig_LeftToeBase"), b.skeleton.find_bone("mixamorig_RightToeBase")]
		var paths := [[], []]
		b.play(c, 1.0, 0.0)
		for f in root.size():
			b.anim.seek(minf(f / fps, a.length), true)
			for k in 2:
				var p := b.skeleton.global_transform * b.skeleton.get_bone_global_pose(toes[k]).origin
				var r := root[f]
				paths[k].append(Vector3(r.x, 0, r.y) + Basis(Vector3.UP, r.z) * p)
		var worst := 0.0
		var contacts := 0
		for k in 2:
			var low := INF
			for p: Vector3 in paths[k]:
				low = minf(low, p.y)
			var f0 := -1
			var n: int = paths[k].size()
			for f in n + 1:
				# Planted: on the floor and nearly still (a foot skimming the floor as it swings is not).
				var down := false
				if f < n:
					var dv := (paths[k][mini(f + 1, n - 1)] as Vector3) - (paths[k][maxi(f - 1, 0)] as Vector3)
					down = (paths[k][f] as Vector3).y < low + 0.03 and Vector2(dv.x, dv.z).length() * fps / 2.0 < 0.8
				if down and f0 < 0:
					f0 = f
				elif not down and f0 >= 0:
					if f - f0 >= 2:
						contacts += 1
						for g in range(f0, f):
							var d := (paths[k][g] as Vector3) - (paths[k][f0] as Vector3)
							worst = maxf(worst, Vector2(d.x, d.z).length())
					f0 = -1
		check(contacts >= 2 and worst <= SLIDE_M, "%s: planted feet hold (%d contacts, worst slide %.1f cm)" % [c, contacts, worst * 100.0])
		b.queue_free()
	var ath := Athlete.new({}, 0, {})
	add_child(ath)
	await frames(1)
	ath.dodge(Vector3(1, 0, 0.3), 0.4)
	var to_left: bool = not ath.mirror
	ath.dodge(Vector3(-1, 0, 0.3), 0.4)
	var to_right: bool = ath.mirror
	for i in 20:
		ath.integrate(1.0 / 30.0)
	check(to_left and to_right and ath.act == "" and not ath.mirror, "a dodge cuts the way he goes, and his run after it is his own")
	ath.queue_free()



## Settings > About: Licences, Help and Privacy Policy are three buttons that open screens in the game (no link out:
## the game has no internet permission). Each one opens with a Back button, scrolls, and says what it must: the
## Godot Engine's licence and the assets' credits, the controls and contact, the policy's date and contact.
func _legal_pages() -> void:
	var st := Game.show_screen("res://ui/settings_screen.gd")
	await frames(3)
	var names := {}
	for b in st.find_children("*", "Button", true, false):
		names[(b as Button).text] = b
	for k in ["LICENCES", "HELP_SUPPORT", "PRIVACY_POLICY"]:
		check(names.has(tr(k)), "settings: a %s button" % tr(k))
	var src := FileAccess.get_file_as_string("res://ui/settings_screen.gd")
	check(not src.contains("shell_open"), "settings: nothing opens outside the game")
	var want := {
		"res://ui/licences_screen.gd": ["Godot Engine", "MIT", "mocap.cs.cmu.edu", "NSF EIA-0196217", "Kenney", "CC0",
			"OpenGameArt", "CC-BY 4.0", "Pixabay Content License", "charlesheffley009", "framptones", "freesound_community",
			"Poly Haven", "Meshy", "Mixamo", "SIL Open Font License"],
		"res://ui/help_screen.gd": [tr("HELP_PLAY"), tr("CTRL_KHO_TEXT"), tr("RULES_OUTS"), tr("GFX_LOW"), Game.CONTACT_EMAIL],
		"res://ui/privacy_screen.gd": [tr("PRIVACY_SUMMARY"), "Last updated", "internet", "vibration", Game.CONTACT_EMAIL],
	}
	for path in want:
		var s := Game.show_screen(path)
		await frames(3)
		var text := ""
		for n in s.find_children("*", "", true, false):
			if n is Label:
				text += (n as Label).text + "\n"
			elif n is RichTextLabel:
				text += (n as RichTextLabel).get_parsed_text() + "\n"
		var missing := []
		for w in want[path]:
			if not text.contains(String(w)):
				missing.append(w)
		check(text.length() > 600 and missing.is_empty(), "%s: not empty (%d characters), missing %s" % [path, text.length(), missing])
		check(s.find_children("*", "ScrollContainer", true, false).size() > 0, "%s: scrolls" % path)
		check(s.has_meta("back") and (s.get_meta("back") as Callable).is_valid(), "%s: a Back button (and the phone's back)" % path)

# ---------------------------------------------------------------- the grounds

## The shared assets round each ground (the graphics update): a photographed sky outdoors, the photo-scanned ground,
## the trees as cut-outs, the chairs and benches; on Low the light chairs, and only on the far side. Every spectator
## faces the play: his forward, flattened to the ground, toward the court's centre.
func _grounds() -> void:
	var keep_g := int(Game.settings.graphics)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for v in DB.venue_ids():
			var a := Arena.new(v, KhoRules.CLASSIC, [Color.RED])
			add_child(a)
			await frames(1)
			var we: WorldEnvironment = a.find_children("*", "WorldEnvironment", true, false)[0]
			var outdoor := a.kind != "arena"
			check((we.environment.sky != null) == outdoor, "graphics %d, %s: %s" % [g, v, "a photographed sky" if outdoor else "no sky indoors"])
			var mms := {}
			for mmi in a.find_children("*", "MultiMeshInstance3D", true, false):
				if mmi is Crowd:
					continue
				var mesh: Mesh = (mmi as MultiMeshInstance3D).multimesh.mesh
				mms[mesh.resource_name if mesh.resource_name != "" else str(mesh.get_instance_id())] = (mmi as MultiMeshInstance3D).multimesh.instance_count
			check(mms.size() >= (3 if outdoor else 1), "graphics %d, %s: the shared assets placed (%d kinds)" % [g, v, mms.size()])
			var people := 0
			var astray := 0
			for c in a.find_children("*", "Crowd", true, false):
				var cr := c as Crowd
				check(cr.xforms.size() == cr.multimesh.instance_count, "graphics %d, %s: a transform for every spectator" % [g, v])
				for x in cr.xforms:
					var t := cr.global_transform * x
					var fwd := Vector3(t.basis.z.x, 0.0, t.basis.z.z).normalized()
					var to_c := Vector3(-t.origin.x, 0.0, -t.origin.z).normalized()
					people += 1
					if fwd.dot(to_c) <= 0.7:
						astray += 1
			check(people > 0 and astray == 0, "graphics %d, %s: all %d spectators face the court (%d astray)" % [g, v, people, astray])
			# Dressed as a tournament ground (the two real matches, docs/GROUNDS.md); the crowd mostly in everyday clothes.
			var want: Array = [] if not outdoor else (["barricades", "banners", "flags"] + (["tents"] if a.kind != "stadium" else []) \
				+ (["stage", "scaffold"] if a.kind == "village" else []) \
				+ (["turf", "scaffold", "second court", "umbrella", "scoreboard"] if a.kind == "school" else []))
			var have: Array = a.dressing.duplicate()
			have.sort()
			want.sort()
			check(have == want, "graphics %d, %s: dressed with %s (want %s)" % [g, v, have, want])
			var everyday := 0
			for c in a.find_children("*", "Crowd", true, false):
				var mm: MultiMesh = (c as Crowd).multimesh
				for i in mm.instance_count:
					if mm.get_instance_custom_data(i).a > 0.0:
						everyday += 1
			check(people > 0 and float(everyday) / people > 0.7, "graphics %d, %s: %d of %d spectators in everyday clothes" % [g, v, everyday, people])
			if a.kind == "village":
				var chairs: int = a._chairs.size()
				check(chairs > 0 and (g != Game.GFX_LOW or chairs < 60), "graphics %d, village: chairs under the front row (%d)" % [g, chairs])
			a.queue_free()
			await frames(1)
	# The extra detail is for Medium and High only: Low loads what it always has.
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		var ground: Texture2D = Props.surface("dry_ground_01")[0]
		var want := 1024 if g == Game.GFX_LOW else 2048
		check(ground.get_width() == want and Crowd.figs() == (8 if g == Game.GFX_LOW else 16),
			"graphics %d: ground photos %d px (want %d), %d people in the crowd's sheet" % [g, ground.get_width(), want, Crowd.figs()])
	check(ModelBody._texture(true).get_width() == 512 and ModelBody._texture(false).get_width() == 2048,
		"the players' texture: 512 px on Low (unchanged), 2048 px on Medium and High")
	Game.settings.graphics = keep_g


# ---------------------------------------------------------------- championships

func _cups() -> void:
	for kind in Cup.KINDS:
		for women in [false, true]:
			var team: String = {"world": "IND", "national": "MAH", "league": "BBS"}[kind]
			var c: Cup = Game.new_cup(kind, team, women)
			if kind == "league":
				_league(c, women)
				continue
			check(c.teams.size() == 16 and team in c.teams, "%s: sixteen sides, yours among them" % kind)
			var guard := 0
			while c.stage != "done" and guard < 12:
				c.sim_round(true)
				guard += 1
			check(c.stage == "done" and c.champion != "", "%s %s: a champion (%s)" % [kind, "women" if women else "men", c.champion])
			for g in 4:
				var tb := c.group_table(g)
				var pts := 0
				for row in tb:
					check(int(row.p) == 3, "%s: three group matches each" % kind)
					pts += int(row.pts)
				check(pts == 12, "%s: a group's points add up to 2 a match (%d)" % [kind, pts])
			check(c.ko_results.size() == 7, "%s: seven knockout matches" % kind)
			Game.save_cup()
			Game.cup = null
			var back = Game.get_cup()
			check(back != null and back.champion == c.champion, "%s: saves and loads" % kind)


## The city league: eight sides, each plays the others home and away (14 rounds), the franchise league's points,
## then 1st v 4th and 2nd v 3rd and the final.
func _league(c: Cup, women: bool) -> void:
	check(c.teams.size() == 8 and c.sched.size() == 14, "league: eight sides, fourteen rounds")
	# The playtest found Punjab among the cities: Pune's code was Punjab's (PUN). Every side's code is its own.
	var codes := {}
	for id in DB.nation_ids() + DB.state_ids() + DB.club_ids():
		codes[id] = int(codes.get(id, 0)) + 1
	var twice := codes.keys().filter(func(k): return codes[k] > 1)
	check(twice.is_empty(), "every side's code is its own (%s)" % str(twice))
	for id in c.teams:
		check(DB.is_club(id) and not DB.is_state(id), "league: %s is a city side" % id)
	var met := {}
	for rnd in c.sched:
		var playing := {}
		for pr in rnd:
			check(not playing.has(pr[0]) and not playing.has(pr[1]), "league: no side twice in a round")
			playing[pr[0]] = true
			playing[pr[1]] = true
			met["%s|%s" % [pr[0], pr[1]]] = true
	check(met.size() == 56, "league: every side at home to every other once (%d)" % met.size())
	check(Sim.league_points(30, 20) == 3 and Sim.league_points(20, 20) == 2 and Sim.league_points(18, 20) == 1 and Sim.league_points(10, 20) == 0,
		"league points: 3 a win, 2 a tie, 1 for losing by 3 or fewer")
	var guard := 0
	while c.stage != "done" and guard < 30:
		c.sim_round(true)
		guard += 1
	check(c.stage == "done" and c.champion != "", "league %s: a champion (%s)" % ["women" if women else "men", c.champion])
	for row in c.group_table(0):
		check(int(row.p) == 14, "league: fourteen matches each (%d)" % int(row.p))
	check(c.ko_results.size() == 3, "league: two semi-finals and the final")
	var top4 := []
	for row in c.group_table(0).slice(0, 4):
		top4.append(row.id)
	for r in c.ko_results:
		check(r[1] in top4 and r[2] in top4, "league: the knockouts are the top four's")
	Game.save_cup()
	Game.cup = null
	check(Game.get_cup() != null and Game.get_cup().sched.size() == 14, "league: saves and loads")


# ---------------------------------------------------------------- matches

func _matches() -> void:
	var cases := [[KhoRules.CLASSIC, "MAH", "ODI", "maidan", 90.0, false], [KhoRules.FAST, "IND", "NEP", "arena", 200.0, false],
		[KhoRules.CLASSIC, "KAR", "KER", "floodlit", 30.0, true]]
	for c in cases:
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": c[1], "away": c[2], "venue": c[3], "format": c[0], "turn_len": c[4], "user_team": -1,
			"seed": 77, "mode": "quick", "test": true, "knockout": c[5], "chase_first": 0}
		add_child(m)
		var audit := MotionAudit.new(m)
		add_child(audit)
		var res: Dictionary = await m.finished
		var outs := 0
		var pts_check := [0, 0]
		for e in res.log:
			if e.kind == "out":
				outs += 1
				var who := int(res.stats[e.who].side)
				pts_check[1 - who] += int(e.pts)
			elif e.kind == "dream":
				pts_check[int(e.side)] += int(e.pts)
		check(outs > 0, "%s: defenders were put out (%d)" % [c[1], outs])
		check(pts_check == res.score, "%s: the score is the outs and the dream runs (%s v %s)" % [c[1], str(pts_check), str(res.score)])
		check(res.turns.size() >= 3, "%s: the turns were played (%d)" % [c[1], res.turns.size()])
		if c[5]:
			check(int(res.winner) >= 0, "a knockout match has a winner")
		var khos := 0
		for e in res.log:
			if e.kind == "kho":
				khos += 1
		check(khos > 5, "%s: the chase was passed on with khos (%d)" % [c[1], khos])
		if c[0] == KhoRules.FAST:
			var pp := 0
			for e in res.log:
				if e.kind == "powerplay":
					pp += 1
			check(pp >= 1 and pp <= res.turns.size(), "fast: a power play a turn at most (%d)" % pp)
		audit.report(self, String(c[1]))
		m.queue_free()
		audit.queue_free()
		await frames(2)


## Your controls, as the buttons send them: KHO from behind a seated chaser hands you the chase (you are then him);
## DIVE dives; defending, the buttons are DODGE and SWITCH and SWITCH changes your defender.
func _your_controls() -> void:
	Game.settings.lane_assist = true
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "MAH", "away": "ODI", "venue": "school", "format": KhoRules.CLASSIC, "turn_len": 60.0, "user_team": 0,
		"seed": 5, "mode": "quick", "test": true, "chase_first": 0}
	add_child(m)
	var guard := 0
	while m.phase != "play" and guard < 200:
		await frames(1)
		guard += 1
	await frames(3)
	check(m.phase == "play", "your match starts")
	check(m.controls.ids.has("KHO") and m.controls.ids.has("DIVE"), "chasing, your buttons are KHO and DIVE (%s)" % str(m.controls.ids))
	# Put your chaser just behind a seated chaser whose back is to his side (a test may place him; play never does).
	var f: Dictionary = m.f
	var i := 2
	var face: int = m.sq_face[i]
	m.chase.half = -face
	m.chase.dir = 1
	m.chase.settled = true
	m.active.position = Vector3(float(f.square_x[i]) - 0.3, 0, -float(face) * 0.55)
	m.active.vel = Vector3.ZERO
	var before: Athlete = m.active
	await frames(2)
	check(m._kho_target(false) == i, "his square is the kho you can give (%d)" % m._kho_target(false))
	m._on_action("KHO")
	await frames(12)
	check(m.active != before, "KHO hands you the chase: you are the one who rose")
	check(m.chase.half == face, "you rise on the side he faced")
	# A thumb pushing at the lane (at the next seated chaser's back) runs you along it at speed, never a crawl.
	for k in 45:
		m.controls.joystick = Vector2(0.3, -float(m.chase.half)).normalized()
		await frames(1)
	check(absf(m.active.vel.x) > 5.0, "pushing at the lane runs you along it (%.1f m/s)" % absf(m.active.vel.x))
	check(m.chase.foul == "", "and keeps you legal")
	m.controls.joystick = Vector2.ZERO
	# KHO a moment early, running flat out at the next seated chaser: he brakes into his back and gives it.
	var j: int = -1
	for k in m.squares.size():
		if int(m.sq_face[k]) == -m.chase.half and k > i + 1:
			j = k
			break
	if j >= 0:
		var giver: Athlete = m.active
		m.chase.dir = 1
		m.active.position = Vector3(float(f.square_x[j]) - 3.0, 0, float(m.chase.half) * 0.6)
		m.active.vel = Vector3(7.5, 0, 0)
		await frames(1)
		m._on_action("KHO")
		for k in 40:
			m.controls.joystick = Vector2(1, 0)
			await frames(1)
		check(m.active != giver and m.chase.half == int(m.sq_face[j]), "KHO pressed 3 m early at full speed still gives the kho")
		check(m.chase.foul == "", "and it is not a late kho")
		m.controls.joystick = Vector2.ZERO
	await frames(20)
	m.active.position = Vector3(float(f.square_x[4]), 0, float(m.chase.half) * 3.0)
	m.active.vel = Vector3.ZERO
	await frames(2)
	m._dive_cool = 0.0
	m._on_action("DIVE")
	await frames(2)
	check(m.active.act == "dive" or m.active.act == "pole_dive", "DIVE dives (%s)" % m.active.act)
	m.queue_free()
	await frames(2)
	var d: Node = (load("res://game/match.gd") as Script).new()
	d.config = {"home": "MAH", "away": "ODI", "venue": "school", "format": KhoRules.CLASSIC, "turn_len": 60.0, "user_team": 0,
		"seed": 6, "mode": "quick", "test": true, "chase_first": 1}
	add_child(d)
	guard = 0
	while d.phase != "play" and guard < 200:
		await frames(1)
		guard += 1
	await frames(3)
	check(d.controls.ids.has("DODGE") and d.controls.ids.has("SWITCH"), "defending, your buttons are DODGE and SWITCH (%s)" % str(d.controls.ids))
	var was: Athlete = d.user_def
	d._on_action("SWITCH")
	check(d.user_def != null and d.user_def != was, "SWITCH takes another defender")
	d.controls.joystick = Vector2(1, 0)
	var x0: float = d.user_def.position.x
	await frames(20)
	check(d.user_def.position.x > x0 + 1.0, "the joystick runs your defender (%.1f m)" % (d.user_def.position.x - x0))
	d.controls.joystick = Vector2.ZERO
	await frames(3)
	check(not d._user_auto(), "just let go, he is still yours")
	await frames(20)
	check(d._user_auto(), "thumb off the stick for half a second: your defender runs himself")
	var seen := false
	for k in 40:
		await frames(1)
		seen = seen or d.user_def == null or d.user_def.want.length() > 0.5 or d.user_def.vel.length() > 0.5
	check(seen, "and he moves (as the AI would)")
	d.controls.joystick = Vector2(0, 1)
	await frames(2)
	check(not d._user_auto(), "the stick takes him back at once")
	# Run him at the side line, thumb held: with the assist on he pulls up inside it.
	var ud: Athlete = d.user_def
	var far_x: float = -signf(d.active.position.x + 0.01) * d.f.pole_gap * 0.4
	ud.position = Vector3(far_x, 0.0, -d.f.width * 0.5 + 2.0)
	ud.vel = Vector3.ZERO
	d.controls.joystick = Vector2(0, -1)
	var stayed := true
	for k in 90:
		await frames(1)
		if d.user_def != ud:
			stayed = false
			break
	check(stayed and d.d_state.get(ud, "") == "in" and absf(ud.position.z) < d.f.width * 0.5,
		"your defender held at the side line pulls up inside it (z %.2f)" % ud.position.z)
	# DODGE (the owner: "doesn't seem to work"): a side-step you can see, and a touch in it mostly slips off.
	var dd: Athlete = d.user_def
	dd.vel = Vector3.ZERO
	d.controls.joystick = Vector2.ZERO
	var at0: Vector3 = dd.position
	d._on_action("DODGE")
	check(d.dodging(), "DODGE starts a side-step")
	await frames(10)
	var moved := (dd.position - at0).length()
	check(moved > 1.0, "DODGE from standing moves him over a metre in a third of a second (%.2f m)" % moved)
	var slips := 0
	for k in 40:
		d._ai[dd].erase("slip_until")
		d._dodge_until = d.t_match + 0.3
		if d._swerves(dd, KhoRules.OUT_TOUCH):
			slips += 1
	check(slips >= 30, "a touch in the side-step slips off him (%d of 40)" % slips)
	d._dodge_until = -1.0
	d._on_action("DODGE")
	check(not d.dodging(), "DODGE waits for its cool-down before the next")
	d._dodge_ready = 0.0
	# The playtest's worst find: a new batch walking on with your thumb held away from the field never came in and
	# was out for a late entry, batch after batch (53-2). Walking on is his own now.
	for a in d.batch:
		d.d_state[a] = "out"
	d._next_batch()
	var away: Vector3 = d.user_def.position.normalized()
	d.controls.joystick = Vector2(away.x, away.z).normalized()
	var all_in := false
	for k in 200:
		await frames(1)
		all_in = true
		for a in d.batch:
			all_in = all_in and d.d_state.get(a, "") == "in"
		if all_in:
			break
	check(all_in, "a new batch walks on even with your thumb held away from the field")
	d.controls.joystick = Vector2.ZERO
	d.queue_free()
	await frames(2)
	# Watching a match (no side yours), the pause button is there, and the pause menu quits it.
	var w: Node = (load("res://game/match.gd") as Script).new()
	w.config = {"home": "KAR", "away": "KER", "venue": "maidan", "format": KhoRules.CLASSIC, "turn_len": 60.0, "user_team": -1,
		"seed": 9, "mode": "quick", "test": true}
	add_child(w)
	await frames(5)
	check(w.hud._pause_btn.visible, "watching a match, the pause button shows")
	w.set_paused(true)
	await frames(2)
	var labels := []
	for b in w.hud._pause.find_children("*", "Button", true, false):
		labels.append((b as Button).text)
	check(labels.has(tr("QUIT_MATCH")) and not labels.has(tr("MOVE_BUTTONS")), "and its pause menu has Quit match (%s)" % str(labels))
	w.queue_free()
	await frames(2)


## Watches every player each frame: nothing moves further in one frame than his speed allows (no snaps), speed
## changes within what a body can do, and the stride keeps pace with the ground (Kabaddi Raid's motion audit).
class MotionAudit extends Node:
	var m
	var last := {}
	var snaps := 0
	var jerks := 0
	var worst := 0.0
	var frames_seen := 0
	var safe_t := 0.0    # defenders out of danger (the chase over 3.2 s away): their time, and the part of it standing
	var safe_still := 0.0

	func _init(p_m) -> void:
		m = p_m

	func _process(delta: float) -> void:
		if m == null or not is_instance_valid(m) or m.phase != "play":
			last.clear()
			return
		frames_seen += 1
		if m.active != null:
			for d in m.batch:
				if m.d_state.get(d, "") == "in" and m.reach_time(d.position) > m.SAFE_S:
					safe_t += delta
					if Vector2(d.vel.x, d.vel.z).length() < 0.5:
						safe_still += delta
		for a in m.roster[0] + m.roster[1]:
			var p: Vector3 = a.position
			if last.has(a):
				var prev: Array = last[a]
				var step := (p - (prev[0] as Vector3)).length()
				var v := step / maxf(delta, 0.001)
				if v > 11.0:
					snaps += 1
				var dv := absf(v - float(prev[1]))
				if dv / maxf(delta, 0.001) > 40.0 and not (a.act in ["dive", "pole_dive"]):
					jerks += 1
				worst = maxf(worst, v)
				last[a] = [p, v]
			else:
				last[a] = [p, 0.0]

	func report(t, name: String) -> void:
		t.check(frames_seen > 100, "%s: the motion audit watched the play (%d frames)" % [name, frames_seen])
		t.check(snaps == 0, "%s: no player snaps (%d frames over 11 m/s; fastest %.1f m/s)" % [name, snaps, worst])
		t.check(jerks <= frames_seen / 200, "%s: speeds change smoothly (%d jerks)" % [name, jerks])
		# As in the real matches watched (docs/AI.md): a defender out of danger stands and watches.
		if safe_t > 5.0:
			t.check(safe_still / safe_t > 0.6, "%s: defenders out of danger stand still (%.0f%% of %.0f s)" % [name, 100.0 * safe_still / safe_t, safe_t])
