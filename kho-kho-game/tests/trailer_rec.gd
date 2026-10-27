extends Node
## Footage for the trailer (tools/store/make_kit.sh): the AI playing on each ground on High, the camera low and close,
## the HUD off, sound on, recorded by Godot's Movie Maker at a fixed 30 frames a second:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --write-movie OUT.avi --fixed-fps 30 --resolution 1920x1080 \
##       res://tests/trailer_rec.tscn -- EVENTS.json [seconds per ground]
## EVENTS.json: every kho, dive, pole turn, pole dive and out, with its time in the film (s) and its ground, for the
## cutting script to find the moments.

var events: Array = []
var frame := 0
var ground := ""


func _process(_d: float) -> void:
	frame += 1


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var path := a[0]
	var per := float(a[1]) if a.size() > 1 else 25.0
	Game.main = self
	Game.settings.sound = true
	Game.settings.music = true
	Game.settings.coach = false
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.auto_gfx = false
	Game._size_theme()
	ModelBody.warm()
	await Crowd.render_sheet(get_tree())
	for spec in [["maidan", KhoRules.CLASSIC, "MAH", "ODI"], ["school", KhoRules.CLASSIC, "KAR", "KER"],
			["floodlit", KhoRules.CLASSIC, "TEL", "DEL"], ["arena", KhoRules.FAST, "IND", "NEP"]]:
		ground = spec[0]
		Game.settings.camera = Game.CAM_CLOSE
		Game.start_match({"home": spec[2], "away": spec[3], "venue": spec[0], "format": spec[1], "turn_len": 300.0,
			"user_team": -1, "seed": 31, "mode": "quick", "chase_first": 0})
		var m: Node = Game.current
		m.game_event.connect(func(kind: String):
			if kind in ["kho", "dive", "pole_turn", "pole_dive", "out", "swerve"]:
				events.append({"t": frame / 30.0, "kind": kind, "ground": ground}))
		var start := frame
		while (frame - start) / 30.0 < per:
			if m.hud:
				m.hud.visible = false
			await get_tree().process_frame
		events.append({"t": frame / 30.0, "kind": "end", "ground": ground})
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(events, " "))
	f.close()
	get_tree().quit()
