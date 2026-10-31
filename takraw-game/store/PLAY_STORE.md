# Sepak Takraw Unleashed on Google Play

Everything Google Play asks for, and the steps to put the game on it. Checked against Google's requirements as they
stand in October 2026.

## What is ready

- **The Play bundle (.aab)**, built by GitHub Actions ("Sepak Takraw Unleashed · Play Store bundle"). It is unsigned until
  your upload key is in the repository (step 2), then signed with it.
- **The game meets Google's technical rules**:
  - targets Android 16 (API 36), required for new apps since 31 August 2026;
  - 64-bit, with 16 KB memory pages;
  - marked as a game, so Android 16 keeps it in landscape on tablets and foldables;
  - one permission (vibration) and no internet access.
  Every bundle is checked for all four: the bundle workflow fails on a target other than API 36, a native library not
  aligned to 16 KB, or any permission but vibration (so none can creep in without the Play answers changing too).
- **The privacy policy, help page and a page for the game**, in `takraw-smash/` at the top of this repository,
  served by GitHub Pages once this branch is merged into `main`:
  https://joshnason8-lab.github.io/ghost-kit-pages/takraw-smash/privacy.html and `/support.html` (they return 404
  until then: Pages serves `main`). Until the merge, the policy loads (HTTP 200) on GitHub as
  https://github.com/joshnason8-lab/ghost-kit-pages/blob/claude/kind-clarke-3g5fqs/takraw-smash/PRIVACY.md. The game
  itself needs neither: Settings > About shows the privacy policy, the help and the licences in the game, offline.
- **The store listing** (drafts until the game is ready to submit): the text in all thirteen of the game's languages
  (`store/listing/`), and the 512 × 512 icon, the 1024 × 500 feature graphic and eight 1920 × 1080 screenshots from
  the game (`store/graphics/`), each remade from the current build by a script (step 5).
- **The answers to every App content form**: `store/PLAY_CONSOLE_ANSWERS.md` (step 4).
- **A soak test**: `tools/soak.sh` (random input on every screen, the phone's Back, the app paused and resumed, then
  AI-v-AI matches on Low and High), clean before each release.

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

Google signs the game for phones with its own key (**Play App Signing**: accept it when Play Console offers it on the
first upload). You sign each bundle you upload with your own **upload key**, so Google knows it came from you.
**Don't use the beta key for Play, and don't replace it**: the beta key (`BETA_KEYSTORE_B64`, certificate SHA-256
6F:23:…:7B:A3) keeps signing the beta APKs on GitHub so they keep installing over each other; the upload key is a
separate key, for Play only.

1. Make the key, on a computer with Java (Android Studio includes it). In a terminal, run:

   ```
   keytool -genkeypair -v -keystore takraw-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```

   - Pick a strong password, and give the same one when asked for the key's password.
   - The name and organisation questions can be your own name.
2. **Keep `takraw-upload.jks` and the password safe**: in a password manager, plus a copy somewhere other than your
   computer. If you lose them, Play support can reset the upload key, but that takes days.
