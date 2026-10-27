# Pok Ta Pok Rivals: Play Console answers

The answers to every form in **Play Console > Policy and programs > App content** and **Store settings**, with the
reason for each, checked against this build (0.5.3-beta: one permission, no internet, nothing collected). If the game
ever changes in a way that touches one of these (an ad, a leaderboard, a link, a crash reporter), the answer has to
change before that build is uploaded.

## Privacy policy

| | |
|---|---|
| URL | **TBD: owner's privacy site** |
| Before you submit | Put the policy on your privacy site, open its address in a browser to check it loads, and give that address here. Play rejects a privacy policy URL that does not load. |

Use the text of the policy inside the game (Settings > About > Privacy policy, dated 27 October 2026; `PRIV_*` in
`i18n/src/`) or `pok-ta-pok-rivals/privacy.html`, which says the same.

## Ads

**No, my app does not contain ads.** There is no ad library in the build.

## App access

**All functionality is available without any access restrictions.** There are no accounts or logins.

## Content rating (IARC questionnaire)

Email: joshnason8@gmail.com. Category: **Game**.

| Question | Answer | Why |
|---|---|---|
| Violence (any, cartoon, fantasy, realistic, blood, gore) | **No** | A ball sport. Players strike a ball with their hips and dive to the ground for it. There is no contact between players, no injury and no blood. |
| Fear, horror, frightening scenes | **No** | |
| Sexuality, nudity, sexual references | **No** | The players are men, bare to the waist as the sport's players are. They wear ulama's deerskin loincloth (gamuza) and belts, or on the classic court the cotton loincloth and padded hip yoke of the old carvings. Nothing is sexual, and there is no nudity beyond a bare chest. |
| Language (profanity, crude humour) | **No** | |
| Controlled substances (drugs, alcohol, tobacco) | **No** | The copal before the stone-court games is incense (tree resin), not a drug. |
| Gambling, simulated gambling, real-money gambling | **No** | No betting, no casino games, no loot boxes. |
| Discriminatory content, hate speech | **No** | |
| Users interact or exchange content | **No** | Single player on one phone; no chat, no online play. |
| Shares the user's current location | **No** | The game cannot use location. |
| Digital purchases | **No** | |
| Unrestricted internet / web browser | **No** | The game has no internet permission and opens no web pages. |

**The ritual and the history, answered honestly.**
- Before games on the stone courts, an elder walks among the players with a censer of burning copal, and they raise
  their arms. A conch sounds.
  - This is the offering held before pelota maya games in Yucatán today.
  - It is shown respectfully and plainly, it takes a few seconds, and a tap skips it (docs/CULTURE.md).
  - It is a cultural and religious observance, not violence, horror, drugs or gambling. None of the IARC categories
    above applies, so nothing needs to be disclosed.
- The ancient ballgame's association with human sacrifice is not shown or mentioned anywhere in the game or the store
  graphics.
  - How to Play's story pages cover the game's age, its names, ulama today and its revival, in a few neutral
    sentences.
  - There is no death, blood or sacrifice imagery.

**Expected rating:** the lowest everywhere (PEGI 3, ESRB Everyone, USK 0, ClassInd L, IARC 3+).

## Target audience and content

| | |
|---|---|
| Target age groups | **13–15, 16–17, 18 and over** |
| Is the store listing designed to appeal to children? | **No** |
| Is the app designed for children? | **No** |

**Why 13+ and not the children's groups.**
- The content suits every age, and the rating says so to parents.
- Choosing any under-13 group opts the game into Google's **Families policy**, which brings:
  - extra review;
  - the Families ads rules;
  - a Teacher Approved / Designed for Families commitment;
  - re-checks on every update.
- The game would pass on content, since it has no ads, no data and no links. But it is built as a sports game for
  teenagers and adults. Its tutorial and difficulty assume that, and it has not been reviewed against the Families
  requirements (for example, its timing-based controls are not designed for young children).
- So start with 13+. If the owner later wants children as a target audience, re-answer this form, and Play will run
  the Families review then.

## Data safety

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not asked once the answer above is No. Nothing leaves the phone. |
| Do you provide a way for users to request that their data is deleted? | Not asked once the answer above is No. Uninstalling the game deletes its saves. |
| Account creation | The app does not let users create an account. |

**Why "No" is true.**
- The manifest has one permission, `android.permission.VIBRATE`. The bundle workflow fails if any other permission
  appears, or if `INTERNET` does.
- Without the internet permission, nothing can be sent anywhere.
- The settings, tournament and records are stored in the app's private storage and never leave the phone.
- There are no analytics, crash-reporting, ads or other SDKs.
- Android vitals (crash and ANR data Google gathers from the phone itself) is Google's collection, not the app's. It
  is not declared.

The listing will show "No data collected" and "No data shared with third parties".

## Advertising ID

**No.** The app does not use the advertising ID, and the manifest has no `AD_ID` permission.

## Other declarations

| Form | Answer |
|---|---|
| Government apps | No |
| Financial features | My app doesn't provide any financial features |
| Health apps | My app does not have any health features |
| News apps | No |
| COVID-19 contact tracing / status | No (if the form appears) |
| Photo and video permissions, health connect, foreground service, full-screen intent, exact alarm | Not used: the app asks for none of these permissions |

## Monetisation

- **Ads:** none.
- **In-app purchases:** none.
- **Price:** free.

## Store settings

| | |
|---|---|
| App or game | **Game** |
| Category | **Sports** |
| Tags (choose up to five from Play's list) | Sports; Offline; Single player; Realistic; Casual (pick the nearest names Play offers) |
| Contact email (shown publicly) | **joshnason8@gmail.com** (the in-game Help and Privacy pages give the same address; change them together if you use another) |
| Website (optional) | TBD: the owner's site |
| Phone (optional) | Leave empty |
| External marketing | Your choice |

## Countries

Suggested order:
1. Mexico.
2. Guatemala, Belize, Honduras, El Salvador and the United States.
3. Brazil, Canada and Europe.
4. Everywhere.

The listing is ready in es-419, es-US, es-ES, en-US, en-GB, en-CA, pt-BR, fr-FR, fr-CA, de-DE and it-IT
(`store/listing/`).
