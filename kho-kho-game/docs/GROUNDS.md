# The grounds round the court

What the outdoor grounds (the village at dusk, the school by day, the floodlit stadium) put up round the court, and
where it comes from. All of it is built in code in `game/arena.gd` and merged into the structure's meshes, so it adds
no draw call on any graphics level and nothing to the download.

## What the two real matches showed (25 October 2026)

The owner sent two full turns of real matches (docs/AI.md, "Watched"). Both were played at temporary tournament
grounds, one by day and one at night, and their surroundings were looked at as well as the play:

- **Steel barricades** (galvanised crowd-control panels) between the court and the crowd, with people standing
  pressed against them.
- **Tents**: a red pop-up canopy over the officials by day; at night, white cloth tents (shamiana) with a frilled
  valance on both sides, people seated inside. Rows of red or white plastic chairs under and beside them; a beach
  umbrella over the scorers.
- **A stage** at one end at night: a raised platform with guests on chairs, a huge printed backdrop, a truss over
  it carrying a row of floodlights, trophies on a white-clothed table in front, speakers on stands.
- **Temporary lighting**: tall truss towers with lamp clusters, and an LED scoreboard on scaffolding by day.
- **Flags** on tall poles (saffron, green, blue, yellow, white) and **printed banners** tied to the barricades.
- **Green turf** round the red court by day; a second court beside it.
- **Beyond**: a long white institutional building, big shade trees, a phone mast; at night, dark buildings and street
  lamps.
- **The crowd in everyday clothes**: white and pale shirts, dark trousers, some bright saris and kurtas. Not dressed
  in the teams' colours.

## What the grounds have now (0.9)

| | Village (dusk) | School (day) | Stadium (night) |
|---|---|---|---|
| Barricades: far side, ends, near side clear of the camera | yes | yes | in front of the stands |
| Banners on the far barricade (colour and pattern only) | 4 | 4 | 4 |
| White tents with a red and yellow valance over the teams' benches | yes | yes | no (the stand's roof) |
| Flags on poles behind the far crowd and at the corners | yes (not where the stage is) | yes | on the stand's back wall |
| Green turf round the lobby | | yes | |
| Bunting over the far crowd | (string lights, as before) | yes | |
| A stage with guests, backdrop, truss lights, trophies and speakers; two truss towers of lamps | yes | | |
| The crowd: 18% in their side's colours, the rest in everyday clothes (`Crowd.CLOTHES`) | yes | yes | yes |

Low keeps all of it but simpler: the barricades are rails without bars, the banners plain, no valance scallops, no
bunting, five lamps on the stage's truss. The banners and the backdrop carry no words: no real event, organisation,
sponsor or place is named or suggested.

The cost, measured with `tests/perf_probe.gd` (draw calls unchanged at every level):

| | Before | After |
|---|---|---|
| Village, Low | 69k triangles | 78k (budget 90k) |
| Village, Medium / High | 62k / 63k | 72k / 73k |
| School, Low / Medium / High | 38k / 57k / 58k | 40k / 67k / 68k |
| Stadium, Low / Medium / High | 39k / 61k / (not logged) | 41k / 68k / 70k |

`tests/test_runner.gd` (`_grounds`) checks each outdoor ground has what the table says on every level and that over
70% of every crowd is in everyday clothes.

Not done yet, from the same matches: scaffold stands, a second court beside the school's, an LED scoreboard, a
beach umbrella over the scorers, and people standing at the barricades rather than seated behind them.
