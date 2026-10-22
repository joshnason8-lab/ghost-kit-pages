# Floorball Unleashed: playtest of 0.1.0-beta, and what 0.2.0 fixed

October 2026. Before 0.2.0 the game was played the way a first-time player would meet it: the Web export (the same
project, single-threaded) in Chromium with touch emulation, driven by real touch events (two fingers: the left thumb
on the joystick, the right on the buttons), landscape at **1280 x 720**, **1600 x 720** (20:9) and **2400 x 1080**
(a 6.7" phone), on **Low** graphics. Full matches in Quick match and the World Finals, then the club season, screenshots every few
seconds and at every screen, each looked at. A software renderer runs the game at a third to a half of real speed,
so feel was judged from the screenshots and the state the game reported each tenth of a second (where the ball, your
player and the goal were on the screen), not from smoothness.

Ranked worst first. **Fixed** items have a test in `tests/test_runner.gd` where one could be written (named after
the check's text).

## Broke the game

| # | Found | Fixed in 0.2.0 | Test |
|---|---|---|---|
| 1 | **Your free-hit and hit-in could not be taken by touch.** While you lined up to take it, the buttons still said Tackle and Switch, and only Shoot or Pass took it, so a tap did nothing. The hint said "PASS or SHOOT" to buttons that were not there. Only the keyboard worked; 0.1 hid it by taking the free-hit for you after 13 seconds. | The buttons turn to Shoot and Pass as soon as the restart is yours; a tap on either place takes it. Kept waiting about nine seconds (a warning at six), the referee gives the free-hit to the other team (507.20, delaying a fixed situation). | "you take your team's free-hit", "507.20: a free-hit kept waiting goes to the other team" |
| 2 | **A penalty that ran out did not bring the player back.** The team stayed a player short (and the place empty) until the next goal or the next penalty, sometimes for minutes. | The match refreshes the penalty bench whenever a penalty ends or a team's strength changes. | "a penalty over: the team is whole again on the rink" |
| 3 | **Defenders never kept a ball they won.** A clean tackle freed the ball and the carrier, still on it, picked it straight back up the next frame, so a team without the ball could not get it; defenders stood round a carrier who was standing still. | A won tackle puts the ball on the tackler's blade, and the player who lost it cannot touch it for half a second. | "a tackle won keeps the ball" |
| 4 | **Shots were deflected almost every time.** A moving ball near a defender's blade rolled its 25% deflection chance every frame it was near (about ten rolls), and the block check did the same. | One try per player per strike (the ball remembers who has had a go); a block is checked once per defender per shot. | AI matches' shot and save numbers (test_runner `_matches`, tests/ai_bench) |
| 5 | **Stuck behind the opponents' goal.** With the ball behind their goal line, Shoot fired into the back of the cage and the ball came straight back; no defender pressed (the pressing spot was the far side of the cage, through it); and passive play was not called, because the ball was "in the attacking end". 50 seconds passed like this. | Shoot from behind their goal passes it out in front to the best-placed team-mate; the presser comes at a carrier behind his goal from the side; time behind their goal counts as passive. | "507.20: a team keeping the ball in its own end is warned of passive play" (and the passive play checks) |

## Hard to follow

| # | Found | Fixed in 0.2.0 |
|---|---|---|
| 6 | **The ball was all but invisible**: a 72 mm white ball on a light floor, seen from 25 m on a 6" screen, is two pixels. | Drawn 1.8 times its size, with a yellow ring on the floor under it and a short streak behind it when it flies. |
| 7 | **Your player was hard to find** among twelve: only the number above him was yellow, and the numbers were small. | A yellow ring on the floor under your player, your number bigger and yellow; everyone's numbers bigger. |
| 8 | **Low graphics showed the rink 40% darker** than Medium and High (the linear tone curve on Low): a murky blue floor under dark stands. | Filmic tone mapping on every level (in GL Compatibility it is a few instructions in the shader). |
| 9 | Nothing told a first-time player what to do. | The coach's notes (below). |

## Looked wrong

| # | Found | Fixed in 0.2.0 |
|---|---|---|
| 10 | The whiteboard's marker tray, bottom left of every menu, read as a stray scroll bar. | Gone. |
| 11 | In a phone's browser the keyboard's letters (␣ J K) sat on the touch buttons. | Off after the first touch of a real finger. |
| 12 | The coach's note (new in 0.2.0) overlapped the Switch button at 16:9. | Moved left, between the joystick and the buttons. |
| 13 | The penalised player vanished from the rink; the penalty bench stayed empty. | He walks to his team's penalty bench at the secretariat and sits there until his time is up. |
| 14 | Passive play warnings came too early once added (24 s with the ball anywhere short of the attacking zone). | 30 s, counting only in a team's own half or behind the opponents' goal; building play in their half holds the count. |
| 15 | In the club season, Midnight Owls (navy) against Granite Moose (charcoal) were two black teams: the clash rule compared colours only, and two dark shirts are far apart in colour but look the same under the hall's lights. | Two dark shirts count as a clash; the visitors change. Test: "kits: the two sides' shirts never look alike" (every pair of the 22 nations and 10 clubs). |
| 16 | In the interval the scoreboard already showed the next period ("Period 2" over "End of period 1"). | It shows the period just played until play restarts. |
| 17 | Running at the goalkeeper area (no field player may enter it, 2026), you were stopped a few centimetres inside it: the check looked 0.12 s ahead, less than a running player needs to stop. | It looks as far ahead as he needs to stop, and only from outside the area (from inside you can always leave). Tests: "2026: running at the goalkeeper area, you stop at its edge", "a player inside the goalkeeper area can run out of it". |

## Still open

- **Your team's shots are all yours.** As in most sports games you always run the team-mate with the ball, so your
  team shoots when you do. The test bot, steering by the screen and shooting only when close, took none in a World
  Finals match (Sweden 2-0 Czechia): a first-time player who does not shoot will see the same. The coach's second
  tip says when to shoot; whether a beginner needs more (an auto-shot on Rookie?) is for phone testing.

- **Goalkeepers wear black**, close to a dark team's shirts at a glance; their pads and the cage tell them apart.
- **Simulated club results run a little high** (8-5, 7-4 in a first round; real league matches average about ten
  goals between them).

- **The penalty benches and secretariat** at the bottom of the broadcast picture are plain boxes and take a strip of
  the screen at 16:9. They are where they are in a real hall; better models are a Meshy job (docs/MESHY_BRIEF.md).
- **The World Finals' tables** use 13-15 px text, readable on a phone held close but small.
- **The Web build picks High graphics** on a computer with a software renderer (the phone's detection does not run
  in a browser). Phones are unaffected.
- **Game speed**: at Real pace the play is fast for a first match; Steady (80%) stays the default.

## The coach (new in 0.2.0)

A first match has a coach: notes at the bottom of the screen, each said once, as its moment comes:

1. At the first face-off: you are the player with the yellow ring; slide your left thumb to run.
2. The first time you have the ball: Shoot near goal (and how to pick a corner), Pass to whom the joystick points.
3. The first time they have it: get goal-side and Tackle from the front; Switch.
4. Your first free-hit or hit-in: the 3 m, point and Pass or Shoot, it may go straight in.
5. The first whistle against you: the card at the top says what and why, with the rule; Pause for a time-out.
6. The first penalty: two minutes in the penalty bench, one player fewer, the timer under the score.
7. The first goal: the face-off at the centre spot.

Settings > Coach tips turns them off, or back on (all seven again). In all 15 languages, fit-audited at the four
screen shapes.
