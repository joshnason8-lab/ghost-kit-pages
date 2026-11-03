extends "res://tests/test_runner.gd"
## The game's own test code (tests/test_runner.gd) for the owner's notes (tests/owner_notes/*.gd): one of its sections
## run as a note's measurement, its checks gathered rather than counted, so a note says exactly which numbers failed.
## (In lib/, not beside the notes: tools/wsg/owner_notes.gd fails on a .gd in tests/owner_notes/ that is not a note.)
##
##   var h := await Harness.make(tree)
##   await h._net_sway()
##   await Harness.into(self, h)  # each failed check a fail(), each passed one an info(); the harness goes

const PATH := "res://tests/owner_notes/lib/harness.gd"

var failed: Array = []
var passed: Array = []


func _ready() -> void:
	pass    # (not the whole run: a note calls the sections it needs)


func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		passed.append(what)
	else:
		failures += 1
		failed.append(what)


## A harness in the tree, as test_runner.tscn has it: the screens' parent (Game.main), no sound, the matches without
## the shared foundation's bodies unless a section turns them on (as test_runner runs them).
static func make(tree: SceneTree) -> Node:
	var h: Node = (load(PATH) as Script).new()
	h.name = "NoteHarness"
	tree.root.add_child(h)
	Game.main = h
	Game.settings.sound = false
	FoundationLink.off = true
	h.set_meta("keep", Game.settings.duplicate(true))
	await tree.process_frame
	return h


## The harness's checks into the note (fail for each failed, info for each passed), then it goes.
static func into(note: WsgOwnerNote, h: Node) -> void:
	for p in h.passed:
		note.info("ok: " + String(p))
	for f in h.failed:
		note.fail(String(f))
	await done(h)


## As into(), only the checks whose words contain one of WORDS (a section that checks more than the note is about).
static func into_only(note: WsgOwnerNote, h: Node, words: Array) -> void:
	var hit := func(s: String) -> bool:
		for w in words:
			if s.contains(String(w)):
				return true
		return false
	var n := 0
	for p in h.passed:
		if hit.call(String(p)):
			note.info("ok: " + String(p))
			n += 1
	for f in h.failed:
		if hit.call(String(f)):
			note.fail(String(f))
			n += 1
	if n == 0:
		note.fail("none of the section's checks ran (%s)" % [words])
	await done(h)


static func done(h: Node) -> void:
	if not is_instance_valid(h):
		return
	if h.has_meta("keep"):
		Game.settings = h.get_meta("keep")
	FoundationLink.off = true
	var tree := h.get_tree()
	for c in h.get_children():
		c.queue_free()
	h.queue_free()
	if tree:
		await tree.process_frame
		await tree.process_frame


## The licensed clip library and the player's rig for it are here (the foundation draws Medium and High).
static func have_clips() -> bool:
	return WsgClips.available() and ResourceLoader.exists(FoundationLink.DIR + "hero_rig.json")
