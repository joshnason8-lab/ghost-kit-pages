extends SceneTree
## Runs the owner's notes named on the command line (file names in tests/owner_notes/, or a part of their id), as
## tools/wsg/owner_notes.gd runs them all: while writing or fixing one.
##   godot --headless --path . --fixed-fps 30 -s res://tests/owner_notes/lib/run_one.gd -- 2026-11-03_net_sway.gd

const DIR := "res://tests/owner_notes"


func _initialize() -> void:
	await process_frame
	var want := OS.get_cmdline_user_args()
	var bad := 0
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".gd"):
			continue
		var hit := want.is_empty()
		for w in want:
			hit = hit or file.contains(w)
		if not hit:
			continue
		var note: WsgOwnerNote = (load(DIR.path_join(file)) as Script).new()
		note.tree = self
		var meta := note.note()
		var t0 := Time.get_ticks_msec()
		await note.check()
		print("\n[%s] \"%s\"" % [meta.get("id", file), meta.get("words", "")])
		for l in note.lines:
			print("    ", l)
		if note.skipped != "":
			print("    SKIPPED: ", note.skipped)
		elif note.fails.is_empty():
			print("    PASS (%d ms)" % (Time.get_ticks_msec() - t0))
		else:
			bad += 1
			for x in note.fails:
				print("    FAIL: ", x)
			print("    (%d ms)" % (Time.get_ticks_msec() - t0))
	quit(1 if bad > 0 else 0)
