# Floorball Unleashed on Google Play

Everything Google Play asks for, and the steps to put the game on it. Checked against Google's requirements as they
stand in October 2026.

## What is ready

- **The Play bundle (.aab)**, built by GitHub Actions ("Floorball Unleashed · Play Store bundle"). It is unsigned until
  your upload key is in the repository (step 2), then signed with it.
- **The game meets Google's technical rules**:
  - targets Android 16 (API 36), required for new apps since 31 August 2026;
  - 64-bit, with 16 KB memory pages (checked on every bundle);
  - marked as a game, so Android 16 keeps it in landscape on tablets and foldables;
  - one permission (vibration) and no internet access.
- **The privacy policy, help and licences in the game**: Settings > About opens each as a page in the game itself
  (works offline; the game has no internet permission). The store's privacy address: TBD, the owner's own privacy
  site (store/PLAY_CONSOLE_ANSWERS.md).
- **The store listing**: the text in fifteen languages (`store/listing/`: en-US, sv-SE, fi-FI, de-DE, fr-FR, it-IT,
  cs-CZ, sk, no-NO, da-DK, lv, et, pl-PL, ja-JP, th), and the 512 × 512 icon, the 1024 × 500 feature graphic and
  the 1920 × 1080 screenshots (`store/graphics/`), as drafts: `bash tools/store/refresh_store_kit.sh` captures them
  again from the game just before submitting and checks them and the text against Play's limits.
- **The answers to every App content form** (step 4, and in full in `store/PLAY_CONSOLE_ANSWERS.md`).

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

**The Play build uses Play App Signing with an upload key you create.** Google keeps the app signing key and signs the
game for phones with it; you sign each bundle you upload with your own **upload key**, so Google knows it came from
you. **Do not use the beta key** (the one the GitHub beta APK is signed with, SHA-256 `6F:23:…:7B:A3`) for Play: it
stays the beta's, unchanged, and the Play upload key is a separate, new one. When Play Console asks at your first
upload, choose **Use Google-generated key** (Play App Signing).

1. Make the key, on a computer with Java (Android Studio includes it). In a terminal, run:

   ```
   keytool -genkeypair -v -keystore floorball-unleashed-upload.jks -storetype PKCS12 -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```

   - Pick a strong password, and give the same one when asked for the key's password.
   - The name and organisation questions can be your own name.
2. **Keep `floorball-unleashed-upload.jks` and the password safe**: in a password manager, plus a copy somewhere other than your
   computer. If you lose them, Play support can reset the upload key, but that takes days.
