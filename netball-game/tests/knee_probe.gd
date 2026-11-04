extends Node
## The knees as drawn (the foundation's world rule "knees": no knee more than 4 cm behind its hip-ankle line), measured
## on the game's own modes before the rule is out:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/knee_probe.tscn -- [tier] [seconds] [modes,...]
## Each mode (World.modes: quick match, cup, league, Watch AI) is started by its own button's handler (World.start_mode),
## at the tier (0 Low, 1 Medium, 2 High), its loading waited out, then SECONDS of play (30 s quarters: the quarter's
## break and its restart in it) watched. Every frame, every skeleton drawn (a skinned mesh of it visible) is read as
## drawn: inside its skeleton_updated (after the foundation's modifiers; our own body has none). Its legs from
## World.leg_bones, or the planter's (WsgFootPlanter.LEGS) on a foundation body that has one. For each leg: how far the
## knee lies behind the hip-ankle line, against the body's forward (the hips' forward: the 4th entry of leg_bones, or
## the toes' at rest, turned as the hips are now). Prints a KNEES line per mode: frames, legs checked, knees over 4 cm
## behind, the worst and whose (her role and move), and what was seen played (leaps, shots, defending, the umpires
## walking, the reserves seated).

const LIMIT := 0.04

var world: WsgWorldGame
var _hooked := {}        # skeleton id -> true
var _latest := {}        # skeleton id -> [ [behind_l, behind_r], who ]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var tier := int(a[0]) if a.size() > 0 else Game.GFX_LOW
	var secs := float(a[1]) if a.size() > 1 else 70.0
	world = (load("res://game/world.gd") as Script).new()
	var modes: Array = Array(a[2].split(",")) if a.size() > 2 else world.modes()
	world.set_tier(tier)
	Game.settings.sound = false
	Game.test_quarter_s = 30.0
	var rows := []
	for mode in modes:
		rows.append(await _play(String(mode), tier, secs))
	print("KNEES_TABLE tier %d" % tier)
	for r in rows:
		print(r)
	get_tree().quit()


func _play(mode: String, tier: int, secs: float) -> String:
	var holder := Node.new()
	holder.name = "Mode_" + mode
	add_child(holder)
	await get_tree().process_frame
	_hooked.clear()
	_latest.clear()
	world.start_mode(mode, holder)
	var waited := 0
	while waited < 30 * 600:
		await get_tree().process_frame
		waited += 1
		if waited > 3 and not WsgLoading.busy() and Game.current is Match:
			break
	var m: Match = Game.current as Match
	var frames := 0
	var legs := 0
	var over := 0
	var skipped := 0
	var worst := -INF
	var worst_who := ""
	var unmapped := {}
	var seen := {}
	var over_who := {}
	for f in int(secs * 30.0):
		await get_tree().process_frame
		frames += 1
		for sk: Skeleton3D in holder.find_children("*", "Skeleton3D", true, false):
			if not drawn(sk):
				continue
			var id := sk.get_instance_id()
			if not _hooked.has(id):
				_hooked[id] = true
				sk.skeleton_updated.connect(_read.bind(sk))
				_read(sk)
			var e: Array = _latest.get(id, [])
			if e.is_empty():
				continue
			if (e[0] as Array).is_empty():
				unmapped[e[1]] = true
				continue
			for b: float in e[0]:
				if is_nan(b):
					skipped += 1
					continue
				legs += 1
				if b > LIMIT:
					over += 1
					var k := String(e[1]).split(" ")[0] + " " + String(e[2])
					over_who[k] = int(over_who.get(k, 0)) + 1
					if OS.has_environment("KNEE_DEBUG"):
						_debug(sk, b)
				if b > worst:
					worst = b
					worst_who = "%s [%s]" % [e[1], e[2]]
		if m and is_instance_valid(m):
			for t in 2:
				for pl: Player in m.players[t]:
					seen[pl.act] = true
					if pl.land_clip != "":
						seen["landing"] = true
			for u: Umpire in m.umpires:
				if u.vel.length() > 0.3:
					seen["umpire walking"] = true
				if u.sig != "":
					seen["signal " + u.sig] = true
			var res := m.get_node_or_null("Reserves")
			if res and res.get_child_count() > 0:
				seen["reserves seated"] = true
	var tops := over_who.keys()
	tops.sort_custom(func(x, y): return over_who[x] > over_who[y])
	var line := "KNEES %-6s %-6s frames %d, legs %d, over 4 cm %d, worst %.1f cm by %s; unmapped drawn skeletons: %s; degenerate legs skipped %d; over by: %s; seen: %s" % [
		mode, ["Low", "Medium", "High"][tier], frames, legs, over, worst * 100.0, worst_who, unmapped.keys(), skipped,
		", ".join(tops.slice(0, 6).map(func(k): return "%s x%d" % [k, over_who[k]])), ", ".join(seen.keys())]
	print(line)
	# Stopped and out of sight (as the world check leaves a played mode).
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	holder.queue_free()
	Game.current = null
	await get_tree().process_frame
	while WsgLoading.busy():
		await get_tree().process_frame
	return line


