extends Node
## What each ground costs to draw at each graphics level: the same seeded AI match from the broadcast camera, through a
## few seconds of its first raid, with the draw calls, primitives and objects drawn a frame (the median and the most;
## the 3D view's own and its shadows' as well as the whole frame's, HUD included), the video memory in use, and each
## frame's time on this machine (software rendering here: comparable only with itself, before and after a change).
##   xvfb-run -a -s "-screen 0 1600x800x24" godot --path . --rendering-driver opengl3 --resolution 1560x720 \
##       --fixed-fps 30 res://tests/perf_probe.tscn -- [OUT.json] [grounds=dome,stadium,...] [gfx=0,1,2] [secs=4]

var _out := ""


func _ready() -> void:
	var grounds := ["dome", "stadium", "village", "monsoon", "beach"]
	var levels := [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]
	var secs := 4.0
	for a in OS.get_cmdline_user_args():
		var t := String(a)
		if t.begins_with("grounds="):
			grounds = Array(t.substr(8).split(","))
		elif t.begins_with("gfx="):
			levels = Array(t.substr(4).split(",")).map(func(x): return int(x))
		elif t.begins_with("secs="):
			secs = float(t.substr(5))
		elif t.ends_with(".json"):
			_out = t
	Game.main = self
	Game.settings.sound = false
	Game.settings.models = 1
	Game.settings.camera = Game.CAM_TV
	Game.settings.auto_gfx = false   # the level asked for, not one a slow machine drops to
	var rows := []
	for g in grounds:
		for lv in levels:
			rows.append(await _probe(String(g), int(lv), secs))
	print("")
	print("perf_probe: draw calls (3D + shadows; whole frame), primitives, objects: median / most; video memory; frame time")
	for r in rows:
		print("  %-8s %-6s  3D %3d/%3d + shadows %3d  frame %3d/%3d  prims %6dk/%6dk  objects %3d  vram %4d MB  %5.1f ms" % [
			r.ground, ["Low", "Medium", "High"][r.gfx], r.draws3d_med, r.draws3d_max, r.shadow_draws_med, r.draws_med,
			r.draws_max, r.prims_med / 1000, r.prims_max / 1000, r.objects_med, r.vram_mb, r.ms_med])
	if _out != "":
		var f := FileAccess.open(_out, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(rows, "  "))
	get_tree().quit()


func _probe(id: String, gfx: int, secs: float) -> Dictionary:
	Game.settings.graphics = gfx
	Game.apply_graphics(get_viewport())
	for i in 10:
		await get_tree().process_frame
	seed(1)
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": id, "mode": "quick", "autoplay": true, "autoplay_no_report": true,
		"length": 0, "difficulty": 1, "seed": 1}
	add_child(m)
	var guard := 0
	while m.phase != "raid" and guard < 30 * 40:
		await get_tree().process_frame
		guard += 1
	var vp := get_viewport().get_viewport_rid()
	var draws := []
	var draws3d := []
	var shadow := []
	var prims := []
	var objects := []
	var ms := []
	for i in int(secs * 30.0):
		var t0 := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		ms.append((Time.get_ticks_usec() - t0) / 1000.0)
		draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		prims.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		objects.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		draws3d.append(RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
		shadow.append(RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	var row := {"ground": id, "gfx": gfx, "draws_med": _med(draws), "draws_max": draws.max(),
		"draws3d_med": _med(draws3d), "draws3d_max": draws3d.max(), "shadow_draws_med": _med(shadow),
		"prims_med": _med(prims), "prims_max": prims.max(), "objects_med": _med(objects),
		"vram_mb": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576),
		"ms_med": _med(ms), "lowered": int(Game.settings.graphics) != gfx}
	print("perf_probe %s %s: %s" % [id, gfx, row])
	m.queue_free()
	await get_tree().process_frame
	return row


func _med(a: Array) -> float:
	var s := a.duplicate()
	s.sort()
	return s[s.size() / 2] if not s.is_empty() else 0.0
