extends SceneTree
## The game profiles (WsgFoundation): which phones start on which tier, what each profile allows, what the 3D crowd
## and the full-detail bodies may cost.
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
	for prof in ["premium", "budget"]:
		WsgFoundation.profile = prof
		var s := WsgFoundation.spec()
		var tiers := []
		for k in [-1, 0, 1]:
			tiers.append(clampi(int(s.default) + k, 0, int(s.max)))
		print("%-7s: renderer %s; starts weak %d, middling %d, flagship %d; at most %d; crowd Medium %s, High %s, Close %s; %d bodies in full" % [
			prof, s.renderer, tiers[0], tiers[1], tiers[2], s.max, WsgFoundation.crowd_budget(1), WsgFoundation.crowd_budget(2),
			WsgFoundation.crowd_budget(3), WsgFoundation.full_bodies()])
		if WsgFoundation.allowed(WsgFoundation.HIGH) != int(s.max):
			fails.append("%s: High chosen gives %d" % [prof, WsgFoundation.allowed(WsgFoundation.HIGH)])
		if prof == "budget":
			if int(s.default) != WsgFoundation.LOW or int(s.max) != WsgFoundation.MEDIUM or s.renderer != "gl_compatibility":
				fails.append("budget: Low by default, Medium at most, GL Compatibility")
			if (WsgFoundation.crowd_budget(1) as Array)[0] > 150:
				fails.append("budget: more than 150 full 3D fans on Medium")
		else:
			if int(s.default) != WsgFoundation.MEDIUM or int(s.max) != WsgFoundation.HIGH:
				fails.append("premium: Medium by default, High at most")
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
	for f in fails:
		printerr("FAIL: ", f)
	print("PROFILE TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
