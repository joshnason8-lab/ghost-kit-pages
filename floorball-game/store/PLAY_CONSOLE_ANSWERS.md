# Play Console answers: Floorball Unleashed

Every form Play Console asks you to fill in, with the true answer for this game, ready to copy. The steps around
them (the account, the upload key, the closed test) are in `store/PLAY_STORE.md`.

The facts the answers rest on (checked on the 0.8.2 bundle):

- **Permissions**: one, `android.permission.VIBRATE` (the buzz on a tackle or a goal; off in Settings). No
  internet permission, so the game cannot send anything anywhere.
- **No SDKs** for ads, analytics, crash reports, sign-in or payments. Nothing but the Godot engine.
- **What it keeps**, on the phone only, in the app's private storage: settings (`settings.json`), the World Finals
  and season in progress (`cup.json`, `season.json`) and your results (`records.json`). Uninstalling deletes them.
- **No accounts, no chat, no online play, no ads, no purchases.**

## App content (Policy and programs > App content)

### Privacy policy

`https://github.com/joshnason8-lab/ghost-kit-pages/blob/claude/floorball-game/floorball-game/docs/PRIVACY.md`

Checked 27 October 2026: **HTTP 200**. (The github.io page,
`https://joshnason8-lab.github.io/ghost-kit-pages/floorball-unleashed/privacy.html`, returns **404** until the
branch is merged into `main` and GitHub Pages serves it; switch the address to it then, if you prefer.)

### Ads

**No, my app does not contain ads.**

### App access

**All functionality is available without any access restrictions.** (No login, no codes.)

### Data safety

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| (Not asked once you answer No: encryption in transit, deletion requests) | — |

The listing then shows **"No data collected"** and **"No data shared with third parties"**. This is true: data
that never leaves the phone is not "collected" in Google's sense, and the game has no way to send any (no internet
permission, no SDKs).

### Content rating (IARC questionnaire)

Email: joshnason8@gmail.com. Category: **Game** (not "Social or communication", not "Reference").

| Question | Answer | Why |
|---|---|---|
| Violence of any kind | **No** | A ball sport. Body contact is shoulder to shoulder and the referee whistles fouls; no blood, no fighting, no injuries shown |
| Fear / horror | **No** | |
| Sexuality, nudity | **No** | |
| Crude humour | **No** | |
| Bad language | **No** | |
| Drugs, alcohol, tobacco | **No** | No sponsors or signs for them in the halls |
| Gambling (real or simulated) | **No** | No betting, no loot boxes |
| Users can interact or exchange content | **No** | Offline, single-player |
| Shares the user's current location | **No** | |
| Allows users to purchase digital goods | **No** | |
| Unrestricted internet access (a browser) | **No** | |
| Is the app a web browser or search engine | **No** | |

Expected result: **PEGI 3, ESRB Everyone, USK 0**, and the equivalent elsewhere.

### Target audience and content

- **Age groups: 13–15, 16–17 and 18+.**
- Could the store listing unintentionally appeal to children? **No.**

**Why not the under-13 groups (Families policy)?** The game itself would suit children: it collects nothing, shows no
ads and has no chat. But ticking any group under 13 puts the game under Google's Families policy, which adds a
separate review, requires the Families ads and data rules to be declared and kept for every future update, and
makes the "Designed for Families" rules apply to its listing. For a first release, **13+ ("not designed for
children")** is the simpler and honest choice: the game is a sports simulation made for teenagers and adults who play
or follow floorball. The content rating (3+) still tells parents it is fine for any age. You can add the younger
groups later.

### News apps · Government apps · Financial features · Health apps

**No** to each (not a news app; not a government app; no financial features; no health features).

### Advertising ID

**No**: the app does not use the advertising ID (no ads, no analytics; `AD_ID` is not in the manifest).

### In-app purchases

**None.** The game is free, with nothing to buy. (Free or paid: **Free**.)

## Store settings

| Field | Value |
|---|---|
| App or game | **Game** |
| Category | **Sports** |
| Tags (pick up to five) | **Sports**, **Simulation**, **Offline**, **Single player**, **Casual** (whichever of these Play offers) |
| Email (shown publicly) | **joshnason8@gmail.com** |
| Website | https://joshnason8-lab.github.io/ghost-kit-pages/floorball-unleashed/ (works once merged into `main`; leave empty until then) |
| Phone | leave empty |
| External marketing | your choice (default on) |

## Main store listing

- App name, short and full description, release notes: `store/listing/<language>.txt` (fifteen languages; every
  name ≤ 30, short description ≤ 80 and full description ≤ 4000 characters, checked).
- App icon: `store/graphics/icon-512.png` (512 × 512, 32-bit PNG).
- Feature graphic: `store/graphics/feature-1024x500.png` (1024 × 500).
- Phone screenshots: `store/graphics/screenshots/` in order (1920 × 1080, from the game on High). The same files
  serve as 7-inch and 10-inch tablet screenshots.

## Release notes for the first Play release

From `store/listing/en-US.txt` (and each language's file):

> The first release of Floorball Unleashed: Quick match, the World Finals and a club season, with a coach for your
> first match, in fifteen languages.

## The release itself

- Release name: the version, e.g. `0.8.2`.
- App signing: **Use Google-generated key** (Play App Signing). Upload the bundle signed with your upload key
  (`store/PLAY_STORE.md`, step 2). Do not upload the beta key.
- Version code: must be higher than any uploaded before (0.8.2 is code 12).
