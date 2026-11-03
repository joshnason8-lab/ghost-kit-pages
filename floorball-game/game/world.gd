extends WsgWorldGame
## Floorball's side of the shared world check (tools/wsg/world_check.gd, docs/WORLD_RULES.md, ADOPTING 5.18): the rules
## every game's world keeps, checked on the game's own code - its own start (Game.play_match, the tap), its own players
## and referees, its own joystick mapping and cameras, its own prop and crowd registries.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/wsg/world_check.gd -- --out DIR

const MATCH := "res://game/match.gd"


func game_name() -> String:
	return "floorball"


func prop_registry() -> String:
	return "res://game/prop_runs.gd"


func crowd_registry() -> String:
	return "res://game/crowd_venues.gd"


## Every way play starts from the menus (the configs as ui/quick_setup.gd starts them): a match (quick, cup and season
## games start the same way), Watch a match, and Penalty shots (the mini game).
func modes() -> Array:
	return ["match", "watch AI", "penalty shots"]


func _config(mode: String) -> Dictionary:
	match mode:
		"watch AI":
			return {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": -1, "watch": true, "mode": "watch", "period": 4.0, "seed": 3}
		"penalty shots":
			return {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "practice", "practice": true, "period": 20.0, "seed": 3}
	return {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": 0, "mode": "quick", "period": 4.0, "seed": 3}


## The tap: the game's own start (Game.play_match covers the screen with WsgLoading in this frame), under PARENT.
func start_mode(mode: String, parent: Node) -> void:
	# (The match before it stops, as on the phone, but stays in its holder: the check reads every mode's bodies and
	# officials after all of them have been played, and frees the holders itself.)
	if Game.current and is_instance_valid(Game.current):
		Game.current.process_mode = Node.PROCESS_MODE_DISABLED
		if Game.current is Node3D:
			(Game.current as Node3D).visible = false
	Game.main = parent
	Game.current = null
	Game.settings.sound = false
	Game.play_match(_config(mode))


## The player's graphics level, as Settings sets it (Game.settings.graphics, the shared foundation's tier with it).
func set_tier(t: int) -> void:
	Game.settings.graphics = t
	Game.settings.auto_gfx = false
	WsgFoundation.tier = t


## The referees as the check reads officials: each one's shared-foundation body (FoundationLink), dressed as a referee.
func find_officials(root: Node) -> Array:
	var out := []
	for n in root.get_tree().get_nodes_in_group("wsg_official"):
		if root.is_ancestor_of(n) and n.get("link") != null and n.link.body != null:
			out.append(n.link.body)
	return out


## Two referees on the rink in a match and a match watched; none in Penalty shots (the shooter and the goalkeeper only).
func officials(mode: String) -> int:
	return 0 if mode == "penalty shots" else 2


## One of the game's skaters as he plays: his shared-foundation body and its locomotor (FoundationLink).
func walker(parent: Node) -> Array:
	if not FoundationLink.enabled():
		return []
	var p := Player.new({"id": "SWE07", "height": 1.84, "num": 7}, 0, "F", 1)
	parent.add_child(p)
	if p.link == null:
		return []
	return [p.link.body, p.link.loco]


func key_sounds() -> Array:
	return ["shot", "post", "net", "whistle"]


## The game's own sounds as the world check reads them: the kinds Sfx plays with no distance filter (Sfx.crisp_kinds).
func audio(parent: Node) -> WsgAudio:
	var au := WsgAudio.new()
	parent.add_child(au)
	au.bright_kinds = Sfx.crisp_kinds()
	return au


## The match's own joystick mapping (Match.stick_world: the screen's up and right at the player, on any camera).
func stick_map() -> Callable:
	return func(stick: Vector2, cam: Camera3D, at: Vector3) -> Vector3:
		return (load(MATCH) as Script).call("stick_world", stick, cam, at)


## The cameras a mode plays with, each set as in play: a match's broadcast, high and behind-the-goal views (the camera
## button's three), placed where the match's camera puts each; Penalty shots its own close camera only.
func cameras(mode: String, root: Node) -> Array:
	var rigs := root.find_children("*", "CameraRig", true, false)
	if rigs.is_empty():
		return root.find_children("*", "Camera3D", true, false)
	var rig: CameraRig = rigs[0]
	if mode == "penalty shots":
		return [rig]
	var out := []
	var keep := rig.mode
	var b := Vector3.ZERO
	var m := rig.get_parent()
	if m and m.get("ball") != null:
		b = (m.ball as Ball).pos
	for cm in [Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END]:
		rig.mode = cm
		var c := Camera3D.new()
		c.name = ["broadcast", "high", "behind the goal"][[Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END].find(cm)]
		c.fov = rig.fov
		rig.get_parent().add_child(c)
		c.look_at_from_position(rig.call("_want_pos", b), rig.call("_want_look", b), Vector3.UP)
		out.append(c)
	rig.mode = keep
	return out
