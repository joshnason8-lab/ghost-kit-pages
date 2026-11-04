# The beta: installing and testing

## Install

1. On the phone, open https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/sepak-takraw-unleashed-beta.
2. Tap `sepak-takraw-unleashed-<version>.apk` under Assets.
3. Open it when it has downloaded. If Android asks, allow your browser (or Files) to install unknown apps.

Each new beta installs over the last and keeps your saves. It runs on 64-bit Android phones (every phone sold since
about 2019, the Galaxy A16 included).

From 0.9.1 every build is signed with the owner's beta key (certificate SHA-256 `6F:23:A9:36:…:69:7B:A3`, in each
build's log). The release page's builds of 0.6.0 to 0.9.0 had another key: if Android says the app wasn't installed,
uninstall that one first (its saves go with it).

## What to try

New in 0.15.28: **knees that bend the right way, and a ball that spins.** On Low, the players' and the referees' knees
had been bent backwards ("broken backwards knees") by the shared foot planter, which read the wrong way as forward on
our players' skeleton: in a ready stance, walking to fetch the ball, running. They bend forward again. The ball spins
faster in the air, and in the replays it now turns as it did in the point (it stood still before). Watch the ready
stance before a serve, the walk to fetch the ball, the line judges, and a replay.

New in 0.15.27: **menus that rest.** The menus (Quick Match, Settings, Records, How to Play, the season and cup
screens, the result, and the home screen on Low) are now drawn only when something on them changes, so a phone
sitting on a menu does far less work and its battery lasts longer. Taps, scrolling, the tiles fading in and the loading
bar all move as before. Matches, sepak raga and the home screen on Medium and High (with a match playing behind it)
are drawn every frame, as before. Tell us if a menu ever looks stuck or blank, for instance after switching back to
the game.

New in 0.15.26: **one touch is one touch.** Sepak raga's end card and the record book say "1 touch", not "1
touches". A polish pass on Low (every venue, sepak raga, the menus, the season and cup screens and the result, at
1600x720) found nothing else. Nothing else changes.

New in 0.15.25: **Sepak raga, the circle game.** On the home screen, next to Watch AI: six players in a ring at the
park keep the ball up with their feet, knees and heads, never letting it touch the ground. When it comes to you
(nearest the camera, your ring at your feet), tap as the ring closes on the ball, as in a match: on time it goes
on, too early or too late it falls. Your best run is kept in Records. Try it on every difficulty: the harder, the
tighter the timing.

Also new in 0.15.25: **feet that stay put on Low.** On Low, the players' feet are now planted by the shared
foundation's planter: a foot on the floor stays where it is as they run, turn, get to the ball and shuffle along the
net to block (gliding in our measure: 14% of the way to 4%; getting to a block: 35% to 1%). Medium and High are
unchanged. Watch the feet on Low as they run in to spike or block and as they come down from a kick.

New in 0.15.24: **a mixed season says so on the home screen.** The Continue card of a mixed quadrant season now
starts with "Mixed quadrant", as a mixed cup's already did. Nothing else changes.

New in 0.15.23: **the 3-serve rule on the scoreboard.** Playing the classic serve (Quick Match, The serve: Three
each), the scoreboard now shows which of the three serves it is under the serving side's ball ("2/3"); from deuce,
when the serve alternates every point, it goes. How to Play's rules on the serve mention the old rule too. Nothing
else changes in play.

New in 0.15.22: **the shared bodies' feet, a step further.** On Medium and High, a foot left a step behind as a
player stops is stepped across, and a foot catching up after a fast move no longer jumps. Low is unchanged. Nothing
else changes in play.

New in 0.15.21: **the old 3-serve rule, for the old-school.** Quick Match (and Watch AI) has a new choice under the
serve: alternate every point (today's rule) or three each (the 2013-2024 rule: each side serves three in a row whoever
wins the points, then one each from deuce). Goes well with 21-point sets, as it was played; in a third set to 21 the
ends now change at 11, as they did then. League Season and International keep today's rules.

New in 0.15.20: **the mixed quadrant in League Season and International.** Starting a season, pick the regu or
the mixed quadrant (two men and two women a side): in a mixed season every match is mixed, yours and the rest.
In International, the Royal Cup and the Southeast Asian Championship have it as a third event, after the regu
and the team event. How to Play's rules now state the format plainly. Worth trying a mixed season with your club.

