extends WsgOwnerNote
## The owner, 2026-11-03 (Kho Kho Rush 0.12.1): "The tag button is overlapping the kho button"

const NOTE := {"id": "2026-11-03-tag-over-kho", "game": "kho-kho", "date": "2026-11-03", "version": "Kho Kho Rush 0.12.1", "words": "The tag button is overlapping the kho button"}
const KK := preload("res://tests/note_kk.gd")


## No two buttons ever overlap: every button size, both hands, two screen shapes, with a place saved for each slot
## anywhere on the screen (a 7 x 5 grid) - a saved place that would overlap is not used.
func check() -> void:
	KK.prepare(tree)
	var keep_places: Dictionary = Game.settings.btn_places.duplicate()
	var keep_size := int(Game.settings.btn_size)
	var keep_left := bool(Game.settings.left_handed)
	var tc := TouchControls.new()
	tree.root.add_child(tc)
	tc.set_buttons(["KHO", "DIVE", "TAG", "POWERPLAY"])
	var worst := INF
	for shape in [Vector2(1600, 720), Vector2(1280, 720)]:
		tc.size = shape
		for k in 3:
			Game.settings.btn_size = k
			for lh in [false, true]:
				Game.settings.left_handed = lh
				for slot in 4:
					for gx in 7:
						for gy in 5:
							Game.settings.btn_places = {str(slot): [0.45 + gx * 0.09, 0.15 + gy * 0.2]}
							var lay: Array = tc.layout()
							for i in lay.size():
								for j in range(i + 1, lay.size()):
									var gap: float = (lay[i][1] as Vector2).distance_to(lay[j][1]) - float(lay[i][2]) - float(lay[j][2])
									worst = minf(worst, gap)
									if gap < 0.0:
										fail("%s over %s (%.0f px) at %s, size %d, %s-handed, slot %d saved at %d,%d" % [lay[i][0], lay[j][0], -gap, shape, k, "left" if lh else "right", slot, gx, gy])
	info("closest two buttons ever came: %.0f px apart" % worst)
	tc.queue_free()
	Game.settings.btn_places = keep_places
	Game.settings.btn_size = keep_size
	Game.settings.left_handed = keep_left
