# The beta: installing and testing

## Install

1. On the phone, open https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/khamba-dash-beta.
2. Tap `kho-kho-rush-<version>.apk` under Assets.
3. Open it when it has downloaded. If Android asks, allow your browser (or Files) to install unknown apps.

Each new beta installs over the last and keeps your saves. It runs on 64-bit Android phones, which is every phone sold
since about 2019. The Play bundle also carries a 32-bit build for older Android Go phones.

## What's new in 0.12.4

- **Everything round the field is solid** (the owner: "every asset was built to be a tangible object"). Nobody -
  chaser, defender, umpire or anyone walking off - goes through the poles, the officials' table, the teams'
  benches, the barricades, the tents' poles, the arena's boards or anything else: a defender who is out walks
  round the table and the tents to his place in front of his bench, a dive slides round the pole, an overrun stops
  at the barricade. The foundation's prop check plays a match at every ground and measures every body every frame;
  the build fails if one is inside anything.

## What's new in 0.12.3

- **A smoother start.** The loading screen now also gets the match's graphics ready behind it, a few at a time, and
  waits until the match runs smoothly before it goes, so the first second of play no longer stutters (the first
  frame of a match was over half a second on its own). The match's files are fetched while you are on the home
  screen, and the clock starts only once you can see the play.

## What's new in 0.12.2

