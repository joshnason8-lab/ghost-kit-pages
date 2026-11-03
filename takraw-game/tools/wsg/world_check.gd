extends SceneTree
## wsg_world_check: the world rules (docs/WORLD_RULES.md) on the game's own code, one entry point for every game's CI.
##   godot --headless --fixed-fps 30 --path . -s res://tools/wsg/world_check.gd -- --out DIR [--game res://game/world.gd]
##       [--only props,crowd,feet,pose,officials,sounds,loading,joystick,web,tiers] [--web-pck build/web/index.pck]
##       [--presets res://export_presets.cfg] [--reuse crowd=DIR,props=DIR] [--draw-modes]
##   ... -- --out DIR --merge DIR1,DIR2,...    (the reports of parallel --only jobs as one; exits 1 if any rule failed)
## The game's hooks are res://game/world.gd (extends WsgWorldGame); a rule it does not wire FAILS ("not wired"), unless
## its exceptions() name the owner's note excusing it. props and crowd run the game's prop_audit and crowd_audit
## (their own sheets under DIR/props, DIR/crowd; the crowd's sheet wants a display: xvfb-run and --rendering-driver
## opengl3, as crowd_audit). Writes DIR/WORLD_CHECK.md and DIR/world_check.json; exits 1 if any rule fails.
## DIR must be outside the project (an export would pack it).
## A failure fails the build from ENFORCED_FROM (UTC; the lead: each game has the morning of 2026-11-03 to write its
## world.gd): before it the report is the same but the exit is 0, with a warning. WSG_WORLD_ENFORCE=1 enforces it now
## (the check's own test); WSG_NOW=2026-11-03T12:00Z judges by another time.

const ENFORCED_FROM := "2026-11-03T12:00Z"
## Rules enforced later than that, for every game (the lead, 2026-11-03: the feet rule's walker read 2.1-2.2 cm on the
## walk on three games' rigs at 888e222 - a foundation fault - so feet from the next day). Before its time a rule's
## failure is reported as deferred. WSG_WORLD_ENFORCE=1 enforces these now too.
const RULE_FROM := {"feet": "2026-11-04T12:00Z", "feet_low": "2026-11-08T12:00Z"}

