# Meshy brief: models the owner may choose to generate later

Floorstorm ships with every person built in code (game/body.gd): a skinned mesh on a 17-bone humanoid skeleton plus a
stick bone, one draw call each. **No Meshy credits were spent.** If you want more realistic people later, this is
what to generate, and how the game would take them.

## What the game needs

| Asset | Count | Notes |
|---|---|---|
| Field player, men | 2-3 builds (slim, medium, strong) | Floorball kit: short-sleeved jersey, shorts, long socks pulled over the knee (shin guards under), indoor court shoes. Plain white jersey and dark shorts so the game can tint them to any team's colours (keep a mask of the kit, or texture the kit pure white) |
| Field player, women | 2 builds | The same kit; hair tied back (ponytail) as most players wear it |
| Goalkeeper | 1 | Padded long trousers, a padded long-sleeved jersey, knee pads, a helmet with a full face cage, thin gloves; **no stick** (Rules 403). In a crouched-ready T-pose if Meshy allows |
| Referee | 1 | Black trousers or shorts and the referees' shirt (a single colour, yellow in the game), a whistle on a cord |
| Stick | 1 | A composite floorball stick, 96 cm shaft with a grip, a plastic blade with holes, about 25 cm; separate object, origin at the grip's end, shaft down -Y, blade's toe toward +Z (the game's stick bone) |
| Spectator cards | 8 figures | Optional: head-and-shoulders sprites for the crowd sheet (game/crowd.gd draws its own today) |

## Prompts (Meshy text-to-3D, then rig)

- Person prompts start with the pose, as Kabaddi learned: "**T-pose**, full body, a floorball player, short-sleeved
  plain white sports jersey, dark shorts, white long socks over the knees, white indoor court shoes, athletic build,
  realistic proportions, game-ready, low poly 8k triangles".
- Goalkeeper: "**T-pose**, full body, a floorball goalkeeper, padded long-sleeved jersey, padded long trousers, knee
  pads, a helmet with a metal face cage, thin gloves, no stick, realistic, low poly 8k triangles".
- Referee: "**T-pose**, full body, a sports referee, plain yellow short-sleeved shirt, black trousers, black shoes,
  a whistle on a cord, low poly 6k triangles".
- Stick: "a floorball stick, straight black composite shaft 96 cm with a white grip, a white plastic blade with
  slots, 25 cm long, slightly curved, low poly 1k triangles".

## How they would go in

1. Rig to the bone names in `Body.BONES` (hips, spine, chest, neck, head, upperarm/forearm/hand _l/_r,
   thigh/shin/foot _l/_r), rest rotations identity, the person facing +Z, soles at y = 0 (Kabaddi's
   `tools/rig` scripts do this).
2. Keep each person under about 8,000 triangles: twelve players and two referees must stay inside the Low budget
   (about 100,000 triangles a frame on a Mali-G52 at 720p, docs in README "Performance").
3. Body.gd would load a packed mesh instead of building one; the stick stays its own bone so body and stick remain
   one draw call; Player.gd's poses and IK are unchanged.
4. Kit colours: the kit's pixels tinted in the shader from the team's colours (Kabaddi's skin/kit mask approach).

Estimated cost: about 8 models x 30 credits (preview, refine, texture, rig): ~240 credits.
