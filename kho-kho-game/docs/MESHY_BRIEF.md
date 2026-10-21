# Meshy brief: the players and officials

**No Meshy credits have been spent.** The players today are built in code (`game/body.gd`): a skinned mesh on a
17-bone humanoid skeleton, posed by the game's own key poses (`game/poses.gd`). This brief is for ordering Meshy models
later. It says what to order and what the game will do with them, if the owner chooses to; the Kabaddi Raid tool
(`tools/meshy/meshy_batch.py` in that game) makes them.

## The look

A **stylized** sports character, as the code-built bodies are: clean shapes, a slightly large head, flat matte
colours that cel shading suits. Not a photograph. Kho kho players are lean and quick, not bulky.

## What to order first (7 models, about 490 credits at ~70 each)

| Model | Who | Why |
|---|---|---|
| `chaser_01_maharashtra_man` | lean, medium height, short hair, vest and shorts | the active chaser's sprint and dive |
| `chaser_02_karnataka_man` | wiry, darker skin, cropped hair | skin and build range |
| `defender_01_odisha_woman` | slim, hair in a plait, vest and shorts | the women's game |
| `defender_02_kerala_man` | very lean, tall | the defenders' build |
| `chaser_03_nepal_woman` | compact, hair tied back | build range, the women's chasers |
| `umpire_01_man` | white shirt, dark trousers, whistle on a cord | the two umpires |
| `referee_01_woman` | navy shirt, dark trousers | the referee, timekeeper, scorer |

The game recolours the kit for every team, as Kabaddi Raid does, and shifts skin tone a little. So five players cover
every squad.

## Settings for every model

| Setting | Value | Why |
|---|---|---|
| Pose | **T-pose**, palms down | rigs cleanly |
| Faces | **3,500** players, 3,000 officials | 24 players and 5 officials on the field: about 100,000 faces, inside the Low budget of a Mali-G52 at 720p |
| Topology | quad, symmetry on | even limbs for the deep squat and the dive |
| Texture | one 1024 × 1024 base colour, no PBR maps | the toon shader uses the colour only; a small download |
| Rig | Meshy's humanoid rig at the player's height | its Mixamo-style bone names map onto the game's |
| Feet | bare feet for two of the players, plain shoes for the rest | kho kho on earth is often played barefoot |

Reject a preview if it has:

- fused fingers;
- a logo, a number, or any real team's kit;
- bulky muscles;
- long trousers on a player;
- knee pads.

## Fitting the models to the game

| Game (`ToonBody.BONES`) | Meshy / Mixamo |
|---|---|
| hips, spine, chest, neck, head | Hips, Spine, Spine1 (or Spine2), Neck, Head |
| upperarm_l / _r, forearm_l / _r, hand_l / _r | LeftArm / RightArm, LeftForeArm / RightForeArm, LeftHand / RightHand |
| thigh_l / _r, shin_l / _r, foot_l / _r | LeftUpLeg / RightUpLeg, LeftLeg / RightLeg, LeftFoot / RightFoot |

The poses are written against a rest pose with the arms hanging down and every bone's rotation the identity. A Meshy
model rests in a T-pose with its own bone axes. To fit them, work in model space: turn the model's arms down to the
sides first, apply each bone's rotation from the pose to that rest pose, then convert back to the bone's local
rotation.

The things the game draws around the players stay as they are:

- the shadows (one multimesh);
- the rings;
- the touch and kho reach.

The seated squat (`Poses.SIT`) needs a check on a real model: the hips must sit low and the heels must lift. Until
then `ToonBody` is the player, and the poses were tuned on it.
