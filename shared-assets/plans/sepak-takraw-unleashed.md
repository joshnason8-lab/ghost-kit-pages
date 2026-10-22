# Sepak Takraw Unleashed: graphics plan

Southeast Asia: Thailand, Malaysia, Indonesia, Vietnam, Laos, Myanmar. Venues: four indoor (National Arena, Grand
Dome, a shopping-mall atrium, a provincial gym) and four outdoor (a temple court, a floodlit park court, a beach at
sunset, a night-market street).

## Temple court

- **The landmark:** `buildings/thai_temple`, the owner's Thai wat with tiered gold-trimmed roofs. Place it so the
  broadcast camera frames it behind the court.
- **Sky:** `skies/qwantani_noon_puresky` or `kloofendal_48d_partly_cloudy_puresky`. **Court:**
  `surfaces/concrete_floor` or `clean_asphalt` with painted lines.
- `trees/coconut_palm`, `trees/rain_tree`, `trees/island_tree_a_card` and `island_tree_b_card`;
  `seating/monobloc_chair` for the crowd.

## Floodlit park court

- **Sky:** `skies/kloppenheim_02_puresky`. **Court:** `surfaces/clean_asphalt`.
- `seating/park_bench`, `props/street_lamp_tall`, `hall/basketball_hoop` (the owner's street hoop) on the next court,
  a chain-link fence (shader), `trees/rain_tree`.

## Beach at sunset

- **Sky:** `skies/qwantani_sunset_puresky` or `table_mountain_1_puresky`. **Sand:** `surfaces/coast_sand_01`, with
  `damp_beach_sand` toward the sea.
- **The sea:** a water plane with `water/water_normal_512.png`.
- `trees/coconut_palm` and `coconut_palm_card`, `buildings/stilt_house` back from the beach.

## Night-market street

- **Sky:** `skies/kloppenheim_07_puresky`. **Street:** `surfaces/asphalt_02`.
- **Stalls:** `props/long_table` and `props/scorers_table` under `surfaces/corrugated_iron` roofs, strings of
  `props/lantern`, `seating/metal_stool`, `seating/folding_stool`, `props/cafe_table_set`, `props/street_lamp_wall` on
  the walls, `buildings/city_apartments` behind.

## Provincial gym

- `surfaces/white_maple_veneer` floor, `concrete_block_wall` walls (pale paint), `hall/fluorescent_light`,
  `hall/wall_clock`, `hall/fire_alarm`, `hall/wet_floor_sign` by the door, `seating/gym_bench`, and a clean
  regulation basketball board built from primitives on each end wall (see the netball plan for the measurements).

## Arenas and mall

- `stands/bleacher_metal` for lower tiers; `skies/gym_01_light_1k.hdr` for floor reflections.

## Not for this game

Oak, terraced houses, the thatched cottage, jacaranda, Irish skies.
