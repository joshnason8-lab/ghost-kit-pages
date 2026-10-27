# Hurling Heroes on Google Play

Everything Google Play asks for, and the steps to put the game on it. Checked against Google's requirements as they
stand in October 2026.

## What is ready

- **The Play bundle (.aab)**, built by GitHub Actions ("Hurling Heroes · Play Store bundle"). It is unsigned until
  your upload key is in the repository (step 2), then signed with it.
- **The game meets Google's technical rules**:
  - targets Android 16 (API 36), required for new apps since 31 August 2026;
  - 64-bit, with 16 KB memory pages (checked on every bundle);
  - marked as a game, so Android 16 keeps it in landscape on tablets and foldables;
  - two permissions: vibration, and internet (used only to download the optional HD pack for High graphics from
    the game's GitHub release, when the player asks; nothing is sent about the player).
- **The privacy policy, help and licences in the game itself** (Settings > About; no browser, so they work
  offline). The privacy policy's web address for Play is **TBD: the owner's privacy site** (the owner is building it);
  `ash-and-leather/privacy.html` in this repository has the same words to put there.
- **The store listing**: the text for English (United Kingdom, the default, which Ireland sees), English (United
  States), English (Australia) and English (Canada) (`store/listing/`). Google Play has no Irish store listing, so
  each says the game is in Irish too, and two screenshots show it in Irish. The 512 × 512 icon, the 1024 × 500
  feature graphic and the 1920 × 1080 screenshots are in `store/graphics/`.
- **The answers to every App content form**: `store/PLAY_CONSOLE_ANSWERS.md` (step 4).
- **The technical checks**, below ("The build"), each made on every bundle or in the soak test.

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

Google signs the game for phones with its own key (Play App Signing). You sign each bundle you upload with your own
**upload key**, so Google knows it came from you.

1. Make the key, on a computer with Java (Android Studio includes it). In a terminal, run:

   ```
   keytool -genkeypair -v -keystore ash-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```

   - Pick a strong password, and give the same one when asked for the key's password.
   - The name and organisation questions can be your own name.
2. **Keep `ash-upload.jks` and the password safe**: in a password manager, plus a copy somewhere other than your
   computer. If you lose them, Play support can reset the upload key, but that takes days.
3. Copy the key file as text:
   - Mac: `base64 -i ash-upload.jks | pbcopy`
   - Windows (PowerShell): `[Convert]::ToBase64String([IO.File]::ReadAllBytes("ash-upload.jks")) | Set-Clipboard`
4. On GitHub, open the repository and go to **Settings > Secrets and variables > Actions > New repository
   secret**. Add three secrets:
   - `ANDROID_UPLOAD_KEYSTORE_BASE64`: paste what you copied in step 3.
   - `ANDROID_UPLOAD_KEY_ALIAS`: `upload`
   - `ANDROID_UPLOAD_KEY_PASSWORD`: your password.
5. Build the signed bundle:
   1. The bundle is built on every new version pushed (and signed once the secrets are there). To build it by hand,
      go to **Actions > Hurling Heroes · Play Store bundle > Run workflow** (GitHub offers this button once the
      workflow is on `main`).
   2. Pick the branch, then **Run workflow**.
   3. When it finishes (about 15 minutes), open the run. Under **Artifacts**, download
      `hurling-heroes-<version>-play-signed`, a zip with the `.aab` inside.

## 3. Create the app

1. In Play Console, go to **Home > Create app**.
2. Fill in:
   - App name: **Hurling Heroes**
   - Default language: **English (United Kingdom)**
   - App or game: **Game**
   - Free or paid: **Free**
3. Tick the two declarations, then **Create app**.

## 4. App content (Policy and programs > App content)

Answer each form as `store/PLAY_CONSOLE_ANSWERS.md` says: privacy policy, ads (none), app access, content rating
(IARC: expect PEGI 3 / ESRB Everyone), target audience (13+ recommended, and why), data safety (no data collected or
shared, and why the HD pack download does not change that), and the rest.

## 5. The store listing (Grow users > Store presence > Main store listing)

1. **App name, short description, full description**: copy them from `store/listing/en-GB.txt` (the default
   language).
2. **Translations**: **Manage translations > Add your own translations**: English (United States) `en-US.txt`,
   English (Australia) `en-AU.txt`, English (Canada) `en-CA.txt`. (Check whether Irish has been added to the list:
   in October 2026 it is not offered.)
3. **App icon**: `store/graphics/icon-512.png`.
4. **Feature graphic**: `store/graphics/feature-1024x500.png`.
5. **Phone screenshots**: upload those in `store/graphics/screenshots/`, in order. Games need at least three,
   landscape at 1920 × 1080, to be recommended by Play. They are drafts: make them again from the build you upload,
   just before you submit (`tools/store/make_store_kit.sh`, below).
6. **7-inch and 10-inch tablet screenshots**: upload the same ones. They are 16:9, which Play accepts for tablets.
7. **Category**: **Store settings > App category: Game > Sports**. Add tags such as Sports.
8. **Contact details**:
   - **Email** (required, shown publicly): an address you are happy to show (the help page uses
     joshnason8@gmail.com; change it there too if you use another).
   - **Website**: TBD: the owner's site.

## 6. The closed test (required for new personal accounts)

1. Go to **Test and release > Testing > Closed testing**, open the **Closed testing (Alpha)** track, and choose
   **Create new release**.
2. Upload the signed `.aab` from step 2.
3. Release name: the version, such as `0.2.0`. Release notes: copy them from `store/listing/en-GB.txt`.
4. Choose **Save > Review release > Start rollout to Closed testing**. Google's first review takes a few days.
5. Under **Testers**, make an email list with at least 12 people's Google (Gmail) addresses: family and friends
   with Android phones.
6. Send them the **opt-in link** shown there. Each tester opens it, accepts, and installs the game from Play.
   - All 12 have to stay opted in for 14 days in a row. Ask them to keep it installed and play now and then.
   - Their feedback reaches you through Play.
7. **Countries**: choose where the test (and later the game) is available: Ireland and the United Kingdom (for
   Northern Ireland and Britain's clubs) first, then the United States, Canada, Australia and New Zealand, then
   everywhere.
8. After 14 days, go to **Dashboard > Apply for production** and answer the questions about the test. Google
   reviews the application, usually within a week.

## 7. Release to everyone

1. Go to **Production > Create new release**, upload the latest signed `.aab`, add release notes and roll it out.
2. Every upload needs a higher version code. Each new version of the game raises it (`version/code` in
   `export_presets.cfg`).

## The build: Google Play's technical rules

Checked for 0.11.2 (versionCode 18). The bundle workflow ("Hurling Heroes · Play Store bundle") fails if any of the
first four stops being true.

| Rule | The game |
|---|---|
| **Target API** (35 or higher for new apps; 36 since 31 August 2026) | `targetSdkVersion 36` (Android 16), set by the bundle workflow and checked in the bundle's manifest |
| **Minimum Android** | `minSdkVersion 24`: Android 7.0 (Godot 4.7's minimum). |
| **Graphics API** | Vulkan (Godot's Mobile renderer) on every level. A phone without usable Vulkan (some Android 7–9 phones, older Mali, PowerVR and Adreno 3xx–5xx GPUs) is switched to OpenGL ES 3.0 (GL Compatibility) by itself: Godot falls back when Vulkan will not start, and the game sets GL from the next start on a phone known to struggle with Vulkan, on Android 9 or older, or after a start that crashed (`game/ultra.gd`, docs/GRAPHICS.md). On GL, High has everything but the real lighting. So the game runs on any phone with Android 7 and OpenGL ES 3.0, nearly all phones sold since 2015. |
| **64-bit**, 16 KB memory pages | arm64-v8a and armeabi-v7a (the 32-bit build kept for older phones; Play serves each phone its own). The 64-bit libraries' LOAD segments are aligned to 16 KB (`tools/check_pages.py` on every bundle: `libgodot_android.so` and `libc++_shared.so`, 0x4000). The beta APKs store the libraries compressed (extracted at install), so the APK's zip alignment does not apply to them; Play builds the bundle's APKs itself. |
| **Permissions** | Two: `INTERNET` (only the optional HD pack download) and `VIBRATE`. The workflow fails on any other. |
| **Bundle size** | 78 MB (0.11.1's .aab, zipped as the artifact), well under Play's 200 MB for the base module: no Play Asset Delivery needed. |
| **versionCode** | 18 for 0.11.2; it goes up by one with every version (`version/code` in `export_presets.cfg`) and has never gone down. Play refuses an upload whose code is not higher than the last. |
| **applicationId** | `com.ashandleather.game`: final (it is the beta's, and Obtainium's in `shared-assets/obtainium`; Play would treat any other as a new app). The name dates from the game's first title, Ash & Leather; players never see it. |
| **Downloaded code** | None. Play forbids an app to download executable code; the HD pack (docs/GRAPHICS.md) holds textures, meshes and animation data only. `tools/ultra/repack.gd` builds it from the files under `ultra/` alone and refuses any script, native library or resource carrying a script (42 files, content only). |
| **Stability** | `tests/soak.tscn`: thousands of random touches across every screen and into matches, the back button on every screen, the app sent to the background and back (the match kept and resumed), and AI v AI matches at every ground, on Low and on High. Results in docs/PROGRESS.md. |

**The HD pack and Play Asset Delivery.** The pack (114 MB, optional, High only, on recent high-end phones) is
downloaded by the game from its GitHub release when the player asks, checked by SHA-256 and mounted. That is allowed
(content only, no code), and the privacy policy and Data safety answers cover it. **Play Asset Delivery would be the
cleaner route for the Play build**: an **on-demand asset pack** in the bundle, served by Play from Google's servers
(no GitHub, no internet permission needed for it, Play's own download UI and storage accounting, updates with the
app). What it would take: Godot 4.7 exports asset packs only with a Gradle build and a plugin (the Play Asset Delivery
plugin for Godot, or the Play Core library in the Android build template); an `ultra` asset pack module with the
pack's files; the game's `Ultra` downloader asking Play for the pack instead of GitHub on the Play build (the beta
keeps GitHub); and testing through Play's internal app sharing. About two days' work, best done once the game's
other updates settle. Until then the GitHub download is policy-compliant as it is.

## 8. Refresh the store graphics before you submit

The screenshots, feature graphic and icon are drafts of the current build. To make them again (on a computer or in a
session with Godot 4.7, the HD pack's sources and a display or `xvfb-run`), from `hurling-game/`:

```
tools/store/make_store_kit.sh
```

It renders the nine screenshots on High with the HD pack (`tools/store/store_shots.tscn`, Vulkan), remakes the icon
and the feature graphic, and checks the listing text's lengths.

## Notes

- **The beta APK on GitHub** is signed with the owner's beta key (fingerprint 6F:23…7B:A3), not with Play's app
  signing key, so a phone with the beta has to uninstall it (and lose its saves) before installing the game from Play.
  Keep the beta key as it is: it is not the upload key.
- **Android's developer verification** covers apps installed from outside the stores too: in Brazil, Indonesia,
  Singapore and Thailand since September 2026, and worldwide from 2027. Before then, either point testers to Play,
  or sign the beta with your own key and register it in Play Console.
- **The privacy policy's address must keep working** while the game is on Play: once the owner's site is up, put
  its address in Play Console and in `store/PLAY_CONSOLE_ANSWERS.md`. (The game itself opens no web pages.)
- **Names**: the counties appear by their place names (in English and Irish), in their traditional colours but in
  kit designs of the game's own: no county board's crest, jersey design, sponsor or nickname. The competition is the
  game's own ("the Summer Championship", "the Tier Two Cup"), not the GAA's. Every player is invented, from common
  first names and surnames, with a list of well-known hurlers' names the game never makes (`autoload/db.gd`). The
  About page and the store listing say the game is not connected with any sporting body, county board or club. Keep
  it that way: no GAA, no "All-Ireland", no real cup's or stadium's name.
- **Category**: the bundle declares itself a game (`android:isGame`, checked by the bundle workflow), so Play files it
  under Games; choose **Sports** in the store settings.
