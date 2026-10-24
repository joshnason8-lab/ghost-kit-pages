# Sounds

Every sound the game plays: the file, where it came from, who made it and its licence. The Licences screen
(Settings > About > Licences, `ui/licences_screen.gd`) carries the same credits. `tests/test_runner.gd` (7c) checks that
every file below is in `assets/audio/` and loads, and that every sound the code names is one the game has.

Only CC0, CC BY, CC BY-SA and OGA-BY sources are used; nothing non-commercial (NC) or no-derivatives (ND).

## Recordings (0.11.0)

Made from the downloads by `tools/audio/make_recorded.py`: mono, 22.05 kHz, silence trimmed off, peak-normalised
(one-shots) or set to one loudness and crossfaded end into start so they loop without a seam (beds), then Ogg Vorbis.

| File(s) in `assets/audio/` | What it is in the game | Source | Author | Licence |
|---|---|---|---|---|
| `crowd_loop.ogg` | The crowd's murmur under a match, louder as a raid gets tense (from "10 - Ambience", 18 s loop) | [Free Crowd Cheering Sounds](https://opengameart.org/content/free-crowd-cheering-sounds) | Gregor Quendel | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `crowd_cheer.ogg` | The crowd cheering a point (from "04 - Strong cheering - II - Short") | same | Gregor Quendel | CC BY 4.0 |
| `roar.ogg` | The big roar: walk-outs, big points, the auction's big buys, trophies (from "03 - Strong cheering - I") | same | Gregor Quendel | CC BY 4.0 |
| `applause.ogg` | Applause after a raid | [Applause in a large hall or church](https://opengameart.org/content/applause-in-a-large-hall-or-church) | eXpl0it3r | CC0 |
| `step_mat_1..3.ogg` | Footsteps on the mats (dome, stadium, monsoon) (`footstep_carpet_000, 001, 003`) | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 |
| `step_earth_1..4.ogg` | Footsteps on the village's beaten earth (`footstep_grass_000, 001, 002, 004`) | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 |
| `step_sand_1..4.ogg` | Footsteps on Puri's sand (`Fantozzi-SandL1, R1, L2, R3`) | [Fantozzi's Footsteps (Grass/Sand & Stone)](https://opengameart.org/content/fantozzis-footsteps-grasssand-stone) | Fantozzi | CC0 |
| `thud_1..3.ogg` | A tackle's hold landing, a dash, a body on the mat (`impactSoft_heavy_000, 002, 003`) | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 |
| `slap_1..3.ogg` | A raider's touch, the bonus line (`impactSoft_medium_000, 001, 003`) | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 |
| `click.ogg` | Every button in the menus (`click_002`) | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 |
| `amb_monsoon.ogg` | Rain at the monsoon ground (16 s loop) | [AMB Rain Loop 1](https://opengameart.org/content/amb-rain-loop-1) | Kresiek The Furry | CC0 |
| `amb_beach.ogg` | The sea at Puri: the recording's four waves, overlapping round a 16 s loop | [Beach Ocean Waves](https://opengameart.org/content/beach-ocean-waves) | jasinski | CC0 |
| `amb_village.ogg` | Birds at the village ground at dusk (16 s loop of `park_ambience_birds`) | [Park ambiences](https://opengameart.org/content/park-ambiences) | Thimras | CC0 |
| `amb_stadium.ogg` | Crickets outside the floodlit stadium at night (10 s loop) | [Crickets Ambient Noise - loopable](https://opengameart.org/content/crickets-ambient-noise-loopable) | Wolfgang_ | CC0 |
| `whistle_short_1..3.ogg` | The referee's short pip: an empty raid, a card (`short_a`, `_b`, `_c`) | Pixabay 568615, 291816, 6121 | charlesheffley009, framptones, freesound_community | Pixabay Content License |
| `whistle_long_1..3.ogg` | The long blast: a raid starting, a point, half-time (`long_a`, `_b`, `_c`) | Pixabay 568615, 291816, 6121 | charlesheffley009, framptones, freesound_community | Pixabay Content License |
| `whistle_double.ogg` | Two quick pips: a time-out | Pixabay 568615 ("Referee whistle") | charlesheffley009 | Pixabay Content License |
| `whistle_final.ogg` | Short, short, long: full time | Pixabay 568615 | charlesheffley009 | Pixabay Content License |
| `whistle_gym.ogg` | A long blast in a hall, with its echo: the dome's long blasts | Pixabay 6320 ("Referee whistle blow, gymnasium") | freesound_community | Pixabay Content License |
| `menu_music.ogg` | The menus' music (an edited loop, `tools/audio/make_menu_music.py`) | "Indian", Pixabay track 611803 | LNPLUSMUSIC | Pixabay Content License |

The dome is indoors and has no ambience of its own: its crowd is its sound.

## Made for the game

| File(s) | What it is | How |
|---|---|---|
| `chant_raider`, `chant_word_1..2` | The raider's "kabaddi, kabaddi" | `tools/audio/make_voices.py` (MBROLA Indian voices through espeak-ng) |
| `yell_aaja`, `yell_pakad`, `yell_shabash`, `yell_chal`, `yell_haan`, `yell_nahi`, `yell_touch` | Players' shouts in Hindi | `tools/audio/make_voices.py` |
| `crowd_chant`, `crowd_ooh`, `crowd_groan`, `clap` | The crowd chanting, a near miss, a lost point, one clap | `tools/audio/make_sounds.py` (layered synthetic voices) |
| `grunt_1..5`, `oof_1..3`, `exhale_1..2`, `hup_1..2` | Players' efforts and breaths | `tools/audio/make_sounds.py` (a source-filter voice) |
| buzzer, whoosh, gavel, dhol loop, bid | The clock's buzzer, moves through the air, the auction | Synthesised at startup in `autoload/sfx.gd` |

The whistles (0.11.1) were supplied by the owner from Pixabay through the shared assets (`shared-assets/sounds/whistle/`,
trimmed, mono, loudness-matched to about -16 LUFS); they are copied in unchanged. The Pixabay licence asks for no
credit; they are credited anyway, as "Whistle sounds from Pixabay".

## How they play (autoload/sfx.gd)

- **The referee's whistle** (`Sfx.whistle`, `Match._whistle`) from where he stands, a take picked at random: a long
  blast as a raid starts, after a point and at half-time (in the dome, the hall take); a short pip after an empty raid
  and for a card; two pips for a time-out; short-short-long at full time. Faint (-16 dB) in the home screen's match.
- **Spatial:** footsteps, tackles' thuds and touches play from where they happen (`Sfx.play_at`, `AudioStreamPlayer3D`),
  louder near the camera and panned to their side. Each player's feet sound a step each stride on the ground's
  surface (`Athlete._footsteps`, `Arena.step_surface`), harder the faster he goes; none for the menus' match behind.
- **The crowd follows the play:** its bed swells with the raid's tension and the struggle of a hold, and it cheers,
  groans, "ooh"s and applauds the points; the ground's own ambience sits under it.
- **Volume:** three sliders in Settings (Effects, Crowd, Music) set three buses (`Sfx.BUSES`); the Sound switch turns
  everything off.
- **Pause:** a paused match holds everything it was playing and starts nothing new (`Sfx.pause`); the menu's click
  still sounds.

## Not found (to source)

Searched kenney.nl and opengameart.org (Freesound and Pixabay are blocked from here):

- **A dhol** (or tabla, or any Indian drum). Only war drums turned up; the synthesised dhol loop stays.
- **Regional chants:** a real crowd chanting "kabaddi, kabaddi", or in Marathi, Tamil, Telugu, Kannada, Bengali or
  Punjabi. The crowd's chant and the players' shouts are still synthesised.
- **Bare feet on a mat**: the mats use Kenney's carpet footsteps, which are shod.
- **A city at night** for the stadium beyond its crickets, and an indoor hall's room tone for the dome.
