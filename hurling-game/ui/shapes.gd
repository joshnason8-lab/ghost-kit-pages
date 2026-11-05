class_name Shapes
## Discs and rings drawn from one small white texture, so that a screen of them (the match's buttons, the ball's dot,
## your player's ring) is one draw call: draw_circle and draw_arc are a draw call each, and the match's HUD was 27 of
## them, a quarter of a phone's budget on Low (docs/GRAPHICS.md).
## The texture: a disc, then rings of a few thicknesses (as a share of their radius), each in a 128-pixel cell; a ring
## is drawn from the cell nearest the thickness asked for. Its mipmaps keep the small ones (the ball's dot) smooth:
## draw with texture_filter LINEAR_WITH_MIPMAPS.

const CELL := 128
const R := 62.0                                  # the outer edge's radius in a cell (a pixel and the blur inside it)
const RINGS := [0.04, 0.065, 0.1, 0.16, 0.25, 0.4]   # each ring's thickness, a share of its outer radius

static var _tex: ImageTexture


static func texture() -> ImageTexture:
	if _tex == null:
		var img := Image.create(CELL * (1 + RINGS.size()), CELL, false, Image.FORMAT_RGBA8)
		var c := CELL * 0.5
		for y in CELL:
			for x in CELL:
				var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
				var out := clampf(R + 0.5 - d, 0.0, 1.0)          # the outer edge, a pixel's blur
				img.set_pixel(x, y, Color(1, 1, 1, out))
				for i in RINGS.size():
					var inner := R * (1.0 - float(RINGS[i]))
					var a := minf(out, clampf(d - inner + 0.5, 0.0, 1.0))
					img.set_pixel(x + CELL * (i + 1), y, Color(1, 1, 1, a))
		img.generate_mipmaps()
		_tex = ImageTexture.create_from_image(img)
	return _tex


## A filled circle at c, radius r.
static func disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	_cell(ci, 0, c, r, col)


## A ring centred on radius r, w wide (as draw_arc's full circle of width w).
static func ring(ci: CanvasItem, c: Vector2, r: float, w: float, col: Color) -> void:
	var outer := r + w * 0.5
	var f := w / maxf(outer, 0.001)
	var best := 0
	for i in RINGS.size():
		if absf(float(RINGS[i]) - f) < absf(float(RINGS[best]) - f):
			best = i
	_cell(ci, best + 1, c, outer, col)


static func _cell(ci: CanvasItem, i: int, c: Vector2, outer: float, col: Color) -> void:
	var h := outer * CELL * 0.5 / R
	ci.draw_texture_rect_region(texture(), Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0), Rect2(i * CELL, 0, CELL, CELL), col)
