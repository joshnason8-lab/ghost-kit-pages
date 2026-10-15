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

What is baked: the sky's light (from the scene's sky outdoors; a dim colour indoors), the sun's light bounced off
everything, and lights that are only there to be baked: the dome's twelve roof lamps and the stadium's four
floodlights, each a spot with soft shadows. Stand-ins for the teams' boards go in for the bake too, so the run-off
has their shadow and a little of their glow. All of it gives soft shadows, darkening into corners and under
benches and roofs, pools of light under the lamps, and colour bounced from the court and the ground.

What is not: the sun's direct light and its shadows stay live, so the players cast shadows on the baked floor as
before (on Medium and High; blob shadows on Low). The players and the crowd are lit live by the sun and the
ambient light: the Compatibility renderer does not light moving things from a bake's light probes (checked: a
sphere next to a baked lamp stays black once the lamp itself is gone), so the bake's own lamps are taken out when a
ground is loaded, and the players cost nothing more to draw.

On the phone a baked ground costs one more texture read for the fixed parts and about 1 MB of memory (an ASTC
lightmap, HDR, one 1024 x 1024 page per ground; a GPU that cannot read HDR ASTC is given it unpacked, 8 MB).

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

## Court and stand textures

`tools/ground_art/make_textures.py` makes seamless textures from noise (nothing to license), each a detail albedo
(multiplied with the material's colour, so one mat texture serves every court colour) and a normal map, in
`assets/grounds/textures/`, imported compressed for the GPU with mipmaps:

- **mat**: 1 m foam tiles with fine seams, each tile a touch lighter or darker, a fine grain, faint scuffs. On the
  field, the lobbies, the run-off and the sitting blocks, laid at its real size (2 m a repeat) by the size of each.
- **concrete**: polished, with soft clouding, flecks and hairline cracks; the dome's floor.
- **stand**: weathered concrete with streaks; the stands, laid in world space (triplanar), so the tiers of any
  ground take it at the same size.
- **grass**, **mud**, **sand**: the fields round the outdoor grounds, the village court, the beach court.

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

## Measuring

`tests/look_check.tscn` plays the same seeded AI match on each ground and saves, at set moments, the broadcast view
as the game shows it and a close look at the raider, so a change can be compared frame for frame:

    xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1493x720 --fixed-fps 30 \
        res://tests/look_check.tscn -- OUTDIR [grounds=dome,stadium] [at=14,31] [gfx=1] [seed=1] [nobake]

Each picture's draw calls and primitives are printed with it.

`test_runner` checks that every ground loads with its baked lighting, and with the bake's lamps and sky taken out.
