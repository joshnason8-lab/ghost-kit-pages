extends WsgWorldGame
## Kabaddi Raid's side of wsg_world_check (docs/WORLD_RULES.md, ADOPTING 5.18): the game's own start code, players,
## officials, sounds, stick and cameras, checked against the rules every World Stage game keeps.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/wsg/world_check.gd -- --out "$RUNNER_TEMP/world" --web-pck build/web/index.pck
##
## Every start goes through Game.start_match (Play, Watch, a cup or season fixture): the modes are those starts.


## The modes are played at Medium: the shared rig draws the players and officials there and on High (Low draws the
## game's own bodies, which the pose and officials rules do not read). The tiers rule sets each level itself.
func _init() -> void:
	set_tier(Game.GFX_MEDIUM)


## Nothing put off: every world rule is enforced.
func deferred() -> Dictionary:
	# (tiers: deferred to 2026-11-04 12:00 by the lead; met on 2026-11-03 - Low's lighter bodies, the village's huts out
	# of the sun's shadow map: season at Medium 126 -> 114 draw calls.)
	return {}


func game_name() -> String:
	return "Kabaddi Raid"


func prop_registry() -> String:
	return "res://game/prop_runs.gd"


func prop_args() -> Array:
	return [1, 60]


func crowd_registry() -> String:
	return "res://game/crowd_venues.gd"


## Quick match (the player defending and raiding), Watch AI, a cup final (the walk-out, the stadium), a season fixture
## at a local ground (chairs, stools, the scorers' trestle table).
func modes() -> Array:
	return ["match", "watch AI", "cup final", "season"]


func _config(mode: String) -> Dictionary:
	var c := {"home": "MUM", "away": "PUN", "length": 0, "difficulty": 1, "arena": "dome", "mode": "quick"}
	match mode:
		"watch AI":
			c.merge({"watch": true, "autoplay": true, "arena": "beach"}, true)
		"cup final":
			c.merge({"mode": "cup", "walkout": true, "arena": "stadium", "knockout": true}, true)
		"season":
			c.merge({"mode": "season", "arena": "village"}, true)
	return c


## The tap: the quick-match screen up (its buttons there to be turned off), then its Play, as the player does it.
## At the level the check last set: Medium for the modes (_init), each level in turn for the tiers rule.
func start_mode(mode: String, parent: Node) -> void:
	# The last mode's match, finished (stopped and hidden in cameras()), is let go rather than freed as a tap would: the
	# check keeps each mode's bodies and officials to read until it frees the modes itself (free_modes); its rules
	# loop over them typed, and a freed one is a script error there.
	var last: Node = Game.current
	if last and is_instance_valid(last) and last.process_mode == Node.PROCESS_MODE_DISABLED:
		Game.current = null
	Game.main = parent
	Game.settings.sound = false
	# The level the check sets stays: on its software renderer every frame is slow, and the match would lower its own
	# graphics mid-play (Match._check_frame_rate), releasing the shared bodies the check has hold of.
	Game.settings.auto_gfx = false
	Game.loading_overlay = true
	Game.show_screen("res://ui/quick_setup.gd")
	Game.start_match(_config(mode))


func play_seconds(_mode: String) -> float:
	return 6.0


## The referee, two umpires and two line judges on their feet (the two scorers sit at their table).
func officials(_mode: String) -> int:
	return 5


## A player as the match draws him on Medium and High: his own Meshy rig, its locomotor as FoundationLink sets it up
## (a cut measured from the way he was going), his feet turned down if his model stands toe-up.
func walker(parent: Node) -> Array:
	set_tier(Game.GFX_MEDIUM)
	var body := WsgBody.new(WsgBody.load_character(FoundationLink.DIR, "player_01"), null, 0)
	parent.add_child(body)
	var loco := WsgLocomotor.attach(body)
	loco.cut_from_heading = true
	WsgFootFlat.attach(body)
	return [body, loco]


## Low (ADOPTING 5.21): what the A16 draws - our own body (RiggedBody, its Low mesh) posed by HumanModel and planted by
## RiggedBody._plant_feet, no FoundationLink - driven as a match drives it (Athlete._pose: speed, and which way he moves
## against where he faces, eased at its rate), its feet read as drawn (anchors after HumanModel._process).
func walker_low(parent: Node) -> Variant:
	var was := int(Game.settings.graphics)
	set_tier(Game.GFX_LOW)
	var m := HumanModel.new()
	m.body_kind = "player"
	m.body_file = "player_01.krb"
	m.setup(Color(DB.SKIN_TONES[2]), Color(DB.HAIR_COLORS[0]), Color("1d4ed8"), Color.WHITE, 7, 1.78, 1.0)
	parent.add_child(m)
	set_tier(was)
	var drive := func(dt: float, vel: Vector3, facing: float) -> void:
		m.position += vel * dt
		var fwd := Vector3(sin(facing), 0.0, cos(facing))
		m.rotation.y = atan2(-fwd.x, -fwd.z)   # the model faces -Z (Athlete._track_motion)
		var k := clampf(dt * 10.0, 0.0, 1.0)
		var flat := Vector3(vel.x, 0.0, vel.z)
		m.speed = flat.length()
		if flat.length() > 0.3:
			var dir := flat.normalized()
			m.move_fwd = lerpf(m.move_fwd, dir.dot(fwd), k)
			m.move_side = lerpf(m.move_side, dir.dot(fwd.cross(Vector3.UP).normalized()), k)
		else:
			m.move_fwd = lerpf(m.move_fwd, 1.0, k)
			m.move_side = lerpf(m.move_side, 0.0, k)
	var feet := func() -> Array:
		if m.rig == null:
			return [m.anchor("foot_l"), m.anchor("toe_l"), m.anchor("foot_r"), m.anchor("toe_r")]
		return [m.rig.anchor("foot_l"), m.rig.anchor("toe_l"), m.rig.anchor("foot_r"), m.rig.anchor("toe_r")]
	return [m, drive, feet]


## The key moments' sounds (Sfx.BRIGHT: a tag's slap, a body onto the mat, the referee's whistle).
func key_sounds() -> Array:
	return Sfx.BRIGHT.values()


func set_tier(t: int) -> void:
	Game.settings.graphics = t
	WsgFoundation.tier = t


## The stick as the game maps it (CameraRig.stick_to_world: up the stick is up the screen where the player stands).
func stick_map() -> Callable:
	return Callable(CameraRig, "stick_to_world")


## The match's cameras, each settled as in play: behind the player he moves, and the broadcast camera. The last the
## check asks of a mode: its match is then stopped and hidden (kept for the rules that read what was captured), so
## it does not go on playing - and drawing - under every rule after it.
func cameras(_mode: String, root: Node) -> Array:
	var out := []
	for rig in root.find_children("*", "CameraRig", true, false):
		var m: Node = rig.get_parent()
		var was: int = rig.mode
		for mode in [Game.CAM_THIRD, Game.CAM_TV]:
			rig.mode = mode
			for i in 45:
				rig.follow(m, 1.0 / 30.0)
			var c := Camera3D.new()
			c.name = "camera %s" % ["behind the player", "", "broadcast"][mode]
			c.fov = rig.cam.fov
			root.add_child(c)
			c.global_transform = rig.cam.global_transform
			out.append(c)
		rig.mode = was
	return out
