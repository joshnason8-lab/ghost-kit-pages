# Sounds: what the game plays, and where each comes from

`autoload/sfx.gd` plays every sound. A sound with a recording in `assets/audio/` uses it; the rest are made in code
when the game loads (so the game ships few audio files). The Licences screen credits every recording.

## Every sound

| Sound (`assets/audio/`) | When | Source | Author | Licence |
|---|---|---|---|---|
| `crowd_loop.ogg` (16 s, loops) | the hall's crowd under play, louder as an attack builds | [Free Crowd Cheering Sounds](https://opengameart.org/content/free-crowd-cheering-sounds), "10 - Ambience", 12-28 s | Gregor Quendel | CC BY 4.0 |
| `crowd_cheer.ogg` (9 s) | a goal; a penalty shot scored | the same, "04 - Strong cheering - II - Short", 3-12 s | Gregor Quendel | CC BY 4.0 |
| `roar.ogg` (7 s) | a goal, under the cheer | the same, "03 - Strong cheering - I", 4-11 s | Gregor Quendel | CC BY 4.0 |
| `applause.ogg` (5.5 s) | the horn at the end of each period (the hall applauds the teams off) | [Applause in a large hall or church](https://opengameart.org/content/applause-in-a-large-hall-or-church), 2-7.5 s | eXpl0it3r | CC0 |
| `step_1.ogg` to `step_5.ogg` | footsteps on the hall floor: your player's and those near the ball, as each foot comes down in the motion capture, heard from where they are | [Impact Sounds](https://kenney.nl/assets/impact-sounds), `footstep_wood_000` to `_004` | Kenney | CC0 |
| `click.ogg` | a button in the menus | [Interface Sounds](https://kenney.nl/assets/interface-sounds), `click_001` | Kenney | CC0 |
| `crowd_ooh.ogg`, `crowd_groan.ogg`, `clap.ogg` | a near miss, a goal against | Kabaddi Raid, by the same maker | Josh Nason | the game's own |
| `grunt_1/2.ogg`, `hup_1/2.ogg` | a hard tackle, a big shot | Kabaddi Raid | Josh Nason | the game's own |
| `menu_music.ogg` | the menus | made for the game (tools/audio/make_music.py) | Josh Nason | the game's own |
| made in code | the referees' whistle (one, long, double), the ball off the blade (shot, pass, touch), the boards, the post, the net, stick on stick, a save, the period horn, the drum; and the crowd bed, roar and click if their recordings were missing | autoload/sfx.gd | | the game's own |

The crowd recordings are of a stadium crowd; in the game they are the hall's crowd at a level that fits its size
(the arena's 5,200, the sports hall's few hundred: the bed's volume follows the play, not the venue).

## How they are made

`tools/audio/prepare_sounds.py <downloads>` cuts each from its source, fades it, makes it mono at 22,050 Hz, brings it
to one loudness for its kind (EBU R128: one-shots -16 LUFS, the crowd bed -20; footsteps and the click, too short to
measure, to peaks of -12 and -6 dBFS) and writes Ogg Vorbis at quality 2 (about 48 kbit/s). The crowd bed loops
seamlessly: its last 1.5 s are crossfaded into its start.

### Remaking them

Download and unpack into one folder: the Gregor Quendel zip (`gregor_quendel_-_free_crowd_cheering_sounds_-_mp3.zip`),
`applause-clapping-church-crowd-immersive.wav`, Kenney's `kenney_impact-sounds.zip` into `impact-sounds/` and
`kenney_interface-sounds.zip` into `interface-sounds/`; then run the tool from `floorball-game/`.

## Size

The new recordings are 210 KB (the crowd bed 76 KB, the cheer and roar 78 KB, the applause 33 KB, five footsteps and a
click 23 KB), against 34 KB for the two files they replace (the crowd bed, roar and click were made in code). APK before and after: docs/PROGRESS.md.

## Looked for and not found (for the owner to source by hand)

These stay made in code; a real recording of each would make the game better. Searched opengameart.org (CC0, CC-BY,
CC-BY-SA only) and kenney.nl; freesound.org and pixabay.com are not reachable from here.

- **A referee's pea whistle** (Fox 40 or similar): short blasts, a long one, a double. The library's "whistles" are
  people whistling a tune (1-1.4 kHz, no pea trill).
- **The floorball itself**: the hollow plastic ball off a composite blade (a sharp, high "tick"), a slap shot, the
  ball against the boards (a plastic knock), off the post, into the net.
- **Stick on stick** (composite shafts clacking).
- **Shoes squeaking** on a sports floor: the sound of an indoor hall. Nothing usable (the "squeak" packs are toys and
  doors).
- **The period horn or buzzer** of a sports hall.
- **A floorball crowd** of a few hundred in a Nordic hall: drums, clapping, chants ("Hei-hei"), the crowd's groan
  and "ooh" (only stadium cheering is on offer).
