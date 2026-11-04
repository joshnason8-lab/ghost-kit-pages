extends WsgOwnerNote
## The owner, 2026-11-03 (every game): "On a lot of the games when you click start game there is a loading delay ... long enough on the slow phone that users might think the game has frozen."

const NOTE := {"id": "2026-11-03-loading-frozen", "game": "all", "date": "2026-11-03", "version": "every game", "words": "On a lot of the games when you click start game there is a loading delay ... long enough on the slow phone that users might think the game has frozen."}

## The tap's own frame shows the loading overlay (in the tree, visible, the buttons off), and the heavy work waits
## until it has been drawn (two frames).
func check() -> void:
	var menu := Control.new()
	tree.root.add_child(menu)
	var b := Button.new()
	menu.add_child(b)
	await frame()
	var f0 := Engine.get_process_frames()
	var ld := WsgLoading.cover(menu, [b])
	expect(ld.is_inside_tree() and ld.visible and b.disabled, "the overlay is not up in the tap's own frame")
	var started := [-1]
	ld.load_started.connect(func(): started[0] = Engine.get_process_frames() - f0)
	ld.step("work", func(): OS.delay_msec(50))
	await ld.run()
	info("the overlay up in the tap's frame; the work began %d frames later" % started[0])
	expect(started[0] >= 2, "the work began %d frames after the tap, before the overlay was drawn" % started[0])
	await ld.done()
	menu.queue_free()
