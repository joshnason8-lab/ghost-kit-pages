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

The rest of a ground's spots stay billboards (the game's own, one draw call). Memory: about 0.9 MB for all five fans
(positions RGBA16F 107 rows x ~230 columns, normals RGBA8, meshes). No shadows from the crowd.

GPU vertex work: each crowd vertex reads about 12 texels (two clips, two frames each, positions and normals, and the
two turning points). Everything else (getting up, clapping on the beat, cheering, watching the ball) is arithmetic.

**Phone (Galaxy A16 class: Helio G99, Mali-G57 MC2).** These numbers are budgets set from the GPU's class, not yet a
measurement on the phone: the cloud machines here have no GPU (the renderer runs on the CPU), so frame times here
mean nothing. The pilot APK (claude/hurling-foundation-pilot) shows the frame rate on the phone in Settings > Graphics
> Show FPS; Hurling also drops a level by itself if a match runs under about 36 fps. If Medium does not hold 60 on the
A16, lower `WsgCrowd3D.BUDGET[1]` (e.g. 250 + 500: about 180,000 triangles).
