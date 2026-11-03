extends SceneTree
## The asset lint in CI (WsgAssetLint; owner-approved item 9): every imported texture and model, the repository's
## files, the game's player as it builds it, and each venue's props.
##   godot --headless --path . -s res://tools/wsg/asset_lint.gd -- --out DIR [--game res://game/world.gd]
##       [--only textures,lods,licensed,toe_up,props]
## Writes DIR/ASSET_LINT.md and asset_lint.json (DIR outside the project); exits 1 on any failure not excused in
## res://asset_lint_allow.txt (lines "<glob>\t<the owner's note>"). Warnings never fail. ADOPTING §5.22.

const CHECKS := ["textures", "lods", "licensed", "toe_up", "props"]


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out_dir := _arg(args, "--out", "")
	var game_path := _arg(args, "--game", "res://game/world.gd")
	var only := _arg(args, "--only", "")
	if out_dir == "":
		printerr("asset_lint: --out DIR (outside the project)")
		quit(2)
		return
	var proj := ProjectSettings.globalize_path("res://").simplify_path()
	var abs_out := (out_dir if out_dir.is_absolute_path() else proj.path_join(out_dir)).simplify_path()
	if abs_out.begins_with(proj):
		printerr("asset_lint: %s is inside the project: put it outside" % out_dir)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(abs_out)
	var checks := CHECKS if only == "" else Array(only.split(",", false))
	var issues := []
	var notes := []
	if "textures" in checks or "lods" in checks:
		var imps := WsgAssetLint.imports("res://")
		notes.append("%d imported files" % imps.size())
		for pair in imps:
			if "textures" in checks:
				issues.append_array(WsgAssetLint.texture(pair[0], pair[1]))
			if "lods" in checks:
				issues.append_array(WsgAssetLint.lods(pair[0], pair[1]))
	if "licensed" in checks:
		var lines := []
		var code := OS.execute("git", ["-C", proj, "ls-files"], lines)
		var files: Array = Array(("\n".join(lines)).split("\n", false)) if code == 0 else []
		var ign := OS.execute("git", ["-C", proj, "check-ignore", "-q", "addons/wsg_foundation/data/mobility.res"]) == 0
		if code != 0:
			issues.append(WsgAssetLint.issue("licensed", proj, "not a git checkout: the committed files cannot be checked"))
		notes.append("%d committed files; the data folder %s" % [files.size(), "git-ignored" if ign else "NOT git-ignored"])
		issues.append_array(WsgAssetLint.licensed(files, ign))
	var game: WsgWorldGame = null
	if ("toe_up" in checks or "props" in checks):
		if ResourceLoader.exists(game_path):
			game = (load(game_path) as GDScript).new()
		else:
			issues.append(WsgAssetLint.issue("toe_up", game_path, "no game world.gd: the player and the venues cannot be checked (ADOPTING §5.18)"))
	var sv := SubViewport.new()
	root.add_child(sv)
	if game and "toe_up" in checks:
		var wl := game.walker(sv)
		if wl.is_empty():
			issues.append(WsgAssetLint.issue("toe_up", game_path, "world.gd's walker() is not filled in"))
		else:
			await process_frame
			var body: WsgBody = wl[0]
			notes.append("the player's model: %.1f degrees toe-up" % WsgFootFlat.sole_tilt(body))
			issues.append_array(WsgAssetLint.toe_up(body))
			body.queue_free()
	if game and "props" in checks:
		var reg_path := game.prop_registry()
		if reg_path == "":
			issues.append(WsgAssetLint.issue("props", game_path, "world.gd's prop_registry() is not filled in"))
		else:
			var reg_script: Script = load(reg_path)
			var reg: Object = reg_script.new()
			for venue in reg_script.call("venues"):
				var audit := WsgPropAudit.new()
				var scene: Node = await reg.call("run", String(venue), 1, 0.3, audit, self)
				if scene and audit.solid:
					issues.append_array(WsgAssetLint.props(scene, audit.solid, String(venue)))
					notes.append("%s: %d solid props" % [venue, audit.solid.props.size()])
				if scene:
					scene.queue_free()
				await process_frame
	var rules := WsgAssetLint.allow_rules()
	var failed := 0
	for i: Dictionary in issues:
		var why := WsgAssetLint.excused(i, rules)
		if why != "":
			i.fail = false
			i["excused"] = why
		if i.fail:
			failed += 1
	_write(abs_out, issues, notes)
	for i: Dictionary in issues:
		print("%-8s %-9s %s: %s%s" % ["FAIL" if i.fail else "warning", i.check, i.path, i.what, (" (excused: %s)" % i.excused) if i.has("excused") else ""])
	for n in notes:
		print("  ", n)
	print("ASSET LINT: %s (%d failures, %d warnings) - %s" % ["PASS" if failed == 0 else "FAIL", failed, issues.size() - failed, abs_out.path_join("ASSET_LINT.md")])
	sv.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)


func _arg(args: PackedStringArray, key: String, def: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else def


func _write(dir: String, issues: Array, notes: Array) -> void:
	var f := FileAccess.open(dir.path_join("asset_lint.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"issues": issues, "notes": notes}, "  "))
	f.close()
	var md := ["# Asset lint", ""]
	for c in CHECKS:
		var mine := issues.filter(func(i: Dictionary) -> bool: return i.check == c)
		md.append("## %s: %s" % [c, "PASS" if mine.all(func(i: Dictionary) -> bool: return not i.fail) else "FAIL"])
		for i: Dictionary in mine:
			md.append("- %s`%s`: %s%s" % ["**FAIL** " if i.fail else "warning ", i.path, i.what, (" (excused: %s)" % i.excused) if i.has("excused") else ""])
		md.append("")
	md.append("## Measured")
	for n in notes:
		md.append("- %s" % n)
	f = FileAccess.open(dir.path_join("ASSET_LINT.md"), FileAccess.WRITE)
	f.store_string("\n".join(md))
	f.close()
