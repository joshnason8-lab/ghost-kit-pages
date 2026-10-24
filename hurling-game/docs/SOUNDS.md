# Sounds

Every sound the game plays, where it came from and under what licence. The recordings are made into the game's files
by `tools/audio/sounds.py` (downloaded, trimmed, levelled, loops made seamless, mono Ogg Vorbis at 22,050 Hz); the
rest are made in code at startup (`autoload/sfx.gd`). `tests/test_runner.gd` checks that every one of them loads.

## Recordings (assets/audio)

| File | What | Source | Author | Licence |
|---|---|---|---|---|
| `crowd_loop.ogg` | The crowd's murmur under the play (a 32 s seamless loop; louder in a bigger crowd) | "Free Crowd Cheering Sounds", 10 - Ambience, https://opengameart.org/content/free-crowd-cheering-sounds | Gregor Quendel | CC-BY 4.0 |
| `crowd_cheer.ogg`, `crowd_cheer_2.ogg`, `crowd_cheer_3.ogg` | The cheer for a point (one of three) | the same, 04 - Strong cheering - II - Short, 05 - Soft cheering - I, 06 - Soft cheering - II | Gregor Quendel | CC-BY 4.0 |
| `roar.ogg`, `roar_2.ogg`, `roar_3.ogg` | The roar for a goal (one of three) | the same, 03 - Strong cheering - I, 01 - Strong cheering and strong rhythmic cheering, 02 - Strong cheering and soft rhythmic cheering | Gregor Quendel | CC-BY 4.0 |
| `birds_loop.ogg` | Birdsong round the parish field and the county ground by day (a 90 s loop) | "Park ambiences", park_ambience_birds.wav, https://opengameart.org/content/park-ambiences | Thimras | CC0 |
| `step_1.ogg` to `step_4.ogg` | Boots on grass: the man you play | "Impact Sounds", footstep_grass_000 to 003, https://kenney.nl/assets/impact-sounds | Kenney | CC0 |
| `clash.ogg` | Hurleys meeting | the same, impactWood_medium_002 | Kenney | CC0 |
| `post.ogg` | The ball off an (aluminium) upright | the same, impactMetal_light_001 | Kenney | CC0 |
| `bounce.ogg` | The sliotar on the grass | the same, impactSoft_medium_000 | Kenney | CC0 |
| `catch.ogg` | The sliotar into the hand | the same, impactPunch_medium_000 | Kenney | CC0 |
| `shoulder.ogg` | A shoulder charge | the same, impactSoft_heavy_001 | Kenney | CC0 |
| `click.ogg` | A tap on the menus | "Interface Sounds", click_001, https://kenney.nl/assets/interface-sounds | Kenney | CC0 |
| `crowd_ooh.ogg`, `crowd_groan.ogg`, `applause.ogg`, `clap.ogg` | The crowd's ooh at a near miss, groan at a wide, applause | Kabaddi Raid, by the same maker | Josh Nason | the game's own |
| `grunt_1.ogg` to `grunt_3.ogg`, `hup_1.ogg`, `hup_2.ogg` | Players' effort | Kabaddi Raid, by the same maker | Josh Nason | the game's own |
| `menu_music.ogg` | The menus' jig | written for the game, `tools/audio/make_music.py` | Josh Nason | the game's own |

## Made in code (autoload/sfx.gd)

`whistle`, `whistle_long` (the referee's whistle), `strike` (ash on leather), `tap` (the sliotar hopped on the bas),
`save`; and, if their files were missing, every sound above with a fallback (`clash`, `catch`, `shoulder`, `post`,
`bounce`, `click`, `roar`, `crowd_loop`).

## Looked for and not found

- **A referee's whistle** (a pea whistle, a long blast and short pips): nothing on OpenGameArt or Kenney is a
  sports whistle (only tunes whistled and steam whistles). The made one stays. A recording from the owner would be
  the biggest single improvement.
- **The strike, ash on leather**: the crack of a hurley on a sliotar; no recording of it, or of a cricket or
  baseball bat close enough. The made one stays.
- **An Irish crowd**: a chant ("Come on the ..."), a county's name roared. Only general stadium cheering was to be
  had (Gregor Quendel's, above).
- **Rain** and **a town's evening** for the night match: none that fit under a crowd without being heard as noise.