## SK's legs as posed now (inside skeleton_updated: as drawn): [[behind per leg (m; NAN: the leg along the forward)],
## who, move].
func _read(sk: Skeleton3D) -> void:
	if not is_instance_valid(sk):
		return
	var w := who(sk)
	_latest[sk.get_instance_id()] = [behind(world, sk), w[0], w[1]]


## How far each leg's knee of SK lies behind its hip-ankle line as posed now (world m; + behind, against the body's
## forward: the 4th entry of WORLD.leg_bones, or the toes' way at rest, as the hips turn it now and as at rest, the worse; NAN where the leg
## lies along the forward). The legs from WORLD.leg_bones, or the planter's (WsgFootPlanter.LEGS) on a foundation body
## that has one; [] for a skeleton with neither.
static func behind(world: WsgWorldGame, sk: Skeleton3D) -> Array:
	var legs: Array = world.call("leg_bones", sk)
	if legs.is_empty():
		for c in sk.get_children():
			if c is WsgFootPlanter:
				legs = WsgFootPlanter.LEGS
	var out := []
	var g := sk.global_transform
	for leg: Array in legs:
		var ix := [sk.find_bone(leg[0]), sk.find_bone(leg[1]), sk.find_bone(leg[2])]
		if ix.has(-1):
			continue
		var hip := g * sk.get_bone_global_pose(ix[0]).origin
		var knee := g * sk.get_bone_global_pose(ix[1]).origin
		var ank := g * sk.get_bone_global_pose(ix[2]).origin
		var f_rest: Vector3
		if leg[3] is Vector3:
			f_rest = leg[3]
		else:
			var ti := sk.find_bone(String(leg[3]))
			f_rest = sk.get_bone_global_rest(ti).origin - sk.get_bone_global_rest(ix[2]).origin
			f_rest.y = 0.0
		var hb := sk.get_bone_parent(ix[0])
		var turn := Basis.IDENTITY
		if hb >= 0:
			turn = sk.get_bone_global_pose(hb).basis.orthonormalized() * sk.get_bone_global_rest(hb).basis.orthonormalized().inverse()
		var d := (ank - hip).normalized()
		var perp := (knee - hip) - d * d.dot(knee - hip)
		# (Against both forwards, the worse: the hips' now, and the skeleton's at rest - the rule's may be either.)
		var worst := NAN
		for fwd: Vector3 in [(g.basis * (turn * f_rest)).normalized(), (g.basis * f_rest).normalized()]:
			var fp := fwd - d * d.dot(fwd)
			if fp.length() < 0.2:
				continue
			var b := -perp.dot(fp.normalized())
			worst = b if is_nan(worst) else maxf(worst, b)
		out.append(worst)
	return out


## (KNEE_DEBUG=1: what her body and feet were doing when a knee went over.)
func _debug(sk: Skeleton3D, b: float) -> void:
	var n: Node = sk
	while n and not (n is Player or n is Umpire):
		n = n.get_parent() if not n is FoundationLink else (n as FoundationLink).who
	var line := "KNEE_DEBUG %.1f cm %s" % [b * 100.0, who(sk)]
	if n is Player:
		var p := n as Player
		line += " legs_w %.2f land_w %.2f move %.2f vel %.2f body_yaw %.2f facing %.2f" % [p.legs_w, p.land_w, p.gait.move, p.vel.length(), p.body_yaw, p.facing]
		for i in 2:
			var f: Gait.Foot = p.gait.feet[i]
			line += " | foot%d down %s s %.2f fyaw %.2f" % [i, f.down, f.s, f.fyaw]
	for bn in ["hips", "thigh_l", "shin_l", "thigh_r", "shin_r"]:
		var i := sk.find_bone(bn)
		if i >= 0:
			line += " %s %s" % [bn, (sk.get_bone_pose_rotation(i).get_euler(EULER_ORDER_YXZ) * 57.3).snapped(Vector3.ONE)]
	print(line)


## A skeleton drawn: a visible skinned mesh on it.
static func drawn(sk: Skeleton3D) -> bool:
	if not sk.is_visible_in_tree():
		return false
	for c in sk.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible and (c as MeshInstance3D).mesh != null:
			return true
	return false


## Who the skeleton draws, and her move: [role, move].
static func who(sk: Skeleton3D) -> Array:
	var n: Node = sk
	while n:
		if n is FoundationLink:
			var l := n as FoundationLink
			if l.kind == "reserve":
				return ["reserve(foundation)", "seated/clap"]
			if l.who:
				n = l.who
				continue
		if n is Player:
			var p := n as Player
			return ["%s%d" % [p.pos, p.team], "%s%s %.0f%%" % [p.act, (" " + p.land_clip) if p.land_clip != "" else "", minf(p.act_t / 0.7, 1.0) * 100.0 if p.act == "leap" else 0.0]]
		if n is Umpire:
			var u := n as Umpire
			return ["umpire%d" % u.half, ("signal " + u.sig) if u.sig != "" else ("walking" if u.vel.length() > 0.3 else "standing")]
		if n.name == "Reserves":
			return ["reserve", "seated/clap"]
		n = n.get_parent()
	return [String(sk.get_path()).get_slice("/", 3), "?"]
