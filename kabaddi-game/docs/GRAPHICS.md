# Graphics

How the grounds, the players and the picture are made to look the way they do, on a phone's GPU and with the
Compatibility (OpenGL) renderer the game uses everywhere since the Galaxy S24 crash. Measured before and after with
`tests/look_check.tscn` (below).

## Baked lighting for the grounds

Each ground is three parts (`game/arena.gd`):

- **its sky and light** (`_env`): the sky or background, the ambient light, the sun, fog, glow and the grade;
- **its fixed parts** (`_shell`): the court, the floor or fields, the stands, roofs, floodlight towers, trees, huts,
  benches, umbrellas;
- **what changes or moves** (`_dress`): the teams' boards and the league's name on the mat, the crowd, rain, the sea.

The fixed parts are baked with Godot's lightmapper (LightmapGI) and saved in `assets/grounds/<id>/`: the scene
(`<id>.tscn`, each mesh with a second set of UVs laid out for its lightmap), the bake (`<id>.lmbake`) and the
lightmap (`<id>.exr`). `Arena.build` loads them when they are there and builds the fixed parts itself when not
(`Arena.use_baked = false` does too, as the bake needs).

What is baked: the sky's light (outdoors the ground's own sky, as strong as its ambient light was before the bake; a
dim colour indoors), the sun's light bounced off everything, and lights that are only there to be baked: the dome's
twelve roof lamps and the stadium's four floodlights, each a spot with soft shadows. Stand-ins for the teams' boards
go in for the bake too, so the run-off has their shadow and a little of their glow. All of it gives soft shadows,
darkening into corners and under benches and roofs, pools of light under the lamps, and colour bounced from the court
and the ground.

What is not: the sun's direct light and its shadows stay live, so the players cast shadows on the baked floor as
before (Shadows, below). The players and the crowd are lit live by the sun and the
ambient light: the Compatibility renderer does not light moving things from a bake's light probes (checked: a
sphere next to a baked lamp stays black once the lamp itself is gone), so the bake's own lamps are taken out when a
ground is loaded, and the players cost nothing more to draw.

On the phone a baked ground costs one more texture read for the fixed parts and about 1 MB of memory (an ASTC
lightmap, HDR, one 1024 x 1024 page per ground; a GPU that cannot read HDR ASTC is given it unpacked, 8 MB). A ground
whose lightmap needs more takes a 2048 page, four times the memory, so the texel sizes keep each under 1024: the
stadium's stands (one mesh since 0.9.0) at 0.25 m, the beach's 320 m strip of sand sloping into the sea at 0.4 m.

### Re-baking

