# Meshy brief: models the owner may choose to generate

**What has been made (0.5.0, round five):** the referee, the umpire, two fans for the crowd sheet and the
floodlight, each kept in `tools/meshy/tasks.json` with its prompt (`tools/meshy/meshy.py` makes and fetches them;
`docs/PROGRESS.md` says how each went in). Tried and not used: the sliotar (egg-shaped; made in code instead), a
first floodlight (a bar), and two hurlers with a hurley in hand (neither had the hurley; both wore an
American-football helmet). The hurlers stay the owner's own model (`tools/player/`). The rest of this brief is what
could still be ordered, and how it slots in.

## How a model replaces the code-built body

`ToonBody` builds a skinned mesh on a 17-bone humanoid skeleton with the usual names (hips, spine, chest, neck, head,
upperarm/forearm/hand left and right, thigh/shin/foot left and right), the rest pose standing, arms hanging, facing
+Z, feet at y = 0, 1.80 m tall. A Meshy model rigged to the same bone names (Meshy's auto-rig, then renamed) can take
its place: the poses are bone rotations, so the same moves play on it. Keep each model to **one mesh, one material,
under about 4,000 triangles** (the low-end phones draw thirty of them), with a lower level of detail under 1,500.

## The order (in priority)

1. **Hurler, outfield** (one body, kit recoloured in game): "A senior hurler in a plain short-sleeved county jersey,
   white shorts, knee-length socks, black boots, a modern hurling helmet with a steel face guard; athletic, 1.80 m,
   T-pose, arms out, palms down; realistic proportions; no logos, no crest, no numbers, no sponsor." The jersey,
   shorts and socks textured plain white or grey so the game tints them with each county's colours (a mask texture:
   red = jersey, green = trim, blue = skin).
2. **Hurley** (a separate prop, attached to the right hand): "An ash hurley, 34 inches, a broad curved bas with a
   metal band, grip tape on the handle, natural wood." Under 300 triangles.
3. **Goalkeeper**: as 1, a different jersey (tinted) and a wider-bas hurley.
4. **Referee**: "A GAA referee in a black short-sleeved shirt and shorts, a whistle on a lanyard, T-pose."
5. **Umpire**: "A Gaelic games umpire in a long white coat to the knees and a white cap, T-pose; a small white flag
   and a small green flag as separate props."
6. **Linesman**: as the referee, with a flag prop.
7. **Spectators** (for the crowd's one-draw-call cards): eight people, waist up, in rain jackets and county-coloured
   jerseys (plain, no crests), rendered to a 384 × 96 sprite sheet.
8. **A sliotar**: "A hurling sliotar, white leather, a raised rim (seam) round it, 70 mm." Under 200 triangles.

## Not to order

Real players' likenesses, county crests or sponsors' marks, real stadiums. The venues stay code-built (merged, a few
draw calls each), which the low-end phones need more than detail.
