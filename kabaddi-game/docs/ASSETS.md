# Replacing the placeholders with real-looking humans

The athletes you see today are built in code from smooth primitives (`game/human_model.gd`) and animated by
code: run cycle, defensive crouch, raider stance, hand touch, toe touch, dive, struggle, fall and celebrate.
They exist so the game is playable now. Realistic players come from a **rigged character model plus motion
capture**, and the code already has a slot for both.

## Drop-in slot

If any of these files exists, every athlete uses it instead of the placeholder body:

```
assets/characters/athlete.tscn   (preferred: a scene wrapping your model)
assets/characters/athlete.glb
assets/characters/athlete.gltf
```

The model must:

- **Face -Z, stand on the origin, be in metres, and be about 1.8 m tall.**
- **Contain an `AnimationPlayer`** with these clips. Rename them in `assets/characters/animations.json` if yours
  differ:

  | Pose state | Default clip name | What it is |
  |---|---|---|
  | idle | `idle` | Standing, breathing |
  | run | `run` | Running. Playback speed follows ground speed. |
  | crouch | `defend_idle` | Defender's low ready stance, hands forward |
  | raid | `raid_idle` | Raider's bent-forward stance |
  | reach | `hand_touch` | Quick one-arm lunge to tag |
  | kick | `toe_touch` | Leg stretched along the mat to tag a foot (also used for back and side kicks) |
  | dubki | `dubki` | Ducking low under the defenders' linked hands |
  | jump | `lion_jump` | Leaping over a defender diving at the ankles |
  | dive | `tackle_dive` | Defender dives for the ankle or thigh |
  | hold | `hold` | Defender clinging on |
  | struggle | `struggle` | Raider dragging defenders toward the midline |
  | fallen | `fallen` | Lying on the mat after a tackle |
  | celebrate | `celebrate` | Arms up |

  Example `animations.json`:

  ```json
  { "run": "Running_Loop", "crouch": "Defend_Stance", "dive": "Ankle_Tackle" }
  ```

- **Name its materials** so kits can be recoloured per team. Any material whose name contains `jersey` or `shirt`
  gets the team colour, `short` gets the shorts colour, `skin` or `body` gets the player's skin tone, and `hair`
  gets the hair colour. Use a white or light-grey base colour on those materials so the tint reads true.

Shirt numbers on the placeholder are a `Label3D` on the back. For a custom model, add a decal or a number
texture. A good follow-up task is a small number atlas.

## Where to get realistic humans

These are listed from fastest to most bespoke.

| Option | Cost | Notes |
|---|---|---|
| **MakeHuman / MPFB2 (Blender)** | Free, CC0 output | Make lean, athletic Indian body types and skin tones. Export glTF. Add motion with Mixamo or your own capture. |
| **Mixamo** (Adobe) | Free with an Adobe account | Auto-rigging plus a big motion library (run, crouch, dive, fall, celebrate). No kabaddi-specific moves. |
| **Reallusion Character Creator + ActorCore** | Paid | The most realistic option at mobile budgets. Includes LOD and mobile export tools. |
| **Commissioned artist** | Varies | For signature looks: PRL kits, specific body types, faces. |

**Kabaddi-specific moves** don't exist in stock libraries: ankle hold, thigh hold, chain tackle, toe touch,
running hand touch, dubki (ducking under a chain), frog jump and scorpion kick. They need capture:

- **Video-to-mocap** (Move.ai, DeepMotion, Rokoko Video). Film local kabaddi players with phones and convert. This
  is cheap and fast, and the data needs cleanup.
- **A suit** (Rokoko, Xsens) for a day at an akhada. This gives the best quality per rupee spent.

## Mobile budgets (aim for these)

- **Per athlete.** 8–15k triangles at LOD0, 3–5k at LOD1, one skinned mesh with 1–3 materials. Textures at
  1024² (jersey, body), ETC2/ASTC compressed (already enabled in `project.godot`).
- **On screen.** 14 athletes plus a crowd. The crowd is already a single instanced mesh (`arena.gd`), so it costs
  one draw call.
- **Today's placeholder** uses about 40 small meshes per athlete. It's fine on mid-range phones. A real skinned
  model will be **cheaper** to draw.

## Audio

Every sound is synthesised in `autoload/sfx.gd` so the game ships with no audio files. Put a file with the same
name in `assets/audio/` (`.ogg`, `.wav` or `.mp3`) to override one:

`whistle`, `buzzer`, `thud`, `slap`, `whoosh`, `click`, `gavel`, `roar`, `crowd_loop`, `dhol_loop`, `bid`

High-value recordings:

- A real crowd at a PKL-style venue.
- A dhol player.
- **Commentary and chants in each supported language.** Regional commentary would be a real differentiator.

## Grounds

Grounds are built in code in `game/arena.gd`. Each one is a function (`_build_dome`, `_build_village`, ...) that
sets the sky, lights and fog, lays the court surface and lines, and places props, stands and the crowd. To use a
modelled stadium, add the `.glb` under `assets/grounds/`, instance it in that ground's function, and keep the
court itself from `_court()` so the line positions stay exact.