- **A loading screen on every Start.** Quick match, the toss, a championship match and Watch AI: "Loading…" and a
  bar come up the moment you tap, and the match is built behind it a piece at a time, so the phone never looks
  frozen (the foundation's shared loading overlay).
- **The arm no longer sticks out.** After a touch or TAG the chaser kept his arm out, standing or running: a reach
  never ended. It ends now.
- **Tags that look like tags.** A chaser right next to a runner gets him far more often, his hand reaches a little
  further, and when the runner does escape he is seen twisting away (instead of the hand passing through him).
  Outs a minute stay as in real matches (classic 1.46, fast 1.57).
- **The pole dive**: his reaching arm a little bent and only for a runner close by, not thrown out at full stretch.
- **TAG never over KHO**: a button place saved for another button (TAG took POWER PLAY's slot) is no longer used if
  it would overlap.
- **The foul whistle**: two blasts when the umpire calls it, then a reminder every 2.5 s while it stands (it was a
  whistle every third of a second).
- **No replays of tags.** Pole turns and near things are still shown again on Medium and High.
- **The birds at the school** barely there now.
- Out defenders kneel in front of the teams' benches, not inside them.

## What's new in 0.12.1

- **A mixed crowd.** A stand of one seat height was the same person over and over; now every fan who fits the seat
  is picked, more men among them, and skin and hair are coloured only where they are skin and hair.
- **Feet flat on the ground** (Medium and High): if the players' boots rest toe-up, their feet are turned down so
  the soles lie on the ground in every move (the foundation's fix from the hurling game).

## What's new in 0.12.0

- **The crowd, sitting and standing properly, at every ground** (the owner's rule for every game). Every seat,
  step, bench, chair, plank and standing row round each ground is now declared to the World Stage Games
  foundation, which places each fan: seated fans sit on their seat (not in it, not floating) with their legs down in
  front of it, standing fans have their feet on the ground behind the barricades, and everyone faces the play. The
  same at every graphics level, Low included (no draw call more). The foundation's crowd check measures every fan
  at all four grounds, on Low and High, and the build fails if one is wrong.
- The fans' shirts: mostly everyday whites and pale colours, some in the home side's colours.

## What's new in 0.11.3

- **Outs back where they were.** 0.11.2's solid bodies pushed a defender on, away from the chaser's hand, every time
  they met, and the classic game's outs fell a fifth. Now the chaser gives way to the defender, so they still never
  pass through each other.

## What's new in 0.11.2

- **The stick follows the camera, in every view.** Up on the stick runs him up the screen, right runs him right,
  whichever camera you pick: behind the pole and close-up too (it went the wrong way off the side view). Changing
  the camera mid-run eases the stick round over a fifth of a second instead of turning him in a frame.
- **TAG**: a third button when you chase. Not every tag is a dive: his arm goes out for the nearest defender in
  reach and he stays on his feet. DIVE is still there for the full-length dive (one arm reaching).
- **You play your defender.** Thumb off the stick, he stands where he is: nothing runs or dodges him for you.
- **No more ghosts.** A runner can no longer run through the seated chasers or through the chaser; he steers round
  them and bodies push apart instead of passing through each other.
- **No floating, no baby steps.** Reaching for a touch at walking pace, his legs walk; slow walking no longer
  shuffles his feet faster than he moves.
- **The crowd**: the seated fans sit on the front of their step, legs down it, not sunk into the seat. At the school
  ground the children at the barricade stand on the grass (they looked like they were sitting on chairs no one
  could see). A new crowd loop: the old one had a repeated chant that sounded like an English word.
- **Quieter birds** at the school ground.

## What's new in 0.11.1

- **A diving tag** (the owner: "it's not a dive for nothing"). The chaser dives at the runner: one arm fully
  stretched out for his leg (the arm on his side), the other bent down under the shoulder to take the landing, his
  body stretched out after the reach. When the dive touches him, the hand ends at his leg and stays there as the
  chaser lands. On every graphics level (Low draws it as before, Medium and High lay it over the shared rig).
- **A natural get-up.** Both hands push his chest up off the ground, his knees come in under him, one foot comes
  forward, and he rises off it through a crouch. No snap, no pop: his hips only ever rise on the way up.
- **Watch AI** (the owner's request for every game): the home screen's "Watch AI" picks the two teams and plays a
  full AI match on the broadcast camera, with the score, clock and replays, pause and leave, and a 1× / 2× button
  beside pause. In all 14 languages.
- Behind the scenes: the game's Mixamo-derived animation clips are no longer in the public repository. Each build
  fetches them from the owner's private assets.

## What's new in 0.11.0

- **The World Stage Games foundation** (the pilot the owner played, now the beta): on Medium and High the players
  and umpires run, walk and stand with motion capture on the shared rig, the dive, pole turn, kho and the rest laid
  over it as before; replays at an out or a long survival; the Galaxy A16 starts on Low, which is unchanged.

## What's new in 0.10.4

- **Every ground built all the way round.** From behind the pole you could see that the near side (where the
  broadcast camera stands) had nothing on it: black space in the arena, bare earth at the stadium, empty field at
  the village and school. It now has stands full of people indoors and at the stadium, and at the grounds a crowd at
  the barricade the whole way along, with tents and flags behind them. It is drawn only from behind the pole: the
  other cameras stand in it, so it would block them, and they never see it.

## What's new in 0.10.3

- **A real dive.** Rebuilt by hand the way Kabaddi Raid's dive is, instead of the recorded dive into water (which,
  it turned out, left him leaning on one leg about half a metre off the ground the whole time). He takes off from his
  stride, flies out flat with his arms reaching ahead, lands on his front with his head up, slides to a stop, pushes
  up onto his hands and knees and gets to his feet through a crouch. Nothing of him goes into the ground, and he is
  down no longer than before.
- **Running at a real pace.** The run was recorded at a jog and was being played nearly twice as fast to keep up
  with a sprint: over five steps a second, like fast forward. Faster than a jog, his stride now lengthens more than
  it quickens, as a runner's does: about four steps a second at full speed.

## What's new in 0.10.2

- **Saves when the phone puts the game away.** Your settings and the championship in play are written the moment
  the game goes to the background (a call, the home button), not only when you leave a screen.
- **Move buttons from the pause menu** no longer stops the game if the match ended while you were moving them (found
  by the new monkey test, `tools/soak.sh`).
- Behind the scenes, for Google Play: the store pictures and the media kit are made by a script from the build
  (`tools/store/make_kit.sh`; the media kit with its trailer by `tools/store/make_media_kit.sh`, which CI runs and publishes on the `kho-kho-rush-media` release), and every Play Console answer is written down (`store/PLAY_CONSOLE_ANSWERS.md`).

## What's new in 0.10.1

- **Dives stay above the ground.** The diver lies level on the ground (his body is laid flat from where the dive
  animation already leans him, and lifted by however far any part of him would go under).
- **The pole turn at a real pace:** he slows to take hold, swings round in about half a second and comes out at a
  jog, not spinning round at full speed.
- **No more gliding.** A chaser slowing into a kho, or reaching for a defender on the run, now keeps his legs moving
  (only his arm reaches); a diver gets up where he lies. The tests now fail if anyone moves at a run's pace with his
  feet still.

## What's new in 0.10

- **The pole turn**, from the owner's video: the chaser takes hold of the pole, swings round it close and lets go
  running down the other side, faster than he came, instead of braking and turning about.
- **Dives land.** The diver goes down flat on the ground, slides, gets to his knees and stands; he no longer hangs in
  the air or runs straight off.
- **Tags you can see, and difficulty that bites.** A chaser's arm goes out for every touch he gets to, landed or
  not. On State and International the AI's chasers catch your defender far more often.
- **The camera:** a camera button beside pause changes the view at once, named as it changes. Three views that
  differ: the broadcast, a low close one and behind the pole. The pause menu's button now works too.
- **Difficulty** at the top of Quick match, and in the Championships.
- **The crowd follows the play**, turning to watch the chase as it moves, and its roar builds as a chaser closes in,
  in a dive and late in a turn, with an "ooh" at a near miss.
- **Sounds:** the kho is the slap of a palm (the raised "hup" over it is gone); birds and crickets quieter.
- The "Kho kho · the real rules" line is gone from the home screen.

## What's new in 0.9.3

- **Licences, Help and Privacy policy in the game.** Settings > About has three buttons that open screens inside the
  game, which work offline: the licences and every asset's credit; how to play, the controls, the rules in brief,
  the graphics levels and how to report a bug; and the privacy policy (nothing collected, no ads, no analytics, no
  internet permission). The old buttons opened web pages that were not online (404).

## What's new in 0.9.2

- **The crowd watches the game.** Spectators at the ends and on the scaffold stands showed their full front to the
  camera, so they seemed to be watching you rather than the play. Each is now drawn as the camera sees him: from the
  front, from behind, or turned three-quarters toward the court.

## What's new in 0.9.1

- **More from the real grounds:** scaffold stands full of people at the ends (both ends at the school, one at the
  village), people standing at the barricades at the ends and on the near side, and at the school a second court
  next door, an electronic scoreboard on a scaffold, and a green and white umbrella over the scorers' table.

## What's new in 0.9

- **The outdoor grounds dressed for a tournament**, as at the two real matches: steel barricades between the court
  and the crowd, white tents over the teams' benches, flags on poles and printed banners on the barricades. The
  village ground has a stage behind the crowd (guests, a lit backdrop, trophies, speakers) and two towers of lamps;
  the school has green turf round the court and bunting over the crowd.
- **The crowd in everyday clothes**: whites, pale shirts, dark colours and some bright saris and kurtas, with a few
  fans in their side's colours, instead of everyone in team colours.
- No change to how the game plays. docs/GROUNDS.md has the details and the cost.

## What's new in 0.8

- **Defenders who play like the real ones**, learned from two real matches: a defender out of danger stands and
  watches the chase (his head following it), and moves only when it comes his way, instead of jogging about. The
  one under threat still dodges tight round the pole and the seated chasers.
- **A chaser with a foul** goes straight for the kho or the pole that puts it right (his touches don't count until
  then), and the foul's bar no longer stays on screen after the foul is over.

## What's new in 0.7.1

- **Real referee whistles**, from where the officials stand: the timekeeper's long whistle and a short one to start a
  turn and a long one to end it, a short pip from the umpire for an out, pips again and again until a foul is put
  right, the final whistle (short, short, long) at the end of the match, and in the hall a whistle with the gym's echo.

## What's new in 0.7

- **Sharper on Medium and High graphics:** the grounds' photographs at twice the detail, the players'
  kit, skin and faces sharper, a crowd of sixteen different people (skin, height, shorts, how they stand), and on High
  sharper skies. Low is exactly as it was.
- **Longer sounds:** the crowd's murmur and the birds at the school run longer before they repeat; cheers and
  applause come in more than one take.

## What's new in 0.6

- **Real recorded sound:** footsteps where the players run (on the earth, or the hall's mat), the slap of a kho, a dive
  landing, a real crowd's murmur and cheer, applause, crickets at the village's dusk and the stadium's night, birds at
  the school's noon, and a little of the hall's echo indoors. A pause now holds every sound until you carry on.
  Where each sound comes from: docs/SOUNDS.md (and the Licences screen).

## What's new in 0.5

- **Real recorded movement** for two moves, from a motion capture library: **DODGE** is now a runner's hard cut, the
  outside foot planted and a low push off (the AI's defenders dodge the same way), and a player or umpire **standing
  still** stands at ease, shifting his weight, instead of frozen.

## What's new in 0.4.2

- **The crowd faces the play** on every side. The near side's spectators, between the broadcast camera and the court,
  used to face the camera; now you see their backs, watching the match.

## What's new in 0.4.1

- **A village temple** at the edge of the village ground: a whitewashed shrine with saffron and red stripes.

## What's new in 0.4

- **The grounds, from photographs:** real skies (a village dusk, a school's hot noon, a lit night), photo-scanned red
  earth and dry ground, rain trees, coconut palms and tropical trees, dry grass, houses in clay plaster under thatch
  and tiles, white plastic chairs under the village crowd's front row, painted benches, a scorers' trestle table,
  apartment blocks behind the school and on the stadium's skyline, concrete terraces, fluorescent lights in the hall.
- **High graphics** no longer looks washed out.

## What's new in 0.3

- **The game is now Kho Kho Rush**, with a new icon. Its Android package changed with the name
  (`com.khokhorush.game`), so 0.3 installs beside the old Khamba Dash beta rather than over it: uninstall Khamba Dash
  (your old saves go with it). From 0.3 on, each beta installs over the last again.
- **The home screen:** one row of buttons.
- **Watch a Match:** the pause button (top right) is there now; its menu has Quit match.
- **The toss:** the coin shows a lion's head for heads and the value for tails, in your language's currency.
- **DODGE** is a real side-step now, and a touch during it mostly slips off.
- **New players:** the owner's athlete model with Mixamo animations: the sprint, the kho (a reach to the seated
  chaser's back), the dive, the turn round the pole, kneeling in the lane; umpires signal on the same model.
- **New grounds:** trees and palms, houses and haystacks, hills and a sky, light towers, the hall's roof and screen,
  and a crowd drawn from the players themselves, up on its feet at an out.

## What's new in 0.2

- **Coach tips** for your first match (Settings > Coach tips turns them on again).
- **The City League**: eight invented city sides, home and away, then the semi-finals and the final.
- **Fixed from a phone playtest** (docs/PLAYTEST.md): your defenders walk on in time; with your thumb off the stick
  your defender runs himself; a chaser pushed into the lane runs along it; KHO can be pressed a moment early; the
  gold arrow shows your way; clearer chalk on Low; no keyboard hints on a touch screen.
- **Rules:** a foul now stands until the chaser gives a kho or reaches a free zone, as the rule books say.
- **Motion:** a hand-on-the-pole turn, and seated chasers' heads follow the play.
- A new icon.

## What to try

- **The new players and grounds.** Do the players look right running, diving, kneeling? Is anything stretched or
  through the floor? Does the phone stay smooth on Low and Medium?

- **The home screen.** One row of buttons over a match the AI plays: can you find everything at a glance?
- **Chasing.** You are the active chaser in gold.
  - Run up behind a seated chaser who faces the other way. When his square lights up, press KHO.
  - Touch a defender, or DIVE at one. In the free zone behind a pole, DIVE is a pole dive.
  - With Settings > Lane assist off, try turning back or crossing the lane: the umpire should whistle until you put it
    right.
- **Defending.** Run your defender behind the active chaser; DODGE and SWITCH. Can you last a minute? Three, for a
  dream run in the fast game?
- **Both rule books.** Classic and Fast, with the real turn length, and the follow-on when you lead by 9.
- **Your first match.** With coach tips on, did you know what to do within a minute? Which tip was unclear?
- **The City League.** A full season: does the table read right (3 a win, 2 a tie, 1 for losing by 3 or fewer)?
- **A championship.** World (fast rules) and national (classic rules), men's and women's, through the knockouts. A
  tied knockout goes to extra innings, then minimum chases.
- **Scrolling.** Drag any long page (How to Play, Settings, the tables, the licences) from anywhere on it, its words
  included.
- **Your language.** Check every screen. Note any word that is wrong, cut off or too long; the translations need a
  native speaker (docs/LANGUAGES.md).
- **Move buttons.** Settings or the pause menu. Drag the buttons, and check they stay where you left them.
- **A budget phone.** Does it stay smooth on Low? Does the phone get warm? Try Settings > Frame rate > Battery saver.
  Seven taps on the version in Settings > About shows the frame times.

## Report

Email joshnason8@gmail.com with the phone's model, what you did and what happened. A screenshot helps.
