# The shared foundation in Hurling Heroes (pilot)

This branch (`claude/hurling-foundation-pilot`, made from `claude/hurling-game`) draws the hurlers, the officials and
the nearer crowd with the World Stage Games foundation (`addons/wsg_foundation`, from `claude/shared-foundation`;
`foundation/ADOPTING.md` there). The game is otherwise unchanged: `player.gd` still poses its own body every frame and
everything it measures (the bas, the hands) comes from that; the foundation draws a new one beside it.

| | What changed | Where |
|---|---|---|
| Hurlers, officials | The owner's model (and the referee's and umpire's) on the shared rig: fingers that close round the hurley, twist and joint helpers, feet flat; running from motion capture (starts, cuts, stops, backpedals, the sprint) with planted feet; the game's own moves (swings, catches, solo, falls, signals) laid over it from the game's body | `game/foundation_link.gd`, `player.gd` (`link`), `assets/foundation/` |
| Crowd (Medium, High) | Whole 3D fans in the stands nearest the far stand's middle, on their seats (standing on the terraces), getting up as a move builds, cheering and clapping at a score, watching the ball; the rest stay cut-outs | `stadium.gd` (`crowd3d`, `_seats`), `crowd.gd` (`set_excite`, `set_light`), `match.gd` (tension, the ball) |
| Arms | The game's arms rebuilt through its shoulders and hands: its hurley arm is mostly bent backwards or turned the wrong way on the 17 bones (the toon hid it), which the rig's elbow hinge straightened, so the arm snapped; now the hand is where the game has it and the elbow bends the way an elbow can | `foundation_link.gd` (`legacy.arms`), `tests/elbow_audit.tscn` |
| Seats | A bench (0.40 m high, 0.35 m deep) along the back of each step of a stand (and the national stadium's seated end); the 3D fans sit on it (they sat in the step behind) | `stadium.gd` (`SEAT_H`, `SEAT_D`, `_seats`) |
| Practice, shoot-out | Close up: the right hand closed on the hurley's handle as drawn, the top hand put on the handle in a swing (and let go of it after), wrists and elbows kept in range through the set, lift, toss, strike and follow-through; the 3D crowd built again behind the goal they shoot at with the most full figures (Close) | `foundation_link.gd` (`_two_hands`, `_grips`), `match.gd` (`_close_crowd`), `practice.gd` |
| Low | The rig and mocap for the players (low mesh); the cut-out crowd as before | |
| Build | The licensed animation is baked in CI from the private assets repository (`ASSETS_REPO_TOKEN`) and only ships inside the APK; without the secret the build is the game as it was | `.github/workflows/hurling-android.yml`, `tools/wsg/fetch_assets.sh` |
| Releases | The beta and the HD pack are published only from `claude/hurling-game` (they were published from any branch); this branch publishes the pre-release `hurling-foundation-pilot` | the workflow |

`tests/foundation_pilot.tscn` films the run, a crowd close-up at a score, the seats, the hurley arm and an umpire's
point, and `tests/free_film.tscn` a practice free and the extra-time shoot-out, with the foundation and without it
(`WSG_OFF=1`), for the owner's before / after videos (`FILM_TAG` sets the caption).

`tests/elbow_audit.tscn` plays a whole AI match on the foundation and fails if an elbow ever bends backwards, points
where an elbow cannot, or is straightened against the game's pose, a wrist is wrung past 110 degrees, or a finger goes
more than 5 mm into the hurley's handle (`-- [minutes] [seed] [raw]`; `raw`: the arms as the game turns them, which
fails; `-- practice`: the ten frees; `-- shootout`: a shoot-out to a winner). It also counts the game's own body's
wrong elbows and wrists, for the record.
