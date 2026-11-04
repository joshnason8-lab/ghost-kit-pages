class_name WsgPerfLog
extends Node
## A game's frame rate and memory measured over a stretch of play, printed as one line a device lab can collect
## from the log (Firebase Test Lab keeps the logcat): `WSG_PERF {json}`. The games' Test Lab scenes (Hurling:
## tests/testlab_run.gd) play a scripted match at each tier with one of these running; .github/workflows/
## wsg-testlab.yml reads the lines back into a table per device and tier.
##   var log := WsgPerfLog.new()
##   add_child(log)
##   log.begin("medium", {"tier": 1})       # after the match has loaded (the first seconds are warm-up)
##   ...60 s of play...
##   log.finish()                            # prints the line, returns it as a Dictionary
##   WsgPerfLog.done()                       # the run is over (WSG_PERF_DONE: the workflow stops reading)

var label := ""
var extra := {}
var _times := PackedFloat32Array()
var _draws := 0
var _prims := 0
var _running := false
var _t0 := 0


func begin(p_label: String, p_extra := {}) -> void:
	label = p_label
	extra = p_extra
	_times = PackedFloat32Array()
	_draws = 0
	_prims = 0
	_t0 = Time.get_ticks_msec()
	_running = true


func _process(delta: float) -> void:
	if not _running:
		return
	_times.append(delta)
	var rs := RenderingServer
	_draws = maxi(_draws, rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	_prims = maxi(_prims, rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))


## The stretch's numbers: frames per second on average and in its worst 5% and 1% of frames (the stutter a player
## feels), frame times, memory (the engine's, the video memory, the phone's own), what drew, and the phone.
func finish() -> Dictionary:
	_running = false
	var ms := []
	var total := 0.0
	for t in _times:
		ms.append(t * 1000.0)
		total += t
	ms.sort()
	var pct := func(p: float) -> float: return ms[clampi(int(ms.size() * p), 0, ms.size() - 1)] if not ms.is_empty() else 0.0
	var mem := OS.get_memory_info()
	var out := {
		"label": label,
		"seconds": snappedf(total, 0.01),
		"frames": ms.size(),
		"fps_avg": snappedf(ms.size() / maxf(total, 0.001), 0.1),
		"fps_low5": snappedf(1000.0 / maxf(pct.call(0.95), 0.001), 0.1),
		"fps_low1": snappedf(1000.0 / maxf(pct.call(0.99), 0.001), 0.1),
		"frame_ms_p50": snappedf(pct.call(0.5), 0.01),
		"frame_ms_p95": snappedf(pct.call(0.95), 0.01),
		"frame_ms_max": snappedf(ms[-1] if not ms.is_empty() else 0.0, 0.01),
		"mem_engine_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"mem_video_mb": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"mem_phone_mb": snappedf(float(mem.get("physical", 0)) / 1048576.0, 1.0),
		"mem_free_mb": snappedf(float(mem.get("available", mem.get("free", 0))) / 1048576.0, 1.0),
		"draw_calls": _draws,
		"triangles": _prims,
		"device": OS.get_model_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"device_class": WsgFoundation.device_class(),
		"profile": WsgFoundation.profile,
	}
	out.merge(extra)
	print("WSG_PERF ", JSON.stringify(out))
	return out


static func done() -> void:
	print("WSG_PERF_DONE")
