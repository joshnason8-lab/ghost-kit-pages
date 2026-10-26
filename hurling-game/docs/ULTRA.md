# Ultra graphics

A fourth graphics level, above High, for recent high-end phones. It is never picked for you: the phone still picks
Low or Medium on its first run (`Game.detect_graphics`), High is a choice, and Ultra is a choice that also needs a
download. **Low, Medium and High are exactly as they were** (below: the same draw calls, triangles and video memory
before and after, and CI fails the build if any Ultra file is in the APK).

## How it works

| | |
|---|---|
| **Who is offered it** | `Ultra.capable()` (`game/ultra.gd`): a 64-bit (arm64) phone with 6 GB of memory or more and a Vulkan-class GPU: Adreno 640 and later (Snapdragon 855, 2019, onward), Mali-G710 and later, Immortalis, or Samsung's Xclipse. Elsewhere the Ultra chip is not shown in Settings. On a computer, always (for testing). |
| **The renderer** | Godot's Mobile (Vulkan) renderer, in place of GL Compatibility. Godot fixes the renderer when it starts, so picking Ultra writes `user://renderer.cfg` (the project's settings override, `application/config/project_settings_override`) and the game says to open it again (Android does not let an app restart itself; on a computer it restarts by itself). Leaving Ultra removes the file, and the same reopen. |
| **Falling back** | Back to High, with a line in Settings saying why, if: Vulkan will not start (Godot falls back to OpenGL by itself, `rendering_device/fallback_to_opengl3`); the HD pack is missing or will not mount; or the last start in Ultra never reached the home screen (a crash: `user://ultra_boot.flag` is written at start and cleared when the home screen is up). |
| **The HD pack** | `hurling-heroes-hd-1.pck` on the [beta release](https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/ash-and-leather-beta), with its manifest `hurling-heroes-hd-1.json` (size, SHA-256, and a hash of what it is built from). Fetched the first time Ultra is picked, from the Ultra screen: the size first, then the download with a progress bar, in 4 MB pieces (HTTP ranges) so a lost connection or a closed app carries on where it stopped; each piece tried again up to four times, and GitHub's signed download address found again when it runs out. The whole file is checked against its SHA-256 before it is kept (`user://hd/`). It is mounted at start with `ProjectSettings.load_resource_pack` (its files appear under `res://ultra/`; the APK's own files are never replaced). "Remove the HD pack" in the Ultra screen when leaving Ultra frees the space. |
| **The APK** | The same name pattern (`hurling-heroes-<version>.apk`, so Obtainium finds it), signed with the owner's beta key, about the size it was: Ultra adds only its code and a few lines of text. The one new permission is internet, used only for the HD pack (the privacy page says so). |

## What Ultra changes

In the order the owner asked for them.

1. **Lighting** (`game/stadium.gd` `_ultra_light`): the sun casts real-time shadows (4 cascades to 220 m, blended),
   from every player, official, hurley, goal and stand; the sky lights the scene and is reflected in it; filmic (ACES)
   tonemapping with an exposure for each time of day; glow on bright things (the floodlights, the sky, white shirts in
   sun); a little more saturation and contrast. At night, a spotlight from each of the ground's floodlight masts (up to
   8) lights the field. Every colour the game writes for GL Compatibility is converted for the Vulkan renderer's linear
   light (`game/shaders/look.gdshaderinc`, a no-op under Compatibility), so the kits and grass keep their colours.
   **SSAO is not there**: Godot's Mobile renderer does not have it (only Forward+, which is for desktops). The shadows,
   normal maps and baked shading do that work instead.
