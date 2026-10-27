# Play Console answers for Netball Unleashed

The true answers for this build (0.8.x), for **Policy and programs > App content** and **Store settings**. Checked
against the game's manifest: `com.netballunleashed.game`, target API 36, minimum API 24, one permission
(`android.permission.VIBRATE`), no internet permission, no SDKs for ads, analytics, crash reporting or sign-in.

## Privacy policy

URL: **TBD: the owner's privacy site.** Its text is `netball-game/PRIVACY.md` (the same as the game's own, under
Settings > About). The address given to Play must keep working while the game is on the store.

## Data safety

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not asked once you answer No (nothing is sent) |
| Do you provide a way for users to request that their data is deleted? | Not asked (no data collected). Uninstalling deletes the settings and progress kept on the phone |
| Account creation | The app has no accounts |

What Play then shows: **No data collected. No data shared with third parties.** Data kept only on the device and
never sent (settings, progress) does not count as collected under Play's definitions.

## Ads

**No, my app does not contain ads.**

## In-app purchases

None. The app is **Free**, with no in-app products or subscriptions.

## App access

**All functionality is available without any access restrictions** (no login, no codes).

## Content rating (IARC questionnaire)

Category: **Game**. Email for the certificate: joshnason8@gmail.com.

| Question | Answer |
|---|---|
| Violence (including cartoon or sports violence) | **No**. Netball is a non-contact sport; a "contact" call is a rule, nobody is hurt |
| Blood, gore | No |
| Fear, horror | No |
| Sexuality, nudity, sexual innuendo | No |
| Crude humour | No |
| Language (profanity) | No |
| Controlled substances (drugs, alcohol, tobacco) | No |
| Gambling, simulated gambling, loot boxes | No |
| Users can interact or exchange content with each other | No |
| Shares the user's current physical location with other users | No |
| Allows users to purchase digital goods | No |
| Unrestricted internet / web browser | No |
| Is it a news app, a social app, or user-generated content | No |

Expected result: **PEGI 3, ESRB Everyone, USK 0, IARC 3+** (or the lowest band in each region).

## Target audience and content

Recommended: **13–15, 16–17 and 18+**. Store listing unintentionally appealing to children: **No**.

Why not under 13: the game would meet the Families policy (it collects nothing, has no ads, no links out, no
purchases), but choosing any under-13 age group puts the app under the Families programme's extra review and its
ongoing obligations (for example every future SDK must be Families-certified). Starting at 13+ keeps the first
release simple; an under-13 group can be added later without a new app. The content rating (3+) still tells
parents it suits every age.

## Other declarations

| Form | Answer |
|---|---|
| News app | No |
| COVID-19 contact tracing or status | No |
| Government app | No |
| Financial features | My app doesn't provide any financial features |
| Health features | My app does not have any health features |
| Advertising ID | No, the app does not use an advertising ID |
| Foreground service, exact alarms, full-screen intent, photo/video, location permissions | Not used (none of these permissions are in the manifest) |

## Store settings

| Setting | Answer |
|---|---|
| App or game | Game |
| Category | **Sports** |
| Tags (up to 5) | Sports, Simulation, Offline, Single player, Casual (choose from Play's list; "Netball" is not one of its tags) |
| Contact email (public) | **joshnason8@gmail.com** |
| Website (optional) | The owner's site, once it is up |
| Phone (optional) | Leave empty |

## The listing and graphics

See `store/PLAY_STORE.md` step 5: text in `store/listing/`, icon `store/graphics/icon-512.png`, feature graphic
`store/graphics/feature-1024x500.png`, screenshots in `store/graphics/screenshots/` (1920 × 1080, captured from the
game on High; the same set serves 7-inch and 10-inch tablets), release notes in `store/RELEASE_NOTES.md`.
