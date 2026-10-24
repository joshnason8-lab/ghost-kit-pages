# The sounds

Every sound the game plays, where it comes from, who made it and under what licence. The recordings are made from
their sources by `tools/audio/make_sfx.py` (cut, mono at 22,050 Hz, set to a common loudness, loops crossfaded,
Ogg Vorbis); the sources themselves are not in the repository. `autoload/sfx.gd` plays them, and
`tests/test_runner.gd` (`_sounds`) checks every one is there and loads.

## Recordings (since 0.6)

| File (`assets/audio/`) | What, and where it plays | Source | Author | Licence |
|---|---|---|---|---|
| `slap_1.ogg`, `slap_2.ogg` | The kho: a palm on the seated chaser's back. | [Punch, slap, n' kick](https://opengameart.org/content/punch-slap-n-kick) (`hits/3.ogg`, `hits/5.ogg`), cut from [freesound 98341](http://freesound.org/people/CGEffex/sounds/98341/) | CGEffex; cut by congusbongus | CC-BY 3.0 |
| `thud_1.ogg`, `thud_2.ogg` | A dive landing, from where he lands. | [Impact Sounds](https://kenney.nl/assets/impact-sounds) (`impactSoft_heavy_000`, `_002`) | Kenney | CC0 |
| `step_earth_1-4.ogg` | Footsteps on the earth grounds (village, school, stadium), from each runner's feet. | [Impact Sounds](https://kenney.nl/assets/impact-sounds) (`footstep_grass_000-003`) | Kenney | CC0 |
| `step_mat_1-3.ogg` | Footsteps on the hall's mat. | [Impact Sounds](https://kenney.nl/assets/impact-sounds) (`footstep_carpet_000`, `_001`, `_003`) | Kenney | CC0 |
| `click.ogg` | A tap in the menus. | [UI Audio](https://kenney.nl/assets/ui-audio) (`click1`) | Kenney | CC0 |
| `crowd_loop.ogg` | The crowd's murmur through a match, louder in a big crowd. | [Free Crowd Cheering Sounds](https://opengameart.org/content/free-crowd-cheering-sounds) ("10 - Ambience", 10-24 s) | Gregor Quendel | CC-BY 4.0 |
| `crowd_cheer.ogg` | An out, a point for the home side. | [Free Crowd Cheering Sounds](https://opengameart.org/content/free-crowd-cheering-sounds) ("04 - Strong cheering - II - Short", 5-10 s) | Gregor Quendel | CC-BY 4.0 |
| `applause.ogg` | The end of a turn, a match. | [Applause in a large hall or church](https://opengameart.org/content/applause-in-a-large-hall-or-church) (1-5.5 s) | eXpl0it3r | CC0 |
| `amb_crickets.ogg` | The village at dusk, and (quieter) the stadium at night. | [Crickets Ambient Noise - loopable](https://opengameart.org/content/crickets-ambient-noise-loopable) | Wolfgang_ | CC0 |
| `amb_birds.ogg` | The school at noon. | [Park ambiences](https://opengameart.org/content/park-ambiences) (`park_ambience_birds`, 185-205 s, the traffic's rumble filtered out) | Thimras | CC0 |

In the hall (the arena) the match's sounds carry a little of a hall's echo (a reverb on the game's own bus).

## Made for the game

| File, or name in `sfx.gd` | What | How |
|---|---|---|
| `whistle`, `whistle_long`, `whistle_short` | The umpires' and the timekeeper's whistles. | Synthesised at startup (`Sfx._whistle`). |
| `whoosh` | A dive, a dodge. | Synthesised (`Sfx._whoosh`). |
| `menu_music.ogg`, `drums_loop.ogg` | The menus' music; the crowd's drums as a chase builds. | Written for the game (`tools/audio/make_music.py`). |
| `crowd_ooh.ogg`, `crowd_groan.ogg`, `clap.ogg` | The crowd at a near thing, at an out against the home side; one clap. | From Kabaddi Raid, by the same maker. |
| `grunt_1-3.ogg`, `hup_1-2.ogg` | The players' effort: a dive, a kho, a dodge. | From Kabaddi Raid, by the same maker. |

## Not found (for the owner to source by hand)

Neither Kenney nor OpenGameArt has these; the game makes do as above.

- **A referee's pea whistle** (a real one, short and long blasts): the whistles are still synthesised.
- **The kho call**: a chaser's sharp "Kho!" as he touches the seated one's back. The game plays a "hup" for now.
- **An Indian crowd**: chants, a dhol, whistling and shouting as at a kho kho ground. The recordings here are a
  European crowd's murmur and cheer (no words to be heard); the drums are written for the game.
- **A crowd's "ooh" and groan** recorded, to replace Kabaddi Raid's.
- **A city at night** that sounds Indian (horns, autorickshaws) for the stadium's skyline: the only city recordings
  found were of European trams.
