# Kabaddi Raid on Google Play

Everything Google Play asks for, and the steps to put the game on it. Checked against Google's requirements as they
stand in October 2026.

## What only you can do

Everything else is ready (below). These steps need you, your Google account or your money:

1. **Make the developer account** and verify your identity (step 1; US$25).
2. **Make the upload key** and add it to GitHub as three secrets (step 2). Then run the Play bundle workflow to get
   a signed `.aab`.
3. **Create the app** in Play Console and **answer the App content forms**: copy the answers from
   `store/PLAY_CONSOLE_ANSWERS.md` (step 4).
4. **Fill in the store listing**: the text from `store/listing/`, the pictures from `store/graphics/`, and a
   **contact email** you are happy to show publicly (step 5).
5. **Run the closed test**: at least 12 testers for 14 days in a row, then apply for production (step 6).
6. **Choose the countries** and press **Release** (step 7).

## What is ready

- **The Play bundle (.aab)**, built by GitHub Actions ("Kabaddi Raid · Play Store bundle") on every new version.
  It is unsigned until your upload key is in the repository (step 2), then signed with it. 0.12.3's bundle:
  - about 104 MB, with both the 64-bit (arm64-v8a) and 32-bit (armeabi-v7a) builds; Play gives each phone only its
    own, **about 78 MB to download** (bundletool, measured on every bundle; the limit is 200 MB, so no Play Asset
    Delivery is needed);
  - **targets Android 16 (API 36)**, required for new apps since 31 August 2026 (API 35 before), and runs on
    Android 7.0 (API 24) and later;
  - **16 KB memory pages**: every 64-bit library's LOAD segments are aligned to 16 KB (`tools/check_pages.py`, run
    on every bundle and APK);
  - **one permission**, `android.permission.VIBRATE`, and no internet access; CI fails the bundle on any other
    permission (such as `INTERNET` or `DUMP`) and on a target below API 36;
  - marked as a game, so Android 16 keeps it in landscape on tablets and foldables;
  - **package name `com.kabaddiraid.game`**, the same as the beta APK and the Obtainium entry
    (`shared-assets/obtainium/ghost-kit-games.json`); it is final once the first bundle is uploaded. The **version
    code** (`version/code` in `export_presets.cfg`, 34 for 0.12.3) goes up by one with every version and never
    goes down: Play refuses a bundle whose code is not higher than the last one's.
- **Soak tested** (`tests/soak.gd`, 0.12.3): thousands of random taps, drags, Back presses and trips to the
  background through every screen on Low and on High, and AI-v-AI matches on every ground on both. The results are
  in `docs/PROGRESS.md`.
- **The privacy policy, help page and a page for the game**, in `kabaddi-raid/` at the top of this repository:
  - live on thekabaddipulse.com: https://thekabaddipulse.com/kabaddi-raid/, `/kabaddi-raid/privacy/` and
    `/kabaddi-raid/support/` (all HTTP 200 on 27 October 2026);
  - in the game too, readable offline (Settings > About: Help, Privacy policy, Licences, since 0.12.2), each with a
    View online button for the web page;
  - the web version's old addresses (https://kabaddi-raid-beta.netlify.app/privacy.html and `/support.html`, which
    builds up to 0.8.6 open) forward there (`tools/web/netlify.toml`).
- **The store listing** in all eight of the game's languages (`store/listing/`: English, Hindi, Marathi, Tamil,
  Telugu, Kannada, Bengali, Punjabi; `tools/check_listing.py` checks Play's length limits), the 512 × 512 icon,
  the 1024 × 500 feature graphic and eight 1920 × 1080 screenshots rendered from the game on High
  (`store/graphics/`).
- **The answers to every App content form** (`store/PLAY_CONSOLE_ANSWERS.md`): data safety, content rating,
  target audience, ads, purchases, category and tags.

## 1. Your developer account (once)

