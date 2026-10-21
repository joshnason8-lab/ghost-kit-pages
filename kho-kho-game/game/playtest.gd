class_name Playtest
extends Node
## For the scripted phone playtest (tools/playtest/): in a browser build opened with "?playtest" in its address, four
## times a second the game tells the page what is on the screen, as window.khoState: the screen, every visible button
## with its words and where it is, and in a match the phase, whose turn it is, where your chaser or defender is, the
## kho you can give, the nearest defender and the touch buttons, all in the page's pixels. It reads the game and never
## changes it. Nowhere else (not on a phone, not without the flag) does it exist.

var _t := 0.0


static func wanted() -> bool:
	if not OS.has_feature("web"):
		return false
	var q = JavaScriptBridge.eval("window.location.search", true)
	return q is String and String(q).contains("playtest")


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	JavaScriptBridge.eval("window.khoState = " + JSON.stringify(snapshot()) + ";", true)


func _k() -> float:
	var vis := get_viewport().get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	return win.x / maxf(vis.x, 1.0)


func _rect(c: Control) -> Array:
	var r := c.get_global_rect()
	var k := _k()
	return [roundi(r.position.x * k), roundi(r.position.y * k), roundi(r.size.x * k), roundi(r.size.y * k)]


func _pt(v: Vector2) -> Array:
	var k := _k()
	return [roundi(v.x * k), roundi(v.y * k)]


func snapshot() -> Dictionary:
	var cur = Game.current
	var out := {"screen": "", "buttons": [], "t": Time.get_ticks_msec(), "loading": Game.loading}
	if cur == null or not is_instance_valid(cur):
		return out
	out.screen = String(cur.get_script().resource_path).get_file().get_basename()
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		var bb := b as BaseButton
		if not bb.is_visible_in_tree() or bb.disabled:
			continue
		var text := ""
		if bb is Button:
			text = (bb as Button).text
		if text == "":
			for l in bb.find_children("*", "Label", true, false):
				text += (l as Label).text + " "
		out.buttons.append({"text": text.strip_edges(), "rect": _rect(bb)})
	if out.screen == "match":
		var m = cur
		var d := {"phase": m.phase, "chasing": m.chasing, "user": m.user, "clock": m.clock, "score": m.score,
			"turn": m.turn, "fmt": m.fmt, "dir": m.chase.dir, "half": m.chase.half, "foul": m.chase.foul}
		var cam: Camera3D = m.cam
		if cam == null or not cam.is_inside_tree() or m.phase == "intro":
			out.match = d
			return out
		if m.active:
			d.active = _pt(cam.unproject_position(m.active.position))
			d.active_x = m.active.position.x
			d.active_z = m.active.position.z
		if m.user_def:
			d.mine = _pt(cam.unproject_position(m.user_def.position))
			d.mine_x = m.user_def.position.x
			d.mine_z = m.user_def.position.z
		var ti: int = m._kho_target(false) if m.user == m.chasing else -1
		d.kho_target = ti
		var sq := []
		for i in m.squares.size():
			var p := Vector3(float(m.f.square_x[i]), 0, 0)
			sq.append({"x": p.x, "face": m.sq_face[i], "at": _pt(cam.unproject_position(p))})
		d.squares = sq
		var defs := []
		for a in m.batch:
			if m.d_state.get(a, "") == "in":
				defs.append({"x": a.position.x, "z": a.position.z, "at": _pt(cam.unproject_position(a.position))})
		d.defenders = defs
		if m.controls:
			var btns := []
			for bt in m.controls.layout():
				btns.append({"id": bt[0], "at": _pt(bt[1]), "r": roundi(float(bt[2]) * _k())})
			d.touch_buttons = btns
		d.field = {"length": m.f.length, "width": m.f.width, "pole_gap": m.f.pole_gap}
		out.match = d
	return out