2. **Players** (`game/hero_body.gd`): the owner's model cut to 23,468 triangles (11,734 far off) where Low, Medium and
   High have 5,866; its texture at 4096 px (from the owner's full-size original) with the kit mask at 2048; lit, with
   cloth shading on the shirt, shorts and socks (Poly Haven's cotton jersey weave as a normal and roughness map, a soft
   rim) and skin shading on face, arms and legs (light through the skin at the edges); faces and helmets from the
   larger texture. The officials (`game/person_body.gd`) from Meshy's PBR refine: 2048 px colour, normal and roughness
   maps.
3. **Animation**: every clip at 60 frames a second (the CMU walk and jog at full quality, `tools/mocap/bvh_clip.py
   --ultra`; the Mixamo run and swings, `tools/player/bake.gd`), and a 0.18 s blend from one action into the next
   (`game/player.gd` `_crossfade`).
4. **Stadium and crowd**: the crowd's sheet at 256 × 512 px a figure (24 figures; twice High's), seats closer together
   so more of them (25,078 at the stadium against High's 22,824); the stands' concrete with a real texture and normal
   map, casting shadows; the grass at 4096 px (Poly Haven's grass_ground: colour, normal and roughness), lit, with a
   mowing cross-cut and wear down the middle.
5. **TV presentation** (`game/replay.gd`): replays cut halfway to a low touchline camera tracking the ball, as a
   broadcast does.

## Numbers

`tests/perf_probe.tscn`, the busiest frame of two seconds' play, each level in a run of its own (so the video memory
is that level's own). Low, Medium and High under GL Compatibility; Ultra under the Mobile renderer
(`--rendering-method mobile`, on Mesa's software Vulkan here: the frame times are this machine's CPU, not a phone's).

| | Draw calls | Triangles | Video memory | Crowd |
|---|---|---|---|---|
| Stadium, Low: 0.9.0 / 0.10.0 | 91 / 91 | 100,997 / 100,997 | 40.1 / 40.1 MB | 4,958 |
| Stadium, Medium | 92 / 92 | 190,613 / 190,613 | 75.5 / 75.5 MB | 16,079 |
| Stadium, High | 132 / 132 | 342,744 / 342,744 | 87.0 / 87.0 MB | 22,824 |
| Parish, Low | 95 / 95 | 102,271 / 102,271 | 40.7 / 40.7 MB | 120 |
| Parish, Medium | 96 / 96 | 168,543 / 168,543 | 75.4 / 75.4 MB | 347 |
| Parish, High | 136 / 136 | 301,011 / 301,011 | 86.4 / 86.4 MB | 493 |
| **Stadium, Ultra** | 129 | 615,371 | 377.6 MB (textures 218.5) | 25,078 |
| **Parish, Ultra** | 127 | 534,768 | 376.4 MB (textures 219.1) | 553 |

Ultra's triangles count the shadow cascades too (each draws the casters again). The video memory is the desktop's;
a phone's ASTC textures come to about the same.

**The budget**: 60 frames a second on a 2023 or later flagship (Snapdragon 8 Gen 2 / Adreno 740, Dimensity 9200 /
Immortalis-G715, Exynos 2400 / Xclipse 940, Tensor G3 / Mali-G715), or a steady 30 with the frame rate set to Battery
saver. About 130 draw calls and 0.6 million triangles a frame (shadows included) is well inside what those GPUs draw
at 60 under Vulkan; the costs to watch are the shadow cascades and the floodlights' spotlights at night. No phone has
measured it yet: the beta's developer readout (tap the version on the home screen 7 times: frame times, draw calls, fps) is the
way to read it on one. Ultra is never dropped a level by the game itself (Low to High are, under about 36 fps):
the player chose it.

**The HD pack**: 119,586,976 bytes (114 MB) for pack 1. The owner's target was 300-600 MB; it is what the content
comes to (a 4K texture is about 12 MB once compressed for the GPU with its mipmaps), and padding it out with larger
files would add download without anything a phone's screen shows.

## Building the pack

```sh
python3 tools/ultra/fetch.py      # the large Poly Haven sources (not in the repository), checked by SHA-256
godot --headless --path . --import
tools/ultra/build_pack.sh         # build/hurling-heroes-hd-<PACK>.pck and .json
```

The pack holds content only, no code: an export always adds the project's settings and its autoload scripts, so
`tools/ultra/repack.gd` rewrites it with the files under `ultra/` and their imported textures alone.
`tools/ultra/pack_preset.py` (run by `build_pack.sh`) writes the "Android HD pack" export preset with every file under
`ultra/`. The Android presets leave `ultra/*` out. CI builds the pack on each push and uploads it only when what it is
made from has changed (the manifest's `source`); the release is updated in place, so the pack stays across betas.
A change to the pack that an older game could not read: raise `Ultra.PACK` (the file names carry it).

After a release, `tests/hd_download.tscn` fetches the real pack from it through the game's own downloader, checks
and mounts it (needs the internet, so not in CI): 114 MB in 21 s here, whole and mounted.

Content tools: `tools/crowd/render_fans.gd -- ultra`, `tools/mocap/bvh_clip.py --ultra ultra/anim`,
`tools/player/bake.gd` (its 7th argument the frame rate, 8th `clips_only`), `tests/kit_view.gd <out> 3` for a picture.

## Meshy credits

Logged in `tools/meshy/tasks.json` (`credit_log`, `tools/meshy/meshy.py credits`). The shared account had 189 at the
start (other games had spent from it). Spent on the referee's and umpire's PBR refines (20) and their rigs (10):

| When | Balance | |
|---|---|---|
| 26 Oct 2026 06:37 | 189 | before the Ultra update |
| 06:40 | 169 | after the two PBR refines |
| 06:41 | 159 | after the two rigs |
| after | 159 | the Ultra update done |

**30 credits** in all. The hurlers are the owner's own model (its full-size original), which Meshy could not better.

## Licences

The grass (grass_ground), the shirts' cloth (cotton_jersey) and the concrete (concrete_wall_008): Poly Haven, CC0. The
officials: the maker's own Meshy models. The CMU clips as before (mocap.cs.cmu.edu). All in the game's Licences screen.
