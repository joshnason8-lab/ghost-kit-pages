# Android beta: install and test

Version **0.8.5-beta**. This page covers installing the beta on an Android phone, what to try, and how to report
what you find.

## What phone

- Android 7.0 or newer, 64-bit (almost every phone since 2017).
- About 200 MB free.
- The game runs in landscape. Turn auto-rotate on, or hold the phone sideways before you open it.

## Install

1. Get the APK on the phone. Either:
   - Download `kabaddi-raid-0.8.5-beta.apk` from the chat, or
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
- **Who is who** (0.8.2): the tag over your player (edged in saffron) and the raider's, with number and name; the
  numbers over everyone else; the scorer's name with the points; the player of the match with his number. Can you
  always tell which player is yours, and who scored? Try Settings → Display → Player tags (Everyone, Off) too.
- **The award plaque** (0.8.2) on the season awards and the Nations Cup awards, in place of the bronze figure.
- **Legs and shorts** (0.8.3): knees and shins were speckled with the team's trim and kit colours (gold or navy
  patches, worst on light and two-colour kits such as Chennai's), and the bottom of most players' shorts took the
  shirt's colour. Look at the players' legs in a few different kits.
- **Text on a 16:9 phone or a tablet** (0.8.3): names and details on the retention cards, in the war room, the
  Nations Cup squad and the auction's Needs box were cut off mid-word, and country names broke in two beside the
  Underdog tag. They now take a second line or end in "…". Say if any text is still cut off, and on which screen.
- **The auction's grades** (0.8.3) count what you paid for the free agents who filled your squad (a purse that went
  down while "spent 0 L" said otherwise), and the Underdog Trophy's countries are the ones rated 75 or below on the
  country picker.
- **Every language** (0.8.4): play a match and go through a season in yours.
  - The match's words (the calls, banners, pause menu and walk-out) were in the engine's own plain font, with Indian
    scripts left to whatever fonts the phone had, and the pause menu was unstyled. They are now in the game's fonts.
  - Tamil, Telugu and Kannada text is set a little smaller, as their words run longer: a Tamil label is typically
    1.4 times as wide as the English.
  - In Tamil, the auction, war room and retentions ran off the right of the screen. They fit now, drawn a little
    smaller where they must.
  - In Kannada, Telugu and Punjabi, two-line details showed only their first line.
  - Long calls and banners ("Time out · Chandigarh Chargers") ran off the screen in every language, English too.
    They now stay in the middle and take two lines.
- **Big phones, foldables and tablets** (0.8.4):
  - The game now tells Android it is a game. On a tablet or a foldable's inner screen, Android 16 had been free to
    ignore its landscape lock.
  - The buttons keep clear of a punch-hole camera at the screen's edge.
  - Try it at the phone's highest screen resolution and refresh rate.
- **Settings → About** (0.8.4): the version, the privacy policy and help pages (they open in your browser), and the
  licences of what the game is made with.
- **The box score** (0.8.5): after a match, the **Box score** tab beside the title shows each side's seven: points,
  raid points, raids, successful and empty raids, tackle points and tackles tried, and the side's line. The player of
  the match wears a crown, and the Summary says what his points came from. Do the numbers match what you saw?
- **Vibration** (0.8.5): the phone buzzes for what happens to you, not to everyone.
  - Short on your touch, firm on your hold, strongest when you are held and when you are brought down.
  - Light when a team-mate holds the raider, a double buzz when your side brings him down or you break free.
  - The live match behind the home screen no longer buzzes the phone (it did on every touch).
  - Is each one clear on your phone? Too strong, or too weak to feel?
- **Frame rate** (0.8.5, Settings → Display):
  - **Battery saver** plays at about 30 frames a second (36 on a 144 Hz screen, which shows 30 unevenly) and draws
    the court a little softer.
  - **60 fps**, the default, appears on a 120 Hz screen (on a 144 Hz one, 72).
  - **Max** plays at the screen's own rate.
  - A 60 Hz or 90 Hz phone shows only Battery saver and Max: 60 would judder on a 90 Hz screen, so the game runs at
    90 there.
  - On a phone that runs hot, compare how warm it gets after a match on Max and on 60.

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
- **Frame rate.** Does it stutter, and on which graphics setting and ground? See *Measuring stutter* below.
- **Heat and battery** after a full match.
- **Text** that is cut off, overlaps, or reads wrong in your language.

## Measuring stutter

The average frame rate hides stutter: a match can average 60 frames a second and still catch every few seconds. A
developer's overlay measures it on your phone:

1. On the home screen, tap the version number (bottom left) seven times quickly. It says **developer overlay on**.
2. Play a match. A dark panel on the left shows the frame times over the last five seconds (median, 95th and 99th
   percentile, worst) and a graph of the last three seconds, the **hitches** (frames more than twice the usual, and
   what was happening at the last one), the graphics level (and when it lowered itself), and for the player you
   control his speed, state and the clip his body is playing, with the last contacts (touches, holds, escapes).
3. When it stutters, tap **Copy summary** and paste it into your report. It has the phone, the screen, the
   graphics and the worst frames with what was happening at each.
4. Seven taps on the version again turn it off.

## Known limits

- Voices, crowd sounds and player grunts are synthesised placeholders. Drop real recordings into
  `assets/audio/` with the same file names to replace them.
- Players move with hand-made animation driven by code. Motion capture from real match video will replace it
  over time.
- Translations other than English were machine-drafted and need a native speaker's review.
- Not in yet: substitutions, reviews, red cards (see [KABADDI.md](KABADDI.md)).
