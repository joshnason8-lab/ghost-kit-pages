**New in 0.14.25: the scorers' legs are their own.** On Low the scorers seated at the table keep their sitting
pose's legs; the foot planting no longer tries to plant a seated scorer's feet.

**In 0.14.24: a guard on knees.** A new automatic check plays a match on Low and on High and fails the build if
a knee bends backwards (outside dives, holds, jumps and falls). On Low every knee now bends forward.

**In 0.14.23: knees bend the right way on Low.** On Low graphics the shared foot planting could bend a
player's or official's knee backwards (most bodies, 20-32 cm behind the leg's line). It now works out which way each
rig's thigh faces, so knees bend forward. Medium and High were not affected.

**In 0.14.22: the trophies shine on Low.** On Low graphics the Nations Cup and the Underdog Trophy drew almost
black (a mirror finish with no sky to reflect); now they read gold and silver. The winners' name and the Underdog
Trophy's line are outlined, so they stay readable over the boards behind them.

**In 0.14.21: a smaller player's catch-up steps no longer snap.** The shared foot planting no longer holds
back a catch-up step on a slightly smaller body (it was read as too small to be a step, then snapped a frame later).
Nothing else changes; on Low a planted foot drifts at most 0.9 cm in a step, as before.

**In 0.14.20: Break free always answers.**
- **No dead presses**: held, after a lion jump out of the hold failed, Break free did nothing for 1.4 s - as long as three
  defenders take to bring you down, so every press after the first was lost. Now a failed try has you back trying a
  quarter of a second later, a press made while a try is still going is kept and made the moment it is over, and the
  Break free button dims and fills with a gold ring while the next try comes back. Breaking free is as hard as before:
  mashing it still gets you out of about 1 hold in 3 (measured over about 150 holds before and after).
- **Braced, not standing up**: caught out of the raid's low stance or a touch's lunge, the raider sinks into his brace
  instead of standing up into it (his middle rose 9 cm as he was grabbed; now it is 5 cm below his raiding stance).

**In 0.14.19: steadier feet in the other World Stage games' corner cases.** The shared foot planting is
corrected for bodies with their own contact rule (other games' officials); in Kabaddi Raid nothing you would notice
changes. (On Low a planted foot can drift up to 0.9 cm in a step, as in 0.14.16.)

**In 0.14.18: getting up without flinging the arms.** A defender who has held a raider on the floor and lets go
to get up brings his arms back from the hold over a third of a second, instead of flinging them back in a tenth (his
hands were moving at 10 m/s; now about 5).

**In 0.14.17: feet that land and stay.** On every graphics level, a foot coming down at the end of a step is held
where it touches the floor from the moment it touches, instead of a frame later: players and officials stopping,
starting and turning no longer slide a landing foot a few centimetres along the mat. On Low, a walking player's planted
foot now moves half a centimetre at most (it was nearly one).

**In 0.14.16: officials move like officials.** An umpire hurrying along his line to keep up with a raid turns and
jogs that way, as real officials do, and turns back to face the play as he arrives; facing the play he only steps
sideways or back slowly (up to 1 m/s). He used to scuttle sideways at a jogging pace with his feet sliding under him.

**In 0.14.15: cleaner steps.** On every graphics level, a player's foot taking a step keeps its toe off the floor until
it lands, instead of scraping the mat on the way, and a foot let go after one of the game's own moves (a dive, a hold,
a kick) starts stepping again cleanly. A player or official put in a new place between raids takes his feet with him
rather than leaving them on the old spot (Medium and High).

**In 0.14.14: feet that stay put on Low (the A16's setting).** On Low graphics the players' feet no longer slide
along the floor as they walk, jog, turn and stop: a foot that comes down stays where it lands until it lifts, as on
Medium and High. (Measured on the test walk: a planted foot moved 2-7 cm a step and a flat foot up to 6 cm in a frame;
now 1 cm at most.)

**In 0.14.13: steadier stops.** On Medium and High, a player stopping hard from a run plants his feet where
they land instead of one foot lurching after him.

**In 0.14.12: feet that step, not slide.** On Medium and High, a foot taking its own step moves evenly across
the floor instead of in a lurch, and a foot let go after a stop lifts at once instead of gliding along the floor.

**In 0.14.11: Android only.** The browser version of the game is retired: it is no longer built, and its page
(kabaddi-raid-beta.netlify.app) is being taken down. The Privacy policy in Settings > About no longer mentions it.
Nothing changes in the Android game.

**In 0.14.10: steadier feet.** A player stopping or turning sharply no longer has a foot jump a stride along
the floor; a foot set down while still easing into place stays where it lands.

**In 0.14.9: tidier arms, and a lighter village.**
- Defenders and raiders shuffling sideways keep their hands out in front, elbows bent, as kabaddi players do; they
  were holding both arms out straight to the sides.
- The village draws fewer things each frame on Medium and High (the houses' sun shadows were drawn twice). It looks
  exactly the same.

**In 0.14.8: smoother on Low (the A16's setting).**
- On Low graphics each player and official is drawn with about a quarter of the detail (still the same people, the
  same kit and the same floor shadow - side by side you cannot tell them apart from the match cameras). A frame on
  Low now draws about 140,000-180,000 triangles instead of 625,000-665,000, over three times less work for the phone.
- Feet: players stopping hard from a run no longer have a foot snap back along the floor, and a foot lifted after a
  step no longer jumps.

**In 0.14.7: the game checks itself.** Nothing changes in how it plays; what changed is how it is tested.
- Every build now plays whole matches by itself, hundreds of them from numbered seeds, faster than real time, and
  checks every frame against kabaddi's rules (who is out and in what order they come back, raid timing, the lobby,
  do-or-die, the score) and for anyone stuck, inside the furniture or standing oddly. Any match that goes wrong can be
  replayed exactly from its number.
- Your notes are now permanent tests: the stance twitch, the tag buzz for raider and defender, the stick on both
  cameras, the news ticker, the crowd in their seats, the get-up twitch and bow legs are each checked on every build,
  and a build fails if any of them comes back.
- The shared World Stage checks (props, crowd, feet, poses, officials, key sounds, loading, the stick, the web build,
  the graphics levels) run on every build too.
- On a keyboard (the web version), Escape now pauses a match.
- Fixed, found by the new checks: a defender settling into his place in little starts and stops jerked his knees
  (your "guy is twitching" note - it still happened now and then); and a match paused by leaving the app during the
  full-time celebration could not be resumed with the back button.

**In 0.14.6: nobody walks through the furniture, and a smoother start.**
- **Solid props**: players and officials walk round the benches, the scorers' table, the chairs and stools, the
  boards and the stands instead of through them. Out players walk to the front of the bench and sit on it; when
  revived they stand forward off it. Checked in every ground over whole matches.
- **Loading**: the match is drawn for the first time behind the loading screen, a little at a time, and the screen
  stays until play runs smoothly; the next match's ground starts loading while you choose it.
- **A smaller download**: the crowd's Medium and High pictures take a third of the space (the APK about 19 MB smaller).

**In 0.14.5: a loading screen the moment you tap Play.** Tapping Play, Watch, a cup or season fixture or a lesson
now dims the screen at once with "Loading…", a spinner, a bar that fills as the match is built, and a tip to read; the
buttons stop answering so a second tap can't start a second match. On a slow phone the wait no longer looks like the
game has frozen.

**In 0.14.4: the crowd claps and watches on Low again.** On Low graphics the fans clap in time with the clapping
you hear and turn their heads to follow the raider, as they did before 0.14.3 (the shared crowd now has those poses).

**In 0.14.3: the crowd, seated properly on every ground.** Every spectator is now placed by the shared crowd
system all the World Stage games use: each ground's stands, chairs, stools and standing room are declared, and every
fan sits on their seat (not in it, not floating), has their feet on the floor or the step below, faces the court, and
stands up properly when the crowd gets to its feet. It is checked fan by fan on all five grounds.
- **Low**: our own Indian crowd (the same people, front and back), sitting, standing and cheering, placed on the seats.
- **Medium and High**: the fans nearest the court are full 3D people who sit, clap with the clapping you hear, get up
  and cheer, and turn their heads to follow the raider; the rest are the same cards as on Low.
- The plastic chairs and stools at the village, the beach and the monsoon ground stand exactly where the fans sit;
  the standing crowd at the village and the beach stand in a line behind the chairs instead of between them.

**In 0.14.2: your list.**
- **No news ticker**: the headlines scrolling along the foot of the home screen, the season and the cup are gone (the
  season and cup still have their front-page story).
- **The crowd sits**: the fans in the stands are drawn sitting, knees forward and laps showing, from a little above as
  the camera sees them; they read as people standing sunk into their seats before.
- **Tagged on defence**: when the raider tags you, the phone gives a firm double buzz; a tag on a team-mate, a light one.
- **Getting up**: no more leg twitch. A defender gets up from a dive at a human pace (his get-up was playing at up to
  2.4 times its speed, the stepping leg flicking), a one-frame knee jerk as he was slid aside is gone, and he rises into
  his crouch instead of standing straight up and dropping back into it.
- **No bow legs**: runners' knees stay over their feet (the captured runs had the knees out by up to 14 cm).
- **The chant**: "kabaddi, kabaddi" in a natural Indian voice instead of the robotic one.

**In 0.14.1: the stick goes where you push it, all over the screen.** Up on the stick moves your player up the
screen, right moves him right, and so on, wherever he is on the screen and in both cameras. Toward the edges of the
screen the camera's perspective had turned the stick by up to 24 degrees (pushing straight up sent him off at an angle);
now it is exact. Switching camera mid-move eases the stick round instead of turning him on the spot.

**In 0.14.0: real movement on Medium and High, replays, and a buzz for your points.**
- **Medium and High**: the players, referees and scorers are drawn on a new shared body rig with motion capture of
  real people for walking back to their half or the sitting block, standing between raids and the referees walking
  their lines. Every kabaddi move (the stance, cant, touches, dubki, lion jump, dives, holds and chains) is still the
  game's own. Low is exactly as it was.
- **Replays** (Medium and High): after a raid with a moment worth seeing (a super tackle, a super raid, an all-out,
  a do-or-die, an escape...) it is shown again, slowed, from beside the court. Tap to skip. Watching at 2×, a replay
  plays at normal speed and 2× comes back after it.
- **Vibration**: your raider winning the bonus point buzzes the phone twice, quickly; getting home with points, twice
  more strongly.
- **Auto graphics** picks the level for your phone a little more carefully: an A16-class phone starts on Low.

**In 0.13.3: Watch AI from the home screen.** The home screen has a Watch AI link: pick the two teams and the
ground, and the computer plays the match on the broadcast camera while you watch the score and the clock. A 2× button
speeds it up (tap again for 1×); pause and camera work as always. Settings > About > Licences opens at once and fills
in as you read (it froze for a second or more, and could crash the game now and then).

**In 0.13.2: a steady raider and seated fans.** The raider waiting at the line no longer twitches: he is set in a
proper ready stance, knees bent, leaning in, hands out in front, only his weight shifting slowly and his breathing.
Fans on chairs and stools sit on them (they stood through their stools, or slid off them), and seated fans in the
stands are drawn from a little above, the way the camera sees them, so their laps show.

**In 0.13.1: real players in the auction.** The player on the block is no longer a model from the game but an
outline of a real kabaddi player, traced from match and training footage, and every player has his own: raiders
reaching, lunging or kicking, defenders crouched ready, in their last team's colours.

**In 0.13.0: a livelier crowd, a raider who looks the part, and Watch.**
- **Watch**: Quick Match has a Watch button: the computer plays both sides while you sit back (pause and camera still work).
- **The raider** waits and works the cover in a low, bouncing stance, dancing from foot to foot and now and then poking a toe
  out in front, as raiders do (measured from training footage); he no longer stands straight-legged.
- **Break free** is no longer a sure thing: mashing it got a raider out of 4 holds in 5; now about 1 in 3, and each
  further try in a raid has less in it.
- **The crowd** turns their heads to follow the raider, claps whenever clapping is heard, and the fans seated in the Mumbai Dome and the
  other stands have their legs (the stands hid everything below the seat). At the Monsoon Ground the fans under the roof are
  in colour instead of black shapes, and the rain's haze is lighter.
- **Sounds**: a real crowd's gasp and groan, and real players' grunts, oofs and breaths, instead of the made-up ones; slower
  music: a tanpura and tabla in the menus, a tabla under matches.
- **Language**: the league's name on the boards and the court follows the game's language, and changes with it.
- **Screens**: Settings scrolls from anywhere you drag; Quick Match has smaller team cards, bigger grounds and bigger
  length and difficulty buttons. The names and numbers over players are off (Settings can turn them back on).
- **High**: sharper, softer-edged sun shadows.

**New in 0.12.3: ready for Google Play.** Saves are now written safely: if Android closes the game while it is
saving (in the background, or the battery dies), your season, cup and settings stay as they were instead of being
lost. The game was put through a long soak test (thousands of random taps, Back presses and trips to the
background on every screen, and AI-v-AI matches on every ground, on Low and on High). Gameplay and graphics are
unchanged.

**In 0.12.2: Help, Privacy policy and Licences in the game.** Settings > About opens all three as pages in the
game itself, with no connection needed: Help (how to play, the controls, the rules in brief, the graphics levels, and
how to report a problem), the Privacy policy (the game collects nothing and has no internet permission) and the
Licences (every asset source with its credit, and the Godot Engine's notices). Each has a View online button for its
web page as well.

**In 0.12.1: (0.12.0 slimmed to about 103 MB): sharper players, courts and crowds on Medium and High.** On Medium and High graphics the
players' faces, skin and kit are half as sharp again (from their models' own textures), the courts' mat, earth and sand are
sharper, and the crowd has twice as many different people: the Sikh fans in saffron and maroon turbans, women in
magenta, mustard, green and royal-blue salwars and sarees, girls in yellow and sky-blue frocks. The crowd's murmur
and each ground's rain, sea and birds now run two to three times as long before they repeat, the crowd cheers a point
three different ways, and claps and chants in time as a do-or-die raid starts. Low is exactly as it was. The download
is bigger (about 103 MB).

**In 0.11.1: one signing key, and a real referee's whistle.** Every beta from now on is signed with the same
key, so each installs over the last and keeps your saves. **Once only**: uninstall your current Kabaddi Raid
before installing this one (Android refuses it over the old key; uninstalling clears your saves). The referee now
blows a real whistle, from where he stands: a long blast as a raid starts and after a point, short pips after an
empty raid and for a card, two pips for a time-out, short-short-long at full time, and in the dome the blast echoes
round the hall.

**In 0.11.0: real sounds.** The crowd is now a recording of a real crowd, and it cheers, groans and applauds the
play. Players' footsteps sound on each ground's surface (the mats, the village's earth, Puri's sand), and tackles and
touches thud and slap from where they happen on the mat. Each ground has its own sound under the crowd: rain at the
monsoon ground, the sea at Puri, birds in the village, crickets outside the stadium at night. Settings has volume
sliders for Effects, Crowd and Music, and a paused match is silent. The sounds are CC0 and CC BY recordings from
kenney.nl and opengameart.org, credited in Settings > About > Licences.

**In 0.10.0: defenders creep in their crouch.** Creeping forward or back in their stance, the defenders now stay
low, knees bent, with short steps, from movement recorded from real people (the CMU motion capture library), where
they used to stand up and stride, or jog backwards in slow motion. Running in to tackle, they still run.

**In 0.9.1: the crowd faces the play.** The spectators nearest the camera, in the stand it looks over and round
the village and beach courts, showed their faces to the camera instead of to the court. Seen from behind, they now
show their backs, on every ground and graphics level.
