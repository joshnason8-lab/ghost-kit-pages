class_name Signage
extends Node
## The hall's words in the phone's language: the slogans on the boards' advertising panels and the city arena's floor
## decals, drawn when the venue is built (a SubViewport drawn once, then kept as a texture with mipmaps). The game's own
## name (FLOORBALL UNLEASHED, #UNLEASHED) stays as it is in every language, as a brand does; the slogans are the
## language's own (in Swedish the sport is innebandy, in Finnish salibandy, in Czech florbal). The venue sheet's
## English panels (tools/crowd/make_venue.gd) are no longer drawn.

const BOARD_W := 1024
const BOARD_H := 128      # two rows of four 2 m panels: ads1 (y 0-64) and ads2 (64-128), as the venue sheet's strips
const DECAL_W := 1024
const DECAL_H := 512

## The board panels: [row, ground, text key ("" the game's name, as is), words, stripe]. As the venue sheet had them.
const BOARDS := [
	[0, "123a7a", "", "ffffff", "f28c28"],
	[0, "f7f8fa", "ADS_PLAY_FAIR", "123a7a", "d0202e"],
	[0, "d0202e", "#UNLEASHED", "ffffff", "ffffff"],
	[0, "f7f8fa", "", "d0202e", "123a7a"],
	[1, "0f8b5f", "ADS_GO_FLOORBALL", "ffffff", "f7d046"],
	[1, "f7f8fa", "ADS_KEEP_MOVING", "0f8b5f", "123a7a"],
	[1, "f28c28", "ADS_FAST_LIGHT_FUN", "ffffff", "123a7a"],
	[1, "1d2633", "", "5ad1f0", "5ad1f0"],
]

signal ready_textures

var boards: Texture2D       # BOARD_W x BOARD_H
var decals: Texture2D       # DECAL_W x DECAL_H, transparent round the pieces
var _vps: Array[SubViewport] = []
var _users: Array = []       # [material, parameter] to give the final textures to


static func text(key: String) -> String:
	if key == "":
		return "FLOORBALL UNLEASHED"
	if key.begins_with("#"):
		return key
	return TranslationServer.translate(key)


func _init() -> void:
	boards = _canvas(Vector2i(BOARD_W, BOARD_H), _draw_boards, false)
	decals = _canvas(Vector2i(DECAL_W, DECAL_H), _draw_decals, true)


func _ready() -> void:
	# Drawn over the first frames (on Vulkan a font's glyphs reach the GPU a frame or two after they are first asked
	# for); then kept as ordinary textures with mipmaps (no shimmer far off), the viewports freed.
	for i in 6:
		await RenderingServer.frame_post_draw
	var done: Array[Texture2D] = []
	for vp in _vps:
		var img := vp.get_texture().get_image() if is_instance_valid(vp) else null
		if img == null or img.is_empty():
			return   # no renderer (a headless test): the viewports' own textures stay
		img.convert(Image.FORMAT_RGBA8)
		img.generate_mipmaps()
		done.append(ImageTexture.create_from_image(img))
	var old := [boards, decals]
	boards = done[0]
	decals = done[1]
	for u: Array in _users:
		var m: Material = u[0]
		var tex: Texture2D = boards if u[2] == old[0] else decals
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter(u[1], tex)
		elif m is StandardMaterial3D:
			(m as StandardMaterial3D).albedo_texture = tex
	for vp in _vps:
		vp.queue_free()
	_vps.clear()
	ready_textures.emit()


## Tell the signage that material m shows one of its textures in param (a shader parameter, or the albedo of a
## StandardMaterial3D): it is given the finished texture once drawn.
func use(m: Material, param: String, tex: Texture2D) -> void:
	_users.append([m, param, tex])


func _canvas(px: Vector2i, painter: Callable, transparent: bool) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = px
	vp.transparent_bg = transparent
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var c := Control.new()
	c.size = Vector2(px)
	c.draw.connect(func(): painter.call(c))
	vp.add_child(c)
	add_child(vp)
	_vps.append(vp)
	return vp.get_texture()


# ---------------------------------------------------------------- the boards

func _draw_boards(c: Control) -> void:
	var font: Font = Game.font_score
	for i in BOARDS.size():
		var a: Array = BOARDS[i]
		var r := Rect2((i % 4) * 256, int(a[0]) * 64, 256, 64)
		var base := Color(String(a[1]))
		# Plastic panel: a touch brighter at the top (the overhead light), darker at the foot, a grey kick strip.
		for y in 64:
			var k := float(y) / 64.0
			c.draw_rect(Rect2(r.position.x, r.position.y + y, r.size.x, 1), base.lightened(0.04 * (1.0 - k)).darkened(0.08 * k * k))
		c.draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), base.darkened(0.35))
		c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), Color(1, 1, 1))
		c.draw_rect(Rect2(r.position.x + 10, r.position.y + 44, r.size.x - 20, 5), Color(String(a[4])))
		var words := text(String(a[2]))
		_text(c, font, Rect2(r.position.x, r.position.y + 2, r.size.x, 44), words, 34 if words.length() > 14 else 40, Color(String(a[3])))
		# The joint between two panels.
		c.draw_rect(Rect2(r.position.x, r.position.y, 2, 64), Color(0.55, 0.57, 0.6))
		c.draw_rect(Rect2(r.position.x + 2, r.position.y, 1, 64), Color(1, 1, 1))


# ---------------------------------------------------------------- the floor decals

## The city arena's floor, as the Swedish league's arenas print on theirs: a dark disc in the centre circle with the
## game's name, and two dark panels with its slogans; white on a dark grey that lets the floor through a little.
func _draw_decals(c: Control) -> void:
	var bg := Color8(58, 62, 68, 215)
	var white := Color8(246, 247, 249)
	var font: Font = Game.font_score
	c.draw_circle(Vector2(256, 256), 248, bg)
	c.draw_arc(Vector2(256, 256), 232, 0, TAU, 96, Color(white, 0.47), 4.0, true)
	_text(c, font, Rect2(60, 150, 392, 120), "FLOORBALL", 118, white)
	_text(c, font, Rect2(40, 262, 432, 98), "UNLEASHED", 92, white)
	var panels := [["ADS_GO_FLOORBALL", "ADS_PLAY_FAIR_FAST"], ["#UNLEASHED", "ADS_HALL_LOUD"]]
	for i in 2:
		var y0 := 16 + i * 248
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.set_corner_radius_all(10)
		c.draw_style_box(box, Rect2(528, y0, 488, 232))
		_text(c, font, Rect2(540, y0 + 18, 464, 142), text(panels[i][0]), 104, white)
		_text(c, font, Rect2(540, y0 + 156, 464, 60), text(panels[i][1]), 40, Color(white, 0.8))


## txt centred in rect, made smaller until it fits its width with a margin.
static func _text(c: Control, font: Font, rect: Rect2, txt: String, size: int, col: Color) -> void:
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	while w > rect.size.x * 0.9 and size > 10:
		size -= 1
		w = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := font.get_ascent(size)
	var desc := font.get_descent(size)
	var pos := Vector2(rect.position.x + (rect.size.x - w) * 0.5, rect.position.y + (rect.size.y + asc - desc) * 0.5)
	c.draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
