# Meshy brief: the players and umpires

The players and umpires today are built in code (`game/body.gd`): a skinned mesh on a 17-bone humanoid skeleton
(the same bone names as Takraw Smash's), posed by the game's own poses (`game/poses.gd`), with the bibs' letters from
one small strip (`assets/ui/bib_letters.png`). **No Meshy credits have been spent.** This is the order for Meshy if
you choose to replace them, and what the game would do with the models. Kabaddi Raid's and Takraw Smash's
`tools/meshy/meshy_batch.py` makes them: a preview to check, then the texture, the rig and the download.

## The look

A **stylized** sports character (clean shapes, a slightly large head, flat matte colours that the game's cel shading
suits), not a photograph: the same family as the code-built players, so the two can live side by side.

## What to order (7 models, about 490 credits at ~70 each)

| Model | Who | Why |
|---|---|---|
| `netball_01_shooter_tall` | a tall shooter (1.90 m), long arms, hair in a high ponytail | GS and GK: the height range |
| `netball_02_midcourt` | a lean, quick mid-court player (1.70 m), hair in a bun | C, WA, WD |
| `netball_03_goal_attack` | an athletic GA / GD (1.80 m), braids tied back | the circle-edge players |
| `netball_04_pacific` | a strong Pacific Islands defender, wide shoulders | build range (Tonga, Samoa, Fiji) |
| `netball_05_africa` | a tall African shooter, short natural hair | skin and hair range (Malawi, Uganda, Zimbabwe) |
| `umpire_01`, `umpire_02` | umpires in a plain polo shirt and long trousers, a whistle on a lanyard | the two officials |

Prompt words for every player: "female netball player, fitted sleeveless sports dress with a short flared skirt,
compression shorts, court shoes, plain kit with no logos, no numbers, no bib". The game adds the bib (front and back,
the position's letters) and recolours the dress for every team (as Kabaddi Raid recolours its kit), and shifts the
skin tone a little, so five players cover every squad.

## Settings for every model

| Setting | Value | Why |
|---|---|---|
| Pose | **T-pose**, palms down | rigs cleanly (Meshy did not hold the A-pose for Kabaddi Raid) |
| Faces | **3,500** for players, 3,000 for umpires | fourteen players and two umpires on a Mali-G52 at 720p: about 55,000 faces, as the code-built bodies are on Low today |
| Topology | quad, symmetry on | even limbs for the passing and shooting poses |
| Texture | one 1024 × 1024 base colour, no PBR maps | the toon shader uses the colour only; a small download |
| Rig | Meshy's humanoid rig at the player's height | its Mixamo-style bone names map onto the game's (below) |

Reject a preview with: fused fingers, a dress with a logo, letters or a number on it, a revealing cut (the netball
dress is a sports uniform), bare feet, jewellery (netball bans it).

## Fitting the models to the game

| Game bone | Meshy / Mixamo |
|---|---|
| hips, spine, chest, neck, head | Hips, Spine, Spine1 (or Spine2), Neck, Head |
| upperarm_l / _r, forearm_l / _r, hand_l / _r | LeftArm / RightArm, LeftForeArm / RightForeArm, LeftHand / RightHand |
| thigh_l / _r, shin_l / _r, foot_l / _r | LeftUpLeg / RightUpLeg, LeftLeg / RightLeg, LeftFoot / RightFoot |

The poses are written against a rest pose with the arms hanging down and every bone's rotation the identity; a Meshy
model rests in a T-pose with its own bone axes. The fitting works in model space: each bone's rotation in a pose,
applied to the model's rest pose with the arms first turned down to the sides, then converted back to the bone's local
rotation (as Takraw Smash plans). The bib stays a separate panel tied to the chest bone, so its letters remain one
texture for every team. Everything else in the match (the rings, the tags, the movement) is unchanged.

Until then, `ToonBody` is the player, and the poses were tuned on it.
