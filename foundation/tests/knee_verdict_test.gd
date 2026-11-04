extends SceneTree
## The knees rules' verdict on a body's backward knees (WsgWorldRules.knee_verdict): which rule each case fails.
##   godot --headless --path . -s tests/knee_verdict_test.gd

func _initialize() -> void:
	var fails := []
	# [backward knee-frames, bent knee-frames, most running, worst cm, the rule it fails]
	for c in [[0, 480, 0, 0.0, ""],
			[1, 30, 1, 6.7, "knee_strays"],       # a lone frame on a body bent briefly: 3%, still a stray (Hurling)
			[1, 94, 1, 16.6, "knees"],            # a lone frame over 15 cm
			[2, 30, 1, 5.0, "knees"],             # two, apart, on 6.7% of its bent frames
			[2, 480, 1, 5.0, "knee_strays"],      # two, apart, on 0.4%
			[3, 480, 3, 6.0, "knees"],            # three running
			[3, 480, 2, 6.0, "knees"],            # two running at most, but 3 of 480 is 0.63%: the share
			[2, 1000, 2, 14.0, "knee_strays"],    # two running, 0.2%, under 15 cm
			]:
		var want: String = c[4]
		var got := WsgWorldRules.knee_verdict(int(c[0]), int(c[1]), int(c[2]), float(c[3]))
		print("%d of %d backward, %d running, %.1f cm: %s" % [c[0], c[1], c[2], c[3], got if got != "" else "none"])
		if got != want:
			fails.append("%s: %s, not %s" % [c, got, want])
	print("KNEE VERDICT TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)
