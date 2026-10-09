# Android beta: install and test

Version **0.7.0-beta**. This page covers installing the beta on an Android phone, what to try, and how to report
what you find.

## What phone

- Android 7.0 or newer, 64-bit (almost every phone since 2017).
- About 200 MB free.
- The game runs in landscape. Turn auto-rotate on, or hold the phone sideways before you open it.

## Install

1. Get the APK on the phone. Either:
   - Download `kabaddi-raid-0.7.0-beta.apk` from the chat, or
   - Open the latest **Android build** run on GitHub (Actions tab) and download the `kabaddi-raid-debug-apk`
     artifact. It is a zip; unzip it on the phone or on a computer.
2. Open the `.apk` file on the phone. Android asks you to allow installs from that app (Files, Chrome or Drive).
   Allow it, go back and tap **Install**.
3. If Play Protect warns about an unknown app, tap **More details**, then **Install anyway**. The beta is signed
   with a test key, not a Play Store key, so this is expected.

### Updating to a newer beta

Android only installs an update over the top if both builds were signed with the same key. The APKs sent in
the chat share one key; the GitHub Actions builds use a different one. If Android says **App not installed**
or **package conflicts**, uninstall Kabaddi Raid first, then install the new APK. Uninstalling clears your
saves (career, season, cup).

## First run

- Pick a language, then try **Training** for the controls. The *Cant* and *Hand touch* lessons are the place
  to start.
- **Settings → Graphics** starts on Medium. If the first raids of a match run slowly, the game drops a level by
  itself and says so. Turn that off with **Auto graphics**. On a fast phone, try High.
- **Settings → Raid rule**: how the cant works. **Breath** (the default) leaves both thumbs free.
  **Say it** has you chant "kabaddi, kabaddi" out loud; Android asks for the microphone the first time, and
  the game listens only during your raids. **Tap** is the old pulsing button. **30-second clock** is the Pro
  rule with no chant.

## Things to try

- A **Quick Match** at each difficulty.
- Raiding: hand and toe touches, kicks, dubki under linked hands, a lion jump over an ankle dive, the bonus
  line, breaking out of a hold.
- Defending: tap a defender to control him, Switch to cycle through them, Chain with a team-mate, then the
  ankle, thigh and waist holds and the Dash near a line.
- The phone's **back button**: in a match it pauses and resumes; on other screens it goes back; on the main
  menu it closes the game.
- Leave the app mid-raid (home button or a call), then come back. The match should be paused.
- A **League Season** through the auction and a few rounds.
- Each **raid rule**, especially **Say it**: does it hear you over the crowd? (Headphones help.)
- **Training**: watch each move's demo, then the lesson.

## Reporting

For each problem, note:

1. What you did, step by step.
2. What happened, and what you expected.
3. The phone model and Android version (Settings → About phone).
4. A screenshot or screen recording if you can (Power + Volume down; most phones also have a screen recorder
   in the quick settings).

Things worth reporting even if nothing is broken:

- **Feel.** Is the raider too fast or too slow? Does a tackle feel fair?
- **Difficulty.** Is Rookie easy enough and Legend hard enough?
- **Frame rate.** Does it stutter, and on which graphics setting?
- **Heat and battery** after a full match.
- **Text** that is cut off, overlaps, or reads wrong in your language.

## Known limits

- Voices, crowd sounds and player grunts are synthesised placeholders. Drop real recordings into
  `assets/audio/` with the same file names to replace them.
- Players move with hand-made animation driven by code. Motion capture from real match video will replace it
  over time.
- Translations other than English were machine-drafted and need a native speaker's review.
- Not in yet: substitutions, reviews, red cards (see [KABADDI.md](KABADDI.md)).
