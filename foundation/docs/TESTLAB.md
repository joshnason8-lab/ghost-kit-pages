# Firebase Test Lab: the games on real phones

What it does: a game's frame rate and memory at Low, Medium and High on three real Android phones in Google's
device lab - a budget phone (a Galaxy A0x/A1x class: where the games' weak end is), a mid-range one and a flagship -
with a table in the GitHub run's summary:

| Phone | Tier | FPS avg | FPS worst 5% | FPS worst 1% | Frame ms p50 / p95 | Engine MB | Video MB | Phone MB free | Draw calls | Triangles | Starts on |
|---|---|---|---|---|---|---|---|---|---|---|---|

"Starts on" is the tier that phone would start on (WsgFoundation.starting_tier: weak Low, flagship High); the row
for that tier is the one that matters most.

## How it works

- The game has an export preset **"Android TestLab"** (the same as its Android one, with the custom feature
  `testlab`). That build opens on a match that plays itself - the AI on both sides, the broadcast camera, the
  biggest venue - 60 seconds at each tier after 8 to settle, and logs each tier as a `WSG_PERF {json}` line
  (`WsgPerfLog`, in the addon). Then it stays on a plain screen. The normal build excludes the `testlab/` folder.
- `.github/workflows/wsg-testlab.yml` (reusable) builds that APK, picks three phones from what Test Lab has that
  day (preference lists: budget, mid, flagship; or the game's own list), runs it there ("robo": Test Lab starts the
  app; the build ignores its taps and Back), and reads the lines back from each phone's log.
- A game calls it with a few lines (Hurling: `.github/workflows/hurling-testlab.yml`, run from the Actions tab:
  "Run workflow"). Without the secret below it says "Test Lab skipped" and stops, green.

## What the owner does once (about 10 minutes)

1. **A Firebase project.** console.firebase.google.com - "Add project" (e.g. `world-stage-games`; Google Analytics
   is not needed). The free **Spark** plan is enough to start.
2. **Turn on the APIs.** In console.cloud.google.com, with that project selected: "APIs & Services" - "Enable APIs"
   - enable **Cloud Testing API** and **Cloud Tool Results API**.
3. **A service account for GitHub.** console.cloud.google.com - "IAM & Admin" - "Service Accounts" - "Create
   service account" (name `github-testlab`). Give it the roles **Firebase Test Lab Admin** and **Storage Object
   Viewer** (it reads the results back), and on the project **Service Usage Consumer**. Then the account - "Keys" -
   "Add key" - "Create new key" - **JSON**: a file downloads.
4. **The secret.** github.com/joshnason8-lab/ghost-kit-pages - Settings - Secrets and variables - Actions - "New
   repository secret": name **`FIREBASE_TESTLAB_KEY`**, value: the whole JSON file's text. Then delete the file
   from your computer (the key can be revoked in step 3's "Keys" any time).
5. **Run it.** Actions - "Hurling Heroes · Test Lab" - "Run workflow". About 15 minutes; the table is on the run's
   page.

## The Spark plan's limits

Test Lab on the free plan has a daily quota - at the time of writing **5 tests a day on physical phones and 10 on
virtual ones** (each phone in a run is one test). A run here is **3 physical tests**, so **one run a day** on
Spark; that is why it runs when asked, not on every push. Check today's numbers in the Firebase console - Test Lab
- "Usage". On the pay-as-you-go **Blaze** plan physical phones cost about $5 per device-hour, billed by the minute (a run
here is about 20 device-minutes: under $2), with the same free daily quota first; check the current price list.

## Choosing the phones

The automatic three are the first of each list Test Lab has (physical, Android 10 or later) - budget: Galaxy A03s,
A02, A12, A13, A10...; mid: Pixel 6a, 7a, Galaxy A52, A53, A54...; flagship: Galaxy S24 Ultra, S23 Ultra, S23, S22
Ultra, Pixel 8 Pro... A game can name its own: `with: { devices: "a03s,30;bluejay,33;e3q,34" }` (Test Lab model id,
Android API level; `gcloud firebase test android models list` shows them).

## Reading it

- **FPS worst 1%** is the stutter a player feels; a phone that holds 30 on average but drops to 12 for 1% of
  frames feels worse than one at a steady 25.
- **Phone MB free** under about 300 on a budget phone: Android may close the game in the background.
- A budget phone below 25 FPS on Low: the game's Low needs trimming (docs/BUDGET.md); a flagship below 45 on High:
  High needs trimming, or that phone should start on Medium (block_vulkan / the device class lists).
