extends Node
## The stride's geometry (Moves.run on the rig, Moves._travel_per_radian): the standing foot's travel back under him
## per radian of the phase along the way he goes, at each speed (k: speed / 5 m/s) and share sideways (+ to his left,
## - to his right; 1 a pure side-shuffle), and the phase rate (Moves.stride_rate) that keeps it planted, as steps a
## second. Positive travel: the standing foot goes back under him (planted); 0.03, the floor, means it does not.
##   godot --headless --path . res://tests/stride_probe.tscn

func _ready() -> void:
	for women in [false, true]:
		var r := RealBody.rig(women)
		print("%s: speed  side  m/rad  steps/s" % ("women" if women else "men"))
		for speed in [0.5, 1.0, 2.0, 3.0, 4.0, 5.0]:
			for side in [0.0, 0.5, 1.0, -1.0]:
				var d := Moves._travel_per_radian(r, speed / 5.0, side)
				print("  %5.1f %5.1f %6.3f %7.1f" % [speed, side, d, Moves.stride_rate(speed, side, women) / PI])
	get_tree().quit()
