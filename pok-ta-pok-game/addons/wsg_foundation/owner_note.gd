class_name WsgOwnerNote
extends RefCounted
## One of the owner's notes, kept as a test for good (tools/owner_notes.gd runs them all; CI fails on any). The owner:
## "the regressions are getting worse" - so every note the owner gives becomes a test that checks the very symptom
## they saw, over its whole range (the joystick at the screen's centre, edges and corners on every camera, not only
## the middle of the sideline view), carrying their own words, the date and the version they saw it on. A note is
## never deleted: tests/owner_notes/INDEX.json lists every one, and tools/owner_notes_guard.sh fails CI if a note
## listed once is gone.
##
##   # tests/owner_notes/2026-11-02_joystick_cameras.gd
##   extends WsgOwnerNote
##   const NOTE := {"id": "2026-11-02-joystick-cameras", "game": "netball", "date": "2026-11-02", "version": "0.9.1",
##       "words": "When switching to a camera angle that is not alongside the court the joystick movement is all wrong."}
##   func check() -> void:
##       for f in WsgNoteChecks.joystick(Callable(Player, "stick_to_world"), await _cameras()):
##           fail(f)
##
## check() may await (tree is the SceneTree). fail(), expect(), skip() (only when the data it needs is not here: CI
## with WSG_NOTES_STRICT=1 fails a skip), info() for the numbers the run prints.

var tree: SceneTree
var fails: Array = []
var skipped := ""
var lines: Array = []


## The test itself: override. Measure the symptom across its range; fail() on each fault.
func check() -> void:
	fail("check() is not written")


func fail(msg: String) -> void:
	fails.append(msg)


func expect(ok: bool, msg: String) -> bool:
	if not ok:
		fails.append(msg)
	return ok


func skip(why: String) -> void:
	skipped = why


func info(msg: String) -> void:
	lines.append(msg)


## The note's own facts (its script's NOTE).
func note() -> Dictionary:
	var s: Script = get_script()
	var c := s.get_script_constant_map()
	return c.get("NOTE", {})


## A frame of the tree (for checks that need the scene to run).
func frame() -> void:
	await tree.process_frame