const RULES := ["props", "crowd", "feet", "feet_low", "pose", "officials", "sounds", "loading", "joystick", "web", "tiers"]


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var game_path := _arg(args, "--game", "res://game/world.gd")
	var out_dir := _arg(args, "--out", "")
	var only := _arg(args, "--only", "")
	var pck := _arg(args, "--web-pck", "")
	var bad := _arg(args, "--bad", "")
	var presets := _arg(args, "--presets", "res://export_presets.cfg")
	# --reuse crowd=DIR,props=DIR: the result the job's own crowd_audit / prop_audit step already wrote there (its
	# crowd_audit.json / prop_audit.json), not the same audit run twice (Hurling's and Floorball's CI: 10 minutes each).
	var reuse := {}
	for kv in _arg(args, "--reuse", "").split(",", false):
		var p := kv.split("=", true, 1)
		if p.size() == 2:
			reuse[p[0].strip_edges()] = p[1].strip_edges()
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
	# --merge DIR,DIR...: the reports of world checks run in parallel (each --only some rules) made one, with one exit.
	if _arg(args, "--merge", "") != "":
		var code := _merge(_arg(args, "--merge", "").split(",", false), abs_out)
		quit(code)
		return
	if not ResourceLoader.exists(game_path):
		printerr("world_check: no %s (the game's WsgWorldGame: ADOPTING.md §5.18)" % game_path)
		quit(1)
		return
	WsgAutoTier.off = true   # (frames at a fixed step are not a phone's)
	var game: WsgWorldGame = (load(game_path) as GDScript).new()
	if bad != "" and "bad" in game:
		game.set("bad", bad)
	var rules := RULES if only == "" else Array(only.split(",", false))
	var excused := game.exceptions()
	var deferred := game.deferred()
	var now := OS.get_environment("WSG_NOW") if OS.has_environment("WSG_NOW") else Time.get_datetime_string_from_system(true).substr(0, 16) + "Z"
	# The screen the modes are played on.
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var results := []
	var modes := []
	# Seconds each rule took (and the modes played for pose, officials, loading and joystick), for CI's time budget.
	var timing := {}
	if rules.any(func(r: String) -> bool: return r in ["pose", "officials", "loading", "joystick"] and not excused.has(r)):
		var tm := Time.get_ticks_msec()
		# (Not drawn while the modes play: the rules that read them read bones, nodes and the loading cover, not pixels,
		# and drawing them in software on CI took most of the check - Kabaddi's four modes, 18 of its 52 minutes. The
		# tiers rule draws its own starts. --draw-modes draws them, as before.)
		if not args.has("--draw-modes"):
			sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
		modes = await WsgWorldRules.play_modes(game, sv)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		timing["modes"] = (Time.get_ticks_msec() - tm) / 1000.0
		print("world_check: the modes played in %.1f s" % timing.modes)
	for rule: String in rules:
		if not rule in RULES:
			printerr("world_check: no rule '%s' (%s)" % [rule, ", ".join(RULES)])
			quit(2)
			return
		var r: Dictionary
		var t0 := Time.get_ticks_msec()
		if excused.has(rule):
			r = WsgWorldRules.result(rule)
			r.status = "excused"
			r.lines.append("excused by the owner: %s" % excused[rule])
		else:
			match rule:
				"props":
					r = _audit(rule, game.prop_registry(), "prop_registry", "prop_audit.gd", abs_out.path_join("props"), _props_args(game.prop_args()), reuse.get("props", ""))
				"crowd":
					r = _audit(rule, game.crowd_registry(), "crowd_registry", "crowd_audit.gd", abs_out.path_join("crowd"), [], reuse.get("crowd", ""))
				"feet":
					r = await WsgWorldRules.feet(game, sv)
				"feet_low":
					# (What the owner sees at Low: the game's own bodies there, the lead 2026-11-03; deferred to 11-08 12:00.)
					r = await WsgWorldRules.feet_low(game, sv)
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
				"tiers":
					r = await WsgWorldRules.tiers(game, sv)
				"web":
					r = WsgWorldRules.web(presets, pck)
		if not r.is_empty() and r.has("status") and r.status in ["fail", "not wired"]:
			# Put off: for every game until the rule's own time (RULE_FROM), or for this game by its deferred() - the
			# lead's word, with a reason, until a time. Reported as deferred, with why; not failed.
			var until := ""
			var why := ""
			if RULE_FROM.has(rule) and now < String(RULE_FROM[rule]) and OS.get_environment("WSG_WORLD_ENFORCE") != "1":
				until = String(RULE_FROM[rule])
				why = "this rule fails the build from %s for every game (foundation fault being fixed)" % until
			var dd: Variant = deferred.get(rule, [])
			if dd is Array and (dd as Array).size() >= 2 and String(dd[1]).strip_edges() != "" and now < String(dd[0]):
				until = String(dd[0])
				why = String(dd[1])
			if until != "":
				r.status = "deferred"
				r.lines.append("deferred until %s: %s" % [until, why])
		if r.is_empty() or not r.has("status"):
			# (A rule stopped by a script error returns nothing: failed, named, and the check goes on and finishes.)
			r = WsgWorldRules.result(rule)
			r.status = "fail"
			r.fails.append("the rule stopped on a script error (see the log above)")
		r["seconds"] = (Time.get_ticks_msec() - t0) / 1000.0
		timing[rule] = r.seconds
		results.append(r)
		print("%-10s %-9s %5.1f s  %s" % [rule, (r.status as String).to_upper(), r.seconds, "; ".join(r.fails) if not (r.fails as Array).is_empty() else ""])
		for l in r.lines:
			print("             ", l)
		for w in r.get("warnings", []):
			print("::warning::world_check %s: near its bound: %s" % [rule, w])
	WsgWorldRules.free_modes(modes)
	var failed := results.filter(func(r: Dictionary) -> bool: return r.status == "fail" or r.status == "not wired")
	_write(abs_out, game.game_name(), results)
	var total := 0.0
	for k in timing:
		total += float(timing[k])
	print("world_check: seconds %s (%.0f s in all)" % [JSON.stringify(timing), total])
	print("WORLD CHECK: %s (%d rules, %d failed) - %s" % ["PASS" if failed.is_empty() else "FAIL", results.size(), failed.size(), abs_out.path_join("WORLD_CHECK.md")])
	sv.queue_free()
	await process_frame
	if not failed.is_empty() and OS.get_environment("WSG_WORLD_ENFORCE") != "1" and now < ENFORCED_FROM:
		print("::warning::world_check: %d rules fail; the world check fails the build from %s (now %s) - fix them before then" % [failed.size(), ENFORCED_FROM, now])
		quit(0)
		return
	quit(0 if failed.is_empty() else 1)


