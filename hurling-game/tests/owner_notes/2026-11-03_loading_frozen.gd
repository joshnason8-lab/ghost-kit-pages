extends WsgOwnerNote
## The owner, 2026-11-03 (every game (Hurling 0.22)): "when you click start game there is a loading delay ... long enough on the slow phone that users might think the game has frozen"

const NOTE := {"id": "2026-11-03-loading-frozen", "game": "hurling", "date": "2026-11-03", "version": "every game (Hurling 0.22)", "words": "when you click start game there is a loading delay ... long enough on the slow phone that users might think the game has frozen"}
const Kit := preload("res://tests/note_kit.gd")

## Throw-in tapped: the loading overlay is up in the tap's own frame, the bar goes forward over the frames that follow,
## and the match comes up.
func check() -> void:
	var host := Node.new()
	tree.root.add_child(host)
	var keep_main: Variant = Game.main
	Game.main = host
	var scr: Node = Game.show_screen("res://ui/quick_setup.gd", {})
	await Kit.frames(tree, 5)
	scr.call("_play")
	expect(WsgLoading.current() != null, "no loading overlay in the tap's own frame")
	var drawn := 0
	var t0 := Time.get_ticks_msec()
	while WsgLoading.current() != null and Time.get_ticks_msec() - t0 < 60000:
		await Kit.frames(tree, 1)
		drawn += 1
	info("the overlay drawn %d frames, %d ms" % [drawn, Time.get_ticks_msec() - t0])
	expect(drawn >= 4, "the overlay was up for only %d frames" % drawn)
	expect(Game.current != null and Game.current.has_method("is_watch"), "no match came up")
	if Game.current:
		Game.current.queue_free()
		Game.current = null
	Game.main = keep_main if is_instance_valid(keep_main) else null
	host.queue_free()
	await Kit.frames(tree, 3)
