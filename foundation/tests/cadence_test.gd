extends SceneTree
## Running cadence: the test hurler sprinting at 6 m/s, cutting 90 degrees every 0.8 s, lands 2.5 to 4.8 feet a second (WsgFootPlanter.landed,
## WsgLocomotor.step: footstep sounds) - the owner's 0.10 note on Kho Kho was "fast-forward legs". The planter's
## recovery step fired at every running stride's toe-off and doubled the landings (Kho Kho's runners: 7.6 a second).
##   godot --headless --fixed-fps 30 --path . -s tests/cadence_test.gd


func _initialize() -> void:
	await process_frame
	if not FileAccess.file_exists("res://addons/wsg_foundation/data/mobility.res"):
		print("CADENCE TEST: SKIPPED (no licensed clip library)")
		quit(0)
		return
	var body := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
	root.add_child(body)
	var loco := WsgLocomotor.attach(body)
	await process_frame
	var lands := [0]
	var frames := [0]
	loco.step.connect(func(_f): lands[0] += 1)
	# (A chaser's run: sprinting, cutting 90 degrees every 0.8 s - where the recovery step fired most.)
	var path := [[1.0, Vector2.ZERO, 0.0], [1.5, Vector2(6.0, 0), NAN]]
	for k in 8:
		path.append([0.8, Vector2(6.0, 0).rotated(PI * 0.5 * float(k % 2)), NAN])
	await WsgWorldRules.drive(self, body, loco, path, func(_t: float, si: int):
		if si < 2:
			lands[0] = 0
		else:
			frames[0] += 1)
	var secs: float = frames[0] / 30.0
	var rate: float = lands[0] / secs
	print("sprinting and cutting at 6 m/s for %.1f s: %d landings, %.1f a second, %.2f m a step" % [secs, lands[0], rate, 6.0 / maxf(rate, 0.01)])
	var ok := rate >= 2.5 and rate <= 4.8
	print("CADENCE TEST: ", "PASS" if ok else "FAIL (%.1f landings a second; 2.5 to 4.8)" % rate)
	quit(0 if ok else 1)
