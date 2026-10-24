# Replacing the placeholders with real-looking humans

The athletes you see today are built in code from smooth primitives (`game/human_model.gd`) and animated by
code: run cycle, defensive crouch, raider stance, hand touch, toe touch, dive, struggle, fall and celebrate.
They exist so the game is playable now. Realistic players come from a **rigged character model plus motion
capture**, and the code already has a slot for both.

## Generated models (what the game uses now)

`assets/characters/bodies/` holds eight generated bodies made with Meshy (see
[MESHY_BRIEF.md](MESHY_BRIEF.md)): six players of different builds, skin tones and faces (Haryana raider
and corner, Tamil cover, Iranian defender, Korean raider, Kenyan all-rounder) and two referees, a man and a
woman. Each is about 15,000 triangles with a 1024 px texture, auto-rigged by `tools/rig` with two finger
bones a hand, and packed (`.krb`). `game/rigged_body.gd` builds each as a skinned mesh and turns its bones
to follow the code-built skeleton every frame, so it needs no animation clips. Every player gets the body
nearest his skin tone and build (`bodies.json`), officials the referees'.

A ninth, `player_10`, is a player made in Meshy's web app from a picture (Image to 3D, Meshy-6): a sharper face,
knee pads and ankle supports, 10,415 triangles, and 4096 px colour, normal, roughness and glow maps, of which the
game uses the colour at 1024 px like the others. It was rigged with `make_body.py --plain-kit`, which also paints
out the light graphics a real kit's picture is full of; its red stripes take each team's trim colour. It is marked
`"featured"` in `bodies.json`, so each side's first raider wears it in every Quick Match, to compare it with the
others (other matches and the tests, which ask for no featured body, are as before); take the mark off and it is
picked by skin tone and build like the rest.

A tenth, `player_11`, is a second player from the web app, rigged there for Mixamo with walk and run clips: a
sleeveless vest and shorts in royal blue with orange trim, barefoot, 206,920 triangles and a 4096 px colour map.
The game uses neither the skeleton nor the clips (it rigs the body to its own); `tools/rig/slim.py` kept the mesh
in its bind pose and brought it down to 15,000 triangles, keeping its texture coordinates, and `make_body.py
--plain-kit --trim-hue 21` rigged it, its orange trim taking each team's trim colour and the number on its back
painted out. It is `"featured"` too, so each side's second player wears it in Quick Match, and `"pick": false`:
no one else is given it (it would be the nearest body for a fifth of all players, and change every seeded match).

Each body's texture (`NAME_albedo.webp`) gives the face, skin, knee and ankle supports and the kit's folds.
The kit map (`NAME_kit.webp`) marks the kit's main colour and trim, so each team's colours replace the
model's own; logos and numbers were painted out, and the shirt number is added by the game. Skin is tinted
to each player's tone; referees keep their own outfits. To add a body, run `tools/rig/make_body.py` (see
[tools/rig/README.md](../tools/rig/README.md)).

The crowd is eight generated people (men, women, an older man, a Sikh man, children) rendered into a
sprite sheet in eight poses (sitting, clapping, standing, arms up), from the front and (since 0.9.1) from behind,
by `tools/crowd/render_crowd.gd` (`assets/crowd/`). The stands draw each spectator as one camera-facing card,
facing the court: a camera behind them, as over the stand it looks over, sees their back. Fans in shirts wear the
teams' colours, and the crowd claps and stands with the match's excitement.

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
| **CMU Graphics Lab Motion Capture Database** ([mocap.cs.cmu.edu](http://mocap.cs.cmu.edu)) | Free, credit asked | About 2,600 takes of real people (walks, runs, sports, martial arts, two-person scenes), as BVH through its conversions. Free in a product that is sold; the data may not be resold by itself, even converted. No kabaddi moves. The game's crouched walks come from it (see `tools/mocap/README.md`, which reads BVH, and the licences screen's credit). |
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

## Icon and menu art

The app icon is a painted raider reaching past a defender who has him by the thigh, and the home screen's tiles
each have a flat figure in the tile's colour (a yellow raider, a green chain, a blue celebration, a purple
lunge). The originals are in `tools/ui_art/src/` (not imported by Godot); `tools/ui_art/import_art.py` frames
the icon for Android's adaptive icons (`assets/icon/`) and crops and scales the figures (`assets/ui/art_*.png`).

## Audio

Every effect is synthesised in `autoload/sfx.gd` or made by the scripts in `tools/audio/`. Put a file with the same
name in `assets/audio/` (`.ogg`, `.wav` or `.mp3`) to override one:

`whistle`, `buzzer`, `thud`, `slap`, `whoosh`, `click`, `gavel`, `roar`, `crowd_loop`, `dhol_loop`, `bid`

The menus' music, `assets/audio/menu_music.ogg`, is **"Indian" by LNPLUSMUSIC** (Pixabay, track 611803), under the
[Pixabay Content License](https://pixabay.com/service/license-summary/): free to use in an app, edited, with no
credit required (credited here anyway). The licence does not allow passing the track on by itself, so only the
edited loop made from it by `tools/audio/make_menu_music.py` is in the repository, not the download.

High-value recordings:

- A real crowd at a PKL-style venue.
- A dhol player.
- **Commentary and chants in each supported language.** Regional commentary would be a real differentiator.

## Grounds

Grounds are built in code in `game/arena.gd`. Each one is a function (`_build_dome`, `_build_village`, ...) that
sets the sky, lights and fog, lays the court surface and lines, and places props, stands and the crowd. To use a
modelled stadium, add the `.glb` under `assets/grounds/`, instance it in that ground's function, and keep the
court itself from `_court()` so the line positions stay exact.
