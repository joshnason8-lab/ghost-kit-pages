# The sounds

Every sound the game plays, where it comes from, who made it and under what licence. The recordings are made from
their sources by `tools/audio/make_sfx.py` (cut, mono at 22,050 Hz, set to a common loudness, loops crossfaded,
Ogg Vorbis); the sources themselves are not in the repository. `autoload/sfx.gd` plays them, and
`tests/test_runner.gd` (`_sounds`) checks every one is there and loads.

## Recordings (since 0.6; longer beds and more takes since 0.7)

| File (`assets/audio/`) | What, and where it plays | Source | Author | Licence |
|---|---|---|---|---|
| `slap_1.ogg`, `slap_2.ogg` | The kho: a palm on the seated chaser's back, from where it lands (since 0.10 alone: the "hup" raised a pitch over it sounded like a cartoon). | [Punch, slap, n' kick](https://opengameart.org/content/punch-slap-n-kick) (`hits/3.ogg`, `hits/5.ogg`), cut from [freesound 98341](http://freesound.org/people/CGEffex/sounds/98341/) | CGEffex; cut by congusbongus | CC-BY 3.0 |
| `thud_1.ogg`, `thud_2.ogg` | A dive landing, from where he lands. | [Impact Sounds](https://kenney.nl/assets/impact-sounds) (`impactSoft_heavy_000`, `_002`) | Kenney | CC0 |
| `step_earth_1-4.ogg` | Footsteps on the earth grounds (village, school, stadium), from each runner's feet. | [Impact Sounds](https://kenney.nl/assets/impact-sounds) (`footstep_grass_000-003`) | Kenney | CC0 |
| `step_mat_1-3.ogg` | Footsteps on the hall's mat. | [Impact Sounds](https://kenney.nl/assets/impact-sounds) (`footstep_carpet_000`, `_001`, `_003`) | Kenney | CC0 |
| `click.ogg` | A tap in the menus. | [UI Audio](https://kenney.nl/assets/ui-audio) (`click1`) | Kenney | CC0 |
| `crowd_loop.ogg` | The crowd's murmur through a match, louder in a big crowd. | [Free Crowd Cheering Sounds](https://opengameart.org/content/free-crowd-cheering-sounds) ("10 - Ambience", 10-34 s) | Gregor Quendel | CC-BY 4.0 |
| `crowd_cheer_1-2.ogg` | An out, a point for the home side (one take or the other). | [Free Crowd Cheering Sounds](https://opengameart.org/content/free-crowd-cheering-sounds) ("04 - Strong cheering - II - Short", 5-10 s; "03 - Strong cheering - I", 5-10 s) | Gregor Quendel | CC-BY 4.0 |
| `applause_1-3.ogg` | The end of a turn, a match. | [Applause in a large hall or church](https://opengameart.org/content/applause-in-a-large-hall-or-church) (1-5.5, 12-16.5, 24-28.5 s) | eXpl0it3r | CC0 |
| `amb_crickets.ogg` | The village at dusk, and (quieter) the stadium at night; 6-7 dB quieter since 0.10. | [Crickets Ambient Noise - loopable](https://opengameart.org/content/crickets-ambient-noise-loopable) | Wolfgang_ | CC0 |
| `amb_birds.ogg` | The school at noon; 7 dB quieter since 0.10. | [Park ambiences](https://opengameart.org/content/park-ambiences) (`park_ambience_birds`, 185-245 s, the traffic's rumble filtered out) | Thimras | CC0 |

| `whistle_short_1-3.ogg` | A short pip: an out (one, from that half's umpire), a foul (again and again until it is put right), the second of the timekeeper's two at a turn's start. | Pixabay 568615 "Referee whistle"; 291816 "Referee whistle / coach whistle / sports whistle"; 6121 "Metal whistle" | charlesheffley009; framptones; freesound_community | Pixabay Content License |
| `whistle_long_1-3.ogg` | A long blast: the timekeeper's at a turn's start and end. | the same three | charlesheffley009; framptones; freesound_community | Pixabay Content License |
| `whistle_gym.ogg` | The long blast in the hall, with its echo. | Pixabay 6320 "Referee whistle blow, gymnasium" | freesound_community | Pixabay Content License |
| `whistle_final.ogg` | Short, short, long: the end of the match (the last turn's whistle). | Pixabay 568615 | charlesheffley009 | Pixabay Content License |
| `whistle_double.ogg` | Two quick pips (loaded; kho kho's umpires have no use for it yet). | Pixabay 568615 | charlesheffley009 | Pixabay Content License |

The whistles were found by the owner and cut, faded and loudness-matched by the lead (shared assets, `sounds/whistle/`);
they are played in 3D from the official who blows them (the timekeeper at the table, the umpire of that half), and
not in the menu's backdrop match. The Pixabay licence asks no credit and does not allow the sounds to be passed on
on their own; here they are part of the game.

The crowd's murmur rises and falls with the chase since 0.10 (`match.gd` `_crowd_roar`): up as a chaser closes on a
defender, through a dive, with the last of a batch left and in a turn's last half-minute; a near miss brings a loud
"ooh" and the roar at its height.

In the hall (the arena) the match's sounds carry a little of a hall's echo (a reverb on the game's own bus).

## Made for the game

| File, or name in `sfx.gd` | What | How |
|---|---|---|
| `whoosh` | A dive, a dodge. | Synthesised (`Sfx._whoosh`). |
| `menu_music.ogg`, `drums_loop.ogg` | The menus' music; the crowd's drums as a chase builds. | Written for the game (`tools/audio/make_music.py`). |
| `crowd_ooh.ogg`, `crowd_groan.ogg`, `clap.ogg` | The crowd at a near thing, at an out against the home side; one clap. | From Kabaddi Raid, by the same maker. |
| `grunt_1-3.ogg`, `hup_1-2.ogg` | The players' effort: a dive, a kho, a dodge. | From Kabaddi Raid, by the same maker. |

## Not found (for the owner to source by hand)

Neither Kenney nor OpenGameArt has these; the game makes do as above.

- **The kho call**: a chaser's sharp "Kho!" as he touches the seated one's back. The game plays a "hup" for now.
- **An Indian crowd**: chants, a dhol, whistling and shouting as at a kho kho ground. The recordings here are a
  European crowd's murmur and cheer (no words to be heard); the drums are written for the game.
- **A crowd's "ooh" and groan** recorded, to replace Kabaddi Raid's.
- **A city at night** that sounds Indian (horns, autorickshaws) for the stadium's skyline: the only city recordings
  found were of European trams.
