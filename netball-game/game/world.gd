extends WsgWorldGame
## Netball Unleashed's side of the foundation's world check (docs/WORLD_RULES.md, ADOPTING §5.18): the rules every
## game's world keeps, checked in CI on the game's own code.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/wsg/world_check.gd -- --out "$RUNNER_TEMP/world"
## The modes are the menus' own buttons: a quick match (the team sheet's Play), a Nations Cup match and a Club Season
## match (their screens' Play) and Watch AI (the team sheet's Watch), each started by that screen's own handler, at
## Medium (the game's default on a phone with the licensed clips: the players and umpires on the foundation's rig).


## The check plays at Medium (a phone's default with the licensed clips) unless a rule sets the tier (tiers: set_tier),
## with the automatic lowering off (a slow machine running the check is not a slow phone).
func _init() -> void:
	set_tier(Game.GFX_MEDIUM)
	Game.settings.auto_gfx = false


func game_name() -> String:
	return "Netball Unleashed"


func prop_registry() -> String:
	return "res://tests/prop_runs.gd"


func prop_args() -> Array:
	return [1, 60]


func crowd_registry() -> String:
	return "res://game/crowd_venues.gd"


func modes() -> Array:
	return ["quick", "cup", "league", "watch"]


## The tap on the mode's Play button: that screen's own handler (Game.start_match_loading when the game has it, the
## loading overlay up in this frame; else Game.start_match), the match made under PARENT.
func start_mode(mode: String, parent: Node) -> void:
	Game.settings.sound = false
	# The previous mode's match stays for the report (its bodies are read after), stopped and out of sight.
	if Game.current and is_instance_valid(Game.current):
		Game.current.process_mode = Node.PROCESS_MODE_DISABLED
		if Game.current is Node3D:
			(Game.current as Node3D).visible = false
		for c in Game.current.find_children("*", "Camera3D", true, false):
			(c as Camera3D).current = false
	Game.current = null
	Game.main = parent
	match mode:
		"quick", "watch":
			var qs: Node = (load("res://ui/quick_setup.gd") as Script).new()
			qs.call("_watch" if mode == "watch" else "_play")
			qs.free()
		"cup":
			var cup := Cup.create("AUS")
			Game.cup = cup
			var cs: Node = (load("res://ui/cup_screen.gd") as Script).new()
			cs.call("_play", cup, cup.next_user_match())
			cs.free()
		"league":
			var league := League.create(String(DB.CLUBS[0][0]))
			Game.league = league
			var ls: Node = (load("res://ui/league_screen.gd") as Script).new()
			ls.call("_play", league, league.next_user_match())
			ls.free()


## The player's graphics choice, as the Settings screen makes it (Game.settings.graphics), handed to the foundation
## (WsgFoundation.tier) as the game does at start.
func set_tier(t: int) -> void:
	Game.settings.graphics = t
	WsgFoundation.tier = t


func officials(_mode: String) -> int:
	return 2   # the two umpires, every mode


## The umpires as drawn: each Umpire's body on the foundation's rig (FoundationLink kind "umpire").
func find_officials(root: Node) -> Array:
	var out := []
	for u in root.find_children("*", "Umpire", true, false):
		for l in u.find_children("*", "FoundationLink", true, false):
			if (l as FoundationLink).body:
				out.append(l)
	return out


## Our player as she is drawn in a match on Medium: the owner's model on the foundation's rig, at a player's height.
func walker(parent: Node) -> Array:
	var body := WsgBody.new(WsgBody.load_character(FoundationLink.DIR, "hero"), null, 0)
	body.scale = Vector3.ONE * (1.75 / FoundationLink.RIG_H)
	parent.add_child(body)
	var loco := WsgLocomotor.attach(body)
	return [body, loco]


