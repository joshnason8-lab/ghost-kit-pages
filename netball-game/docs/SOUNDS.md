# Sounds

Every sound file in `assets/audio/`, where it came from and under what licence. All are mono Ogg Vorbis, 22 kHz,
made from the downloads by `tools/audio/make_sounds.py` (the whistles are the owner's recordings, prepared on the
shared-assets branch; they play from the umpire who blows, a take at random, quietly in the home screen's match) (trimmed, layered, levelled to an even loudness, the
ambience cross-faded into seamless loops). The menu music is made by `tools/audio/make_music.py`. A few sounds are
still synthesised at startup by `autoload/sfx.gd` (see the end). The same credits are on the Licences screen
(`ui/licences_screen.gd`). `tests/test_runner.gd` checks every file here is named in this page and loads.

| File | What | Source | Author | Licence |
|---|---|---|---|---|
| `whistle_short_1.ogg`, `whistle_long_1.ogg`, `whistle_double.ogg`, `whistle_final.ogg` | the umpire's pea whistle, recorded: a short pip (an infringement, a restart), a long blast (the centre pass after a goal, the end of a quarter), two pips (an injury, a time-out), the final whistle (short, short, long) | "Referee whistle", Pixabay 568615 (supplied by the owner; trimmed, faded, levelled on the shared-assets branch, `shared-assets/sounds/whistle/`) | charlesheffley009 | Pixabay Content License |
| `whistle_short_2.ogg`, `whistle_long_2.ogg` | more takes of the pip and the blast | "Referee whistle / coach whistle / sports whistle", Pixabay 291816 | framptones | Pixabay Content License |
| `whistle_short_3.ogg`, `whistle_long_3.ogg` | more takes of the pip and the blast | "Metal whistle", Pixabay 6121 | freesound_community | Pixabay Content License |
| `whistle_gym.ogg` | the long blast in a sports hall, its echo recorded with it | "Referee whistle blow, gymnasium", Pixabay 6320 | freesound_community | Pixabay Content License |
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

The Pixabay Content License allows use in a game without attribution (not redistributing the sounds unmodified on
their own); they are credited here and on the Licences screen all the same.

The CC-BY-SA 4.0 sounds are adapted (cut, filtered, mixed, looped); the adapted files are under CC-BY-SA 4.0 too.

## Medium and High: longer beds, more takes (`assets/audio/hd/`)

On Medium and High the game plays richer versions, made by `tools/audio/make_sounds_hd.py` as stereo Ogg Vorbis at
44.1 kHz: each venue's bed as a long loop (65 s, 46 s and 2 minutes, where Low's repeat every 16-17 s), and more
takes of each crowd reaction, one picked at random each time (Low's own take among them). Each is set to the
loudness of the Low sound it stands beside. Low plays only the set above, as before.

| File | What | Source | Author | Licence |
|---|---|---|---|---|
| `hd/amb_arena_long.ogg` | the arena's crowd, 65 s loop: three stretches between cheers, evened out | "Free Crowd Cheering Sounds" (10, Ambience; 11, Full recording at 20-38 s and 150-179 s), https://opengameart.org/content/free-crowd-cheering-sounds | Gregor Quendel | CC-BY 4.0 |
| `hd/amb_hall_long.ogg` | a sports hall's small crowd, 46 s loop, a wide hall's echo | "Free General Ambience Sounds" (Crowd - School excursion), https://opengameart.org/content/free-general-ambience-sounds; filtered, reverb added | Gregor Quendel | CC-BY-SA 4.0 |
| `hd/amb_outdoor_long.ogg` | a park court, 2-minute loop: birds, distant traffic and a plane, a few people | "Free General Ambience Sounds" (City ambience - Park - Spring - with birds, cars and planes, 98-222 s; Crowd - School excursion, distant), https://opengameart.org/content/free-general-ambience-sounds | Gregor Quendel | CC-BY-SA 4.0 |
| `hd/crowd_cheer_2..5.ogg` | four more big cheers (the arena) | "Free Crowd Cheering Sounds" (03, Strong cheering I; 02, Strong cheering and soft rhythmic cheering; 11, Full recording at 64 s and 108 s), https://opengameart.org/content/free-crowd-cheering-sounds | Gregor Quendel | CC-BY 4.0 |
| `hd/crowd_cheer_small_2..4.ogg` | three more smaller cheers (hall, park) | "Free Crowd Cheering Sounds" (05, Soft cheering I; 07, Soft cheering and chatter at 8 s and 18 s), https://opengameart.org/content/free-crowd-cheering-sounds | Gregor Quendel | CC-BY 4.0 |
| `hd/applause_2..3.ogg` | more of the arena's applause | "Free General Ambience Sounds" (Crowd - Applause - Clapping, at 12 s and 25 s), https://opengameart.org/content/free-general-ambience-sounds | Gregor Quendel | CC-BY-SA 4.0 |
| `hd/applause_4.ogg` | another crowd's applause (the arena) | "Applause", https://opengameart.org/content/applause; cut from the end of Yo Frankie! (Blender Foundation) | leezh (from Yo Frankie!, Blender Foundation) | CC-BY 3.0 |
| `hd/applause_hall_2..3.ogg` | more applause in a hall | "Applause in a large hall or church" (at 12 s and 24 s), https://opengameart.org/content/applause-in-a-large-hall-or-church | eXpl0it3r | CC0 |
| `hd/crowd_ooh_2..3.ogg`, `hd/crowd_groan_2..3.ogg` | the crowd's "ooh" and groan re-voiced as other crowds (pitched apart, layered across the stand) | made from `crowd_ooh.ogg` and `crowd_groan.ogg` (Kabaddi Raid) by `tools/audio/make_sounds_hd.py` | Josh Nason | the game's own |

The adapted CC-BY-SA 4.0 sounds here are under CC-BY-SA 4.0 too.

## Synthesised at startup (`autoload/sfx.gd`)

`pass` (the ball pushed away on a pass), `buzzer`, `roar`, `crowd_loop` (a stand-in bed if an `amb_*.ogg` is
missing), and the fallbacks for the ring, net and click when their files are missing.

## Not found (to source by hand)

- A recorded netball (or basketball) bounce on a sprung timber floor and on asphalt, and a recorded catch (the
  bounces and catches are layered from Kenney's generic impacts).
- A ball through a cord net (the swish is a cloth rustle).
- Shoe squeaks on a sports floor (synthesised).
- A crowd's groan and "ooh" from a netball crowd (the Kabaddi Raid ones are kept).
