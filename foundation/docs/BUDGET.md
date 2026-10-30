# Budgets

## 3D crowd (`WsgCrowd3D`, Medium and High; Low keeps the game's billboards)

Measured from the baked data (`addons/wsg_foundation/crowd/crowd.json`, five fan models):

| | near figure | far figure |
|---|---|---|
| triangles | 388-496 (mean 426) | 108-200 (mean 163) |
| vertices | 197-241 | the same vertices |

| Quality | fans in 3D (near + far) | triangles | draw calls | CPU a frame |
|---|---|---|---|---|
| Medium | 400 + 800 = 1,200 | about 300,000 | 10 | 5 uniforms x 10 materials |
| High | 1,000 + 2,000 = 3,000 | about 750,000 | 10 | the same |
| Close (3: a practice, a shoot-out) | 2,000 + 1,000 = 3,000 | about 990,000 | 10 | the same; paid for by the 25-odd players not on the pitch (6,000 triangles each) |

The rest of a ground's spots stay billboards (the game's own, one draw call). Memory: about 0.9 MB for all five fans
(positions RGBA16F 107 rows x ~230 columns, normals RGBA8, meshes). No shadows from the crowd.

GPU vertex work: each crowd vertex reads about 12 texels (two clips, two frames each, positions and normals, and the
two turning points). Everything else (getting up, clapping on the beat, cheering, watching the ball) is arithmetic.

**Phone (Galaxy A16 class: Helio G99, Mali-G57 MC2).** These numbers are budgets set from the GPU's class, not yet a
measurement on the phone: the cloud machines here have no GPU (the renderer runs on the CPU), so frame times here
mean nothing. The pilot APK (claude/hurling-foundation-pilot) shows the frame rate on the phone in Settings > Graphics
> Show FPS; Hurling also drops a level by itself if a match runs under about 36 fps. If Medium does not hold 60 on the
A16, lower `WsgCrowd3D.BUDGET[1]` (e.g. 250 + 500: about 180,000 triangles).

## Measured in Hurling Heroes (the pilot, `tests/perf_probe.tscn`, the national stadium, the busiest frame)

| | before (the game today) | after (the foundation) |
|---|---|---|
| Low | 95 draw calls, 161,000 triangles | 97 draw calls, 164,000 triangles |
| Medium | 96 draw calls, 232,000 triangles | 108 draw calls, 443,000 triangles |
| High | 141 draw calls, 373,000 triangles | 159 draw calls, 1,125,000 triangles |

Medium adds about 210,000 triangles (the 3D crowd) and 12 draw calls; High adds 750,000. On a Galaxy A16 class phone
Medium should be checked first (the pilot APK, Settings > Graphics); if it does not hold 60 fps, lower
`WsgCrowd3D.BUDGET[1]`. High's 3,000 fans are for high-end phones; 2,000 may be wiser.

## By profile (WsgFoundation), measured

Hurling's `tests/perf_probe.tscn` at the national stadium (the biggest ground: 30 players, 8 officials, the most
crowd spots), the HD pack off, the most each frame over a second of play; `WSG_PROFILE=budget` draws Hurling as a
budget game would (its crowd caps and its full-detail bodies). Measured in the build container (software rendering:
lavapipe for Vulkan, llvmpipe for GL), so the draw calls and triangles are what a phone draws, the frame times are not
a phone's and are left out.

| profile, tier | GL Compatibility | Vulkan (Mobile) |
|---|---|---|
| premium Low | 90 draw calls, 162,000 triangles | 89, 162,000 |
| premium Medium | 101, 442,000 | 100, 442,000 |
| premium High | 150, 878,000 (was 1,125,000 before High's crowd was trimmed to 2,000) | 146, 1,013,000 |
| budget Low | 90, 162,000 | 89, 162,000 |
| budget Medium | 96, 241,000 | 95, 241,000 |

Budget Medium is Low plus 79,000 triangles and 6 draw calls (150 3D fans, the 6 nearest bodies in full detail, the
rest on the light mesh); premium Medium adds 280,000. The target, 30 fps on Medium on a Galaxy A16 class phone
(Mali-G57 MC2 / Adreno 610) under GL Compatibility, has to be confirmed on the phone: Hurling's Low (162,000
triangles, 90 draw calls) is what such phones run today, and budget Medium is 1.5 times its triangles at the same
draw calls. If it does not hold 30, lower `PROFILES.budget.crowd[1]` (the 3D fans) first, then `full_bodies`.