3. Copy the key file as text:
   - Mac: `base64 -i floorball-unleashed-upload.jks | pbcopy`
   - Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("floorball-unleashed-upload.jks")) | Set-Clipboard`
4. On GitHub, open the repository and go to **Settings > Secrets and variables > Actions > New repository
   secret**. Add three secrets:
   - `ANDROID_UPLOAD_KEYSTORE_BASE64`: paste what you copied in step 3.
   - `ANDROID_UPLOAD_KEY_ALIAS`: `upload`
   - `ANDROID_UPLOAD_KEY_PASSWORD`: your password.

   The bundle workflow (`.github/workflows/floorball-play-bundle.yml`) reads these three if they are there and signs
   the `.aab` with them; without them it builds the bundle unsigned. Never commit the key file or the password: this
   repository is public.
5. Build the signed bundle:
   1. On GitHub, go to **Actions > Floorball Unleashed · Play Store bundle > Run workflow**.
   2. Pick the branch `claude/floorball-game` (or `main` once merged), then **Run workflow**.
   3. When it finishes (about 15 minutes), open the run. Under **Artifacts**, download
      `floorball-unleashed-<version>-play-signed`, a zip with the `.aab` inside.

## 3. Create the app

1. In Play Console, go to **Home > Create app**.
2. Fill in:
   - App name: **Floorball Unleashed** (the store name; the game calls itself Floorball Unleashed)
   - Default language: **English (United States)**
   - App or game: **Game**
   - Free or paid: **Free**
3. Tick the two declarations, then **Create app**.

## 4. App content (Policy and programs > App content)

Answer each form like this:

| Form | Answer |
|---|---|
| **Privacy policy** | TBD: the owner's privacy site (store/PLAY_CONSOLE_ANSWERS.md) |
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
| Violence | No. It is a ball game; body contact is shoulder to shoulder and fouls are whistled |
| Fear, horror | No |
| Sexuality, nudity | No |
| Language | No |
| Controlled substances | No |
| Gambling, including simulated gambling | No |
| Users interact with each other, or share content | No |
| Shares the user's location | No |
| Digital purchases | No |

## 5. The store listing (Grow users > Store presence > Main store listing)

1. **App name, short description, full description**: copy them from `store/listing/en-US.txt`.
2. **Translations**: **Manage translations > Add your own translations**, one per file in `store/listing/`: Swedish
   (`sv-SE`), Finnish (`fi-FI`), German (`de-DE`), French (`fr-FR`), Italian (`it-IT`), Czech (`cs-CZ`), Slovak
   (`sk`), Norwegian (`no-NO`), Danish (`da-DK`), Latvian (`lv`), Estonian (`et`), Polish (`pl-PL`), Japanese
   (`ja-JP`) and Thai (`th`). The sport's players read these first: Sweden, Finland, Czechia and Switzerland are
   three-quarters of the world's players.
3. **App icon**: `store/graphics/icon-512.png`.
4. **Feature graphic**: `store/graphics/feature-1024x500.png`.
5. **Phone screenshots**: upload those in `store/graphics/screenshots/`, in order. Games need at least three,
   landscape at 1920 × 1080, to be recommended by Play.
6. **7-inch and 10-inch tablet screenshots**: upload the same ones. They are 16:9, which Play accepts for tablets.
7. **Category**: **Store settings > App category: Game > Sports**. Add tags such as Sports.
8. **Contact details**:
   - **Email** (required, shown publicly): an address you are happy to show (the help page uses
     joshnason8@gmail.com; change it there too if you use another).
   - **Website**: TBD: the owner's website.

## 6. The closed test (required for new personal accounts)

1. Go to **Test and release > Testing > Closed testing**, open the **Closed testing (Alpha)** track, and choose
   **Create new release**.
2. Upload the signed `.aab` from step 2.
3. Release name: the version, such as `0.1.0`. Release notes: copy them from `store/listing/en-US.txt`.
4. Choose **Save > Review release > Start rollout to Closed testing**. Google's first review takes a few days.
5. Under **Testers**, make an email list with at least 12 people's Google (Gmail) addresses: family and friends
   with Android phones.
6. Send them the **opt-in link** shown there. Each tester opens it, accepts, and installs the game from Play.
   - All 12 have to stay opted in for 14 days in a row. Ask them to keep it installed and play now and then.
   - Their feedback reaches you through Play.
7. **Countries**: choose where the test (and later the game) is available: Sweden, Finland, Switzerland, Czechia,
   Slovakia, Norway, Denmark, Latvia, Estonia, Germany, Austria and Poland first, then everywhere. A release before
   the men's world championship in Tampere (5-13 December 2026) catches the sport's biggest audience.
8. After 14 days, go to **Dashboard > Apply for production** and answer the questions about the test. Google
   reviews the application, usually within a week.

## 7. Release to everyone

1. Go to **Production > Create new release**, upload the latest signed `.aab`, add release notes and roll it out.
2. Every upload needs a higher version code. Each new version of the game raises it (`version/code` in
   `export_presets.cfg`).

## Notes

- **The beta APK on GitHub** is signed with the beta key, not Play's, so a phone with the beta has to uninstall
  it (and lose its saves) before installing the game from Play.
- **Android's developer verification** covers apps installed from outside the stores too: in Brazil, Indonesia,
  Singapore and Thailand since September 2026, and worldwide from 2027. Before then, either point testers to Play,
  or sign the beta with your own key and register it in Play Console.
- **The privacy policy's address must keep working** while the game is on Play: keep `docs/PRIVACY.md` (or the
  github.io page) where the listing points, and the same text as the game's Settings > About > Privacy policy.
- **Names**: only national teams appear, under their countries' names with flags drawn in code; the players are
  made up from each country's common names (`autoload/db.gd`). The game never names the IFF, a league, a club or a
  competition: the rules are "the international Rules of the Game" and the tournament is the game's own "World
  Finals". No logos, crests or kits are copied (the kits use each country's flag colours). Keep it that way.
- **The name**: no floorball game called Floorball Unleashed, or any floorball game at all, was found on Google Play
  (October 2026). A trademark search (EUIPO, USPTO, WIPO) before launch is still worth doing.
- **32-bit phones**: the bundle keeps armeabi-v7a, so older 32-bit Android phones (still common in Thailand, the
  Philippines and eastern Europe) get the game from Play; the beta APK on GitHub is 64-bit only.
