extends WsgWorldGame
## Kho Kho Rush's side of wsg_world_check (the foundation's world rules, docs/WORLD_RULES.md, ADOPTING 5.18): every
## mode started as its button starts it, on the game's own code. The players and officials are WsgBodies on Medium
## and High (FoundationLink, with the licensed clips: CI has them); on Low the game draws its own models, which the
## pose, officials and feet rules cannot read - the check plays the modes at the player's tier, Medium unless set.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/wsg/world_check.gd -- --out DIR

const MatchScript := preload("res://game/match.gd")
const OFFICIALS := 5   # two umpires, the referee, the timekeeper and the scorer (Match.build_rest)


func _init() -> void:
	# The modes are played at Medium: on Low the game draws its own models (the owner: Low as it is), which the pose,
	# officials and feet rules cannot read; Medium and High draw everyone on the shared rig. (A CI machine's detected
	# tier is Low.) The tiers rule still plays every mode at Low, Medium and High.
	set_tier(Game.GFX_MEDIUM)
	Game.settings.sound = true
	Game.settings.coach = false


func game_name() -> String:
	return "Kho Kho Rush"


func prop_registry() -> String:
	return "res://game/prop_runs.gd"


func crowd_registry() -> String:
	return "res://game/crowd_venues.gd"


## Quick match (your side, after the toss: START) and Watch AI (two AI sides), each from its setup screen.
func modes() -> Array:
	return ["quick match", "watch AI"]


## The tap: the setup screen's own start, as its button calls it (Game.play_match puts WsgLoading.cover up at once).
func start_mode(mode: String, parent: Node) -> void:
	# A tap replaces what was on the screen: the last mode's match (or its setup screen) goes, as Game._swap does.
	if Game.current and is_instance_valid(Game.current):
		Game.current.queue_free()
	Game.main = parent
	Game.current = null
	var watch := mode == "watch AI"
	var screen: Node = Game.show_screen("res://ui/match_setup.gd", {"watch": watch})
	if watch:
		screen.call("_on_go")
	else:
		Game.play_match(screen.call("config", 0))


func officials(_mode: String) -> int:
	return OFFICIALS


func _match(root: Node) -> Node:
	for n in root.find_children("*", "Node3D", true, false):
		if n.get_script() == MatchScript:
			return n
	return null


## The officials: their bodies on the shared rig (FoundationLink), or the Athletes themselves where there is none.
func find_officials(root: Node) -> Array:
	var m := _match(root)
	if m == null:
		return []
	var out := []
	for o: Athlete in (m.officials as Dictionary).values():
		if is_instance_valid(o):
			out.append(o.link.body if o.link != null else o)
	return out


## A chaser as he plays in a match: on the shared rig with his locomotor (FoundationLink, Medium).
func walker(parent: Node) -> Array:
	var was := int(Game.settings.graphics)
	var was_in := FoundationLink.in_match
	Game.settings.graphics = maxi(was, Game.GFX_MEDIUM)
	FoundationLink.in_match = true
	var a := Athlete.new({"id": "w", "num": 4, "speed": 75}, 0)
	parent.add_child(a)
	Game.settings.graphics = was
	FoundationLink.in_match = was_in
	if a.link == null:
		return []   # (no licensed clips here: the rule says "not wired")
	# The check drives his locomotor along its path; his own link would drive it too, every frame, from his (still)
	# Athlete: the two fought over the feet. The link's posing is let go; the body and its locomotor are the match's.
	var gs: Skeleton3D = a.body.skeleton
	if gs.skeleton_updated.is_connected(a.link._on_game_posed):
		gs.skeleton_updated.disconnect(a.link._on_game_posed)
	return [a.link.body, a.link.loco]


## The world check's pose rule asks this before it fails a T- or A-pose (WsgWorldGame.pose_excuse). Narrow, as the lead
## ruled (2026-11-03): a pole turn only while a hand is on the pole (the other arm thrown out: the Drive video's
## slingshot), and a touch or kho reached for on the run (FoundationLink "upper": the foundation's ruling). Every pose
## asked about is printed (WORLD_POSE: who, act, mode, grip, hand to pole) so the log says what it was.
const POLE_HOLD := 0.25   # m from a hand to the pole's axis: holding it
var _pose_said := {}


