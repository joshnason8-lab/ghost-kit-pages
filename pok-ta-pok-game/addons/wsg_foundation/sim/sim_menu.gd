class_name WsgSimMenu
extends RefCounted
## WsgSim's menu fuzzer: from the game's main menu (WsgSimGame.menu_start), presses what a person could press -
## any visible, enabled button, check box, option, slider - in a seeded order, through every screen, into matches and
## out again (tournaments, seasons and cups as far as the steps reach, every setting's combinations, a quit mid-match,
## a rematch, next), and fails on: any script or engine error, a dead end (nothing to press and no match on), and the
## game's own invariants (menu_check). corrupt() spoils the game's save files first (cut short, garbage, empty, an
## old version's): the game must start anyway.

var game: WsgSimGame
var tree: SceneTree
var rng := RandomNumberGenerator.new()
var pressed := {}


func _init(p_game: WsgSimGame, seed: int, p_tree: SceneTree) -> void:
	game = p_game
	tree = p_tree
	rng.seed = seed


## STEPS presses; returns {ok, failures: [...], screens: n (distinct names pressed), presses}.
func run(steps: int, log: WsgSimLog) -> Dictionary:
	var fails := []
	log.take()
	var root := await game.menu_start(tree)
	if root == null:
		return {"ok": false, "failures": ["menu_start gave no menu"], "presses": 0}
	var idle := 0
	var presses := 0
	for i in steps:
		for k in 3:
			await tree.process_frame
		for e in log.take():
			fails.append(e)
		for m in game.menu_check():
			fails.append(m)
		var ctl := _controls(tree.root)
		if ctl.is_empty():
			if not game.in_match():
				idle += 1
				if idle > 60:
					fails.append("a dead end: nothing to press and no match on (after %d presses)" % presses)
					break
			continue
		idle = 0
		var c: Control = ctl[rng.randi() % ctl.size()]
		_press(c)
		presses += 1
		pressed[String(c.name)] = int(pressed.get(String(c.name), 0)) + 1
		if fails.size() >= 5:
			break
	return {"ok": fails.is_empty(), "failures": fails, "presses": presses, "controls": pressed.size()}


## Spoils PATH as MODE: "truncate" (cut in half), "garbage" (random bytes), "empty", "flip" (bytes changed here and
## there), or replaces it with an old version's file (OLD). Returns what it did.
func corrupt(path: String, mode: String, old := "") -> String:
	if mode == "old" and old != "":
		DirAccess.copy_absolute(ProjectSettings.globalize_path(old), ProjectSettings.globalize_path(path))
		return "%s replaced with an old version's %s" % [path, old]
	var data := FileAccess.get_file_as_bytes(path)
	match mode:
		"truncate":
			data = data.slice(0, data.size() / 2)
		"garbage":
			data = PackedByteArray()
			for k in 64 + rng.randi() % 512:
				data.append(rng.randi() % 256)
		"empty":
			data = PackedByteArray()
		"flip":
			for k in maxi(1, data.size() / 50):
				if data.size() > 0:
					data[rng.randi() % data.size()] = rng.randi() % 256
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()
	return "%s: %s" % [path, mode]


func _controls(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		if ctl is BaseButton and not (ctl as BaseButton).disabled:
			out.append(ctl)
		elif ctl is Range and ctl is not ScrollBar and ctl is not ProgressBar and (ctl as Range).editable:
			out.append(ctl)
	return out


func _press(c: Control) -> void:
	if c is OptionButton:
		var ob := c as OptionButton
		if ob.item_count > 0:
			ob.select(rng.randi() % ob.item_count)
			ob.item_selected.emit(ob.selected)
	elif c is BaseButton:
		var b := c as BaseButton
		if b.toggle_mode:
			b.button_pressed = not b.button_pressed
		else:
			b.pressed.emit()
	elif c is Range:
		var r := c as Range
		r.value = rng.randf_range(r.min_value, r.max_value)
