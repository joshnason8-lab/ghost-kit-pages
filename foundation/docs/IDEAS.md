# Ideas for the games (the owner: "ANYTHING you think will make the game better")

Short, ranked by what a player would notice for the work. Impact / cost: high, medium, low. Games: all seven unless
named.

| # | Idea | Impact | Cost | Games |
|---|---|---|---|---|
| 1 | **One-tap "watch it back" after a score**: the replay ring (WsgReplay) and the director (WsgDirector) from the scorer's angle, skippable - the moment players share. | high | low now (B is in) | all |
| 2 | **Normal maps on the players close up** (practice, shoot-outs, replays): done in Hurling (the hurler, the officials); each game as it adopts (tools/blender). | high in close-ups | low per character | the other six |
| 3 | **Phone-tier aware crowd noise**: the crowd's audio follows the 3D crowd's excitement and tension (item C), so the stadium sounds like the moment, even on Low. | high | low once C is in | all |
| 4 | **Kit colour clash check**: when two teams' kits are too alike (contrast below a threshold) the away side wears its second kit automatically. | medium | low | all |
| 5 | **Ghost of your best free** in the free-taking practice: a translucent replay of your best strike from that spot. | medium | low (reuse the replay buffer) | Hurling, Netball (shooting), Floorball (penalties), Kabaddi (raid timing) |
| 6 | **Crowd in the home colours by section, with flags** (as Croke Park's Hill 16): the shirts already lean by section (Stadium._shirts, both crowds); flags waved over them are next. | medium | low | Hurling, Floorball, Netball |
| 7 | **Haptic "sweet spot" pulse** on a perfectly timed strike (WsgAudio.haptic is in). | medium | low | all with a strike |
| 8 | **Photo mode** after a match: pause, free camera, hide the HUD, share - players post these. | medium | medium | all |

Each milestone report to the lead carries the top three.

## Considered and left out

- **Normal maps on the 3D crowd's fans.** The fans' Meshy meshes are already drawn whole (there is no more detailed
  source to bake from), they are about 50 pixels tall in the stands, and the crowd shader runs for thousands of
  them: a normal map is a texture read per fan for nothing a player could see. (Players and officials have them.)
