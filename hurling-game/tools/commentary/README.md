# Commentary: two voices, made with ElevenLabs

The game has two commentators, as a TV broadcast does:

- **Mick** (voice A) calls the play. His lines are short, in the present tense, and lift for scores: "Fahy... and he splits the posts!"
- **Ger** (voice B) is a former hurler. He comes in after the call to explain it: puck-outs, the wind, runners, turnovers.

Every line is in [`SCRIPT.md`](SCRIPT.md), generated from [`script.py`](script.py). Change `script.py`, not `SCRIPT.md`, then run
`python3 tools/commentary/script.py`.

The game reads `assets/commentary/lines.json` and plays `assets/commentary/<id>.ogg` (or `.mp3`).
- A line with no recording is skipped, so the game works with none, some or all of the lines recorded.
- [`game/commentary.gd`](../../game/commentary.gd) decides **when** each line is said.

## How the game decides when to talk

These rules are based on what a real broadcast does:

- **One voice at a time.** A line never starts over another one.
- **The bigger moment wins.** A goal, a save or the final whistle cuts straight across small talk. A tackle waits its turn.
- **Late calls are dropped.** A call is skipped once it's too late to make sense (a wide two seconds later, a point 2.5 s later), so the commentators are never describing an earlier play.
- **Ger follows Mick** when there's room, more often for big moments: 80% after a goal, 35% after a point.
- **Name first.** For the man on the ball, Mick says the surname first ("Hogan...") and then a line written to follow a name.
- **Replays get Ger's analysis.** His commentary keeps running while the replay plays. When a replay follows, his word goes over the replay instead of straight after the call.
- **Puck-outs.** These are called as the keeper takes them, after the replay, not when they're awarded.
- **The score after a score.** Straight after the call, and before Ger's word over the replay, Mick says where it leaves the match ("Galway... edge in front by a point"):
  - level;
  - a one-point game;
  - a big lead;
  - a comeback;
  - or "the last few minutes" when it's close and late.
- **The man on the ball.** When nobody is talking, Mick names whoever wins the ball ("Hogan..."), as a broadcast follows the play. He never names the same man twice running. This reuses the surname recordings, so it costs no extra credits.
- **Quiet spells.** After 12 s of live play with nothing said, one of them talks about the game in general.
- **No repeats.** The same call is never made twice in a few seconds, and every line in a group is used before any repeats.
- **The crowd dips** under the voices. Commentary pauses with the game.
- **When it's on.** It's off in practice and in the menu's background match. It's on in quick matches, the championship and Watch AI. **Settings → Sound and controls → Commentary** turns it off.

The style was learned from a full match broadcast the owner shared (studied only, never put in the game):
- Pace: about 165 words a minute while talking, and they talk nearly all the time.
- Calls: short and clipped ("Against the wind." "The ball is wide."), with exclamations at scores and saves.
- Ger: tactical talk in the gaps.

None of its wording is copied.

## What it costs on the free plan

| | |
|---|---|
| Lines | 267: 207 commentary lines, 40 surnames, 20 counties |
| Characters | **about 8,620** (Mick 4,380, Ger 4,240) |
| Free plan | 10,000 credits a month |
| Credits per character | Multilingual v2 and v3: 1. Flash / Turbo: 0.5 |

On Multilingual v2, everything fits in one month's free credits with about 1,400 left for retakes. Every regeneration costs credits too, so:

1. **First month:** record the names and counties (555 characters) and the important groups:
   - goal, point, point_long, point_free, wide, save;
   - throw_in, half_time, full_time;
   - level, lead_one.
2. **Next month:** record everything else.
3. If credits are short, use **Flash v2.5** at half the cost. It sounds a little flatter, but it's fine for the short calls.

**Licence: this matters before release.**
- The **free plan is non-commercial only** and requires crediting ElevenLabs.
- **Before the game goes on sale, or carries ads or purchases**, the voices must be generated on a paid plan. **Starter** (about $5 a month) gives a commercial licence.
- Generate (or regenerate) the final files while subscribed. One month is enough; the licence for audio made on a paid plan stays after you cancel. Check ElevenLabs' current terms when you do this.
- Add ElevenLabs to the in-game licences screen when the recordings go in.

## Step 1: pick the two voices (no credits used)

Both commentators need **Irish accents**.

1. Sign in at elevenlabs.io and open **Voices → Explore** (the Voice Library).
2. Filter by **Language: English** and **Accent: Irish**. Also try searching "Irish", "Cork", "Kerry", "Dublin" and "sports".
3. Listen to the previews:
   - **Mick:** an older man with energy and a clear Munster or midlands sound, who can lift his voice. Search terms like "narrator", "announcer" and "sports" help.
   - **Ger:** a calmer, deeper man who sounds conversational and dry, like an ex-player.
   - Make the two voices **clearly different** in pitch and pace, so the player can always tell who is talking.