3. Copy the key file as text:
   - Mac: `base64 -i takraw-upload.jks | pbcopy`
   - Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("takraw-upload.jks")) | Set-Clipboard`
4. On GitHub, open the repository and go to **Settings > Secrets and variables > Actions > New repository
   secret**. Add three secrets:
   - `ANDROID_UPLOAD_KEYSTORE_BASE64`: paste what you copied in step 3.
   - `ANDROID_UPLOAD_KEY_ALIAS`: `upload`
   - `ANDROID_UPLOAD_KEY_PASSWORD`: your password.
5. Build the signed bundle:
   1. On GitHub, go to **Actions > Sepak Takraw Unleashed · Play Store bundle > Run workflow**.
   2. Pick the branch `claude/kind-clarke-3g5fqs` (or `main` once merged), then **Run workflow**.
   3. When it finishes (about 15 minutes), open the run. Under **Artifacts**, download
      `sepak-takraw-unleashed-<version>-play-signed`, a zip with the `.aab` inside.

## 3. Create the app

1. In Play Console, go to **Home > Create app**.
2. Fill in:
   - App name: **Sepak Takraw Unleashed**
   - Default language: **English (United States)**
   - App or game: **Game**
   - Free or paid: **Free**
3. Tick the two declarations, then **Create app**.

## 4. App content (Policy and programs > App content)

Answer each form like this:

| Form | Answer |
|---|---|
| **Privacy policy** | TBD: the owner's privacy site (the text is `takraw-smash/PRIVACY.md`, the same as the game's own). Check the address loads before submitting. |
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
| Violence | No. It is a ball game |
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
2. **Translations**: **Manage translations > Add your own translations**, one for each of the game's other twelve
   languages, from `store/listing/`: Thai (`th-TH.txt`), Malay (`ms.txt`), Indonesian (`id.txt`), Vietnamese (`vi.txt`),
   Lao (`lo-LA.txt`), Burmese (`my-MM.txt`), Khmer (`km-KH.txt`), Filipino (`fil.txt`), Japanese (`ja-JP.txt`), Korean
   (`ko-KR.txt`), Chinese (Simplified, `zh-CN.txt`) and Hindi (`hi-IN.txt`). The sport's players read these first.
3. **App icon**: `store/graphics/icon-512.png`.
4. **Feature graphic**: `store/graphics/feature-1024x500.png`.
5. **Phone screenshots**: upload the eight in `store/graphics/screenshots/`, in order. Games need at least three,
   landscape at 1920 × 1080, to be recommended by Play. They are drafts: just before submitting, remake them (and the
   feature graphic) from the current build, on a computer with Godot 4.7 and Python 3 with Pillow:

   ```
   cd takraw-game
   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tools/store/store_shots.tscn
   python3 tools/store/make_feature.py
   ```

   (Without `xvfb-run`, on a desktop: the same `godot` line without it.)
6. **7-inch and 10-inch tablet screenshots**: upload the same eight. They are 16:9, which Play accepts for tablets.
7. **Category**: **Store settings > App category: Game > Sports**. Add tags such as Sports.
8. **Contact details**:
   - **Email** (required, shown publicly): an address you are happy to show (the help page uses
     joshnason8@gmail.com; change it there too if you use another).
   - **Website**: the owner's site, when it is up (optional).

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
7. **Countries**: choose where the test (and later the game) is available: Thailand, Malaysia, Indonesia, Vietnam,
   the Philippines, Laos, Myanmar, Cambodia, Singapore and Brunei first, then everywhere.
8. After 14 days, go to **Dashboard > Apply for production** and answer the questions about the test. Google
   reviews the application, usually within a week.

## 7. Release to everyone

1. Go to **Production > Create new release**, upload the latest signed `.aab`, add release notes and roll it out.
2. Every upload needs a higher version code. Each new version of the game raises it (`version/code` in
   `export_presets.cfg`).

## Notes

- **The beta APK on GitHub** is signed with the owner's beta key, not Play's, so a phone with the beta has to
  uninstall it (and lose its saves) before installing the game from Play.
- **Android's developer verification** covers apps installed from outside the stores too: in Brazil, Indonesia,
  Singapore and Thailand since September 2026, and worldwide from 2027. Before then, either point testers to Play,
  or sign the beta with your own key and register it in Play Console.
- **The privacy policy's address must keep working** while the game is on Play (the game links to no web page: its
  Settings show the policy in the game).
- **Names**: the clubs, leagues, tournaments and players are made up (`autoload/db.gd`); countries appear with flags
  drawn in code. No federation's, league's, club's or player's names or logos are used, so no rights are involved.
  Keep it that way: the World Cup, Royal Cup and the championships are the game's own names, not ISTAF's events.
