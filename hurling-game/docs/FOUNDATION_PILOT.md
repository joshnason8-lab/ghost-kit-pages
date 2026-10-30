# The shared foundation in Hurling Heroes (pilot)

This branch (`claude/hurling-foundation-pilot`, made from `claude/hurling-game`) draws the hurlers, the officials and
the nearer crowd with the World Stage Games foundation (`addons/wsg_foundation`, from `claude/shared-foundation`;
`foundation/ADOPTING.md` there). The game is otherwise unchanged: `player.gd` still poses its own body every frame and
everything it measures (the bas, the hands) comes from that; the foundation draws a new one beside it.

| | What changed | Where |
|---|---|---|
| Hurlers, officials | The owner's model (and the referee's and umpire's) on the shared rig: fingers that close round the hurley, twist and joint helpers, feet flat; running from motion capture (starts, cuts, stops, backpedals, the sprint) with planted feet; the game's own moves (swings, catches, solo, falls, signals) laid over it from the game's body | `game/foundation_link.gd`, `player.gd` (`link`), `assets/foundation/` |
| Crowd (Medium, High) | Whole 3D fans in the stands nearest the far stand's middle, on their seats (standing on the terraces), getting up as a move builds, cheering and clapping at a score, watching the ball; the rest stay cut-outs | `stadium.gd` (`crowd3d`, `_seats`), `crowd.gd` (`set_excite`, `set_light`), `match.gd` (tension, the ball) |
| Low | The rig and mocap for the players (low mesh); the cut-out crowd as before | |
| Build | The licensed animation is baked in CI from the private assets repository (`ASSETS_REPO_TOKEN`) and only ships inside the APK; without the secret the build is the game as it was | `.github/workflows/hurling-android.yml`, `tools/wsg/fetch_assets.sh` |
| Releases | The beta and the HD pack are published only from `claude/hurling-game` (they were published from any branch); this branch publishes the pre-release `hurling-foundation-pilot` | the workflow |

`tests/foundation_pilot.tscn` films the run, a crowd close-up at a score and an umpire's point, with the foundation and
without it (`WSG_OFF=1`), for the owner's before / after videos.
