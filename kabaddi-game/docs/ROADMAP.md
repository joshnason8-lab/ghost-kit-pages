# Roadmap

What exists is a complete, playable loop across all three modes. This file lists what it would take to get from
here to a store release, roughly in order.

## 1. Look and feel (biggest jump in quality)
- [ ] Real athlete model and kabaddi mocap. See [ASSETS.md](ASSETS.md). This is the single biggest visual upgrade.
- [ ] Shirt number decals and team kit textures for custom models.
- [ ] Modelled stands and venue meshes. Crowd cards and flags at the Nations Cup.
- [ ] Replays: a 3-second slow-motion replay of super raids and super tackles.
- [ ] Recorded audio: crowd, dhol, whistle. **Commentary in each language** is the standout feature.

## 2. Gameplay depth
- [ ] Raider moves: *dubki* (duck under a chain), frog jump over an ankle hold, running hand touch, scorpion kick.
- [ ] Defender moves: ankle hold vs thigh hold vs block vs chain, each with its own timing window.
- [ ] Choose your raider before each raid and pick defensive formations (2-2-3, umbrella).
- [x] Stamina that carries across raids, and time-outs.
- [ ] Substitutions (see docs/KABADDI.md).
- [x] Technical points: 5-second rule, cards.
- [ ] Review system (challenge a touch call).
- [ ] Tune the AI per difficulty against real PKL averages: raid success near 35–40%, tackle success near 35%,
      empty raids near 25%.

## 3. Modes
- [ ] Women's league and women's Nations Cup.
- [ ] Owner mode: run a franchise's auction (bid for a whole squad) instead of being a lot.
- [ ] Beach kabaddi rules on the Puri Beach ground (4 v 4, no lobbies, smaller court).
- [ ] Circle-style kabaddi (Punjab) as an event mode.
- [ ] Online: async challenges first, real-time 1v1 later. Real-time needs a server and anti-cheat.

## 4. Performance on budget phones
- [ ] Profile on a 3–4 GB RAM Android device. Keep the Low preset at 30 fps or better.
- [ ] Merge each placeholder athlete into one mesh (or ship the skinned model) to cut draw calls.
- [ ] Keep the download under 150 MB. Use Play Asset Delivery if the grounds grow.

## 5. Release
- [ ] Release keystore and signed AAB (Godot exports it; switch `gradle_build/export_format` to AAB).
- [ ] Privacy policy and data safety form. The game stores only local saves today.
- [ ] Native-speaker review of all 7 translations, especially the kabaddi terms.
- [ ] Monetisation: free-to-play with cosmetics (kits, celebrations) and a season pass. **No real-money gaming**:
      India's 2025 online gaming law bans it, so keep anything that looks like betting or paid contests out.
- [ ] Licensing (optional, later): a real league or player licence costs real money. Fictional teams keep that
      off the critical path.
