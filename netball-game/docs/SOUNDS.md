# Sounds

Every sound file in `assets/audio/`, where it came from and under what licence. All are mono Ogg Vorbis, 22 kHz,
made from the downloads by `tools/audio/make_sounds.py` (trimmed, layered, levelled to an even loudness, the
ambience cross-faded into seamless loops). The menu music is made by `tools/audio/make_music.py`. A few sounds are
still synthesised at startup by `autoload/sfx.gd` (see the end). The same credits are on the Licences screen
(`ui/licences_screen.gd`). `tests/test_runner.gd` checks every file here is named in this page and loads.

| File | What | Source | Author | Licence |
|---|---|---|---|---|
| `whistle.ogg`, `whistle_long.ogg` | the umpire's pea whistle: a call; a goal or the end of a quarter | made for the game (`tools/audio/make_sounds.py`) | Josh Nason | the game's own |
| `squeak_1..3.ogg` | a shoe squeaking on a sprung floor on a hard cut (indoors) | made for the game (`tools/audio/make_sounds.py`) | Josh Nason | the game's own |
| `catch_1..3.ogg` | the ball into two hands | Impact Sounds (`impactPunch_medium_000..002`), https://kenney.nl/assets/impact-sounds | Kenney (kenney.nl) | CC0 |
| `bounce_floor_1..2.ogg` | a bounce pass / loose ball on a sprung timber floor (hall, arena) | Impact Sounds (`impactSoft_heavy_000, 002` with `impactPunch_medium_000, 001`), https://kenney.nl/assets/impact-sounds; a room added | Kenney | CC0 |
| `bounce_court_1..2.ogg` | the same on outdoor asphalt | Impact Sounds (`impactSoft_medium_001, 003` with `impactPunch_medium`), https://kenney.nl/assets/impact-sounds | Kenney | CC0 |
| `rim.ogg` | the ball off the ring, the net shaken | Impact Sounds (`impactMetal_medium_000`, `impactSoft_medium_002`), https://kenney.nl/assets/impact-sounds; RPG Audio (`cloth3`), https://kenney.nl/assets/rpg-audio | Kenney | CC0 |
| `swish.ogg` | the ball through the net | RPG Audio (`cloth1`), https://kenney.nl/assets/rpg-audio | Kenney | CC0 |
| `click.ogg` | the buttons' click | UI Audio (`click2`), https://kenney.nl/assets/ui-audio | Kenney | CC0 |
| `step_court_1..4.ogg` | footsteps on asphalt (the park courts) | Impact Sounds (`footstep_concrete_000..003`), https://kenney.nl/assets/impact-sounds | Kenney | CC0 |
| `step_floor_1..4.ogg` | footsteps on a polished hall floor | "Footsteps on different surfaces" (`tile/0, 2, 4, 6`), https://opengameart.org/content/footsteps-on-different-surfaces; derived from "footstep-concrete.wav" by swuing (https://freesound.org/people/swuing/sounds/38873/) and "Squeaky footstep.wav" by ceberation (https://freesound.org/people/ceberation/sounds/235524/) | congusbongus; swuing; ceberation | CC-BY 3.0 |
| `crowd_cheer.ogg` | a big crowd's cheer for a goal (the arena) | "Free Crowd Cheering Sounds" (04, Strong cheering II), https://opengameart.org/content/free-crowd-cheering-sounds | Gregor Quendel | CC-BY 4.0 |
| `crowd_cheer_small.ogg` | a smaller crowd's cheer (hall, park) | "Free Crowd Cheering Sounds" (06, Soft cheering II), https://opengameart.org/content/free-crowd-cheering-sounds | Gregor Quendel | CC-BY 4.0 |
| `amb_arena.ogg` | the arena's crowd, a loop | "Free Crowd Cheering Sounds" (10, Ambience), https://opengameart.org/content/free-crowd-cheering-sounds | Gregor Quendel | CC-BY 4.0 |
| `applause.ogg` | applause, the arena (quarter time, full time) | "Free General Ambience Sounds" (Crowd - Applause - Clapping), https://opengameart.org/content/free-general-ambience-sounds | Gregor Quendel | CC-BY-SA 4.0 |
| `amb_hall.ogg` | a sports hall's small crowd, echoing, a loop | "Free General Ambience Sounds" (Crowd - School excursion), https://opengameart.org/content/free-general-ambience-sounds; filtered, a hall's reverb added | Gregor Quendel | CC-BY-SA 4.0 |
| `amb_outdoor.ogg` | a park court: birds, distant traffic, a few people, a loop | "Free General Ambience Sounds" (City ambience - Park - Spring - with birds, cars and planes; Crowd - School excursion, distant), https://opengameart.org/content/free-general-ambience-sounds | Gregor Quendel | CC-BY-SA 4.0 |
| `applause_hall.ogg` | applause in a hall | "Applause in a large hall or church", https://opengameart.org/content/applause-in-a-large-hall-or-church | eXpl0it3r | CC0 |
| `applause_small.ogg` | a few people clapping (the park) | "Well Done", https://opengameart.org/content/well-done | qubodup | CC0 |
| `crowd_ooh.ogg`, `crowd_groan.ogg`, `clap.ogg` | the crowd's "ooh" (an intercept), groan (a miss, a fumble); a clap | from Kabaddi Raid, by the same maker | Josh Nason | the game's own |
| `menu_music.ogg` | the menus' music | `tools/audio/make_music.py` | Josh Nason | the game's own |

The CC-BY-SA 4.0 sounds are adapted (cut, filtered, mixed, looped); the adapted files are under CC-BY-SA 4.0 too.

## Synthesised at startup (`autoload/sfx.gd`)

`pass` (the ball pushed away on a pass), `buzzer`, `roar`, `crowd_loop` (a stand-in bed if an `amb_*.ogg` is
missing), and the fallbacks for the whistle, ring, net and click when their files are missing.

## Not found (to source by hand)

- A recorded referee's pea whistle under a free licence (the whistle is synthesised).
- A recorded netball (or basketball) bounce on a sprung timber floor and on asphalt, and a recorded catch (the
  bounces and catches are layered from Kenney's generic impacts).
- A ball through a cord net (the swish is a cloth rustle).
- Shoe squeaks on a sports floor (synthesised).
- A crowd's groan and "ooh" from a netball crowd (the Kabaddi Raid ones are kept).
