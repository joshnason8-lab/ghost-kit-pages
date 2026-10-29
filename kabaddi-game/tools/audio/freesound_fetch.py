#!/usr/bin/env python3
"""Download freesound.org sounds' high-quality previews by id, after checking on each sound's page that it is CC0.

Writes OUT/<id>.ogg and OUT/<id>.json (title, author, page, licence). Previews are 192 kbps Ogg Vorbis (stereo where
the original is), plenty for a phone game's mono 22 kHz sounds.

    python3 tools/audio/freesound_fetch.py OUT 763875 763880 ...
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request


def fetch(sid, out):
    page_url = "https://freesound.org/s/%d/" % sid
    req = urllib.request.Request(page_url, headers={"User-Agent": "Mozilla/5.0"})
    resp = urllib.request.urlopen(req, timeout=30)
    page = resp.read().decode("utf-8", "replace")
    final = resp.geturl()
    if "creativecommons.org/publicdomain/zero" not in page:
        raise SystemExit("%d is not CC0 (%s)" % (sid, final))
    title = re.search(r'<meta property="og:title" content="([^"]*)"', page)
    author = re.search(r"/people/([^/]+)/sounds/%d" % sid, final + page)
    ogg = re.search(r'https://cdn\.freesound\.org/previews/\d+/%d_\d+-hq\.ogg' % sid, page)
    if not ogg:
        lq = re.search(r'https://cdn\.freesound\.org/previews/\d+/%d_\d+-lq\.ogg' % sid, page)
        ogg_url = lq.group(0).replace("-lq.", "-hq.")
    else:
        ogg_url = ogg.group(0)
    data = None
    for url in [ogg_url, ogg_url.replace(".ogg", ".mp3"), ogg_url.replace("-hq.", "-lq.")]:
        try:
            data = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}),
                                          timeout=60).read()
            break
        except urllib.error.HTTPError:
            continue   # older sounds lack some previews
    if data is None:
        raise SystemExit("no preview for %d" % sid)
    open(os.path.join(out, "%d.ogg" % sid), "wb").write(data)
    meta = {"id": sid, "title": title.group(1) if title else "", "author": author.group(1) if author else "",
            "page": final, "licence": "CC0 1.0"}
    json.dump(meta, open(os.path.join(out, "%d.json" % sid), "w"), indent=1)
    return meta


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for sid in sys.argv[2:]:
        print(fetch(int(sid), out))
