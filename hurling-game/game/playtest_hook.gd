extends Node
## For playtesting the Web build in a browser (docs/PLAYTEST.md): with ?playtest in the page's address, what is on
## the screen is put in window.ashState a few times a second (the buttons and where they are, your player, the
## sliotar, the goal you attack, all in the page's pixels), so a test script can play through the real touch controls.
## Nothing else reads it, and without ?playtest it is never added.

var m: Node
var _t := 0.0


static func wanted() -> bool:
	return OS.has_feature("web") and String(JavaScriptBridge.eval("location.search", true)).contains("playtest")


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or m == null:
		return
	_t = 0.12
	var xf: Transform2D = get_viewport().get_final_transform()
	var cam: Camera3D = m.cam.camera
	var px := func(p: Vector3) -> Array:
		if cam.is_position_behind(p):
			return []
		var s: Vector2 = xf * cam.unproject_position(p)
		return [roundi(s.x), roundi(s.y)]
	var buttons := []
	for b in m.controls._layout():
		var c: Vector2 = xf * (b[1] as Vector2)
		buttons.append({"id": b[0], "x": roundi(c.x), "y": roundi(c.y), "r": roundi(float(b[2]) * xf.get_scale().x)})
	var a: Node3D = m.active
	var st := {
		"phase": int(m.phase), "phase_name": String(m.P.keys()[int(m.phase)]), "half": int(m.half), "clock": int(m.clock),
		"score": m.score, "paused": bool(m.paused), "buttons": buttons,
		"active": px.call(a.global_position + Vector3(0, 1.0, 0)) if a != null else [],
		"ball": px.call(m.ball.global_position), "ball_h": snappedf(m.ball.global_position.y, 0.1),
		"carrier": -1 if m.carrier == null else int(m.carrier.team), "mine": m.carrier != null and m.carrier == a,
		"in_hand": m.carrier != null and m.carrier == a and bool(a.ball_hand),
		"goal": px.call(Vector3(Pitch.HALF_L * m.dir(m.user_team), 1.5, 0)) if m.user_team >= 0 else [],
		"goal_dist": snappedf(Pitch.from_goal_line(a.global_position, m.dir(a.team)), 0.1) if a != null else 0.0,
		"user_team": int(m.user_team), "restart": String(m.restart.get("kind", "")),
		"taker": m.taker != null and m.taker == a, "events": m.events.size(),
		"drop": px.call(m.hud._drop) if m.hud._drop != Vector3.INF else [],
		"fired": m.controls.last_fired, "action": String(a.action) if a != null else "", "busy": a != null and a.busy(),
	}
	JavaScriptBridge.eval("window.ashState = " + JSON.stringify(st) + ";", true)