1. Go to https://play.google.com/console/signup and sign in with the Google account you want to own the game.
2. Choose **Yourself** (a personal account). An organisation account needs a D-U-N-S number, which can take up to a
   month.
3. Pay the one-time US$25 fee.
4. Verify your identity: your legal name and address, a government ID, your email and phone number. Google also
   asks you to verify a real Android phone with the Play Console app.
5. Your developer name, country and contact email are shown publicly on the store.

**New personal accounts must test first.** Before the game can be released to everyone, it has to run a closed
test with at least **12 testers** who stay opted in for **14 days in a row** (step 6).

## 2. The upload key (once)

Google signs the game for phones with its own key (**Play App Signing**, which Play Console turns on for every new
app). You sign each bundle you upload with your own **upload key**, so Google knows it came from you.

**Keep the beta key as it is.** The beta APKs on GitHub stay signed with the beta key (the `BETA_KEYSTORE_B64`
secret), so each beta keeps installing over the last. The Play build uses only the upload key below; the two never
mix, and the beta key must not be uploaded to Play.

1. Make the key, on a computer with Java (Android Studio includes it). In a terminal, run:

   ```
   keytool -genkeypair -v -keystore kabaddi-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```

   - Pick a strong password, and give the same one when asked for the key's password.
   - The name and organisation questions can be your own name.
2. **Keep `kabaddi-upload.jks` and the password safe**: in a password manager, plus a copy somewhere other than your
   computer. If you lose them, Play support can reset the upload key, but that takes days.
3. Copy the key file as text:
   - Mac: `base64 -i kabaddi-upload.jks | pbcopy`
   - Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("kabaddi-upload.jks")) | Set-Clipboard`
4. On GitHub, open the repository and go to **Settings > Secrets and variables > Actions > New repository
   secret**. Add three secrets:
   - `ANDROID_UPLOAD_KEYSTORE_BASE64`: paste what you copied in step 3.
   - `ANDROID_UPLOAD_KEY_ALIAS`: `upload`
   - `ANDROID_UPLOAD_KEY_PASSWORD`: your password.
5. Build the signed bundle:
   1. On GitHub, go to **Actions > Kabaddi Raid · Play Store bundle > Run workflow**.
   2. Pick the branch `claude/kabaddi-game-concept-asnz07`, then **Run workflow**.
   3. When it finishes (about 15 minutes), open the run. Under **Artifacts**, download
      `kabaddi-raid-<version>-play-signed`, a zip with the `.aab` inside.

## 3. Create the app

1. In Play Console, go to **Home > Create app**.
2. Fill in:
   - App name: **Kabaddi Raid**
   - Default language: **English (United States)**
   - App or game: **Game**
   - Free or paid: **Free**
3. Tick the two declarations, then **Create app**.

## 4. App content (Policy and programs > App content)

Answer each form like this (`store/PLAY_CONSOLE_ANSWERS.md` has each answer with the reason it is true, and the
full IARC questionnaire):

| Form | Answer |
|---|---|
| **Privacy policy** | `https://thekabaddipulse.com/kabaddi-raid/privacy/` |
| **Ads** | No, my app does not contain ads |
| **App access** | All functionality is available without any access restrictions |
| **Content rating** | See below. Expect 3+ (PEGI 3, ESRB Everyone) |
| **Target audience and content** | 13–15, 16–17 and 18+. Store listing appealing to children: No |
| **News apps** | No |
| **Data safety** | Collects or shares any of the required user data types: **No**. Account creation: the game has no accounts. The listing then shows "No data collected" and "No data shared" |
| **Government apps** | No |
| **Financial features** | My app doesn't provide any financial features |
| **Health apps** | My app does not have any health features |
| **Advertising ID** | No (the game does not use it) |

**Target audience.** The game suits every age, and the content rating says so to parents. Choosing an under-13 age
group would bring Google's Families policy and its extra review; the game would pass it, since it collects nothing
and shows no ads, but the 13+ groups are the simpler start.

