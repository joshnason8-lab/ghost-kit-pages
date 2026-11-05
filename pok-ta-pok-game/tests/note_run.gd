extends RefCounted
## The owner's notes (tests/owner_notes/) measure the game with the test suite's own measurements: this runs one of
## test_runner.gd's (a match, its checks over the whole range) once a run, however many notes read it, and hands back
## its checks, [passed, what] each.

static var _done := {}       # "func|args" -> its checks


static func checks(tree: SceneTree, fn: String, args: Array = []) -> Array:
	var key := "%s|%s" % [fn, str(args)]
	if _done.has(key):
		return _done[key]
	var r: Node = (load("res://tests/test_runner.gd") as Script).new()
	r.only = true
	tree.root.add_child(r)
	Game.main = r
	Game.settings.sound = false
	Game.settings.coach = false
	tree.root.size = Vector2i(1280, 720)
	FoundationLink.off = true
	var keep: Dictionary = Game.settings.duplicate(true)
	await r.callv(fn, args)
	Game.settings = keep
	_done[key] = (r.log as Array).duplicate()
	r.queue_free()
	await tree.process_frame
	return _done[key]


## A note's checks: those of fn(args) whose words hold any of WORDS ([] for all); each failure fail()ed on the note,
## each pass info()ed; and at least one must be there (a renamed check must not leave a note measuring nothing).
static func apply(note: WsgOwnerNote, fn: String, args: Array, words: Array = []) -> void:
	var all: Array = await checks(note.tree, fn, args)
	var n := 0
	for c in all:
		var what := String(c[1])
		var hit := words.is_empty()
		for w in words:
			if what.contains(String(w)):
				hit = true
		if not hit:
			continue
		n += 1
		if bool(c[0]):
			note.info("ok: " + what)
		else:
			note.fail(what)
	note.expect(n > 0, "%s%s made none of the checks this note reads %s" % [fn, str(args), str(words)])
