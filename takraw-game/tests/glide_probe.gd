class_name GlideProbe
extends Node
## Gliding, measured: in AI matches, every frame a player is on the floor and moving (his body over 0.5 m/s) with a
## foot down (its ankle within FLOOR_FOOT of its height standing, as RealBody plants it; a running man's both feet are
## off the floor a moment each stride), how fast his feet on the floor move over it. A man stepping has a foot planted (still); a man gliding carries the foot
## he stands on along at his own speed. For each kind of moment (a move playing, by
## name; running with no move; walking between points) the frames, how far he travelled, and how far of it glided
## (his slower foot over half his speed), worst first:
##   godot --headless --path . --fixed-fps 30 res://tests/glide_probe.tscn [-- seconds [seeds]]

const SLIDE := 0.5
const FLOOR_FOOT := 0.03   # m: an ankle this close to its height standing is on the floor (RealBody.PLANT_HEIGHT)


func _ready() -> void:
	Game.main = self
	Game.reset_settings_for_tests()
	FoundationLink.off = true
	Game.settings.graphics = Game.GFX_LOW
	var a := OS.get_cmdline_user_args()
	var secs := float(a[0]) if a.size() > 0 else 180.0
	var seeds: Array = Array(a[1].split(",")).map(func(s): return int(s)) if a.size() > 1 else [7]
	var stats := measure(self, secs, seeds)
	var steps: Dictionary = stats.get("_steps", {})
	stats.erase("_steps")
	print("planted-foot slide per step (cm): kind, steps, median, 95th percentile, worst")
	for k in steps:
		var v: Array = steps[k]
		v.sort()
		print("  %-22s %5d %6.1f %6.1f %6.1f" % [k, v.size(), 100.0 * float(v[v.size() / 2]), 100.0 * float(v[int(v.size() * 0.95)]), 100.0 * float(v[-1])])
	var rows: Array = stats.keys()
	rows.sort_custom(func(x, y): return float(stats[x][2]) > float(stats[y][2]))
	print("%-22s %7s %9s %9s %6s" % ["", "frames", "moved m", "glided m", "share"])
	for k in rows:
		var s: Array = stats[k]
		print("%-22s %7d %9.1f %9.1f %5.0f%%" % [k, s[0], s[1], s[2], 100.0 * float(s[2]) / maxf(float(s[1]), 0.001)])
	get_tree().quit()


## {kind: [frames, metres moved, metres glided]} over SECS of match time for each seed (regu at the National Arena),
## and "_steps": {kind: [metres each planted foot slid over the floor from putting down to lifting, ...]} (the kind
## the player was in as it lifted; steps of at least two frames down while he moved).
static func measure(host: Node, secs: float, seeds: Array) -> Dictionary:
	var stats := {}
	var steps := {}
	var down := {}   # [player, foot] -> [where it went down, frames, kind, moved?]
	for sd in seeds:
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 1, "points": 15,
			"user_team": -1, "demo": true, "seed": sd, "mode": "quick"}
		host.add_child(m)
		var last := {}
		var dt := 1.0 / 30.0
		for i in int(secs * 30.0):
			m._process(dt)
			m.set("_start_replay_after", -1.0)
			if int(m.state) == int(m.S.REPLAY) or int(m.state) == int(m.S.OVER):
				last.clear()
				continue
			for side in 2:
				for pp in m.players_on(side):
					var pl: Player = pp
					var fl: Vector3 = pl.body.bone_world("foot_l")
					var fr: Vector3 = pl.body.bone_world("foot_r")
					var was: Array = last.get(pl, [])
					last[pl] = [fl, fr, pl.global_position, float(pl.get("_yaw"))]
					if was.is_empty() or absf(pl.body.position.y) > 0.02:
						continue
					var body_v := Vector2(pl.global_position.x - was[2].x, pl.global_position.z - was[2].z).length() / dt
					if body_v < 0.5:
						continue
					var ground: Array = RealBody._leg_cal(RealBody.rig(pl.body.women)).ground
					var sc := pl.body.global_transform.basis.get_scale().y
					var vl := Vector2(fl.x - was[0].x, fl.z - was[0].z).length() / dt if fl.y < float(ground[0]) * sc + FLOOR_FOOT else INF
					var vr := Vector2(fr.x - was[1].x, fr.z - was[1].z).length() / dt if fr.y < float(ground[1]) * sc + FLOOR_FOOT else INF
					var kind0 := pl.move if pl.move != "" else ("walk (between points)" if pl.stroll else "run")
					for f in 2:
						var on: bool = (vl if f == 0 else vr) != INF
						var at: Vector3 = fl if f == 0 else fr
						var key := [pl, f]
						if on:
							if not down.has(key):
								down[key] = [at, 0, kind0]
							down[key][1] += 1
							down[key][2] = kind0
						elif down.has(key):
							var d0: Array = down[key]
							if int(d0[1]) >= 2:
								var s0: Array = steps.get(String(d0[2]), [])
								s0.append(Vector2(at.x - (d0[0] as Vector3).x, at.z - (d0[0] as Vector3).z).length() if false else d0[3] if d0.size() > 3 else 0.0)
								steps[String(d0[2])] = s0
							down.erase(key)
						if on and down.has(key):
							# (how far it is from where it went down, the most it got: its slide while down)
							var d1: Array = down[key]
							var off := Vector2(at.x - (d1[0] as Vector3).x, at.z - (d1[0] as Vector3).z).length()
							if d1.size() < 4:
								d1.append(off)
							else:
								d1[3] = maxf(float(d1[3]), off)
					if vl == INF and vr == INF:
						continue   # (both feet off the floor: a running stride's flight, a jump)
					var kind := pl.move if pl.move != "" else ("walk (between points)" if pl.stroll else "run")
					if OS.get_environment("GLIDE_DETAIL") != "" and pl.move == "":
						var turn := absf(wrapf(float(pl.get("_yaw")) - float(was[3]), -PI, PI)) / dt if was.size() > 3 else 0.0
						kind += " %s %s%s" % ["<1.5" if body_v < 1.5 else ("<3" if body_v < 3.0 else "3+"),
							["back", "side", "fwd", "side", "back"][int(pl.get("_gait")) + 2], " TURN" if turn > 4.0 else ""]
					var s: Array = stats.get(kind, [0, 0.0, 0.0])
					s[0] += 1
					s[1] += body_v * dt
					if minf(vl, vr) > SLIDE * body_v:
						s[2] += body_v * dt
					stats[kind] = s
		m.queue_free()
		host.remove_child(m)
	stats["_steps"] = steps
	return stats
