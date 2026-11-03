extends SceneTree
## WsgSimInput against a game that pauses itself when sent to the background and whose pause key toggles (Pok Ta Pok,
## most mobile games): with the game's paused() hook the fuzzer never leaves it paused for good (a person taps Resume
## on coming back; its own pause pair starts only from a known state); without it (paused() -1, the old way) the
## same seeds do leave it stuck - the check sees the fault Pok Ta Pok's matches hit ("endless").
##   godot --headless --fixed-fps 30 --path . -s tests/sim_pause_test.gd

const FRAMES := 9000
const STUCK := 900    # 30 s paused on end: stuck


class Pausable:
	extends Node
	var paused := false
	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			paused = true
	func _unhandled_input(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_cancel"):
			paused = not paused


class FakeGame:
	extends WsgSimGame
	var node: Pausable
	var tells := true
	func paused() -> int:
		return (1 if node.paused else 0) if tells else -1
	func human_team() -> int:
		return 0


func _initialize() -> void:
	await process_frame
	var fails := []
	var stuck_old := 0
	for tells in [true, false]:
		var stuck_seeds := 0
		for seed in 8:
			var node := Pausable.new()
			root.add_child(node)
			var g := FakeGame.new()
			g.node = node
			g.tells = tells
			var input := WsgSimInput.new(g, seed * 7919 + 13, self)
			var run := 0
			var worst := 0
			for f in FRAMES:
				input.tick(f)
				await process_frame
				run = run + 1 if node.paused else 0
				worst = maxi(worst, run)
			if worst >= STUCK:
				stuck_seeds += 1
			node.queue_free()
		print("%s: %d of 8 seeds left the game paused %d s or more" % ["with paused()" if tells else "without paused() (the old way)", stuck_seeds, STUCK / 30])
		if tells and stuck_seeds > 0:
			fails.append("with paused() the fuzzer still left the game paused for good on %d seeds" % stuck_seeds)
		if not tells:
			stuck_old = stuck_seeds
	if stuck_old == 0:
		fails.append("without paused() no seed was left paused: the test no longer shows the fault it guards")
	print("SIM PAUSE TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % fails)
	quit(0 if fails.is_empty() else 1)