`tools/bake_lighting/bake.sh [grounds]`: at medium quality, the default and what the game ships, half an hour for all
five on a 4-core machine without a GPU (2 to 9 minutes a ground); `BAKE_QUALITY=low` is quicker and, once denoised,
nearly as clean, for trying things out. Godot's lightmapper only runs from the editor and on a Vulkan device, so the
script works on a copy of the project: it imports, builds the scenes (`make_scenes.tscn`: the arena's fixed parts,
every mesh unwrapped for its lightmap at a texel size that suits it, the LightmapGI set up per ground), turns on
`addon/` (a plugin that presses the editor's Bake Lightmaps button for each scene, answers where to save it and saves
the scene), runs the editor under xvfb with Vulkan (Mesa's lavapipe on a machine without a GPU: `apt-get install
mesa-vulkan-drivers xvfb`), and copies each ground's scene, bake and lightmap back. Re-bake after changing a ground's
fixed parts, their materials or the bake's lights.

Previews of baked grounds on a machine without a GPU are slow: Mesa's software OpenGL decodes the desktop lightmap
format (BC6H) texel by texel. A copy of the project with the lightmaps imported uncompressed renders them at the usual
speed; phones decode their format (ASTC) in hardware.

## Shadows

On Medium and High the sun casts real shadows, of everything: a shadow map, and on the Compatibility renderer a second
pass over everything the sun lights, which makes them the dearest thing in the picture (on the software renderer the
same frames take 2.4 to 2.8 times as long as on Low, and twice the triangles). A phone that cannot keep up drops a
level by itself in its first match (Settings, Auto graphics), so a mid-range phone plays on Low, where the sun casts
none.

On Low each player, official and the scorers' table cast their own (`Arena.floor_shadow`,
`HumanModel.set_floor_shadow`): the body drawn a second time, flattened onto the floor along the sun's light, in
see-through black. The shadow has his shape, is as long as the sun is low (seven metres in the village's late
afternoon, a pool round his feet under the dome's lamps) and moves with him; a stencil lets each pixel be darkened
once where limbs or players overlap. It is as dark as the sun's own shadow on the court is on each ground
(`Arena.SHADE`, measured with `tests/shade_check.tscn`: the court with the sun and without it, which is all a shadow
keeps). It costs one more draw of each body (21 in a match) and nothing else: the bodies are most of the picture's
triangles on Low (about 300,000 of 320,000), so those double, and a frame took 4% longer on the software renderer.
When a match lowers itself to Low, the bodies' own shadows take over from the sun's there and then.

Before 0.7.11 a match that lowered itself lost its shadows altogether, and a match that started on Low had a faint
round blob under each player; the placeholder body still has that.

Low still has no shadows of the stands, trees, huts, umbrellas or crowd (the bake has the sky's light, not the
sun's), and its sunlit floors are darker than Medium's: the Compatibility renderer adds a shadowed sun's light to a
picture already turned to sRGB, which makes Medium's sunlit floors brighter than the same light gives on Low (the
dome's court about 1.7 times, the whole picture 1.5 to 1.75 times).

## Skies, surfaces and the scenery round the grounds (0.9.0)

From the lead session's shared assets (Poly Haven's photographs and scans, CC0, and the owner's Meshy models), in
`assets/scenery/`, put together by `game/scenery.gd`; what goes where on each ground, and why, is in
[PROGRESS.md](PROGRESS.md).

- **Skies** (`Scenery.sky`): a 2K panorama for the background on every level, turned so its sun is where the
  ground's sun is. What lights the ground (ambient light, reflections, and the bake) comes from the same sky in HDR on
  Medium and High, from the panorama on Low (the HDR is not even loaded there), each scaled so the ground gets as
  much light from the sky as it did from the painted sky before (measured looking up and sideways); the beach's bake
  takes 45 % of it (`Arena.BAKE_SKY`), as its clear evening sky left the sand in shade almost as bright as in the sun.
  The HDR's sun is held down: the sun's own light is the ground's DirectionalLight3D. Below the horizon the panorama's
  haze goes on for the background, and the ground's colour lights things from below. Distant fog takes the sky's own
  colour.
- **Ground** (`Scenery.ground`): a photographed surface laid over the world in metres, so it runs on across every plane
  that shows it; a second surface showing through in patches, toward a line (the wet sand by the sea), out from the
  middle (worn grass round the village) or outside a box (the red earth round the village court); brightness varied
  over tens of metres so the tiles do not show; on Medium and High the surfaces' normal maps (the `scenery_detail`
  shader global, set by `Arena.graphics_changed`). The monsoon's is wet, its puddles rippling and showing the sky.
- **Walls and stands** (`Scenery.wall`): a photographed surface's grain in grey, in the wall's own colour, laid along
  whichever axis each face looks down (the stands in concrete, the village houses in plaster).
- **The sea** (`Scenery.sea`): a gentle swell, ripples from a normal map in two drifting layers, deep and shallow water,
  the sky's reflection, surf where it runs up the sloping sand.
- **Models round a ground**: each kind drawn in one go however many there are (a MultiMesh: one draw for forty
  chairs), the cut-down model on Low. Trees are cut-outs (two crossed pictures of the tree) facing the broadcast
  camera, the full model only within 25 m of it on Medium and High; they sway a little, let some light through, and
  are lit partly from above. Seats carry the crowd at their height, with a soft shadow under each, all in one go.
  The stadium's city at night is unshaded: dark walls and lit windows, out of the floodlights' reach.
- `tools/scenery/fetch.sh` fetches the source models from the shared assets and `tools/scenery/convert.tscn` makes
  what the game loads from them (each mesh, its textures as they came, their import settings): the sources are not
  committed, and the game ships only what it loads.

## Court textures

`tools/ground_art/make_textures.py` makes the mat's texture from noise (nothing to license): a detail albedo
(multiplied with the material's colour, so one texture serves every court colour) and a normal map, in
`assets/grounds/textures/`: 1 m foam tiles with fine seams, each tile a touch lighter or darker, a fine grain, faint
scuffs. On the field, the lobbies, the run-off and the sitting blocks, laid at its real size (2 m a repeat) by the size
of each. Until 0.9.0 it made the concrete, stand, grass, mud and sand textures too; photographs took their place.

## Medium and High's extra detail (0.12.0)

The owner let the APK grow toward 100 MB to make the game look and sound better, on one condition: Low stays exactly
as it was. So every addition is a file of its own that only Medium and High load (`Game.detail_textures()`); Low
loads the same files as before and never the new ones (`tests/test_runner.gd`, 7d), and every new texture is
compressed for the GPU (ETC2 on a phone), so the video memory stays in reach of a mid-range phone.

- **The players' faces, skin and kit** (`assets/characters/bodies/*_albedo_2k.webp`, `tools/rig/albedo_2k.py`): the
  models' own 2K and 4K textures at 2048 px, with the 1K albedo's work (logos and numbers painted out, islands
  padded) brought over where it was done. The kit map stays at 1K (it marks colours, not detail).
  `RiggedBody.albedo_for` picks the albedo for the level; a match lowered to Low by itself puts the 1K ones back on.
  The 1K albedos are uncompressed in video memory; the 2K ones are ETC2 (2.8 MB each with mipmaps).
- **The courts**: the mat's albedo at 2048 px (`tools/ground_art/make_textures.py`: the same mat, seams as wide in
  metres, four times the grain), and Poly Haven's 2K albedos of the village's earth (`brown_mud_dry`,
  `red_dirt_mud_01`), Puri's sand (`coast_sand_01`, `damp_beach_sand`) and the dome's floor (`concrete_floor`),
  `*_albedo_2k.jpg` beside the 1K ones (`Scenery.texture`, `Arena._texture`). Their normal maps stay at 1K.
- **The crowd** (`assets/crowd/crowd_atlas_hi*`, `tools/crowd/variants.py`): sixteen people where Low has eight, the
  eight again in other colours: the Sikh man's turban saffron and maroon, the salwar kameez magenta and mustard,
  the saree green and royal blue, the girl's frock yellow and sky blue. Each variant takes a share of its own
  person's place in the crowd, so the mix of men, women and children is as before.

## Skin and kit

The bodies' shader (`RiggedBody.SHADER_TEXTURED`): skin has a soft sheen that gets wetter as a player tires (his
energy drives `sweat`; it dries slowly once he has his breath back) and warm light carried through where it is thin
(backlight); the kit is matte cloth with a jersey's sheen at grazing angles. Both catch the lights behind them at the
edges (rim), more on cloth than on skin, which keeps the players apart from the court in the broadcast view.

## Camera and picture

- **Broadcast camera** (`CameraRig`): in close while the raider is held (narrower, a little nearer and lower), back
  out as he gets away or the raid ends; never quite still, as a camera operator's hands are not; a short jolt at a
  takedown, a dash and, smaller, a hold. The third-person camera has the jolts too.
- **Vignette**: the edges of the picture a shade darker, as a lens has them, under the HUD.
- **Grade**: each ground has its own, after tonemapping (a lookup the Compatibility renderer applies): cool shadows
  under warm lamps in the dome, blue night shadows and warm floodlit highlights in the stadium, a warm late afternoon
  in the village, a soft cool haze in the monsoon, teal shadows and warm sand at the beach.
- **Crowd under lights**: in the dome and the stadium at night the back rows of the crowd fall into shadow.
- **The crowd faces the court** (0.9.1): each spectator is a card turned to the camera, its instance's -z pointing at
  the court's middle; a camera behind them (as over the stand the broadcast camera looks over) gets their back, from
  a second sheet drawn from behind (`tools/crowd/render_crowd.gd`). Before, every card showed the person's front,
  so the near stand looked up at the camera.

## Measuring

`tests/look_check.tscn` plays the same seeded AI match on each ground and saves, at set moments, the broadcast view
as the game shows it and a close look at the raider, so a change can be compared frame for frame:

    xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1493x720 --fixed-fps 30 \
        res://tests/look_check.tscn -- OUTDIR [grounds=dome,stadium] [at=14,31] [gfx=1] [seed=1] [nobake]

Each picture's draw calls and primitives are printed with it.

What the pass cost, measured on 0.7.8 and 0.7.9, each run alone: the first 6 s of the same match on every ground at
Medium, on a machine without a GPU (Mesa's software OpenGL, so the times are long and texture reads count for more
than on a phone's GPU):

| Ground | Draw calls | Primitives | Frame, median |
|---|---|---|---|
| Dome | 243 → 244 | 651,404 → 632,114 | 383 → 483 ms |
| Stadium | 255 → 256 | 653,506 → 634,216 | 448 → 552 ms |
| Village | 288 → 289 | 666,548 → 637,706 | 386 → 395 ms |
| Monsoon | 252 → 253 | 705,260 → 635,354 | 389 → 402 ms |
| Beach | 277 → 270 | 829,618 → 640,680 | 395 → 360 ms |

One more draw call (the vignette); fewer primitives (the trees, palms and umbrellas with fewer sides). The dome and
the stadium take a quarter longer: their stands, and the dome's floor, take their textures in world space, three
reads a texture where a surface laid out flat takes one. If a phone cannot keep up, the game drops a graphics level
by itself (Settings, Auto graphics).

`test_runner` checks that every ground loads with its baked lighting, and with the bake's lamps and sky taken out;
and that every body has its own floor shadow on Low, from the start and once a match lowers itself from Medium.