## Our player as she is drawn on Low (ADOPTING §5.21; the owner plays at Low): the game's own body (HeroBody) and its
## feet (Gait), made as a match makes her on Low, standing at the origin. Each frame of the drive moves her by the
## velocity and steps her feet (Gait.update), her body posed from them as Player._animate does on the run; her feet read
## as drawn (Gait.drawn_feet: the ankles' bones, the balls of the feet - no modifier, the pose set is the one drawn).
func walker_low(parent: Node) -> Variant:
	var was := int(Game.settings.graphics)
	Game.settings.graphics = Game.GFX_LOW      # (her own body: no FoundationLink on Low)
	var pl := Player.new(0, DB.squad("NZL")[2], "WA")
	parent.add_child(pl)
	Game.settings.graphics = was
	pl.place(Vector2.ZERO, 0.0)
	var drive := func(dt: float, vel: Vector3, facing: float) -> void:
		pl.position += Vector3(vel.x, 0.0, vel.z) * dt
		pl.p = Vector2(pl.position.x, pl.position.z)
		pl.vel = Vector2(vel.x, vel.z)
		pl.facing = facing
		pl.rotation.y = facing
		pl.body.rotation.y = 0.0
		pl.gait.update(dt, pl.p, pl.vel, facing)
		var out := Gait.lay(pl.gait.loco_pose(), pl._pose, 0.0, 1.0 - pl.gait.move)
		pl.body.apply(pl.gait.solve(out))
	var feet := func() -> Array:
		return pl.gait.drawn_feet()
	return [pl, drive, feet]


## The key moments' sounds (Sfx's names): the ball off the ring and post, the net, the umpire's whistle.
func key_sounds() -> Array:
	return ["rim", "swish", "whistle_short", "whistle_long"]


## The sounds Sfx keeps crisp at a distance (Sfx.BRIGHT), as the foundation's WsgAudio would have them.
func audio(parent: Node) -> WsgAudio:
	var au := WsgAudio.new()
	parent.add_child(au)
	au.bright_kinds = Sfx.BRIGHT.duplicate()
	au.bright_distance = Sfx.BRIGHT_DISTANCE
	return au


## The stick as the match reads it: CameraRig.court_dir, through each camera.
func stick_map() -> Callable:
	return func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3:
		if cam is CameraRig:
			var d: Vector2 = (cam as CameraRig).court_dir(st, at)
			return Vector3(d.x, 0, d.y)
		return Vector3.ZERO


## The match's cameras: the broadcast (TV), courtside (LOW) and behind the goal (END), each set as in play.
func cameras(_mode: String, root: Node) -> Array:
	var m: Match = null
	for n in root.find_children("*", "Match", true, false):
		m = n
	if m == null or m.cam == null:
		return []
	var out := []
	for cm in [Game.CAM_TV, Game.CAM_LOW, Game.CAM_END]:
		var c := CameraRig.new()
		c.name = ["TV", "Low", "End"][[Game.CAM_TV, Game.CAM_LOW, Game.CAM_END].find(cm)]
		m.add_child(c)
		c.mode = cm
		c.end_dir = m.cam.end_dir
		c.track(m.ball.court_pos(), 0, 1.0 / 30.0, true)
		c.current = false
		out.append(c)
	m.cam.make_current()
	return out


## knees: each leg's bones on a skeleton of ours, [[thigh_l, shin_l, foot_l, toe_l], [thigh_r, shin_r, foot_r, toe_r]]:
##   - our own body (ToonBody, and HeroBody on its bones: the players and umpires on Low, the reserves' figure under
##     the foundation's on Medium and High): its bones thigh_*, shin_*, foot_*; it has no toe bone, so the 4th is the
##     body's forward at rest in skeleton space, +Z (every bone's rest rotation is the identity, the figure facing +Z);
##   - the foundation's body drawn for a reserve on the bench (FoundationLink kind "reserve": posed by the game, no
##     locomotor, so no WsgFootPlanter for the rule to read): the rig's names, as WsgFootPlanter.LEGS has them.
## [] for any other skeleton: the players' and umpires' WsgBody on Medium and High carry a WsgFootPlanter (their
## WsgLocomotor's) the rule reads itself.
func leg_bones(skeleton: Skeleton3D) -> Array:
	if skeleton == null:
		return []
	var holder := skeleton.get_parent()
	if holder is ToonBody and (holder as ToonBody).skeleton == skeleton:
		var out := []
		for s in ["l", "r"]:
			out.append(["thigh_" + s, "shin_" + s, "foot_" + s, Vector3(0, 0, 1)])
		return out
	if holder is WsgBody and holder.get_parent() is FoundationLink:
		var link := holder.get_parent() as FoundationLink
		if link.body == holder and link.loco == null:
			return WsgFootPlanter.LEGS.duplicate(true)
	return []


## knees: why a knee of SKELETON may be bent the wrong way this frame - only a named acrobatic move while it plays
## (a leap's tuck), never by who she is. "": none. None of our moves bends a knee back (Poses' legs bend forward, Gait's
## IK puts the knee ahead of the hip-ankle line, the reserves' seated knees over their feet), so none is excused.
func knee_excuse(_skeleton: Skeleton3D) -> String:
	return ""
