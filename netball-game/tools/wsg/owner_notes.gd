extends SceneTree
## Runs every one of the owner's notes kept as tests (WsgOwnerNote): tests/owner_notes/INDEX.json lists them; each
## file there must be listed and each listed one must be there (never deleted: tools/owner_notes_guard.sh checks the
## index's history too). Prints each note with the owner's own words and what failed; exits 1 on any failure (a skip,
## too, with WSG_NOTES_STRICT=1: CI has the licensed data, so nothing may be skipped there).
##   godot --headless --path . -s res://tools/wsg/owner_notes.gd [-- res://tests/owner_notes]

func _initialize() -> void:
	await process_frame
	var a := OS.get_cmdline_user_args()
	var dir := String(a[0]) if a.size() > 0 else "res://tests/owner_notes"
	var strict := OS.has_environment("WSG_NOTES_STRICT")
	var problems := []
	var f := FileAccess.open(dir.path_join("INDEX.json"), FileAccess.READ)
	if f == null:
		printerr("owner_notes: no %s/INDEX.json" % dir)
		quit(1)
		return
	var index: Variant = JSON.parse_string(f.get_as_text())
	if not index is Dictionary or not (index as Dictionary).has("notes"):
		printerr("owner_notes: INDEX.json has no \"notes\"")
		quit(1)
		return
	var listed := {}
	for e: Dictionary in index.notes:
		listed[String(e.file)] = e
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") and not listed.has(file):
			problems.append("%s is not in INDEX.json (add it: a note is listed for good)" % file)
	var passed := 0
	var failed := 0
	var skipped := 0
	for e: Dictionary in index.notes:
		var path := dir.path_join(String(e.file))
		if not FileAccess.file_exists(path):
			problems.append("note %s (%s) is gone: notes are never deleted - '%s'" % [e.id, e.file, e.get("words", "")])
			continue
		var s: Script = load(path)
		if s == null or not s.can_instantiate():
			problems.append("note %s does not compile (%s)" % [e.id, e.file])
			continue
		var n: Object = s.new()
		if not n is WsgOwnerNote:
			problems.append("note %s does not extend WsgOwnerNote" % e.id)
			continue
		var note := n as WsgOwnerNote
		note.tree = self
		var meta := note.note()
		if String(meta.get("id", "")) != String(e.id):
			problems.append("%s: its NOTE id '%s' is not the index's '%s'" % [e.file, meta.get("id", ""), e.id])
		var t0 := Time.get_ticks_msec()
		await note.check()
		var ms := Time.get_ticks_msec() - t0
		print("\n[%s] %s, %s (%s): \"%s\"" % [e.id, meta.get("game", ""), meta.get("date", ""), meta.get("version", ""), meta.get("words", "")])
		for l in note.lines:
			print("    ", l)
		if note.skipped != "":
			skipped += 1
			print("    SKIPPED: ", note.skipped)
			if strict:
				problems.append("%s skipped (%s) - not allowed here" % [e.id, note.skipped])
		elif note.fails.is_empty():
			passed += 1
			print("    PASS (%d ms)" % ms)
		else:
			failed += 1
			for x in note.fails:
				print("    FAIL: ", x)
				problems.append("%s: %s" % [e.id, x])
	print("\n%d notes: %d pass, %d fail, %d skipped" % [index.notes.size(), passed, failed, skipped])
	for p in problems:
		printerr("FAIL: ", p)
	print("OWNER NOTES: ", "PASS" if problems.is_empty() else "FAIL (%d)" % problems.size())
	quit(0 if problems.is_empty() else 1)
