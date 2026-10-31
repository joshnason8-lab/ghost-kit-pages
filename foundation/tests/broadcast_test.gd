extends SceneTree
## The broadcast layer: the director's close-up finds a way round a body standing in its line (and keeps to the
## camera's side of the play), runs its shots for at least MIN_HOLD each and hands the picture back; a lower third
## comes on inside the screen and goes; the score bug shows the score in the game's form; the tiers that cut away.
##   godot --headless --path . --fixed-fps 30 -s tests/broadcast_test.gd

func _initialize() -> void:
	var fails := []
	var ch := WsgBody.load_character("res://tests/character", "hero")
	var scorer := WsgBody.new(ch)
	root.add_child(scorer)
	var blocker := WsgBody.new(ch)
	root.add_child(blocker)
	var live := Camera3D.new()
	root.add_child(live)
	live.position = Vector3(0, 12, 30)
	live.current = true
	var d := WsgDirector.new()
	root.add_child(d)
	await process_frame
	# The blocker right in the first choice's line (between the scorer and the live camera's side).
	blocker.position = Vector3(0, 0, 1.6)
	var way := d._clear_bearing(scorer, Vector3.BACK, 4.2, 1.45)
	print("close-up with a body in the line: %.0f degrees round, %.1f m up" % [rad_to_deg(way[0]), way[1]])
	if is_zero_approx(way[0]) and is_zero_approx(way[1]):
		fails.append("the close-up did not go round the body in its line")
	if absf(rad_to_deg(way[0])) > 50.0:
		fails.append("the close-up crossed the line")
	blocker.position = Vector3(8, 0, -8)
	var clear := d._clear_bearing(scorer, Vector3.BACK, 4.2, 1.45)
	if not is_zero_approx(clear[0]) or not is_zero_approx(clear[1]):
		fails.append("with nobody in the way the close-up still moved: %s" % [clear])
	# The shots run, each held at least MIN_HOLD, then the live camera has the picture again.
	var f0 := Engine.get_process_frames()
	await d.run([{"shot": "close", "target": scorer, "secs": 0.2}, {"shot": "crowd", "at": Vector3(0, 6, -40), "secs": 0.3}], live)
	var secs := (Engine.get_process_frames() - f0) / 30.0
	print("two shots asked 0.2 and 0.3 s: ran %.1f s (each at least %.1f); live camera current again: %s" % [secs, WsgDirector.MIN_HOLD, live.current])
	if secs < WsgDirector.MIN_HOLD * 2.0 - 0.2 or not live.current:
		fails.append("shots: %.1f s, live %s" % [secs, live.current])
	# A lower third: on, inside the screen, then off.
	# (In a 1280 x 720 picture: the headless window is 64 pixels.)
	var screen := SubViewport.new()
	screen.size = Vector2i(1280, 720)
	root.add_child(screen)
	var layer := CanvasLayer.new()
	screen.add_child(layer)
	var lt := WsgLowerThird.new()
	layer.add_child(lt)
	lt.show_card("Tomás Ó Briain", "1-02 today", Color.GOLD, 0.6)
	for i in 20:
		await process_frame
	var box: Control = lt._box
	var vp := lt.get_viewport_rect()
	var inside := vp.encloses(Rect2(box.position, box.size))
	print("lower third on: %s at %s (screen %s)" % [inside, box.position, vp.size])
	await create_timer(1.2).timeout
	var gone := box.position.x + box.size.x <= 0.0 or box.modulate.a < 0.05
	print("and gone: %s" % gone)
	if not inside or not gone:
		fails.append("lower third: on %s, off %s" % [inside, gone])
	# The score bug.
	var bug := WsgScorebug.new()
	layer.add_child(bug)
	bug.setup(["KIL", Color.BLACK, Color.GOLD], ["TIP", Color.BLUE, Color.GOLD])
	bug.set_score("0-00", "0-00")
	bug.set_score("1-07", "0-09")
	bug.set_clock("23:41", "1st half")
	var shown: String = (bug._rows[0][2] as Label).text + " " + (bug._rows[1][2] as Label).text
	print("score bug: %s" % shown)
	if shown != "1-07 0-09":
		fails.append("score bug shows %s" % shown)
	# The tiers that cut away: not a budget phone's Low.
	WsgFoundation.profile = "budget"
	WsgFoundation.tier = WsgFoundation.LOW
	var low := WsgDirector.packages()
	WsgFoundation.tier = WsgFoundation.MEDIUM
	var med := WsgDirector.packages()
	WsgFoundation.profile = "premium"
	print("cut-aways: budget Low %s, budget Medium %s" % [low, med])
	if low or not med:
		fails.append("packages by tier: %s %s" % [low, med])
	for f in fails:
		printerr("FAIL: ", f)
	print("BROADCAST TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
