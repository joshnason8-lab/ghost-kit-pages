#!/usr/bin/env python3
"""List CC0 sounds on freesound.org for a search, most downloaded first: id, seconds, title, author, preview URL.

Only Creative Commons 0 sounds (the search's own licence filter, checked again on each sound's page by
freesound_fetch.py). Reads the public search page; no API key.

    python3 tools/audio/freesound_search.py "crowd groan" [max_seconds]
"""
import html
import re
import sys
import urllib.parse
import urllib.request


def search(query, max_s=60.0, page=1):
    url = "https://freesound.org/search/?" + urllib.parse.urlencode({
        "q": query, "f": 'license:"Creative Commons 0"', "s": "Downloads (most first)", "page": page})
    text = urllib.request.urlopen(url, timeout=30).read().decode("utf-8", "replace")
    out = []
    for block in text.split('data-sound-id="')[1:]:
        sid = block.split('"', 1)[0]
        get = lambda k: html.unescape(re.search(k + r'="([^"]*)"', block).group(1)) if re.search(k + r'="([^"]*)"', block) else ""
        dur = float(get("data-duration") or 0)
        user = re.search(r'/people/([^/]+)/sounds/' + sid, block)
        if dur <= max_s:
            out.append({"id": int(sid), "seconds": round(dur, 2), "title": get("data-title"),
                        "author": user.group(1) if user else "", "preview": get("data-ogg").replace("-lq.", "-hq.")})
    return out


if __name__ == "__main__":
    for s in search(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 60.0):
        print("%7d %6.2fs  %-40s %s" % (s["id"], s["seconds"], s["title"][:40], s["author"]))
