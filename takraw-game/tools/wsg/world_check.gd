extends SceneTree
## wsg_world_check: the world rules (docs/WORLD_RULES.md) on the game's own code, one entry point for every game's CI.
##   godot --headless --fixed-fps 30 --path . -s res://tools/wsg/world_check.gd -- --out DIR [--game res://game/world.gd]
##       [--only props,crowd,feet,pose,officials,sounds,loading,joystick,web] [--web-pck build/web/index.pck]
##       [--presets res://export_presets.cfg]
## The game's hooks are res://game/world.gd (extends WsgWorldGame); a rule it does not wire FAILS ("not wired"), unless
## its exceptions() name the owner's note excusing it. props and crowd run the game's prop_audit and crowd_audit
## (their own sheets under DIR/props, DIR/crowd; the crowd's sheet wants a display: xvfb-run and --rendering-driver
## opengl3, as crowd_audit). Writes DIR/WORLD_CHECK.md and DIR/world_check.json; exits 1 if any rule fails.
## DIR must be outside the project (an export would pack it).
## A failure fails the build from ENFORCED_FROM (UTC; the lead: each game has the morning of 2026-11-03 to write its
## world.gd): before it the report is the same but the exit is 0, with a warning. WSG_WORLD_ENFORCE=1 enforces it now
## (the check's own test); WSG_NOW=2026-11-03T12:00Z judges by another time.

const ENFORCED_FROM := "2026-11-03T12:00Z"

const RULES := ["props", "crowd", "feet", "pose", "officials", "sounds", "loading", "joystick", "web"]


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var game_path := _arg(args, "--game", "res://game/world.gd")
	var out_dir := _arg(args, "--out", "")
	var only := _arg(args, "--only", "")
	var pck := _arg(args, "--web-pck", "")
	var bad := _arg(args, "--bad", "")
	var presets := _arg(args, "--presets", "res://export_presets.cfg")
	if out_dir == "":
		printerr("world_check: --out DIR (outside the project) is needed")
		quit(2)
		return
	var proj := ProjectSettings.globalize_path("res://").simplify_path()
	var abs_out := (out_dir if out_dir.is_absolute_path() else proj.path_join(out_dir)).simplify_path()
	if abs_out.begins_with(proj):
		printerr("world_check: %s is inside the project (an export would pack it): put it outside" % out_dir)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(abs_out)
	if not ResourceLoader.exists(game_path):
		printerr("world_check: no %s (the game's WsgWorldGame: ADOPTING.md §5.18)" % game_path)
		quit(1)
		return
	var game: WsgWorldGame = (load(game_path) as GDScript).new()
	if bad != "" and "bad" in game:
		game.set("bad", bad)
	var rules := RULES if only == "" else Array(only.split(",", false))
	var excused := game.exceptions()
	# The screen the modes are played on.
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var results := []
	var modes := []
	if rules.any(func(r: String) -> bool: return r in ["pose", "officials", "loading", "joystick"] and not excused.has(r)):
		modes = await WsgWorldRules.play_modes(game, sv)
	for rule: String in rules:
		if not rule in RULES:
			printerr("world_check: no rule '%s' (%s)" % [rule, ", ".join(RULES)])
			quit(2)
			return
		var r: Dictionary
		if excused.has(rule):
			r = WsgWorldRules.result(rule)
			r.status = "excused"
			r.lines.append("excused by the owner: %s" % excused[rule])
		else:
			match rule:
				"props":
					r = _audit(rule, game.prop_registry(), "prop_registry", "prop_audit.gd", abs_out.path_join("props"), game.prop_args())
				"crowd":
					r = _audit(rule, game.crowd_registry(), "crowd_registry", "crowd_audit.gd", abs_out.path_join("crowd"), [])
				"feet":
					r = await WsgWorldRules.feet(game, sv)
				"pose":
					r = WsgWorldRules.pose(game, modes)
				"officials":
					r = WsgWorldRules.officials(game, modes)
				"loading":
					r = WsgWorldRules.loading(game, modes)
				"joystick":
					r = WsgWorldRules.joystick(game, modes)
				"sounds":
					r = WsgWorldRules.sounds(game, sv)
				"web":
					r = WsgWorldRules.web(presets, pck)
		results.append(r)
		print("%-10s %-9s %s" % [rule, (r.status as String).to_upper(), "; ".join(r.fails) if not (r.fails as Array).is_empty() else ""])
		for l in r.lines:
			print("             ", l)
	WsgWorldRules.free_modes(modes)
	var failed := results.filter(func(r: Dictionary) -> bool: return r.status == "fail" or r.status == "not wired")
	_write(abs_out, game.game_name(), results)
	print("WORLD CHECK: %s (%d rules, %d failed) - %s" % ["PASS" if failed.is_empty() else "FAIL", results.size(), failed.size(), abs_out.path_join("WORLD_CHECK.md")])
	sv.queue_free()
	await process_frame
	var now := OS.get_environment("WSG_NOW") if OS.has_environment("WSG_NOW") else Time.get_datetime_string_from_system(true).substr(0, 16) + "Z"
	if not failed.is_empty() and OS.get_environment("WSG_WORLD_ENFORCE") != "1" and now < ENFORCED_FROM:
		print("::warning::world_check: %d rules fail; the world check fails the build from %s (now %s) - fix them before then" % [failed.size(), ENFORCED_FROM, now])
		quit(0)
		return
	quit(0 if failed.is_empty() else 1)


func _arg(args: PackedStringArray, key: String, def: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else def


## The game's own audit tool (props, crowd) on its registry, in its own Godot: passes on its exit 0.
func _audit(rule: String, registry: String, hook: String, tool: String, out: String, extra: Array) -> Dictionary:
	var r := WsgWorldRules.result(rule)
	if registry == "":
		r.status = "not wired"
		r.fails.append("the game's world.gd does not fill in %s()" % hook)
		return r
	var tool_path := (get_script() as Script).resource_path.get_base_dir().path_join(tool)
	var a := PackedStringArray()
	if DisplayServer.get_name() == "headless":
		a.append("--headless")
	a.append_array(["--path", ProjectSettings.globalize_path("res://"), "-s", tool_path, "--", registry, out])
	for e in extra:
		a.append(str(e))
	var lines := []
	var code := OS.execute(OS.get_executable_path(), a, lines, true)
	var text := "\n".join(lines)
	var last := ""
	for l in text.split("\n"):
		if l.strip_edges() != "":
			last = l.strip_edges()
	r.lines.append("%s %s: exit %d; %s" % [tool.get_basename(), registry, code, last])
	if code != 0:
		r.fails.append("%s failed (exit %d): see %s" % [tool.get_basename(), code, out])
	return r


func _write(dir: String, game_name: String, results: Array) -> void:
	var f := FileAccess.open(dir.path_join("world_check.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"game": game_name, "rules": results}, "  "))
	f.close()
	var md := ["# World check: %s" % game_name, "", "The world rules (docs/WORLD_RULES.md) on the game's own code.", ""]
	md.append("| Rule | Result | What broke it |")
	md.append("|---|---|---|")
	for r: Dictionary in results:
		md.append("| %s | %s | %s |" % [r.rule, (r.status as String).to_upper(), "<br>".join(r.fails).replace("|", "/")])
	md.append("")
	for r: Dictionary in results:
		md.append("## %s" % r.rule)
		for l in r.lines:
			md.append("- %s" % l)
		for x in r.fails:
			md.append("- **%s**" % x)
		md.append("")
	f = FileAccess.open(dir.path_join("WORLD_CHECK.md"), FileAccess.WRITE)
	f.store_string("\n".join(md))
	f.close()
