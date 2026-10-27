# Kho Kho Rush: Play Console answers

The true answers for every form in Play Console, for this build (checked against `export_presets.cfg` and the
bundle's manifest on 27 October 2026). Where a form asks the same thing twice, the answer is the same. If the game
ever adds an internet feature, ads, analytics or purchases, every answer below has to be read again.

## The facts the answers rest on

- **Permissions**: one, `android.permission.VIBRATE` (the bundle's manifest, checked on every Play build). No
  internet permission, so the game cannot send anything anywhere.
- **Data kept**: settings and progress (the championship in play, the record book), in the game's private storage on
  the phone. Never sent anywhere; deleted when the game is uninstalled.
- **No** account, sign-in, server, ads, analytics, crash reporting, advertising ID, in-app purchases or links out.
- **Third-party code**: the Godot Engine only (no SDKs).

## App content (Policy and programs > App content)

| Form | Answer |
|---|---|
| **Privacy policy URL** | TBD: owner's privacy site. (The policy is also inside the game: Settings > About > Privacy policy.) |
| **Ads** | No, my app does not contain ads |
| **App access** | All functionality is available without any access restrictions |
| **Content rating** | The questionnaire below. Expect PEGI 3 / ESRB Everyone / IARC 3+ |
| **Target audience and content** | 13–15, 16–17, 18+ (see below). Appeals to children: No |
| **News apps** | No |
| **Health apps** | My app does not have any health features |
| **Financial features** | My app doesn't provide any financial features |
| **Government apps** | No |
| **Advertising ID** | No, my app does not use advertising ID |
| **Data safety** | Below |

### Data safety

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not asked once the answer above is No (nothing is sent) |
| Do you provide a way for users to request that their data is deleted? | Not asked (nothing is collected). Uninstalling deletes what is kept on the phone |
| Account creation | My app does not allow users to create an account |

The listing then shows **No data collected** and **No data shared with third parties**.

### Content rating (IARC questionnaire)

Category: **Game**. Email for the rating certificate: joshnason8@gmail.com.

| Question | Answer and why |
|---|---|
| Violence | **No.** A tag game: a player touches another on the back or arm, and dives to the ground to reach. No fighting, no blood, no injury |
| Fear / horror | No |
| Sexuality / nudity | No |
| Language (profanity, crude humour) | No |
| Controlled substances (drugs, alcohol, tobacco) | No |
| Gambling or simulated gambling | No. (The coin toss before a match only picks who chases first; nothing is staked) |
| Users interact or share content | No (no online play, chat or sharing) |
| Shares the user's physical location | No |
| Digital purchases | No |
| Unrestricted internet access | No |

### Target audience: 13+ recommended

The game has nothing unsuitable for children, collects nothing and shows no ads. Even so, choose **13–15, 16–17 and
18+** for the first release and leave the under-13 groups unticked:

- Ticking any group under 13 puts the app under Google's **Families policy**. That brings an extra review of every
  release and a stricter set of rules (every SDK must be Families-certified, the store listing is judged for
  appeal to children, and so on). The game would very likely pass, but nobody has reviewed it against that policy
  yet, and it would apply to every future update.
- The content rating (expected 3+) still tells parents the game is fine for all ages.
- An under-13 audience can be added later, after reading the Families policy against the game then.

## Store settings

| Field | Answer |
|---|---|
| App or game | Game |
| Category | **Sports** |
| Tags (up to 5) | Sports, Offline, Single player, Realistic, Casual |
| Email (public) | joshnason8@gmail.com |
| Website | TBD: owner's site |
| Phone | Leave empty |
| Ads | No |
| In-app purchases | None |
| Price | Free |

## The listing kit

- Text: `store/listing/*.txt` (app name ≤ 30, short description ≤ 80, full description ≤ 4000 characters; English
  US, UK and India, and Hindi, Marathi, Kannada, Telugu, Tamil, Malayalam, Bengali, Gujarati, Punjabi, Nepali and
  Sinhala). Each file also has the release notes.
- Graphics: `store/graphics/` (512 × 512 icon, 1024 × 500 feature graphic, phone screenshots at 1920 × 1080).
  Drafts: regenerate them from the current build just before submitting, with `tools/store/make_kit.sh`
  (store/PLAY_STORE.md, "Graphics").
- First release notes: `store/listing/*.txt`, "First release notes".
