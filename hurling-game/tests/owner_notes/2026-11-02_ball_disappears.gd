extends WsgOwnerNote
## The owner (relayed by the lead), 2026-11-02 (Hurling 0.18.0): "ball disappears in some free take shots"

const NOTE := {"id": "2026-11-02-ball-disappears", "game": "hurling", "date": "2026-11-02", "version": "Hurling 0.18.0", "words": "ball disappears in some free take shots"}
const Kit := preload("res://tests/note_kit.gd")

## A free's sliotar, all the way along its flight from the low camera behind the taker (4 to 70 m off): drawn, and
## never smaller on the screen than 4 pixels across (the dot comes up where it would be less).
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "practice", "user_team": 0, "seed": 7}, 5, true)
	var cam: Camera3D = m.get_viewport().get_camera_3d()
	var vp := Vector2(1280, 720)
	var fwd := -cam.global_transform.basis.z
	var smallest := INF
	var at := 0.0
	for d in range(4, 71, 2):
		var p: Vector3 = cam.global_position + fwd * float(d)
		var px: float = m.hud.ball_px(cam, p, vp)
		var dot: bool = m.hud.ball_dot_on(cam, p, vp) if m.hud.has_method("ball_dot_on") else px < 4.0
		var seen := maxf(px, 4.0 if dot else 0.0)
		if seen < smallest:
			smallest = seen
			at = d
	info("the smallest the sliotar shows over 4-70 m: %.1f px (at %.0f m)" % [smallest, at])
	expect(m.ball.visible, "the sliotar is hidden")
	expect(smallest >= 4.0, "at %.0f m the sliotar is %.1f px across: lost" % [at, smallest])
	await Kit.done(tree, m)
