# Graphics: the renderer, the three levels, the HD pack

Since 0.11 the game draws with **Godot's Mobile (Vulkan) renderer** at every level, and has three levels, **Low,
Medium and High**, changed in Settings at once, no restart. (0.10 had a fourth, Ultra, on Vulkan while the others
were on GL Compatibility, so changing to it meant opening the game again; the owner asked for one renderer and
three levels. 0.10's Ultra is High now.)

## The renderer

| | |
|---|---|
| **Vulkan, for everyone** | The project's renderer (`project.godot`: `rendering_method="mobile"`). Phones sold in Ireland and the UK over the last four years or so, the mid-range Samsungs included, have usable Vulkan, and it does more with each frame than OpenGL. |
| **The fallback** | GL Compatibility, the renderer the game used up to 0.10, for phones Vulkan does not suit (`game/ultra.gd`): Godot itself falls back to OpenGL if Vulkan will not start (`rendering_device/fallback_to_opengl3`); a phone whose graphics are known to struggle with Vulkan (older Mali: T-series, G31/G51/G52; PowerVR; Adreno 3xx, 4xx, 50x, 51x) or that runs Android 9 or older, or whose last start on Vulkan never reached the home screen (a crash: `user://vulkan_boot.flag` is written at start and cleared at the home screen), is set to GL Compatibility from its next start, quietly, by `user://renderer.cfg` (the project's settings override, `application/config/project_settings_override`). A phone that crashed is told once, in Settings. |
| **The same look on both** | The game's colours were all chosen under GL Compatibility, which draws them as written; Vulkan works in linear light. Every shader reads its textures and colours as written (no `source_color` hint: Vulkan was found to decode a GPU-compressed texture and an uncompressed one differently) and converts once at the end (`game/shaders/look.gdshaderinc`, nothing under GL); colours given to shaders from code are plain `Vector3`s (a `Color` is decoded too). Compared frame for frame on both renderers: the grass, the crowd, the stands, the kits and the floodlights match. Medium smooths 4× (on Vulkan 2× left the far lines of the pitch in dashes; a phone's tiled GPU does 4× almost for free). |

## The three levels

| | Low | Medium | High |
|---|---|---|---|
| **For** | Phones under 4.5 GB or with a small GPU (Mali-G52/G57, Adreno 5xx/61x, PowerVR) | The rest | Recent high-end phones (`Ultra.capable`: 64-bit, 6 GB, Adreno 640+, Mali-G710+, Immortalis, Xclipse) |
| **Picked** | By the game on the first run (`Game.detect_graphics`), changed in Settings any time; the game drops a level by itself if a match runs under about 36 fps (Settings can turn that off) | | |
| **Players** | 1,757 triangles, no outlines | 5,866, 2K texture | as Medium; with the HD pack 23,468 and 4K |
| **Light** | the time of day's light in the colours, unlit | as Low, the grass's normal map catching the sun, a shadow under each man | **real lighting (on Vulkan)**: the sun's shadows from everything on lit grass, lit players (cloth and skin shading) and officials, the sky's light and reflections, filmic tonemapping and glow, floodlights that light the field at night |
| **Crowd** | 5,400 at the stadium | 17,300 | 24,600; with the HD pack 26,800, sharper |
| **Moves** | the clips | the clips | blended into each other (0.18 s); with the HD pack the Mixamo moves (the swings, catches, the sprint) at 60 fps |
| **Replays** | from behind the goal | | then cut to a low touchline camera, as television does |
| **Picture** | 75% scale, no anti-aliasing | 90%, 4× MSAA | 100%, 4× MSAA |

On the GL fallback High has its textures, crowd and anti-aliasing but not the real lighting (it needs Vulkan).

## The HD pack (optional, for High)

The hurlers at full detail (23,468 triangles, 11,734 far off) with a 4K texture and the cotton jersey's weave as a
normal and roughness map; the officials' Meshy PBR models; the pitch's grass at 4K; the crowd's sheet twice as sharp
and seats closer together; the stands' concrete texture; the Mixamo moves at 60 fps (the CMU walk and jog stay at 30: their strides were measured there). 114 MB.

| | |
|---|---|
| **Where** | `hurling-heroes-hd-1.pck` on a release of its own, [hurling-heroes-hd](https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/hurling-heroes-hd) (kept, never remade; its title does not start "Hurling Heroes ", so Obtainium's filter for the beta passes it by), with its manifest `hurling-heroes-hd-1.json` (size, SHA-256, a hash of what it is built from). |
| **Getting it** | Settings > The screen, on a phone that can use it: a line saying whether it is in, and the HD pack button (`ui/hd_pack_screen.gd`). The size first, then the download with a progress bar, in 4 MB pieces (HTTP ranges) so a lost connection or a closed app carries on where it stopped; each piece tried again up to four times, and GitHub's signed download address found again when it runs out. The whole file is checked against its SHA-256 before it is kept (`user://hd/`), then **mounted at once** (`ProjectSettings.load_resource_pack`: its files are new to the game, so no restart) and at every start after. Remove frees the space (used no more from that moment; unmounted at the next start). |
| **What is in it** | Content only, no code: an export always adds the project's settings and autoload scripts, so `tools/ultra/repack.gd` rewrites it with the files under `ultra/` and their imported textures alone. |
| **Internet** | The only thing the game uses the internet for, and only when asked (the privacy policy, in the game and on the web, says so). |

### Building it

```sh
python3 tools/ultra/fetch.py      # the large Poly Haven sources (not in the repository), checked by SHA-256
godot --headless --path . --import
tools/ultra/build_pack.sh         # build/hurling-heroes-hd-<PACK>.pck and .json
```

`tools/ultra/pack_preset.py` (run by `build_pack.sh`) writes the "Android HD pack" export preset with every file under
`ultra/`. The Android presets leave `ultra/*` out, and CI fails a build with any of it in the APK. CI builds the pack on
each push and uploads it only when what it is made from has changed (the manifest's `source`), to its own release; the
beta release is made afresh on every push, so its date moves on and Obtainium ("release date as version") sees each
beta. A change to the pack that an older game could not read: raise `Ultra.PACK` (the file names carry it).

After a release, `tests/hd_download.tscn` fetches the real pack through the game's own downloader, checks and mounts
it (needs the internet, so not in CI). Content tools: `tools/crowd/render_fans.gd -- ultra`,
`tools/player/bake.gd` (its 7th argument the frame rate, 8th
`clips_only`). Pictures: `tests/kit_view.tscn -- <out> <level>`, `tests/venue_view.tscn -- <out> <venue> <level>
[nopack]`, `tests/house_view.tscn`, `tests/run_view.tscn`.

## Numbers

`tests/perf_probe.tscn`, the busiest frame of two seconds' play, each level in a run of its own (so the video memory
is that level's own). On Mesa's software Vulkan here, so the frame times are this machine's CPU, not a phone's: the
draw calls, triangles and memory are what a phone draws.

| | Draw calls | Triangles | Video memory | Crowd |
|---|---|---|---|---|
| **Stadium, Low** (Vulkan / GL) | 90 / 91 | 140,378 / 140,378 | 48.9 / 40.0 MB | 5,356 |
| **Stadium, Medium** | 91 / 92 | 231,672 / 231,672 | 103.3 / 86.9 MB | 17,298 |
| **Stadium, High** (no HD pack; GL without the real lighting) | 129 / 132 | 530,529 / 384,845 | 159.0 / 87.0 MB | 24,564 |
| **Stadium, High with the HD pack** (Vulkan) | 129 | 660,736 | 377.6 MB | 26,818 |
| **Parish, Low** | 94 / 95 | 96,820 / 96,820 | 49.2 / 40.1 MB | 120 |
| **Parish, Medium** | 95 / 96 | 163,092 / 163,092 | 102.6 / 86.1 MB | 347 |
| **Parish, High** (no HD pack) | 127 / 136 | 407,486 / 295,560 | 157.3 / 85.8 MB | 493 |
| **Parish, High with the HD pack** (Vulkan) | 127 | 529,317 | 375.7 MB | 553 |

Against 0.10 (GL): the stadium's Low, Medium and High were 91 / 101,000, 92 / 191,000 and 132 / 343,000; the new
corner stands and their crowd are the difference (the same on both renderers).

High's triangles on Vulkan include the shadow cascades (each draws the casters again). Vulkan keeps a little more in
video memory than GL for the same level (its buffers); the HD pack's 4K textures are most of High's 378 MB.

**The budget**: Low and Medium for the phones they are picked for, at 30 to 60 fps; High at 60 fps on a 2023 or
later flagship (Snapdragon 8 Gen 2 / Adreno 740, Dimensity 9200 / Immortalis-G715, Exynos 2400 / Xclipse 940,
Tensor G3 / Mali-G715), or a steady 30 with the frame rate set to Battery saver. No phone has measured it yet: the
beta's developer readout (tap the version on the home screen 7 times: frame times, draw calls, fps) is the way to read
it on one.

## Meshy credits

Logged in `tools/meshy/tasks.json` (`credit_log`, `tools/meshy/meshy.py credits`). For the HD pack (0.10): the
referee's and umpire's PBR refines (20) and their rigs (10), 30 credits (189 to 159). The hurlers are the owner's own
model (its full-size original).

## Licences

The grass (grass_ground), the shirts' cloth (cotton_jersey) and the concrete (concrete_wall_008): Poly Haven, CC0. The
officials: the maker's own Meshy models. The CMU clips (mocap.cs.cmu.edu). All in the game's Licences screen.
