# Floorball Unleashed beta: install and test

Version **0.8.2-beta** (0.8.2: ready for Google Play: a long soak test of random inputs and AI matches on Low and High, the store kit finished; 0.8.1: Licences, Help and the privacy policy as pages in the game, Settings > About; 0.8: teams play as a Swedish league match showed, the city arena a league arena with a goal light show, referees in black, the crowd facing the rink from every side; 0.7.1: real referee whistles, heard from the referee, and the beta signed with the owner's key; 0.7: on Medium and High, sharper floors and kits and a fuller crowd; a richer crowd sound with chants; 0.6: a real crowd in the hall (its murmur, cheers and applause) and footsteps on the floor; 0.5: the players and referees walk, jog and run with real people's motion capture, their feet planted as they run; 0.4: the halls rebuilt: birch walls, ceilings with lights, folded-up basketball boards, a wooden school gym, steel bleachers in the arena; 0.4.1: an aluminium stand in the sports hall, Nordic fire alarms, pale birch gym benches). This page covers installing the beta on an Android phone, what to try, and how to report
what you find. docs/PLAYTEST.md has what the last playtest found and what was fixed.

## What phone

- Android 7.0 or newer, 64-bit (almost every phone since 2017; the Play Store build adds 32-bit).
- About 150 MB free.
- The game runs in landscape. Turn auto-rotate on, or hold the phone sideways before you open it.

## Install

1. On the phone, open https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/floorball-unleashed-beta and tap the
   `.apk` file under **Assets**.
2. Open the downloaded file. Android asks you to allow installs from your browser (or Files). Allow it, go back and
   tap **Install**.
3. If Play Protect warns about an unknown app, tap **More details**, then **Install anyway**. The beta is signed
   with the beta's own key, not a Play Store key, so this is expected.

### Updating

**From 0.2 (Floorstorm) to 0.3:** the game changed its name to Floorball Unleashed and, with it, its app id, so
0.3 installs as a new app beside the old one. Uninstall **Floorstorm** when you have the new one (your old settings
and saves stay with the old app). The old beta's page,
https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/floorstorm-beta, is no longer updated.

**From 0.7.0 or earlier to 0.7.1: uninstall once.** 0.7.1 is signed with the owner's beta key, the one every game's
beta now uses (0.3 to 0.7.0 used a public debug key), so Android will not install it over 0.7.0 ("App not installed",
or "failure conflict" in Obtainium). Uninstall Floorball Unleashed, then install 0.7.1 (this clears the saves, once).

From 0.7.1 on, every beta on the page above is signed with that same key, so a new one installs over the old and keeps
your settings, your World Finals and your club season.

## First run

- The game starts in your phone's language if it has it, and in English if not. The **globe** at the top right of
  the home screen changes it; **Settings > Language > Phone language** goes back to following the phone.
- **Your first match has a coach.** Notes at the bottom of the screen say what to do as the moment comes: how to
  move, what to do with the ball, how to win it back, your free-hit, the whistle, a penalty, a goal. Each says its
  piece once. **Settings > Coach tips** brings them all back.
- **How to play** on the home screen has the controls, the rules with their numbers and the referees' signs.
- **Settings > Graphics** starts at a level picked for your phone. If the first seconds of a match run slowly the
  game drops a level by itself and says so (turn that off with **Lower by itself if slow**).

## Things to try

- A **Quick match** at each difficulty and both game speeds (Steady is 80% of real pace).
- **Your player** has the yellow ring at his feet and the yellow arrow over his head (no numbers over heads since 0.3). Slide your left thumb anywhere on the left half to
  run. With the ball: **Shoot** (push the joystick up or down as you shoot to pick a corner), **Pass** (to the
  team-mate the joystick points at), **Sprint** (held). Without it: **Tackle** from the front, **Switch** to the
  team-mate nearest the ball.
- **Your free-hits and hit-ins**: the buttons turn to Shoot and Pass. Take it within about nine seconds: kept
  waiting, the referee gives it to the other team.
- **Passive play**: keep the ball in your own half for half a minute and the referee raises his arm; shoot within
  eight seconds or the other team gets a free-hit.
- **A penalty**: the penalised player walks to the penalty bench on the near side and sits there; his team plays one
  fewer (the timer is under the score) until the time is up or the other team scores.
- **Late in a match a goal or two down**: the team behind takes its goalkeeper off for a sixth outfield player. An
  empty net can be scored from anywhere.
- **The World Finals**: sixteen nations, groups, play-offs, quarter-finals, semi-finals and the medal matches.
- **The club season**: ten invented clubs, one round of matches against each other with 3-2-1-0 points (3 for a win
  in regulation time, 2 for a win in overtime or penalty shots, 1 for a loss after regulation time), then the top
  four play semi-finals and a final.
- **Settings**: left-handed, button size, **Move buttons** (drag each where your thumbs want them; also in the pause
  menu), camera (Broadcast, High, Behind the goal), sound, music, vibration.
- The phone's **Back** button: in a match it pauses and resumes; elsewhere it goes back; on the home screen it
  closes the game. Leave the app mid-match and come back: the match should be paused.

## What to look for

- **The sound** (new in 0.6): the crowd under play, its cheer at a goal, the applause at the end of a period, the
  footsteps of the players near the ball. Too loud, too quiet, anything that sounds wrong? The whistle, the ball and
  the horn are still made in code (docs/SOUNDS.md says what is wanted).

- **How the players run** (new in 0.5): do they look like people running? Watch the feet: a foot on the floor should
  stay put, not skate. Running backward and at an angle too. Anything that looks wrong (a leg crossing through the
  stick, a twist at the hips), with what he was doing.

- Can you follow the ball? Can you always find your player?
- Do the buttons sit where your thumbs are? Is anything under your thumbs that you need to see?
- Does any text run off a button or a card in your language?
- Frame rate on Low and Medium, and how warm the phone gets over a 3 x 8 minute match.
- Any call by the referee that is wrong by the rules (docs/RULES.md has every rule the game plays).

## Reporting

Write down the phone model, the Android version, the graphics level and what happened (a screenshot helps). Send it
to joshnason8@gmail.com or open an issue on the repository.
