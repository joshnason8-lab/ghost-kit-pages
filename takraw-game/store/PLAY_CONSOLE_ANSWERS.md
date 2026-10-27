# Play Console: the answers, for the build as it is

Every form Play Console asks to fill in for Sepak Takraw Unleashed, answered for the game as it is built today
(0.12.x). The step-by-step guide is store/PLAY_STORE.md. If the game changes (an ad, an account, a server, a purchase),
change these answers before uploading that version.

What the answers rest on (checked in the build, `.github/workflows/takraw-play-bundle.yml` prints it on every bundle):
- **Permissions**: one, `android.permission.VIBRATE` (to buzz the phone when your player touches the ball; Settings >
  Vibration turns it off). No `INTERNET`: the game cannot connect to anything.
- **No SDKs** that collect or send data: no ads, analytics, crash reporting, sign-in or purchases. The engine (Godot
  4.7) sends nothing.
- **Stored on the phone only**: settings, the season or tournament in progress, records. Deleted with the app.

## App content (Policy and programs > App content)

| Form | Answer |
|---|---|
| Privacy policy | **TBD: owner's privacy site** (the owner is building one). The policy's text is in the game (Settings > About > Privacy policy) and in `takraw-smash/PRIVACY.md`; put the same text on the site. |
| Ads | **No, my app does not contain ads** |
| App access | **All functionality is available without any access restrictions** (no login) |
| Content rating | The IARC questionnaire below. Expected: PEGI 3, ESRB Everyone, IARC 3+ |
| Target audience and content | **13–15, 16–17, 18 and over** (below). Appeals to children: **No** |
| News app | No |
| COVID-19 contact tracing and status | No |
| Data safety | Below: **no data collected, no data shared** |
| Government app | No |
| Financial features | My app doesn't provide any financial features |
| Health | My app does not have any health features |
| Advertising ID | **No** (the game does not use it; with no internet permission it could not send it anywhere) |
| Photo and video permissions, foreground service, full-screen intents, exact alarms | Not used (no form appears) |

### Data safety form

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | (Not asked when the answer above is No) |
| Do you provide a way for users to request that their data is deleted? | (Not asked) |
| Account creation | The app has no accounts |

The listing then shows **"No data collected"** and **"No data shared with third parties"**. Why that is true: the game
has no internet permission, so nothing can leave the phone; what it saves (settings, progress, records) stays in its
private storage, which Play's form does not count as collection.

### Content rating (IARC questionnaire)

Category: **Game**. Email for the certificate: joshnason8@gmail.com.

| Question | Answer | Why |
|---|---|---|
| Violence (any, including cartoon or fantasy) | No | A ball game: kicks are at the ball, no player hurts another |
| Blood, gore | No | |
| Fear, horror, scary content | No | |
| Sexuality, nudity, sexual content | No | Sports kit only |
| Language (profanity, crude humour) | No | The text is the game's menus and the referee's calls |
| Controlled substances (drugs, alcohol, tobacco) | No | |
| Gambling, simulated gambling, loot boxes | No | Nothing is bought or won |
| Users interact or exchange content (chat, user-generated content) | No | Single player, offline |
| Shares the user's current location with others | No | |
| Digital purchases | No | |
| Unrestricted internet access (a web browser) | No | The help's "Email us" opens the phone's email app; nothing else leaves the game |

Expected result: **PEGI 3, ESRB Everyone, USK 0, ClassInd L, IARC 3+**.

### Target audience and content

- **Age groups: 13–15, 16–17, 18 and over.** Recommended, though the content suits everyone (the rating above says so
  to parents).
- Why not under 13: choosing any under-13 group puts the app under Google's **Families policy**: its rules on ads,
  data and content, and a closer review of the app and of each update. The game would meet those rules (no ads, no
  data, no links out apart from the help's email button), but the extra review adds time to every release and little
  for a sports game whose audience is teenagers and adults. The owner can add the younger groups later.
- **Does the store listing appeal to children?** **No** (realistic players and venues, no cartoon characters or
  child-directed wording).

## Monetisation

- **Ads**: no.
- **In-app purchases**: none. **Free** app.
- **Subscriptions**: none.

## Store settings

| Setting | Answer |
|---|---|
| App or game | Game |
| Category | **Sports** |
| Tags (up to 5, from Play's list) | Sports, Single player, Offline, Realistic, Stylized (or Casual): pick from what Play offers then |
| Contact email (shown publicly) | **joshnason8@gmail.com** |
| Website | TBD: owner's site (optional) |
| Phone | Leave empty |
| External marketing | Allowed (the default) |

## Store listing

- Text, in 13 languages: `store/listing/` (`en-US.txt` the default; the 12 others under Manage translations: th-TH,
  ms, id, vi, lo-LA, my-MM, km-KH, fil, ja-JP, ko-KR, zh-CN, hi-IN). Each has the app name (22 of 30 characters), the
  short description (at most 80) and the full description (at most 4000), checked by length. **Drafts**: re-read them
  against the build before submitting (the game is still changing).
- Graphics (**drafts**, made from the real game; regenerate just before submitting, store/PLAY_STORE.md step 5):
  - `store/graphics/icon-512.png` (512 × 512, 32-bit PNG);
  - `store/graphics/feature-1024x500.png`;
  - `store/graphics/screenshots/` (eight, 1920 × 1080, captured on High).

## Release notes for the first Play release

The `== Release notes (first release) ==` part of each listing file, in all 13 languages. In English:

> The first release of Sepak Takraw Unleashed: Quick Match, League Season and International, in thirteen languages.