func _arg(args: PackedStringArray, key: String, def: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else def


## The game's own audit tool (props, crowd) on its registry, in its own Godot: passes on its exit 0.
func _audit(rule: String, registry: String, hook: String, tool: String, out: String, extra: Array, reuse_dir := "") -> Dictionary:
	var r := WsgWorldRules.result(rule)
	if registry == "":
		r.status = "not wired"
		r.fails.append("the game's world.gd does not fill in %s()" % hook)
		return r
	if reuse_dir != "":
		# The job's own run of the same tool on the same registry (its step ran first, into reuse_dir).
		var jp := reuse_dir.path_join(tool.get_basename() + ".json")
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(jp)) if FileAccess.file_exists(jp) else null
		if not j is Dictionary:
			r.fails.append("--reuse %s: no %s (the step that writes it did not run first?)" % [rule, jp])
			return WsgWorldRules._close(r)
		var ok := true
		if (j as Dictionary).has("pass"):
			ok = bool(j.pass)
		else:
			for v in (j as Dictionary).values():
				if v is Dictionary and not ((v as Dictionary).get("fails", []) as Array).is_empty():
					ok = false
		r.lines.append("%s %s: reused from %s (this job's own step): %s" % [tool.get_basename(), registry, jp, "PASS" if ok else "FAIL"])
		if not ok:
			r.fails.append("%s failed: see %s" % [tool.get_basename(), reuse_dir])
		return WsgWorldRules._close(r)
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
	# (Without this a failing audit was reported PASS - Sepak Takraw's "crowd | PASS | crowd_audit failed (exit 1)".)
	return WsgWorldRules._close(r)


func _write(dir: String, game_name: String, results: Array) -> void:
	var f := FileAccess.open(dir.path_join("world_check.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"game": game_name, "rules": results}, "  "))
	f.close()
	var md := ["# World check: %s" % game_name, "", "The world rules (docs/WORLD_RULES.md) on the game's own code.", ""]
	md.append("| Rule | Result | What broke it |")
	md.append("|---|---|---|")
	for r: Dictionary in results:
		var near: Array = r.get("warnings", [])
		md.append("| %s | %s | %s |" % [r.rule, (r.status as String).to_upper() + (" (near a bound)" if not near.is_empty() and r.status == "pass" else ""),
			"<br>".join(r.fails + near.map(func(w: String) -> String: return "near: " + w)).replace("|", "/")])
	md.append("")
	for r: Dictionary in results:
		md.append("## %s" % r.rule)
		for l in r.lines:
			md.append("- %s" % l)
		for x in r.fails:
			md.append("- **%s**" % x)
		for w in r.get("warnings", []):
			md.append("- warning, near its bound: %s" % w)
		md.append("")
	f = FileAccess.open(dir.path_join("WORLD_CHECK.md"), FileAccess.WRITE)
	f.store_string("\n".join(md))
	f.close()


## The props rule's sample, at most PROPS_MAX ([matches, seconds] a venue): a game's own props step can run longer
## (Floorball's default [2, 60] took 23 of its world check's 40 minutes).
const PROPS_MAX := [1, 30.0]


func _props_args(a: Array) -> Array:
	var m := mini(int(a[0]) if a.size() > 0 else 1, int(PROPS_MAX[0]))
	var s := minf(float(a[1]) if a.size() > 1 else float(PROPS_MAX[1]), float(PROPS_MAX[1]))
	return [m, s]


## The parallel jobs' world_check.json made one report in OUT: every rule once (the first job that ran it), exit 1 if
## any failed (as one check's: before ENFORCED_FROM a warning). A rule no job ran is a failure.
func _merge(dirs: Array, out: String) -> int:
	var game_name := ""
	var by := {}
	for d in dirs:
		var jp := String(d).path_join("world_check.json")
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(jp)) if FileAccess.file_exists(jp) else null
		if not j is Dictionary:
			printerr("world_check --merge: no %s" % jp)
			return 1
		game_name = String(j.get("game", game_name))
		for r: Dictionary in j.get("rules", []):
			if not by.has(r.rule):
				by[r.rule] = r
	var results := []
	for rule in RULES:
		if by.has(rule):
			results.append(by[rule])
		else:
			var r := WsgWorldRules.result(rule)
			r.status = "fail"
			r.fails.append("no parallel job ran this rule (--only)")
			results.append(r)
	DirAccess.make_dir_recursive_absolute(out)
	_write(out, game_name, results)
	var failed := results.filter(func(r: Dictionary) -> bool: return r.status == "fail" or r.status == "not wired")
	for r: Dictionary in results:
		print("%-10s %-9s %5.1f s  %s" % [r.rule, String(r.status).to_upper(), float(r.get("seconds", 0.0)), "; ".join(r.fails)])
	print("WORLD CHECK: %s (%d rules, %d failed, merged from %d jobs) - %s" % ["PASS" if failed.is_empty() else "FAIL", results.size(), failed.size(), dirs.size(), out.path_join("WORLD_CHECK.md")])
	var now := OS.get_environment("WSG_NOW") if OS.has_environment("WSG_NOW") else Time.get_datetime_string_from_system(true).substr(0, 16) + "Z"
	if not failed.is_empty() and OS.get_environment("WSG_WORLD_ENFORCE") != "1" and now < ENFORCED_FROM:
		print("::warning::world_check: %d rules fail; the world check fails the build from %s" % [failed.size(), ENFORCED_FROM])
		return 0
	return 0 if failed.is_empty() else 1
