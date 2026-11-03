extends WsgWorldGame
## The foundation's own world for wsg_world_check (a game's res://game/world.gd is the same shape, on its own code): a
## "match" mode - two players and an official on the test hurler's rig, four cameras - started behind WsgLoading, the
## test hurler as the walker, the foundation's prop and crowd registries. BAD (world_check --bad) breaks one rule the
## way a game could, and the check must fail it (tests/world_check_test.sh):
##   loading (no overlay at the tap), pose (a player left in its rest pose), officials (an official in a player's
##   kit), feet (the planter off), sounds (the post's ping dulled by distance), joystick (the stick fixed to the world),
##   tiers (the mode puts the graphics tier up to High and asks for the Close crowd, as Hurling's practice did)

var bad := ""


func game_name() -> String:
	return "foundation (tests/world_demo)"


func prop_registry() -> String:
	return "res://tests/prop_runs.gd"


func prop_args() -> Array:
	return [1, 20]


func crowd_registry() -> String:
	return "res://tests/crowd_venues.gd"


func modes() -> Array:
	return ["match", "rematch"] if bad == "freed" else ["match"]


func play_seconds(_mode: String) -> float:
	return 3.0


var _last: Node = null


func start_mode(_mode: String, parent: Node) -> void:
	# ("freed": two modes, each start freeing the last one's match - as a real tap replaces it; the rules after must
	# not stop on its freed bodies.)
	if bad == "freed" and is_instance_valid(_last):
		_last.free()
	if bad == "freed":
		_last = DemoMatch.new("")
		var ldf := WsgLoading.cover(parent, [])
		ldf.step("The players", func(): parent.add_child(_last))
		await ldf.run()
		await ldf.done()
		return
	if bad == "loading":
		parent.add_child(DemoMatch.new(bad))
		return
	var ld := WsgLoading.cover(parent, [])
	ld.step("The players", func(): parent.add_child(DemoMatch.new(bad)))
	await ld.run()
	await ld.done()


func officials(_mode: String) -> int:
	return 1


func walker(parent: Node) -> Array:
	var body := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
	parent.add_child(body)
	var loco := WsgLocomotor.attach(body)
	if bad == "feet":
		loco.planter.enabled = false
	if bad == "manual":
		body.set_manual(true)     # (a body the game advances itself: the walk must still run - Hurling's hung)
	return [body, loco]


func key_sounds() -> Array:
	return ["post", "whistle", "tag"]


func audio(parent: Node) -> WsgAudio:
	var au := super.audio(parent)
	if bad == "sounds":
		au.bright_kinds.erase("post")
	return au


func stick_map() -> Callable:
	if bad == "joystick":
		return func(st: Vector2, _cam: Camera3D, _at: Vector3) -> Vector3: return Vector3(st.x, 0, st.y)
	return func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3: return WsgNoteChecks.stick_world(st, cam, at)


func cameras(_mode: String, root: Node) -> Array:
	return root.find_children("*", "Camera3D", true, false)


## The demo's match: two players running rings, an official following the play, the cameras a game has.
class DemoMatch:
	extends Node3D
	var _bad := ""
	var players := []
	var official: WsgOfficial
	var t := 0.0

	func _init(p_bad: String) -> void:
		_bad = p_bad
		name = "Match"
		var ch := WsgBody.load_character("res://tests/character", "hero")
		for i in 2:
			var kit := StandardMaterial3D.new()
			kit.albedo_color = [Color(0.8, 0.1, 0.1), Color(0.1, 0.2, 0.8)][i]
			var b := WsgBody.new(ch, kit)
			b.name = "Player%d" % (i + 1)
			add_child(b)
			var loco := WsgLocomotor.attach(b)
			players.append([b, loco, kit])
		var ref_kit: Material = players[0][2] if _bad == "officials" else StandardMaterial3D.new()
		if ref_kit is StandardMaterial3D and _bad != "officials":
			(ref_kit as StandardMaterial3D).albedo_color = Color(0.95, 0.85, 0.1)
		official = WsgOfficial.new(ch, ref_kit)
		official.name = "Referee"
		add_child(official)
		# A stand of fans behind the far touchline: the crowd the game asks for (High), built at what the tier allows.
		var q := 2
		if _bad == "tiers":
			WsgFoundation.tier = WsgFoundation.HIGH
			q = 3
		if WsgCrowd3D.available():
			var crowd := WsgCrowd3D.new()
			crowd.name = "Crowd"
			add_child(crowd)
			crowd.build_venue((load("res://tests/crowd_venue_test.gd") as GDScript).call("arena"), q, Vector3.ZERO, 1.0, 3)
		for c in [["Alongside", Vector3(0, 6, 22), Vector3.ZERO], ["End-on", Vector3(-30, 5, 0), Vector3.ZERO],
				["Overhead", Vector3(0, 35, 0.01), Vector3.ZERO], ["Behind the player", Vector3(3, 2.2, -8), Vector3(3, 1, 4)]]:
			var cam := Camera3D.new()
			cam.name = c[0]
			add_child(cam)
			cam.look_at_from_position(c[1], c[2], Vector3.UP if c[0] != "Overhead" else Vector3.RIGHT)

	func _process(delta: float) -> void:
		t += delta
		for i in players.size():
			var b: WsgBody = players[i][0]
			var loco: WsgLocomotor = players[i][1]
			var a := t * 0.5 + i * PI
			var vel := Vector3(-sin(a), 0, cos(a)) * 2.5
			b.position = Vector3(cos(a), 0, sin(a)) * 5.0
			if i == 0 and _bad == "pose":
				b.set_manual(true)
				b.reset_pose()
				continue
			loco.drive(delta, vel, atan2(vel.x, vel.z), vel)
		official.position = Vector3(0, 0, -8)
		official.follow(delta, Vector3.ZERO, (players[0][0] as WsgBody).position)
