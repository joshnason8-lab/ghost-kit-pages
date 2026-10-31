# Kabaddi Raid: answers for Play Console

The true answers to every form Play Console asks for, checked against the game as it is (0.12.3). Where an answer
depends on something the game does or does not do, the reason is given, so it can be checked again before each
release. The steps around them (account, upload key, closed test) are in `PLAY_STORE.md`.

## App details

| Field | Answer |
|---|---|
| App name | Kabaddi Raid |
| Default language | English (United States), en-US |
| App or game | Game |
| Free or paid | Free |
| Category | Game > **Sports** |
| Tags | Sports; Single player; Offline (pick from Play's list; it offers up to five) |
| Contact email | The developer account's contact email (shown publicly on the listing) |
| Website | https://thekabaddipulse.com/kabaddi-raid/ (HTTP 200, 27 October 2026) |
| Privacy policy | https://thekabaddipulse.com/kabaddi-raid/privacy/ (HTTP 200, 27 October 2026) |
| Package name | `com.kabaddiraid.game` (final: Play never lets it change once the first bundle is uploaded) |

The game also carries the privacy policy itself (Settings > About > Privacy policy), so it reads offline too.

## Ads, purchases, access

| Form | Answer | Why |
|---|---|---|
| Ads | **No**, my app does not contain ads | No ad library; the game has no internet permission |
| In-app purchases | **None** | Nothing is sold; the auction spends a made-up franchise purse |
| App access | **All functionality is available without any access restrictions** | No account, no login |
| Advertising ID | **No** | No ad or analytics library; the bundle declares no `AD_ID` permission |

## Data safety

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not asked once the answer above is No |
| Do you provide a way for users to request that their data is deleted? | Not asked once the answer above is No |

The listing then shows **No data collected** and **No data shared with third parties**. The reasons, each checked in
the 0.12.3 bundle:

- **One permission**, `android.permission.VIBRATE` (the buzz on a tackle; it can be turned off in Settings). No
  `INTERNET`, so the game cannot send anything anywhere; CI fails the bundle if any other permission ever appears.
- **No accounts, ads, analytics or crash reporting.** Godot, the engine, sends nothing.
- **What stays on the phone**: settings, the league season, the Nations Cup and the records, in the app's own
  storage. Uninstalling the app deletes them. Play counts only data sent off the phone as "collected".
- **The two "View online" buttons** (Help, Privacy policy) open the phone's browser at thekabaddipulse.com; the game
  itself sends nothing. The website's own privacy policy covers the browser's visit.

## Content rating (IARC questionnaire)

Category: **Game**. Email for the rating certificate: the developer account's.

| Question | Answer | Why |
|---|---|---|
| Violence (any, including cartoon or fantasy) | **No** | Tackles are holds in a contact sport: no hitting, blood, injury or death. A player who is out walks to the bench |
| Fear, horror | **No** | |
| Sexuality, nudity | **No** | Players wear kabaddi kit |
| Language (crude humour, profanity) | **No** | |
| Controlled substances (drugs, alcohol, tobacco) | **No** | |
| Gambling, including simulated gambling | **No** | The auction bids a made-up purse for players; no wagers, no chance-based rewards, no money |
| Users can interact or exchange content | **No** | No online play, chat or sharing |
| Shares the user's current location | **No** | |
| Allows purchases of digital goods | **No** | |
| Unrestricted internet access (a browser) | **No** | The two links open the phone's own browser |

Expected ratings: **IARC 3+, PEGI 3, ESRB Everyone, USK 0**.

## Target audience and content

- **Target age groups: 13–15, 16–17 and 18+.**
- **Could the store listing unintentionally appeal to children?** No.
- **Recommendation: "not designed for children" (13+).** The game itself is fine for any age, and its content
  rating says so to parents. But choosing an under-13 group puts the game under Google's **Families policy**, with a
  stricter review of the app and of every later update, and its own rules (on links out of the app, among others:
  the game has two, to the help and privacy pages). The game would likely pass, collecting nothing and showing no
  ads, but a sports management game with an auction, league tables and the rules of kabaddi is written
  for teenagers and adults, and 13+ is the simpler, honest start. The age groups can be widened later.

## Other declarations (Policy and programs > App content)

| Form | Answer |
|---|---|
| News app | No |
| COVID-19 contact tracing and status | No |
| Government app | No |
| Financial features | My app doesn't provide any financial features |
| Health | My app does not have any health features |
| Photo and video permissions | Not asked (the game requests none) |
| Foreground service | Not asked (none) |
| Exact alarms, full-screen intent, accessibility | Not asked (none) |

## Store listing

- **Text**: `listing/en-US.txt` (default) and `listing/hi-IN.txt`, `mr-IN.txt`, `ta-IN.txt`, `te-IN.txt`,
  `kn-IN.txt`, `bn-BD.txt`, `pa-IN.txt`: the app name (30 characters at most), short description (80) and full
  description (4000) in each of the game's eight languages. `python3 tools/check_listing.py` checks the limits.
  If Play Console does not offer Punjabi, leave it out: the game itself is still in Punjabi.
- **Graphics** (`graphics/`): `icon-512.png` (512 × 512, 32-bit PNG), `feature-1024x500.png` (24-bit PNG, no
  alpha), and eight phone screenshots in `screenshots/`, 1920 × 1080 (16:9), rendered from the game on High
  (`tools/store_art.py`). Upload the same eight for 7-inch and 10-inch tablets: Play takes 16:9 there too.

## Release notes for the first release (en-US)

```
The first release of Kabaddi Raid: Quick Match, League Season and the Nations Cup, in eight languages. Plays
offline, with no ads, purchases or data collected.
```

Each language's notes are at the end of its listing file. For each later release, the changes are in
`docs/RELEASE_NOTES.md`; Play's box takes 500 characters.