4. Click **Add to my voices** for each. The free plan holds a few custom voices.

**If the Library has nothing right:** use **Voices → Create → Voice Design** and describe the voice. It costs a few credits per preview. For example:
- *Mick:* "Irish man in his fifties from County Tipperary, a GAA radio commentator. Fast, energetic, clear Munster accent, his voice rises with excitement at scores. Broadcast quality, close microphone."
- *Ger:* "Irish man in his forties from Galway, a former hurler working as a TV analyst. Relaxed, warm, measured, conversational, a soft west of Ireland accent. Broadcast quality."

Save the one that sounds right.

**Don't clone a real commentator's voice.** That includes the RTÉ commentators from the broadcast.

## Step 2: settings per tone

Each line in SCRIPT.md has a **tone**. Use these settings on the Text to Speech page (the ⚙ settings), or let `generate.py` set them:

| tone | used for | stability | style | similarity |
|---|---|---|---|---|
| call | short calls, names | 0.45 | 0.25 | 0.8 |
| flat | frees, sideline, puck-outs | 0.6 | 0.1 | 0.8 |
| lift | throw-in, attacks | 0.4 | 0.35 | 0.8 |
| rise | building play | 0.35 | 0.45 | 0.8 |
| shout | goals, saves | 0.25 | 0.7 | 0.75 |
| big | the final whistle | 0.3 | 0.6 | 0.75 |
| warm | everything Ger says | 0.55 | 0.2 | 0.8 |

- Lower stability means more expressive but less predictable delivery. Retake a shouted line if it comes out wrong.
- **Model:** use *Eleven Multilingual v2*; it has the steadiest accent.
- *Eleven v3* is more lively and understands tags like `[excited]` or `[shouting]` at the start of a line. Try it on the goal lines if v2 sounds too calm, but keep the tags out of `script.py` (they'd be counted as characters to say).
- **Speed:** leave Mick at 1.0–1.1 and Ger at 0.95.

## Step 3a: make them by hand (the website)

1. Open **Text to Speech**, pick Mick's voice and the settings for the tone.
2. Paste one line from SCRIPT.md and generate it.
3. Download the MP3 and **rename it to the line's id**, for example `goal_a1.mp3` or `name_23.mp3`.
4. Put the files in `hurling-game/assets/commentary/`.

The game plays `.mp3` as well as `.ogg`, so you can drop them straight in. `.ogg` files are smaller in the app.

To convert them all:
`for f in *.mp3; do ffmpeg -i "$f" -ac 1 -c:a libvorbis -q:a 4 "${f%.mp3}.ogg"; done`

Some tips:
- Do the names one at a time: "Ryan...". The dots make him trail off ready for the next line.
- Lines marked "(after a name)" start in lower case ("and he splits the posts!") because they follow straight on from the name.

## Step 3b: or let the script make them (the API)

[`generate.py`](generate.py) makes every missing line for you, with the right voice and tone, and converts it to `.ogg`.

1. In ElevenLabs, open **Profile → API keys** and create a key.
2. Copy each voice's **Voice ID** from its menu in **My voices**.
3. On your own computer, in `hurling-game/`, run:

```sh
export ELEVENLABS_API_KEY=...        # never paste it into a file in the repo, never commit it
export ELEVENLABS_VOICE_MICK=...     # the voice ids
export ELEVENLABS_VOICE_GER=...
python3 tools/commentary/generate.py --dry-run           # what it would make, and the characters it costs
python3 tools/commentary/generate.py --first --budget 5000   # the important groups first, stopping at 5,000 characters
python3 tools/commentary/generate.py --budget 4000       # next month: the rest
```

- It only makes lines that don't have a file yet, so running it again never spends credits twice.
- To retake a line, delete its file and run the script again.
- It needs Python 3 and ffmpeg.

## Step 4: listen in the game

- Play a match, or use **Watch AI**, which is the quickest way to hear lots of it.
- To render a film of a Watch AI match with the commentary, use the command at the top of [`preview.gd`](preview.gd). It prints each line as it's said.
- If a line sounds wrong, delete its file and remake it. If the wording is wrong, change `script.py`, run it, and remake that id.

**Changing the script changes ids.** Ids are numbered within each group, so adding a line in the middle of a group renumbers the lines after it. Add new lines at the end of a group to keep the existing files matching.

## Placeholder voices (for testing only)

The preview film made during development used stand-in voices from Piper, a free offline TTS, with British English voices. They aren't Irish and aren't good enough to ship; they only test the timing. They are never committed.
