# Android beta: install and test

Version **0.8.0-beta**. This page covers installing the beta on an Android phone, what to try, and how to report
what you find.

## What phone

- Android 7.0 or newer, 64-bit (almost every phone since 2017).
- About 200 MB free.
- The game runs in landscape. Turn auto-rotate on, or hold the phone sideways before you open it.

## Install

1. Get the APK on the phone. Either:
   - Download `kabaddi-raid-0.8.0-beta.apk` from the chat, or
   - Open the latest **Android build** run on GitHub (Actions tab) and download the `kabaddi-raid-…-apk`
     artifact. It is a zip; unzip it on the phone (My Files) or on a computer. Builds too big to send in the
     chat come this way.
2. Open the `.apk` file on the phone. Android asks you to allow installs from that app (Files, Chrome or Drive).
   Allow it, go back and tap **Install**.
3. If Play Protect warns about an unknown app, tap **More details**, then **Install anyway**. The beta is signed
   with a test key, not a Play Store key, so this is expected.

### Updating to a newer beta

Android only installs an update over the top if both builds were signed with the same key. The APKs sent in
the chat and the GitHub Actions builds from 0.7.4 on share one key, so either installs over the other and keeps
your saves. Actions builds from before 0.7.4 used a different key: if Android says **App not installed** or
**package conflicts**, uninstall Kabaddi Raid first, then install the new APK. Uninstalling clears your saves
(career, season, cup).

## First run

- The game starts in your phone's language if it has it, and in English if not. To change it, tap the
  **globe** button at the top left of the main menu (it shows the current language), or go to
  **Settings → Language**. **Phone language** goes back to following the phone.
- **How to Play** (bottom left of the main menu) has the controls and the rules, a topic at a time.
- **Settings → Graphics** starts on Medium. If the first raids of a match run slowly, the game drops a level by
  itself and says so. Turn that off with **Auto graphics**. On a fast phone, try High.
- **Settings → Raid rule**: how the cant works. **Breath** (the default) leaves both thumbs free. **Tap** is
  the pulsing button. **30-second clock** is the Pro rule with no chant.

## Things to try

- A **Quick Match** at each difficulty.
- Raiding: hand and toe touches, kicks, dubki under linked hands, a lion jump over an ankle dive, the bonus
  line, breaking out of a hold.
- Defending: tap a defender to control him, Switch to cycle through them, Chain with a team-mate, then the
  ankle, thigh and waist holds and the Dash near a line.
- The phone's **back button**: in a match it pauses and resumes; on other screens it goes back; on the main
  menu it closes the game.
- Leave the app mid-raid (home button or a call), then come back. The match should be paused.
- A **League Season**, the 0.8.0 way:
  - **Retentions**: keep up to six (watch the purse fall as you keep stars), then the **war room**: what your squad
    needs, the fit stars and likely prices on the list, a **shortlist** with your maximum for each, the other
    franchises' purses and needs.
  - **The auction**: likely bidders on each lot, **auto-bid** to your maximum, **Next target** to skip ahead,
    and the **grades** for all twelve franchises at the end.
  - **Match day**: the preview (form guide, last meeting, key battles), then pick **your seven**. Rest a tired
    player (his fitness bar) and see whether the match feels different with fresh legs; injured players cannot
    play.
  - **The news**: the ticker along the bottom, the front page after each round, and breaking news (a record, a
    knock to your star, clinching a playoff place). Are the headlines interesting, and do they read well in your
    language?
  - The **board's goal** (on your team card) and its verdict at the end, the **weekly awards**, a **derby**
    (louder crowd), the **walk-out** before the final, the **Hall of fame**, and **Next season** (players a year
    older; look for a rising star or a retirement in the news).
- A **Nations Cup**: pick 12 of 18 and a captain, check **What you need** before your last group match, the
  bracket, the awards, and try the **Underdog Trophy** with Kenya, Japan or Argentina.
- **Every ground** in a Quick Match. Since 0.7.9 each has baked lighting, new court and stand surfaces and a
  broadcast camera that moves in on a tackle. Say if one looks wrong or runs slower than the others.
- **The new player models**: in a Quick Match each side's first two players wear the two players made in Meshy's
  web app (the first from a picture, with knee pads; the second in a sleeveless vest, barefoot). Compare them with
  the others, from the broadcast camera and from behind (the Camera button).
- **Shadows on Low**: since 0.7.11 every player, official and the scorers' table casts a shadow on Low too, along
  the sun's light (long in the village's late afternoon, short under the dome's lamps), and keeps it when a slow
  phone drops to Low by itself in its first match. Say if a shadow looks detached from the feet or flickers.
- Each **raid rule**: Breath, Tap and the 30-second clock.

## Reporting

For each problem, note:

1. What you did, step by step.
2. What happened, and what you expected.
3. The phone model and Android version (Settings → About phone).
4. A screenshot or screen recording if you can (Power + Volume down; most phones also have a screen recorder
   in the quick settings).

If the game closes by itself (it crashed): say when (at start-up, on the home screen, starting a match, mid-raid),
and the phone model. A crash log helps most: with the phone plugged into a computer with USB debugging on,
`adb logcat -d > log.txt` straight after the crash; without a computer, Settings → Developer options → **Bug report**.
Since 0.7.6 the game draws with OpenGL rather than Vulkan, which is what crashed on a Galaxy S24.

Things worth reporting even if nothing is broken:

- **Feel.** Is the raider too fast or too slow? Does a tackle feel fair?
- **Difficulty.** Is Rookie easy enough and Legend hard enough?
- **Frame rate.** Does it stutter, and on which graphics setting and ground?
- **Heat and battery** after a full match.
- **Text** that is cut off, overlaps, or reads wrong in your language.

## Known limits

- Voices, crowd sounds and player grunts are synthesised placeholders. Drop real recordings into
  `assets/audio/` with the same file names to replace them.
- Players move with hand-made animation driven by code. Motion capture from real match video will replace it
  over time.
- Translations other than English were machine-drafted and need a native speaker's review.
- Not in yet: substitutions, reviews, red cards (see [KABADDI.md](KABADDI.md)).
