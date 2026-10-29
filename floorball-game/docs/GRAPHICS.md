# Graphics: the renderer and the three levels

Since 0.9 the game draws with **Godot's Mobile (Vulkan) renderer** at every level (as Hurling Heroes does since its
0.11), with **GL Compatibility** as the fallback. Low, Medium and High change in Settings at once, no restart.

## The renderer (game/renderer.gd)

| | |
|---|---|
| **Vulkan, for everyone** | `project.godot`: `rendering_method="mobile"`. Floorball is played where phones are recent and strong (the Nordic countries, Switzerland, Czechia, Germany), and a recent phone's Vulkan does more with each frame than OpenGL. |
| **The fallback** | Godot itself falls back to OpenGL if Vulkan will not start (`rendering_device/fallback_to_opengl3`). A phone whose graphics are known to struggle with Vulkan (older Mali: T-series, G31/G51/G52; PowerVR; Adreno 3xx, 4xx, 50x, 51x), or that runs Android 9 or older, or whose last start on Vulkan never reached the home screen (`user://vulkan_boot.flag`, written at start and cleared at the home screen), is set to GL Compatibility from its next start, quietly, by `user://renderer.cfg` (`application/config/project_settings_override`). |
| **The same colours on both** | Every shader reads its textures and colours as written (no `source_color` hint) and converts once at the end (`game/shaders/look.gdshaderinc`; nothing under GL), and colours given to shaders from code are plain vectors. Compared frame for frame (`tests/arena_look.tscn` with `--rendering-driver vulkan` and `opengl3`): the floor, its lamps' reflections, the crowd and the hall match. Before this the floor's lamp reflections came out as white blotches on Vulkan (an emission written for GL's sRGB light). |

## The three levels

| | Low | Medium | High |
|---|---|---|---|
| **For** | Phones under 4.5 GB or with a small GPU | The rest | Recent high-end phones (`Renderer.capable`: 64-bit, 6 GB, Adreno 640+, Mali-G710+, Immortalis, Xclipse), picked by the game on the first run |
| **Light** | the hall's light, no shadows | as Low, the floor's relief | **On Vulkan**: the key light's shadows from a 4096 map, soft-edged; a pool of light under the rink's lamps (up to eight spotlights); the lamps, screens and LED ribbons glowing (bloom); the polished floor reflecting the boards, benches and stands (a reflection probe); a touch more contrast and colour. On GL: the shadows as before. |
| **Ball** | drawn 1.8 times its size (it is 3 pixels across otherwise) | | as Low in play; on a penalty shot's close camera near life size, with its 26 holes cut through it |
| **Picture** | 75% scale, no anti-aliasing | 90%, 4x MSAA on Vulkan (2x left the far lines in dashes), 2x on GL | 100%, 4x MSAA |

## The hall's words

The boards' slogans and the arena's floor decals are drawn when the hall is built, in the phone's language
(`game/signage.gd`: a viewport drawn once and kept as a texture with mipmaps): "HEJA INNEBANDY" in Swedish, "HYVÄ
SALIBANDY" in Finnish, "HURÁ NA FLORBAL" in Czech. The game's name stays as it is, as a brand does.

## Pictures and numbers

`xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan res://tests/arena_look.tscn -- OUT cams arena,hall 0,2`
(Mesa's software Vulkan, `mesa-vulkan-drivers`, here; slow, but what a phone draws). No phone has measured High on
Vulkan yet: the developer readout (seven taps on the version in Settings > About) is the way to read it on one.
