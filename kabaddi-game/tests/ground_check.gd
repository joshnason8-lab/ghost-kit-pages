extends Node3D
## How well the realistic bodies meet the floor: poses a player through stances, moves, falls and running,
## skins the actual mesh on the CPU every few frames and reports, per move, how far its lowest point sits
## above (+) or below (-) the floor while the move means to be on it. Run with "off" to compare without
## grounding.
##   godot --headless --path . res://tests/ground_check.tscn [-- off]

const MOVES := [["raid", 1.5], ["ready", 1.5], ["idle", 1.5], ["touch", 0.34], ["kick", 0.5], ["backkick", 0.46],
	["dodge", 0.26], ["dubki", 0.42], ["jump", 0.62], ["held", 1.5], ["fallen", 2.0], ["recover", 1.1],
	["celebrate", 1.5], ["slump", 2.0]]
const RUNS := [["walk", 1.5, Vector2(0, 1)], ["jog", 2.5, Vector2(0, 1)], ["sprint", 5.0, Vector2(0, 1)],
	["strafe", 3.0, Vector2(1, 0)], ["backpedal", 2.4, Vector2(0, -1)], ["shuffle", 2.0, Vector2(-1, 0)]]


func _ready() -> void:
	RiggedBody.grounding = not ("off" in OS.get_cmdline_user_args())
	Game.settings.models = 1
	var worst := 0.0
	for b in RiggedBody.bodies().slice(0, 3):
		var data: Dictionary = DB.team("MUM").squad[0].duplicate(true)
		data["body"] = String(b.file)
		var a := Athlete.new()
		a.setup(data, 0, Color.TEAL, Color.WHITE, true)
		add_child(a)
		a.facing = Vector3(0, 0, -1)
		a.set_process(false)
		var line := String(b.file) + ":"
		for m in MOVES:
			if m[0] == "ready":
				a.tackle_kind = "ankle"
			a.vel = Vector3.ZERO
			a.set_state(m[0], m[1])
			var r := _run(a, m[1] + 0.3)
			line += " %s %+.1f/%+.1f" % [m[0], r.x * 100, r.y * 100]
			worst = maxf(worst, maxf(absf(r.x), absf(r.y)))
		for m in RUNS:
			a.set_state("ready" if m[0] == "shuffle" else "idle", 1000.0)
			var right := a.facing.cross(Vector3.UP)
			a.vel = (right * m[2].x + a.facing * m[2].y) * m[1]
			var r := _run(a, 1.5)
			line += " %s %+.1f/%+.1f" % [m[0], r.x * 100, r.y * 100]
			worst = maxf(worst, maxf(absf(r.x), absf(r.y)))
		print(line)
		a.queue_free()
	print("worst %.1f cm off the floor while on it (grounding %s)" % [worst * 100, "on" if RiggedBody.grounding else "off"])
	get_tree().quit()


## Lowest skinned point over the move, while the motion means to be on the floor: (lowest, highest), m.
func _run(a: Athlete, secs: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var n := int(secs * 30.0)
	for f in n:
		a.st_t += 1.0 / 30.0
		a._pose(1.0 / 30.0)
		a.model._process(1.0 / 30.0)
		if f < 8 or f % 3 != 0 or a.model.air > 0.01:
			continue
		var y := _lowest_vertex(a.model.rig)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return Vector2(lo, hi) if lo < INF else Vector2.ZERO


func _lowest_vertex(rig: RiggedBody) -> float:
	var sk := rig.skeleton
	var arrays := (rig.body.mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var pose := []
	for i in sk.get_bone_count():
		pose.append(sk.get_bone_global_pose(i) * Transform3D(Basis(), rig._rest_head[i]).affine_inverse())
	var low := INF
	for v in range(0, verts.size(), 7):
		var p := Vector3.ZERO
		for k in 4:
			var w := weights[v * 4 + k]
			if w > 0.0:
				p += (pose[bones[v * 4 + k]] as Transform3D) * verts[v] * w
		low = minf(low, p.y)
	return low * rig.scale.y
