extends SceneTree
## The Low planter's own CPU cost (the lead, 2026-11-03: Low within about 1 ms of before on the A16): 18 of Low's own
## bodies (ModelBody, the light mesh) running and stopping, a frame's process time with their planters on and off.
##   godot --headless --path . -s res://tests/low_planter_bench.gd

func _initialize() -> void:
	for k in 5:
		await process_frame
	var bodies := []
	for i in 18:
		var b := ModelBody.new({}, true)
		root.add_child(b)
		b.position = Vector3(float(i % 6) * 3.0, 0, float(i / 6) * 3.0)
		bodies.append(b)
	for on in [false, true, false, true]:
		for b: ModelBody in bodies:
			b.feet_near = on
		var total := 0
		for f in 300:
			var t0 := Time.get_ticks_usec()
			for i in bodies.size():
				var sp := 6.0 if (f / 60 + i) % 3 != 0 else 0.0
				(bodies[i] as ModelBody).drive(1.0 / 30.0, Vector3(0, 0, sp), 0.0)
			await process_frame
			total += Time.get_ticks_usec() - t0
		print("LOWBENCH planter %s: %.2f ms a frame (18 bodies, 300 frames, process and skeleton updates)" % ["on " if on else "off", total / 300.0 / 1000.0])
	quit(0)
