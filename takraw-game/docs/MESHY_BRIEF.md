# Meshy brief: the players and referees

The players today are built in code (`game/body.gd`): a skinned mesh on a 17-bone humanoid skeleton, posed by the
game's own moves (`game/moves.gd`). This is the order for Meshy to replace them, and what the game will do with the
models. The prompts are in `tools/meshy/assets.json`; `tools/meshy/meshy_batch.py` (the same tool Kabaddi Raid uses)
makes them: a preview to check, then the texture, the rig and the download. Nothing has been ordered yet.

## The look

The concept art's: a **stylized** sports character (clean shapes, a slightly large head, flat matte colours that cel
shading suits), not a photograph. The venues around them are more realistic. Every prompt says so; check the
previews for it before paying for textures.

## What to order first (8 models, about 560 credits at ~70 each)

| Model | Who | Why |
|---|---|---|
| `player_01_striker_thai` | lean, long-legged striker | the roll spike's body |
| `player_02_tekong_malay` | compact, strong server | the tekong's build |
| `player_03_feeder_vietnam_woman` | slim setter, ponytail | the women's events |
| `player_04_striker_indonesia` | wiry, deep brown skin | skin and build range |
| `player_05_tekong_japan` | tall, fair | height range |
| `player_06_striker_philippines_woman` | strong striker, bun | women's strikers |
| `referee_01_man`, `referee_02_woman` | officials | the referee's chair and line judges |

The game recolours the kit for every team (as Kabaddi Raid does) and shifts skin tone a little, so six players
cover every squad.

## Settings for every model

| Setting | Value | Why |
|---|---|---|
| Model | Meshy latest | best faces and hands |
| Pose | **T-pose**, palms down | rigs cleanly (Meshy did not hold the A-pose for Kabaddi Raid) |
| Faces | **5,000** for players, 4,000 for referees | ten players and seven officials on a Galaxy A16: about 85,000 faces, comfortable for a Mali-G57 MC2 |
| Topology | quad, symmetry on | even limbs for the moves' big swings |
| Texture | one 1024 × 1024 base colour, no PBR maps | the toon shader uses the colour only; small download |
| Rig | Meshy's humanoid rig at the player's height | its Mixamo-style bone names map onto the game's (below) |

Reject a preview with: fused fingers, a jersey with a logo or number, a big belly or bulky muscles (takraw players
are lean), bare feet, long trousers.

## Fitting the models to the game

The game's skeleton (`game/body.gd`, `BONES`) uses these names; Meshy's rig maps onto them:

| Game | Meshy / Mixamo |
|---|---|
| hips, spine, chest, neck, head | Hips, Spine, Spine1 (or Spine2), Neck, Head |
| upperarm_l / _r, forearm_l / _r, hand_l / _r | LeftArm / RightArm, LeftForeArm / RightForeArm, LeftHand / RightHand |
| thigh_l / _r, shin_l / _r, foot_l / _r | LeftUpLeg / RightUpLeg, LeftLeg / RightLeg, LeftFoot / RightFoot |

The game's moves are written against a rest pose with the arms hanging down and every bone's rotation the identity;
a Meshy model rests in a T-pose with its own bone axes. The fitting (to do when the models arrive) works in model
space: each bone's rotation in a move, applied to the model's rest pose with the arms first turned down to the sides,
then converted back to the bone's local rotation. The players' blob shadows, tags, selection rings and contact points
stay as they are, so nothing else in the match changes.

Until then, `ToonBody` is the player, and the moves were tuned on it.

## Lessons from Kabaddi Raid's Meshy players

What went wrong when Kabaddi Raid's Meshy models went into its game, and what to do here from the start:

- **The pose**: Meshy ignores an A-pose request unless the prompt leads with it: start every person prompt with
  "T-pose".
- **Size**: a model came back at 206,920 triangles. Cut every body to about 15,000 before rigging.
- **Standing on the floor**: downloads are centred on the origin; put each model's lowest point at y = 0.
- **Seams**: vertices split along UV seams got different weights and tore open in motion. Weld before rigging.
- **Normals and winding**: keep the file's own normals and fix the triangle winding; do not recompute them.
- **Legs**: the auto-rig swapped legs on one model. Check every knee and ankle sits on its hip's side.
- **Face**: the face, jaw and beard lagged a turning head: give every face part wholly to the head bone.
- **Kit against skin**: the kit-colour mask caught saturated skin (kit colour speckled on knees and shins, the
  shorts' hem taking the shirt colour). Mark skin in a mask saved without loss (a lossy encoder dropped colour under
  transparent texels); never treat hands as kit; judge skin by the face's own hue; keep kit trims well away from
  skin hues (an orange trim was read as skin).
- **Skin tones**: pale peach tones went grey-white on tan textures; use warm tans (d4966c, cf9069) for the lightest.
- **Shine**: only bare skin takes a sweat sheen, not hair, shoes or officials' clothes.
- **No real people**: no player's face, name or number, and no logos on kit (see "Reject a preview with" above).
