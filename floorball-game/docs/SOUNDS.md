# Sounds: what the game plays, and where each comes from

`autoload/sfx.gd` plays every sound. A sound with a recording in `assets/audio/` uses it; the rest are made in code
when the game loads (so the game ships few audio files). The Licences screen credits every recording.

## Every sound

| Sound (`assets/audio/`) | When | Source | Author | Licence |
|---|---|---|---|---|
| `crowd_loop.ogg` (27 s, stereo, loops) | the hall's crowd under play, louder as an attack builds | [Free Crowd Cheering Sounds](https://opengameart.org/content/free-crowd-cheering-sounds), "10 - Ambience", 4-31 s | Gregor Quendel | CC BY 4.0 |
| `chant_loop.ogg` (5 s, stereo, loops) | the crowd's rhythmic cheering, rising over the bed as an attack nears the goal | the same, "08 - Rhythmic cheering", 6-11 s | Gregor Quendel | CC BY 4.0 |
| `crowd_cheer.ogg`, `_2`, `_3` (9 s, stereo) | a goal; a penalty shot scored (one of the three, at random) | the same, "04 - Strong cheering - II - Short" 3-12 s, "02 - Strong cheering and soft rhythmic cheering" 3.5-12.5 s, "01 - Strong cheering and strong rhythmic cheering" 4-13 s | Gregor Quendel | CC BY 4.0 |
| `roar.ogg`, `roar_2.ogg` (6-7 s, stereo) | a goal, under the cheer | the same, "03 - Strong cheering - I" 4-11 s, "09 - Ambience and cheering" 12.5-18.5 s | Gregor Quendel | CC BY 4.0 |
| `applause.ogg`, `applause_2.ogg` (5.5 and 9 s, stereo) | the horn at the end of each period (the hall applauds the teams off) | [Applause in a large hall or church](https://opengameart.org/content/applause-in-a-large-hall-or-church), 2-7.5 s and 10-19 s | eXpl0it3r | CC0 |
| `step_1.ogg` to `step_5.ogg` | footsteps on the hall floor: your player's and those near the ball, as each foot comes down in the motion capture, heard from where they are | [Impact Sounds](https://kenney.nl/assets/impact-sounds), `footstep_wood_000` to `_004` | Kenney | CC0 |
| `click.ogg` | a button in the menus | [Interface Sounds](https://kenney.nl/assets/interface-sounds), `click_001` | Kenney | CC0 |
| `crowd_ooh.ogg`, `crowd_groan.ogg`, `clap.ogg` | a near miss, a goal against | Kabaddi Raid, by the same maker | Josh Nason | the game's own |
| `grunt_1/2.ogg`, `hup_1/2.ogg` | a hard tackle, a big shot | Kabaddi Raid | Josh Nason | the game's own |
| `menu_music.ogg` | the menus | made for the game (tools/audio/make_music.py) | Josh Nason | the game's own |
| `whistle_short_a/b/c.ogg` | the referee's short pip: a stoppage (a foul, out of play, a penalty), a free-hit for delay, a penalty shot awarded or taken (one take at random) | Pixabay: "Referee whistle" (568615), "Referee whistle / coach whistle / sports whistle" (291816), "Metal whistle" (6121) | charlesheffley009, framptones, freesound_community | Pixabay Content License |
| `whistle_long_a/b/c.ogg` | a long blast: a face-off, a goal, a penalty shot's start | the same three | the same | Pixabay Content License |
| `whistle_double.ogg` | two pips: a time-out | "Referee whistle" (568615) | charlesheffley009 | Pixabay Content License |
| `whistle_gym.ogg` | a long blast in a gym, its echo with it: the end of a period | "Referee whistle blow, gymnasium" (6320) | freesound_community | Pixabay Content License |
| `whistle_final.ogg` | short, short, long: the end of the match | "Referee whistle" (568615) | charlesheffley009 | Pixabay Content License |
| made in code | the ball off the blade (shot, pass, touch), the boards, the post, the net, stick on stick, a save, the period horn, the drum; and any recording above if it were missing | autoload/sfx.gd | | the game's own |

The whistles came from the owner (Pixabay, via the shared assets, already cut and levelled; the Pixabay licence lets
them be built into a game but not handed out on their own). They are heard from the nearer referee (3D) through a
little of the hall's reverb, and not in the home screen's match.

The crowd recordings are of a stadium crowd; in the game they are the hall's crowd at a level that fits its size
(the arena's 5,200, the sports hall's few hundred: the bed's volume follows the play, not the venue).

## How they are made

`tools/audio/prepare_sounds.py <downloads>` cuts each from its source, fades it, makes it mono at 22,050 Hz, brings it
to one loudness for its kind (the crowd's recordings in stereo) (EBU R128: one-shots -16 LUFS, the crowd bed -20; footsteps and the click, too short to
measure, to peaks of -12 and -6 dBFS) and writes Ogg Vorbis at quality 2 (about 48 kbit/s). The crowd bed loops
seamlessly: its last 1.5 s are crossfaded into its start.

### Remaking them

Download and unpack into one folder: the Gregor Quendel zip (`gregor_quendel_-_free_crowd_cheering_sounds_-_mp3.zip`),
`applause-clapping-church-crowd-immersive.wav`, Kenney's `kenney_impact-sounds.zip` into `impact-sounds/` and
`kenney_interface-sounds.zip` into `interface-sounds/`; then run the tool from `floorball-game/`.

## Size

The recordings are 0.95 MB in all (0.7.0: the crowd in stereo, a longer bed, the chant, two more cheers, a second
roar and applause; 0.6.0's set was 0.21 MB). APK before and after: docs/PROGRESS.md.

## Looked for and not found (for the owner to source by hand)

These stay made in code; a real recording of each would make the game better. Searched opengameart.org (CC0, CC-BY,
CC-BY-SA only) and kenney.nl; freesound.org and pixabay.com are not reachable from here.

- **The floorball itself**: the hollow plastic ball off a composite blade (a sharp, high "tick"), a slap shot, the
  ball against the boards (a plastic knock), off the post, into the net.
- **Stick on stick** (composite shafts clacking).
- **Shoes squeaking** on a sports floor: the sound of an indoor hall. Nothing usable (the "squeak" packs are toys and
  doors).
- **The period horn or buzzer** of a sports hall.
- **A floorball crowd** of a few hundred in a Nordic hall: drums, clapping, chants ("Hei-hei"), the crowd's groan
  and "ooh" (only stadium cheering is on offer).
