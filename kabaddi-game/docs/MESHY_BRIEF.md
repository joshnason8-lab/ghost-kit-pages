# Meshy brief: players, referees and crowd

This is the asset order for Meshy: what to make, the exact prompts and settings, what to reject, and what the game
does with each model afterwards. Every prompt is under Meshy's 600-character limit, so it can be pasted as is.

## What Meshy can and can't do (checked October 2026)

- **Can:** realistic textured humans from text or a picture; a set face count (Smart Topology, up to 15,000 faces,
  or a remesh to any count); an automatic body rig with Mixamo-style bone names, plus a library of over 600
  animations; GLB and FBX export; a new texture on the same model and UVs (Retexture).
- **Can't:** a face rig. Meshy rigs the body only: no jaw, eye or eyelid bones, no blendshapes. The game adds a
  simple face rig itself (see [Faces](#faces-that-move)).
- Every generation is a new person. Bodies and faces can't be mixed afterwards, so each combination we want is
  its own generation. Skin tone can still be shifted a little in the game, as it is now.

## Settings for every character

| Setting | Value | Why |
|---|---|---|
| Model | Meshy 7 (latest) | Best faces and hands |
| Art style | Realistic | |
| Pose | **A-pose** | Rigs cleanly; arms clear of the body |
| Symmetry | On | Even shoulders and limbs |
| Topology | **Quad** | Bends better at knees, elbows and shoulders |
| Face count | Players and referees **10,000**; crowd 30,000 | 17 people on court must run on a Galaxy A16. The crowd is rendered into pictures beforehand, so it can be detailed |
| Texture | On, **PBR on**, 2048 px | The game shrinks it to 1024 for the phone |
| Height for rigging | Per character, below | So the rig matches real proportions |

Ask every time for: **no baked shadows or ambient occlusion in the texture** (the game lights the scene itself),
and **no logos, text, numbers, sponsors or crests** (the game is its own league and adds shirt numbers itself).

## The kit rule (players)

Every player wears the same plain kit, so the game can paint it in any team's colours:

- **Jersey:** tight-fitting, short sleeves, **flat solid royal blue** (about #1E3CFF).
- **Trim:** **flat solid red** (about #E01020) on the collar, a shoulder panel on each side, the sleeve cuffs and a
  stripe down each side.
- **Shorts:** tight, above the knee, the same royal blue with a red stripe down each side.
- **Barefoot.** No knee pads, ankle wraps or tape on the bodies; those come as separate pieces (below) so each
  player can have his own.

Blue and red are what the game's kit tool looks for (`tools/rig/kit_texture.py`). Flat colours, no gradients or
patterns, make clean edges.

## Workflow for each character

1. **Picture first** (best faces). In Meshy's Text to Image, use the *image prompt*, front view, plain light-grey
   background. Pick the best of the four. Reject it if the hands, feet or face are wrong.
2. **Image to 3D** from that picture with the settings above. If there is no picture, use Text to 3D with the
   *3D prompt*.
3. **Texture** with the *texture prompt* (on Image to 3D, keep the picture's colours).
4. **Check** it against the reject list below. Regenerate rather than fix.
5. **Rig** (Animate → Auto-rig) with the height given. Then add the animations **Idle**, **Running** and
   **Cheering**, so the rig can be checked.
6. **Download** the **rigged GLB** and the plain textured GLB. Name them as below.

### Reject if

- Extra, missing or fused fingers or toes; hands like mittens.
- Legs or arms joined to the body; armpits filled in.
- Any logo, letters, numbers or crest on the kit.
- Shadows painted into the texture (dark armpits, dark under the chin).
- A face that is blurred, smeared, or not looking forward; an open mouth.
- Hair that sticks out as a solid block (tight, short hair works best).

## Players

All are adult professional kabaddi players: very fit, strong thighs and core, short tidy hair. The common ending
of every prompt:

> *…wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar,
> shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees
> from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.*

**Texture prompt (all players):** *Photorealistic skin with pores and natural tone variation, realistic short hair,
matte stretch sports fabric with fine stitching, flat solid royal blue and red kit, no logos, no text, no numbers,
even studio lighting, no baked shadows, no ambient occlusion.*

| File | Who | Height | Prompt start (add the common ending) |
|---|---|---|---|
| `player_01_raider_haryana` | Lean raider | 1.76 m | Photorealistic Indian kabaddi raider, 24-year-old man from Haryana, lean wiry athletic build, long limbs, defined calves, wheatish light-brown skin, short black hair faded at the sides, light stubble, sharp jaw, |
| `player_02_allrounder_maharashtra` | All-rounder | 1.80 m | Photorealistic Indian kabaddi all-rounder, 27-year-old man from Maharashtra, athletic muscular build, broad chest, medium-brown skin, short wavy black hair, clean-shaven, |
| `player_03_corner_haryana` | Stocky corner defender | 1.78 m | Photorealistic Indian kabaddi corner defender, 29-year-old man from Haryana, stocky powerful build about 92 kg, thick neck, very strong thighs, light-brown skin, black buzz cut, thick black moustache, |
| `player_04_cover_tamil` | Tall cover defender | 1.85 m | Photorealistic Indian kabaddi cover defender, 26-year-old man from Tamil Nadu, tall heavy muscular build about 95 kg, dark-brown skin, short tight curly black hair, short trimmed beard, |
| `player_05_veteran_punjab` | Veteran captain | 1.79 m | Photorealistic Indian kabaddi team captain, 34-year-old man from Punjab, solid muscular build about 88 kg, medium-brown skin, short salt-and-pepper hair, short salt-and-pepper beard, calm face, |
| `player_06_raider_bengal` | Small quick raider | 1.72 m | Photorealistic kabaddi raider from Bangladesh, 22-year-old man, small light quick build about 68 kg, medium-brown skin, short side-parted black hair, thin black moustache, |
| `player_07_defender_iran` | Iranian defender | 1.83 m | Photorealistic Iranian kabaddi defender, 28-year-old man, powerful muscular build about 90 kg, light olive skin, short dark-brown hair, full short dark beard, |
| `player_08_raider_korea` | Korean raider | 1.74 m | Photorealistic South Korean kabaddi raider, 25-year-old man, lean athletic build about 72 kg, light skin, straight short black hair, clean-shaven, |
| `player_09_allrounder_kenya` | Kenyan all-rounder | 1.82 m | Photorealistic Kenyan kabaddi all-rounder, 26-year-old man, long lean muscular build about 82 kg, deep dark-brown skin, shaved head, clean-shaven, |
| `player_10_raider_japan` | Japanese raider | 1.73 m | Photorealistic Japanese kabaddi raider, 23-year-old man, compact athletic build about 70 kg, light skin, short spiky black hair, clean-shaven, |

**Image prompt** (step 1): the same text with *"Photorealistic"* replaced by *"Full-body studio photo, front view,
plain light-grey background:"*. Both versions are written out in full at the end.

These cover the body types (lean, athletic, stocky, tall and heavy, small and quick) and the countries in the
game: India in several regions, Bangladesh, Iran, Korea, Kenya and Japan. Nepal, Sri Lanka and Thailand use the
nearest faces with a skin-tone shift. Argentina and Poland can be added with two more lines in the same style.

### Jersey designs (optional, after the players)

Use **Retexture** on a finished player, with **Keep original UVs** on, to make other jersey designs on the same
body. The game paints blue as the team's main colour and red as its second colour, so keep to blue and red:

- *Hooped kabaddi jersey: horizontal royal blue and red hoops, flat solid colours, no logos, no text, no numbers.*
- *Kabaddi jersey with a red diagonal sash across a royal blue body, flat solid colours, no logos, no text.*
- *Sleeveless kabaddi vest version: royal blue with red edging at the arm holes and collar, no logos, no text.*

## Pads and wraps (separate pieces)

Make each as its own small model, so the game can put them on any player and paint them. Settings: Realistic,
**2,000 faces**, texture on, no rigging. The game fits them to each player's knee, ankle or wrist and moves them with
the bone.

| File | Prompt |
|---|---|
| `gear_knee_pad` | A single sports knee pad on its own, a short open tube of black neoprene with a red padded front patch, realistic product model, front view, no logo, no text. |
| `gear_ankle_support` | A single elastic ankle support sleeve on its own, open at the toes and heel, royal blue fabric, realistic product model, no logo, no text. |
| `gear_wrist_tape` | A short tube of white athletic tape wrapped around a wrist, on its own with no hand, realistic product model, no logo. |
| `gear_thigh_sleeve` | A single black compression thigh sleeve on its own, a tapered open tube, matte fabric, realistic product model, no logo, no text. |
| `gear_headband` | A plain red elastic sports headband on its own, a thin ring of fabric, realistic product model, no logo, no text. |

## Referees

Height for rigging as given. **Texture prompt:** *Photorealistic skin and hair, crisp white cotton polo shirt, matte
black trousers, polished black shoes, no logos, no text, no badges, even studio lighting, no baked shadows.*

| File | Height | 3D prompt |
|---|---|---|
| `referee_01_man` | 1.75 m | Photorealistic kabaddi match referee, 45-year-old Indian man, average fit build, medium-brown skin, short neat black hair greying at the temples, trimmed moustache, plain white short-sleeve collared polo shirt tucked into black trousers, black belt, black sports shoes, silver whistle on a black cord around the neck, no logos, no text. Full body A-pose, open hands, neutral face, mouth closed. |
| `referee_02_woman` | 1.65 m | Photorealistic kabaddi match referee, 38-year-old Indian woman, fit build, medium-brown skin, black hair tied in a low bun, plain white short-sleeve collared polo shirt tucked into black trousers, black belt, black sports shoes, silver whistle on a black cord, no logos, no text. Full body A-pose, open hands, neutral face, mouth closed. |
| `referee_03_senior` | 1.72 m | Photorealistic senior kabaddi umpire, 55-year-old Indian man, slightly heavy build, light-brown skin, short grey hair, grey moustache, thin glasses, plain white short-sleeve collared polo shirt tucked into black trousers, black sports shoes, whistle on a black cord, no logos, no text. Full body A-pose, open hands, neutral face, mouth closed. |

## Crowd

The crowd is far too many people to animate on a phone one by one, so the game renders each of these people
beforehand, sitting and cheering from a few angles, and the stands show those pictures: thousands of real-looking
people for the cost of one. They can be detailed (30,000 faces). Rig each one and add the animations **Sitting
Idle**, **Sitting Clapping**, **Cheering** and **Fist Pump** if Meshy has them; otherwise **Idle** and **Cheering**.

Common ending: *…Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth
closed, no logos, no text.* **Texture prompt:** *Photorealistic skin, hair and everyday fabrics, even studio
lighting, no baked shadows, no logos, no text.*

| File | Height | Prompt start |
|---|---|---|
| `crowd_01_man_tshirt` | 1.72 m | Photorealistic Indian man in his 30s, medium-brown skin, short black hair, plain mustard-yellow t-shirt, blue jeans, sandals, |
| `crowd_02_man_fan_jersey` | 1.75 m | Photorealistic young Indian man, kabaddi fan, light-brown skin, plain royal blue fan jersey with red trim, black track pants, sneakers, plain red cap, |
| `crowd_03_sikh_man` | 1.80 m | Photorealistic Sikh man in his 40s, navy blue turban, full black beard, light-brown skin, plain white kurta, grey trousers, sandals, |
| `crowd_04_old_man` | 1.68 m | Photorealistic elderly Indian man about 70, thin build, dark-brown skin, short white hair, white moustache, round glasses, plain white kurta pyjama, brown sandals, |
| `crowd_05_woman_salwar` | 1.60 m | Photorealistic young Indian woman in her 20s, medium-brown skin, long black hair in a braid, plain teal salwar kameez with a cream dupatta, flat sandals, |
| `crowd_06_woman_saree` | 1.58 m | Photorealistic Indian woman in her 40s, dark-brown skin, black hair in a bun, maroon cotton saree with a gold border, flat sandals, |
| `crowd_07_woman_jeans` | 1.63 m | Photorealistic young Indian woman, college student, light-brown skin, black hair in a ponytail, plain white t-shirt, blue jeans, white sneakers, |
| `crowd_08_old_woman` | 1.55 m | Photorealistic elderly Indian woman about 65, medium-brown skin, grey hair in a bun, plain light-blue cotton saree, flat sandals, |
| `crowd_09_boy` | 1.35 m | Photorealistic Indian boy about 10 years old, medium-brown skin, short black hair, plain orange t-shirt, navy shorts, sneakers, |
| `crowd_10_girl` | 1.25 m | Photorealistic Indian girl about 8 years old, light-brown skin, black hair in two braids, plain pink cotton dress, sandals, |
| `crowd_11_teen_facepaint` | 1.65 m | Photorealistic Indian teenage boy, medium-brown skin, short black hair, saffron white and green stripes painted on both cheeks, plain white t-shirt, jeans, sneakers, |
| `crowd_12_man_hoodie` | 1.78 m | Photorealistic young Indian man, light-brown skin, short styled black hair, plain grey hoodie, black joggers, white sneakers, |
| `crowd_13_man_office` | 1.70 m | Photorealistic Indian man in his 50s, slightly heavy build, medium-brown skin, balding with short grey hair, thick moustache, plain light-blue shirt, dark trousers, black shoes, |
| `crowd_14_woman_hijab` | 1.62 m | Photorealistic young woman, light-brown skin, plain black hijab, plain olive-green long tunic, black trousers, flat shoes, |
| `crowd_15_woman_fan` | 1.60 m | Photorealistic young Indian woman, kabaddi fan, dark-brown skin, black hair in a ponytail, plain royal blue fan jersey with red trim, black leggings, sneakers, |
| `crowd_16_man_kurta_jacket` | 1.74 m | Photorealistic Indian man in his 60s, light-brown skin, short white hair, white beard, plain white kurta under a brown sleeveless jacket, sandals, |

The two fans in blue and red jerseys can be painted in each home team's colours.

## Faces that move

Meshy faces are one painted surface, so the game adds the movement:

- **Jaw:** a jaw bone added to each head, opening the mouth for the chant, shouts and celebrations, with a dark
  mouth inside so an open mouth doesn't look hollow.
- **Blinks:** a short eyelid close, painted from the skin around the eye.
- **Head and gaze:** the head already turns to follow the raider.

A mouth closed in a relaxed line and eyes looking straight ahead make this work best; that's why every prompt asks
for them. Full facial animation (dozens of expression shapes, as in console games) needs a dedicated character tool
such as Character Creator, and would be hard to see from the match camera on a phone anyway.

## Phone budget (Galaxy A16)

- 14 players and 3 referees on court: about 10,000 faces each, about 170,000 in all. Players far from the camera
  switch to a 3,000-face version (Remesh in Meshy, or made by the game's tools).
- One material and one 1024 px texture per person on the phone; the kit map is a second, small texture.
- The crowd costs almost nothing: pictures on flat cards, a few hundred draw calls at most.

## Hand-over

Put the downloads in a folder named `meshy/` with the file names above (`.glb`; FBX not needed), zip it, and attach
it here, or add `api.meshy.ai` and `assets.meshy.ai` to the cloud environment's allowed domains and a Meshy API key
as an environment secret named `MESHY_API_KEY`, and a new session can run this whole list itself:

```sh
python3 tools/meshy/meshy_batch.py --dry-run                            # what would be sent
python3 tools/meshy/meshy_batch.py --only player_01_raider_haryana      # one test player first
python3 tools/meshy/meshy_batch.py --kind player                        # then each group
```

`tools/meshy/assets.json` holds the same prompts as this page. The script was written from Meshy's API documentation
before any live call could be made, so the first run is the test: if Meshy rejects a field (HTTP 400), the script
stops and prints Meshy's message.

For each model the game's tools then: turn and check it (`tools/rig/prepare.py`), map Meshy's rig onto the game's
skeleton (or rig it with `tools/rig/autorig.py`), make the kit map (`tools/rig/kit_texture.py`), add the face bones,
make the far version, and, for the crowd, render the cheering pictures.

## Full prompts to paste

Generated from the tables above. For each: the picture prompt (Text to Image), then the 3D prompt (Text to 3D,
or as the description on Image to 3D).

### Players

**player_01_raider_haryana** (rig height 1.76 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: Indian kabaddi raider, 24-year-old man from Haryana, lean wiry athletic build, long limbs, defined calves, wheatish light-brown skin, short black hair faded at the sides, light stubble, sharp jaw, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

3D:

```text
Photorealistic Indian kabaddi raider, 24-year-old man from Haryana, lean wiry athletic build, long limbs, defined calves, wheatish light-brown skin, short black hair faded at the sides, light stubble, sharp jaw, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

**player_02_allrounder_maharashtra** (rig height 1.80 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: Indian kabaddi all-rounder, 27-year-old man from Maharashtra, athletic muscular build, broad chest, medium-brown skin, short wavy black hair, clean-shaven, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

3D:

```text
Photorealistic Indian kabaddi all-rounder, 27-year-old man from Maharashtra, athletic muscular build, broad chest, medium-brown skin, short wavy black hair, clean-shaven, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

**player_03_corner_haryana** (rig height 1.78 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: Indian kabaddi corner defender, 29-year-old man from Haryana, stocky powerful build about 92 kg, thick neck, very strong thighs, light-brown skin, black buzz cut, thick black moustache, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

3D:

```text
Photorealistic Indian kabaddi corner defender, 29-year-old man from Haryana, stocky powerful build about 92 kg, thick neck, very strong thighs, light-brown skin, black buzz cut, thick black moustache, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

**player_04_cover_tamil** (rig height 1.85 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: Indian kabaddi cover defender, 26-year-old man from Tamil Nadu, tall heavy muscular build about 95 kg, dark-brown skin, short tight curly black hair, short trimmed beard, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

3D:

```text
Photorealistic Indian kabaddi cover defender, 26-year-old man from Tamil Nadu, tall heavy muscular build about 95 kg, dark-brown skin, short tight curly black hair, short trimmed beard, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

**player_05_veteran_punjab** (rig height 1.79 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: Indian kabaddi team captain, 34-year-old man from Punjab, solid muscular build about 88 kg, medium-brown skin, short salt-and-pepper hair, short salt-and-pepper beard, calm face, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

3D:

```text
Photorealistic Indian kabaddi team captain, 34-year-old man from Punjab, solid muscular build about 88 kg, medium-brown skin, short salt-and-pepper hair, short salt-and-pepper beard, calm face, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

**player_06_raider_bengal** (rig height 1.72 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: kabaddi raider from Bangladesh, 22-year-old man, small light quick build about 68 kg, medium-brown skin, short side-parted black hair, thin black moustache, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

3D:

```text
Photorealistic kabaddi raider from Bangladesh, 22-year-old man, small light quick build about 68 kg, medium-brown skin, short side-parted black hair, thin black moustache, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

**player_07_defender_iran** (rig height 1.83 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: Iranian kabaddi defender, 28-year-old man, powerful muscular build about 90 kg, light olive skin, short dark-brown hair, full short dark beard, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

3D:

```text
Photorealistic Iranian kabaddi defender, 28-year-old man, powerful muscular build about 90 kg, light olive skin, short dark-brown hair, full short dark beard, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

**player_08_raider_korea** (rig height 1.74 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: South Korean kabaddi raider, 25-year-old man, lean athletic build about 72 kg, light skin, straight short black hair, clean-shaven, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

3D:

```text
Photorealistic South Korean kabaddi raider, 25-year-old man, lean athletic build about 72 kg, light skin, straight short black hair, clean-shaven, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

**player_09_allrounder_kenya** (rig height 1.82 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: Kenyan kabaddi all-rounder, 26-year-old man, long lean muscular build about 82 kg, deep dark-brown skin, shaved head, clean-shaven, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

3D:

```text
Photorealistic Kenyan kabaddi all-rounder, 26-year-old man, long lean muscular build about 82 kg, deep dark-brown skin, shaved head, clean-shaven, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

**player_10_raider_japan** (rig height 1.73 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: Japanese kabaddi raider, 23-year-old man, compact athletic build about 70 kg, light skin, short spiky black hair, clean-shaven, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

3D:

```text
Photorealistic Japanese kabaddi raider, 23-year-old man, compact athletic build about 70 kg, light skin, short spiky black hair, clean-shaven, wearing a tight short-sleeve kabaddi jersey and tight shorts, flat solid royal blue with flat solid red collar, shoulder panels and side stripes, no logos, no text, no numbers, barefoot. Full body, A-pose, arms 45 degrees from the body, open hands, feet flat shoulder-width apart, neutral face, mouth closed, eyes forward.
```

### Pads and wraps

**gear_knee_pad**

```text
A single sports knee pad on its own, a short open tube of black neoprene with a red padded front patch, realistic product model, front view, no logo, no text.
```

**gear_ankle_support**

```text
A single elastic ankle support sleeve on its own, open at the toes and heel, royal blue fabric, realistic product model, no logo, no text.
```

**gear_wrist_tape**

```text
A short tube of white athletic tape wrapped around a wrist, on its own with no hand, realistic product model, no logo.
```

**gear_thigh_sleeve**

```text
A single black compression thigh sleeve on its own, a tapered open tube, matte fabric, realistic product model, no logo, no text.
```

**gear_headband**

```text
A plain red elastic sports headband on its own, a thin ring of fabric, realistic product model, no logo, no text.
```

### Referees

**referee_01_man** (rig height 1.75 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: kabaddi match referee, 45-year-old Indian man, average fit build, medium-brown skin, short neat black hair greying at the temples, trimmed moustache, plain white short-sleeve collared polo shirt tucked into black trousers, black belt, black sports shoes, silver whistle on a black cord around the neck, no logos, no text. Full body A-pose, open hands, neutral face, mouth closed.
```

3D:

```text
Photorealistic kabaddi match referee, 45-year-old Indian man, average fit build, medium-brown skin, short neat black hair greying at the temples, trimmed moustache, plain white short-sleeve collared polo shirt tucked into black trousers, black belt, black sports shoes, silver whistle on a black cord around the neck, no logos, no text. Full body A-pose, open hands, neutral face, mouth closed.
```

**referee_02_woman** (rig height 1.65 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: kabaddi match referee, 38-year-old Indian woman, fit build, medium-brown skin, black hair tied in a low bun, plain white short-sleeve collared polo shirt tucked into black trousers, black belt, black sports shoes, silver whistle on a black cord, no logos, no text. Full body A-pose, open hands, neutral face, mouth closed.
```

3D:

```text
Photorealistic kabaddi match referee, 38-year-old Indian woman, fit build, medium-brown skin, black hair tied in a low bun, plain white short-sleeve collared polo shirt tucked into black trousers, black belt, black sports shoes, silver whistle on a black cord, no logos, no text. Full body A-pose, open hands, neutral face, mouth closed.
```

**referee_03_senior** (rig height 1.72 m)

Picture:

```text
Full-body studio photo, front view, plain light-grey background: senior kabaddi umpire, 55-year-old Indian man, slightly heavy build, light-brown skin, short grey hair, grey moustache, thin glasses, plain white short-sleeve collared polo shirt tucked into black trousers, black sports shoes, whistle on a black cord, no logos, no text. Full body A-pose, open hands, neutral face, mouth closed.
```

3D:

```text
Photorealistic senior kabaddi umpire, 55-year-old Indian man, slightly heavy build, light-brown skin, short grey hair, grey moustache, thin glasses, plain white short-sleeve collared polo shirt tucked into black trousers, black sports shoes, whistle on a black cord, no logos, no text. Full body A-pose, open hands, neutral face, mouth closed.
```

### Crowd

**crowd_01_man_tshirt** (rig height 1.72 m)

```text
Photorealistic Indian man in his 30s, medium-brown skin, short black hair, plain mustard-yellow t-shirt, blue jeans, sandals, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_02_man_fan_jersey** (rig height 1.75 m)

```text
Photorealistic young Indian man, kabaddi fan, light-brown skin, plain royal blue fan jersey with red trim, black track pants, sneakers, plain red cap, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_03_sikh_man** (rig height 1.80 m)

```text
Photorealistic Sikh man in his 40s, navy blue turban, full black beard, light-brown skin, plain white kurta, grey trousers, sandals, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_04_old_man** (rig height 1.68 m)

```text
Photorealistic elderly Indian man about 70, thin build, dark-brown skin, short white hair, white moustache, round glasses, plain white kurta pyjama, brown sandals, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_05_woman_salwar** (rig height 1.60 m)

```text
Photorealistic young Indian woman in her 20s, medium-brown skin, long black hair in a braid, plain teal salwar kameez with a cream dupatta, flat sandals, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_06_woman_saree** (rig height 1.58 m)

```text
Photorealistic Indian woman in her 40s, dark-brown skin, black hair in a bun, maroon cotton saree with a gold border, flat sandals, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_07_woman_jeans** (rig height 1.63 m)

```text
Photorealistic young Indian woman, college student, light-brown skin, black hair in a ponytail, plain white t-shirt, blue jeans, white sneakers, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_08_old_woman** (rig height 1.55 m)

```text
Photorealistic elderly Indian woman about 65, medium-brown skin, grey hair in a bun, plain light-blue cotton saree, flat sandals, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_09_boy** (rig height 1.35 m)

```text
Photorealistic Indian boy about 10 years old, medium-brown skin, short black hair, plain orange t-shirt, navy shorts, sneakers, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_10_girl** (rig height 1.25 m)

```text
Photorealistic Indian girl about 8 years old, light-brown skin, black hair in two braids, plain pink cotton dress, sandals, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_11_teen_facepaint** (rig height 1.65 m)

```text
Photorealistic Indian teenage boy, medium-brown skin, short black hair, saffron white and green stripes painted on both cheeks, plain white t-shirt, jeans, sneakers, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_12_man_hoodie** (rig height 1.78 m)

```text
Photorealistic young Indian man, light-brown skin, short styled black hair, plain grey hoodie, black joggers, white sneakers, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_13_man_office** (rig height 1.70 m)

```text
Photorealistic Indian man in his 50s, slightly heavy build, medium-brown skin, balding with short grey hair, thick moustache, plain light-blue shirt, dark trousers, black shoes, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_14_woman_hijab** (rig height 1.62 m)

```text
Photorealistic young woman, light-brown skin, plain black hijab, plain olive-green long tunic, black trousers, flat shoes, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_15_woman_fan** (rig height 1.60 m)

```text
Photorealistic young Indian woman, kabaddi fan, dark-brown skin, black hair in a ponytail, plain royal blue fan jersey with red trim, black leggings, sneakers, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```

**crowd_16_man_kurta_jacket** (rig height 1.74 m)

```text
Photorealistic Indian man in his 60s, light-brown skin, short white hair, white beard, plain white kurta under a brown sleeveless jacket, sandals, Full body, A-pose, arms 45 degrees from the body, open hands, feet flat, neutral face, mouth closed, no logos, no text.
```