**Content rating questionnaire (IARC).** Category: **Game**. Then:

| Question | Answer |
|---|---|
| Violence | No. Tackles are sport, with no blood or injuries |
| Fear, horror | No |
| Sexuality, nudity | No |
| Language | No |
| Controlled substances | No |
| Gambling, including simulated gambling | No. The auction spends a franchise's purse, not money |
| Users interact with each other, or share content | No |
| Shares the user's location | No |
| Digital purchases | No |

## 5. The store listing (Grow users > Store presence > Main store listing)

1. **App name, short description, full description**: copy them from `store/listing/en-US.txt`.
2. **The other seven languages** (optional): **Manage translations > Add your own translations**, then Hindi
   (`hi-IN.txt`), Marathi (`mr-IN.txt`), Tamil (`ta-IN.txt`), Telugu (`te-IN.txt`), Kannada (`kn-IN.txt`),
   Bengali (`bn-BD.txt`) and Punjabi (`pa-IN.txt`, if Play Console offers it), all in `store/listing/`.
3. **App icon**: `store/graphics/icon-512.png`.
4. **Feature graphic**: `store/graphics/feature-1024x500.png`.
5. **Phone screenshots**: upload the eight in `store/graphics/screenshots/`, in order. Games need at least three,
   landscape at 1920 × 1080, to be recommended by Play.
6. **7-inch and 10-inch tablet screenshots**: upload the same eight. They are 16:9, which Play accepts for tablets.
7. **Category**: **Store settings > App category: Game > Sports**. Add tags such as Sports.
8. **Contact details**:
   - **Email** (required, shown publicly): an address you are happy to show. The pages' contact is the site's
     contact form (https://thekabaddipulse.com/contact/), which cannot stand in for it.
   - **Website**: https://thekabaddipulse.com/kabaddi-raid/

## 6. The closed test (required for new personal accounts)

1. Go to **Test and release > Testing > Closed testing**, open the **Closed testing (Alpha)** track, and choose
   **Create new release**.
2. Upload the signed `.aab` from step 2.
3. Release name: the version, such as `0.8.4`. Release notes: copy them from `store/listing/en-US.txt`.
4. Choose **Save > Review release > Start rollout to Closed testing**. Google's first review takes a few days.
5. Under **Testers**, make an email list with at least 12 people's Google (Gmail) addresses: family and friends
   with Android phones.
6. Send them the **opt-in link** shown there. Each tester opens it, accepts, and installs the game from Play.
   - All 12 have to stay opted in for 14 days in a row. Ask them to keep it installed and play now and then.
   - Their feedback reaches you through Play.
7. **Countries**: choose where the test (and later the game) is available, such as India and your own country.
8. After 14 days, go to **Dashboard > Apply for production** and answer the questions about the test. Google
   reviews the application, usually within a week.

## 7. Release to everyone

1. Go to **Production > Create new release**, upload the latest signed `.aab`, add release notes and roll it out.
2. Every upload needs a higher version code. Each new version of the game raises it (`version/code` in
   `export_presets.cfg`).

## Notes

- **The beta APK on GitHub** is signed with a public debug key, not Play's, so a phone with the beta has to uninstall
  it (and lose its saves) before installing the game from Play.
- **Android's developer verification** covers apps installed from outside the stores too: in Brazil, Indonesia,
  Singapore and Thailand since September 2026, and worldwide from 2027. Before then, either point testers to Play,
  or sign the beta with your own key and register it in Play Console.
- **The privacy policy's address must keep working** while the game is on Play: keep
  https://thekabaddipulse.com/kabaddi-raid/privacy/ where it is. Builds up to 0.8.6 link to the Netlify site, which
  forwards there, so keep that site too.
- **Names**: the league, franchises and players in the game are made up, and real players' names are blocked
  (`autoload/db.gd`), so no league's or player's rights are involved. Do not add real logos or names.