New in 0.15.19: **on Medium and High, a landing foot plants at once.** A foot coming down from a step was
planted a frame late and could slide a few centimetres as it touched; now it holds from the moment it touches.
Low is unchanged. Nothing else changes in play.

New in 0.15.18: **on Medium and High, no sliding feet as a player moves off after a kick.** When a player set off
again after a kick, a set or a block, a foot could slide a few centimetres along the floor (up to 7 cm) from where
it had been planted before the move; now his feet start where they are drawn. A stepping foot's toe also no longer
skims the floor just before it lands. Low is unchanged. Nothing else changes in play.

New in 0.15.17: **How to Play's rules on the mixed quadrant.** The Rules page's "The regu" now says the mixed
quadrant is two men and two women a side, and that the mixed format varies by tournament (the game plays the SEA
Games and King's Cup way). Nothing else changes in play.

New in 0.15.16: **the mixed quadrant.** Quick Match (and Watch AI) has a fifth event: four a side, two men and two
women in each team - a man serving, a woman setting, a man and a woman striking - at the men's net, as at the SEA
Games and the Thai King's Cup. Pick it under Event; the Women's switch makes no difference to it. Worth trying with
your team and with Watch AI.

New in 0.15.15: **on Low, the line judges' feet stay put.** A line judge stepping out of the ball's way and back
could leave a foot sliding along the floor (up to 40 cm in a frame, now and then); on Low the judges now plant their
feet with the shared planter the Medium and High bodies use. Nothing else changes in play.

New in 0.15.14: **on Medium and High, a foot let go lifts off the floor at once.** As a player pulled up from a
run, the foot he was about to step with could slide a few centimetres flat along the floor (up to 7 cm) before it
lifted; now it rises from the first frame. On Low, a line judge stepping out of the ball's way now moves smoothly:
his steps were drawn only every other frame, so his feet jumped. Nothing else changes in play.

New in 0.15.13: **on Low, a player's foot steps instead of jumping.** On Low (where the Galaxy A16 plays), a foot
kept on the floor as a player moved past it used to be put down again a stride on in a single frame, a jump of 32 to
68 cm that read as a slide; that happened over 450 times in five minutes of a match. Now the foot lifts and steps
there, one foot at a time when he edges along slowly (a blocker in his crouch, a player shuffling under the ball):
nine such jumps are left in the same five minutes. Worth watching the blocker shuffling along the net, players
getting under the ball, and turns at a run.

New in 0.15.12: **no T-pose in the replays** (Medium and High). A player or official who had not moved yet when a
point began could show for a moment with his arms straight out in the slow-motion replay; now every body in a replay is
as it was drawn. Behind the scenes, a new beta is now put up before the old one comes down, so this page is never left
empty while a build is published.

New in 0.15.11: **feet stay planted when players stop or turn hard** (Medium and High). Pulling up from a run, a
player's foot could skate several centimetres across the floor in a single frame (up to 7 cm on a hard stop); now a
foot flat on the floor stays where it landed, and a foot let go lifts over the floor to its next step. Worth watching
players stopping to receive, and the blocker's shuffle along the net. And a line judge lowering his flag as he steps
back to his place no longer has his feet jump (up to 24 cm in one frame), nor a player taking or giving up the ball on
the move.

New in 0.15.10: **a ball hit hard into the park's fence no longer sticks in it.** 0.15.9's fix for balls behind the
boards could leave a ball, flying at the fence at waist height, caught in the wire; now it comes off the fence like any
other. Nothing else changes in play.

New in 0.15.9: **the ball no longer passes through the boards or the fence.** A ball that flew over the low LED
boards (indoor) or came down fast against the park's fence could end up back on the court side of it, as if it had
gone through; now it stays behind it, or comes off it. A player chesting the ball now bends his elbows and draws his
arms back, as players do, instead of holding them out straight. Found by the thousands of matches the game now plays
by itself each night.

New in 0.15.8: **in the national arena, nobody sits right behind the jury table's chairs any more.** A fan there who
got up to cheer put a knee into a chair in front of him; those few seats are now left empty, as they would be.

New in 0.15.7: **fans on their feet behind a glass barrier stand back from it.** At the mall's balconies a standing
fan's hands could reach a few centimetres into the glass; now they stand clear of it. Nothing else changes in play.

New in 0.15.6: **nothing new to see; more checking behind the scenes.** Every note you have given is now a test the
game must pass before each build goes out, and thousands of matches are played automatically every night to catch
bugs before you do.

New in 0.15.5: **a match no longer stops when the ball rolls behind a bench.** In 0.15.4 a ball that came to rest
behind a team bench left the player fetching it walking up and down in front of the bench, and the next serve never
came. Now he walks round the bench and picks it up. If the ball somehow can't be reached, the thrower is given it and
walks back to his place, as before 0.15.4. On Medium and High the players and officials are now there on the very
first frame of a match (they appeared a frame late), and the loading bar keeps moving while they are put on court.

New in 0.15.4: **everything round the court is solid.** Nobody walks through the referee's chair, the scorers' table,
a bench, the net posts or anything else any more: players and the line judges go round them, and the ball bounces
off them (a ball in play that hits one is out, as the rules have it). Starting a match now shows its loading screen
until the first frames run smoothly, so the match begins without a stutter, and the match is loaded while you pick
the teams.

New in 0.15.3: **no more gliding.** The players' feet now stay planted on the floor as they run, shuffle along the
net, back up and turn: a foot that is down stays where it was put down while the body moves over it, and the
stride keeps pace with how fast he goes. Sideways, a real step-and-close shuffle (before, the legs only swung while
he slid). A long way at speed, he turns and runs, then faces the net again as he arrives. Getting to the ball, to a
block or a spike, he arrives as his move begins rather than sliding into it, a blocker shuffles along the net upright
and folds into his crouch only to jump, and he finishes a kick before he runs off. The referees and line judges step
the same way.

New in 0.15.2: **a Start tap shows it is loading.** Tap Play (Quick match, Watch AI, a season's or an international's
next match, Next regu, Rematch) and the screen dims at once, with "Loading", a bar and a spinner; the button goes
off, so a second tap starts nothing. The bar moves until the match starts: the match is built a part at a time
behind it, so the phone never sits frozen on the menu. The first match after installing or updating takes longest
(the phone makes the game's graphics then, once); after that it is much quicker.

New in 0.15.1: **the fans on the near side are back**, seen from behind: from the broadcast camera, over their heads,
you now see their backs (0.15.0 hid them, as the shared cards had only their fronts, and from behind they turned to
slivers). The fans' faces are from their full models, and on Medium and High, where the shared motion capture draws
the players, the boots no longer rest toe-up if the rig's do.

New in 0.15.0: **the crowd sits properly, everywhere**, as the owner asked of every game. The spectators are now the
shared foundation's: in every venue each fan sits on their seat (not in it, not floating) with their feet on the floor
in front of it, or stands on the floor, and sits square to their row turned toward the court. Before, every fan's
whole body pointed at the middle of the court (up to 55 degrees off at the ends of the long stands) and seated fans'
feet hung down into the step below. What changed in the venues:
- The arena's steps have a seat pad at the front of every step, on every graphics level (Low had none).
- The mall's temporary bleachers are now the same aluminium bleachers as the provincial hall's, whose seats could be
  measured exactly. The near side has two sections, clear of the escalators.
- The fans are new: the six people shared by all the games, in many skin tones, hair colours, trousers and shirts
  (the home side's colours most), seated, standing and cheering. Flags of the two teams are still waved here and
  there.

New in 0.14.4: **the joystick goes the way you push it, on the screen, in every camera.** Push up and your player
runs up the screen; push right and he runs right, whether the camera is the broadcast one, side on or behind your end,
and wherever he is in the picture. Before, the stick only followed the camera's heading, which put it 24-33 degrees out
on the diagonals even in the middle of the screen and up to 56 near the edges. Aiming a kick or a serve follows the
screen the same way. When the camera changes, the stick's directions turn over about 0.2 s, so your player doesn't
swerve under your thumb.

New in 0.14.3: **the serve's throw is one-handed**, as the owner pointed out, and traced from the World Cup
broadcast. The thrower holds the ball in his right hand. When the serve is due he goes down into a crouch with the
ball held low in front of him, then drives up and swings it underarm to the server, letting go at chest height and
following through with the arm out level. In doubles, serving yourself, it is the same throw from standing. The serve's
timing is the same as before, so a serve comes to you exactly as it did. Also smoother:
- the block no longer snaps its leg up in one frame;
- a player who wins the point mid-kick finishes the kick before he cheers (he used to snap upright in the air);
- a player coming out of a kick into a run eases into his stride.

New in 0.14.2, four things the owner saw:
- **Spikes you can see.** A spike now flies at about two-thirds of a real one's speed: a roll spike at about 76 km/h
  rather than 110, so the ball crosses the court in about a third of a second instead of a fifth. The defenders still
  reach the same spikes as before, so kills, digs and rally lengths are unchanged.
- **No gliding back.** A player walking back to his place after fetching the ball (or lobbing it to the thrower)
  walks with his legs; before, a move still playing held his legs still and he slid along.
- **The officials step backwards.** An official backing away from the ball, still facing the court, steps back.
  Before, his legs ran forward while he went backwards.
- **A new kick sound.** The ball's hit is now a light, hollow knock, closer to a rattan ball. It comes from Kenney's
  CC0 impact pack, with the old soccer-ball kick underneath for the foot's weight. The spike gets the same knock on top
  of its hit. Before, the kick was mostly a low thud.

New in 0.14.1: **Settings > About > Licences can no longer crash the game**: its long texts were laid out on a
worker thread, and the engine can crash when such a page is drawn or closed mid-layout (it did once in a test). It
now opens at once and fills in a piece at a time.

New in 0.14.0: **Watch AI** (on the home screen): pick the two teams (countries or clubs, men or women), the event,
the length and the venue, and watch the computer play a full match on both sides, from the broadcast camera with the
replays and the score. 1×/2× (top right) doubles the speed; pause or Back to stop, the pause menu's Quit match to
leave. Watched matches don't count in your records.

New in 0.13.1: **the serve's toss keeps the ball out of the thrower**: as he winds up he lowers the ball in front of
his knees, both hands on it, and swings it up and out to the server; before, his arms swung back to his sides and the
ball between his hands went into his body (on every graphics level).

New in 0.13.0: **the shared foundation** (the pilot, merged). On Medium and High the players, the officials and the
substitutes are drawn on the World Stage Games rig: walking between points and the officials standing and stepping
with motion capture, every kick, header, block and toss still the game's own; a replay of each point's best moment.
Low (where the Galaxy A16 starts) is exactly as it was. It installs over the foundation pilot (0.12.4-pilot) as well
as over the beta.

New in 0.12.4: **the phone's Back closes what is open first**: the language picker on the home screen (Back used to
close the whole game there), a team list in Quick Match, and League Season's "Abandon?" question, instead of leaving the
screen under them.

New in 0.12.3: **the pause menu takes every tap**: the joystick and the match buttons no longer show over it or its
Settings, where they could take a tap meant for a setting under them. **The language picker's** long names ("Bahasa
Indonesia") fit their tiles. The rest of 0.12.3 is for the Play Store and the website, outside the game.

New in 0.12.2: **players walk between points** (turned to where they go, walking back to their places and jogging
to fetch the ball, their feet stepping back when they back up) instead of gliding backwards. **The park** is dressed on
its near side too (benches and people, the path and lamps, the town behind the trees), and **the beach's** hills and
headlands are no longer black from the end and replay cameras.

New in 0.12.1: **Settings > About** has the licences, the help and the privacy policy in the game (no internet
needed). The help now has the rules in brief, what each graphics level does, and how to report a bug.

New in 0.12.0, the owner's list:

- **The ball is never left hanging:** after a point it falls, bounces and rolls, and bounces off the walls, boards
  and fences (an ace no longer rolls through them). A player picks it up and lobs it to the thrower (the server in
  doubles), who catches it and carries it to his place.
- **The serve's toss:** the thrower faces the tekong, the ball in both hands, and tosses it in one smooth movement
  from his hands, then turns back to play.
- **Players alive while they wait:** breathing, swaying, shifting their weight, the receivers on their toes.
- **The ball sounds like a ball:** real recordings of balls kicked, touched and bouncing, in place of the wooden
  knocks.
- **Four officials:** the referee in his chair, the assistant at the other post, and a line judge standing at each
  end off the far corner with a flag: he bends to watch his lines when play is at his end, signals in or out, and
  gets out of the ball's way when it comes at him.
- **Substitutes** sitting on the team benches in their kit, cheering their side's big points.
- **The crowd** turns smoothly with the ball, cheers in four ways mixed through the stands (clapping, jumping, fist
  pumps, arms up), and waves the two teams' flags.
- **The score at the top** is narrower, with no empty space.
- **The gym:** real basketball hoops, block walls with high windows, aluminium bleachers. **The beach:** islands,
  headlands, a fishing village, hotels and boats behind it.
- **The words on the floor and the boards** are in your language.
- **Privacy policy and Help** in Settings open in the game. League Season no longer says "the real leagues".
- **Five venues:** the night market, the temple court and the Grand Dome are gone; the world championship is at the
  mall.

New in 0.11.1: **the officials in suits**: the referee, his assistant and the line judges in dark jackets and
trousers, white shirts and red ties, black shoes, as at the World Cup and the Asian championships.

New in 0.11.0, from the two matches the owner sent (the 2024 World Cup's Thailand v the Philippines, the Asian Cup's
India v the Philippines; docs/AI.md):

- **The computer serves like the top sides:** hard and flat every time, at the one receiver it picks for the set,
  and it misses more often for it (into the net, wide or long). Receive it well and you are in the rally; a spilled
  reception off its serve goes out, dies at the receiver's feet or floats back over to be put away.
- **Its formation:** a flat line 3-4 m off the net to receive; the pass to the setter in the middle; one blocker
  against a spike (the inside player on its side), the cover behind its own spiker for a block's rebound; a loose ball
  that comes over is headed or soled straight back.
- **Shorter rallies:** spikes are harder to dig and go out less often, a block stuffs a spike less often.
- **Difficulty** works on the serve and the reception: on Rookie the computer misses more serves, spills more
  receptions and serves a little softer at you; on Legend fewer and harder.
- **A serve into the net** is a fault called at once ("the serve didn't cross"): before, the serving side could play
  it on.
- **The arenas and the dome** as at those two events: red pads round the posts with a box at their feet, a ball stand
  by the near post, TV cameras on tripods at the corners, the game's name on the floor behind each back line, a
  scoreboard by the scorers' table that keeps the score, the jury's tables in white cloths behind the far boards, and
  flags in the home side's colours waving in the crowd (the mall has the same but the jury's tables).

New in 0.10.0, the owner's list:

- **The venues filled in.** The mall atrium is a mall now: three floors of shops all round, balconies with glass
  railings and people leaning on them, escalators, palms, kiosks, a granite floor, the skylight; bleachers on both
  sides. The beach's bare side has a thatched bar, sun loungers and umbrellas, palms, and people watching from there
  too; a lifeguards' tower and longtail boats by the water. The temple court has a sala, chedis, a spirit house, food
  carts and scooters on its near side; the arenas a lit ribbon round the top of the stands and a scoreboard over the
  court; the gym windows, a scoreboard and bleachers on both sides. From every camera (try the end camera): is
  anything still bare?
- **The fans watch the game.** Each spectator is drawn from the side the camera sees of them (front, three-quarters,
  side, from behind) and turns a little to follow the ball, instead of all of them facing the camera.
- **Simulate to the end**, in the pause menu of a season's or a tournament's match: the rest is played out from the
  score as it stands, and you get the result.
- **The score:** the sets each side has won in words ("Sets: 1"), not two dots.
- **The seated line judges** rest their hands on their knees.
- **The home screen:** How to Play, Settings and Records fit their buttons in every language; the "real rules" line
  is gone.
- **International:** only the nations that take part in an event can enter it (no United States at the Asian
  Championship).

In 0.9.1: a real referee's whistle (recordings, not a made-up tone): a short pip for a serve or a fault, a long
blast at the end of a rally and of a set (with a hall's echo indoors), two pips for a video review, and short, short,
long when the match is won; from the referee's chair. And a smaller download than 0.9.0's (about 117 MB, from 154):
the ground's relief at 1K on Medium and High, where 2K made little difference.

In 0.9.0: more detail on Medium and High (Low is exactly as it was). The ground and courts are photographed at
2K (four times the pixels), the skies at 4K, the players' skin and kit at twice the resolution; the crowd has twice
as many different people in it (more skin tones and builds, shorts of their own colours, new poses: elbows on knees,
filming on a phone). The sound beds are longer (a minute of sea, birds or a market), and the crowd has more ways to
cheer and applaud, and claps in time when the home side is a point from the set. The download is bigger. On a mid-range phone on Medium or High: is it still smooth, and does it look sharper close up?

In 0.8.0: the sound of the game. The ball's knocks, its bounce on the court and on sand and into the net are
recordings now, and come from where the ball is (left or right in the picture); the players' footsteps on the court
(a trainer's squeak now and then) and on sand; a real crowd's murmur, cheer and applause, a groan when the home side
gives a point away and an "ooh" for a ball on the line; the sea at the beach, birds at the temple, a summer evening at
the park, chatter at the mall and the night market; new menu music. Pausing holds every sound. Listen with headphones:
does anything sound wrong, too loud or too quiet?

In 0.7.0, the owner's list:

- **Play as one player** (Settings > Play as: the team, the tekong, the feeder or the striker). Only that player's
  touches are yours (a white ring under him); your team-mates play theirs. Does it feel like being on a team?
- **Settings in the pause menu**, so the graphics, the frame rate, the camera or the assist can be changed mid-match.
  **Graphics: Auto** (the new default) picks Low, Medium or High from the phone's chip and memory. Which does it pick on
  your phone, and does it run smoothly there?
- **The crowd are whole people.** They stand up to cheer a point and sit down again, with legs. At the beach (and behind
  the fences and stalls) people stand on their feet.
- **The officials move:** they follow the ball with their heads, breathe, shift their weight, settle on their chairs;
  the referee points to the side that won the point.
- **The ball spins** in the air.
- **No white beyond the ground.** At the beach the sea runs to the horizon (no square end), and in every outdoor venue
  the ground fades into the haze. The night market's street is closed at both ends by more shophouses (the end camera).
- **The home screen:** new pictures for Quick Match, League Season and International; bigger How to Play, Settings and
  Records; the tagline is gone.

In 0.6.0: the jumps are real. The block, the header spike and the jump for joy take off and land the way a
real jump does (motion capture from the CMU library): the dip with the arms swung back, the spring, the landing taken
on the knees, with the takraw part (the raised foot, the nod, the arms up) on top. Watch a block at the net: does it
look right, and does the timing of the Block button feel the same? The kicks no longer slide the foot they stand on:
the serve, the roll spike, the sunback, the sole spike and the knee keep it planted and step with the other, and after
a roll spike the striker lands where the jump takes him.

In 0.5.2: the crowd watches the court from every side. Seen from behind a stand, people show their backs instead
of turning round to face the camera.

In 0.5.1: a much smaller download (under 50 MB instead of 89 MB). Shophouses line the night market's street and
the park's far side, and apartment blocks with lit windows stand behind them. If anything in a venue looks blurrier
than in 0.5.0, say where.

In 0.5.0: every venue rebuilt from real-world pieces. Real skies; courts painted on concrete, asphalt and a maple
gym floor; a Thai temple behind the temple court with spectators on plastic chairs; palms and rain trees; the sea
moving at the beach and stilt houses back from it; a fenced park court with benches, lamps and a basketball hoop on
the next court; a night market with stalls, lanterns and stools; metal bleachers, a clock and basketball boards in
the provincial gym; bleachers in the mall. Try every venue on Low and on High: does anything float, look out of
place, or slow the game down?

In 0.4.0: the game is **Sepak Takraw Unleashed**, with its new icon. Real-looking players (a man's and a
woman's model in each team's colours), the new ball, crowds of real-looking people, glossier courts. The spikes, the
serve and the knee are motion capture, and so are the run and walk; blocks are made with the feet (a jump, a foot
raised over the net: press Block as their striker hits). No more numbers over the players' heads; a smaller
scoreboard with the referee's calls under it.

In 0.3.0: players are shirt numbers (no names); plain league and event names; Kabaddi Raid's fixes brought over
(the game waits for players to walk to their places before a serve, the teams cross at a change of ends behind a quick
cut, bigger pause buttons with Quit apart, the nearest button takes a press, the joystick lets go if you leave the
app, Auto graphics now works, celebrations vary); a paler beach.

- **The controls**: run the lit player to the gold mark with the joystick, and press as the ring meets the gold
  circle. Nothing is played for you. Is it clear who is yours and where to go? Is PERFECT reachable? Try the three
  assist levels and the three game speeds (Settings).
- **Scrolling**: drag any long page (Settings, How to Play, the season tables) from anywhere on it.
- **Serve** with both buttons; **spike** with each; **block** when their striker goes up. Aim with the joystick.
- **A season** in each league: Malaysia's Grand Prix (and Division 1: pick a Division 1 club), Thailand's two-regu
  ties, Indonesia's regions and finals. Does it play out the way the real league does?
- **A tournament** (International), men's and women's, and the team event.
- **Your language**: every screen. Note any word that is wrong, cut off or too long.
- **A budget phone**: does it stay smooth on Low? Does the phone get warm? (Settings > Frame rate > Battery saver.)

## Report

Email joshnason8@gmail.com with the phone's model, what you did and what happened (a screenshot helps).
