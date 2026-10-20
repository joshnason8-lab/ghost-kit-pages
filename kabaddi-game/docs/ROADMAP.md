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
- [x] Owner mode: run a franchise's auction (bid for a whole squad) instead of being a lot. Since 0.8.0 with your own
  retentions, a war room and shortlist, auto-bid to your price, and grades for every franchise.
- [x] The League Season around the matches (0.8.0): the news, your seven for each match, form, fitness and knocks,
  the board's goal and next year's budget, derbies, weekly awards, the record book, a hall of fame, and players who
  age, improve and retire.
- [x] Nations Cup squads (0.8.0): twelve from eighteen and a captain, what you need before the last group match, the
  bracket, the tournament's awards and the Underdog Trophy.
- [ ] Beach kabaddi rules on the Puri Beach ground (4 v 4, no lobbies, smaller court).
- [ ] Circle-style kabaddi (Punjab) as an event mode.
- [ ] Online: async challenges first, real-time 1v1 later. Real-time needs a server and anti-cheat.

## 4. Performance on budget phones
- [ ] Profile on a 3–4 GB RAM Android device. Keep the Low preset at 30 fps or better.
- [ ] Merge each placeholder athlete into one mesh (or ship the skinned model) to cut draw calls.
- [ ] Keep the download under 150 MB. Use Play Asset Delivery if the grounds grow.

## 5. Release
- [x] Signed AAB (0.8.4): GitHub Actions builds the Play bundle with Gradle, signed with your upload key once it is
  in the repository's secrets. See [store/PLAY_STORE.md](../store/PLAY_STORE.md) for every step to Google Play.
- [x] Privacy policy, help page and the Data safety answers (0.8.4): `kabaddi-raid/` at the top of the repository,
  linked from Settings > About.
- [ ] Native-speaker review of all 7 translations, especially the kabaddi terms.
- [ ] Monetisation: free-to-play with cosmetics (kits, celebrations) and a season pass. **No real-money gaming**:
      India's 2025 online gaming law bans it, so keep anything that looks like betting or paid contests out.
- [ ] Licensing (optional, later): a real league or player licence costs real money. Fictional teams keep that
      off the critical path.

## 6. Gameplay, after the 0.8.4 audit
Ideas ranked by how much they would add for the work they take.
- [ ] **A first raid that teaches**: the first Quick Match opens with one guided raid (cross, touch, get back),
      prompts on screen, so a new player learns by playing rather than reading How to Play.
- [ ] **Replays of the big moments**: a super raid, super tackle or do-or-die raid plays again from a second camera,
      slowed down (the match already records every event).
- [x] **A box score after the match** (0.8.5): each player's raid and tackle points, raids, successful and empty
      raids and tackles tried, the side's raid success rate, and the player of the match's numbers.
- [x] **Haptics on contact** (0.8.5): a short buzz on your touch, a firmer one on your hold, the strongest when you are
      held or brought down; lighter for a team-mate's hold; none for the AI's match behind the home screen.
- [ ] **Daily and season challenges**: "win a raid with a lion jump", "a super tackle with Kenya", for a reason to
      come back each day.
- [ ] **Commentary lines in each language**, written first (on screen), voiced later.
- [x] **A 60 fps cap and a battery saver** in Settings (0.8.5), for phones that run hot at 120 Hz.
- [x] **Bigger or movable buttons** (0.8.6), for players with large thumbs or small phones: three sizes (up to 1.4
      times), and Move buttons in Settings and the pause menu to drag each one where the thumb finds it.
