"""Makes the commentary's missing recordings with ElevenLabs: each line of assets/commentary/lines.json that has no
assets/commentary/<id>.ogg|.mp3 yet, in its commentator's voice and its tone's settings, saved as <id>.ogg.
Run on your own computer (README.md, step 3b); needs python3 and ffmpeg. The API key comes from the environment only:
  export ELEVENLABS_API_KEY=...  ELEVENLABS_VOICE_MICK=...  ELEVENLABS_VOICE_GER=...
  python3 tools/commentary/generate.py [--dry-run] [--first] [--budget N] [--model eleven_multilingual_v2] [--only goal,save]
"""
import argparse, json, os, subprocess, sys, tempfile, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "commentary")

# tone -> (stability, style, similarity)
TONES = {
    "call": (0.45, 0.25, 0.8), "flat": (0.6, 0.1, 0.8), "lift": (0.4, 0.35, 0.8), "rise": (0.35, 0.45, 0.8),
    "shout": (0.25, 0.7, 0.75), "big": (0.3, 0.6, 0.75), "warm": (0.55, 0.2, 0.8),
}
# --first: the names and the moments heard most, so a part of the month's credits covers what matters.
FIRST = {"name", "county", "goal", "point", "point_long", "point_free", "wide", "save", "throw_in", "half_time",
    "full_time", "level", "lead_one"}


def have(i):
    return any(os.path.exists(os.path.join(OUT, i + e)) for e in (".ogg", ".mp3"))


def speak(key, voice, model, line):
    st, style, sim = TONES.get(line.get("tone", "call"), TONES["call"])
    body = json.dumps({"text": line["text"], "model_id": model, "voice_settings": {
        "stability": st, "similarity_boost": sim, "style": style, "use_speaker_boost": True}}).encode()
    req = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % voice,
        data=body, headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--first", action="store_true", help="only the names and the most-heard moments")
    ap.add_argument("--budget", type=int, default=0, help="stop before this many characters are spent")
    ap.add_argument("--model", default="eleven_multilingual_v2")
    ap.add_argument("--only", default="", help="comma-separated kinds")
    a = ap.parse_args()
    lines = json.load(open(os.path.join(OUT, "lines.json"), encoding="utf-8"))["lines"]
    todo = [l for l in lines if not have(l["id"])]
    if a.first:
        todo = [l for l in todo if l["on"] in FIRST]
    if a.only:
        todo = [l for l in todo if l["on"] in a.only.split(",")]
    todo.sort(key=lambda l: (l["on"] not in ("name", "county"), l["on"] not in FIRST))
    total = sum(len(l["text"]) for l in todo)
    print("%d lines to make, %d characters (%s)" % (len(todo), total,
        "about %d credits" % (total // 2 if "flash" in a.model or "turbo" in a.model else total)))
    if a.dry_run:
        for l in todo:
            print("  %-22s %s %s" % (l["id"], "Mick" if l["who"] == "A" else "Ger ", l["text"]))
        return
    key = os.environ.get("ELEVENLABS_API_KEY", "")
    voices = {"A": os.environ.get("ELEVENLABS_VOICE_MICK", ""), "B": os.environ.get("ELEVENLABS_VOICE_GER", "")}
    if not key or not voices["A"] or not voices["B"]:
        sys.exit("Set ELEVENLABS_API_KEY, ELEVENLABS_VOICE_MICK and ELEVENLABS_VOICE_GER first (README.md, step 3b).")
    spent = 0
    for l in todo:
        if a.budget and spent + len(l["text"]) > a.budget:
            print("budget reached: %d characters spent" % spent)
            break
        try:
            mp3 = speak(key, voices[l["who"]], a.model, l)
        except urllib.error.HTTPError as e:
            sys.exit("ElevenLabs said %d on %s: %s" % (e.code, l["id"], e.read()[:300].decode(errors="replace")))
        spent += len(l["text"])
        with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as f:
            f.write(mp3)
        # Mono Vorbis, the silence at each end trimmed (the game spaces the lines itself).
        trim = "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", f.name, "-af", trim, "-ac", "1", "-c:a", "libvorbis", "-q:a", "4",
            os.path.join(OUT, l["id"] + ".ogg")], check=True)
        os.unlink(f.name)
        print("made %-22s (%d characters so far)" % (l["id"], spent))
    print("done: %d characters" % spent)


if __name__ == "__main__":
    main()
