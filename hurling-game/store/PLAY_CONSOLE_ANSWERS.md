# Play Console answers: Hurling Heroes

The answers to Play Console's forms (Policy and programs > App content, and the store settings), true for the game as
it is (0.11.2, October 2026). Check them again if the game changes what it does: a new permission, an online
feature, an account, ads or purchases would each change an answer here.

## Privacy policy

**URL: TBD: the owner's privacy site** (the owner is building a website for the game's pages). Until then the policy
is in the game itself (Settings > About > Privacy policy) and in this repository (`ash-and-leather/privacy.html`); the
GitHub Pages address for that file answers 404 until this branch is merged into `main`, so it is not used here.
The policy on the site should say what the in-game one says (below), with its date.

## Ads

**No, my app does not contain ads.**

## App access

**All functionality is available without any access restrictions** (no account, no sign-in).

## In-app purchases

**None.** The game is free, with nothing to buy.

## Data safety

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | (not asked when the answer above is No) |
| Do you provide a way for users to request that their data is deleted? | (not asked when the answer above is No) |

Result on the listing: **No data collected. No data shared with third parties.**

Why that is true:

- The game has no account, no server, no analytics, no crash reporting, no advertising and no advertising ID. Its
  settings and progress stay in its own storage on the phone; nothing is sent anywhere.
- **The HD pack** (High graphics, optional): when the player taps the HD pack button, the game downloads the pack's
  files from the game's GitHub release. Like any download, GitHub's servers see the phone's internet address; the game
  sends nothing about the player, the phone or their play, and the developer receives nothing. Google's Data safety
  rules do not count data a user's own action sends to a service to fetch what they asked for, handled only to serve
  that request ("ephemeral processing", and "user-initiated action" for sharing), and the developer never has it, so
  it is neither "collected" nor "shared". The privacy policy says this in plain words.
- **Permissions**: internet (only the HD pack download) and vibration. No location, camera, microphone, contacts,
  files or phone state.

## Content rating (IARC questionnaire)

Category: **Game** (not a social or communication app). Email for the certificate: joshnason8@gmail.com.

| Question | Answer, and why |
|---|---|
| Violence | **No.** It is a field sport played to its rules: the players carry hurleys (sticks) to strike the ball, and tackle shoulder to shoulder, block and hook stick on stick. No one is struck with a hurley, no one is hurt, no injury, blood or fighting is shown; a foul is a free or a card, as in the real game. IARC treats sports played within their rules (football's tackles, hockey's checks) as no violence; the answer would change only if the game showed players hitting each other. |
| Fear / horror | No |
| Sexuality / nudity | No |
| Language (crude humour, profanity) | No |
| Controlled substances (alcohol, tobacco, drugs) | No (no drink advertising round the grounds either) |
| Gambling, simulated gambling | No |
| Users interact or exchange content | No (no online play, no chat) |
| Shares the user's current location | No |
| Digital purchases | No |
| Unrestricted internet access | No (the one download is the game's own HD pack, from a fixed address) |

Expected ratings: **PEGI 3, ESRB Everyone, USK 0**, and the same elsewhere.

## Target audience and content

**Recommended: 13–15, 16–17 and 18+. Store listing unintentionally appealing to children: No.**

The game would suit younger players, and it has nothing a child should not see: no ads, no purchases, no data
collected. But choosing any under-13 age group puts the game under Google's **Families policy**: extra review, the
Families ads and data rules (which it meets), the "Teacher Approved" programme's expectations, and a commitment to keep
every later update within them, including any online feature or SDK added later. Starting at 13+ keeps the first
release simple; the age groups can be widened later, once the game's updates have settled. The content rating still
tells parents the game is suitable for all ages.

## Other declarations

| Form | Answer |
|---|---|
| News apps | No |
| COVID-19 apps | No |
| Government apps | No |
| Financial features | My app doesn't provide any financial features |
| Health apps | My app does not have any health features |
| Advertising ID | No (the game does not use it; the manifest does not declare `AD_ID`) |
| Photo and video permissions | Not used |
| Foreground services, exact alarms, full-screen intents | Not used |

## Store settings

| Setting | Answer |
|---|---|
| App or game | Game |
| Category | **Sports** |
| Tags | Sports, Simulation, Offline, Single player (pick up to five Play offers under Sports) |
| Contact email (public) | joshnason8@gmail.com |
| Website | TBD: the owner's site |
| Phone | (optional; leave empty) |
| Countries | Ireland and the United Kingdom first, then the United States, Canada, Australia, New Zealand, then everywhere |

## Store listing

The text is in `store/listing/` (English (United Kingdom) the default, then en-US, en-AU, en-CA; `ga.txt` an Irish
draft for when Play offers Irish), checked against Play's limits by `python3 tools/store/check_listing.py`. The
graphics are in `store/graphics/`, made again from the current build by `tools/store/make_store_kit.sh`. The first
release's notes are the "Release notes (first Play release)" part of each listing file.
