# The beta: installing and testing

## Install

1. On the phone, open https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/ash-and-leather-beta.
2. Tap `hurling-heroes-<version>.apk` under Assets (an older or Android Go phone that will not install it:
   `hurling-heroes-<version>-32bit.apk`).
3. Open it when it has downloaded. If Android asks, allow your browser (or Files) to install unknown apps.

Each new beta installs over the last and keeps your saves.

## New in 0.24.10

- **A man sent off really goes**: at the stadium a board just past the touchline could hold him a metre short of the
  spot he walks off to, and he stood there for the rest of the match. He's now off once he's over the line.

## New in 0.24.9

- **Steadier feet again**: a foot moves an even share of each step, and a foot that lets go lifts at once (the shared
  animation foundation's latest planter); the worst slide in the owner's gliding test is down to 1.5 cm a step.

## New in 0.24.8

- **A man sent off leaves the field**: after a red card the player walks off over the touchline and is gone. He used
  to head for a spot behind the wall at the stadium (and too far out at the other grounds), stand there, and keep
  playing when the game restarted.

## New in 0.24.7

- **No T-pose flash in replays**: a player who comes into view during a score's replay no longer appears for a frame
  with his arms straight out (the shared animation foundation's replay fix).

## New in 0.24.6

- **Smoother replays**: when a score is shown again, the players' feet go with them as the replay moves them, and
  back again at its end (a planted foot used to stay behind for a moment).
- A stopping foot is put down where it's drawn, not a stride further on (the shared animation foundation's fix).

## New in 0.24.5

- **Cleaner restarts**: when the players and officials are put on their spots for a throw-in, a free or a shootout,
  their feet go with them (a planted foot used to stay behind for a moment and catch up, stretching the leg).

## New in 0.24.4

- **No more skidding feet**: when a player starts walking or pulls up from a run, his planted foot no longer skids
  across the grass (it could jump several centimetres in a single frame; now under half a centimetre).

## New in 0.24.3

- **Steadier feet**: a foot that has just landed no longer slides as the toe comes down (the shared animation
  foundation's fix); the worst slide in a step when walking is down from 2.2 cm to 1.7 cm.

## New in 0.24.2

- **Gates in the club ground's rail**: the rail round the parish field now has a gate near each corner of every
  long side and end, so a player can walk off the field to fetch a ball that has gone behind the clubhouse or the
  grass bank.
- Under the hood: the game is now checked by thousands of simulated matches, including a player fetching the ball
  from behind the ground's biggest stands and walls without walking through them.

## New in 0.24.1

- **Less gliding**: a player picking the ball up or catching it on the move now steps with his feet instead of
  sliding across the grass (a pick-up at a walk slid 7.7 cm in a step; now under 1.5 cm). His feet are held still
  when he barely moves.
- Every note you've given on the beta is now a permanent test the build must pass (21 of them so far), so a fixed
  problem can't quietly come back.

## New in 0.24.0

- **Nobody walks through anything**: the players, the referee, the linesmen and the substitutes go round the corner
  flags, the posts, the nets, the dugouts and their benches, the rails, the boards and the walls, never through them
  (a linesman used to walk straight through the flags on the touchline). A man taken off walks to the front of his
  bench and sits down.
- **The ball bounces off them**: a sliotar into the boards, a wall, a dugout, a stand's steps or a flag knocks back
  off it, each its own way (a dull thud off concrete, a ping off a metal rail, next to nothing off a net). The posts
  and the crossbar are as before, with their clang.
- **The crowd builds a little at a time behind the loading screen**, so the bar and the spinner keep moving on a slow
  phone.
- **Free-taking practice at your own graphics level**: the taker, his hurley, the sliotar and the posts are drawn
  at full detail on every level (with his shadow on the grass); the crowd and the stands are as your setting draws
  them, as in a match. Practice no longer switches the whole game to High, so it starts faster on a budget phone.
- **The clang off the posts comes from the posts**: still crisp and clear at a free's distance, now placed where
  the ball hit.
- Strikes keep their crack at a distance.

## New in 0.23.1

- **No stutter as a match begins**: the graphics are prepared behind the loading screen, and it stays up until the
  game runs smoothly.
- **Free-taking practice starts faster**: the crowd behind the posts is the normal High crowd, not twice as many
  3D fans.

## New in 0.23.0

- **A loading screen when a match starts**: tap Throw-in, Watch AI, a championship match or free-taking practice and
  the screen dims at once with "Loading…", a bar that fills as the ground, the crowd and the teams are built, a
  spinner and a tip about the game. The buttons can't be tapped twice. (On a slow phone the game looked frozen for
  several seconds.)

## New in 0.22.1

- **The clang off the posts, properly this time**: the ping of the sliotar off the aluminium is played clear and
  full again (0.21.0 only made it louder; it was being muffled with distance, the highs taken out, as a sound far
  across a ground is), and the crowd's "ooh" comes a beat after it instead of over it.

## New in 0.22.0

- **The crowd sits and stands properly at every ground** (the shared foundation's crowd placement): fans in the
  seated stands sit on the benches (not in them, not floating), the terraces and the banks stand with their feet on
  the steps, and everyone faces square to their stand and turned toward the play (they faced the exact centre of the
  pitch, so the ends of the long stands looked sideways). On Low the fans are whole people now, seated where there
  are seats. Their heads follow the ball.

## New in 0.21.2

- **The seated fans look right close up** (Medium and High): the 3D fans past the nearest few hundred were a cut-down
  figure whose arms stuck out and whose bodies looked sheared; every 3D fan is now the full figure.
- **No gliding when a player strikes, hooks or passes on the run**: his legs keep running while his arms make the move.

## New in 0.21.1

- **Feet flat on the grass again**: the players' and officials' boots stood with their toes up (the model's own
  boots are made that way); every foot is now turned down to lie flat.
- **A proper finish to the free**: after the strike the hurley comes through and up over the left shoulder and he
  turns to the posts, back heel up, then puts it down (it stopped upright by his right ear, his hips square).

## New in 0.21.0

- **The ball off the woodwork is heard again in free-taking**: the clang carries from the goal to the camera
  behind the taker (it was lost under the crowd at 40 to 65 metres).
- **The commentary is off** for now (to come back in a later version).
- **The birdsong is quieter** at the county and club grounds.
- **No more gliding sideways**: a player moving across the way he faces faster than a sidestep (getting to his
  place for a free, a keeper across his goal) turns and runs, instead of sliding sideways with his legs running.
- **A new celebration**: the scorer raises both arms high and holds them (the old fist pump flapped his forearm and
  looked broken in the close-up).
- **The field's lines no longer break up or vanish in the distance**: they are painted in the grass itself now, each
  at least a pixel wide.
- **Half-time**: the players walk to their places for the second half (some ran on off the field into the trees).
- **The clock no longer jumps**: after a stoppage it runs quickly up to the time instead of leaping on a minute or two.

## New in 0.20.2

- **The joystick is right wherever your player is on the screen**: in 0.20.1 it followed the camera's facing, which
  is only exact in the middle of the screen; off to the side, the camera's perspective threw it 15 to 60 degrees out.
  Now up is up the screen at your player, wherever he is.

## New in 0.20.1

- **The joystick follows the camera you are watching**: up on the stick runs your player up the screen and right
  runs him right, whichever camera is on (the broadcast camera, the high one, behind the goal, the low one behind a
  free's taker). Passes and shots aimed with the stick follow it too. When the camera changes mid-run, he turns
  to the new view over a fifth of a second instead of all at once.

## New in 0.20.0

- **Match commentary, ready for voices**: two commentators, Mick calling the play and Ger (a former hurler)
  reading it, follow the match: the throw-in, every score with the scorer's name, saves, wides, frees, cards,
  big catches and tackles, the man on the ball, the score after a score, the closing minutes, the replays and the
  final whistle. One talks at a time, a goal cuts across small talk, and a call that comes too late is dropped. **It is
  silent in this beta**: the voices are recorded with ElevenLabs from the script in tools/commentary/ (the guide is
  tools/commentary/README.md) and go in with a later beta. Settings → Sound and controls → Commentary turns it off.

## New in 0.19.2

- **The hurley no longer goes through the free-taker's arm**: just after he strikes, the stick passed through his left
  upper arm for a moment (from behind it looked like it went through his body). His left elbow now swings out round
  it, his hand staying on the handle; the stick is also kept clear of his chest.

## New in 0.19.1

- **The stands' light baked again**: the goal posts, the net frames, the rails and the poles behind the parish
  goals were left black by the baked light on Medium (too thin for its map); now each is lit as the walls beside
  it. (The shared foundation's fix, with every ground's light baked afresh.)

## New in 0.19.0

- **Watch AI** (the main menu): pick two counties and the ground and watch the computer play the whole match, on the
  television camera, with the score, the clock, the scorer's close-up and the replays after scores and wides. A
  1×/2× button (top right) plays it at double speed; pause and quit as in any match.
- **Referees and linesmen in proper kit**: black shorts to just above the knee and black socks to just below it, as
  GAA referees wear them (they looked bare-legged, the shorts like underwear). Umpires keep their white coats.
- **The goal posts are white again** (the baked light had turned them black on Medium).
- **The free's follow-through**: the hurley no longer passes through his body; the arm swings out round it.
- **The ball no longer disappears** on a long free: as it flies far off towards the posts, its small dot comes up
  over it (it was lost against the crowd, a few pixels across).
- **Licences**: motion capture by MoCap Online and ActorCore (Reallusion) credited.
- The shared foundation brought up to date.

## New in 0.18.0

- **The players move as people do.** Every hurler and official is drawn on the World Stage Games' shared
  animation (motion-captured starts, cuts, stops, backpedals and sprints, feet planted, fingers closed on the hurley).
- **The officials** wear the players' build in their own kit, with their own faces; the linesmen and umpires hold
  their flags in a closed hand.
- **Frees**: the taker stands tall while you aim, settles into his stance and strikes; his legs, feet and arms stay
  as a body can hold them through the follow-through.
- **The crowd** in 3D on Medium and High, in their counties' colours behind the goals with flags; their feet flat.
  The substitutes sit on the bench with their feet on the floor.
- **Television**: the scorer close after a score with his name, "Watch it back" in slow motion, the flight round the
  ground before the throw-in; the crowd's sound swells with an attack.
- **Smoother**: the match's animation costs the phone's processor about half what it did (a third on Low).

## New in 0.17.1

- **"Lower it by itself" now works all match long.** If the match stutters (slow frames, or a run of hitches) for
  about three seconds, the graphics drop a level at once: the shadows, the sky's lighting, the crowd's size and the
  players' look, not just the picture's sharpness; and again later if it still stutters. Before, it only watched the
  first ten seconds and only lowered the resolution, so a phone like a Galaxy A16 stayed stuttering on High.
- **The game picks the graphics level for your phone until you choose one** in Settings. If you never chose one,
  it decides again once on this update (an older beta's High was kept on the A16). Phones with a Mali-G57 or G68
  GPU (Helio G99, Exynos 1330, Dimensity 6300, such as the Galaxy A16) start on Low.
- Battery saver's 30 frames a second is not counted as a stutter.

## New in 0.17.0

- **Frees without the walk-up**: the taker is in his stance over the ball as each free starts, and goes back into it
  after the shot, scored or missed (the walk and the putting down are gone).
- **The penalty shoot-out in extra time is taken the same way**: the same low camera behind the taker, the same
  stance and strike. You aim and SHOOT your own team's penalties; the other team's are taken for them. Only the taker
  and the goalkeeper are in the picture.
- **The free-taking practice is at the county ground**; the choice of ground is gone.
- **The owner's hurley sounds in the matches too**: lifting the ball onto the hurley, the solo's hops and the
  goalkeeper's saves.
- **Running legs**: longer strides as the player speeds up (fewer, bigger steps), and each foot stays planted on the
  grass while it is down, so the players no longer skate or float.
- **Goalkeepers go round the goal**, not through the posts and the net, to the ball behind it or back to the line;
  and they keep inside the pitch.
- **The menu's picture fills its card** (the red "Clár an Lae" band across it is gone).
- The hurley in the free's swing lies right (it was too flat and long at contact).

## New in 0.16.0

- **A free taken as the owner's slow-motion video shows it**: your free-taker walks up on his own side of the ball
  with it in his left hand, bends and puts it down, and stands over it side-on to the posts, his left shoulder to
  them, the hurley in both hands, while you aim (no more hunched over it). On SHOOT he bends to it, slides the bas
  under it and lifts it, the sliotar riding the hurley up to his head; he tosses it, swings back over his right
  shoulder and strikes it as it drops past his waist out in front of him, then follows through to the posts. The
  motion, the hurley and the sliotar all taken from the video, frame by frame.
- **Hands that hold the hurley**: fists closed round the handle, both hands on it through the swing (the model's
  hands were open, the fingers straight).
- **The camera further back and higher**, so the ball is in the picture as it is put down and lifted; and it turns
  to follow a ball going out of the picture, with an arrow to it if it is off the screen.
- **A ball struck out over the sideline is called wide at once** (it was flying on for ten seconds before the call).
- **Post challenges**: the crossbar challenge is gone (the target never really runs across it): the third, sixth and
  ninth frees ask for the left post, the right post, then either. "POST CHALLENGE!", and "DOUBLE POINTS!" with a
  roar when it rings.
- **The officials' elbows bend forward**, the umpires' and the referee's (their hands were behind their hips).
- **The crowd cheers with its arms**: on Medium and High, as the crowd goes up, each fan's arms go up and wave, or a
  fist pumps, each at their own pace, blended smoothly.
- **Every strike goes where it is aimed**: the flight is worked out to the centimetre (a long free could go up as a
  lob before).

## New in 0.15.0

- **Frees from the grass, as they are taken**: your free-taker settles over the sliotar with his hurley under it
  while you aim, then rolls it up onto the bas, tosses it and strikes it: the motion taken from the owner's videos of
  a free (pose-tracked frame by frame). The sliotar rides the hurley up and goes up in the toss to meet the swing.
  In free-taking practice and for your aimed frees, 65s and penalties in a match.
- **No more shots taken for you**: left alone, the target and the bar wait for you however long you take (in a
  match the clock waits too).
- **Woodwork challenges** in free-taking practice: the third, sixth and ninth frees ask you to hit the left post, the
  right post, then the crossbar (lit gold); hit it and that free is worth two. Stop the target near it with the bar
  in the green and the sliotar goes right onto it.
- **The crowd cheers smoothly**: up off their seats and swaying, each at their own pace, easing in and settling
  again (no more hopping up and down in step); in practice too, for every score.
- **The sound of the ball**: the strike and the ping off the posts are now real recordings (supplied by the owner),
  the ping given its ring.
- **Feet flat on the grass**: the players' boots and the officials' shoes no longer point their toes at the sky.
- **The umpires' signals**: the flag raised from the side with a straight arm (no more broken-looking shoulders),
  eased up and down and waved slowly, the shoulder lifting with the arm so it stays joined at the shoulder (it came
  out of the coat's side below it); after a score the umpires keep facing the play, not round at each other.
- **Up close in practice**: the sliotar nearer its real size and, on High, real leather (grain, sheen, scuffs, two
  rows of stitches by its rim); every model at full detail at any distance, sharper textures at a low angle and
  finer, softer shadows.

## New in 0.14.0

- **Aimed frees, 65s and penalties have a second tap**: after SHOOT stops the target, a bar runs from side to side
  under it, red at the ends and green in the middle. SHOOT again with the marker in the green and the sliotar goes
  where the target stopped; out towards the red it goes off that side, further the further out. In free-taking
  practice and in matches alike.
- **Free-taking practice, closer and cleaner**: the camera stays low behind your free-taker the whole time (no cut
  to the wide camera after a shot), easing in as he walks up to each ball; he is alone on the pitch but for the
  umpires (no goalkeeper, no referee and linesmen running about); the sliotar flies on over the bar or into the net
  and lands instead of stopping in the air, and the next free comes sooner. It draws on High with a smooth frame
  rate whatever Settings says (your own settings come back after it), with the HD pack's hurler if you have it.
- **He swings every time**: a man the match camera was not looking at was not being posed, so while you aimed from
  the low camera your taker sometimes stood still through the strike. In matches too.
- **New goal nets**: a fine diamond mesh of white cord with knots, sagging a little, on a white frame, and the net
  shakes where the sliotar hits it.

## New in 0.13.0

- **Free-taking practice** (the home screen's fourth row): your county's free-taker takes ten frees and 65s at the
  posts, from close in and central to out on the wing and back at the 65, each aimed the new way (the low camera, the
  target going round the goal, SHOOT to stop it). A point is one, a goal three; the panel at the top keeps the score
  and a mark for each free, and at the end you get your score, a word on it, your best (kept on the phone) and Go
  again. Pick the county and the ground first; the spots move a little each round.
- **Simulate to the end** fills in the match in numbers (it left them at nothing).

## New in 0.12.0

- **Frees, 65s and penalties at the posts are yours to strike.** Press STRIKE on a free in range (or GOAL on a
  penalty) and the camera drops to the ground behind your man, looking at the posts. A target goes round in front of
  the goal: through the net, out wide, up between the posts over the bar and out the other side. Press SHOOT and it
  stops: that is where the sliotar goes. It hurries through the goal (a small space, with the keeper in it) and
  lingers between the posts; further out it goes round faster. The camera stays low to watch it go over.

## New in 0.11.2

- **The referee and umpires look right**: no more dark cracks across their faces, arms and legs (the step that
  cleaned a sportswear maker's marks off the referee's kit was also blacking out the edges of his skin), no pale
  flecks on the umpires' trousers (Medium and High now draw the whole model, not one cut down), hands hanging with the
  palms to the thighs rather than forward like a shop dummy, and arms that swing beside the body when they run rather
  than coming up in front like a boxer's. Their flags and cards are held as before.

## New in 0.11.1

- **Licences, Help and the privacy policy**, all in Settings > About and in the game itself (no browser, so they work
  offline): Licences now lists every asset with its source, author and licence (the Godot Engine and its parts, the
  fonts, Mixamo, the CMU motion capture, Poly Haven, Meshy, Gregor Quendel, Thimras, Kenney, the Pixabay whistles, and
  the HD pack's own); Help has a section on the graphics levels and how to report a bug; the privacy policy carries
  its date. Easier to read on a small phone (each part on a card).

## New in 0.11.0

- **One renderer, three levels**: the game draws with Vulkan on every phone that suits it, and Graphics is Low,
  Medium or High again, changed at once (no closing and opening the game). High on Vulkan has real shadows from every
  player, lit grass and players, floodlights that light the field and filmic colour; the HD pack (Settings) makes it
  sharper still, in use as soon as it is downloaded. Phones that Vulkan does not suit carry on with the older renderer
  by themselves.
- **Pick-up by itself**: run onto the sliotar and your player lifts it onto his hurley (or catches a dropping ball)
  and solos, with Settings > Help with the ball on Solo or Full (the default).
- **The Summer Championship**: Simulate your next game, or the rest of the championship; Simulate to the end from
  the pause menu in a match; leave a match for the menu (or close the game) and Continue carries on from the same
  minute and score.
- **Moving**: a man running away from where he is looking turns and runs (or backpedals, if slow), no more running
  forward while sliding back; the hurley is carried steady at a run, not swung round.
- **The crowd** rises as an attack nears the posts and roars as the shot goes up; **substitutions** come up on the
  fourth official's board, one after another.
- **The grounds**: real-looking houses round them (Irish terraces in their colours, thatched cottages, lit windows at
  night); the national stadium's two corner blocks are now seated corner stands, with the press box and the big
  screen.
- **The menu**: the game's name in a new face; no strip under the picture or "In this programme". Privacy and Help
  are in the game (Settings > About); How to Play no longer lists keyboard keys.

## New in 0.10.2

- **Clean kits** on every graphics level: the grime and the streaks of the model's own texture are gone from the
  shirts, shorts and helmets; each county's colours are solid.

## New in 0.10.1

- The HD pack has a release of its own, so the beta page is new with every build again (Obtainium sees each beta).

## New in 0.10.0

- **Ultra graphics** (Settings > Graphics, on recent high-end phones only; off unless you pick it): the Vulkan
  renderer, real shadows from every player, floodlights that light the field at night, sharper hurlers with cloth and
  skin shading, 4K grass, a denser crowd, smoother animation and a touchline camera in replays. Picking it downloads
  the HD pack (about 115 MB, best on Wi-Fi; it carries on if the connection drops), then asks you to open the game
  again. Low, Medium and High are exactly as they were. If Ultra will not start on your phone, the game goes back to
  High by itself and says so.

## New in 0.9.0

- **Shadows**: every player has a shadow on the grass (Medium and High), long and hard on a summer afternoon, so you
  can see where everyone is.
- **The national stadium looks like Croke Park** on Medium and High: a level of glass-fronted boxes between the two
  decks, a lit magenta ribbon on the upper deck, the roof's white truss, lit advertising boards round the field and a
  terracotta border. The crowd at the stadium and the county ground is in the two counties' colours, section by
  section.
- **Played like the real thing**: from watching a 2026 championship match, sides now squeeze across toward the ball,
  close the man in possession in twos further out, and a ball on the ground becomes a ruck. Scoring still matches real
  hurling.
- **The strike** sounds sharper: a crack, made to the measure of real strikes.

## New in 0.8.2

- **One signing key from now on.** Until now each beta was signed with a key of its own, so Android refused to
  install a new beta over the last ("failure conflict"). The builds are now signed with the owner's beta key, the same
  one every game uses: uninstall Hurling Heroes once (this clears its saves) and install the latest; every beta after
  that installs over it and keeps your saves.

## New in 0.8.1

- **A real referee's whistle**: recorded pea-whistle blasts in place of the made one, from where the referee
  stands (quieter when he is far off): a short pip for a free, a long blast for the throw-in and the end of a half,
  short-short-long at full time, two pips when a substitute comes on. Three takes of each, so no two sound alike.

## New in 0.8.0

- **Sharper on Medium and High** (Settings > Graphics; Low is exactly as it was): the pitch's grass at twice the
  detail, the players' kit and skin from a texture twice as sharp, the officials too.
- **A more varied crowd** on Medium and High: six different fans (an older man in a cap and scarf, a red-haired
  teenager, and more) in four poses each, 24 figures where there were 8.
- **Longer crowd and birdsong**, and the crowd cheers and roars three different ways.

## New in 0.7.0

- **Real sounds**: a stadium crowd recorded live (its murmur under the play, a cheer for a point, a roar for a goal),
  birdsong round the parish field and the county ground by day, your man's boots on the grass, hurleys clashing,
  the ball off the post, a shoulder going in. Everything stops while the game is paused. Turn the sound up: does it
  sound like a match?

## New in 0.6.0

- **Real walking and jogging**: players off the ball walk and jog with motion capture from the CMU library (a real
  walk and a real jog) instead of drawn leg swings, blending into the sprint as they speed up. Their feet stay put on
  the grass instead of skating; a sprinter's legs turn over faster. Watch a man drifting back into position: does it
  look like a hurler?

## New in 0.5.0

- **Every score shown again** from behind the goal (tap to skip), as a wide is. The still white ball that sat in the
  middle of a replay is gone (it was the ball's marker, drawn for the match camera).
- **The buttons come up sooner**: switch to a man standing in the gold ring under a dropping ball and CATCH and PULL
  are there at once. Press one early and he does it when the ball comes to him.
- **New people**: real fans in the stands (from the front, or the backs of their heads behind a stand), a referee in
  black and umpires in white coats, all modelled. The substitutes sit in the dugouts, and the men taken off walk
  over and sit down with them.
- **A new sliotar** (cream leather, the stitched rim) and new floodlights on every mast and the stadium roof, lit at
  dusk and at night.
- **The run**: the hurley carried lower, clear of the legs, the free arm swinging.
- The home screen is quieter: no line of small print under the title.

## New in 0.4.1

- **The crowd faces the play**: the people in the stand under the television camera were drawn facing the camera,
  so from the gantry they seemed to be looking away from the match. Everyone now faces the field: from behind a
  stand you see the backs of their heads.

## New in 0.4.0

- **New graphics round every ground**: real skies (a Northern Irish sunset at the parish field, Irish grey cloud at
  the county ground, a bright final day at the national stadium), a photo-scanned pitch mown in bands and worn in
  the goalmouths, real trees and hedgerows, a village with thatched cottages and a lough beyond the parish field,
  terraced streets round the county ground and the stadium. Look behind the goals (the camera button: End) and in
  the replay of a wide. Is it still smooth on your phone? (Settings > Graphics > Low if not.)

## New in 0.3.0

- **New players**: the owner's hurler, in every county's colours, running and swinging from motion capture. Do they
  read on your phone? Does the strike look like hurling?
- **Your player answers the stick** at once now, and is drawn bigger, with the camera closer.
- **A wide is shown again** from behind the goal (tap to skip), and every ball over the end line flies on into the
  net behind.
- **PULL** no longer crashes the game. The trees round the grounds stand in fields now.
- **Hurling Heroes**: the new name, the new icon and the new home screen picture.

## New in 0.2.0

- **A full match that ends like one**: Settings > Match length > 35 min plays all 70 minutes, the ball live about as
  long as in a real match; expect a score like 2-20 v 1-19. The shorter lengths are the same game, less of it.
- **The coach** in your first match: the game in three lines before the throw-in, then a tip the first time each
  thing comes up. Did you know how to play within a minute? (Settings > Coach's tips turns them on again.)
- **Substitutions**: pause, Substitutions. Tap a tired man (the bar is his legs), then who comes on. Or leave it to
  the manager. **Tactics**: pause, Tactics: a sweeper, two inside, short or long puck-outs.
- **A high ball near you** has a gold ring on the grass where it comes down: run under it and CATCH.

## What to try

- **A match**: Throw-in on the home screen. Run with your left thumb; the buttons on the right change with what
  your player can do. Do you always know which player is yours (the gold ring) and where the sliotar is (the white
  dot, the arrow at the screen's edge)? Can you catch, lift, solo, strike a point, go for goal, hand-pass, tackle?
- **The four steps**: carry the sliotar in your hand and watch the dots: do you get the free against you if you
  forget to solo? (Settings > Help with the ball > Solo does it for you.)
- **Restarts**: your puck-out (LONG with the joystick, or SHORT), your frees, 65s, sideline cuts, a penalty.
- **The officials**: does the referee give the free the right way, play advantage, show the cards? Do the umpires'
  flags match what happened?
- **The Summer Championship**: play it through. Does it run the way the real one does?
- **Irish**: Settings > Language > Gaeilge (or the globe on the home screen). Note any word that is wrong, cut off or
  too long.
- **A budget phone**: does it stay smooth on Low? Does the phone get warm? (Settings > Frame rate > Battery saver.)
- **Buttons**: Settings > Button size, Move buttons, Left-handed.

## Report

Email joshnason8@gmail.com with the phone's model, what you did and what happened (a screenshot helps). With the
developer overlay on (tap the version on the home screen seven times), the frame times are on the screen during a
match.
