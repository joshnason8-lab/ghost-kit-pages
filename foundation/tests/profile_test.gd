extends SceneTree
## The game profiles (WsgFoundation): which phones start on which tier (the phone decides), what the 3D crowd and
## the full-detail bodies may cost at each.
##   godot --headless --path . -s tests/profile_test.gd

func _initialize() -> void:
	var fails := []
	# Phones: [GPU, memory GB, class]. A Galaxy A16 (Mali-G57 MC2 or Adreno 610, 4 GB) is the weak end, as Hurling's
	# players' phones taught it; a mid-range phone (Adreno 620-63x, Mali-G7x with 6 GB+) the middle.
	var phones := [["Mali-G57 MC2", 4.0, -1], ["Adreno (TM) 610", 4.0, -1], ["Adreno (TM) 506", 3.0, -1],
		["Mali-G52 MC2", 6.0, -1], ["PowerVR Rogue GE8320", 2.0, -1], ["Adreno (TM) 750", 12.0, 1],
		["Mali-G715-Immortalis MC11", 12.0, 1], ["Adreno (TM) 619", 6.0, -1], ["Adreno (TM) 620", 6.0, 0], ["Mali-G77 MC9", 8.0, 0],
		["Xclipse 940", 8.0, 1], ["Adreno (TM) 740", 4.0, -1]]
	for p in phones:
		var c := WsgFoundation.device_class(p[0], p[1])
		print("%-28s %4.1f GB: class %+d" % [p[0], p[1], c])
		if c != int(p[2]):
			fails.append("%s %.0f GB: class %d, want %d" % [p[0], p[1], c, p[2]])
	# The phone decides where it starts: weak Low, a flagship High (a budget game too: the owner's "a new phone and
	# Kabaddi: high quality"), the rest the game's default; every tier can be chosen.
	var starts := {"premium": {"Mali-G57 MC2": 0, "Adreno (TM) 620": 1, "Adreno (TM) 750": 2},
		"budget": {"Mali-G57 MC2": 0, "Adreno (TM) 620": 0, "Adreno (TM) 750": 2}}
	for prof in ["premium", "budget"]:
		WsgFoundation.profile = prof
		var s := WsgFoundation.spec()
		var got := {}
		for gpu in starts[prof]:
			var c := WsgFoundation.device_class(gpu, 4.0 if gpu.begins_with("Mali") else 8.0)
			got[gpu] = WsgFoundation.tier_for_class(c)
			if got[gpu] != int(starts[prof][gpu]):
				fails.append("%s: %s starts on %d, want %d" % [prof, gpu, got[gpu], starts[prof][gpu]])
		var bodies := []
		for t in [0, 1, 2]:
			WsgFoundation.tier = t
			bodies.append(WsgFoundation.full_bodies())
		print("%-7s: renderer %s; starts %s; crowd Medium %s, High %s, Close %s; bodies in full by tier %s" % [
			prof, s.renderer, got, WsgFoundation.crowd_budget(1), WsgFoundation.crowd_budget(2), WsgFoundation.crowd_budget(3), bodies])
		if WsgFoundation.allowed(WsgFoundation.HIGH) != WsgFoundation.HIGH:
			fails.append("%s: High cannot be chosen" % prof)
		if prof == "budget":
			if int(s.default) != WsgFoundation.LOW or s.renderer != "gl_compatibility":
				fails.append("budget: Low for an ordinary phone, GL Compatibility")
			if (WsgFoundation.crowd_budget(1) as Array)[0] > 150 or int(bodies[1]) > 6:
				fails.append("budget Medium: more than 150 full 3D fans or 6 full bodies")
		elif int(s.default) != WsgFoundation.MEDIUM:
			fails.append("premium: Medium for an ordinary phone")
	WsgFoundation.tier = WsgFoundation.MEDIUM
	# Full detail for the nearest bodies only.
	WsgFoundation.profile = "budget"
	var bodies := []
	for i in 10:
		var b := WsgBody.new()
		root.add_child(b)
		b.position = Vector3(i * 3.0, 0, 0)
		bodies.append(b)
	await process_frame
	WsgFoundation.rank_detail(bodies, Vector3.ZERO)
	var full := bodies.filter(func(b): return (b as WsgBody).full).size()
	print("budget: %d of 10 bodies in full detail, the nearest: %s" % [full, (bodies[0] as WsgBody).full and not (bodies[9] as WsgBody).full])
	if full != WsgFoundation.full_bodies() or not (bodies[0] as WsgBody).full or (bodies[9] as WsgBody).full:
		fails.append("rank_detail: %d in full" % full)
	WsgFoundation.profile = "premium"
	# Lowering the graphics by itself (WsgAutoTier): a steady 60 never; a steady 30 within a few seconds; a phone at
	# 55 on average with a tenth of a second's hitch three times a second within a few seconds too; never in the
	# moments after a reset (loading).
	var cases := {"steady 60": [1.0 / 60.0, 0, false], "steady 30": [1.0 / 30.0, 0, true], "hitching": [1.0 / 60.0, 20, true]}
	for k in cases:
		var at := WsgAutoTier.new()
		var t := 0.0
		var stepped := -1.0
		var i := 0
		while t < 12.0 and stepped < 0.0:
			var dt: float = cases[k][0]
			if int(cases[k][1]) > 0 and i % int(cases[k][1]) == 0:
				dt = 0.1
			t += dt
			i += 1
			if at.feed(dt):
				stepped = t
		print("auto tier, %s: %s" % [k, ("steps down at %.1f s" % stepped) if stepped >= 0.0 else "stays"])
		if (stepped >= 0.0) != bool(cases[k][2]) or stepped > 6.0:
			fails.append("auto tier, %s: %s" % [k, stepped])
	var settle := WsgAutoTier.new()
	for i in int(WsgAutoTier.SETTLE / 0.2) - 1:
		if settle.feed(0.2):
			fails.append("auto tier: stepped while settling")
			break
	for f in fails:
		printerr("FAIL: ", f)
	print("PROFILE TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