func pose_excuse(body: Node) -> String:
	var link = body.get_parent() if body else null
	var a = link.get("who") if link != null else null
	if a == null or not (a is Athlete) or not is_instance_valid(a):
		return ""
	var m = a.get_parent()
	var hand := INF
	if m != null and m.get("f") != null and body is WsgBody:
		for sx in [-1.0, 1.0]:
			var pole := Vector2(sx * float(m.f.pole_gap) * 0.5, 0.0)
			for hs in ["LeftHand", "RightHand"]:
				var hp: Vector3 = (body as WsgBody).bone_world(hs).origin
				hand = minf(hand, Vector2(hp.x, hp.z).distance_to(pole))
	var why := ""
	if a.act == "pole_turn" and hand < POLE_HOLD:
		why = "pole turn: a hand on the pole (%.2f m), the other arm out" % hand
	elif String(link.get("mode")) == "upper":
		why = "a touch or kho reached for on the run: the reaching arm over the run"
	var n := int(_pose_said.get(body.get_instance_id(), 0))
	if n < 3:
		_pose_said[body.get_instance_id()] = n + 1
		print("WORLD_POSE %s: act '%s' act_t %.2f, link mode %s, weight %.2f, grip %s, speed %.1f, hand to pole %.2f m -> %s" % [
			body.name, a.act, a.act_t, link.get("mode"), float(link.layer.weight), a.body.grip, a.vel.length(), hand,
			why if why != "" else "NOT excused"])
	return why


## Low (ADOPTING 5.21): the game draws its own body there (ModelBody, the light mesh; FoundationLink is off below
## Medium), its feet held by the clips' baked foot locks, not a planter. Driven a frame at a time as play does
## (ModelBody.drive), its feet read as drawn.
func walker_low(parent: Node) -> Variant:
	var b := ModelBody.new({}, true)
	parent.add_child(b)
	b.feet()   # (watching its skeleton from now)
	var drive := func(dt: float, vel: Vector3, facing: float): b.drive(dt, vel, facing)
	var feet := func() -> Array: return b.feet()
	return [b, drive, feet]


## The whistles and the kho's slap on the back (Sfx.key: WsgAudio's kinds "whistle" and "tag").
func key_sounds() -> Array:
	return Sfx.KEY_KINDS


func audio(parent: Node) -> WsgAudio:
	return Sfx.make_key_audio(parent)


func set_tier(t: int) -> void:
	Game.settings.graphics = t
	WsgFoundation.tier = t


## The game's own mapping (Match.stick_map_at, as _stick_map uses it): the stick's [right, down] at the body.
func stick_map() -> Callable:
	return func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3:
		var ax: Array = MatchScript.stick_map_at(cam, at)
		var w: Vector2 = (ax[0] as Vector2) * st.x + (ax[1] as Vector2) * st.y
		return Vector3(w.x, 0.0, w.y)


## The match's three views (Settings: Camera; the camera button by pause), each placed as in play.
func cameras(_mode: String, root: Node) -> Array:
	var m := _match(root)
	if m == null or m.cam == null:
		return []
	var keep: int = m._cam_mode
	var out := []
	for mode in [Game.CAM_TV, Game.CAM_CLOSE, Game.CAM_POLE]:
		m._cam_mode = mode
		for i in 12:
			m._camera(1.0 / 30.0)
		var c := Camera3D.new()
		c.name = ["broadcast", "close", "behind the pole"][mode]
		c.fov = m.cam.fov
		(m.cam.get_parent() as Node).add_child(c)
		c.global_transform = m.cam.global_transform
		out.append(c)
	m._cam_mode = keep
	m._camera(1.0 / 30.0)
	return out


## props: the prop audit as CI ran it before the world check (2 matches of 120 s a ground).
func prop_args() -> Array:
	return [2, 120]
