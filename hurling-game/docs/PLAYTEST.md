# Playtest: the game played in a phone's shape

Round two of the beta (0.2.0), 21 October 2026. The game was played the way a phone tester plays it: the Web export
in Chromium (Playwright, the pre-installed browser), touch emulation on, landscape, graphics on Low, every input a
touch on the real controls (a thumb held on the joystick, the other tapping the buttons; never a call into the
game). Matches were played through to full time by a script that reads what is on the screen (the buttons and where
they are, your player, the sliotar, the goal: `game/playtest_hook.gd`, only with `?playtest` in the address) and
touches the screen as a player would: run to the ball, CATCH or LIFT it, SOLO before the fourth step, STRIKE for the
posts in range, GOAL close in, TACKLE the man on the ball, SWITCH when the ball is far away, take its restarts. A
screenshot every 20 seconds, at every score and every restart; each was looked at.

The browser drew the game in software (no GPU in the sandbox), at 3 to 8 frames a second: the match ran in slow
motion (the game steps at most 1/20 s a frame), so each played match took an hour or more. Frame rates here say
nothing about a phone's; `tests/perf_probe.tscn` and a real phone do.

| Played | Screen | Result |
|---|---|---|
| Quick Match (Throw-in), Kilkenny v Tipperary, the parish field, 8 minutes, Intermediate, coach's tips on | 1280 × 720 | to full time: 1-5 v 0-9 |
| Quick Match again, the county ground, after the fixes below | 1280 × 720 | see below |
| The Summer Championship, a group match | 1600 × 720 | see below |
| The Tier Two Cup, a group match | 2400 × 1080 | see below |

## What was wrong, worst first

| What was seen | Why | What changed | Test |
|---|---|---|---|
| A full-length match scored twice a real one's (5-34 v 5-46) | The ball was live for about 80% of the 70 minutes; in a real match it is live 38% | Stoppages cost their real time on the watch; the 35-minute length is the full 70 with the ball live as long as in a real match (docs/AI.md) | `tests/score_check.tscn` in CI, at every length |
| Your side scored nothing from play in the first match: the man on the ball ran and ran and never struck | Not the game: the test's own touches. Chrome's touch emulation lifts the first finger when one of two lifts, so the joystick thumb came up and the tapping finger stayed down, and every later tap was lost. Found by logging the page's own touch events | The playtest script lifts both and puts the joystick thumb back down. The game's two-thumb play (joystick held, a button tapped) was checked by hand in the browser: the button fires | - |
| The coach's card covered the PASS button | It sat in the middle at the bottom, 600 wide | It sits between the joystick's side and the nearest button, wherever the buttons are moved, at any size, either hand | "the coach's card clear of every button" |
| The keyboard's letters (Space, J, K, Q) on the buttons in a phone's browser | They showed whenever the game was not an Android build | Gone once the screen is touched | "no keyboard hints ... once the screen is touched" |
| A floodlight mast stood in the foreground, a grey pillar across the play near the goal, at the parish field and the county ground | The near side's masts stood between the camera's gantry and the field | They stand behind the gantry, out of the picture | "no floodlight mast in front of the camera" |
| Above the trees, on every ground, a brown band where the sky should be | The camera looks down from the gantry into the sky's ground half, left at Godot's default brown | The horizon's own haze (grey-green by day, lilac at dusk) | "the horizon's haze, not the sky's default brown" |
| The parish field at dusk nearly black around the field on Low | The hills and the sky's ground dark, with no fog on Low to lift them | Lighter hills and haze | (a look: venue_view) |
| No sideline cuts in a match (one in seven AI matches; a real match has a good many) | The ball hardly ever went out over the sideline: passes aim inside, nobody cleared it | A back hemmed in near his own goal, or anyone pinned on the sideline with no pass on, drives it over the sideline: about ten cuts a full match | score_check: "sideline cuts" |
| A high ball was hard to judge: a white dot against the stand or the sky, no way to tell where it would come down | Only the ball was marked | A gold ring on the grass where a high ball near you comes down to hand height | "a high ball is marked where it comes down" |
| A chip dragged over when scrolling stayed lit, as if chosen | Android (and a phone's browser) leaves the emulated mouse where a finger lifts, so the chip stayed "hovered" | No hover look on a touch screen | "no hover look on a touch screen" |
| Match setup forgot the ground: back to the county ground every time | The choice was not saved | Saved | "match setup remembers the ground" |

## What a first-time player meets

- **The first minute.** Before the throw-in the coach's card says the game in three lines (drag on the left to run,
  the buttons come up as you need them, over the bar a point, in the net a goal). Then a tip the first time each
  thing happens: the ball near you (CATCH, LIFT, PULL), in your hand (four steps; SOLO), on the hurley (STRIKE,
  PASS), in range, close in (GOAL), a tackle, your puck-out, your free, too many steps. Each once, six and a half
  seconds, in English and Irish, fit_audit clean.
- **No buttons at the throw-in.** Until the ball is thrown in there is nothing to press; the coach's card covers it.
- **The buttons** sit where a right thumb rests: STRIKE, the biggest, in the corner; PASS to its left; SOLO, HAND or
  GOAL above; SWITCH small, higher up. Nothing in the screenshots was ever under the score bug, the camera or the
  pause button. Settings > Button size and Move buttons are there for other hands.

## Following the sliotar, striking, soloing, catching

- **In the air**: the white dot with its dark rim reads against the grass, the crowd and the stands at every
  ground; off the screen an arrow at the edge points to it; its shadow on the grass shows where it is over the
  field. With the ring where a high ball comes down, a long puck-out can be run under and caught.
- **Striking**: STRIKE with the joystick toward the posts (or let go of it) is the shot; pushed elsewhere, a long ball
  to the teammate that way. In the screenshots the strike is a full swing from the hand or off the hurley, and the
  umpire's flag goes up for the point.
- **Soloing**: SOLO puts the sliotar on the hurley (it rides on the bas, hopping); the dots over your man count his
  steps in the hand. With Help on Solo he does it himself before the fourth step.
- **Catching**: CATCH when the ball is near and above the knee; LIFT when it is on the ground; a rival in the
  contest makes it a fifty-fifty, a fumble breaks it loose.

## Still to look at

- On a real phone: the frame rate on Low on a 2-3 GB Mali-G52/G57 phone, and how the buttons feel under real thumbs
  (this playtest could only touch where the buttons are, not feel them).
- Players of the match from the losing side when the winners scored less (the scorer of 1-5 in a one-point defeat
  was named): arguable either way, left as it is.
