# Netball Unleashed: graphics plan

Netball is played in the UK, Australia, New Zealand, South Africa, Jamaica, Malawi, Uganda, Fiji and more, mostly in
sports halls, arenas and on outdoor asphalt courts.

## The sports hall: the owner's top request

The owner called out the back wall: "a terrible looking basketball hoop". Make it look like an actual sports hall.

- **Basketball backboards, clean and regulation** (build from primitives; don't use the street hoop here): a clear
  glass board 1.80 × 1.05 m with a 5 cm white border and a 59 × 45 cm white target box, its bottom edge 2.90 m up;
  an orange rim of 45 cm inside diameter at 3.05 m, 15 cm off the board, with a white net; mounted on a dark grey
  steel truss bracket from the end wall (or folded up to the ceiling on a winch frame, as many halls do during
  netball). One at each end, centred.
- **Floor:** `surfaces/white_maple_veneer` (sprung maple), lightly glossy. Paint netball lines in white, and add the
  faint lines of the other sports in other colours (basketball in black, badminton in yellow, volleyball in blue):
  every real multi-use hall has them.
- **Walls:** the lower 2.4 m in painted concrete block (`surfaces/concrete_block_wall` normal map, pale grey or light
  blue paint), blue wall pads (about 2 m high) behind each goal line, upper walls in `surfaces/plastered_wall` or pale
  timber slats (`white_maple_veneer`), and a strip of high windows letting in daylight.
- **Ceiling:** steel trusses with rows of `hall/fluorescent_light` (or `hall/hanging_lamp` for an older hall),
  `surfaces/ceiling_interior` between them.
- **Small things:** `hall/wall_clock` above the main doors, `hall/fire_alarm` beside each door, green exit signs over
  the doors, `hall/wet_floor_sign` by the entrance (off court), `seating/gym_bench` along a side wall,
  `seating/painted_bench` as team benches, a plain scorers' table, a folded cage of balls.
- **Reflections:** `skies/gym_01_light_1k.hdr` for floor and glass reflections on Medium and High.

## The outdoor court

- **Sky:** `skies/netball_court`, a real outdoor netball court at sunset. Use it as the background and the light.
- **Court:** `surfaces/clean_asphalt` coated in green or blue acrylic (tint), white 50 mm lines; `asphalt_02`
  around the run-off.
- **Surrounds:** a chain-link fence (shader; see the README), `seating/park_bench`, `props/street_lamp_tall` on the
  path, floodlight poles (your own), `hall/basketball_hoop` (the owner's street hoop) on a neighbouring court,
  `trees/jacaranda_card` (Australia and South Africa) mixed with `trees/oak_tree` and `trees/small_broadleaf_card`
  (UK, NZ), `foliage/grass_clumps_card` along the fence, `buildings/terrace_row` beyond the fence for a UK
  setting.

## The arena

- `stands/bleacher_metal` for any lower tier you rebuild; keep your seated crowd.

## Not for this game

Palms, temples, monobloc chairs, Indian or Southeast Asian buildings.
